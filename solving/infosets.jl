module tree

using StaticArrays

export History
export infoset
export history
export getutils

abstract type AbstractHistory{T, U, V, N} end

struct Node{T<:AbstractArray}
    cum_strategy::T # cumulative strategy
    cum_regret::T #cumulative regret
end

struct History{T<:GameState, U<:AbstractArray, V<:AbstractFloat, N} <: AbstractHistory{T, U, V, N}
    infosets::Dict{UInt64, Node{U}}
    histories::Dict{UInt8, History{T, Node{U}}}
    game_state::T # history keeps a reference to a game state data
end

struct CachingHistory{T<:GameState, U<:AbstractArray, V<:AbstractFloat, N} <: AbstractHistory{T, U, V, N}
    infosets::Dict{UInt64, Node{U}}
    histories::Dict{UInt8, History{T, Node{U}}}
    game_state::T # history keeps a reference to a game state data
    cache::SizedVector{N, V}
end

@inline function infoset(::Type{T}, h::AbstractHistory, key::UInt64) where T<:StaticArray
    info = h.infosets
    
    if haskey(info, key)
        return h.infosets[key]
    else
        node = createinfoset(h)
        h.infosets[key] = node
        return node
    end
end

@inline function createinfoset(::SizedMatrix{N, M, T}) where {T<:AbstractFloat, N, M}
    return SizedMatrix{N, M, T}(zeros(N,M))
end

@inline function createinfoset(::SizedVector{N, T}) where {T<:AbstractFloat, N}
    return SizedVector{N, T}(zeros(N))
end

@inline function createinfoset(::MVector{N, T}, h::AbstractHistory) where {N, T<:AbstractFloat}
    return Node{MVector{N, T}}(@MVector zeros(T, A), @MVector zeros(T, A), @MVector zeros(T, A))
end

@inline function createinfoset(::MMatrix{N, M, T}) where {N, M, T<:AbstractFloat}
    return Node{MMatrix{N, M, T}}(@MMatrix zeros(T, N, M), @MMatrix zeros(T, N, M), @MMatrix zeros(T, N, M))
end

@inline function history(
    h::History{T, Node{U}, N}, 
    action_idx::UInt8) where {T <: GameState, U <: AbstractArray, N}
    
    hist = h.histories
    
    if haskey(hist, action_idx)
        return hist[action_idx]
    else
        hst = History{T, Node{U}, N}(
            Dict{UInt64, Node{U}}(), 
            Dict{UInt8, History{T, Node{U}}}(), 
            T())

        hist[action_idx] = hst
        
        return hst

    end
end

@inline function history(
    h::CachingHistory{T, Node{U}, V, N}, 
    action_idx::UInt8) where {T<:GameState, U<:AbstractArray, V, N}
    
    hist = h.histories
    
    if haskey(hist, action_idx)
        return hist[action_idx]
    else
        hst = CachingHistory{T, Node{U}, V, N}(
            Dict{UInt64, Node{U}}(), 
            Dict{UInt8, History{T, Node{U}}}(), 
            T(), 
            SizedArray(N, V)(zeros(V, N)))

        hist[action_idx] = hst
        
        return hst

    end
end

@inline function getutils(h::CachingHistory{T, U, V, N}) where {T<:GameState, U<:AbstractArray, V<:AbstractFloat, N}
    return h.cache
end

@inline function getutils(h::History{T, U, V, N}) where {T<:GameState, U<:AbstractArray, V<:AbstractFloat, N}
    return @MVector zeros(V, N)
end
