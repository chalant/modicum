using solver
using StaticArrays
using IterTools

#todo: need a vectorized version 

function bestresponse!(
    h::AbstractHistory{GameState{A, 2, FullSolving, T}, U, V, N}, 
    gs::AbstracGameState{A, 2, FullSolving, T}, 
    pl::Integer,
    opp_probs::W) where {N, A, T<:AbstractFloat, V, U<:StaticMatrix{N, A, T}, W<:StaticVector{N, T}}


    
return

function innersolve(
    solver::CFRPlus{N, true, T}, 
    gs::AbstractGameState{A, 2, FullSolving, T}, 
    h::AbstractHistory{AbstractGameState{A, 2, FullSolving, T}, V, T, N},
    pl::Integer,
    state::Integer, 
    opp_probs::U) where {N, A, T<:AbstractFloat, V<:StaticMatrix{N, A, T}, U<:StaticVector{N, T}}

    
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

    if pl == gs.player
        lga = legalactions!(actions_mask, n_actions)

        for i in 1:n_actions
            #todo: create multiple threads
            idx = lga[i]

            a = actions[idx]

            ha = history(h, idx)

            game_state = ha.game_state

            copy!(game_state, gs)

            state = perform!(a, game_state, game_state.player)

            utils = innersolve(
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

        lga = legalactions!(actions_mask, n_actions)

        for i in 1:n_actions
            idx  = lga[i]

            cr_vector = @view cum_regrets[:, i]
            cs_vector = @view cum_strategy[:, i]

            #total reach probability
            ps = T(0)

            for j in 1:N
                p = opp_probs[j]

                norm = sum(@view cum_regrets[j, :])

                cr = cr_vector[j]

                norm = (norm > 0) * norm + (norm <= 0) * n_actions
                
                np = (norm != n_actions) * (cr * p)/norm +  (norm == n_actions) * p/n_actions
                
                opp_probs[j] = np
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

                utils = innersolve(
                    solver, 
                    gs, h, pl, 
                    state,
                    opp_probs)
                
                for j in 1:N
                    ev[j] += utils[j]
                end
            end
        end
    end
    
    return ev
end

# todo: implement function for a specific game... and specific solver
# ex: texas holdem, kuhn, leduc ...

function solve(
    solver::CFRPlus{N, T}, 
    gs::AbstractGameState{A, 2, FullSolving, T},
    itr::IterationStyle) where {A, N, T<:AbstractFloat}

    g = game!(gs)
    stp = setup(g) # game setup
    data = shared(g)
    deck = data.deck
    players = players!(gs)
    
    # root history
    
    h = history(History{typeof(gs), SizedMatrix{N, A, T}, T, N}, gs)()

    opp_probs = @MVector ones(T, N)

    for _ in itr
        # need average strategy here
        # need average regret here

        for pl in players
            shuffle!(deck)
            
            #distribute private cards only to main player

            for i in 1:g.num_private_cards
                data.privatecards[pl.id][i] = pop!(deck) 
            
            util += innersolve(
                solver, 
                gs,
                h, 
                pl,
                initialstate(), 
                opp_probs)
            
            putbackcards!(root, stp, data)
        end

    end
end