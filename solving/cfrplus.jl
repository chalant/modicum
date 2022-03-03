module cfrplus

using StaticArrays
using IterTools
using BenchmarkTools
using FunctionWrappers

using TimerOutputs

using games
using solving
using infosets
using kuhn

export CFRPlus
export T1

export solve

struct CFRPlus{P} <: Solver
end

const T1 = TimerOutput()

function playerreachprob!(arr::V, pl::I, i::I, p::T) where {V<:StaticVector, I<:Integer, T<:AbstractFloat}
    return arr[pl] * (p * (pl == i) + (pl != i) * 1)
end

function updatereachprobs!(arr::V, pl::I, p::T) where {N, I<:Integer, T<:AbstractFloat, V<:StaticVector{N, T}}
    # return StaticArrays.sacollect(SVector{N, T}, playerreachprob!(arr, pl, i, p) for i::I in 1:N)
    m = MVector{N, T}(arr)
    m[pl] *= p
    return SVector{N, T}(m)
end

function solve(
    solver::CFRPlus{true},
    gs::G,
    h::H,
    chance_action::C,
    pl::I1,
    reach_probs::P,
    iteration::I2) where {A, I1<:Integer, I2<:Integer, C<:games.ChanceAction, T<:AbstractFloat, P<:StaticVector{3, T}, G<:AbstractGameState{A, FullSolving, 2}, N<:Node, K1<:Integer, K2<:Integer, H<:History{N, K1, K2}}

    # println(typeof(gs), " ", 
    # typeof(h), " ", 
    # typeof(chance_action), " ",
    # typeof(pl), " ",
    # typeof(reach_probs), " ",
    # typeof(iteration))

    # @assert typeof(gs) == KUHNGameState{FullSolving}
    # @assert typeof(h) == History{Node{MVector{2, MVector{3, Float32}}}, UInt64, UInt8}
    # @assert typeof(chance_action) == KUHNChanceAction{UInt8}
    # @assert typeof(pl) == UInt8
    # @assert typeof(reach_probs) == SVector{3, Float32}
    # @assert typeof(iteration) == Int64

    if terminal!(gs) == true       
        return computeutility!(T, gs, pl, chance_action)
    
    elseif chance!(gs) == true
        #pass-in an index to the function so that we can track the
        #which card subset to pass.
        #we will compress actions (public data, by combining with main players private data)
        #that way, we can parallelize without collisions...
        iter = chanceactions!(gs, chance_action)
        next = iterate(iter)

        (a, state) = next

        ha = History(h, a.idx)

        p = chanceprobability!(T, gs, chance_action)

            # game_state = ha.game_state
            # copy!(game_state, gs)

            # state = performchance!(a, game_state, game_state.player)
        # res = @timeit T1 "perform chance" performchance!(a, gs, gs.player)

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

            # game_state = ha.game_state
            # copy!(game_state, gs)

            # state = performchance!(a, game_state, game_state.player)
            # res = @timeit T1 "perform chance" performchance!(a, gs, gs.player)

            ev += solve(
                solver, 
                performchance!(a, gs, gs.player), 
                History(h, a.idx, ha.infosets), 
                a, pl, 
                SVector{3, T}(reach_probs[1], reach_probs[2], reach_probs[3] * p),
                iteration) * p
            
            next = iterate(iter, state)
        end

        return ev
    end

    info = infoset(h, infosetkey(gs, gs.player))

    (lga, n_actions) = games.legalactions!(K2, gs)

    # action_mask = actionsmask!(gs)
    # n_actions = sum(action_mask)


    cum_regrets = cumulativeregrets!(info, gs.player)
    
    norm = sum(T, cum_regrets)
    
    norm = (norm != 0) * norm + n_actions * (norm == 0)


    # actions = actions!(gs)
    
    # lga = games.legalactions!(K2, action_mask, n_actions)

    utils = getutils(h)

    idx = lga[1]
    
    ha = History(h, K2(1))

    # game_state = ha.game_state
    # copy!(game_state, gs)

    # state = perform!(actions[idx], gs, gs.player)

    stg = (norm!=n_actions) * cum_regrets[1]/norm + (norm==n_actions) * T(1/n_actions)

    # new_probs = copy(reach_probs)
    # new_probs[game_state.player] *= stg

    # res = @timeit T1 "perform" perform(actions[idx], gs, gs.player)
    # new_probs = updatereachprobs!(reach_probs, gs.player, stg)

    util = solve(
        solver, 
        perform(action(gs, idx), gs, gs.player), 
        ha, 
        chance_action, 
        pl,
        updatereachprobs!(reach_probs, gs.player, stg), 
        iteration)

    node_util = util * stg
    utils[1] = -util

    for i in 2:n_actions
        idx = lga[i]

        # game_state = ha.game_state
        # copy!(game_state, gs)

        # state = perform!(actions[idx], gs, gs.player)
        
        stg = (norm!=n_actions) * cum_regrets[i]/norm + (norm==n_actions) * T(1/n_actions)

        # @assert typeof(chance_action) == KUHNChanceAction{UInt8}
        # # println(typeof(gs), " ", typeof(perform(actions[idx], gs, gs.player)))
        # @assert typeof(gs) == typeof(perform(actions[idx], gs, gs.player))
        # @assert typeof(ha) == typeof(History(h, i, ha.infosets))
        # @assert typeof(h) == typeof(ha)


        # @assert typeof(new_probs) == typeof(reach_probs)
        # new_probs = copy(reach_probs)
        # new_probs[game_state.player] *= stg
        # res = @timeit T1 "perform" perform(actions[idx], gs, gs.player)

        util = solve(
            solver, 
            perform(action(gs, idx), gs, gs.player), 
            History(h, K2(i), ha.infosets), 
            chance_action, 
            pl,
            updatereachprobs!(reach_probs, gs.player, stg), 
            iteration)
        
        # println(typeof(util), " ", typeof(util1))
        # @assert typeof(util) == typeof(util1)
        
        node_util += util * stg
        utils[i] = -util

    end

    #todo: update cumulative regrets and cumulative strategy
    if pl == gs.player
        cum_stg = cumulativestrategy!(info, pl)

        norm = T(0)

        for i in 1:n_actions
            cr = cum_regrets[i]
            res = cr + (utils[i] - node_util)
            
            #will be zero or res
            cum_regrets[i] = res * (res > 0)
            norm += cum_regrets[i]
        end

        #update cumulative strategy
        norm = (norm == 0) * n_actions + (norm != 0) * norm

        for i in 1:n_actions
            cum_stg[i] += ((norm != n_actions) * cum_regrets[i]/norm + (norm == n_actions) * T(1/n_actions)) * utils[i] * reach_probs[pl] * iteration
        end
    end

    return node_util

end

end