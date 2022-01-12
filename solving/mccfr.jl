include("tree.jl")
include("abstraction/filtering.jl")

using StaticArrays

using solving
using solver
using playing

struct MCCFR{N, T<:AbstractFloat} <: Solver
    probs::SVector{N, T}
    epsilon::T 
end

@inline function updatestrategy!(
    info_set::Node, 
    gs::GameState, 
    g::Game, 
    w::Float32)

    st = info_set.stg_profile
    i = 1
    
    actions = actions!(g)
    actions_mask = actionsmask!(gs)

    for _ in actions
        if actions_mask[i] == 1
            cr = info_set.cum_regret[i]
            r = cr > 0 ? cr : 0
            st[i] = r
            norm += r
        else
            st[i] = 0 # unavailable action
        end
        i += 1
    end

    i = 1
    
    for _ in actions
        if actions_mask[i] == 1
            nr = norm > 0 ? st[i]/norm : 1/g.num_actions
            info_set.cum_strategy[i] += w * nr
            st[i] = nr
        end
        i += 1
    end

    return st
end

function innersolve(
    solver::MCCFR{A, T}, 
    gs::GameState{A, 2, Game{FullTraining}}, 
    g::Game{FullTraining},
    data::SharedData,
    h::History{A, T}, 
    pl::PlayerState) where {T<:AbstractFloat, A}

    #todo: handle ended and terminated states!
    # get utility on ended state

    state = gs.state

    if state == ENDED_ID
        #todo return utility
        return

    util = Float32(0)

    info = infoset(
        h,
        key(privatecards(pl, data), 
        data.public_cards)
    )

    stg = updatestrategy!(
        info, 
        gs, g, 
        solver.probs[id(ply)])
    
    # use static array to avoid heap allocations
    utils = SVector{A, T}(zeros(A))

    i = 1
    ply = gs.player

    action_mask = actionsmask!(gs)
    actions = actions!(g)

    if pl == ply
        # todo: spawn thread of each action!
        for a in actions
            if action_mask[i] == 1
                ha = history(h, a.id, n)
                
                game_state = ha.game_state
                
                #copy game state into buffer
                copy!(game_state, gs)
                
                #perform action and update state of copy
                perform!(a, game_state, gs.player)
                
                ut = innersolve(
                    solver, 
                    game_state,
                    g, data, 
                    ha, pl)
                
                utils[i] = ut
                util += stg[i] * ut

            else
                utils[i] = 0
            end

            i += 1
        end

        # update regrets
        
        i = 1

        pos = id(ply)
        
        #opponent reach probability
        rp = solver.probs[pos + @fastmath (-1)^(pos-1)]

        for _ in actions
            if action_mask[i] == 1
                info.cum_regret[i] += rp * (utils[i] - util)
            end
            
            i += 1
        end

        return util
    else
        #sample opponent action...

        a = actions[epsilongreedysample!(
            stg, 
            action_mask, 
            solver.epsilon)]

        ha = history(h, a.id, n)

        game_state = ha.game_state

        copy!(game_state, gs)

        perform!(a, game_state, gs.player)

        return innersolve(
            solver,
            game_state,
            g, data, 
            ha, pl)
    end

end

function solving.solve(
    solver::MCCFR{T}, 
    gs::GameState, 
    g::Game{FullSolving}, 
    itr::Iteration) where {T<:AbstractFloat}

    data = shared(g)
    n = g.num_actions

    util = Float32(0)
    #initial history
    h = History(n, gs, zeros(Float32, n))

    for _ in itr
        #sample private cards

        shuffle!(data.deck)
        distributecards!(gs, g, data)

        for pl in g.players
            util += innersolve(
                solver, 
                gs, g, 
                data, 
                h, pl)
        end

        putbackcards!(root, g, data)

end

function solving.solve(
    solve::MCCFR{T},
    gs::GameState,
    g::Game{DepthLimitedSolving}) where {T<:AbstractFloat}
    

end
