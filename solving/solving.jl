module solving

# include("infosets.jl")
# include("../abstraction/filtering.jl")

# using .infosets
# using .games
# using .filtering

export DepthLimitedSolving
export FullSolving
export Solver

export computeutility!

using StaticArrays

using games
using hermes_exceptions

# # todo add compression data to resources folder
# # filter for private cards
# const PreFlopFilter = Filter(indexdata(
#     IndexData, 
#     "/resources/lossless/pre_flop"))

# function key(pr::Vector{UInt64}, cc::Vector{UInt64})
#     #returns a unique key for a combination of private and public hands
#     if length(cc) == 0
#         # return equivalent index (after compression)
#         return filterindex(PreFlopFilter, pr)
#     end
#     return evaluate(pr, cc)
# end

# export epsilongreedysample!
# export limit!
# export showdown!
# export key

abstract type Solver end
# abstract type Solving end

# # todo add compression data to resources folder
# # filter for private cards
# const PreFlopFilter = Filter(indexdata(
#     IndexData, 
#     "/resources/lossless/pre_flop"))

# @inline function key(pr::MVector{P, UInt64}, pc::MVector{B, UInt64}) where {B, P}
#     #returns a unique key for a combination of private and public hands

#     #if no public cards
#     if length(pc) == 0
#         # return equivalent index (after compression)
#         return filterindex(PreFlopFilter, pr)
#     end

#     return evaluate(binomial(length(pr) + length(pc), 2), pr, pc)
# end

struct DepthLimited{T<:Solver, V<:StaticVector, L<:Integer} <: GameSetup
    strategy_index::V # oppenent will randomly chose a strategy to play at the depth
    limit::L
end

struct FullSolving{T<:Solver} <: GameSetup

end

@inline function computeutility!(gs::AbstractGameState, pl::T) where T<:Integer
    throw(NotImplementeError())
end

@inline function computeutility!(gs::AbstractGameState, pl::T, chance_action::games.ChanceAction) where T<:Integer
    throw(NotImplementeError())
end

end
