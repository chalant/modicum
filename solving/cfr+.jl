using solver
using StaticArrays
using IterTools

#todo: need a vectorized version 

struct CFRPlus{N, T<:AbstractFloat} <: Solver
    weight::Float32
end

function regretmatching(::CFRPlus, infoset::Node)

end

@inline function updatestrategy!(
    cum_regrets::StaticVector{N, T}) where {N, T <: AbstractFloat}
    
    st = @MVector zeros(T, N)

    for i in 1:N
        cr = cum_regrets[i]
        r = cr > 0 ? cr : 0
        st[i] = r
    end

    return st

end

function innersolve(
    solver::CFRPlus{N, T}, 
    gs::GameState{A, 2, Game{U}}, 
    g::Game{U}, 
    data::ShareData, 
    h::History{T},
    pl::PlayerState, 
    opp_probs::MVector{N, T}) where {T<:AbstractFloat, U<:GameMode, N}

    ev = @MVector zeros(T, N)

    info_set = infoset(
        MMatrix{N, A, T},
        h, 
        key(privatecards(pl, data)), 
        data.public_cards)
    
    actions = actions!(g)
    actions_mask = actionsmask!(gs)

    #alternatively, we could cache this array in the history
    #node... h.utils we could also store ev in h, to avoid using
    # too much memory... this should be safe since we only use the previous history...

    if pl == ps.player
        n_actions = sum(actions_mask)
        
        for a in actions
            #todo: create multiple threads
            i = a.id

            if actions_mask[i] == 1
                ha = history(h, i)

                game_state = ha.game_state

                copy!(game_state, gs)

                perform!(a, game_state, game_state.player)

                utils = innersolve(solver, gs, g, data, h, pl, opp_probs)

                #update strategy for all hands for one action
                
                cum_regrets = info_set.cum_regrets

                cr_vector = view(cum_regrets, :, i)

                for j in 1:N
                    #this could be cached...
                    #but could use too much memory... trade-off
                    #shoulndn't take too long since we don't have a lot of actions

                    norm = sum(view(cum_regrets, j, :))

                    cr = cr_vector[j]
                    r = cr > 0 ? cr : 0
                    u = utils[j]
                    
                    ev[i] += norm > 0 ? r/norm * u : 1/n_actions
                    
                    cr += u
                    cr_vector[j] = max(cr, 0)
                end

            end
        end
    else
        cum_strategy = info_set.cum_strategy

        for a in actions
            
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

        for p in stp.players
            util += solve(solver, h, g, p)
        end
    
    end

    putbackcards!(root, stp, data)
end