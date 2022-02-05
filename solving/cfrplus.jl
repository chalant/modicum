module cfrplus

using StaticArrays
using IterTools

using solver
using infosets
using bestresponse

export solve

struct CFRPlus{P, T<:AbstractFloat} <: Solver

end

function solve(
    solver::CFRPlus{true, T}, 
    gs::AbstractGameState{A, 2, FullSolving, T}, 
    h::AbstractHistory{AbstractGameState{A, 2, FullSolving, T}, V, T, N},
    pl::Integer,
    state::Integer, 
    opp_probs::U) where {N, A, T<:AbstractFloat, V<:StaticMatrix{N, A, T}, U<:StaticVector{N, T}}

            #todo: we could sort actions such that all the active actions are
        #at the top, then would would
    ev = getutils(h)

    if terminal!(state) == true
        return computeutility!(gs, pl, ev)
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
                    gs, h, pl, 
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

function solve(
    solver::CFRPlus{true, T}, 
    gs::AbstractGameState{A, 2, FullSolving, T}, 
    h::AbstractHistory{AbstractGameState{A, 2, FullSolving, T}, V, T, N},
    pl::Integer,
    state::Integer,
    chance_action::ChanceAction{R, W},
    opp_probs::U) where {N, A, T<:AbstractFloat, V<:StaticMatrix{N, A, T}, U<:StaticVector{N, T}}

            #todo: we could sort actions such that all the active actions are
        #at the top, then would would
    ev = getutils(h)

    if terminal!(state) == true
        return computeutility!(gs, pl, ev)
    end

    if chance!(state) == true
        i = 1

        #pass-in an index to the function so that we can track the
        #which card subset to pass.

        for a in chanceactions!(gs, chance_action)
            #todo: create a key with the public cards and the private cards, and use that
            # to retrieve or create history
            #todo: the key must be UInt64 in this case, so action ids must be
            #UInt64-based
            #problem: if we use the cached, game state and parallelize, we might
            #overwrite game state while it is still being used, so we would need to compress
            #before. Problem: we might update strategies in a spefic infoset only per iteration...

            #note: the key must be different from the other actions id

            ha = history(h, a)

            game_state = ha.game_state
            copy!(game_state, gs)

            utils = solve(
                solver, 
                gs, ha, pl, 
                performchance!(a, game_state, game_state.player)
                i, opp_probs)

            for i in 1:N
                ev[i] += utils[i]
            end

            i += 1
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