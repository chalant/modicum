module cfrplus

using StaticArrays
using IterTools

using solver
using infosets
using bestresponse

export solve

struct CFRPlus{P} <: Solver

end

function solve(
    solver::CFRPlus{true},
    gs::G,
    h::H,
    chance_action::C,
    pl::Integer,
    state::Integer,
    reach_probs::P,
    iteration::Integer) where {A, C<:ChanceAction, T<:AbstractFloat, P<:StaticVector{3, T}, V<:StaticVector{A, T}, K<:Unsigned, G<:AbstractGameState{A, 2, FullSolving, T}, H<:AbstractHistory}

    if terminal!(gs, state) == true       
        #get the utilty of the main player
        return computeutility!(gs, pl)
    
    elseif chance!(gs, state) == true

        #pass-in an index to the function so that we can track the
        #which card subset to pass.

        #we will compress actions (public data, by combining with main players private data)
        #that way, we can parallelize without collisions...
        ev = T(0)

        for a in chanceactions!(gs, chance_action)
            #todo: create a key with the public cards and the private cards, and use that
            # to retrieve or create history
            #todo: the key must be UInt64 in this case, so action ids must be
            #UInt64-based
            #problem: if we use the cached, game state and parallelize, we might
            #overwrite game state while it is still being used, so we would need to compress
            #before. Problem: we might update strategies in a spefic infoset only per iteration...

            #add an offset of A to the action index to avoid conflicts with player actions
            #note: there is no risk of index collision since histories are different.
            ha = history(h, a.idx)

            p = chanceprobability!(gs, chance_action)

            game_state = ha.game_state
            copy!(game_state, gs)

            state = performchance!(a, game_state, game_state.player)

            ev += solve(
                solver, 
                game_state, 
                ha, a, pl, 
                state,
                @SVector [reach_probs[1], reach_probs[2], reach_probs[3] * p],
                iteration) * p
        end

        return ev
    end
    
    info = infoset(h, infosetkey(gs))

    action_mask = actionsmask!(gs)
    n_actions = T(sum(action_mask))

    cum_regrets = cumulativeregrets!(info, gs.player)
    
    norm = sum(cum_regrets)
    
    norm = (norm != 0) * norm + n_actions * (norm == 0)

    action_mask = actionsmask!(gs)
    n_actions = sum(action_mask)
    actions = actions!(gs)
    
    lga = legalactions!(gs, action_mask, n_actions)

    node_util = T(0)
    utils = getutils!(h)

    idx = lga[1]

    ha = History(h, idx, gs)

    game_state = ha.game_state
    copy!(game_state, gs)

    state = perform!(actions[idx], game_state, game_state.player)

    stg = (norm!=n_actions) * cum_regrets[idx]/norm + (norm==n_actions) * 1/n_actions

    new_probs = copy(reach_probs)
    new_probs[game_state.player] *= stg

    util += solve(
        solver, 
        gs, ha, 
        chance_action, 
        pl, state, 
        new_probs, 
        iteration)

    node_util += util * stg
    utils[idx] = util

    for i in 2:n_actions
        idx = lga[i]

        ha = History(h, ha.infosets, idx, gs)

        game_state = ha.game_state
        copy!(game_state, gs)

        state = perform!(actions[idx], game_state, game_state.player)

        stg = (norm!=n_actions) * cum_regrets[idx]/norm + (norm==n_actions) * 1/n_actions

        new_probs = copy(reach_probs)
        new_probs[game_state.player] *= stg

        util += solve(
            solver, 
            gs, ha, 
            chance_action, 
            pl, state, 
            new_probs, 
            iteration)

        node_util += util * stg
        utils[idx] = util

    end

    #todo: update cumulative regrets and cumulative strategy
    if pl == gs.player
        cum_stg = cumulativestrategy!(info, pl)

        norm = T(0)

        for i in eachindex(action_mask)
            cr = cum_regrets[i]
            res = cr + action_mask[i] * (utils[i] - util)
            
            #will be zero or res
            cum_regrets[i] = res * (res > 0)
            norm += cum_regrets[i]
        end

        #update cumulative strategy
        norm = (norm == 0) * n_actions + (norm != 0) * norm

        for i in eachindex(action_mask)
            cum_stg[i] += ((norm != n_actions) * cum_regrets[i]/norm + (norm == n_actions) * 1/n_actions) * utils[i] * reach_probs[pl] * iteration * action_mask[i]
        end

        return node_util
    end

    return node_util

