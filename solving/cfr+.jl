using solver
using StaticArrays

struct CFRPlus{N} <: Solver
    weight::Float32
    opp_probs::SVector{N, Float32}
end

function regretmatching(::CFRPlus, infoset::Node)

end

function innersolve(solver, infoset)

function solve(
    solver::CFRPlus, 
    gs::GameState,
    g::Game{Training, T},
    h::History) where T <: GameMode

    stp = setup(g) # game setup
    data = shared(g)
    n = length(stp.actions)
    # root history
    h = History(n, gs, zeros(Float32, n))
    #=println("Dealer ", last(states).id)
    println("Players Order ", [p.id for p in states])=#

    # need average strategy here
    # need average regret here

    #we could parallelize at this level calculate util for each player
    #then do a summation at the end of the loop.
    #problem: data is shared.

    for p in stp.players
        util += solve(solver, h, g, p)
    end
    
    putbackcards!(root, stp, data)
end