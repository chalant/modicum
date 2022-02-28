module cfrplus

using StaticArrays
using IterTools

using games
using solving
using infosets

export CFRPlus

export solve

struct CFRPlus{P} <: Solver
end

@inline function playerreachprob!(arr::V, pl::I, i::I, p::T) where {V<:StaticVector, I<:Integer, T<:AbstractFloat}
    arr[pl] * (p * (pl == i) + (pl != i) * 1)
end

@inline function updatereachprobs!(arr::V, pl::I, p::T) where {N, I<:Integer, T<:AbstractFloat, V<:StaticVector{N, T}}
    return StaticArrays.sacollect(SVector{N, T}, playerreachprob!(arr, pl, i, p) for i::I in 1:N)
end

function solve(
    solver::CFRPlus{true},
    gs::G,
    h::H,
    chance_action::C,
    pl::I1,
    reach_probs::P,
    iteration::I2) where {A, I1<:Integer, I2<:Integer, C<:games.ChanceAction, T<:AbstractFloat, P<:StaticVector{3, T}, G<:AbstractGameState{A, FullSolving, 2}, N<:Node, K1<:Integer, K2<:Integer, H<:History{N, K1, K2}}

    if terminal!(gs) == true       
        return computeutility!(gs, pl, chance_action)
    
    elseif chance!(gs) == true
        #pass-in an index to the function so that we can track the
        #which card subset to pass.

        #we will compress actions (public data, by combining with main players private data)
        #that way, we can parallelize without collisions...

        iter = chanceactions!(gs, chance_action)
        next = iterate(iter)

        (a, state) = next

        ha = History(h, a.idx)

        p = chanceprobability!(T, gs, chance_action)

            # game_state = ha.game_state
            # copy!(game_state, gs)

            # state = performchance!(a, game_state, game_state.player)

        ev = solve(
            solver, 
            performchance!(a, gs, gs.player), 
            ha, 
            a, pl, 
            SVector{3, T}(reach_probs[1], reach_probs[2], reach_probs[3] * p),
            iteration) * p
        
        next = iterate(iter, state)

        while next !== nothing
            # ha = history(h, a.idx)

            (a, state) = next

            p = chanceprobability!(T, gs, chance_action)

            # game_state = ha.game_state
            # copy!(game_state, gs)

            # state = performchance!(a, game_state, game_state.player)

            ev += solve(
                solver, 
                performchance!(a, gs, gs.player), 
                History(h, a.idx, ha.infosets), 
                a, pl, 
                SVector{3, T}(reach_probs[1], reach_probs[2], reach_probs[3] * p),
                iteration) * p

            next = iterate(iter, state)
        end

        return ev
    end
    
    info = infoset(h, infosetkey(gs, gs.player))

    action_mask = actionsmask!(gs)
    n_actions = sum(action_mask)

    cum_regrets = cumulativeregrets!(info, gs.player)
    
    norm = sum(cum_regrets)
    
    norm = (norm != 0) * norm + n_actions * (norm == 0)

    actions = actions!(gs)
    
    lga = games.legalactions!(K2, action_mask, n_actions)

    utils = getutils(h)

    idx = lga[1]

    ha = History(h, K2(1))

    # game_state = ha.game_state
    # copy!(game_state, gs)

    # state = perform!(actions[idx], gs, gs.player)

    stg::T = (norm!=n_actions) * cum_regrets[1]/norm + (norm==n_actions) * 1/n_actions

    # new_probs = copy(reach_probs)
    # new_probs[game_state.player] *= stg

    util = solve(
        solver, 
        perform(actions[idx], gs, gs.player), 
        ha, 
        chance_action, 
        pl,
        updatereachprobs!(reach_probs, gs.player, stg), 
        iteration)

    node_util = util * stg
    utils[1] = util

    for i::K2 in 2:n_actions
        idx = lga[i]

        # game_state = ha.game_state
        # copy!(game_state, gs)

        # state = perform!(actions[idx], gs, gs.player)

        stg = (norm!=n_actions) * cum_regrets[i]/norm + (norm==n_actions) * 1/n_actions

        # new_probs = copy(reach_probs)
        # new_probs[game_state.player] *= stg

        util += solve(
            solver, 
            perform(actions[idx], gs, gs.player), 
            History(h, i, ha.infosets), 
            chance_action, 
            pl,
            updatereachprobs!(reach_probs, gs.player, stg), 
            iteration)

        node_util += util * stg
        utils[i] = util

    end

    #todo: update cumulative regrets and cumulative strategy
    if pl == gs.player
        cum_stg = cumulativestrategy!(info, pl)

        norm = T(0)

        for i::K2 in 1:n_actions
            cr = cum_regrets[i]
            res = cr + (utils[i] - util)
            
            #will be zero or res
            cum_regrets[i] = res * (res > 0)
            norm += cum_regrets[i]
        end

        #update cumulative strategy
        norm = (norm == 0) * n_actions + (norm != 0) * norm

        for i::K2 in 1:n_actions
            cum_stg[i] += ((norm != n_actions) * cum_regrets[i]/norm + (norm == n_actions) * 1/n_actions) * utils[i] * reach_probs[pl] * iteration * action_mask[i]
        end
    end

    return node_util

end

end