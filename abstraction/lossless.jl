include("../games/evaluation/evaluator.jl")
include("../games/evaluation/lookup.jl")
include("../games/cards.jl")
include("../abstraction/batches.jl")

using IterTools
using JuMP
using LightGraphs
using Clp
using LightGraphsMatching
using Base.Threads
using ProgressMeter
using Mmap
using JSON
using HDF5
using Serialization

using .evaluator
using .lookup
using .cards
using .batches

const NUM_THREADS = nthreads()

function compress_hands(idx_array::Vector{UInt64})
    dct = Dict{UInt64,UInt64}()
    compressed = Vector{UInt64}()
    for idx in idx_array
        h_idx = find_hand(idx, idx_array)
        if !haskey(dct, h_idx)
            dct[h_idx] = h_idx
            append!(compressed, h_idx)
        end
    end
    return compressed
end


function get_compressed_hands(
    hands::Vector{Vector{UInt64}},
    idx_array::Vector{UInt64},
)
    compressed = Vector{Vector{UInt64}}()
    for i in idx_array
        append!(compressed, [hands[i]])
    end
    return compressed
end

function _create_hands_matrix(
    cards::Vector{UInt64},
    round_name::String,
    dir::String,
)

    println("Building ", round_name, " index and hand matrix...")

    hd_io = open(joinpath(dir, "hands.bin"), "w+")
    compio = open(joinpath(dir, "compression_index"))

    tmp_hd_path = joinpath(dir, "tmp_hands.bin")
    tmp_hdio = open(tmp_hd_path, "w+")

    f = open(joinpath(dir, "metadata.json"))
    metadata = JSON.parse(f)
    close(f)

    comp_sz = metadata["compression_size"]
    m = metadata["hand_length"]
    n = metadata["total_hands"]
    num_chance_cards = metadata["board_cards_length"]

    compr = Mmap.mmap(compio, Vector{UInt32}, n)
    hands = Dict{UInt32, Vector{UInt64}}()
    hands_tmp = Mmap.mmap(tmp_hdio, Matrix{UInt64}, (m, n))

    println("Creating temporary hands...")

    if round_name != "pre_flop"
        z = 1

        @showprogress for hand in subsets(cards, 2)
            for board in subsets(setdiff(cards, hand), num_chance_cards)
                hands_tmp[:, z] = vcat(hand, board)
                z += 1
            end
        end
    else
        @showprogress for (l, h) in enumerate(subsets(cards, 2))
            hands_tmp[:, l] = h
        end
    end

    println("Compressing hands...")
    p = Progress(comp_sz)
    for j in distinct(compr)
        hands[j] = hands_tmp[:, j]
        next!(p)
    end

    serialize(hd_io, hands)

    close(hd_io)
    close(compio)
    close(tmp_hdio)
    rm(tmp_hd_path)
end

function get_equivalent_hand(
    hand::Vector{UInt64},
    hands::Vector{UInt64},
    order_index::Vector{UInt64},
    index_array::Vector{UInt64},
)

    idx = findall(x -> hands[:, x] == hand, 1:size(hands)[2])[1]
    f = find_hand(order_index[idx], index_array)

    return hands_matrix[:, findall(x -> x == f, order_index)[0]]
end

function find_hand(hand::UInt32, forest::Vector{UInt32})

    hd = hand
    # path::Vector{UInt64} = []
    # append!(path, hd)
    while hd != forest[hd]
        hd = forest[hd]
        # append!(path, hd)
    end
    # for h in path
    #     forest[h] = hd
    # end
    return hd
end

function hand_union(
    u::UInt32,
    v::UInt32,
    idx_array::Vector{UInt32},
    sizes::Vector{UInt32},
)

    l = find_hand(u, idx_array)
    r = find_hand(v, idx_array)

    if l != r
        if sizes[l] < sizes[r]
            idx_array[l] = r
            sizes[r] += sizes[l]
        else
            idx_array[r] = l
            sizes[l] += sizes[r]
        end
        return -1
    end

    # if l != r
    #     idx_array[l] = r
    #     return -1
    # end

    return 0
end

function batch(array::Vector{Int64}, lg::Int64)
    arr = Vector{Vector{Int16}}()
    j = 1
    mx = length(array)
    itr = ceil(mx / lg)
    for i = 1:itr
        try
            t = j + lg - 1
            push!(arr, array[j:t])
            j = t + 1
        catch
            push!(arr, array[j:mx])
        end
    end
    return arr
