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
using value_estimation
using infosets

abstract type Solver end

struct DepthLimited{T<:Solver, V<:StaticVector, L<:Integer, I<:Integer} <: GameSetup
    biases::V # oppenent will randomly chose a strategy to play at the depth
    limit::L
    iterations::I
end

struct FullSolving{T<:Solver} <: GameSetup

end

@inline function computeutility!(::Type{T}, h::H, gs::G, pl::I) where {A, P, T<:AbstractFloat, I<:Integer, H<:History, G<:AbstractGameState{A, DepthLimited, P}}
    if ended(gs)
        return computeutility!(T, gs, pl)
    elseif depthlimit(gs)
        return estimatevalue(T, h, gs, pl)
    end
end

@inline function computeutility!(gs::AbstractGameState, pl::T) where T<:Integer
    throw(NotImplementedError())
end

@inline function computeutility!(gs::AbstractGameState, pl::T, chance_action::games.ChanceAction) where T<:Integer
    throw(NotImplementedError())
end

end
