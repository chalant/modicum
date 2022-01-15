module tree

using StaticArrays

export History
export infoset
export history

abstract type AbstractInfoset end

struct Node{T<:AbstractArray}
    cum_strategy::T # cumulative strategy
    cum_regret::T #cumulative regret
end

struct History{T<:GameState, U<:AbstractInfoSet}
    infosets::Dict{UInt64, Node}
    histories::Dict{UInt8, History}
    game_state::T # history keeps a reference to a game state data
end

History(gs::T) where T<:GameState = History(
    Dict{UInt64, Node}(), 
    Dict{Int64, History}(), gs)

function infoset(::Type{T}, h::History, key::UInt64) where T<:AbstractArray
    info = h.infosets
    
    if haskey(info, key)
        return h.infosets[key]
    else
        node = createinfoset(T)
        h.infosets[key] = node
        return node
    end
end

function createinfoset(::SizedMatrix{N, M, T}) where {T<:AbstractFloat, N, M}
    return SizedMatrix{N, M, T}(zeros(N,M))
end

function createinfoset(::SizedVector{N, T}) where {T<:AbstractFloat, N}
    return SizedVector{N, T}(zeros(N))
end

function createinfoset(::MVector{N, T}, h::History{T}) where {N, T<:AbstractFloat}
    return Node{MVector{N, T}}(@MVector zeros(T, A), @MVector zeros(T, A), @MVector zeros(T, A))

end

function createinfoset(::MMatrix{N, M, T}) where {N, M, T<:AbstractFloat}
    return Node{MMatrix{N, M, T}}(@MMatrix zeros(T, N, M), @MMatrix zeros(T, N, M), @MMatrix zeros(T, N, M))
end

function history(h::History, action::UInt8, num_actions::Int)
    return history(h, action, num_actions)
end

function history(
    h::History{T}, 
    action_idx::UInt8, 
    num_actions::UInt8) where T <: GameState
    
    hist = h.histories
    
    if haskey(hist, action_idx)
        return hist[action_idx]
    else
        hst = History{T}(
            Dict{UInt64, Node}(), 
            Dict{UInt8, History{T}}(), 
            num_actions,
            T())

        hist[action_idx] = hst
        
        return hst

    end
end
end
