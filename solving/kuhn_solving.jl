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

#todo: compute for the case where the last round was not reached! (one player folded)

@inline function solving.computeutility!(
    ::Type{F},
    gs::KUHNGameState{FullSolving}, 
    pl::T) where {T<:Integer, F<:AbstractFloat}
    
    data = game!(gs)

    mpc = data.private_cards[pl]
    opp = data.private_cards[(pl == 1) * 2 + (pl != 1) * 1]

    # folded = gs.players_states[pl] == false
    # opp_folded = gs.players_states[(pl==2)*1 + (pl==1)*2] == false

    # # if folded == false
    # #     if opp < mpc
    # #         return gs.pot
    # #     elseif opp > mpc
    # #         return bet
    # #     end
    # # else
    # #     return -bet
    
    # # end
    # util = F(0)

    # if opp_folded || opp < mpc
    #     util = gs.pot
    # elseif folded || opp > mpc
    #     util = -gs.pot
    # end

    # # return util

    # # util = !folded * ((opp < mpc) * gs.pot + (opp_folded * gs.pot - !opp_folded * (opp > mpc) * gs.pot)) - folded * gs.pot
    # println("UTIL! ", util, " ", mpc, " ", opp, " ", gs.pot, " ", bet, " ", folded)
    # # # # return _utility!(folded, opp, mpc, gs.pot, bet)
    # return util

    # folded = gs.players_states[pl] == false
    # opp_folded = gs.players_states[(pl==2)*1 + (pl==1)*2] == false
    
    # bet = gs.bets[pl]

    # if folded == false
    #     if opp < mpc
    #         return gs.pot
    #     elseif opp > mpc
    #         return bet
    #     end
    # else
    #     return -bet
    
    # end
    # util = F(0)

    # if opp < mpc || opp_folded
    #     util = gs.pot - bet
    # elseif opp > mpc || folded
    #     util = -gs.pot + bet
    # end

    # act1 = SVector{3, UInt8}(3, 3, 0) #CC
    # act2 = SVector{3, UInt8}(3, 1, 2) #CBB
    # act3 = SVector{3, UInt8}(1, 2, 0) #BB
    # act4 = SVector{3, UInt8}(1, 4, 0) #BC
    # act5 = SVector{3, UInt8}(3, 1, 4) 
    is_higher = opp < mpc

    if gs.action_sequence == SVector{3, UInt8}(3, 3, 0)
        if is_higher
            util = 1
        else
            util = -1
        end
    elseif gs.action_sequence == SVector{3, UInt8}(3, 1, 2)
        if is_higher
            util = 2
        else
            util = -2
        end
    elseif gs.action_sequence == SVector{3, UInt8}(1, 2, 0)
        if is_higher
            util =  2
        else
            util = -2
        end
    elseif gs.action_sequence == SVector{3, UInt8}(3, 1, 4)
        util = 1
    elseif gs.action_sequence == SVector{3, UInt8}(1, 4, 0)
        util = 1
    end

    # return util

    # util = F(0)

    # if opp < mpc
    #     util = pot
    # elseif opp > mpc
    #     util = -pot
    # end

    # util = !folded * ((opp < mpc) * gs.pot + (opp_folded * gs.pot - !opp_folded * (opp > mpc) * gs.pot)) - folded * gs.pot
    # println("UTIL! ", util, " ", mpc, " ", opp, " ", gs.pot, " Main ", folded, " Opponent ", opp_folded)
    # # # return _utility!(folded, opp, mpc, gs.pot, bet)
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

    mpc = deck[cha.p_idx] # main player private card
    opp = deck[cha.opp_idx] # opponent private card
    last_player = gs.player

    folded = gs.players_states[pl] == false
    opp_folded = gs.players_states[(pl==2)*1 + (pl==1)*2] == false
    
    bet = gs.bets[pl]

    # if folded == false
    #     if opp < mpc
    #         return gs.pot
    #     elseif opp > mpc
    #         return bet
    #     end
    # else
    #     return -bet
    
    # end
    # util = F(0)

    # if opp < mpc || opp_folded
    #     util = gs.pot - bet
    # elseif opp > mpc || folded
    #     util = -gs.pot + bet
    # end

    # act1 = SVector{3, UInt8}(3, 3, 0) #CC
    # act2 = SVector{3, UInt8}(3, 1, 2) #CBB
    # act3 = SVector{3, UInt8}(1, 2, 0) #BB
    # act4 = SVector{3, UInt8}(1, 4, 0) #BC
    # act5 = SVector{3, UInt8}(3, 1, 4) 
    is_higher = opp < mpc

    if gs.action_sequence == SVector{3, UInt8}(3, 3, 0)
        if is_higher
            util = 1
        else
            util = -1
        end
    elseif gs.action_sequence == SVector{3, UInt8}(3, 1, 2)
        if is_higher
            util = 2
        else
            util = -2
        end
    elseif gs.action_sequence == SVector{3, UInt8}(1, 2, 0)
        if is_higher
            util =  2
        else
            util = -2
        end
    elseif gs.action_sequence == SVector{3, UInt8}(3, 1, 4)
        if folded == true
            util = -1
        else
            util = 1
        end
    elseif gs.action_sequence == SVector{3, UInt8}(1, 4, 0)
        if folded == true
            util = -1
        else
            util = 1
        end
    end

    # return util

    # util = F(0)

    # if opp < mpc
    #     util = pot
    # elseif opp > mpc
    #     util = -pot
    # end

    # util = !folded * ((opp < mpc) * gs.pot + (opp_folded * gs.pot - !opp_folded * (opp > mpc) * gs.pot)) - folded * gs.pot
    # println("UTIL! ", util, " ", mpc, " ", opp, " ", gs.pot, " Main ", folded, " Opponent ", opp_folded)
    # # # return _utility!(folded, opp, mpc, gs.pot, bet)
    # println("UTIL! ", util, " ", mpc, " ", opp, " ", folded, " ", opp_folded)
    return util

