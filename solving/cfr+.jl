using solver
using StaticArrays
using IterTools

#todo: need a vectorized version 

function innersolve(
    solver::CFRPlus{N, true, T}, 
    gs::GameState{A, 2, FullSolving, T}, 
    h::AbstractHistory{GameState{A, 2, FullSolving, T}, V, T, N},
    pl::PlayerState{T}, 
    opp_probs::MVector{N, T}) where {N, A, T<:AbstractFloat, V <: StaticMatrix{N, A, T}}

    #todo: problem N might be too big (>1000 elements), so we might need a cache
    # so that we do not increment each time... cache the util vector in history...
    ev = getutils(h)
    g = game!(gs)
    data = shared(gs)

    if gs.state == ENDED_ID
        
        #todo: abstract this part away, since we do not know which game we are playing could be kuhn
        # etc.

        mpc = data.private_cards[players.id(pl)]

        mpc_rank = evaluateterminal(mpc, data.public_cards)

        #showdown against each possible combination of opponent private cards
        
        deck = g.deck
        k = 2
        opp_pc = @MVector zeros(UInt64, 2) 
        
        l = 0

        for i in 1:N-k+1
            opp_pc[1] = deck[i]

            for j in i+k-1:N
                l += 1
                opp_pc[2] = deck[j]
                
                ev[l] = showdown!(gs, g, pl, mpc_rank, opp_pc)
            end

        end

        return ev

    end

    info_set = infoset(
        V,
        h, 
        key(privatecards(pl, data), data.public_cards), 
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

        #todo: we could sort actions such that all the active actions are
        #at the top, then would would just iterate until we hit n_actions
        # we do some permutations following the mask... we would then avoid branching
        lga = legalactions!(actions_mask, n_actions)

        for i in 1:n_actions
            #todo: create multiple threads
            idx = lga[i]

            a = actions[idx]

            ha = history(h, idx)

            game_state = ha.game_state

            copy!(game_state, gs)

            perform!(a, game_state, game_state.player)

            utils = innersolve(solver, gs, h, pl, opp_probs)

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
                
                #note: instead using 0, we could 
                # compare to a very small value (1*10^-x) 
                e += norm > 0 ? (cr * u)/norm : u/n_actions 
                
                cr += u - e

                ev[j] = e
                cr_vector[j] = (cr > 0) * cr
            end
        end
    else
        cum_strategy = actions.cum_strategy

        lga = legalactions!(actions_mask, n_actions)

        for i in 1:n_actions
            idx  = lga[i]

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

            ha = history(h, idx)
            game_state = ha.game_state

            copy!(game_state, gs)

            perform!(
                actions[idx], 
                game_state, 
                game_state.player)

            #whether we prune or not
            if ps > 0
                utils = innersolve(solver, gs, h, pl, opp_probs)
                
                for j in 1:N
                    ev[j] += utils[j]
                end
            end
        end
    end
    
    return ev
end

function solve(
    solver::CFRPlus{N, T}, 
    gs::GameState{A, 2, FullSolving, T},
    itr::IterationStyle) where {A, N, T<:AbstractFloat}

    g = game!(gs)
    stp = setup(g) # game setup
    data = shared(g)
    deck = data.deck
    
    # root history
    
    h = history(History{typeof(gs), SizedMatrix{N, A, T}, T, N}, gs)()
    
    #=println("Dealer ", last(states).id)
    println("Players Order ", [p.id for p in states])=#

    opp_probs = @MVector ones(T, N)

    for _ in itr
        # need average strategy here
        # need average regret here

        for pl in stp.players
            shuffle!(deck)
            
            #distribute private cards only to main player

            for i in 1:g.num_private_cards
                data.privatecards[pl.id][i] = pop!(deck) 
            
            util += innersolve(
                solver, 
                gs,
                h, 
                pl, 
                opp_probs)
            
            putbackcards!(root, stp, data)
        end

    end
end