end

function sortscols(A::AbstractArray; kws...)
    _sortslices(A, Val{2}(); kws...)
end

# Works around inference's lack of ability to recognize partial constness
struct DimSelector{dims,T}
    A::T
end

DimSelector{dims}(x::T) where {dims,T} = DimSelector{dims,T}(x)
(ds::DimSelector{dims,T})(i) where {dims,T} = i in dims ? axes(ds.A, i) : (:,)

_negdims(n, dims) = filter(i -> !(i in dims), 1:n)

function _compute_itspace(A, ::Val{dims}) where {dims}
    negdims = _negdims(ndims(A), dims)
    axs = Iterators.product(ntuple(DimSelector{dims}(A), ndims(A))...)
    vec(permutedims(collect(axs), (dims..., negdims...)))
end

function _sortslices(A::AbstractArray, d::Val{dims}; kws...) where {dims}
    itspace = _compute_itspace(A, d)
    vecs = map(its -> view(A, its...), itspace)
    p = sortperm(vecs; kws...)
    if ndims(A) == 2 && isa(dims, Integer) && isa(A, Array)
        # At the moment, the performance of the generic version is subpar
        # (about 5x slower). Hardcode a fast-path until we're able to
        # optimize this.
        return dims == 1 ? A[p, :] : A[:, p]
    else
        B = similar(A)
        for (x, its) in zip(p, itspace)
            B[its...] = vecs[x]
        end
        B
    end
end

function compute_ranks(
    cards::Vector{UInt64},
    flush_lookup::Dict{UInt64,UInt64},
    unsuited_lookup::Dict{UInt64,UInt64},
    hh_lookup::Dict{UInt64,UInt64},
    num_chance_cards::Int64,
    num_hand_cards::Int64,
    round_name::String,
    dir::String,
)

    dir = joinpath(dir, round_name)

    try
        mkdir(dir)
    catch
    end

    path = joinpath(dir, "ranks.bin")
    temp = joinpath(dir, "ranks_temp.bin")
    idx = joinpath(dir, "hands_index.bin")

    nc = length(cards)
    hand_combos = binomial(nc, num_hand_cards)

    dms = (binomial(nc - num_hand_cards, num_chance_cards), hand_combos)
    #load pre-computed ranks
    if isfile(path)
        open(path, "r") do io
            compress_round(Mmap.mmap(io, Matrix{Int16}, dms), round_name, dir)
        end
    else
        println("Pre-computing ", round_name, " ranks")

        io = open(path, "w+")
        tempio = open(temp, "w+")
        # ta = table([Int16[] for j in 1:length(hands)]...,)
        ranks = Mmap.mmap(tempio, Matrix{Int16}, dms)

        # if num_chance_cards > num_hand_cards
        #     k = 1
        #
        #     @showprogress for tbl in subsets(cards, num_chance_cards)
        #         j = 1
        #         for hand in subsets(cards, num_hand_cards)
        #             if length(intersect(hand, tbl)) == 0
        #                 ranks[k, j] = Int16(evaluate(
        #                     vcat(hand, tbl),
        #                     flush_lookup,
        #                     unsuited_lookup,
        #                 ))
        #             # else
        #             #     ranks[k, j] = 0
        #             end
        #             # ranks[k, j] = Int16(evaluate(
        #             #     vcat(hand, tbl),
        #             #     flush_lookup,
        #             #     unsuited_lookup,
        #             # ))
        #             j += 1
        #         end
        #         k += 1
        #     end
        # else
        k = 1

        @showprogress for hand in subsets(cards, num_hand_cards)
            j = 1
            for board in subsets(setdiff(cards, hand), num_chance_cards)
                # if length(intersect(hand, tbl)) == 0
                #     ranks[j, k] = Int16(evaluate(
                #         vcat(hand, tbl),
                #         flush_lookup,
                #         unsuited_lookup,
                #     ))
                # else
                #     ranks[j, k] = 0
                # end
                ranks[j, k] = Int16(evaluate(
                    hand,
                    board,
                    flush_lookup,
                    unsuited_lookup,
                    hh_lookup,
                ))
                j += 1
            end
            k += 1
            # end
        end

        Mmap.sync!(ranks)

        itspace = _compute_itspace(ranks, Val{2}())
        vecs = map(its -> view(ranks, its...), itspace)

        s_ranks = Mmap.mmap(io, Matrix{Int16}, dms)

        println("Computing order permutations...")

        p = sortperm(vecs)

        println("Building index matrix...")
        hd_io = open(idx, "w+")
        hand_to_idx = Mmap.mmap(hd_io, Matrix{UInt64}, (hand_combos, 3))

        @showprogress for (l, m) in enumerate(map(
            x -> hash(x),
            subsets(cards, num_hand_cards),
        ))
            hand_to_idx[l, 1] = m
            hand_to_idx[l, 2] = l
            hand_to_idx[l, 3] = l #id of the hand
        end

        println("Re-indexing index matrix...")
        #re-index positions
        l = 1
        @showprogress for i in p
            hand_to_idx[i, 2] = l
            l += 1
        end
        Mmap.sync!(hand_to_idx)
        # s_ranks[:, p] = ranks[:, p]

        println("Sorting ranks...")

        @showprogress for (x, its) in zip(p, itspace)
            s_ranks[its...] = vecs[x]
        end

        Mmap.sync!(s_ranks)
        close(tempio)
        close(hd_io)
        rm(temp)
        compress_round(s_ranks, round_name, dir)
        close(io)
        _create_hands_matrix(cards, num_hand_cards, round_name, dir)
    end
