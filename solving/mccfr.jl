include("infosets.jl")
include("../abstraction/filtering.jl")

using StaticArrays
using Threads

using solving
using solver
using playing
using players
using iterationstyles

struct MCCFR{N, T<:AbstractFloat} <: Solver
    epsilon::T 
end

@inline function stategysum!(
    strategy::MVector{A, T}, 
    actions_mask::MVector{A, Bool}, 
    w::T) where {T <: AbstractFloat, A}
    
    num_actions = sum(actions_mask)

    for i in 1:A
        if actions_mask[i] == 1
            nr = norm > 0 ? strategy[i]/norm : 1/num_actions
            info_set.cum_strategy[i] += w * nr
            st[i] = nr
        end
    end
end

@inline function updatestrategy!(
    cum_regrets::StaticVector{A, T}, 
    actions_mask::StaticVector{A, Bool}) where {T <: AbstractFloat, A}

    st = @MVector zeros(T, A)

    for i in 1:A
        if actions_mask[i] == 1
            cr = cum_regrets[i]
            r = cr > 0 ? cr : 0
            st[i] = r
            norm += r
    end

    return st
end

@inline function solveforaction!(
    h::History, 
    action_idx::UInt8,
    utils::MVector{A, T},
    node_utils::MVector{A, T}) where {T<:AbstractFloat, A, P}              
    
    ha = history(h, action_idx)

    game_state = ha.game_state

    #copy game state into buffer
    copy!(game_state, gs)

    #perform action and update state of copy
    perform!(a, game_state, game_state.player)

    stgi = stg[action_idx]

    ut = innersolve(
        solver, 
        game_state,
        g, data, 
        ha, pl, 
        p0*stgi,
        p1)

    utils[action_idx] = ut
    node_utils[action_idx] = stgi * ut

end

function innersolve(
    solver::MCCFR{A, T}, 
    gs::GameState{A, 2, Game{FullTraining}}, 
    g::Game{FullTraining},
    data::SharedData,
    h::History{T}, 
    pl::PlayerState,
    p0::T,
    p1::T) where {T<:AbstractFloat, A}

    #todo: handle ended and terminated states!
    # get utility on ended state

    if gs.state == ENDED_ID        
        #get the utilty of the main player
        return showdown!(gs)[players.id(pl)]
    end

    util = Float32(0)

    info = infoset(
        h,
        key(privatecards(pl, data), 
        data.public_cards)
    )

    action_mask = actionsmask!(gs)

    stg = updatestrategy!(
        info, 
        action_mask)
    
    # use static array to avoid heap allocations
    utils = @MVector zeros(T, A)
    node_utils = @MVector zeros(T, A)

    ply = gs.player

    action_mask = actionsmask!(gs)
    actions = actions!(g)

    if pl == ply
        #solve in different threads 
        #(note: this will recursively spawn threads 
        #until there are no more threads...)
        
        @sync for a in actions
            idx = a.id
            
            if action_mask[idx] == 1
                Threads.@spawn solveforaction!(
                    h, 
                    idx, 
                    utils, 
                    node_utils)
            end
        end

        # update regrets
        util = sum(node_utils)

        for i in 1:A
            info.cum_regret[i] += action_mask[i] * p1 * (utils[i] - util)
        end

        return util

    #sample opponent action...
    idx = epsilongreedysample!(
        stg, 
        action_mask, 
        solver.epsilon)
    
    a = actions[idx]

    ha = history(h, a.id, n)

    game_state = ha.game_state

    copy!(game_state, gs)

    perform!(a, game_state, gs.player)
    
    #todo: why are we updating the strategy when it is the opponent?
    strategysum!(stg, action_mask, 1)
    
    #todo reach probabilities!! we need 2!!!
    return innersolve(
        solver,
        game_state,
        g, data, 
        ha, pl,
        p0, 
        p1 * stg[idx])
end

end

function solving.solve(
    solver::MCCFR{T}, 
    gs::GameState{A, 2, Game{U}}, 
    g::Game{FullSolving}, 
    itr::IterationStyle) where {T<:AbstractFloat, U <: GameMode, A}

    data = shared(g)
    n = g.num_actions

    #todo: one util per player?
    util = Float32(0)
    
    #todo: maybe use an internal SVector instead of MVector

    #initial history
    h = History(n, gs, zeros(Float32, n))
    
    for _ in itr
        #sample public and private cards

        shuffle!(data.deck)

        for pl in g.players
            shuffle!(data.deck)
            distributecards!(gs, g, data)
            
            util += innersolve(
                solver, 
                gs, g, 
                data, 
                h, pl, 
                T(1), T(1))
        

            putbackcards!(root, g, data)
        end

end

function solving.solve(
    solve::MCCFR{T},
    gs::GameState,
    g::Game{DepthLimitedSolving}) where {T<:AbstractFloat}
    

end
