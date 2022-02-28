module mccfr

using StaticArrays

using games
using solving
using infosets

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
    norm::T) where {T<:AbstractFloat, S<:MCCFR{T}, K<:Unsigned, A, V<:StaticVector{A, T}, C<:games.Action, G<:AbstractGameState{A, FullSolving, 2}, H<:History}              

    cr = cum_regrets[action_idx]

    stg = (cr > 0) * cr/norm

    # cr += (utils[i] - util)

    ut = solve(
        solver, 
        perform(a, gs, gs.player),
        h, pl)

    utils[action_idx] = ut
    node_utils[action_idx] = stg * ut

end

function solve(
    solver::MCCFR{T}, 
    gs::G, 
    h::H, 
    pl::I) where {A, I<:Integer, T<:AbstractFloat, G<:AbstractGameState{A, FullSolving, 2}, H<:History}

    #todo: handle ended and terminated states!
    # get utility on ended state

    if terminal!(gs) == true       
        #get the utilty of the main player
        return computeutility!(gs, pl)
    
    elseif chance!(gs) == true
        nextround!(gs, pl)
    end
    
    info = infoset(h, infosetkey(gs))

    action_mask = actionsmask!(gs)
    n_actions = T(sum(action_mask))

    cum_regrets = cumulativeregrets!(info, gs.player)
    
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
        ha = History(h, lgs[1], gs)

        Threads.@spawn solveforaction!(
            solver, gs, 
            actions[lgs[1]],
            ha,
            lgs[1],
            utils,
            node_utils,
            cum_regrets,
            norm)
        
        @sync for i in 2:n_actions
            ha = History(h, ha.infosets, lgs[i], gs)
            
            Threads.@spawn solveforaction!(
                solver,
                gs,
                actions[lgs[i]],
                ha, 
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

    cum_stg = cumulativestrategy!(info, gs.player)
    
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
    
    return solve(
        solver,
        perform(actions[idx], gs, gs.player),
        history(h, idx), pl)
end
end