end

function compress_index(dir::String, round_name::String)
    f = open(joinpath(dir, "metadata.json"))
    metadata = JSON.parse(f)
    close(f)

    n = metadata["total_hands"]
    compr = Mmap.mmap(compio, Vector{UInt64}, n)
    path::Vector{UInt64} = []

    println("Compressing search index...")
    @showprogress for i in compr
        j = i
        append!(path, j)

        while j != compr[j]
            j = compr[j]
            append!(path, j)
        end

        for h in path
            compr[h] = j
        end

        empty!(path)
    end
    # close(compio)
end

function compute_ranks_3(
    cards::Vector{UInt64},
    flush_lookup::Dict{UInt64,UInt64},
    unsuited_lookup::Dict{UInt64,UInt64},
    hh_lookup::Dict{UInt64,UInt64},
    num_chance_cards::Int64,
    round_name::String,
    dir::String,
)

    dir = joinpath(dir, round_name)

    try
        mkdir(dir)
    catch
    end

    path = joinpath(dir, "ranks.bin")
    temp = joinpath(dir, "ranks_temp.bin")
    order_path = joinpath(dir, "order.bin")
    tmp_order = joinpath(dir, "rev_perm.bin")

    cols = 1
    rows = 1
    nc = length(cards)

    if num_chance_cards == 0
        cols = binomial(nc, 2)
        rows = binomial(nc - 2, 3)
        num_chance_cards = 3
        pvt = 2
        ncc = 0
    else
        cols = binomial(nc, 2) * binomial(nc - 2, num_chance_cards)
        pvt = 2 + num_chance_cards
        ncc = num_chance_cards
    end

    dms = (rows, cols)

    #load pre-computed ranks
    if isfile(path)
        rks_io = open(path)
        permsio = open(tmp_order)
        compress_round(
            Mmap.mmap(rks_io, Matrix{Int16}, dms),
            Mmap.mmap(permio, Vector{Int64}, dms),
            pvt,
            num_chance_cards,
            round_name,
            dir)
        close(rks_io)
        close(permsio)
    else
        println("Pre-computing ", round_name, " ranks")

        io = open(path, "w+")
        tempio = open(temp, "w+")
        orderio = open(order_path, "w+")
        tmp_orderio = open(tmp_order, "w+")
        # ta = table([Int16[] for j in 1:length(hands)]...,)
        ranks = Mmap.mmap(tempio, Matrix{Int16}, dms)

        if round_name == "pre_flop"
            k = 1

            @showprogress for hand in subsets(cards, 2)
                j = 1
                for board in subsets(setdiff(cards, hand), num_chance_cards)
                    ranks[j, k] = Int16(evaluate(
                        hand,
                        board,
                        flush_lookup,
                        unsuited_lookup,
                        hh_lookup,
                    ))
                    j += 1
                end
                k += 1
                # end
            end
        else
            k = 1

            @showprogress for hand in subsets(cards, 2)
                for board in subsets(setdiff(cards, hand), num_chance_cards)
                    ranks[1, k] = Int16(evaluate(
                        hand,
                        board,
                        flush_lookup,
                        unsuited_lookup,
                        hh_lookup,
                    ))
                    k += 1
                end
            end
        end

        Mmap.sync!(ranks)

        function view_col(index::Int64)
            return view(ranks, :, index)
        end

        println("Computing order vector")
        perms = Mmap.mmap(orderio, Vector{Int64}, cols)
        rev_perms = Mmap.mmap(tmp_orderio, Vector{Int64}, cols)

        function position(index::Int64)
            return view(perms, index)
        end

        for i = 1:cols
            perms[i] = i
            rev_perms[i] = i
        end

        sort!(perms, by=view_col)
        sort!(rev_perms, by=position)

        s_ranks = Mmap.mmap(io, Matrix{Int16}, dms)

        println("Sorting ranks...")

        @showprogress for (i, j) in enumerate(perms)
            s_ranks[:, i] = ranks[:, j]
        end

        Mmap.sync!(s_ranks)

        compress_round(s_ranks, rev_perms, pvt, ncc, round_name, dir)

        close(tempio)
        close(orderio)
        close(io)
        close(tmp_orderio)

        rm(temp)
    end
    _create_hands_matrix(cards, round_name, dir)
