module tree

using StaticArrays

export History
export infoset
export history

struct Node{N, T<:AbstractFloat}
    cum_strategy::MVector{N, T} # cumulative strategy
    cum_regret::MVector{N, T} #cumulative regret
    stg_profile::MVector{N, T} #strategy profile
    opp_prob::T
    util::T
end

struct History{T<:AbstractFloat}
    infosets::Dict{UInt64, Node}
    histories::Dict{UInt8, History}
    num_actions::UInt8
    game_state::GameState # history keeps a reference to a game state data
end

History(n::UInt8, gs::GameState) = History(
    Dict{UInt64, Node}(), 
    Dict{Int64, History}(), 
    n, gs)

function infoset(::T, ::Val{A}, h::History, key::UInt64) where {T <: AbstractFloat, A}
    info = h.infosets
    
    if haskey(info, key)
        return h.infosets[key]
    else
        v = MVector{A, T}(zeros(A))
        node = Node{A}(v, similar(v), similar(v))
        h.infosets[key] = node
        return node
    end
end

function history(h::History, action::UInt8, num_actions::Int)
    return history(h, action, num_actions)
end

function history(
    h::History, 
    action::UInt8, 
    num_actions::UInt8)
    
    hist = h.histories
    if haskey(hist, action)
        return hist[action]
    else
        hst = History{A}(
            Dict{UInt64, Node}(), 
            Dict{UInt8, History}(), 
            num_actions,
            GameState())

        hist[action] = hst
        
        return hst

    end
end
end
