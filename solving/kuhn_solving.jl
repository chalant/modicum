push!(LOAD_PATH, join([pwd(), "utils"], "/"))
push!(LOAD_PATH, join([pwd(), "games"], "/"))
push!(LOAD_PATH, join([pwd(), "solving"], "/"))
push!(LOAD_PATH, join([pwd(), "games/kuhn"], "/"))

using StatsBase
using StaticArrays
using FunctionWrappers

using BenchmarkTools
using TimerOutputs

using kuhn
using games
using solving
using cfrplus
using mccfr
using infosets
using exploitability
using iterationstyles

#todo: compute for the case where the last round was not reached! (one player folded)

@inline function solving.computeutility!(
    gs::KUHNGameState{FullSolving}, 
    pl::T) where T <: Integer
    
    data = game!(gs)

    mpc = data.private_cards[pl]
    opp = data.private_cards[(pl == 1) * 2 + (pl != 1) * 1]

    folded = gs.players_states[pl] == false
    bet = gs.bets[pl]
    # return !folded * ((opp < mpc) * gs.pot - (opp > mpc) * (gs.pot - bet) + (opp == mpc) * gs.pot/2) + folded * bet

    util = !folded * ((opp < mpc) * gs.pot - (opp > mpc) * bet + (opp == mpc) * gs.pot/2) - folded * bet

    println("UTIL! ", util, " ", bet, " ", folded, " ", mpc, " ", opp, " ", gs.pot)

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

    folded = gs.players_states[pl] == false
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

    return !folded * ((opp < mpc) * gs.pot - (opp > mpc) * bet + (opp == mpc) * gs.pot/2) - folded * bet
    # println("UTIL! ", util, " ", mpc, " ", opp, " ", gs.pot, " ", bet)
    # # return _utility!(folded, opp, mpc, gs.pot, bet)
    # return util

end

@inline function infosets.infosetkey(gs::KUHNGameState, pl::Integer)
    return privatecards!(gs)[pl]
end

@inline function infosets.infosetkey(gs::KUHNGameState, cha::KUHNChanceAction)
    return deck!(gs)[cha.p_idx]
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

    for i in itr
        for pl in players

            util += solve(
                solver, 
                gs, 
                root_h,
                inc, 
                pl,
                init_probs, i)
            
            rotateplayers!(game)

        end

        n += 1

        # compute and display exploitability each 10 iterations

        # if n == 10000
        #     println(util)
        #     println(
        #         "Exploitability ", 
        #         computeexploitability!(Float32, gs, root_h, inc)/2, 
        #         " Milli Big Blind")

        #     n = 0
        # end

    end

    println(
        "Final Exploitability ", 
        computeexploitability!(Float32, gs, root_h, inc)/2, 
        " Milli Big Blind")
    
    println(util/n)

    # show(merge(T1, T2))

end

# function solvekuhn(solver::MCCFR{T}, itr::IterationStyle)
#     deck = getdeck(Vector{UInt8})

#     game = KUHNGame{Vector{UInt8}}(getcompresseddeck(Vector{UInt8}))

#     #todo: we need to remove the distributed private cards from the deck!

#     gs = KUHNGameState{FullTraining}(game)

#     h = history(History{typeof(gs), MVector{4, T}, T, 13}, gs)()


# end