include("../games/evaluation/lookup.jl")
include("./abstraction/kmeans.jl")
include("./abstraction/memory_mapping.jl")

using Mmap

using .lookup
using .kmeans


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


function compute_equities(
    lookup_tables::LookupTables,
    cards::Vector{UInt64},
    num_hand_cards::Int64,
    max_hand_cards::Int64,
    round_name::String,
    dir::String,
)
    dir = joinpath(dir, round_name)

    try
        mkdir(dir)
    catch
    end

    println("Pre-computing ", round_name, " ranks")

    equities_path = joinpath(dir, "equities.bin")
    order_path = joinpath(dir, "order.bin")

    equities_io = open(equities_path, "w+")

    function element(index::Int64)
        return arr[index]
    end

    function remove(
        arr::Vector{UInt64},
        target::Vector{UInt64},
        elements::Vector{UInt64},
    )
        #initialize
        m = searchsortedfirst(target, element[1])
        for i in 1:m-1
            arr[i] = target[i]
        end

        l = m + 1
        for e in elements
            m = searchsortedfirst(target, e)
            for i in 1:m-1
                arr[i - 1] = target[i]
            end
            l = m + 1
        end
    end

    # arr = Vector{Int16}(undef, cols)
    # perms = Vector{Int64}([i for 1:cols], cols)

    equities = Mmap.mmap(
        equities_io,
        Matrix{Float64},
        (rows, cols))

    cat_arr = Vector{UInt64}(undef, max_hand_cards)
    ch_arr = Vector{UInt64}(undef, nc - num_chance_cards)
    pr_arr = Vector{UInt64}(undef, nc - num_chance_cards - num_ch)

    high = lookup.MAX_HIGH_CARD

    println("Computing ", round_name, " equities...")

    num_board = num_hand_cards - 2
    num_chance_cards = max_hand_cards - num_hand_cards

    nc = length(cards)

    rows = binomial(nc, num_chance_cards)
    cols = binomial(nc - num_chance_cards,
        2) * binomial(nc - (num_chance_cards - 2), num_board)

    progress = Progress(rows * cols)

    if num_chance_cards != 0
        for (m, chance) in enumerate(subsets(cards, num_chance_cards))
            diff1 = setdiff(cards, chance)
            n = 1
            for private in subsets(diff1, 2)
                for board in subsets(setdiff(diff1, private), num_board))
                    #  rank = Int16(evaluate(
                    #     hand,
                    #     concatenate(cat_arr, private, board, chance),
                    #     lookup_tables
                    # ))
                    equities[m, n] = (high - Int16(evaluate(
                       hand,
                       concatenate(cat_arr, private, board, chance),
                       lookup_tables)))/high
                   n += 1
                   next!(progress)
                end
            end
        end
    else
        for private in subsets(cards, 2)
            for board in subsets(setdiff(diff1, private), num_board))
                #  rank = Int16(evaluate(
                #     hand,
                #     concatenate(cat_arr, private, board, chance),
                #     lookup_tables
                # ))
                equities[1, n] = (high - Int16(evaluate(
                   hand,
                   concatenate(cat_arr, private, board),
                   lookup_tables)))/high
               n += 1
               next!(progress)
            end
        end
    end
    # sort!(perms, by=element)


    #number of times the hand wins
    # @showprogress for j in 1:cols
    #     # rank = equities[j]
    #     equities[j] = (high-equities[j])/high
    # end

    # leap = (c - 1) * cols
    # #write to matrix
    # # equities[leap + i:cols + leap] = copy(arr)
    # for k in 1:cols
    #     equities[1, leap + k] = arr[k]
    #     perms[k] = k
    # end
end

struct Round
    name::String
end

function create_round(
    round_name::String,
    dir::String,
    hand_size::Int64)
end

