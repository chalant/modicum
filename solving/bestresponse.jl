module bestresponse

using StaticArrays

using infosets
using games
using solving

export bestresponse!
export BRHistory

mutable struct BRHistory{V<:StaticVector, K1<:Integer, K2<:Integer}
    strategies::Dict{K1, V}
    histories::Dict{K2, BRHistory{V, K1, K2}}
end

# @inline function addstrategy(h::H, key::K2) where {A, P, K1<:Integer, K2<:Integer, T<:Real, V<:StaticVector{A, T}, U<:StaticVector{P, V}, H<:BRHistory{U, K1, K2}}
#     r = T(1/A)
#     stg = StaticArrays.sacollect(U, StaticArrays.sacollect(V, r for _ in 1:A) for _ in 1:P)
#     h.strategies[key] = stg
#     return stg
# end

# @inline function addstrategy(h::H, key::K2) where {A, K1<:Integer, K2<:Integer, T<:Real, V<:StaticVector{A, T}, H<:BRHistory{V, K1, K2}}
#     r = T(1/A)
#     stg = StaticArrays.sacollect(V, r for _ in 1:A)
#     h.strategies[key] = stg
#     return stg
# end

# @inline function infosets.history(h::H, action_idx::K1, strategies::I) where {U<:StaticVector, K1<:Integer, K2<:Integer, H<:BRHistory{K1, K2}, I<:Dict{K2, Int64}}
#     hist = h.histories
    
#     if haskey(hist, action_idx) == true
#         return hist[action_idx]
#     else
#         #pass a reference to the infosets
#         hst =  BRHistory{U, K}(
#             Dict{K,  BRHistory{U, K}}(),
#             strategies)

#         hist[action_idx] = hst
        
#         return hst

#     end
# end

@inline function infosets.history(h::H, action_idx::K2) where {V<:StaticVector, K<:Integer, K2<:Integer, H<:BRHistory{V, K, K2}}
    hist = h.histories
    
    if haskey(hist, action_idx) == true
        return hist[action_idx]
    else
        #pass a reference to the infosets
        hst =  BRHistory{V, K, K2}(
            Dict{K2, V}(),
            Dict{K,  BRHistory{V, K, K2}}())

        hist[action_idx] = hst
        
        return hst

    end
end

BRHistory(::Type{H}) where {A, T<:AbstractFloat, U<:StaticVector{A, T}, N<:Node{U}, K1<:Integer, K2<:Integer,  H<:History{N, K1, K2}} = BRHistory{U, K1, K2}(Dict{K1, U}(), Dict{K2, BRHistory{U, K1, K2}}())
BRHistory(::Type{H}) where {A, P, T<:AbstractFloat, U<:StaticVector{A, T}, V<:StaticVector{P, U}, N<:Node{V}, K1<:Integer, K2<:Integer, H<:History{N, K1, K2}} = BRHistory{U, K1, K2}(Dict{K1, U}(), Dict{K2, BRHistory{U, K1, K2}}())

# BRHistory(::Type{U}) where {A, K1<:Integer, K2<:Integer, N<:AbstractFloat, U<:StaticVector{A, N}} = BRHistory{U, K1, K2}(Dict{K1, BRHistory{U, K1, K2}}(), Dict{K2, U}())
# BRHistory(::Type{V}) where {A, P, K1<:Integer, K2<:Integer, N<:AbstractFloat, U<:StaticVector{A, N}, V<:StaticVector{P, U}} = BRHistory{V, K1, K2}(Dict{K1, BRHistory{V, K1, K2}}(), Dict{K2, U}())
# BRHistory(::Type{V}) where {P, K1<:Integer, K2<:Integer, N<:AbstractFloat, V<:StaticVector{P, N}} = BRHistory{V, K1, K2}(Dict{K1, BRHistory{V, K1, K2}}(), Dict{K2, N}())
# BRHistory(::Type{N}) where {K1<:Integer, K2<:Integer, N<:AbstractFloat} = BRHistory{N, K1, K2}(Dict{K1, BRHistory{N, K1, K2}}(), Dict{K2, N}())

# BRHistory(h::H, idx::K1) where {A, P, K1<:Integer, K2<:Integer, T<:AbstractFloat, V<:StaticArray{A, T}, U<:StaticArray{P, V}, H<:BRHistory{U, K1, K2}} = history(h, idx)
# BRHistory(h::H, strategies::S, idx::K) where {K<:Integer, S<:Dict, H<:BRHistory} = history(h, idx, strategies)

@inline function getstrategy(h::H, key::K2, pl::I) where {A, P, I<:Integer, K1<:Integer, K2<:Integer, H<:BRHistory{K1, K2}}
    if haskey(h.strategies, key) == true
        return h.strategies[key][pl]
    else
        return addstrategy(h, key)
    end
