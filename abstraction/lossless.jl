include("../games/evaluation/evaluator.jl")
include("../games/evaluation/lookup.jl")
include("../games/cards.jl")

using .evaluator
using .lookup
using .cards
using IterTools
using JuMP
using LightGraphs
using Clp
using LightGraphsMatching

function compress_hands(
    hands::Vector{Vector{UInt64}},
    idx_array::Vector{UInt64})
    dct = Dict{UInt64,UInt64}()
    compressed = Vector{Vector{UInt64}}()
    for idx in idx_array
        h_idx = find_hand(idx, idx_array)
        if !haskey(dct, h_idx)
            dct[h_idx] = h_idx
            append!(compressed, [hands[h_idx]])
        end
    end
    return compressed
end

function find_hand(
    hand::UInt64,
    forest::Vector{UInt64})

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
    sizes::Vector{UInt64})

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

function compression_loop(
    combos::Vector{Vector{UInt64}},
    round::Int64,
    optimizer::OptimizerFactory)
    i::UInt64 = 1
    j::UInt64 = 2
    t = 0
    N = length(combos)
    idx_array = Vector{UInt64}([i for i in 1:N])
    sizes = Vector{UInt64}([1 for i in 1:N])
    ct = N

    sz = 1
    println("Start compressing ")
    while i < N
        while j < N
            u = combos[i]
            v = combos[j]

            if is_ordered_isomorphic(
                u, v, cards, 1,
                a, b, optimizer)
                ct += hand_union(i, j, idx_array, sizes)
            end
            t += 1
            if t % 100000 == 0
                println(100*ct/N," ", i, " ", j)
                println("Progress ", 100*i/N)
            end
            j += 1
        end
        # println("Next Iteration")
        i += 1
        j = i + 1
    end
end


function five_hand_compression(
    forest::Vector{Vector{UInt64}},
    flush_lookup::Dict{UInt64, UInt64},
    unsuited_lookup::Dict{UInt64, UInt64})

    N = length(forest)
    ct = N
    utilities::Vector{UInt64} = [
        evaluate(c, flush_lookup, unsuited_lookup)
        for c in forest]

    # sort!(utilities)

    idx_array::Vector{UInt64} = [i for i in 1:N]
    sizes::Vector{UInt64} = [1 for i in 1:N]

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

function turn_compression(
    cards::Vector{UInt64},
    hands::Vector{Vector{UInt64}},
    flush_lkp::Dict{UInt64, UInt64},
    unsuited_lkp::Dict{UInt64, UInt64})

    N = length(hands)
    t = 0
    ct = N
    idx_array = Vector{UInt64}([i for i in 1:N])
    sizes = Vector{UInt64}([1 for i in 1:N])
    sort!(arr)

    i::UInt64 = 1
    j::UInt64 = 2

    while j < N + 1
        # problem: in a compressed array, u and v are always different
        broke::Bool = false
        h1 = hands[i]
        h2 = hands[j]
        diffr = setdiff(cards, union(h1, h2))

        hands1 = Vector{UInt64}([
            evaluate(vcat(c,h1), flush_lkp, unsuited_lkp)
            for c in diffr])
        hands2 = Vector{UInt64}([
            evaluate(vcat(c,h2), flush_lkp, unsuited_lkp)
                for c in diffr])

        sort!(hands1)
        sort!(hands2)

        k::UInt64 = 1

        while k < length(hands1) + 1
            if hands1[k] != hands2[k]
                broke = true
                break
            end
            k += 1
        end
        if !broke
            ct += hand_union(
                idx_array[i],
                idx_array[j],
                idx_array,
                sizes)
        end
        i += 1
        j += 1
        t += 1

        if t % 10000 == 0
            prog = 100 * t/N
            println("Progress ", prog)
            println("Compressed ", 100*ct/N)
        end
    end
    println("Compressed to ", 100*ct/N)
end

