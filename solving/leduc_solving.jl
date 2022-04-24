push!(LOAD_PATH, join([pwd(), "utils"], "/"))
push!(LOAD_PATH, join([pwd(), "games"], "/"))
push!(LOAD_PATH, join([pwd(), "solving"], "/"))

using IterTools
using StaticArrays
using Plots

using solving
using cfrplus
using mccfr
using cfr
using infosets
using games
using leduc
using unionfind
using dataindex
using iterationstyles

const SMoney = UInt8(100)

struct LeDucFullSolving{T} <: GameSetup
    index::Index{T}
end

struct LeDucPublicTree{T<:Integer, U<:Integer}
    n::T
    chance_action::LeDucChanceAction{U}
end

@inline function games.chanceactions!(gs::LeDucGameState{S}, a::LeDucChanceAction{T}) where {T<:Integer, S<:GameSetup}
    #todo, we need to read part of the tree that is in the next round
    return LeDucPublicTree(length(a.index.indices), a)
end

LeDucFullSolving(index::Index{T}) where T <: Integer = LeDucFullSolving{T}(index)

function Base.iterate(pt::LeDucPublicTree{T, U}) where {T<:Integer, U<:Integer}
    index = pt.chance_action.index
    ind = indice!(index, 1)
    return (LeDucChanceAction{U}(ind[3], ind, index!(index, 1)), 1)
end

function Base.iterate(pt::LeDucPublicTree{T, U}, idx::Int64) where {T<:Integer, U<:Integer}    

    index = pt.chance_action.index

    idx += 1

    if idx > pt.n
        return nothing
    end

    #retrieve cards index
    ind = indice!(index, idx)

    return (LeDucChanceAction{U}(ind[3], ind, index!(index, idx)), idx)

end

@inline function games.chanceprobability!(::Type{T}, gs::LeDucGameState{S}, a::LeDucChanceAction{U}) where {S<:GameSetup, U<:Integer, T<:AbstractFloat}
    return T(1/length(a.index.indices))
end

function createindex(deck::T) where T<:AbstractVector

    idx = collect(UInt8, 1:length(deck))

    #todo create a tuple of 3 elements and use union find to compress.
    round1 = UnionFind(UInt8, length(deck) * (length(deck) - 1))

    #todo: use ranks instead of the cards

    root = Index(SVector{3, UInt8})

    private_cards = Vector{Tuple{UInt8, UInt8, UInt8}}()
    public_cards = Vector{Tuple{UInt8, UInt8, UInt8}}()

    #private cards

    for i in 1:length(deck)
        for j in 1:length(deck)
            if i != j 
                push!(private_cards, (i, j, 0))
            end
        end
    end

    #compress private cards

    for i in 1:length(private_cards) - 1
        for j in i+1:length(private_cards)
            if (deck[private_cards[i][1]], deck[private_cards[i][2]]) == (deck[private_cards[j][1]], deck[private_cards[j][2]])
                union(round1, i, j)
            end
        end
    end

    pbl_idx = Vector{Vector{UInt8}}()

    # for community cards, given a pair of private cards, get a public card.
    p = 1

    for i in 1:length(deck) * (length(deck) - 1)
        # todo: should we use compressed cards? 

        pair = private_cards[i]

        vec = Vector{UInt8}()
        
        push!(pbl_idx, vec)

        for c in setdiff(idx, pair)
            push!(public_cards, (pair[1], pair[2], c))
            push!(vec, p)
            
            p += 1
        end
    end

    round2 = UnionFind(UInt8, length(deck) * (length(deck) - 1) * (length(deck) - 2))

    #compress public cards

    for i in 1:length(public_cards) - 1
        idx = public_cards[i]
        hand = (deck[idx[1]], deck[idx[2]], deck[idx[3]])
        
        for j in i+1:length(public_cards)
            idx2 = public_cards[j]
            
            if hand == (deck[idx2[1]], deck[idx2[2]], deck[idx2[3]])
                union(round2, i, j)
            end
        end
    end


    #compress private to public array mapping

    for i in 1:length(deck) * (length(deck) - 1)

        vec = pbl_idx[i]

        for i in 1:length(vec)
            vec[i] = find(round2, vec[i])
        end

    end


    # transfer everything to index struct

    for i in sort!(collect(Set(round1.id)))

        idx1 = private_cards[i]

        pair = (idx1[1], idx1[2], 0)

        push!(root.indices, pair)

        child = LeafIndex(SVector{3, UInt8})
        
        push!(root.children, child)

        for v in sort!(collect(Set(pbl_idx[i])))
            idx = public_cards[v]

            push!(child.indices, (idx[1], idx[2], idx[3]))
        end

    end

    return root

end

function printsubtree(h::History{Node{MVector{2, MVector{N, T}}}, I, J}, a::String) where {N, T<:AbstractFloat, I<:Integer, J<:Integer}
    for (i, s) in h.infosets
        println("info ", i, " action ", a, " " , 
        s.cum_strategy[1]./sum(s.cum_strategy[1]), " ", 
        s.cum_strategy[2]./sum(s.cum_strategy[2]))
    end

    for (k, h1) in h.histories
        printsubtree(h1, a * string(k))
    end
end

