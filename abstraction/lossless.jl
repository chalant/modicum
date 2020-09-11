include("../games/evaluation/evaluator.jl")
include("../games/evaluation/lookup.jl")
include("../games/cards.jl")

using IterTools
using JuMP
using LightGraphs
using Clp
using LightGraphsMatching
using Base.Threads
using ProgressMeter
using Mmap

using .evaluator
using .lookup
using .cards

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
    num_hand_cards::Int64,
    round_name::String,
    dir::String)

    println("Creating ", round_name, " hands matrix...")

    io = open(joinpath(dir, string(round_name, "_hands_matrix")), "w+")

    matrix = Mmap.mmap(
        io, Matrix{UInt64},
        (num_hand_cards, binomial(length(cards), num_hand_cards)))



    @showprogress for (j, h) in enumerate(subsets(cards, num_hand_cards))
        matrix[:, j] = h
    end
    Mmap.sync!(matrix)
    close(io)
end

function get_equivalent_hands(
    index_matrix::Matrix{UInt64},
    hands_matrix::Matrix{UInt64},
    index_array::Vector{UInt64})

    #index_matrix (num_subsets x num_hands)
    #hands_matrix (num_hands x num_subsets)

end

function get_equivalent_hand(
    hand::Vector{UInt64},
    hashes::Vector{UInt64},
    order_index::Vector{UInt64},
    id_array::Vector{UInt64},
    index_array::Vector{UInt64},
    hands_matrix::Matrix{UInt64})

    hand_id = hash(hand)

    idx::UInt64 = 1
    for h in hashes
        if hand_id == h
            break
        end
        idx += 1
    end

    f = find_hand(order_index[idx], index_array)

    i = 1
    for j in order_index
        if f == j
            return hands_matrix[:, i]
        end
        i += 1
    end

    # #return a view of the hands array
    # return hands_matrix[:, id_array[find_hand(order_index[idx], index_array)]]
end

function find_hand(hand::UInt64, forest::Vector{UInt64})

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
    u::UInt64,
    v::UInt64,
    idx_array::Vector{UInt64},
    sizes::Vector{UInt64},
)

    l = find_hand(u, idx_array)
    r = find_hand(v, idx_array)

    # if l != r
    #     if sizes[l] < sizes[r]
    #         idx_array[l] = r
    #         sizes[r] += sizes[l]
    #     else
    #         idx_array[r] = l
    #         sizes[l] += sizes[r]
    #     end
    #     return -1
    # end

    if l != r
        idx_array[l] = r
        return -1
    end

    return 0
end

function compress_river(
    cards::Vector{UInt64},
    flush_lookup::Dict{UInt64,UInt64},
    unsuited_lookup::Dict{UInt64,UInt64},
)

    function strength(hand::Vector{UInt64})
        evaluate(hand, flush_lookup, unsuited_lookup)
    end
    hands = [c for c in subsets(cards, 5)]
    N = length(hands)
    ct = N
    sort!(hands, by = strength)
    idx_array = Vector{UInt64}([i for i = 1:N])
    sizes = ones(UInt64, N)

    i::UInt64 = 1
    j::UInt64 = 2
    while j < N + 1
        if evaluate(hands[i], flush_lookup, unsuited_lookup) ==
           evaluate(hands[j], flush_lookup, unsuited_lookup)
            ct += hand_union(idx_array[i], idx_array[j], idx_array, sizes)
        end
        i += 1
        j += 1
    end
    #return a dict that maps a hash of hands to coresponding to index array
    return Dict{UInt64,UInt64}(zip([hash(Tuple(c)) for c in hands], idx_array))
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
struct DimSelector{dims, T}
    A::T
end

DimSelector{dims}(x::T) where {dims, T} = DimSelector{dims, T}(x)
(ds::DimSelector{dims, T})(i) where {dims, T} = i in dims ? axes(ds.A, i) : (:,)

