using solving
using cfrplus
using mccfr
using infosets

@inline function solving.computeutility!(
    gs::KUHNGameState,
    mp::T,
    uv::StaticVector{N}) where {N, T<:Integer}

    g = game!(gs)
    
    deck = g.deck
    mpc = g.private_cards[mp]

    for i in eachindex(deck)
        opp = deck[i]

        uv[i] = (opp < mpc) * gs.pot - (opp > mpc) * gs.pot + (opp == mpc) * gs.pot/2
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

    h = history(VHistory{typeof(gs), MMatrix{13, 4, T}, T, 13}, gs)()

    opp_probs = @MVector ones(T, 13)
    br_probs = @MVector ones(T, 13)

    private_cards = game.private_cards

    #to avoid looping over a changing array
    players = copy(game.players)

    #todo: we might need to start with a smaller kuhn game, where we only have a deck
    # of three cards.

    n = 0
    initial_state = initialstate()
    util = T(0)

    for _ in itr
        for pl in players
            #random chance sampling (external sampling)
            shuffle!(deck)

            #todo: pop respecting the main player's position
            # if he's second, deal the second card of the deck,
            # since we distribute clock-wise...
            
            # i = findall(x->x==pl, gs.players)
            # c = deck[i]
            
            # deleteat!(deck, i)
            
            private_cards[pl] = deck[1]

            util += sum(solve(
                solver, 
                gs, h, pl, 
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
                        br_probs[i] /= 12
                    end

                    private_cards[pl] = deck[i]
                    total_br += sum(bestresponse(h, gs, pl, initial_state, br_probs))
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
    exploitability = sum(bestresponse(h, gs, pl, initial_state, br_probs))/26 * 1000

    println("Final Exploitability ", exploitability, " Milli Big Blind")

end

function solvekuhn(solver::MCCFR{N, T}, itr::IterationStyle)
    deck = getdeck(Vector{UInt8})

    game = KUHNGame{Vector{UInt8}}(getcompresseddeck(Vector{UInt8}))

    #todo: we need to remove the distributed private cards from the deck!

    gs = KUHNGameState{FullTraining}(game)

    h = history(History{typeof(gs), MVector{4, T}, T, 13}, gs)()


end