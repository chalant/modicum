module

export epsilongreedysample!
export limit!
export DepthLimitedSolving
export FullSolving

abstract type Solver end
abstract type Solving end

using playing
using games

# todo add compression data to resources folder
# filter for private cards
const PreFlopFilter = Filter(indexdata(
    IndexData, 
    "/resources/lossless/pre_flop"))

@inline function key(pr::Vector{UInt64}, cc::Vector{UInt64})
    #returns a unique key for a combination of private and public hands
    if length(cc) == 0
        # return equivalent index (after compression)
        return filterindex(PreFlopFilter, pr)
    end

    return evaluate(pr, cc)
end

@inline function randomsample!(wv::Vector{Bool})
    n = length(wv)
    t = rand()
    i = 1
    cw = 0

    #count active actions (could use game.num_actions instead)
    c = 0
    
    for j in 1:n
        if @inbounds wv[j] == 1
            c += 1
        end
    end

    while i < n
        @inbounds cw += wv[i]/c

        if t < cw
            break
        end

        i += 1
    end

    return i
end

@inline function weightedsample!(
    strategy::Vector{T},
    action_mask::Vector{T})

    n = length(wv)
    i = 1
    
    cw = Float32(0)

    while i < n
        @inbounds cw += strategy[i] * action_mask[i]

        if t < cw
            break
        end

        i += 1
    end

    return i

end

@inline function epsilongreedysample!(
    strategy::Vector{T},
    action_mask::Vector{Bool}, 
    epsilon::T) where T <: AbstractFloat
    
    #sample action using strategy or select random action

    t = rand(Float32)

    if t >= epsilon
        return weightedsample!(strategy, action_mask)
    else
        return randomsample!(action_mask)
    end
end

@inline function games.limit!(gs::GameState{Game{DepthLimited, T}}) where T <: GameMode
    #override numrounds! functions for depth-limited game setups
    return setup(gs).limit
end

struct DepthLimited <: GameSetup
    strategy_index::SVector{UInt8} # oppenent will randomly chose a strategy to play at the depth
    limit::UInt8
end

struct FullTraining <: GameSetup

end

end