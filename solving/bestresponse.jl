module bestresponse

using infosets

export bestresponse!

#todo: we need to update bestresponse for all players at the same time!
function bestresponse!(
    h::AbstractHistory{AbstractGameState{A, P, FullSolving, T}, U, V, N}, 
    gs::AbstracGameState{A, P, FullSolving, T}, 
    pl::I,
    state::I,
    opp_probs::W) where {N, A, T<:AbstractFloat, V, U<:StaticMatrix{N, A, T}, W<:StaticVector{N, T}, I<:Integer}

    ev = getutils(h)

    if terminal!(state) == true
        return computetutility!(gs, pl, ev)
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
                h,
                game_state,
                pl,
                state,
                opp_probs)
            
            for j in 1:N
                e = ev[j]
                u = utils[j]
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
                new_probs[j] = cs_vector[i]/sum(cs_vector) * op[j]
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

@inline function exploitability(num_players, n)
    return 
end

end