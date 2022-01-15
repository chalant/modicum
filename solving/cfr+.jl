using solver
using StaticArrays

#todo: need a vectorized version 

struct CFRPlus{N, T<:AbstractFloat} <: Solver
    weight::Float32
end

function regretmatching(::CFRPlus, infoset::Node)

end

@inline function updatestrategy!(
    cum_regrets::StaticVector{A, T}, 
    actions_mask::StaticVector{A, Bool}) where {A, T <: AbstractFloat}
    
    st = @MVector zeros(T, M)

    for a in 1:A
        if actions_mask[a] == 1
            cr = cum_regrets[a]
            r = cr > 0 ? cr : 0
            st[a] = r
            norm += r
    end

    return st

end

function innersolve(
    solver::CFRPlus{N, T}, 
    gs::GameState{A, 2, Game{U}}, 
    g::Game{U}, 
    data::ShareData, 
    h::History{T},
    pl::PlayerState, 
    opp_probs::MVector{N, T}) where {T<:AbstractFloat, U<:GameMode, N}

    ev = @MVector zeros(T, N)

    info_set = infoset(
        MMatrix{N, A, T},
        h, 
        key(privatecards(pl, data)), 
        data.public_cards)
    
    actions = actions!(g)
    actions_mask = actionsmask!(gs)

    #alternatively, we could cache this array in the history
    #node... h.utils we could also store ev in h, to avoid using
    # too much memory... this should be safe since we only use the previous history...

    #use a vector to avoid heap allocations
    utils = @MVector zeros(T, N * A)

    if pl == ps.player
        for a in actions
            if actions_mask[a.id] == 1
                ha = history(h, a.id)

                game_state = ha.game_state

                copy!(game_state, gs)

                perform!(a, game_state, game_state.player)

                i = 1

                for u in innersolve(solver, gs, g, data, h, pl, opp_probs)
                    utils[i] = u
                    i += 1
                end
            end

        end

        for i in 1:N
            stg = updatestrategy!(info_set.cum_regrets[i], actions_mask)
            
            for a in actions
                idx = a.id
                ev[i] += stg[idx] * utils[(i-1) * A + idx] * actions_mask[idx]
            end
        end

        cum_regrets = info_set.cum_regets

        for a in actions
            idx = a.id
            am = actions_mask[idx]
            
            for i in 1:N
                cr = cum_regrets[i][idx]
                cr += am * utils[(idx-1) * N + i]
                cum_regrets[i][idx] = maximum(cr, 0)
            end
        end
    else

    end

    return ev

end

function solve(
    solver::CFRPlus{N, T}, 
    gs::GameState{A, 2, Game{U}},
    g::Game{FullSolving},
    itr::IterationStyle) where {A, N, U <: GameMode}

    stp = setup(g) # game setup
    data = shared(g)
    n = length(stp.actions)
    # root history
    h = History(n, gs, zeros(T, n))
    #=println("Dealer ", last(states).id)
    println("Players Order ", [p.id for p in states])=#

    opp_probs = @MVector ones(T, N)

    for _ in itr
        # need average strategy here
        # need average regret here

        #we could parallelize at this level calculate util for each player
        #then do a summation at the end of the loop.
        #problem: data is shared.

        for p in stp.players
            util += solve(solver, h, g, p)
        end
    
    end

    putbackcards!(root, stp, data)
end