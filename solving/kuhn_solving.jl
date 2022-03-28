push!(LOAD_PATH, join([pwd(), "utils"], "/"))
push!(LOAD_PATH, join([pwd(), "games"], "/"))
push!(LOAD_PATH, join([pwd(), "solving"], "/"))
push!(LOAD_PATH, join([pwd(), "games/kuhn"], "/"))

using StatsBase
using StaticArrays
using FunctionWrappers

using BenchmarkTools
using TimerOutputs

using Random
using StatsBase

using kuhn
using games
using solving
using cfrplus
using cfr
using mccfr
using infosets
using exploitability
using iterationstyles
using bestresponse
using simulation

@inline function solving.computeutility!(
    ::Type{F},
    h::H,
    gs::KUHNGameState{DepthLimited},
    pl::T) where {}

    stp = setup(gs)

    # todo: randomly select a bias in the depth limited
    bias = selectrandom(stp.biases)

    vals = @SVector zeros(F, 2)

    # run a simulation for a certain amount of iterations to get an approximation
    # of the value a depth limited game.

    for _ in 1:stp.iterations
        vals += simulate(h, gs, pl, bias)
    end

    return vals/stp.iterations

end

@inline function solving.computeutility!(
    ::Type{F},
    gs::KUHNGameState{FullSolving}, 
    pl::T) where {T<:Integer, F<:AbstractFloat}
    
    data = game!(gs)

    mpc = data.private_cards[1]
    opp = data.private_cards[2]

    winnings = minimum(gs.bets)

    pot = gs.bets

    if pot[1] > pot[2]
        util = SVector{2, F}(winnings, -winnings)
    elseif pot[1] < pot[2]
        util = SVector{2, F}(-winnings, winnings)
    elseif opp < mpc
        util = SVector{2, F}(winnings, -winnings)
    elseif opp > mpc
        util = SVector{2, F}(-winnings, winnings)
    end

    # println(util, " ", mpc, " ", opp, " ", winnings, " ", pl, " ", opp_pl)

    return util

end

function _utility!(folded::Bool, opp::I, mpc::I, pot::K, bet::K) where {I<:Integer, K<:AbstractFloat}
    if folded == false
        if opp < mpc
            return pot
        elseif opp > mpc
            return bet
        end
    else
        return -bet
    end
    # return !folded * ((opp < mpc) * pot - (opp > mpc) * bet + (opp == mpc) * Float32(pot/2)) - folded * bet
end

# const f1 = FunctionWrappers.FunctionWrapper{Float32, Tuple{Bool, UInt8, UInt8, UInt8, UInt8}}(_utility!)

function solving.computeutility!(
    ::Type{F},
    gs::KUHNGameState,
    pl::T,
    cha::KUHNChanceAction) where {T<:Integer, F<:AbstractFloat}

    deck = deck!(gs)

    # opp_pl = (pl==2)*1 + (pl==1)*2

    mpc = deck[cha.arr[1]] # main player private card
    opp = deck[cha.arr[2]] # opponent private card
    last_player = gs.player

    # folded = gs.players_states[pl] == false
    # opp_folded = gs.players_states[(pl==2)*1 + (pl==1)*2] == false
    
    # bet = gs.bets[pl]

    winnings = minimum(gs.bets)

    # println(winnings)

    pot = gs.bets

    if pot[1] > pot[2]
        util = SVector{2, F}(winnings, -winnings)
    elseif pot[1] < pot[2]
        util = SVector{2, F}(-winnings, winnings)
    elseif opp < mpc
        util = SVector{2, F}(winnings, -winnings)
    elseif opp > mpc
        util = SVector{2, F}(-winnings, winnings)
    end

    # println(util, " ", mpc, " ", opp, " ", winnings, " ", pl, " ", opp_pl)

    return util

end

@inline function infosets.infosetkey(gs::KUHNGameState, pl::Integer)
    return privatecards!(gs)[pl]
end

@inline function infosets.infosetkey(gs::KUHNGameState, cha::KUHNChanceAction)
    return deck!(gs)[cha.arr[gs.player]]
end

function printsubtree(h::History{Node{MVector{2, MVector{2, T}}}, UInt64, UInt8}, a::String) where T <: AbstractFloat
    for (i, s) in h.infosets
        println("info ", i, " action ", a, " " , 
        s.cum_strategy[1]./sum(s.cum_strategy[1]), " ", 
        s.cum_strategy[2]./sum(s.cum_strategy[2]))
    end

    for (k, h1) in h.histories
        printsubtree(h1, a * string(k))
    end
end