end

@inline function playerreachprob!(arr::V, pl::I, i::I, p::T) where {V<:StaticVector, I<:Integer, T<:AbstractFloat}
    arr[pl] * (p * (pl == i) + (pl != i) * 1)
end

@inline function updatereachprobs!(arr::V, pl::I, p::T) where {N, I<:Integer, T<:AbstractFloat, V<:StaticVector{N, T}}
    return StaticArrays.sacollect(SVector{N, T}, playerreachprob!(arr, pl, i, p) for i::I in 1:N)
end

# @inline function getstrategy!(h::S, key::K2, pl::I) where {A, P, I<:Integer, K1<:Integer, K2<:Integer, T<:Real, U<:StaticVector{A, T}, V<:StaticVector{P,U}, S<:BRHistory{V, K1, K2}}
#     return h.strategies[key][pl]
# end

# @inline function getstrategy!(h::S, key::K2, pl::I) where {A, I<:Integer, K<:Integer, K2<:Integer, T<:Real, U<:StaticVector{A, T}, S<:BRHistory{U, K, K2}}
#     return h.strategies[key]
# end

# @inline function getstrategy!(h::S, key::K2, pl::I) where {P, I<:Integer, K1<:Integer, K2<:Integer, T<:Real, V<:StaticVector{P, T}, S<:BRHistory{V, K1, K2}}
#     return h.strategies[key][pl]
# end

# @inline function setstrategy!(key::K, h::H, pl::I2, max_action::I3) where {A, P, I1<:Integer, I2<:Integer, I3<:Integer, K<:Integer, T<:AbstractFloat, U<:StaticVector{A, T}, V<:StaticVector{P, U}, H<:BRHistory{V, I1, K}}
#     stg = h.strategies[key][pl]
    
#     for i in eachindex(stg)
#         stg[i] = (max_action == i) * 1
#     end
# end

# @inline function setstrategy!(key::K, h::H, pl::I2, max_action::I3) where {P, I1<:Integer, I2<:Integer, I3<:Integer, K<:Integer, T<:Real, V<:StaticVector{P, T}, H<:BRHistory{V, I1, K}}
#     h.strategies[key][pl] = max_action
# end

function bestresponse!(
    gs::G,
    h::H,
    br_h::BH,
    pl::I,
    reach_probs::V) where {A, P, I<:Integer, T<:AbstractFloat, V<:StaticVector{2, T}, G<:AbstractGameState{A, FullSolving, P}, N<:Node, K1<:Integer, K2<:Integer, H<:History{N, K1, K2}, U<:StaticVector, BH<:BRHistory{U, K1, K2}}

    if terminal!(gs) == true
        # println("Hello! ", -computeutility!(T, gs, pl)[gs.player])
        return -computeutility!(T, gs, pl)[gs.player]
    end

    lgs, n_actions = legalactions!(K2, gs)

    key = infosetkey(gs, gs.player)
    info = infoset(h, key)

    #create best response strategy for history and infoset
    if pl == gs.player

        max_action = 1
        
        idx = lgs[1]

        br_ha = history(br_h, K2(idx))

        vals = @MVector zeros(T, A)
        
        val = bestresponse!(
            perform(action(gs, idx), gs, gs.player), 
            History(h, K2(idx)),
            br_ha,
            pl,
            reach_probs)
        
        vals[1] = val

        for i in 2:n_actions
            idx = lgs[i]
            
            util = bestresponse!(
                perform(action(gs, idx), gs, gs.player), 
                History(h, K2(idx)),
                history(br_h, K2(idx)),
                pl,
                reach_probs)

            cond = val < util

            #set maximum value
            # val = setindex(
            #     val,
            #     cond * util[gs.player] + !cond * val[gs.player], i)
            
            val = cond * util + !cond * val

            vals[i] = util

            max_action += cond * 1 + !cond * 0

        end

        if (key in keys(br_h.strategies)) == false
            br_h.strategies[key] = @SVector zeros(T, A)
        end

        br_h.strategies[key] = br_h.strategies[key] + reach_probs[(gs.player == 1) * 2 + (gs.player == 2) * 1] * vals

        return -val
    end
    
    cum_strategy = cumulativestrategy!(info, pl)

    norm = sum(cum_strategy)

    idx = lgs[1]

    stg = cum_strategy[1]/norm

    ha = History(h, K2(idx))
    br_ha = history(br_h, K2(idx))
    
    util = bestresponse!(
        perform(action(gs, idx), gs, gs.player),
        ha,
        br_ha,
        pl,
        updatereachprobs!(reach_probs, gs.player, stg)) * stg

    for i in 2:n_actions
        idx = lgs[i]

        stg = cum_strategy[i]/norm
        
        util += bestresponse!(
            perform(action(gs, idx), gs, gs.player), 
            History(h, K2(idx)),
            history(br_h, K2(idx)),
            pl,
            updatereachprobs!(reach_probs, gs.player, stg)) * stg
    end

    return -util