function flop_compression(
    cards::Vector{UInt64},
    hands::Vector{Vector{UInt64}},
    flush_lkp::Dict{UInt64, UInt64},
    unsuited_lkp::Dict{UInt64, UInt64})

    arr = Vector{UInt64}(
        [evaluate(hand, flush_lkp, unsuited_lkp)
            for hand in hands])

    N = length(arr)
    t = 0
    ct = N
    idx_array = Vector{UInt64}([i for i in 1:N])
    sizes = Vector{UInt64}([1 for i in 1:N])
    sort!(arr)

    i::UInt64 = 1
    j::UInt64 = 2

    while j < N + 1
        u = arr[i]
        v = arr[j]
        # problem: in a compressed array, u and v are always different
        if u == v
            h1 = hands[i]
            h2 = hands[j]
            diffr = setdiff(cards, union(h1, h2))

            ut1 = Vector{UInt64}([
                evaluate(vcat(c,h1), flush_lkp, unsuited_lkp)
                for c in diffr])
            ut2 = Vector{UInt64}([
                evaluate(vcat(c,h2), flush_lkp, unsuited_lkp)
                    for c in diffr])

            sort!(ut1)
            sort!(ut2)

            for c in diffr
                h11 = vcat(c, h1)
                h22 = vcat(c, h2)

                l::UInt64 = 1
                broke::Bool = false

                if evaluate(h11, flush_lkp, unsuited_lkp) == evaluate(
                    h22, flush_lkp, unsuited_lkp)

                    diffr2 = setdiff(cards, union(h11, h22))
                    ut11 = Vector{UInt64}(
                        [evaluate(vcat(i, h11), flush_lkp, unsuited_lkp)
                            for i in diffr2])
                    ut22 = Vector{UInt64}(
                        [evaluate(vcat(i, h22), flush_lkp, unsuited_lkp)
                            for i in diffr2])

                    while l < length(ut11) + 1
                        if ut11[l] != ut22[l]
                            broke = true
                            break
                        end
                        l += 1
                    end

                    if !broke
                        ct += hand_union(
                            idx_array[i],
                            idx_array[j],
                            idx_array,
                            sizes)
                    end
                end
            end
        end
        i += 1
        j += 1
        t += 1
        if t % 1000 == 0
            prog = 100 * t/N
            println("Progress ", prog)
            println("Compressed ", 100*ct/N)
        end
    end
    println("Compressed to ", 100*ct/N)
    return idx_array
    end

function is_ordered_isomorphic(
    u::Vector{UInt64},
    v::Vector{UInt64},
    cards::Vector{UInt64},
    round::Int64,
    flush_lkp::Dict{UInt64,UInt64},
    unsuited_lkp::Dict{UInt64, UInt64},
    optimizer::OptimizerFactory)
    if round == 1
        for c in setdiff(cards, union(u,v))
            if evaluate(vcat(c,u),flush_lkp, unsuited_lkp) != evaluate(
                vcat(c,v), flush_lkp, unsuited_lkp)
                #return if different
                return false
            end
        end
        return true
    else
        diffr = setdiff(cards, union(u,v))
        h1 = [vcat(i, u) for i in diffr]
        h2 = [vcat(j, v) for j in diffr]
        k = 1
        l = 2
        lh = length(h1)
        g = SimpleGraph(2*lh)
        round -= 1
        for i in 1:lh
            u1 = h1[i]
            v1 = h2[i]
            if is_ordered_isomorphic(
                u1,
                v1,
                cards,
                round,
                flush_lkp,
                unsuited_lkp,
                optimizer)
                add_edge!(g, k, l)
            end
            k += 2
            l += 2
        end
        result = maximum_weight_matching(g, optimizer)
        #if the result contains -1 then it is not a perfect match
        if in(-1, result.mate)
            return false
        end
        return true
    end
end


function compress()
    a, b = create_lookup_tables()
    cards = get_deck()

    function strength(hand::Vector{UInt64})
        evaluate(hand, a, b)
    end

    combos5=Vector{Vector{UInt64}}([c for c in subsets(cards, 5)])
    sort!(combos5, by=strength)

    #use compressed hands
    compressed = compress_hands(
        combos5,
        five_hand_compression(combos5, a, b))

    combos6 = Vector{Vector{UInt64}}([
        vcat(i,c)
        for c in compressed
            for i in setdiff(cards, c)])
    sort!(combos6, by=strength)

    optimizer = with_optimizer(Clp.Optimizer, LogLevel=0)

    i::UInt64 = 1
    j::UInt64 = 2
    t = 0
    N6 = length(combos6)
    idx_array = Vector{UInt64}([i for i in 1:N6])
    sizes = Vector{UInt64}([1 for i in 1:N6])
    ct = N6

    println("Start compressing ")
    while i < N6
        while j < N6
            u = combos6[i]
            v = combos6[j]

            if is_ordered_isomorphic(
                u, v, cards, 1,
                a, b, optimizer)
                ct += hand_union(i, j, idx_array, sizes)
            end
            t += 1
            if t % 100000 == 0
                println(100*ct/N6," ", i, " ", j)
                println("Progress ", 100*i/N6)
            end
            j += 1
        end
        # println("Next Iteration")
        i += 1
        j = i + 1
    end
end

function compress2()
    a, b = create_lookup_tables()
    cards = get_deck()
    subs = subsets(cards, 5)

    function strength(hand::Vector{UInt64})
        evaluate(hand, a, b)
    end

    #compress flop round

    println("Creating 5 combo array")

    combos5=Vector{Vector{UInt64}}([c for c in subs])
    sort!(combos5, by=strength)

    println("Done")

    i::UInt64 = 1
    j::UInt64 = 2
    t = 0
    N = length(combos5)
    optimizer = with_optimizer(Clp.Optimizer, LogLevel=0)
    while j < N + 1
        if is_ordered_isomorphic(
            combos5[i],
            combos5[j],
            cards,
            3,
            a,
            b,
            optimizer)
            # println("Match! ", combos5[i], combos5[j])
        end
        i += 1
        j += 1
        t += 1
        if t % 10 == 0
            println("Progress ", 100*t/N)
        end
    end
end

# @time compress()
