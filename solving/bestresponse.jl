module bestresponse

using StaticArrays
using infosets

export bestresponse!

mutable struct BRHistory{U<:StaticVector, K1<:Integer, K2<:Integer}
    histories::Dict{K1, BRHistory{U, K}}
    strategies::Dict{K2, U}
end

@inline function addstrategy(h::H, key::K) where {A, P, K1<:Integer, K2<:Integer, T<:Real, V<:StaticVector{A, T}, U<:StaticVector{P, V}, H<:BRHistory{U, K1, K2}}
    r = T(1/A)
    stg = StaticArrays.sacollect(U, StaticArrays.sacollect(V, r for _ in 1:A) for _ in 1:P)
    h.strategies[key] = stg
    return stg
end

@inline function addstrategy(h::H, key::K) where {A, K1<:Integer, K2<:Integer, T<:Real, V<:StaticVector{A, T}, H<:BRHistory{V, K1, K2}}
    r = T(1/A)
    stg = StaticArrays.sacollect(V, r for _ in 1:A)
    h.strategies[key] = stg
    return stg
end

@inline function infosets.history(h::H, action_idx::K, strategies::I) where {U<:StaticVector, K1<:Integer, K2<:Integer, H<:BRHistory{U, K1, K2}, I<:Dict{K2, U}}
    hist = h.histories
    
    if haskey(hist, action_idx) == true
        return hist[action_idx]
    else
        #pass a reference to the infosets
        hst =  BRHistory{U, K}(
            Dict{K,  BRHistory{U, K}}(),
            strategies)

        hist[action_idx] = hst
        
        return hst

    end
end

@inline function infosets.history(h::H, action_idx::K) where {U<:StaticVector, K<:Integer, K2<:Integer, H<:BRHistory{U, K, K2}}
    hist = h.histories
    
    if haskey(hist, action_idx) == true
        return hist[action_idx]
    else
        #pass a reference to the infosets
        hst =  BRHistory{U, K, K2}(
            Dict{K,  BRHistory{U, K}}(),
            Dict{K2, U}())

        hist[action_idx] = hst
        
        return hst

    end
end

BRHistory(::Type{U}) where {A, K1<:Integer, K2<:Integer, N<:AbstractFloat, U<:StaticVector{A, N}} = BRHistory{U, K1, K2}(Dict{K1, BRHistory{U, K1, K2}}(), Dict{K2, U}())
BRHistory(::Type{V}) where {A, P, K1<:Integer, K2<:Integer, N<:AbstractFloat, U<:StaticVector{A, N}, V<:StaticVector{P, U}} = BRHistory{V, K1, K2}(Dict{K1, BRHistory{V, K1, K2}}(), Dict{K2, U}())
BRHistory(::Type{N}) where {P, K1<:Integer, K2<:Integer, N<:AbstractFloat, V<:StaticVector{P, N}} = BRHistory{V, K1, K2}(Dict{K1, BRHistory{V, K1, K2}}(), Dict{K2, N}())
BRHistory(::Type{N}) where {K1<:Integer, K2<:Integer, N<:AbstractFloat} = BRHistory{N, K1, K2}(Dict{K1, BRHistory{N, K1, K2}}(), Dict{K2, N}())

BRHistory(h::H, idx::K1) where {A, P, K1<:Integer, K2<:Integer, T<:AbstractFloat, V<:StaticArray{A, T}, U<:StaticArray{P, V}, H<:BRHistory{U, K1, K2}} = history(h, idx)
BRHistory(h::H, strategies::S, idx::K) where {} = history(h, idx, strategies)

@inline function getstrategy(h::H, key::K2, pl::I) where {A, P, K1<:Integer, K2<:Integer, N<:AbstractFloat, U<:StaticVector{A, N}, V<:StaticVector{P, U}, H<:BRHistory{V, K1, K2}}
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
    return StaticArrays.sacollect(SVector{N, T}, playerreachprob!(arr, pl, i, p) for i in 1:N)
end

@inline function getstrategy!(h::S, key::K, pl::I) where {A, P, I<:Integer, K<:Integer, T<:Real, U<:StaticVector{A, T}, V<:StaticVector{P,U}, S<:BRHistory{V, K1, K2}}
    return h.strategies[key][pl]
end

@inline function getstrategy!(h::S, key::K, pl::I) where {A, I<:Integer, K<:Integer, T<:Real, U<:StaticVector{A, T}, S<:BRHistory{U, K1, K2}}
    return h.strategies[key]
end

@inline function getstrategy!(h::S, key::K, pl::I) where {P, I<:Integer, K<:Integer, T<:Real, V<:StaticVector{P, T}, S<:BRHistory{V, K1, K2}}
    return h.strategies[key][pl]
end

@inline function setstrategy!(key::I1, h::H, pl::I2, max_action::I3) where {A, P, I1<:Integer, I2<:Integer, I3<:Integer, K<:Integer, U<:StaticVector{A, T}, V<:StaticVector{P, U}, H<:BRHistory{V, I1, K}}
    stg = h.strategies[key][pl]
    
    for i in eachindex(stg)
        stg[i] = (max_action == i) * 1
    end
end

@inline function setstrategy!(key::I1, h::H, pl::I2, max_action::I3) where {P, I1<:Integer, I2<:Integer, I3<:Integer, K<:Integer, T<:Real, V<:StaticVector{P, T}, H<:BRHistory{V, I1, K}}
    h.strategies[key][pl] = max_action