function printtree(root_h::History{Node{MVector{2, MVector{2, T}}}, UInt64, UInt8}) where T <: AbstractFloat
    for (i, s) in root_h.infosets
        println("info ", i, " " , 
        s.cum_strategy[1]./sum(s.cum_strategy[1]), " ", 
        s.cum_strategy[2]./sum(s.cum_strategy[2]))
    end

    for (k, h) in root_h.histories
        printsubtree(h, string(k))
    end
end

# function solvekuhn(solve::CFR, itr::IterationStyle)
#     game = KUHNGame
# end

function solvekuhn(solver::CFR, itr::IterationStyle)
    deck = MVector{3, UInt8}(1, 2, 3)
    
    game = KUHNGame{MVector{3, UInt8}}(MVector{3, UInt8}(1, 2, 3))

    #todo: we need to remove the distributed private cards from the deck!

    gs = performchance!(KUHNGameState{FullSolving}(game))

    #create root history
    root_h = History(History{Node{MVector{2, MVector{2, Float32}}}, UInt64, UInt8})
    root_brh = BRHistory(History{Node{MVector{2, MVector{2, Float32}}}, UInt64, UInt8})
    #to avoid looping over a changing array
    players = copy(game.players)

    n = 0
    
    init_probs = @SVector ones(Float32, 2)

    util = Float32(0)
    utils = @SVector zeros(Float32, 2)

    k = 1
    j = 2

    for i in itr

        game.private_cards[1] = deck[k]
        game.private_cards[2] = deck[j]

        # for i in eachindex(game.private_cards)
        #     game.private_cards[i] = pc[i]
        # end

        j += 1
        j = (j == k) * (j + 1) + (j != k) * j

        if j > 3
            k += 1
            j = 1
        end
        
        if k > 3
            k = 1
            j = 2
        end

        # pc = samplepair(deck)

        # for pl in players

            utils += cfr.solve(
                solver, 
                gs, 
                root_h,
                players[1],
                init_probs)

            n += 1

        # end

    end

    k = 1
    j = 2

    expl = 0

    for i in 1:6

        game.private_cards[1] = deck[k]
        game.private_cards[2] = deck[j]

        j += 1
        j = (j == k) * (j + 1) + (j != k) * j

        if j > 3
            k += 1
            j = 1
        end
        
        if k > 3
            k = 1
            j = 2
        end

        for pl in players!(gs)
            bestresponse!(gs, root_h, root_brh, pl, init_probs)
        end

    end

    for i in 1:6

        game.private_cards[1] = deck[k]
        game.private_cards[2] = deck[j]

        j += 1
        j = (j == k) * (j + 1) + (j != k) * j

        if j > 3
            k += 1
            j = 1
        end
        
        if k > 3
            k = 1
            j = 2
        end

        ev1 = computeexploitability!(Float32, gs, root_h, root_brh, 2)
        ev2 = computeexploitability!(Float32, gs, root_h, root_brh, 1)

        expl += 1/6 * (ev1 - ev2)

    end

    println(
        "Final Exploitability ", 
        expl, 
        " Milli Big Blind")
    println("Average Utility ", utils/n)
    
    printtree(root_h)

end

function solvekuhn(solver::CFRPlus{true}, itr::IterationStyle)
    game = KUHNGame{MVector{3, UInt8}}(MVector{3, UInt8}(1, 2, 3))

    #todo: we need to remove the distributed private cards from the deck!

    gs = KUHNGameState{FullSolving}(game)

    #create root history
    root_h = History(History{Node{MVector{2, MVector{2, Float32}}}, UInt64, UInt8})
    #to avoid looping over a changing array
    players = copy(game.players)

    n = 0
    
    inc = initialchanceaction(UInt8, gs)
    init_probs = @SVector ones(Float32, 3)

    util = Float32(0)
    utils = @MVector zeros(Float32, 2)

    for i in itr
        for pl in players
            utils[pl] += cfrplus.solve(
                solver, 
                gs, 
                root_h,
                inc, 
                pl,
                init_probs, i)
        end

        # gs = rotateplayers!(gs)

        n += 1

        # # compute and display exploitability each 10 iterations

        # println(
        #     "Exploitability ", 
        #     computeexploitability!(Float32, gs, root_h, inc)/2, 
        #     " Milli Big Blind")

    end

    # println(
    #     "Final Exploitability ", 
    #     computeexploitability!(Float32, gs, root_h, inc)/6, 
    #     " Milli Big Blind")
    
    println("Average Utility ", utils/n)
    
    printtree(root_h)

end

# function solvekuhn(solver::MCCFR{T}, itr::IterationStyle)
#     deck = getdeck(Vector{UInt8})

#     game = KUHNGame{Vector{UInt8}}(getcompresseddeck(Vector{UInt8}))

#     #todo: we need to remove the distributed private cards from the deck!

#     gs = KUHNGameState{FullTraining}(game)

#     h = history(History{typeof(gs), MVector{4, T}, T, 13}, gs)()


# end