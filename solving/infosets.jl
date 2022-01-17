module tree

using StaticArrays

export History
export infoset
export history

struct Node{T<:AbstractArray}
    cum_strategy::T # cumulative strategy
    cum_regret::T #cumulative regret
end

struct History{T<:GameState, U<:Node}
    infosets::Dict{UInt64, U}
    histories::Dict{UInt8, History{T, U}}
    game_state::T # history keeps a reference to a game state data
end

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

function history(
    h::History{T, Node{U}}, 
    action_idx::UInt8) where {T <: GameState, U <: AbstractArray}
    
    hist = h.histories
    
    if haskey(hist, action_idx)
        return hist[action_idx]
    else
        hst = History{T, Node{U}}(
            Dict{UInt64, Node{U}}(), 
            Dict{UInt8, History{T, Node{U}}}(), 
            T())

        hist[action_idx] = hst
        
        return hst

    end
end
end
