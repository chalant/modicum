include("tree.jl")
include("games/playing.jl")
include("abstraction/filtering.jl")

using .tree
using .games
using .filtering

# todo add compression data to resources folder
# filter for private cards
const PreFlopFilter = Filter(indexdata(
    IndexData, 
    "/resources/lossless/pre_flop"))

function key(pr::Vector{UInt64}, cc::Vector{UInt64})
    #returns a unique key for a combination of private and public hands
    if length(cc) == 0
        # return equivalent index (after compression)
        return filterindex(PreFlopFilter, pr)
    end
    return evaluate(pr, cc)
end

function updatestrategy!(info_set::Node, h::History, g::Game, stp::GameSetup, w::Float32)
    st = info_set.stg_profile
    i = 1
    for a in stp.actions
        if g.actions_mask[i] == 1
            cr = n.cum_regret[i]
            r = cr > 0 ? cr : 0
            st[i] = r
            norm += r
        else
            st[i] = 0 # unavailable action
        end
        i += 1
    end

    i = 1
    for a in stp.actions
        if g.actions_mask[i] == 1
            nr = norm > 0 ? st[i]/norm : 1/g.num_actions
            n.cum_strategy[i] += w * nr
            st[i] = nr
        end
        i += 1
    end

    return st
end

function solve(
    h::History,
    game::Game,
    st::GameState,
    player::Player,
    p0::Float32,
    p1::Float32)

    return solve(h, game, state, p0, p1)
end

function solve(
    h::History,
    g::Game{Full,U},
    st::Terminated,
    pl::Player,
    p0::Float32,
    p1::Float32) where U <: GameMode
    # todo: compute utility
    return
end

function solve(
    h::History,
    g::Game{DepthLimited{T},U},
    st::Terminated,
    pl::Player,
    p0::Float32,
    p1::Float32) where {T <: Estimation, U <: GameMode}
end

# Implementation of solve functions could depend on the type of algorithm (MCsolve, solve+, ...)
function solve(
    gs::GameState,
    g::Game{Training, T},
    h::History,
    p0::U,
    p1::U) where {T <: GameMode, U <: AbstractFloat}

    stp = setup(g)
    data = shared(g)
    # execute actions
    # note: in mcsolve variant, we sample only one action from the adversary
    n = length(stp.actions)
    # retrieve infoset based on player cards and community cards from current history
    info = infoset(
        h, 
        key(privatecards(pl, data), 
        data.public_cards))
    
    # get strategy profile of the infoset
    strg = strategy!(info, h, g, stp, pl == g.player ? p0 : p1)
    util = Float32(0)
    utils = h.utils

    # This block could be specialized (to a type of solver )
    # =========================================================================
    i = 1
    ply = gs.player

    for a in viewactions(gs, ply)
        #only execute active actions
        if actionsmask(ply)[i] == 1
            # retrieve history associated with the action
            ha = history(h, a.id, utils, n)
            #copy game data to next history node
            copy!(ha.game_state, gs)
            stg = strg[i]
            
            game_state = ha.game_state

            if g.player == pl
                # perform action and update game state
                ut = solve(ha, game_state, perform!(a, game_state, gs.player), p0 * stg, p1)
            else
                # todo finish inputs (p0 and p1)
                ut = solve(ha, game_state, perform!(a, game_state, gs.player), p0, p1 * stg)
            end
            utils[i] = ut
            util += st * ut
        else
            utils[i] = 0
        end
        i += 1
    end

    p = pl == ply ? p1 : p0
    # =========================================================================

    # update regrets
    i = 1
    for a in stp.actions
        if g.actions_mask[i] == 1
            info.cum_regret[i] += p * utils[i] - util
        end
        i += 1
    end
    return util
end