_negdims(n, dims) = filter(i->!(i in dims), 1:n)

function _compute_itspace(A, ::Val{dims}) where {dims}
    negdims = _negdims(ndims(A), dims)
    axs = Iterators.product(ntuple(DimSelector{dims}(A), ndims(A))...)
    vec(permutedims(collect(axs), (dims..., negdims...)))
end

function _sortslices(A::AbstractArray, d::Val{dims}; kws...) where dims
    itspace = _compute_itspace(A, d)
    vecs = map(its->view(A, its...), itspace)
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
    num_chance_cards::Int64,
    num_hand_cards::Int64,
    round_name::String,
    dir::String)

    path = joinpath(dir, string(round_name,".bin"))
    temp = joinpath(dir, string(round_name, "_temp.bin"))
    idx = joinpath(dir, string(round_name, "_hands_index.bin"))

    nc = length(cards)
    hand_combos = binomial(nc, num_hand_cards)
    dms = (binomial(nc - num_hand_cards, num_chance_cards), hand_combos)
    #load pre-computed ranks
    if isfile(path)
        open(path, "r") do io
            compress_round(
                Mmap.mmap(io, Matrix{Int16}, dms),
                round_name,
                dir)
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

        @showprogress for tbl in subsets(cards, num_hand_cards)
            j = 1
            for hand in subsets(setdiff(cards,tbl), num_chance_cards)
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
                    vcat(hand, tbl),
                    flush_lookup,
                    unsuited_lookup,
                ))
                j += 1
            end
            k += 1
            # end
        end

        Mmap.sync!(ranks)

        itspace = _compute_itspace(ranks, Val{2}())
        vecs = map(its->view(ranks, its...), itspace)

        s_ranks = Mmap.mmap(io, Matrix{Int16}, dms)

        p = sortperm(vecs)

        println("Building index matrix...")
        hd_io = open(idx, "w+")
        hand_to_idx = Mmap.mmap(hd_io, Matrix{UInt64}, (hand_combos, 3))

        @showprogress for (l, m) in enumerate(map(x -> hash(x),
            subsets(cards, num_hand_cards)))
            hand_to_idx[l,1] = m
            hand_to_idx[l,2] = l
            hand_to_idx[l,3] = l #id of the hand
        end

        println("Re-indexing index matrix...")
        #re-index positions
        l = 1
        @showprogress for i in p
            hand_to_idx[i,2] = l
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
    end
end

function equal_ranks_array(
    arr1::Vector{Int16},
    arr2::Vector{Int16})

    # for i in 1:length(arr1)
    #     u = arr1[i]
    #     v = arr2[i]
    #     if u != v
    #         return false
    #     end
    # end
    # return true

    if length(setdiff(arr1, arr2)) > 0
        return false
    end
    return true
    # k = 1
    # l = 1
    #
    # while arr1[k] == 0
    #     k += 1
    # end
    #
    # while arr2[l] == 0
    #     l += 1
    # end
    #
    # # l1 = length(arr1) - k
    # # l2 = length(arr2) - l
    #
    # # graph = SimpleGraph(l1 + l2)
    #
    # # println(k, " ", l, " ", l1, " ", l2)
    # i = k
    # j = l
    #
    # a = length(arr1)
    # b = length(arr2)
    #
    # while true
    #
    #     if (k > a || l > b)
    #         break
    #     end
    #
    #     u = arr1[k]
    #     v = arr2[l]
    #
    #     if u > v
    #         l += 1
    #
    #     elseif u == v
    #         # add_edge!(graph, k - i, (l - j) + l1)
    #         k += 1
    #         l += 1
    #
    #     elseif u < v
    #         k += 1
    #     end
    # end
    #
    # if k != l
    #     return true
    # else
    #     return false
    # end
    # try
    #     match = maximum_weight_matching(graph, of)
    #     # println(match.mate)
    #     # println(arr1)
    #     # println(arr2)
    #     if in(-1, match.mate)
    #         return false
    #     end
    #     return true
    # catch
    #     return false
    # end
