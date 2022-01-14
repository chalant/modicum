module

    abstract type IterationStyle end

    struct Counter <: IterationStyle
        count::UInt64
    end

    struct CounterState
        index::Int64
    end

    mutable struct Timer <: IterationStyle
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
end
