module infosets

using StaticArrays

using games

export History
export infoset
export history
export getutils

export infosetkey

abstract type AbstractHistory{T, U, V, N} end

struct Node{T<:AbstractArray}
    cum_strategy::T # cumulative strategy
    cum_regret::T #cumulative regret
end

struct History{T<:AbstractGameState, U<:AbstractArray, V<:AbstractFloat, N} <: AbstractHistory{T, U, V, N}
    infosets::Dict{UInt64, Node{U}}
    histories::Dict{UInt8, History{T, Node{U}}}
    game_state::T # history keeps a reference to a game state data
end

struct CachingHistory{T<:AbstractGameState, U<:AbstractArray, V<:AbstractFloat, N} <: AbstractHistory{T, U, V, N}
    infosets::Dict{UInt64, Node{U}}
    histories::Dict{UInt8, History{T, Node{U}}}
    game_state::T # history keeps a reference to a game state data
    cache::SizedVector{N, V}
end

@inline function infosetkey(gs::AbstractGameState)
    throw(NotImplementedErrorr())
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
    return SizedMatrix{N, M, T}(zeros(T,N,M))
end

@inline function createinfoset(::SizedVector{N, T}) where {T<:AbstractFloat, N}
    return SizedVector{N, T}(zeros(N))
end

@inline function createinfoset(::MVector{N, T}, h::AbstractHistory) where {N, T<:AbstractFloat}
    cum_stg = @MVector zeros(T, A)
    cum_regret = @MVector zeros(T, A)

    return Node{MVector{N, T}}(
        cum_stg, cum_regret)
end

@inline function createinfoset(::MMatrix{N, M, T}) where {N, M, T<:AbstractFloat}
    cum_stg = @MMatrix zeros(T, N, M)
    cum_regrets = @MMatrix zeros(T, N, M)

    return Node{MMatrix{N, M, T}}(cum_stg, cum_regrets)
end

@inline function history(
    h::History{T, U, V, N}, 
    action_idx::UInt8) where {T <: AbstractGameState, U <: AbstractArray, V <: AbstractFloat, N}
    
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
    ::Type{CachingHistory{T, U, V, N}}, 
    gs::T) where {T <: AbstractGameState, U <: AbstractArray, V <: AbstractFloat, N}
    
    return CachingHistory{T, U, V, N}(
        Dict{UInt64, Node{U}}(), 
        Dict{UInt8, CachingHistory{T, U, V, N}}(), 
        gs, 
        SizedArray(N, V)(zeros(V, N)))
end

@inline function history(
    ::Type{History{T, U, V, N}}, 
    gs::T) where {T <: AbstractGameState, U <: AbstractArray, V <: AbstractFloat, N}
    
    return History{T, U, V, N}(
        Dict{UInt64, Node{U}}(), 
        Dict{UInt8, History{T, U, V, N}}(), 
        gs)
end

@inline function history(
    h::CachingHistory{T, U, V, N}, 
    action_idx::UInt8) where {T <: AbstractGameState, U <: AbstractArray, V <: AbstractFloat, N}
    
    hist = h.histories
    
    if haskey(hist, action_idx)
        return hist[action_idx]
    else
        hst = CachingHistory{T, U, V, N}(
            Dict{UInt64, Node{U}}(), 
            Dict{UInt8, CachingHistory{T, U, V, N}}(), 
            T(), 
            SizedArray(N, V)(zeros(V, N)))

        hist[action_idx] = hst
        
        return hst

    end
end

@inline function getutils(h::CachingHistory{T, U, V, N}) where {T<:AbstractGameState, U<:AbstractArray, V<:AbstractFloat, N}
    return h.cache
end

@inline function getutils(h::History{T, U, V, N}) where {T<:AbstractGameState, U<:AbstractArray, V<:AbstractFloat, N}
    return @MVector zeros(V, N)
end

end