end

function compute_ranks_2(
    cards::Vector{UInt64},
    flush_lookup::Dict{UInt64,UInt64},
    unsuited_lookup::Dict{UInt64,UInt64},
    num_chance_cards::Int64,
    num_hand_cards::Int64,
    round_name::String,
    dir::String,
)

    dtr = joinpath(dir, string(round_name))

    try
        mkdir(dtr)
    catch
    end

    path = joinpath(dtr, "ranks.bin")
    order_path = joinpath(dtr, "order.bin")
    hashes_path = joinpath(dtr, "hashes.bin")
    sizes_path = joinpath(dtr, "sizes.bin")
    index_path = joinpath(dtr, "index.bin")

    nc = length(cards)
    hand_combos = binomial(nc, num_hand_cards)
    board_combos = binomial(nc - num_hand_cards, num_chance_cards)

    num_hands = hand_combos * board_combos
    ct = num_hands

    #load pre-computed ranks
    if isfile(path)
        open(path, "r") do io
            compress_round(Mmap.mmap(io, Vector{Int16}, ct), round_name, dir)
        end
    else
        println("Pre-computing ", round_name, " ranks")

        io = open(path, "w+")
        orderio = open(order_path, "w+")
        hashesio = open(hashes_path, "w+")
        sizesio = open(sizes_path, "w+")
        indexio = open(index_path, "w+")

        # ta = table([Int16[] for j in 1:length(hands)]...,)
        ranks = Mmap.mmap(io, Vector{Int16}, ct)
        order = Mmap.mmap(orderio, Vector{UInt64}, ct)
        index_array = Mmap.mmap(indexio, Vector{UInt64}, ct)
        hashes = Mmap.mmap(hashesio, Vector{UInt64}, ct)
        sizes = Mmap.mmap(sizesio, Vector{UInt64}, ct)

        for i = 1:ct
            sizes[i] = 1
        end

        for i = 1:ct
            index_array[i] = i
        end

        k = 1

        @showprogress for hand in subsets(cards, num_hand_cards)
            for board in subsets(setdiff(cards, hand), num_chance_cards)
                ranks[k] =
                    Int16(evaluate(hand, board, flush_lookup, unsuited_lookup))
                hashes[k] = hash(vcat(hand, board))
                k += 1
            end
        end

        Mmap.sync!(ranks)

        order = sortperm(ranks)

        a = 1
        b = 2

        println("Compressing...")

        @showprogress for j = 1:length(ranks)-1
            u = UInt64(order[a])
            v = UInt64(order[b])

            if ranks[u] == ranks[v]
                ct += hand_union(u, v, index_array, sizes)
            end
            a += 1
            b += 1
        end

        println("Total Compression ", 100 * ct / num_hands)
        println("Number of hands ", ct)

        close(orderio)
        close(hashesio)
        close(sizesio)
        close(indexio)

        rm(sizes_path)
        close(io)
    end
