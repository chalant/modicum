module infosets

using StaticArrays

using games
using hermes_exceptions

export History

export infoset
export getutils
export getprobs
export infosetkey
export cumulativeregrets!
export cumulativestrategy!

abstract type AbstractHistory{G, N} end
abstract type AbstractNode end

struct Node{T<:StaticArray} <: AbstractNode
    cum_strategy::T # cumulative strategy
    cum_regrets::T #cumulative regret
end

Node(x::T, y::T) where {A, N<:AbstractFloat, T<:StaticVector{A, N}} = Node{T}(x, y)
Node(x::T, y::T) where {A, P, N<:AbstractFloat, U<:StaticVector{A, N}, T<:StaticVector{P, U}} = Node{T}(x, y)
Node() where {A, U<:AbstractFloat, T<:StaticVector{A, U}} = Node(StaticArrays.sacollect(T, 1/A for _ in 1:A), StaticArrays.sacollect(T, O for _ in 1:A))
Node() where {A, P, N<:AbstractFloat, U<:StaticVector{A, N}, T<:StaticVector{P, U}} = Node(
    StaticArrays.sacollect(T, StaticArrays.sacollect(U, 1/A for _ in 1:A) for _ in 1:P), 
    StaticArrays.sacollect(T, StaticArrays.sacollect(U, O for _ in 1:A) for _ in 1/P))

struct History{A, T<:AbstractGameState, U<:AbstractNode, K1<:Integer, K2<:Integer} <: AbstractHistory{A, G}
    infosets::Dict{K1, U}
    histories::Dict{K2, History{T, U, K1, K2}}
    game_state::T # history keeps a reference to a game state data
end

History(infosets::Dict{K1, N}, histories::Dict{K2, H}, game_state::G) where {A, T<:AbstractFloat, G<:AbstractGameState, U<:StaticVector{A, T}, N<:Node{U}, K1<:Integer, K2<:Integer,  H<:History{G, N, K1, K2}} = History{T, U, K1, K2}(infosets, histories, game_state)
History(infosets::Dict{K1, N}, histories::Dict{K2, H}, game_state::G) where {A, P, T<:AbstractFloat, G<:AbstractGameState, U<:StaticVector{A, T}, V<:StaticVector{P, U}, N<:Node{V}, K1<:Integer, K2<:Integer, H<:History{G, N, K1, K2}} = History{T, N, K1, K2}(infosets, histories, game_state)
History(::Type{U}, gs::G) where {A, T<:AbstractFloat, G<:AbstractGameState, U<:StaticVector{A, T}, N<:Node{U}, K1<:Integer, K2<:Integer,  H<:History{G, N, K1, K2}} = History{G, N, K1, K2}(Dict{K1, N}(), Dict{K2, H}(), gs)
History(::Type{V}, gs::G) where {A, P, T<:AbstractFloat, G<:AbstractGameState, U<:StaticVector{A, T}, V<:StaticVector{P, U}, N<:Node{V}, K1<:Integer, K2<:Integer, H<:History{G, N, K1, K2}} = History{G, N, K1, K2}(Dict{K1, N}(), Dict{K2, H}(), gs)

@inline function history(
    h::H, 
    action_idx::K,
    infosets::I, 
    gs::G) where {K1<:Integer, N<:Node, K<:Integer, I<:Dict{K1, N}, G<:AbstractGameState, H<:History{G, N, K1, K}}
    
    hist = h.histories
    
    if haskey(hist, action_idx) == true
        return hist[action_idx]
    else
        hst = History(
            Dict{K, N}(), 
            infosets, 
            copy(gs))

        hist[action_idx] = hst
        
        return hst

    end
end

@inline function history(
    h::H, 
    action_idx::K, 
    gs::G) where {K1<:Integer, N<:Node, K<:Integer, I<:Dict{K1, N}, G<:AbstractGameState, H<:History{G, N, K1, K}}
    
    hist = h.histories
    
    if haskey(hist, action_idx) == true
        return hist[action_idx]
    else
        hst = History(
            Dict{K, N}(), 
            I(), 
            copy(gs))

        hist[action_idx] = hst
        
        return hst

    end
end


History(h::H, infosets::I, idx::K, gs::G) where {K1<:Integer, K<:Integer, N<:Node, I<:Dict{K1, N}, G<:AbstractGameState, H<:History{G, N, K1, K}} = history(h, infosets, idx, gs)
History(h::H, idx::K, gs::G) where {K1<:Integer, K<:Integer, N<:Node, G<:AbstractGameState, H<:History{G, N, K1, K}} = history(h, idx, gs)

struct CachingVHistory{T<:AbstractGameState, U<:AbstractNode, V<:AbstractFloat, N<:StaticArray, K1<:Integer, K2<:Integer} <: AbstractHistory
    infosets::Dict{UInt64, U}
    histories::Dict{K, CachingVHistory{T, U, V, N, K1, K2}}
    game_state::T
    opp_probs::N
    utils::N
end

struct VHistory{T<:AbstractGameState, U<:StaticMatrix, V<:AbstractFloat, N, K} <: AbstractHistory{T, U, V, N}
    infosets::Dict{UInt64, Node{U}}
    histories::Dict{K, VHistory{T, Node{U}}}
    game_state::T
end

@inline function infosetkey(gs::AbstractGameState)
    throw(NotImplementedErrorr())
end

@inline function infoset(h::H, key::I) where {K<:Integer, I<:Integer, G<:AbstractGameState, N<:Node, H<:History{G, N, K, I}}
    info = h.infosets
    
    if haskey(info, key)
        return h.infosets[key]
    else
        node = N()
        h.infosets[key] = node
        return node
    end
end

@inline function getutils(h::CachingVHistory{T, U, V, N, K}) where {T<:AbstractGameState, U<:AbstractArray, V<:AbstractFloat, N, K<:Unsigned}
    return h.utils
end

@inline function getutils(h::VHistory{T, U, V, N, K}) where {T<:AbstractGameState, U<:AbstractMatrix, V<:AbstractFloat, N, K<:Unsigned}
    return @MVector zeros(V, N)
end

@inline function getprobs(h::CachingVHistory{T, U, V, N, K}) where {T<:AbstractGameState, U<:AbstractMatrix, V<:AbstractFloat, N, K<:Unsigned}
    return h.opp_probs
end

@inline function getprobs(h::VHistory{T, U, V, N, K}) where {T<:AbstractGameState, U<:AbstractMatrix, V<:AbstractFloat, N, K<:Unsigned}
    @MVector zeros(V, N)
end

@inline function cumulativestrategy!(node::N, pl::I) where {I<:Integer, N<:MPNode}
    return node.cum_strategy[pl]
end

@inline function cumulativestrategy!(node::N, pl::I) where {I<:Integer, N<:Node}
    return node.cum_strategy
end

@inline function cumulativeregrets!(node::N, pl::I) where {I<:Integer, A, P, F<:AbstractFloat, U<:StaticVector{A, F}, T<:StaticVector{P, U}, N<:Node{T}}
    return node.cum_regrets[pl]
end

@inline function cumulativeregrets!(node::N, pl::I) where {I<:Integer, A, F<:AbstractFloat, T<:StaticVector{A, F}, N<:Node{T}}
    return node.cum_regrets
end

end