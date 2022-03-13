module infosets

using StaticArrays

using games
using hermes_exceptions

export History
export Node

export infoset
export getutils
export getprobs
export infosetkey
export cumulativeregrets!
export cumulativestrategy!

abstract type AbstractHistory end
abstract type AbstractNode end

struct Node{T<:StaticArray} <: AbstractNode
    cum_strategy::T # cumulative strategy
    cum_regrets::T #cumulative regret
end

Node(x::T, y::T) where {A, N<:AbstractFloat, T<:StaticVector{A, N}} = Node{T}(x, y)
Node(x::T, y::T) where {A, P, N<:AbstractFloat, U<:StaticVector{A, N}, T<:StaticVector{P, U}} = Node{T}(x, y)
Node(::Type{T}) where {A, U<:AbstractFloat, T<:StaticVector{A, U}} = Node{T}(StaticArrays.sacollect(T, N(0) for _ in 1:A), StaticArrays.sacollect(T, N(0) for _ in 1:A))
Node(::Type{T}) where {A, P, N<:AbstractFloat, U<:StaticVector{A, N}, T<:StaticVector{P, U}} = Node{T}(
    StaticArrays.sacollect(T, StaticArrays.sacollect(U, N(0) for _ in 1:A) for _ in 1:P), 
    StaticArrays.sacollect(T, StaticArrays.sacollect(U, N(0) for _ in 1:A) for _ in 1:P))

mutable struct History{U<:AbstractNode, K1<:Integer, K2<:Integer} <: AbstractHistory
    infosets::Dict{K1, U}
    histories::Dict{K2, History{U, K1, K2}}
end

History(::Type{H}) where {A, T<:AbstractFloat, U<:StaticVector{A, T}, N<:Node{U}, K1<:Integer, K2<:Integer,  H<:History{N, K1, K2}} = History{N, K1, K2}(Dict{K1, N}(), Dict{K2, H}())
History(::Type{H}) where {A, P, T<:AbstractFloat, U<:StaticVector{A, T}, V<:StaticVector{P, U}, N<:Node{V}, K1<:Integer, K2<:Integer, H<:History{N, K1, K2}} = History{N, K1, K2}(Dict{K1, N}(), Dict{K2, H}())

@inline function history(
    h::H, 
    action_idx::K,
    infosets::I) where {K1<:Integer, N<:Node, K<:Integer, I<:Dict{K1, N}, H<:History{N, K1, K}}

    hist = h.histories
    
    if haskey(hist, action_idx) == true
        return hist[action_idx]
    else
        hst = History(
            infosets,
            Dict{K, H}())

        hist[action_idx] = hst
        
        return hst

    end
end

@inline function history(
    h::H, 
    action_idx::K) where {K1<:Integer, N<:Node, K<:Integer, H<:History{N, K1, K}}
    
    hist = h.histories
    
    if haskey(hist, action_idx) == true
        return hist[action_idx]
    else
        hst = History(
            Dict{K1, N}(), 
            Dict{K, H}())

        hist[action_idx] = hst
        
        return hst

    end
end

History(h::H, action_idx::K) where {K1<:Integer, N<:Node, K<:Integer, H<:History{N, K1, K}} = history(h, action_idx)
History(h::H, action_idx::K, infosets::I) where {K1<:Integer, K<:Integer, N<:Node, I<:Dict{K1, N}, H<:History{N, K1, K}} = history(h, action_idx, infosets)

@inline function infosetkey(gs::AbstractGameState)
    throw(NotImplementedError())
end

@inline function infosetkey(gs::AbstractGameState, cha::games.ChanceAction)
    throw(NotImplementedError())
end

function infoset(h::H, key::I) where {K<:Integer, I<:Integer, V<:StaticVector, N<:Node{V}, H<:History{N, K, I}}
    info = h.infosets

    if haskey(info, key)
        return h.infosets[key]
    else
        node = Node(V)
        h.infosets[key] = node
        return node
    end
end

function getutils(h::H) where {A, K1<:Integer, K2<:Integer, T<:AbstractFloat, U<:StaticVector{A, T}, N<:Node{U}, H<:History{N, K1, K2}}
    return @MVector zeros(T, A)
end

function getutils(h::H) where {A, P, K1<:Integer, K2<:Integer, T<:AbstractFloat, U<:StaticVector{A, T}, V<:StaticVector{P, U}, N<:Node{V}, H<:History{N, K1, K2}}
    return @MVector zeros(T, A)
end

@inline function cumulativestrategy!(node::N, pl::I) where {A, P, I<:Integer, T<:AbstractFloat, U<:StaticVector{A, T}, V<:StaticVector{P, U}, N<:Node{V}}
    return node.cum_strategy[1]
end

@inline function cumulativestrategy!(node::N, pl::I) where {A, I<:Integer, T<:AbstractFloat, U<:StaticVector{A, T}, N<:Node{U}}
    return node.cum_strategy
end

@inline function cumulativeregrets!(node::N, pl::I) where {A, P, I<:Integer, T<:AbstractFloat, U<:StaticVector{A, T}, V<:StaticVector{P, U}, N<:Node{V}}
    return node.cum_regrets[1]
end

@inline function cumulativeregrets!(node::N, pl::I) where {A, I<:Integer, T<:AbstractFloat, U<:StaticVector{A, T}, N<:Node{U}}
    return node.cum_regrets
end

end