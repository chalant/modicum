push!(LOAD_PATH, join([pwd(), "utils"], "/"))
push!(LOAD_PATH, join([pwd(), "games"], "/"))
push!(LOAD_PATH, join([pwd(), "solving"], "/"))
push!(LOAD_PATH, join([pwd(), "games/kuhn"], "/"))

using StatsBase
using StaticArrays

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
    bet = Float32(gs.bets[pl])

    # return !folded * ((opp < mpc) * gs.pot - (opp > mpc) * (gs.pot - bet) + (opp == mpc) * gs.pot/2) + folded * bet

    util = !folded * ((opp < mpc) * gs.pot - (opp > mpc) * bet + (opp == mpc) * gs.pot/2) - folded * bet

    println("UTIL! ", util, " ", bet, " ", folded, " ", mpc, " ", opp, " ", gs.pot)

    return util

end

@inline function solving.computeutility!(
    gs::KUHNGameState,
    pl::T,
    cha::KUHNChanceAction) where T<:Integer

    deck = deck!(gs)

    mpc = deck[cha.p_idx] # main player private card
    opp = deck[cha.opp_idx] # opponent private card

    folded = gs.players_states[pl] == false
    bet = Float32(gs.bets[pl])

    # return !folded * ((opp < mpc) * gs.pot - (opp > mpc) * (gs.pot - bet) + (opp == mpc) * gs.pot/2) + folded * bet

    # util = !folded * ((opp < mpc) * gs.pot - (opp > mpc) * bet + (opp == mpc) * gs.pot/2) - folded * bet

    # println("UTIL! ", util, " ", bet, " ", folded, " ", mpc, " ", opp, " ", gs.pot)

    return !folded * ((opp < mpc) * gs.pot - (opp > mpc) * bet + (opp == mpc) * gs.pot/2) - folded * bet

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
    root_h = History(History{Node{MVector{2, MVector{3, Float32}}}, UInt64, UInt8})
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

        #compute and display exploitability each 10 iterations

        if n == 10000
            println(util)
            println(
                "Exploitability ", 
                computeexploitability!(Float32, gs, root_h)/2 * 1000, 
                " Milli Big Blind")

            n = 0
        end

    end

    println(
        "Final Exploitability ", 
        computeexploitability!(Float32, gs, root_h)/(2 * 1000), 
        " Milli Big Blind")
    println(util)

end

# function solvekuhn(solver::MCCFR{T}, itr::IterationStyle)
#     deck = getdeck(Vector{UInt8})

#     game = KUHNGame{Vector{UInt8}}(getcompresseddeck(Vector{UInt8}))

#     #todo: we need to remove the distributed private cards from the deck!

#     gs = KUHNGameState{FullTraining}(game)

#     h = history(History{typeof(gs), MVector{4, T}, T, 13}, gs)()


# end