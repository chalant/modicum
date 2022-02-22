using StatsBase

using solving
using cfrplus
using mccfr
using infosets

#todo: compute for the case where the last round was not reached! (one player folded)

@inline function solving.computeutility!(
    gs::KUHNGameState{FullSolving}, 
    pl::T) where T <: Integer
    
    data = game!(gs)

    mp = data.private_cards[pl]
    opp = data.private_cards[(pl != 1) * 2 + (pl == 1)]

    folded = gs.states[pl] == false
    bet = gs.bets[mp]

    return !folded * ((opp < mpc) * gs.pot - (opp > mpc) * (gs.pot - bet) + (opp == mpc) * gs.pot/2) + folded * bet

end

@inline function solving.computeutility!(
    gs::KUHNGameState{FullSolving},
    mp::T,
    uv::V) where {N, T<:Integer, V<:StaticVector{N}}

    g = game!(gs)
    
    deck = g.deck
    mpc = g.private_cards[mp]

    folded = gs.states[pl] == false
    bet = gs.bets[mp]

    for i in eachindex(deck)
        opp = deck[i]

        uv[i] = !folded * ((opp < mpc) * gs.pot - (opp > mpc) * (gs.pot - bet) + (opp == mpc) * gs.pot/2) + folded * bet
    end

    return uv

end

@inline function infosets.infosetkey(gs::KUHNGameState, pl::Integer)
    return privatecards!(gs)[pl]
end

function solvekuhn(solver::CFRPlus{P, T}, itr::IterationStyle) where {P, T<:AbstractFloat}
    deck = getcompresseddeck(MVector{UInt8})

    game = KUHNGame{Vector{UInt8}}(getcompresseddeck(SVector{UInt8}))

    #todo: we need to remove the distributed private cards from the deck!

    gs = KUHNGameState{FullTraining}(game)

    #create root history
    root_h = History(SizedVector{2, SizedVector{3, Float32}}, gs)

    reach_probs = @SVector ones(T, 3)
    br_probs = @SVector ones(T, 3)

    private_cards = game.private_cards

    #to avoid looping over a changing array
    players = copy(game.players)

    #todo: we might need to start with a smaller kuhn game, where we only have a deck
    # of three cards.

    n = 0
    initial_state = initialstate(gs)

    util = T(0)

    for _ in itr
        for pl in players
            #sample one card from the deck
            c1 = sample!(deck, 1)

            #todo: pop respecting the main player's position
            # if he's second, deal the second card of the deck,
            # since we distribute clock-wise...
        
            # c = deck[i]
            
            # deleteat!(deck, i)
            
            private_cards[pl] = c1

            # KUHNChanceAction{UInt64}(0, findall(x->x==c1, deck))

            util += sum(solve(
                solver, 
                gs, root_h, pl, 
                initial_state, 
                opp_probs))
            
            rotateplayers!(game)
            
            # push!(deck, private_cards[pl])

            reset!(gs)

        end

        n += 1

        #compute and display exploitability each 

        if n == 1000
            total_br = 0

            deck = gs.deck

            for i in eachindex(deck)

                for pl in players

                    for i in 1:N
                        br_probs[i] /= 2
                    end

                    private_cards[pl] = deck[i]
                    total_br += sum(bestresponse(root_h, gs, pl, initial_state, br_probs))
                end

                rotateplayers!(game)
                reset!(gs)

            end

            println(
                "Exploitability ", 
                total_br/26 * 1000, 
                " Milli Big Blind")

            n = 0
        end

    end

    #todo: compute best response to track exploitability
    exploitability = sum(bestresponse(root_h, gs, pl, initial_state, br_probs))/26 * 1000

    println("Final Exploitability ", exploitability, " Milli Big Blind")

end

function solvekuhn(solver::MCCFR{T}, itr::IterationStyle)
    deck = getdeck(Vector{UInt8})

    game = KUHNGame{Vector{UInt8}}(getcompresseddeck(Vector{UInt8}))

    #todo: we need to remove the distributed private cards from the deck!

    gs = KUHNGameState{FullTraining}(game)

    h = history(History{typeof(gs), MVector{4, T}, T, 13}, gs)()


end