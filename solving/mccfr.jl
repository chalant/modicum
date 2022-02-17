include("infosets.jl")
include("../abstraction/filtering.jl")

using StaticArrays
using Threads

using solving
using solver
using playing
using players
using iterationstyles

struct MCCFR{T<:AbstractFloat} <: Solver
    epsilon::T 
end

@inline function stategysum!(
    strategy::MVector{A, T}, 
    actions_mask::MVector{A, Bool}, 
    w::T) where {T<:AbstractFloat, A}
    
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
    solver::S,
    gs::G,
    a::C,
    h::H, 
    action_idx::K,
    utils::V,
    node_utils::V,
    cum_regrets::V,
    norm::T) where {T<:AbstractFloat, S<:MCCFR{T}, K<:Unsigned, A, V<:StaticVector{A, T}, C<:Action, G<:AbstractGameState{A, 2, FullSolving, T}, H<:AbstractHistory{G, V, T, 1, K}}              
    
    ha = history(h, action_idx)

    game_state = ha.game_state

    #copy game state into buffer
    copy!(game_state, gs)

    #perform action and update state of copy
    state = perform!(a, game_state, game_state.player)

    cr = cum_regrets[action_idx]

    stg = (cr > 0) * cr/norm

    # cr += (utils[i] - util)

    ut = solve(
        solver, 
        game_state,
        ha, pl,
        state)

    utils[action_idx] = ut
    node_utils[action_idx] = stg * ut

end

function solve(
    solver::MCCFR{T}, 
    gs::G, 
    h::H, 
    pl::Integer,
    state::Integer) where {T<:AbstractFloat, A, V <: StaticVector{A, T}, K<:Unsigned, G<:AbstractGameState{A, 2, FullSolving, T}, H<:AbstractHistory{G, V, T, 1, K}}

    #todo: handle ended and terminated states!
    # get utility on ended state

    if terminal!(gs, state) == true       
        #get the utilty of the main player
        return computeutility!(gs, pl)
    
    elseif chance!(gs, state) == true
        nextround!(gs, pl)
    end
    
    info = infoset(V, h, infosetkey(gs))

    action_mask = actionsmask!(gs)
    n_actions = T(sum(action_mask))

    cum_regrets = info.cum_regrets
    
    norm = T(0)

    for cr in cum_regrets
        norm += (cr > 0) * cr
    end
    
    norm = (norm > 0) * norm + n_actions * (norm <= 0)

    action_mask = actionsmask!(gs)
    actions = actions!(gs)

    if pl == gs.player
        # use static array to avoid heap allocations
        utils = @MVector zeros(T, A)
        node_utils = @MVector zeros(T, A)
        
        #solve in different threads 
        #(note: this will recursively spawn threads 
        #until there are no more threads...)

        lgs = legalactions!(action_mask)
        
        @sync for i in 1:n_actions
            Threads.@spawn solveforaction!(
                solver,
                gs,
                actions[lgs[i]],
                h, 
                lgs[i],
                utils, 
                node_utils,
                cum_regrets,
                norm)
        end
        # update regrets
        util = sum(node_utils)

        for (i, am) in enumerate(action_mask)
            cum_regrets[i] += am * (utils[i] - util)
        end

        return util
    end
    
    # update cumulative strategy and sample random action

    cum_stg = info.cum_strategy
    
    rn = rand()
    cw = T(0)
    idx = UInt8(0)
    j = UInt8(1)

    sampled = false

    s = T(0)

    e = solver.epsilon

    #sample one action for the opponent

    for i in eachindex(action_mask)
        am = action_mask[i]

        cr = cum_regrets[i]
        
        #this is set to zero when cr is negative
        stg = (cr > 0) * cr/norm

        cum_stg[i] += stg * am

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
        e_cond = (rn < e)
        
        cw += (stg * am) * !e_cond

        idx = e_cond * j * !sampled + sampled * idx * e_cond
        
        cond = (rn < cw || e_cond)

        idx = cond * j * !sampled + sampled * idx * !cond
        s = cond * stg * !sampled + sampled * s * !cond

        sampled = cond

        j += 1

    end

    ha = history(h, idx)

    game_state = ha.game_state

    copy!(game_state, gs)

    state = perform!(actions[idx], game_state, gs.player)
    
    return solve(
        solver,
        game_state,
        ha, pl,
        state)
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
                gs, h, pl,
                state,
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
