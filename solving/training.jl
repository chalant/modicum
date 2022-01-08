using Base

using playing
using games

using solving

abstract type Iteration end

struct Counter <: Iteration
    count::UInt64
end

struct CounterState
    index::Int64
end

mutable struct Timer <: Iteration
    t0::Float64
    elapsed::Float64
    max_time::Float64

    Timer(max_time) = new(time(), 0, max_time)
end

function Base.iterate(iteration::Counter, state=1)
    if state < iteration.count
        return (nothing, state+1)
    else
        return nothing
    end
end

function Base.iterate(timer::Timer, state=0)
    dt = time() - time.t0

    if timer.elapsed + dt >= timer.max_time
        return nothing
    
    #predit if the next loop will put us over the max time.
    elseif state != 0 && (timer.elapsed + (timer.elapsed + dt)/state) >= timer.max_time
        return nothing
    
    else
        timer.elapsed += dt
        timer.t0 = time()

        return (nothing, state + 1)
    end

end

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