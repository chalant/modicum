module Utilities

using NLTH
using THPlayers
using THEvaluation

using KUHN
using KUHNPlayers


@inline function _showdown!(
    gs::NLTHGameState{A, 2, FullSolving, T}, 
    mp::NLTHPlayerState{T}, 
    mpc_rank::UInt64, 
    opp_pc::StaticVector{2, UInt64}) where {A, T<:AbstractFloat}
    
    #returns utils of the main player

    cond = gs.round >= numrounds!(gs)
    earnings = _computepotentialearning!(gs.players_states, mp)
    active = mp.active
    
    return cond * _lastround!(gs, g, mpc_rank, opp_pc, earnings) + !cond * (active * earnings - !active * mp.total_bet)

    # if gs.round >= numrounds!(g)
    #     # game has reached the last round
    #     return _lastround!(gs, g, mp, mpc_rank, opp_pc)
    # else
    #     # all players except one have folded
    #     return _notlastround!(gs, g, mp, mpc_rank, opp_pc)
    # end
end

@inline function _lastround!(
    gs::NLTHGameState{A, 2, Game{T, 2}}, 
    data::ShareData,
    mpc_rank::UInt64, 
    opp_pc::SizedArray{2, UInt64},
    earnings::U) where {A, U<:AbstractFloat, T<:GameSetup}
    
    opp_rank = evaluateterminal(opp_pc, data.public_cards)

    best_rank = (mpc_rank < opp_rank) * mpc_rank + (mpc_rank >= opp_rank) * opp_rank

    has_best_rk = mpc_rank == best_rank

    return ((has_best_rk - (mpc_rank > best_rk))) * ((earnings >= gs.pot_size) * (earnings ^ 2) / (gs.pot_size * (1 + has_best_rk && opp_rank == best_rank))) + (earnings < gs.pot_size) * earnings
    
end

@inline function computeutility!(
    gs::NLTHGameState{A, 2, FullSolving, T},
    pl::THPlayerState{T}, 
    uv::StaticVector{N}) where {A, N, T<:AbstractFloat}

    data = shared(gs)

    mpc = data.private_cards[players.id(pl)]

    mpc_rank = evaluateterminal(mpc, data.public_cards)

    #showdown against each possible combination of opponent private cards

    deck = game!(gs).deck
    
    k = 2
    opp_pc = @MVector zeros(UInt64, 2) 

    l = 0

    for i in 1:N-k+1
        opp_pc[1] = deck[i]

        for j in i+k-1:N
            l += 1
            
            opp_pc[2] = deck[j]
            uv[l] = _showdown!(gs, pl, mpc_rank, opp_pc)
        end

    end

    return uv

end

@inline function computeutility!(
    gs::NLTHGameState{A, 2, FullSolving, T},
    pl::THPlayerState{T}) where {A, T<:AbstractFloat}

    pos = THPlayers.id(pl)

    return _showdown!(
        gs, 
        pl, 
        evaluateterminal(data.private_cards[pos], data.public_cards), 
        data.private_cards[(pos != 1) * 2 + (pos == 1) * 1])

end

#todo: compute for the case where the last round was not reached! (one player folded)

@inline function computeutility!(gs::KUHNGameState{FullSolving, T}, pl::KUHNPlayerState) where T <: AbstractFloat
    data = shared(gs)

    pos = Players.id(pl)

    mp = data.private_cards[pos]
    opp = data.private_cards[(pos != 1) * 2 + (pos == 1)]

    return opp < mp - (opp > mp)

end

@inline function computeutility!(
    gs::KUHNGameState{FullSolving, T}, 
    pl::KUHNPlayerState{T},
    uv::StaticVector{N}) where {N, T<:AbstractFloat}

    deck = game!(gs).deck

    mp = data.private_cards[Players.id(pl)]

    for i in eachindex(deck)
        opp = deck[i]

        uv[i] = opp < mp - (opp > mp)
    end

    return uv
    
end

end