end

function bestresponse!(
    gs::G,
    h::H,
    chance_action::C,
    pl::I,
    reach_probs::V) where {A, P, C<:games.ChanceAction, I<:Integer, T<:AbstractFloat, V<:StaticVector{3, T}, G<:AbstractGameState{A, FullSolving, P}, N<:Node, K1<:Integer, K2<:Integer, H<:History{N, K1, K2}}

    if terminal!(gs) == true
        return -computeutility!(T, gs, pl, chance_action)[gs.player]
    
    elseif chance!(gs) == true
        #todo: we need to initialize for chance actions...

        iter = chanceactions!(gs, chance_action)
        next = iterate(iter)

        (a, state) = next

        ha = History(h, a.arr[gs.player])

        p = chanceprobability!(T, gs, chance_action)

        node_util = bestresponse!(
            performchance!(a, gs, gs.player), 
            ha,
            a, 
            pl,
            @SVector [reach_probs[1], reach_probs[2], reach_probs[3] * p]) * p
        
        next = iterate(iter, state)
        
        while next !== nothing

            (a, state) = next

            p = chanceprobability!(T, gs, chance_action)

            # game_state = ha.game_state
            # copy!(game_state, gs)

            # state = performchance!(a, game_state, game_state.player)
            
            node_util += bestresponse!(
                performchance!(a, gs, gs.player), 
                History(h, a.arr[gs.player]),
                a, 
                pl,
                @SVector [reach_probs[1], reach_probs[2], reach_probs[3] * p]) * p
            
            next = iterate(iter, state)
        end

        return node_util
    
    end

    lgs, n_actions = legalactions!(K2, gs)

    # n_actions = sum(actions_mask)
    # actions = actions!(gs)

    info = infoset(h, infosetkey(gs, chance_action))
    # cum_regrets = cumulativeregrets!(info, gs.player)
    
    # br_strategy = getstrategy(br_h, key, pl)

    # norm = T(0)

    # for cr in cum_regrets
    #     norm += (cr > 0) * cr
    # end
    
    # norm = (norm > 0) * norm + n_actions * (norm <= 0)
    # lgs = legalactions!(K2, actions_mask, n_actions)

    #create best response strategy for history and infoset
    if pl == gs.player

        # max_action = 1
        
        idx = lgs[1]

        # ha = history(h, idx)
        # br_ha = history(br_h, idx, br_h.strategies)

        # copy!(ha.game_state, gs)

        # state = perform!(actions[a], ha.game_state, game_state.player)
        
        val = bestresponse!(
            perform(action(gs, idx), gs, gs.player), 
            History(h, K2(idx)),
            chance_action,
            pl,
            reach_probs)

        for i in 2:n_actions
            idx = lgs[i]

            # br_ha = history(br_h, idx, br_h.infosets)
            # ha = history(h, idx, h.infosets)

            # copy!(ha.game_state, gs)

            # state = perform!(actions[a], ha.game_state, game_state.player)
            
            util = bestresponse!(
                perform(action(gs, idx), gs, gs.player), 
                History(h, K2(idx)),
                chance_action,
                pl,
                reach_probs)

            cond = val[gs.player] < util[gs.player]

            #set maximum value
            val = setindex(
                val,
                cond * util[gs.player] + !cond * val[gs.player],
                Int64(gs.player))

            # max_action += cond * 1 + !cond * 0

        end

        # setstrategy!(key, br_h, pl, max_action)
        #set the best response strategy
        
        return val
    end
    
    cum_strategy = cumulativestrategy!(info, gs.player)

    norm = sum(cum_strategy)

    idx = lgs[1]

    stg = cum_strategy[1]/norm

    ha = History(h, K2(idx))
    
    util = bestresponse!(
        perform(action(gs, idx), gs, gs.player),
        ha,
        chance_action,
        pl,
        updatereachprobs!(reach_probs, pl, stg)) * stg

    for i in 2:n_actions
        idx = lgs[i]

        # ha = history(h, idx)
        # game_state = ha.game_state
        
        # copy!(gamestate, gs)

        # state = perform!(actions[idx], game_state, game_state.player)

        stg = cum_strategy[i]/norm

        util += bestresponse!(
            perform(action(gs, idx), gs, gs.player), 
            History(h, K2(idx)),
            chance_action, 
            pl,
            updatereachprobs!(reach_probs, pl, stg)) * stg
    end

    return util
end

end