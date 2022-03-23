module cfrplus

using StaticArrays

using games
using solving
using infosets
using kuhn

export CFRPlus

export solve

struct CFRPlus{P} <: Solver
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
    solver::CFRPlus{true},
    gs::G,
    h::H,
    chance_action::C,
    pl::I1,
    reach_probs::P,
    iteration::I2) where {A, I1<:Integer, I2<:Integer, C<:games.ChanceAction, T<:AbstractFloat, P<:StaticVector{3, T}, G<:AbstractGameState{A, FullSolving, 2}, N<:Node, K1<:Integer, K2<:Integer, H<:History{N, K1, K2}}
    
    # println(chance_action)

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
            SVector{3, T}(reach_probs[1], reach_probs[2], reach_probs[3] * p),
            iteration) * p
        
        next = iterate(iter, state)
        
        while next !== nothing
            # ha = history(h, a.idx)

            (a, state) = next

            p = chanceprobability!(T, gs, chance_action)

            # println("Chance Action ",  a)

            ev += solve(
                solver, 
                performchance!(a, gs, gs.player), 
                History(h, a.idx), 
                a, pl, 
                SVector{3, T}(reach_probs[1], reach_probs[2], reach_probs[3] * p),
                iteration) * p
            
            next = iterate(iter, state)
        end

        return ev
    end

    info = infoset(h, infosetkey(gs, chance_action))

    (lga, n_actions) = games.legalactions!(K2, gs)

    # println("Legal Actions ", lga)

    cum_regrets = cumulativeregrets!(info, gs.player)
    
    norm = sum(T, cum_regrets)
    
    norm = (norm != 0) * norm + n_actions * (norm == 0)

    utils = getutils(h)

    idx = lga[1]

    stg = (norm!=n_actions) * cum_regrets[1]/norm + (norm==n_actions) * T(1/n_actions)
    # println("STG ", stg, " ", norm, " ", cum_regrets)

    util = solve(
        solver, 
        perform(action(gs, idx), gs, gs.player), 
        History(h, K2(idx)), 
        chance_action, 
        pl,
        updatereachprobs!(reach_probs, gs.player, stg), 
        iteration)

    node_util = util * stg
    utils[1] = util

    for i in 2:n_actions
        idx = lga[i]
        
        stg = (norm!=n_actions) * cum_regrets[i]/norm + (norm==n_actions) * T(1/n_actions)

        util = solve(
            solver, 
            perform(action(gs, idx), gs, gs.player), 
            History(h, K2(idx)), 
            chance_action, 
            pl,
            updatereachprobs!(reach_probs, gs.player, stg), 
            iteration)
        
        node_util += util * stg
        utils[i] = util

    end

    # println("State Value ", node_util)
    # println("Utils ", utils)

    #todo: update cumulative regrets and cumulative strategy
    if pl == gs.player
        norm = T(0)

        #todo: we need a better way to get the opponent index
        p1 = reach_probs[(pl == 1) * 2 + (pl == 2) * 1]

        for i in 1:n_actions
            cr = cum_regrets[i]
            res = cr + (utils[i] - node_util) * p1

            # println("Res ", res)
            
            cum_regrets[i] = res * (res > 0)
            norm += cum_regrets[i]
        end

        # println("Cumulative Regrets ", cum_regrets)

        #update cumulative strategy
        norm = (norm == 0) * n_actions + (norm != 0) * norm

        cum_stg = cumulativestrategy!(info, pl)
        p0 = reach_probs[pl]

        for i in 1:n_actions
            cum_stg[i] += ((norm != n_actions) * cum_regrets[i]/norm + (norm == n_actions) * T(1/n_actions)) * p0 * iteration
        end

        # println("Cumulative Policy ", cum_stg)

    end

    return node_util

end

end