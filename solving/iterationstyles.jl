module iterationstyles

export IterationStyle
export CounterIteration
export TimerIteration

abstract type IterationStyle end

struct CounterIteration <: IterationStyle
    count::UInt64
end

struct CounterState
    index::Int64
end

struct TimerIteration <: IterationStyle
    t0::Float64
    max_time::Float64

    TimerIteration(max_time) = new(time(), max_time)
end

function Base.iterate(iteration::CounterIteration, state=1)
    if state <= iteration.count
        return (state, state+1)
    else
        return nothing
    end
end

function Base.iterate(timer::TimerIteration, state=(0, timer.t0, 0))
    count, t0, elapsed = state
    
    t = time()
    dt = t - t0

    #we assume that the next iteration will take the same amount of time...
    #todo: count how many times the predictions are correct and use that as weight
    # to compute mean time.

    # initial_prediction = 2 * dt
    # x, error = (isequal(previous_prediction, dt, timer.tolerance) + p) / count

    # x : probability of being right

    # prediction = x * previous_prediction + (1 - x) * (previous_prediction + error)


    if elapsed + 2*dt >= timer.max_time
        # println("elapsed ", elapsed + dt)
        return nothing
    # #predict using mean elapsed time
    # elseif elapsed + 2*(elapsed+dt)/(count + 1) >= timer.max_time
    #     println("predicted ", elapsed + dt)
    #     return nothing
    else
        return (count, (count + 1, t, elapsed + dt))
    end

end

end