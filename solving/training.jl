include("solving/solving.jl")
include("games/games.jl")

using .solving

abstract type Iterations end

struct Counter <: Iterations
    it::UInt64
end

struct Timer <: Iterations
    t::UInt64
end

function train(g::Game, itr::Counter, util::Float32=0.0)
    stp = setup(g) # game setup
    data = shared(g)
    n = length(stp.actions)
    # root history
    h = History(n, g, zeros(Float32, n))
    #=println("Dealer ", last(states).id)
    println("Players Order ", [p.id for p in states])=#

    # need average strategy here
    # need average regret here

    util::Float32 = 0

    #we could parallelize at this level calculate util for each player
    #then do a summation at the end of the loop.
    #problem: data is shared.
    # we could parallelize


    for i in 1:itr.it
        shuffle!(data.deck)
        distributecards!(root, stp, data)

        for p in stp.players
            util += solve(h, g, start!(g), p, 1, 1)
        end
        putbackcards!(root, stp, data)
    end
end

function train(g::Game, itr::Timer, util::Float32=0.0)
    #todo
end