end

function solve(
    solver::CFRPlus{true}, 
    gs::G, 
    h::AbstractHistory{G, V, T, N, K},
    pl::Integer,
    state::Integer, 
    opp_probs::U) where {N, A, T<:AbstractFloat, V<:StaticMatrix{N, A, T}, U<:StaticVector{N, T}, K<:Unsigned, G<:AbstractGameState{A, 2, FullSolving, T}}

    #todo: we could sort actions such that all the active actions are
    #at the top, then would would
    
    ev = getutils(h)

    if terminal!(gs, state) == true
        return computeutility!(gs, pl, ev)
    end

    if chance!(gs, state) == true
        nextround!(gs, pl)
    end

    info_set = infoset(V, h, infosetkey(gs))
    
    actions = actions!(gs)
    actions_mask = actionsmask!(gs)
    n_actions = sum(actions_mask)

    #alternatively, we could cache this array in the history
    #node... h.utils we could also store ev in h, to avoid using
    # too much memory... this should be safe since we only use 
    #the previous history...

    cum_regrets = info_set.cum_regrets

    lga = legalactions!(actions_mask, n_actions)

    if pl == gs.player
        
        for i in 1:n_actions
            #todo: create multiple threads
            idx = lga[i]

            a = actions[idx]

            ha = history(h, idx)

            game_state = ha.game_state

            copy!(game_state, gs)

            state = perform!(a, game_state, game_state.player)

            utils = solve(
                solver, 
                game_state, 
                h, pl, 
                state, 
                opp_probs)

            #update strategy for all hands for one action

            cr_vector = @view cum_regrets[:, i]

            for j in 1:N
                #this could be cached...
                #but could use too much memory... trade-off
                #shouldn't take too long since we don't have a lot of actions

                norm = sum(@view cum_regrets[j, :])

                cr = cr_vector[j]
                u = utils[j]

                e = ev[j]
                
                norm = (norm > 0) * norm + (norm <= 0) * n_actions 

                #norm is always equal to n_actions or strictly bigger than zero
                
                e += (norm != n_actions) * (cr * u)/norm + (norm == n_actions) * u/norm
                
                cr += u - e

                ev[j] = e
                cr_vector[j] = (cr > 0) * cr
            end
        end
    else
        cum_strategy = info_set.cum_strategy
        
        #todo: this might need to be cached if the vector is heap allocated
        new_probs = getprobs(h)

        for i in 1:n_actions
            idx  = lga[i]

            cr_vector = @view cum_regrets[:, i]
            cs_vector = @view cum_strategy[:, i]

            #total reach probability
            ps = T(0)

            for j in 1:N
                norm = sum(@view cum_regrets[j, :])

                cr = cr_vector[j]

                norm = (norm > 0) * norm + (norm <= 0) * n_actions
                
                p = opp_probs[j]
                np = (norm != n_actions) * (cr * p)/norm +  (norm == n_actions) * p/n_actions
                
                new_probs[j] = np
                cs_vector[j] += np
                
                ps += np
            end

            ha = history(h, idx)
            game_state = ha.game_state

            copy!(game_state, gs)

            #whether we prune or not
            if ps > 0
                state = perform!(
                    actions[idx],
                    game_state, 
                    game_state.player)

                utils = solve(
                    solver, 
                    game_state, 
                    h, pl, 
                    state,
                    new_probs)
                
                for j in 1:N
                    ev[j] += utils[j]
                end
            end
        end
    end
    
    return ev
end

#todo: we need chance reach probs

#todo: add linear averaging, cum_strategy[a] += iteration_ * reach_prob * strategy[a]

#todo: implement a value cfr plus algorithm (alternating non vectorized)