end

function equal_ranks_array(arr1::Vector{Int16}, arr2::Vector{Int16})
    if length(setdiff(arr1, arr2)) > 0
        return false
    end
    return true

end

function compute_ranks_4(
    cards::Vector{UInt64},
    flush_lookup::Dict{UInt64,UInt64},
    unsuited_lookup::Dict{UInt64,UInt64},
    hh_lookup::Dict{UInt64,UInt64},
    num_chance_cards::Int64,
    round_name::String,
    dir::String,
    )

    dir = joinpath(dir, round_name)

    try
        mkdir(dir)
    catch
    end

    println("Pre-computing ", round_name, " ranks")

    path = joinpath(dir, "ranks.bin")
    temp = joinpath(dir, "ranks_temp.bin")
    order_path = joinpath(dir, "order.bin")
    # tmp_order = joinpath(dir, "rev_perm.bin")

    cols = 1
    rows = 1
    nc = length(cards)

    if num_chance_cards == 0
        cols = binomial(nc, 2)
        rows = binomial(nc - 2, 3)
        num_chance_cards = 3
        pvt = 2
        ncc = 0
    else
        cols = binomial(nc, 2) * binomial(nc - 2, num_chance_cards)
        pvt = 2 + num_chance_cards
        ncc = num_chance_cards
    end

    dms = (rows, cols)

    # io = open(path, "w+")
    tempio = open(temp, "w+")
    orderio = open(order_path, "w+")
    # tmp_orderio = open(tmp_order, "w+")
    ranks = Mmap.mmap(tempio, Matrix{Int16}, dms)

    if round_name == "pre_flop"
        k = 1

        @showprogress for hand in subsets(cards, 2)
            j = 1
            for board in subsets(setdiff(cards, hand), num_chance_cards)
                ranks[j, k] = Int16(evaluate(
                    hand,
                    board,
                    flush_lookup,
                    unsuited_lookup,
                    hh_lookup,
                ))
                j += 1
            end
            k += 1
            # end
        end
    else
        k = 1

        @showprogress for hand in subsets(cards, 2)
            for board in subsets(setdiff(cards, hand), num_chance_cards)
                ranks[1, k] = Int16(evaluate(
                    hand,
                    board,
                    flush_lookup,
                    unsuited_lookup,
                    hh_lookup,
                ))
                k += 1
            end
        end
    end

    Mmap.sync!(ranks)

    function view_col(index::UInt32)
        return view(ranks, :, index)
    end

    println("Creating permutation vector...")
    perms = Mmap.mmap(orderio, Vector{UInt32}, cols)
    # rev_perms = Mmap.mmap(tmp_orderio, Vector{UInt32}, cols)

    @showprogress for i in 1:cols
        perms[i] = i
        # rev_perms[i] = i
    end

    println("Sorting permutations...")
    sort!(perms, by=view_col)
    #
    # tmp_rev_path = "tmp_rev.bin"
    # fid = h5open("perms.h5", "r")
    # perms = fid["perms/perms"]
    # # g["perms", "chunk", 1000000] = perms
    # batches = Batch(perms, cols, 1000000)
    # println("Number of batches ", length(batches))
    # println("Sorting reverse permutations...")
    # p = Progress(cols)
    # i = 1
    # for batch in batches
    #     for j in batch
    #         rev_perms[j] = i
    #         i += 1
    #         next!(p)
    #     end
    # end
    # @showprogress for (i, j) in enumerate(perms)
    #     rev_perms[j] = i
    # end
    # close(fid)
    # #
    # s_ranks = Mmap.mmap(io, Matrix{Int16}, dms)
    # #
    # println("Sorting ranks...")
    #
    # @showprogress for (i, j) in enumerate(perms)
    #     s_ranks[:, i] = ranks[:, j]
    # end
    #
    # Mmap.sync!(s_ranks)

    compress_round(ranks, perms, pvt, ncc, round_name, dir)

    close(tempio)
    close(orderio)
    # close(io)
    # close(tmp_orderio)

    # rm(temp)
    # rm(order_path)
end

