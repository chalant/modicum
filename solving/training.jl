using Base

using playing
using games

using solving


function train(
    solver::Solver,
    gs::GameState, 
    g::Game{Training, T}, 
    itr::Iteration, 
    util::Float32) where T <: GameMode
    
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

    for _ in itr
        shuffle!(data.deck)
        distributecards!(root, stp, data)

        for p in stp.players
            util += solve(solver, h, g, p)
        end
        
        putbackcards!(root, stp, data)

    end
end