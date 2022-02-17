module bestresponse

using StaticArrays
using infosets

export bestresponse!

mutable struct BestResponseHistory{U<:StaticVector, K<:Unsigned}
    histories::Dict{K, BestResponseHistory{U, K}}
    strategies::Dict{K, U}
end

@inline function infosets.infoset!(::Type{U}, h::BestResponseHistory{U, K}, key::K)

end

@inline function infosets.history(h::H, action_idx::K, infosets::I) where {A, T<:AbstractFloat, U<:StaticVector{A, T}, K<:Unsigned, H<:BestResponseHistory{U, K}, I<:Dict{K, U}}
    hist = h.histories
    
    if haskey(hist, action_idx)
        return hist[action_idx]
    else
        #pass a reference to the infosets
        hst =  BestResponseHistory{U, K}(
            infosets, 
            Dict{K,  BestResponseHistory{U, K}}(), 
            T())

        hist[action_idx] = hst
        
        return hst

    end
end

@inline function infosets.history(h::H, action_idx::K) where {A, T<:AbstractFloat, U<:StaticVector{A, T}, K<:Unsigned, H<:BestResponseHistory{U, K}}
    hist = h.histories
    
    if haskey(hist, action_idx)
        return hist[action_idx]
    else
        #pass a reference to the infosets
        hst = BestResponseHistory{U, K}(
            Dict{K, U}, 
            Dict{K, BestResponseHistory{U, K}}(), 
            T())

        hist[action_idx] = hst
        
        return hst

    end
end

function bestresponseforaction(a::C, action_idx::K, norm::T, vals::V, gs::G, h::History{G, U, V}, pl::Integer, state::Integer, p::T)
    ha = history(h, action_idx)

    game_state = ha.game_state

    #copy game state into buffer
    copy!(game_state, gs)

    #perform action and update state of copy
    state = perform!(a, game_state, game_state.player)

    cr = cum_regrets[action_idx]

    stg = (cr > 0) * cr/norm
    
    vals[action_idx] = bestresponse(gs, ha, pl, state)

end

function bestresponse!(
    gs::G,
    h::History{G, U, V, K},
    br_h::BestResponseHistory{G, U, K},
    chance_action::C,
    pl::I,
    state::I,
    reach_probs::P) where {A, V, C<:ChanceAction, K<:Integer, I<:Integer, T<:AbstractFloat, P<:StaticVector{3, T}, U<:StaticVector{A, T}, G<:AbstracGameState{A, 2, FullSolving, T}}

    if terminal!(gs, state) == true
        return computeutility!(gs, pl)
    
    elseif chance!(gs, state) == true

        node_util = T(0)
        
        for a in chanceactions!(gs, chance_action)
            ha = history(h, a)

            p = chanceprobability!(gs, chance_action)

            game_state = ha.game_state
            copy!(game_state, gs)

            new_probs = copy(probs)

            new_probs[3] *= p

            state = performchance!(a, game_state, game_state.player)
            #todo: should we multiply by chance probability?
            
            node_util += bestresponse!(
                gs, ha, br_ha, 
                chance_action, 
                pl, state, 
                new_probs) * p

        end

        return node_util
    
    end

    actions_mask = actionsmask!(gs)

    n_actions = sum(actions_mask)
    actions = actions!(gs)

    key = infosetkey(gs)

    info = infoset(U, h, key)
    cum_regrets = info.cum_regrets

    br_strategies = br_h.strategies

    if haskey(br_strategies, key) == false
        br_strategies[key] = @MVector zeros(T, A)
    end
    
    br_strategy = br_strategies[key]

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
        br_ha = history(br_h, idx, br_h.infosets)

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

        #set the best response strategy
        for i in eachindex(br_strategy)
            br_strategy[i] = (max_action == i) * 1
        end

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
        
        new_probs = copy(reach_probs)
        

        stg = cum_strategy[idx]/norm

        new_probs[pl] *= stg

        util += bestresponse!(gs, ha, br_ha, pl, state, new_probs) * stg
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