end

@inline function infosets.infosetkey(gs::KUHNGameState, pl::Integer)
    return privatecards!(gs)[pl]
end

@inline function infosets.infosetkey(gs::KUHNGameState, cha::KUHNChanceAction)
    return deck!(gs)[cha.p_idx]
end

function printsubtree(h::History{Node{MVector{2, MVector{2, Float32}}}, UInt64, UInt8}, a::String)
    for (k, h1) in h.histories
        for (i, s) in h1.infosets
            println(a, k, " info ", i, " " , 
            s.cum_strategy[1]./sum(s.cum_strategy[1]), " ", 
            s.cum_strategy[2]./sum(s.cum_strategy[2]))
        end

        printsubtree(h1, a * string(k))

    end
end

function printtree(root_h::History{Node{MVector{2, MVector{2, Float32}}}, UInt64, UInt8})

    for (k, h) in root_h.histories
        for (i, s) in h.infosets
            println(k, " info ", i, " " , 
            s.cum_strategy[1]./sum(s.cum_strategy[1]), " ", 
            s.cum_strategy[2]./sum(s.cum_strategy[2]))
        end

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

    gs = KUHNGameState{FullSolving}(game)

    #create root history
    root_h = History(History{Node{MVector{2, MVector{2, Float32}}}, UInt64, UInt8})
    #to avoid looping over a changing array
    players = copy(game.players)

    n = 0
    
    init_probs = @SVector ones(Float32, 2)

    util = Float32(0)

    for i in itr
        pc = samplepair(deck)

        for i in eachindex(game.private_cards)
            game.private_cards[i] = pc[i]
        end

        for pl in players

            util += cfr.solve(
                solver, 
                gs, 
                root_h,
                pl,
                init_probs)

        end

        # println("Rotate! ")
        gs = rotateplayers!(gs)

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
    
    println("Average Utility ", util/n)
    
    printtree(root_h)

end

# function solvekuhn(solver::CFR, itr::IterationStyle)
#     game = KUHNGame{MVector{3, UInt8}}(MVector{3, UInt8}(1, 2, 3))

#     #todo: we need to remove the distributed private cards from the deck!

#     gs = KUHNGameState{FullSolving}(game)

#     #create root history
#     root_h = History(History{Node{MVector{2, MVector{2, Float32}}}, UInt64, UInt8})
#     #to avoid looping over a changing array
#     players = copy(game.players)

#     n = 0
    
#     inc = initialchanceaction(UInt8, gs)
#     init_probs = @SVector ones(Float32, 3)

#     util = Float32(0)

#     for i in itr
#         for pl in players

#             util += cfr.solve(
#                 solver, 
#                 gs, 
#                 root_h,
#                 inc, 
#                 pl,
#                 init_probs)

#         end

#         # println("Rotate! ")
#         gs = rotateplayers!(gs)

#         n += 1

#         # # compute and display exploitability each 10 iterations

#         # println(
#         #     "Exploitability ", 
#         #     computeexploitability!(Float32, gs, root_h, inc)/2, 
#         #     " Milli Big Blind")

#     end

#     println(
#         "Final Exploitability ", 
#         computeexploitability!(Float32, gs, root_h, inc)/6, 
#         " Milli Big Blind")
    
#     println("Average Utility ", util/n)
    
#     printtree(root_h)

# end

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

    for i in itr
        for pl in players

            util += cfrplus.solve(
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

    println(
        "Final Exploitability ", 
        computeexploitability!(Float32, gs, root_h, inc)/6, 
        " Milli Big Blind")
    
    println("Average Utility ", util/n)
    
    printtree(root_h)

end

# function solvekuhn(solver::MCCFR{T}, itr::IterationStyle)
#     deck = getdeck(Vector{UInt8})

#     game = KUHNGame{Vector{UInt8}}(getcompresseddeck(Vector{UInt8}))

#     #todo: we need to remove the distributed private cards from the deck!

#     gs = KUHNGameState{FullTraining}(game)

#     h = history(History{typeof(gs), MVector{4, T}, T, 13}, gs)()


# end