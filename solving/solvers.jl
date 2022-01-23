module Solvers

export epsilongreedysample!
export limit!
export showdown!
export key
export DepthLimitedSolving
export FullSolving

abstract type Solver end
abstract type Solving end

using playing
using games
using filtering
using evaluator

struct MCCFR{T<:AbstractFloat} <: Solver
    epsilon::T 
end

struct CFRPlus{N, P, T<:AbstractFloat} <: Solver
end

# todo add compression data to resources folder
# filter for private cards
const PreFlopFilter = Filter(indexdata(
    IndexData, 
    "/resources/lossless/pre_flop"))

@inline function key(pr::MVector{P, UInt64}, pc::MVector{B, UInt64}) where {B, P}
    #returns a unique key for a combination of private and public hands

    #if no public cards
    if length(pc) == 0
        # return equivalent index (after compression)
        return filterindex(PreFlopFilter, pr)
    end

    return evaluate(binomial(length(pr) + length(pc), 2), pr, pc)
end

@inline function randomsample!(wv::Vector{Bool})
    n = length(wv)
    t = rand()
    i = 1
    cw = 0

    #count active actions (could use game.num_actions instead)
    c = 0
    
    for j in 1:n
        if @inbounds wv[j] == 1
            c += 1
        end
    end

    while i < n
        @inbounds cw += wv[i]/c

        if t < cw
            break
        end

        i += 1
    end

    return i
end

@inline function weightedsample!(
    strategy::Vector{T},
    action_mask::Vector{T},
    rn::T) where T <: AbstractFloat

    n = length(wv)
    i = 1
    
    cw = T(0)

    while i < n
        @inbounds cw += strategy[i] * action_mask[i]

        if rn < cw
            break
        end

        i += 1
    end

    return i

end

@inline function epsilongreedysample!(
    strategy::MVector{A, T},
    action_mask::MVector{A, Bool}, 
    epsilon::T) where {T <: AbstractFloat, A}
    
    #sample action using strategy or select random action

    t = rand(Float32)

    if t >= epsilon
        return weightedsample!(strategy, action_mask, t)
    else
        return randomsample!(action_mask)
    end
end

@inline function games.limit!(gs::GameState{A, P, Game{DepthLimited, P}}) where {A, P}
    #override numrounds! functions for depth-limited game setups
    return setup(gs).limit
end

struct DepthLimited{Solver} <: GameSetup
    strategy_index::SVector{UInt8} # oppenent will randomly chose a strategy to play at the depth
    limit::UInt8
end

struct FullTraining{T<:Solver} <: GameSetup

end

@inline function showdown!(gs::GameState{A, 2, Game{T}}, g::Game{T}, mp::PlayerState, mpc_rank::UInt64, opp_pc::SVector{2, UInt64}) where T <: GameMode
    #returns utils of the main player

    cond = gs.round >= numround!(g)
    earnings = _computepotentialearning!(gs.players_states, mp)
    
    return cond * _lastround!(gs, g, mpc_rank, opp_pc, earnings) + !cond * mp.active == true * earnings

    # if gs.round >= numrounds!(g)
    #     # game has reached the last round
    #     return _lastround!(gs, g, mp, mpc_rank, opp_pc)
    # else
    #     # all players except one have folded
    #     return _notlastround!(gs, g, mp, mpc_rank, opp_pc)
    # end
end

@inline function _lastround!(
    gs::GameState{A, 2, Game{T, 2}}, 
    data::ShareData,
    mpc_rank::UInt64, 
    opp_pc::SizedArray{2, UInt64},
    earnings::U) where {A, U<:AbstractFloat, T<:GameSetup}
    
    opp_rank = evaluate(opp_pc, data.public_cards)
    best_rank = min(mpc_rank, opp_rank)

    has_best_rk = mpc_rank == best_rank

    return ((-(mpc_rank > best_rk)) + has_best_rk) * ((earnings >= gs.pot_size) * (earnings ^ 2) / (gs.pot_size * (1 + has_best_rk && opp_rank == best_rank))) + (earnings < gs.pot_size) * earnings
    
end

@inline function _nlastround!(mp::PlayerState, earnings::U) where U <: AbstractFloat
    return mp.active == true * earnings
end


end