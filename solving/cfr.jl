module cfr

using StaticArrays
using IterTools

using TimerOutputs

using games
using solving
using infosets
using kuhn

export CFR

export solve

struct CFR <: Solver
end

function playerreachprob!(arr::V, pl::I, i::I, p::T) where {V<:StaticVector, I<:Integer, T<:AbstractFloat}
    return arr[pl] * (p * (pl == i) + (pl != i) * 1)
end

@inline function updatereachprobs!(arr::V, pl::I, p::T) where {N, I<:Integer, T<:AbstractFloat, V<:StaticVector{N, T}}
    # return StaticArrays.sacollect(SVector{N, T}, playerreachprob!(arr, pl, i, p) for i::I in 1:N)
    # m = MVector{N, T}(arr)
    # m[pl] *= p
    return setindex(arr, arr[pl] * p, Int64(pl))
end

function solve(
    solver::CFR,
    gs::G,
    h::H,
    chance_action::C,
    pl::I,
    reach_probs::P) where {A, I<:Integer, C<:games.ChanceAction, T<:AbstractFloat, P<:StaticVector{3, T}, G<:AbstractGameState{A, FullSolving, 2}, N<:Node, K1<:Integer, K2<:Integer, H<:History{N, K1, K2}}

    if terminal!(gs) == true       
        return computeutility!(T, gs, pl, chance_action)
    
    elseif chance!(gs) == true        
        iter = chanceactions!(gs, chance_action)
        next = iterate(iter)

        (a, state) = next

        ha = History(h, a.idx)

        p = chanceprobability!(T, gs, chance_action)

        ev = solve(
            solver, 
            performchance!(a, gs, gs.player), 
            ha, 
            a, pl, 
            SVector{3, T}(reach_probs[1], reach_probs[2], reach_probs[3] * p)) * p
        
        next = iterate(iter, state)
        
        while next !== nothing
            # ha = history(h, a.idx)

            (a, state) = next

            p = chanceprobability!(T, gs, chance_action)

            ev += solve(
                solver, 
                performchance!(a, gs, gs.player), 
                ha, 
                a, pl, 
                SVector{3, T}(reach_probs[1], reach_probs[2], reach_probs[3] * p)) * p
            
            next = iterate(iter, state)
        end

        return ev
    end

    info = infoset(h, infosetkey(gs, chance_action))

    (lga, n_actions) = games.legalactions!(K2, gs)

    cum_regrets = cumulativeregrets!(info, gs.player)
    
    norm = T(0)

    for i in cum_regrets
        norm += (i > 0) * i
    end
    
    norm = (norm != 0) * norm + n_actions * (norm == 0)

    utils = getutils(h)

    idx = lga[1]
    
    ha = History(h, K2(idx))

    nr = cum_regrets[1]/norm
    stg = ((norm != n_actions) * nr * (nr > 0) + (norm == n_actions) * T(1/n_actions))

    util = solve(
        solver, 
        perform(action(gs, idx), gs, gs.player), 
        ha, 
        chance_action, 
        pl,
        updatereachprobs!(reach_probs, gs.player, stg))

    node_util = util * stg
    utils[1] = util

    for i in 2:n_actions
        idx = lga[i]
        
        nr = cum_regrets[i]/norm  
        stg = ((norm != n_actions) * nr * (nr > 0) + (norm == n_actions) * T(1/n_actions))

        util = solve(
            solver, 
            perform(action(gs, idx), gs, gs.player), 
            History(h, K2(idx)), 
            chance_action, 
            pl,
            updatereachprobs!(reach_probs, gs.player, stg))
        
        node_util += util * stg
        utils[i] = util

    end

    #todo: update cumulative regrets and cumulative strategy
    if pl == gs.player
        cum_stg = cumulativestrategy!(info, pl)
        p0 = reach_probs[pl]

        #update cumulative strategy

        for i in 1:n_actions
            nr = cum_regrets[i]/norm
            cum_stg[i] += ((norm != n_actions) * nr * (nr > 0) + (norm == n_actions) * T(1/n_actions)) * p0
            # println("norm ", norm, " cum ", cum_regrets[i], " utils ", utils[i])
        end

        # norm = T(0)

        #todo: we need a better way to get the opponent index
        
        p1 = reach_probs[(pl == 1) * 2 + (pl == 2) * 1]

        # println("PREVIOUS ", cum_regrets)

        for i in 1:n_actions
            cum_regrets[i] += (utils[i] - node_util) * p1
            # norm += cum_regrets[i]
            # println("DIFF ", utils[i] - node_util)
        end

        # println("STG ", cum_stg)
        # println("REGRETS ", cum_regrets)
        # println("UTILS ", utils)

    end

    return node_util

end

function solve(
    solver::CFR,
    gs::G,
    h::H,
    pl::I,
    reach_probs::P) where {A, I<:Integer, T<:AbstractFloat, P<:StaticVector{2, T}, G<:AbstractGameState{A, FullSolving, 2}, N<:Node, K1<:Integer, K2<:Integer, H<:History{N, K1, K2}}

    if terminal!(gs) == true       
        return computeutility!(T, gs, pl)
    end

    info = infoset(h, infosetkey(gs, pl))

    (lga, n_actions) = games.legalactions!(K2, gs)

    cum_regrets = cumulativeregrets!(info, gs.player)
    
    norm = T(0)

    for i in cum_regrets
        norm += (i > 0) * i
    end
    
    norm = (norm != 0) * norm + n_actions * (norm == 0)

    utils = getutils(h)

    idx = lga[1]
    
    ha = History(h, K2(idx))

    nr = cum_regrets[1]/norm
    stg = ((norm != n_actions) * nr * (nr > 0) + (norm == n_actions) * T(1/n_actions))

    util = solve(
        solver, 
        perform(action(gs, idx), gs, gs.player), 
        ha, 
        pl,
        updatereachprobs!(reach_probs, gs.player, stg))

    node_util = util * stg
    utils[1] = util

    for i in 2:n_actions
        idx = lga[i]
        
        nr = cum_regrets[i]/norm  
        stg = ((norm != n_actions) * nr * (nr > 0) + (norm == n_actions) * T(1/n_actions))

        util = solve(
            solver, 
            perform(action(gs, idx), gs, gs.player), 
            History(h, K2(idx)), 
            pl,
            updatereachprobs!(reach_probs, gs.player, stg))
        
        node_util += util * stg
        utils[i] = util

    end

    #todo: update cumulative regrets and cumulative strategy
    if pl == gs.player
        cum_stg = cumulativestrategy!(info, pl)
        p0 = reach_probs[pl]

        #update cumulative strategy

        for i in 1:n_actions
            nr = cum_regrets[i]/norm
            cum_stg[i] += ((norm != n_actions) * nr * (nr > 0) + (norm == n_actions) * T(1/n_actions)) * p0
            # println("norm ", norm, " cum ", cum_regrets[i], " utils ", utils[i])
        end

        # norm = T(0)

        #todo: we need a better way to get the opponent index
        
        p1 = reach_probs[(pl == 1) * 2 + (pl == 2) * 1]

        # println("PREVIOUS ", cum_regrets)

        for i in 1:n_actions
            cum_regrets[i] += (utils[i] - node_util) * p1
            # norm += cum_regrets[i]
            # println("DIFF ", utils[i] - node_util)
        end

        # println("STG ", cum_stg)
        # println("REGRETS ", cum_regrets)
        # println("UTILS ", utils)

    end

    return node_util

end

end