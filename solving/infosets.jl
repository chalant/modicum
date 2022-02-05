module infosets

using StaticArrays

using games
using hermes_exceptions

export History
export infoset
export history
export getutils
export getprobs

export infosetkey

abstract type AbstractHistory{T, U, V, N} end

struct Node{T<:AbstractArray}
    cum_strategy::T # cumulative strategy
    cum_regret::T #cumulative regret
end

struct History{T<:AbstractGameState, U<:StaticVector, V<:AbstractFloat, N} <: AbstractHistory{T, U, V, N}
    infosets::Dict{UInt64, Node{U}}
    histories::Dict{UInt8, History{T, Node{U}}}
    game_state::T # history keeps a reference to a game state data
end

struct CachingVHistory{T<:AbstractGameState, U<:StaticMatrix, V<:AbstractFloat, N} <: AbstractHistory{T, U, V, N}
    infosets::Dict{UInt64, Node{U}}
    histories::Dict{UInt8, CachingCFRHistory{T, Node{U}}}
    game_state::T
    opp_probs::SizedVector{N, V}
    utils::SizedVector{N, V}
end

struct VHistory{T<:AbstractGameState, U<:StaticMatrix, V<:AbstractFloat, N} <: AbstractHistory{T, U, V, N}
    infosets::Dict{UInt64, Node{U}}
    histories::Dict{UInt8, VHistory{T, Node{U}}}
    game_state::T
end

@inline function infosetkey(gs::AbstractGameState)
    throw(NotImplementedErrorr())
end

@inline function infoset(::Type{T}, h::U, key::UInt64) where {T<:StaticArray, U<:AbstractHistory}
    info = h.infosets
    
    if haskey(info, key)
        return h.infosets[key]
    else
        node = createinfoset(h)
        h.infosets[key] = node
        return node
    end
end

@inline function history(
    h::History{T, U, V, N}, 
    action_idx::UInt8) where {T<:AbstractGameState, U<:StaticVector, V<:AbstractFloat, N}
    
    hist = h.histories
    
    if haskey(hist, action_idx)
        return hist[action_idx]
    else
        hst = History{T, U, V, N}(
            Dict{UInt64, Node{U}}(), 
            Dict{UInt8, History{T, U, V, N}}(), 
            T())

        hist[action_idx] = hst
        
        return hst

    end
end

@inline function history(
    ::Type{CachingVHistory{T, U, V, N}}, 
    gs::T) where {N, V<:AbstractFloat, T<:AbstractGameState, U<:StaticMatrix}
    
    return CachingVHistory{T, U, V, N}(
        Dict{UInt64, Node{U}}(), 
        Dict{UInt8, CachingVHistory{T, U, V, N}}(), 
        gs, 
        SizedVector(N, V)(zeros(V, N)),
        SizedVector(N, V)(zeros(V, N)))
end

@inline function history(
    ::Type{VHistory{T, U, V, N}}, 
    gs::T) where {T<:AbstractGameState, U<:StaticMatrix, V<:AbstractFloat, N}
    
    return VHistory{T, U, V, N}(
        Dict{UInt64, Node{U}}(), 
        Dict{UInt8, VHistory{T, U, V, N}}(), 
        gs)
end

@inline function history(
    ::Type{History{T, U, V, N}}, 
    gs::T) where {T<:AbstractGameState, U<:StaticVector, V<:AbstractFloat, N}

    return History{T, U, V, N}(
        Dict{UInt64, Node{U}}(), 
        Dict{UInt8, History{T, U, V, N}}(), 
        gs)

end

@inline function history(
    h::CachingVHistory{T, U, V, N}, 
    action_idx::UInt8) where {T<:AbstractGameState, U<:StaticMatrix, V<:AbstractFloat, N}
    
    hist = h.histories
    
    if haskey(hist, action_idx)
        return hist[action_idx]
    else
        hst = CachingVHistory{T, U, V, N}(
            Dict{UInt64, Node{U}}(), 
            Dict{UInt8, CachingHistory{T, U, V, N}}(), 
            T(), 
            SizedArray(N, V)(zeros(V, N)))

        hist[action_idx] = hst
        
        return hst

    end
end

@inline function getutils(h::CachingVHistory{T, U, V, N}) where {T<:AbstractGameState, U<:AbstractArray, V<:AbstractFloat, N}
    return h.utils
end

@inline function getutils(h::VHistory{T, U, V, N}) where {T<:AbstractGameState, U<:AbstractMatrix, V<:AbstractFloat, N}
    return @MVector zeros(V, N)
end

@inline function getprobs(h::CachingVHistory{T, U, V, N}) where {T<:AbstractGameState, U<:AbstractMatrix, V<:AbstractFloat, N}
    return h.opp_probs
end

@inline function getprobs(h::VHistory{T, U, V, N}) where {T<:AbstractGameState, U<:AbstractMatrix, V<:AbstractFloat, N}
    @MVector zeros(V, N)
end

end