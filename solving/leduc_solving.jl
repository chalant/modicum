using solving
using cfrplus
using mccfr
using infosets

#todo: compute for the case where the last round was not reached! (one player folded)

@inline function solving.computeutility!(
    gs::LeDucGameState{FullSolving}, 
    pl::T) where T <: Integer
    
    data = game!(gs)

    mp = data.private_cards[pl]
    opp = data.private_cards[(pl != 1) * 2 + (pl == 1)]

    folded = gs.states[pl] == false
    bet = gs.bets[mp]

    return !folded * ((opp < mpc) * gs.pot - (opp > mpc) * (gs.pot - bet) + (opp == mpc) * gs.pot/2) + folded * bet

end

@inline function solving.computeutility!(
    gs::LeDucGameState{FullSolving},
    mp::T,
    uv::V) where {A, N, T<:Integer, V<:StaticVector{A, N}}

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

@inline function solving.computeutility!(
    gs::LeDucGameState{FullSolving},
    mp::T,
    opp_probs::V,
    uv::V) where {A, N, T<:Integer, V<:StaticVector{A, N}}
end