include("tree.jl")
include("games/playing.jl")
include("abstraction/filtering.jl")

using .tree
using .games
using .filtering

abstract type Solver end

struct CFR <: Solver
end

struct MCCFR <: Solver
end

struct CFRP <: Solver
end

# todo add compression data to resources folder
# filter for private cards
const PR_FILTER = Filter(indexdata(IndexData, "/resources/lossless/pre_flop"))

function key(pr::Vector{UInt64}, cc::Vector{UInt64})
    #returns a unique key for a combination of private and public hands
    if length(cc) == 0
        # return equivalent index (after compression)
        return filterindex(PR_FILTER, pr)
    end
    return evaluate(pr, cc)
end

function strategy!(n::Node, h::History, g::Game, stp::GameSetup, w::Float32)
    st = n.stg_profile
    for a in stp.actions
        i = a.id
        if g.actions_mask[a.id] == 1
            cr = n.cum_regret[i]
            r = cr > 0 ? cr : 0
            st[i] = r
            norm += r
        else
            st[i] = 0 # unavailable action
        end
        i += 1
    end

    for a in stp.actions
        i = a.id
        if g.actions_mask[i] == 1
            nr = norm > 0 ? st[i]/norm : 1/g.num_actions
            n.cum_strategy[i] += w * nr
            st[i] = nr
        end
    end

    return st
end

function solve(h::History, game::Game, st::GameState, player::Player, p0::Float32, p1::Float32)
    return solve(h, game, state, p0, p1)
end

function train(g::Game, iterations::Int)
    stp = setup(g) # game setup
    data = shared(g)
    n = length(stp.actions)
    # root history
    h = History(n, g, zeros(Float32, n))

    # need average strategy here
    # need average regret here
    for i in 1:iterations
        for p in stp.players
            #initialize game and run solve
            solve(h, g, start!(g, g.state), player, 1, 1)
        end
    end
end

function solve(h::History, g::Game, st::Terminated, pl::Player, p0::Float32, p1::Float32)
    # todo: compute utility
    return
end

# Implementation of solve functions could depend on the type of algorithm (MCsolve, solve+, ...)
function solve(h::History, g::Game, st::Started, pl::Player, p0::Float32, p1::Float32)
    stp = setup(g)
    data = shared(g)
    # execute actions
    # note: in mcsolve variant, we sample only one action from the adversary
    n = length(stp.actions)
    # retrieve infoset based on player cards and community cards from current history
    info = infoset(h, key(privatecards(pl, data), data.public_cards))
    # get strategy profile of the infoset
    strg = strategy!(info, h, g, stp, pl == g.player ? p0 : p1)
    util::Float32 = 0
    utils = h.utils

    # This block could be specialized (to a type of solver )
    # =========================================================================
    for a in stp.actions
        i = a.id
        #only execute active actions
        if g.actions_mask[i] == 1
            # retrieve history associated with the action
            ha = history(h, a.id, utils, n)
            #copy game data to next history node
            copy!(ha.game, g)
            stg = strg[i]
            if g.player == pl
                # perform action and update game state
                ut = solve(ha, ha.game, perform!(a, ha.game, g.player), p0 * stg, p1)
            else
                # todo finish inputs (p0 and p1)
                ut = solve(ha, ha.game, perform!(a, ha.game, g.player), p0, p1 * stg)
            end
            utils[i] = ut
            util += st * ut
        else
            utils[i] = 0
        end
        i += 1
    end
    p = pl == g.player ? p1 : p0
    # =========================================================================

    # update regrets
    for a in stp.actions
        i = a.id
        if g.actions_mask[i] == 1
            info.cum_regret[i] += p * utils[i] - util
        end
    end
    return util
end

function solve(h::History, g::Game, state::Initializing, pl::Player, p0::Float32, p1::Float32)
    throw("Cannot compute unitialized game")
end