end

function bestresponse!(
    gs::G,
    h::History{G, U, V, K},
    br_h::BRHistory{U, K1, K2},
    chance_action::C,
    pl::I,
    state::I,
    reach_probs::P) where {A, V, C<:ChanceAction, K1<:Integer, K2<:Integer, I<:Integer, T<:AbstractFloat, P<:StaticVector{3, T}, U<:StaticVector{A, T}, G<:AbstracGameState{A, 2, FullSolving, T}}

    if terminal!(gs, state) == true
        return computeutility!(gs, pl)
    
    elseif chance!(gs, state) == true

        node_util = T(0)
        
        for a in chanceactions!(gs, chance_action)
            ha = history(h, a)

            p = chanceprobability!(gs, chance_action)

            game_state = ha.game_state
            copy!(game_state, gs)

            state = performchance!(a, game_state, game_state.player)
            
            node_util += bestresponse!(
                gs, ha, br_ha, 
                chance_action, 
                pl, state, 
                @SVector [probs[1], probs[2], probs[3] * p]) * p

        end

        return node_util
    
    end

    actions_mask = actionsmask!(gs)

    n_actions = sum(actions_mask)
    actions = actions!(gs)

    #todo: best response uses another type of key

    key = infosetkey(gs)

    info = infoset(h, key)
    cum_regrets = info.cum_regrets
    
    br_strategy = getstrategy(br_h, key, pl)

    norm = T(0)

    for cr in cum_regrets
        norm += (cr > 0) * cr
    end
    
    norm = (norm > 0) * norm + n_actions * (norm <= 0)
    lgs = legalactions!(actions_mask, n_actions)

    #create best response strategy for history and infoset
    if pl == gs.player

        max_action = 1
        
        idx = lgs[1]

        ha = history(h, idx)
        br_ha = history(br_h, idx, br_h.strategies)

        copy!(ha.game_state, gs)

        state = perform!(actions[a], ha.game_state, game_state.player)
        
        val = bestresponse!(
            gs, ha,
            br_ha,
            chance_action,
            pl, state, 
            reach_probs) * p

        for i in 2:n_actions
            idx = lgs[i]

            br_ha = history(br_h, idx, br_h.infosets)
            ha = history(h, idx, h.infosets)

            copy!(ha.game_state, gs)

            state = perform!(actions[a], ha.game_state, game_state.player)
            
            util = bestresponse!(
                gs, ha,
                br_ha,
                chance_action,
                pl, state, 
                new_probs)

            cond = val < util

            val = cond * util + !cond * val

            max_action += cond * 1 + !cond * 0

        end

        setstrategy!(key, br_h, pl, max_action)
        #set the best response strategy

        return val
    end
    
    cum_strategy = info.cum_strategy
    norm = sum(cum_strategy)
    util = T(0)

    for i in 1:n_actions
        idx = lgs[i]

        ha = history(h, idx)
        game_state = ha.game_state
        
        copy!(gamestate, gs)

        state = perform!(actions[idx], game_state, game_state.player)

        stg = cum_strategy[idx]/norm

        util += bestresponse!(
            gs, ha, br_ha, 
            chance_action, pl, state, 
            updatereachprobs!(reach_probs, pl, stg)) * stg
    end

    return util
end

#todo: we need to update bestresponse for all players at the same time!
function bestresponse!(
    h::VHistory{G, U, V, N, K}, 
    gs::G, 
    pl::I,
    state::I,
    opp_probs::W) where {N, A, K<:Integer, T<:AbstractFloat, V, U<:StaticMatrix{N, A, T}, W<:StaticVector{N, T}, I<:Integer, G<:AbstracGameState{A, P, FullSolving, T}}

    ev = getutils(h)

    if terminal!(gs, state) == true
        return computetutility!(gs, pl, ev)
    elseif chance!(gs, state) == true
        nextround!(gs, pl)
    end

    actions_mask = actionsmask!(gs)

    n_actions = sum(actions_mask)
    actions = actions!(gs)

    info_set = infoset(V, h, infosetkey(gs))
    lga = legalactions!(actions_mask, n_actions)

    if pl == gs.player
        for i in 1:n_actions
            idx = lga[i]

            ha = history(h, idx)
            
            game_state = ha.game_state
            
            copy!(game_state, gs)

            state = perform!(actions[idx], game_state, game_state.player)

            utils = bestresponse!(
                ha,
                game_state,
                pl,
                state,
                opp_probs)
            
            for j in 1:N
                e = ev[j]
                u = utils[j]
                #select the maximum value
                ev[j] = (e > u) * e + (e <= u) * u
            end

        end
    else
        new_probs = getprobs(opp_probs)
        cum_strategy = info_set.cum_strategy

        for i in 1:n_actions
            idx = lga[i]

            for j in 1:N
                cs_vector = @view cum_strategy[j, :]
                new_probs[j] = cs_vector[i]/sum(cs_vector) * opp_probs[j]
            end

            ha = history(h, idx)
            game_state = ha.game_state
            
            copy!(gamestate, gs)

            state = perform!(actions[idx], game_state, game_state.player)

            utils = bestresponse!(ha, gs, pl, state, new_probs)

            for j in 1:N
                ev[j] += utils[j]
            end
        end
    end

    return ev
end

end