function compress_round(
    ranks::Matrix{Int16},
    permutations::Vector{UInt32},
    hand_length::Int64,
    num_chance_cards::Int64,
    round_name::String,
    dir::String)

    tmp_path = joinpath(dir, "tmp_compression_index")
    # display(ranks)
    # io = open(joinpath(dir, "compression_index"), "w+")
    tmp_io = open(joinpath(dir, "compression_index"), "w+")

    sizes_path = joinpath(dir, "size")
    sizesio = open(sizes_path, "w+")
    metadata = Dict{String, Int64}()

    num_hands = size(ranks)[2]
    sizes = Mmap.mmap(sizesio, Vector{UInt32}, num_hands)
    # index_array = Mmap.mmap(io, Vector{UInt32}, num_hands)
    tmp_idx_array = Mmap.mmap(tmp_io, Vector{UInt32}, num_hands)

    # for i = 1:num_hands
    #     sizes[i] = 1
    # end

    println("Initializing arrays...")
    @showprogress for i in 1:num_hands
        # index_array[i] = i
        tmp_idx_array[i] = i
        sizes[i] = 1
    end

    println("Compressing ", round_name, "...")
    ct = num_hands

    k::UInt32 = 1
    j::UInt32 = 2

    # of = with_optimizer(Clp.Optimizer, LogLevel=0)
    @showprogress for i in 1:num_hands-1
        if equal_ranks_array(ranks[:, permutations[i]],
            ranks[:, permutations[j]])
            ct += hand_union(k, j, tmp_idx_array, sizes)
        end
        k += 1
        j += 1
    end

    path::Vector{UInt32} = []

    println("Compressing search index...")
    @showprogress for i in 1:num_hands
        j = i
        append!(path, j)

        while j != tmp_idx_array[j]
            j = tmp_idx_array[j]
            append!(path, j)
        end

        for h in path
            tmp_idx_array[h] = j
        end

        empty!(path)
    end

    # println("Re-indexing index array")
    # @showprogress for (i, j) in enumerate(rev_permutations)
    #     index_array[i] = tmp_idx_array[j]
    # end


    println("Total Compression ", 100 * ct / num_hands)
    println("Number of hands ", ct)

    metadata["compression_size"] = ct
    metadata["total_hands"] = num_hands
    metadata["hand_length"] = hand_length
    metadata["board_cards_length"] = num_chance_cards

    open(joinpath(dir, "metadata.json"), "w") do f
        write(f, json(metadata))
    end

    close(sizesio)
    # close(io)
    close(tmp_io)

    # rm(tmp_path)
    rm(sizes_path)
end

function five_hand_compression(
    forest::Vector{Vector{UInt64}},
    flush_lookup::Dict{UInt64,UInt64},
    unsuited_lookup::Dict{UInt64,UInt64},
)

    N = length(forest)
    ct = N
    utilities::Vector{UInt64} =
        [evaluate(c, flush_lookup, unsuited_lookup) for c in forest]

    # sort!(utilities)

    idx_array::Vector{UInt64} = [i for i = 1:N]
    sizes::Vector{UInt64} = [1 for i = 1:N]

    i::UInt64 = 1
    j::UInt64 = 2

    while j < N + 1
        if utilities[i] == utilities[j]
            ct += hand_union(i, j, idx_array, sizes)
        end
        i += 1
        j += 1
    end
    return idx_array
end

function print_equivalent_hands(
    cards::Vector{UInt64},
    num_chance_cards::Int64,
    round_name::String,
    hand_size::Int64,
    dir::String,
)
    println("Equivalent hands ")

    dir = joinpath(dir, round_name)

    io2 = open(joinpath(dir, "compression_index"))
    hd_io = open(joinpath(dir, "hands.bin"))
    orderio = open(joinpath(dir, "order.bin"))

    nc = length(cards)

    if round_name != "pre_flop"
        subs = binomial(nc - 2, num_chance_cards) * binomial(nc, 2)

        idx_arr = Mmap.mmap(io2, Vector{UInt64}, subs)
        hands = Mmap.mmap(hd_io, Matrix{UInt64}, subs)
        orders = Mmap.mmap(orderio, Vector{UInt64}, subs)

        for hand in subsets(cards, 2)
            for board in subsets(setdiff(cards, hand), num_chance_cards)
                hd = vcat(hand, board)
                println(
                    pretty_print_cards(hd),
                    ", ",
                    pretty_print_cards(get_equivalent_hand(
                        hd,
                        hands,
                        orders,
                        idx_arr,
                    )),
                )
            end
        end
    else
        subs = binomial(nc, 2)

        idx_arr = Mmap.mmap(io2, Vector{UInt64}, subs)
        hands = Mmap.mmap(hd_io, Matrix{UInt64}, (2, subs))
        orders = Mmap.mmap(orderio, Vector{UInt64}, subs)

        for hand in subsets(cards, 2)
            println(pretty_print_cards(hand), ", ", pretty_print_cards())
        end

    end

    close(io)
    close(io1)
    close(io2)
