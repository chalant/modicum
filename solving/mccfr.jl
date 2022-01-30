include("infosets.jl")
include("../abstraction/filtering.jl")

using StaticArrays
using Threads

using solving
using solver
using playing
using players
using iterationstyles

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
            st[i] = (cr > 0) * cr
        end
    end

    return st
end

@inline function solveforaction!(
    a::Action,
    h::History, 
    action_idx::UInt8,
    utils::SizedVector{A, T},
    node_utils::SizedVector{A, T},
    cum_regrets::SizedVector{A, T},
    norm::T) where {T<:AbstractFloat, A, P}              
    
    ha = history(h, action_idx)

    game_state = ha.game_state

    #copy game state into buffer
    copy!(game_state, gs)

    #perform action and update state of copy
    perform!(a, game_state, game_state.player)

    cr = cum_regrets[action_idx]

    stg = cr > 0 ? cr/norm : 0

    cr += p1 * (utils[i] - util)

    ut = innersolve(
        solver, 
        game_state,
        ha, pl, 
        p0*stg,
        p1)

    utils[action_idx] = ut
    node_utils[action_idx] = stg * ut

end

function innersolve(
    solver::MCCFR{T}, 
    gs::AbstractGameState{A, 2, FullSolving, T}, 
    h::AbsractHistory{GameState{A, 2, R, FullSolving}, V, T, 1}, 
    pl::PlayerState{T},
    p0::T,
    p1::T) where {T<:AbstractFloat, A, R, V <: StaticVector{A, T}}

    data = shared(gs)

    #todo: handle ended and terminated states!
    # get utility on ended state

    if terminal(gs) == true       
        #get the utilty of the main player
        return computeutility!(gs, pl)
    end

    util = T(0)

    info = infoset(
        MVector{A, T},
        h,
        key(privatecards(pl, data), 
        data.public_cards,
        data.pbl_cards_mask)
    )

    action_mask = actionsmask!(gs)
    n_actions = T(sum(action_mask))

    cum_regrets = info.cum_regrets
    
    norm = T(0)

    for cr in cum_regrets
        norm += (cr > 0) * cr
    end
    
    norm = (norm > 0) * norm + n_actions * (norm <= 0)

    ply = gs.player

    action_mask = actionsmask!(gs)
    actions = actions!(gs)

    if pl == ply
        # use static array to avoid heap allocations
        utils = @MVector zeros(T, A)
        node_utils = @MVector zeros(T, A)
        
        #solve in different threads 
        #(note: this will recursively spawn threads 
        #until there are no more threads...)

        lgs = legalactions!(action_mask)
        
        @sync for i in 1:n_actions
            Threads.@spawn solveforaction!(
                actions[lgs[i]],
                h, 
                i,
                utils, 
                node_utils,
                cum_regrets,
                norm)
        end
        # update regrets
        util = sum(node_utils)

        for (i, am) in enumerate(action_mask)
            cum_regrets[i] += am * p1 * (utils[i] - util)
        end

        return util
    
    # update cumulative strategy and sample random action

    cum_stg = info.cum_strategy
    
    rn = rand()
    cw = T(0)
    idx = UInt8(0)
    j = UInt8(1)

    sampled = false
    s = T(0)

    e = solver.epsilon

    for i in eachindex(action_mask)
        am = action_mask[i]

        cr = cum_regrets[i]
        
        #this is set to zero when cr is negative
        stg = (cr > 0) * cr/norm

        cum_stg[i] += p1 * stg * am

        # if sampled == false
        #     if rn < e
        #         cw += nr * stg * am
        #     else
        #         cw += am / n_actions
        #     end

        #     if rn < cw
        #         idx = j
        #         s = stg
        #         sampled = true
        #     end

        #     j += 1
        # end

        cond = rn < e

        cw += (nr * stg * am) * cond + (am / n_actions) * !cond  
        
        cond = (rn < cw)

        sampled = cond * true + false

        idx = cond * j * !sampled + sampled * idx * !cond
        s = cond * stg * !sampled + sampled * s * !cond

        j += 1

    end
    
    a = actions[idx]

    ha = history(h, idx)

    game_state = ha.game_state

    copy!(game_state, gs)

    perform!(a, game_state, gs.player)
    
    return innersolve(
        solver,
        game_state,
        ha, pl,
        p0, 
        p1 * s)
end

end

function solving.solve(
    solver::MCCFR{T}, 
    gs::GameState{A, 2, R, FullSolving}, 
    g::Game{FullSolving}, 
    itr::IterationStyle) where {A, R, T<:AbstractFloat}

    data = shared(g)

    #todo: one util per player?
    util = T(0)
    
    #todo: maybe use an internal SVector instead of MVector

    #initial history
    h = history(History{typeof(gs), MArray{A, T}, T}, gs)()
    
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
                T(1), 
                T(1))
        

            putbackcards!(root, g, data)
        end

end

function solving.solve(
    solve::MCCFR{T},
    gs::GameState,
    g::Game{DepthLimitedSolving}) where {T<:AbstractFloat}
    

end
