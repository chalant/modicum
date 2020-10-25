include("../games/evaluation/evaluator.jl")
include("../games/evaluation/lookup.jl")
include("../games/cards.jl")
include("../abstraction/hands_filter.jl")

using IterTools
using ProgressMeter
using Mmap
using JSON
using Serialization

using .evaluator
using .lookup
using .cards
using .hands_filter

function concatenate(
    arr::Vector{UInt64},
    l::Vector{UInt64},
    r::Vector{UInt64},
)
    i = 1
    for c in l
        arr[i] = c
        i += 1
    end

    for c in r
        arr[i] = c
        i += 1
    end

    return arr
end

function concatenate(
    arr::Vector{UInt64},
    l::Vector{UInt64},
    r::Vector{UInt64},
    m::Vector{UInt64},
)
    i = 1
    for c in l
        arr[i] = c
        i += 1
    end

    for c in r
        arr[i] = c
        i += 1
    end

    for c in m
        arr[i] = c
        i += 1
    end

    return arr
end

function _create_hands_matrix(
    cards::Vector{UInt64},
    round_name::String,
    dir::String,
)

    println("Building ", round_name, " hand lookup index")

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
    return 0
end

function equal_ranks_array(arr1::Vector{Int16}, arr2::Vector{Int16})
    if length(setdiff(arr1, arr2)) > 0
        return false
    end
    return true
end

function compute_ranks(
    cards::Vector{UInt64},
    lookup_tables::LookupTables,
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

    temp = joinpath(dir, "ranks.bin")
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

    cat_arr = Vector{UInt64}(undef, num_chance_cards + 2)

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
                    concatenate(cat_arr, hand, board),
                    lookup_tables,
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
                    concatenate(cat_arr, hand, board),
                    lookup_tables,
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

    @showprogress for i in 1:cols
        perms[i] = i
    end

    println("Sorting permutations...")
    sort!(perms, by=view_col)

    compress_round(ranks, perms, pvt, ncc, round_name, dir)

    close(tempio)
    close(orderio)
    _create_hands_matrix(cards, round_name, dir)
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
    tmp_io = open(joinpath(dir, "compression_index"), "w+")

    sizes_path = joinpath(dir, "size")
    sizesio = open(sizes_path, "w+")
    metadata = Dict{String, Int64}()

    num_hands = size(ranks)[2]
    sizes = Mmap.mmap(sizesio, Vector{UInt32}, num_hands)
    idx_array = Mmap.mmap(tmp_io, Vector{UInt32}, num_hands)

    println("Initializing arrays...")
    @showprogress for i in 1:num_hands
        idx_array[i] = i
        sizes[i] = 1
    end

    println("Compressing ", round_name, "...")
    ct = num_hands

    j::UInt32 = 2

    # of = with_optimizer(Clp.Optimizer, LogLevel=0)
    @showprogress for i in 1:num_hands-1
        k = permutations[i]
        l = permutations[j]
        if equal_ranks_array(ranks[:, k],
            ranks[:, l])
            ct += hand_union(k, l, idx_array, sizes)
        end
        j += 1
    end

    path::Vector{UInt32} = []

    println("Compressing search index...")
    @showprogress for i in 1:num_hands
        j = i
        append!(path, j)

        while j != idx_array[j]
            j = idx_array[j]
            append!(path, j)
        end

        for h in path
            idx_array[h] = j
        end

        empty!(path)
    end

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

function compress()
    lkp = create_lookup_table()
    cards = get_deck()

    dir = "/media/yves/Data/lossless"
    # dir = "/home/yves/PycharmProjects/hermes"

    try
        mkdir(dir)
    catch
    end

    # compute_ranks(cards, a, b, 0, "pre_flop", dir)
    compute_ranks(cards, lkp, 3, "flop", dir)
    # compute_ranks(cards, a, b, 4, "turn", dir)
    # compute_ranks(cards, a, b, 5, "river", dir)

    # compute_ranks_2(cards, a, b, c, 3, "flop", dir)
    # dir = joinpath(dir, "river")
    # _create_hands_matrix(cards, "river", dir)

end

@time compress()