end

function compress_round_brute(
    ranks::Matrix{Int16},
    round_name::String,
    dir::String)

    io = open(joinpath(dir, string(round_name, "_compression_index")), "w+")
    num_hands = size(ranks)[2]
    sizes = ones(UInt64, num_hands)
    index_array = Mmap.mmap(io, Vector{UInt64}, num_hands)

    for i in 1:length(index_array)
        index_array[i] = i
    end

    println("Compressing ", round_name, " ...")
    ct = num_hands

    @showprogress for a in 1:num_hands
        for b in a:num_hands
            if equal_ranks_array(ranks[:, a], ranks[:, b])
                ct += hand_union(UInt64(a), UInt64(b), index_array, sizes)
            end
        end
    end
end

function compress_round(
    ranks::Matrix{Int16},
    round_name::String,
    dir::String)

    # display(ranks)
    io = open(joinpath(dir, string(round_name, "_compression_index")), "w+")
    num_hands = size(ranks)[2]
    sizes = ones(UInt64, num_hands)
    index_array = Mmap.mmap(io, Vector{UInt64}, num_hands)

    for i in 1:length(index_array)
        index_array[i] = i
    end

    println("Compressing ", round_name, " ...")
    ct = num_hands
    k::UInt64 = 1
    j::UInt64 = 2

    # of = with_optimizer(Clp.Optimizer, LogLevel=0)
    @showprogress for i in 1:num_hands - 1
        if equal_ranks_array(ranks[:, i], ranks[:, j])
            ct += hand_union(k, j, index_array, sizes)
        end
        k += 1
        j += 1
    end

    println("Total Compression ", 100 * ct / num_hands)
    println("Number of hands ", ct)

    close(io)
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
        round_name::String,
        hand_size::Int64,
        dir::String)
    println("Equivalent hands ")

    io = open(joinpath(dir, string(round_name, "_hands_index.bin")))
    io1 = open(joinpath(dir, string(round_name, "_hands_matrix")))
    io2 = open(joinpath(dir, string(round_name, "_compression_index")))

    subs = binomial(length(cards), hand_size)

    idx_mat = Mmap.mmap(io, Matrix{UInt64}, (subs, 3))
    hands_mat = Mmap.mmap(io1, Matrix{UInt64}, (hand_size, subs))
    idx_arr = Mmap.mmap(io2, Vector{UInt64}, subs)

    hashes = idx_mat[:,1]
    orders = idx_mat[:,2]
    ids = idx_mat[:,3]

    for hand in subsets(cards, hand_size)
        println(
            pretty_print_cards(hand),",",
            pretty_print_cards(get_equivalent_hand(
                hand, hashes, orders, ids, idx_arr, hands_mat)))
    end

    close(io)
    close(io1)
    close(io2)
end

function compress()
    a, b = create_lookup_tables()
    cards = get_deck()

    dir = "/media/yves/Data/ranks"
    # dir = "/home/yves/PycharmProjects/hermes/resources"
    try
        mkdir(dir)
    catch
    end

    compute_ranks(cards, a, b, 5, 2, "test", dir)

    # compute_ranks(cards, a, b, 3, 2, "pre_flop", dir)
    # compute_ranks(cards, a, b, 1, 5, "flop", dir)
    # compute_ranks(cards, a, b, 1, 6, "turn", dir)

    # _create_hands_matrix(cards, 2, "test", dir)
    # _create_hands_matrix(cards, 2, "pre_flop", dir)
    # _create_hands_matrix(cards, 5, "flop", dir)
    # _create_hands_matrix(cards, 6, "turn", dir)
    # _create_hands_matrix(cards, 7, "river", dir)

    # print_equivalent_hands(cards, "pre_flop", 2, dir)
    # print_equivalent_hands(cards, "flop", 5, dir)

end

@time compress()