end

function compression_info(
    cards::Vector{UInt64},
    num_hand_cards::Int64,
    round_name::String,
    dir::String,
)

    nc = length(cards)
    hand_combos = binomial(nc, num_hand_cards)
    counter = 0

    io1 = open(joinpath(dir, string(round_name, "_hands_index.bin")))

    idx_mat = Mmap.mmap(io1, Matrix{UInt64}, (hand_combos, 3))
    orders = view(idx_mat, :, 2)
    hashes = view(idx_mat, :, 1)

    d = Dict{UInt64,UInt64}()

    open(joinpath(dir, string(round_name, "_compression_index"))) do io
        index_array = Mmap.mmap(io, Vector{UInt64}, hand_combos)

        for idx = 1:hand_combos
            # h = hash(card)
            # idx = 1
            # for k in hashes
            #     if k == h
            #         break
            #     end
            #     idx += 1
            # end

            j = find_hand(orders[idx], index_array)
            if !haskey(d, j)
                d[j] = j
                counter += 1
            end
        end
        println("Number of hands: ", counter)
        println("Compression ratio: ", 100 * (counter / hand_combos))
    end
    close(io1)
end

function compress()
    a, b, c = create_lookup_tables()
    cards = get_deck()

    dir = "/media/yves/Data/lossless_test"
    # dir = "/media/yves/Data/ranks"
    # dir = "/media/yves/Data/lossless_1"
    # dir = "/home/yves/PycharmProjects/hermes"
    # dir = "/media/yves/Data/lossless_test1"

    rdn_to_nhd = Dict{String,Int64}(
        "pre_flop" => 2,
        "flop" => 3,
        "turn" => 4,
        "river" => 5,
    )

    try
        mkdir(dir)
    catch
    end

    # compute_ranks(cards, a, b, 5, 2, "test", dir)
    # compute_ranks(cards, a, b, 2, 5, "test2", dir)

    # compute_ranks(cards, a, b, 3, 2, "pre_flop", dir)
    # compute_ranks(cards, a, b, 0, 5, "flop", dir)
    # compute_ranks(cards, a, b, c, 0, 6, "turn", dir)
    # compute_ranks(cards, a, b, c, 0, 7, "river", dir)




    # round_name = "flop"
    # print_equivalent_hands(cards, round_name, rdn_to_nhd[round_name], dir)
    # compression_info(cards, rdn_to_nhd[round_name], round_name, dir)
    # compute_ranks_3(cards, a, b, c, 0, "pre_flop", dir)
    # compute_ranks_4(cards, a, b, c, 3, "flop", dir)
    # compute_ranks_3(cards, a, b, c, 4, "turn", dir)
    # compute_ranks_4(cards, a, b, c, 5, "river", dir)
    dir = joinpath(dir, "river")
    _create_hands_matrix(cards, "river", dir)
    # round_name = "pre_flop"
    # _create_hands_matrix(cards, rdn_to_nhd[round_name], round_name, dir)
    # round_name = "flop"
    # _create_hands_matrix(cards, rdn_to_nhd[round_name], round_name, dir)
    # round_name = "turn"
    # _create_hands_matrix(cards, rdn_to_nhd[round_name], round_name, dir)
    # round_name = "river"
    # _create_hands_matrix(cards, rdn_to_nhd[round_name], round_name, dir)

end

# @main function equivalent_hands(round_name::String, look_ahead::String)
#     cards = get_deck()
#
#     rdn_to_nhd = Dict{String, Int64}(
#         "pre_flop" => 2,
#         "flop" => 5,
#         "turn" => 6,
#         "river" => 7
#     )
#
# end

@time compress()
