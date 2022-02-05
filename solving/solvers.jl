module Solvers

export epsilongreedysample!
export limit!
export showdown!
export key
export DepthLimitedSolving
export FullSolving

abstract type Solver end
abstract type Solving end

using playing
using games
using filtering
using evaluator

struct MCCFR{T<:AbstractFloat} <: Solver
    epsilon::T 
end

# todo add compression data to resources folder
# filter for private cards
const PreFlopFilter = Filter(indexdata(
    IndexData, 
    "/resources/lossless/pre_flop"))

@inline function key(pr::MVector{P, UInt64}, pc::MVector{B, UInt64}) where {B, P}
    #returns a unique key for a combination of private and public hands

    #if no public cards
    if length(pc) == 0
        # return equivalent index (after compression)
        return filterindex(PreFlopFilter, pr)
    end

    return evaluate(binomial(length(pr) + length(pc), 2), pr, pc)
end

struct DepthLimited{T<:Solver} <: GameSetup
    strategy_index::SVector{UInt8} # oppenent will randomly chose a strategy to play at the depth
    limit::UInt8
end

struct FullTraining{T<:Solver} <: GameSetup

end

end