using solver
using StaticArrays
using IterTools

#todo: need a vectorized version 

struct CFRPlus{N, P, T<:AbstractFloat} <: Solver
    weight::T
end

function innersolve(
    solver::CFRPlus{N, true, T}, 
    gs::GameState{A, 2, Game{U}}, 
    g::Game{U}, 
    data::ShareData, 
    h::History{T},
    pl::PlayerState, 
    opp_probs::MVector{N, T}) where {T<:AbstractFloat, U<:GameMode, N}

    ev = @MVector zeros(T, N)

    if gs.state == ENDED_ID
        #todo: loop over all possible opponent private cards
        #and evaluate against main player. We then return a vector
        #with the utilities with respect to the main player.
        #if the main player wins the entry is positive, if the player
        # loses, the entry is negative, if it is a draw, it is null.
        mpc = data.private_cards[players.id(pl)]

        mpc_rank = evaluate(mpc, data.public_cards)

        #showdown against each possible combination of opponent private cards

        #todo: get opponent private cards combinations
        for (i, opp_pc) in enumerate(combination())
            ev[i] = showdown!(gs, g, pl, mpc_rank, opp_pc)
        end

    end

    info_set = infoset(
        MMatrix{N, A, T},
        h, 
        key(privatecards(pl, data)), 
        data.public_cards,
        data.pbl_cards_mask)
    
    actions = actions!(g)
    actions_mask = actionsmask!(gs)

    #alternatively, we could cache this array in the history
    #node... h.utils we could also store ev in h, to avoid using
    # too much memory... this should be safe since we only use 
    #the previous history...

    cum_regrets = info_set.cum_regrets

    if pl == ps.player
        n_actions = sum(actions_mask)
        
        for (i, (a, am)) in enumerate(zip(actions, actions_mask))
            #todo: create multiple threads

            if am == 1
                ha = history(h, a.id)

                game_state = ha.game_state

                copy!(game_state, gs)

                perform!(a, game_state, game_state.player)

                utils = innersolve(solver, gs, g, data, h, pl, opp_probs)

                #update strategy for all hands for one action

                cr_vector = view(cum_regrets, :, i)

                for j in 1:N
                    #this could be cached...
                    #but could use too much memory... trade-off
                    #shouldn't take too long since we don't have a lot of actions

                    norm = sum(view(cum_regrets, j, :))

                    cr = cr_vector[j]
                    u = utils[j]

                    e = ev[j]
                    
                    e += norm > 0 ? (cr * u)/norm : u/n_actions 
                    
                    cr += u - e

                    ev[j] = e
                    cr_vector[j] = max(cr, 0)
                end

            end
        end
    else

        cum_strategy = actions.cum_strategy

        for (i, (a, am)) in enumerate(zip(actions, actions_mask))

            if am == 1
                cr_vector = view(cum_regrets, :, i)
                cs_vector = view(cum_strategy, :, i)

                #total reach probability
                ps = T(0)

                for j in 1:N
                    p = opp_probs[j]
  
                    norm = sum(view(cum_regrets, j, :))

                    cr = cr_vector[j]
                    
                    np = norm > 0 ? (cr * p)/norm : p/n_actions
                    
                    opp_probs[j] = np
                    cs_vector[j] += np
                    
                    ps += np
                end

                ha = history(h, a.id)
                game_state = ha.game_state

                copy!(game_state, gs)

                perform!(a, game_state, game_state.player)

                if ps > 0
                    utils = innersolve(solver, gs, g, data, h, pl, opp_probs)
                    
                    for j in 1:N
                        ev[j] += utils[j]
                    end
                end

            end
        end
    end

    return ev

end

function solve(
    solver::CFRPlus{N, T}, 
    gs::GameState{A, 2, Game{U}},
    g::Game{FullSolving},
    itr::IterationStyle) where {A, N, U <: GameMode}

    stp = setup(g) # game setup
    data = shared(g)
    n = length(stp.actions)
    # root history
    h = History(n, gs, zeros(T, n))
    #=println("Dealer ", last(states).id)
    println("Players Order ", [p.id for p in states])=#

    opp_probs = @MVector ones(T, N)

    for _ in itr
        # need average strategy here
        # need average regret here

        #we could parallelize at this level calculate util for each player
        #then do a summation at the end of the loop.
        #problem: data is shared.

        for pl in stp.players
            util += innersolve(
                solver, 
                gs, g, 
                data, 
                h, pl, 
                opp_probs)
        end
    
    end

    putbackcards!(root, stp, data)
end