function solve(
    solver::CFRPlus{true, T}, 
    gs::G, 
    h::AbstractHistory{G, V, T, N, K},
    pl::Integer,
    state::Integer,
    chance_action::C,
    opp_probs::U) where {C<:ChanceAction, N, A, T<:AbstractFloat, V<:StaticMatrix{N, A, T}, U<:StaticVector{N, T}, K<:Unsigned, G<:AbstractGameState{A, 2, FullSolving, T}}

    #todo: we could sort actions such that all the active actions are
    #at the top, then would would
    
    ev = getutils(h)

    if terminal!(gs, state) == true
        return computeutility!(gs, pl, opp_probs, ev)
    end

    if chance!(gs, state) == true

        #pass-in an index to the function so that we can track the
        #which card subset to pass.

        #we will compress actions (public data, by combining with main players private data)
        #that way, we can parallelize without collisions...

        for a in chanceactions!(gs, chance_action)
            #todo: create a key with the public cards and the private cards, and use that
            # to retrieve or create history
            #todo: the key must be UInt64 in this case, so action ids must be
            #UInt64-based
            #problem: if we use the cached, game state and parallelize, we might
            #overwrite game state while it is still being used, so we would need to compress
            #before. Problem: we might update strategies in a spefic infoset only per iteration...

            #add an offset of A to the action index to avoid conflicts with player actions
            #note: there is no risk of index collision since histories are different.
            ha = history(h, a.idx)

            p = chanceprobability!(gs, chance_action)

            game_state = ha.game_state
            copy!(game_state, gs)

            state = performchance!(a, game_state, game_state.player)

            #todo: should we update opponents reach probability based on chance probability?
            new_probs = getprobs(h)

            for i in eachindex(new_probs)
                new_probs[i] = opp_probs[i] * p
            end

            utils = solve(
                solver, 
                game_state, 
                ha, pl, 
                state,
                new_probs, a)

            for i in 1:N
                ev[i] += utils[i] * p
            end
        end

        return ev
    end

    info_set = infoset(V, h, infosetkey(gs))
    
    actions = actions!(gs)
    actions_mask = actionsmask!(gs)
    n_actions = sum(actions_mask)

    #alternatively, we could cache this array in the history
    #node... h.utils we could also store ev in h, to avoid using
    # too much memory... this should be safe since we only use 
    #the previous history...

    cum_regrets = info_set.cum_regrets

    lga = legalactions!(actions_mask, n_actions)

    if pl == gs.player
        
        for i in 1:n_actions
            #todo: create multiple threads
            idx = lga[i]

            a = actions[idx]

            ha = history(h, idx)

            game_state = ha.game_state

            copy!(game_state, gs)

            state = perform!(a, game_state, game_state.player)

            utils = solve(
                solver, 
                game_state, 
                h, pl, 
                state,
                chance_idx, 
                opp_probs)

            #update strategy for all hands for one action

            cr_vector = @view cum_regrets[:, i]

            for j in 1:N
                #this could be cached...
                #but could use too much memory... trade-off
                #shouldn't take too long since we don't have a lot of actions

                norm = sum(@view cum_regrets[j, :])

                cr = cr_vector[j]
                u = utils[j]

                e = ev[j]
                
                norm = (norm > 0) * norm + (norm <= 0) * n_actions 

                #norm is always equal to n_actions or strictly bigger than zero
                
                e += (norm != n_actions) * (cr * u)/norm + (norm == n_actions) * u/norm
                
                cr += u - e

                ev[j] = e
                cr_vector[j] = (cr > 0) * cr
            end
        end
    else
        cum_strategy = info_set.cum_strategy
        
        #todo: this might need to be cached if the vector is heap allocated
        new_probs = getprobs(h)

        for i in 1:n_actions
            idx  = lga[i]

            cr_vector = @view cum_regrets[:, i]
            cs_vector = @view cum_strategy[:, i]

            #total reach probability
            ps = T(0)

            for j in 1:N
                norm = sum(@view cum_regrets[j, :])

                cr = cr_vector[j]

                norm = (norm > 0) * norm + (norm <= 0) * n_actions
                
                p = opp_probs[j]
                np = (norm != n_actions) * (cr * p)/norm +  (norm == n_actions) * p/n_actions
                
                new_probs[j] = np
                cs_vector[j] += np
                
                ps += np
            end

            ha = history(h, idx)
            game_state = ha.game_state

            copy!(game_state, gs)

            #whether we prune or not
            if ps > 0
                state = perform!(
                    actions[idx],
                    game_state, 
                    game_state.player)

                utils = solve(
                    solver, 
                    gs, h, pl, 
                    state,
                    chance_idx,
                    new_probs)
                
                for j in 1:N
                    ev[j] += utils[j]
                end
            end
        end
    end
    
    return ev
end

end