function printtree(root_h::History{Node{MVector{2, MVector{N, T}}}, I, J}) where {N, T<:AbstractFloat, I<:Integer, J<:Integer}
    for (i, s) in root_h.infosets
        println("info ", i, " " , 
        s.cum_strategy[1]./sum(s.cum_strategy[1]), " ", 
        s.cum_strategy[2]./sum(s.cum_strategy[2]))
    end

    for (k, h) in root_h.histories
        printsubtree(h, string(k))
    end
end

@inline function infosets.infosetkey(gs::LeDucGameState, cha::LeDucChanceAction)
    pub = cha.cards_idx[3]

    if pub != 0
        return deck!(gs)[cha.cards_idx[gs.player]] * 10 + deck!(gs)[pub]
    end

    return deck!(gs)[cha.cards_idx[gs.player]]
end

#todo: compute for the case where the last round was not reached! (one player folded)

@inline function solving.computeutility!(
    ::Type{F},
    gs::LeDucGameState{LeDucFullSolving{V}}, 
    pl::T,
    cha::LeDucChanceAction{T}) where {T<:Integer, F<:AbstractFloat, V<:StaticVector}
    
    deck = deck!(gs)

    mpc = deck[cha.cards_idx[1]] # p1 private card
    opp = deck[cha.cards_idx[2]] # p2 private card

    # if (mpc - 1) % 10 == 0
    #     mpc = (mpc - 1) / 10
    # else
    #     mpc = (mpc - 2) / 10
    # end

    # if (opp - 1) % 10 == 0
    #     opp = (opp - 1) / 10
    # else
    #     opp = (opp - 2) / 10
    # end    

    reached = cha.cards_idx[3] != 0

    pub = 0

    if reached
        pub = deck[cha.cards_idx[3]] # public card
    end

    states = gs.players_states

    money = gs.money
    pot = gs.pot

    # println("Pot ", gs.pot, " States ", states)
    if states[2] == false
        # println("Player Two Folded! ", mpc, " ", opp, " ", pub, " ", states)
        return SVector{2, F}(F(gs.bets[2]), -F(gs.bets[2]))
    elseif states[1] == false
        # println("Player One Folded! ", mpc, " ", opp, " ", pub, " ", states)
        return SVector{2, F}(-F(gs.bets[1]), F(gs.bets[1]))
    elseif mpc == pub
        # println("Player One Won! ", mpc, " ", opp, " ", pub, " ", states)
        return SVector{2, F}(F(gs.bets[2]), -F(gs.bets[2]))
    elseif opp == pub
        return SVector{2, F}(-F(gs.bets[1]), F(gs.bets[1]))
    elseif mpc > opp
        # println("Player One Won! ", mpc, " ", opp, " ", pub, " ", states)
        return SVector{2, F}(F(gs.bets[2]), -F(gs.bets[2]))
    elseif opp > mpc
        # println("Player Two Won! ", mpc, " ", opp, " ", pub, " ", states)
        return SVector{2, F}(-F(gs.bets[1]), F(gs.bets[1]))
    elseif (mpc == opp)
        # println("Tie! ", mpc, " ", opp, " ", pub, " ", states)
        return SVector{2, F}(0, 0)
    end

    # if (mpc == pub || mpc > opp || states[2] == false)
    #     # println("Player One Won! ", mpc, " ", opp, " ", pub)
    #     return SVector{2, F}(F(gs.bets[2]), -F(gs.bets[2]))
    # elseif (opp == pub || opp > mpc || states[1] == false)
    #     # println("Player Two Won! ", mpc, " ", opp, " ", pub)
    #     return SVector{2, F}(-F(gs.bets[1]), F(gs.bets[1]))
    # elseif (mpc == opp)
    #     # println("Tie! ", mpc, " ", opp, " ", pub)
    #     return SVector{2, F}(F(gs.bets[1]/2), F(gs.bets[1]/2))
    # end
    

end

# @inline function solving.computeutility!(
#     ::Type{F},
#     h::H,
#     gs::LeDucGameState{DepthLimited},
#     pl::T) where {F}

#     stp = setup(gs)

#     # todo: randomly select a bias in the depth limited
#     bias = selectrandom(stp.biases)

#     vals = @SVector zeros(F, 2)

#     # run a simulation for a certain amount of iterations to get an approximation
#     # of the value a depth limited game.

#     for _ in 1:stp.iterations
#         vals += simulate(h, gs, pl, bias)
#     end

#     return vals/stp.iterations

# end

function solveleduc(solver::CFR, itr::IterationStyle)
    setup = LeDucFullSolving(createindex(UInt8[1, 1, 2, 2, 3, 3]))

    game = LeDucGame(UInt8, UInt8[1, 1, 2, 2, 3, 3])

    root_h = History(History{Node{MVector{2, MVector{3, Float32}}}, UInt64, UInt8})

    root_gs = placebets(LeDucGameState(game, setup), SVector{2, UInt8}(1, 1))

    #initial chance action
    inc = LeDucChanceAction(
        UInt8(0), 
        SVector{3, UInt8}(0, 0, 0), 
        setup.index)

    utils = @SVector zeros(Float32, 2)
    init_probs = @SVector ones(Float32, 3)

    n = 0

    points = Vector{Float32}()

    for _ in itr
        for pl in game.players
            ut = cfr.solve(
                solver, 
                root_gs, 
                root_h, 
                inc,
                pl,
                init_probs)
                
            utils += ut

            push!(points, ut[1])

            n += 1
        end
    end

    println("Average Utility ", utils/n)

    # x = 1:length(points)
    
    # plot(x, points)
    
    # printtree(root_h)
    
end



# end