#fist step of the algorithm (create initial clusters)
function initialize(
    lookup_tables::LookupTables,
    cards::Vector{UInt64},
    num_hand_cards::Int64,
    num_clusters::Int64,
    dir::String,
)

    dir = joinpath(dir, round_name)

    try
        mkdir(dir)
    catch
    end

    println("Pre-computing ", round_name, " ranks")

    # equities_path = joinpath(dir, "equities.bin")
    #
    # equities_io = open(equities_path, "w+")
    #
    # equities = Mmap.mmap(
    #     equities_io,
    #     Matrix{Float64},
    #     (rows, cols))
    equities = mem_map(dir, "equities.bin", "w+", Matrix{Float64}, (rows, cols))

    cat_arr = Vector{UInt64}(undef, max_hand_cards)

    num_board = num_hand_cards - 2
    num_chance_cards = max_hand_cards - num_hand_cards

    nc = length(cards)

    sz = binomial(nc - num_board, 2)
    cols = binomial(nc - num_board, 2) * binomial(nc, num_board)
    arr = Vector{Float64}(undef, sz)
    sorted = Vector{Float64}(undef, sz)
    perms = Vector{UInt32}([i for i in 1:sz], sz)

    function element(index::Int64)
        return arr[index]
    end

    println("Computing ", round_name, " equities...")
    @showprogress for (c, board) in enumerate(subsets(cards, num_board)))
        i = 1
        for private in subsets(setdiff(cards, private), 2)
            rank = Int16(evaluate(concatenate(cat_arr, private, board), lookup_tables))
            arr[i] = rank
            sorted[i] = rank
            i += 1
        end
        sort!(perms, by=element)
        sort!(sorted)

        #compute equity
        for j in 1:sz
            p = perms[j]
            rn = searchsorted(sorted, arr[p])
            tied = (last(rn) - rn[1])
            wins = sz - j
            arr[p] =  (wins + tied/2)/(tied + wins + j - 1)
        end

        leap = (c - 1) * cols
        for k in 1:sz
            equities.arr[1, leap + k] = arr[k]
            perms[k] = k
        end
    end
    return kmeans(dir, equities, num_clusters)
end

function compress_game(
    lookup_tables::LookupTables,
    cards::Vector{UInt64},
    num_clusters::Int64,
    dir::AbstractString,
)

    #initial clusters
    #river
    println("Compressing river...")
    c1 = initialize(
        lookup_tables,
        cards, 7, num_clusters,
        joinpath(dir, "river"))

    println("Compressing turn...")
    compress_round(
        c1, lookup_tables,
        cards, 6, num_clusters,
        joinpath(dir, "turn"))

    println("Compressing flop...")
    compress_round(
        c1, lookup_tables,
        cards, 5, num_clusters,
        joinpath(dir, "flop"))

end

function compress_round(
    kmeans_result::Clustering.KmeansResult,
    lookup_tables::lookup.LookupTables,
    cards::Vector{UInt64},
    hand_size::Int64,
    num_clusters::Int64,
)
    println("Pre-computing ", round_name, " ranks")
    equities = mem_map(dir, "equities.bin", "w+", Matrix{Float64}, (rows, cols))

    cat_arr = Vector{UInt64}(undef, max_hand_cards)

    num_board = num_hand_cards - 2
    num_chance_cards = max_hand_cards - num_hand_cards

    nc = length(cards)

    hd = binomial(nc - num_board, 2)
    sz = hd * binomial(nc - num_board - num_chance_cards, num_chance_cards)
    cols = binomial(nc - num_board, 2) * binomial(nc, num_board)
    arr = Vector{Float32}(undef, sz)
    sorted = Vector{Float32}(undef, sz)
    perms = Vector{UInt32}([i for i in 1:sz], sz)
    dst = Vector{Float32}(undef, num_clusters)
    #histogram array
    hist = zeros(Float32, num_clusters)

    function element(index::Int64)
        return arr[index]
    end

    rdc = hd - 2

    println("Computing ", round_name, " equities...")
    @showprogress for (c, board) in enumerate(subsets(cards, num_board)))
        i = 1
        diff1 = setdiff(cards, private)
        for private in subsets(diff1, 2)
            for chance in subsets(setdiff(diff1, private), num_chance_cards)
                rank = Int16(evaluate(concatenate(cat_arr, private, board, chance), lookup_tables))
                arr[i] = rank
                sorted[i] = rank
                i += 1
            end
        end

        sort!(perms, by=element)
        sort!(sorted)

        #compute equity
        for j in 1:sz
            p = perms[j]
            rng = searchsorted(sorted, arr[p])
            tied = (last(rng) - rng[1])
            wins = sz - j
            arr[p] =  (wins + tied/2)/(tied + wins + j - 1)
        end

        #compute histogram
        for e in arr
            for (k, c) in enumerate(kmeans_result.centers)
                dst[k] = abs(e - c)
            end
            hist[argmin(dst)] += 1 / rdc
        end


    #todo need distance (EMD)
    return kmeans(hist, num_clusters)
end
