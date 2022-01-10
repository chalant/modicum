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

struct History{N, T<:AbstractFloat}
    infosets::Dict{UInt64, Node}
    histories::Dict{UInt8, History}
    num_actions::UInt8
    game_state::GameState # history keeps a reference to a game state data
    utils::MVector{N, T} # cache a vector for lazy instanciation
end

History(n::UInt8, gs::GameState, u::MVector{N, T}) where T <: AbstractFloat = History(
    Dict{UInt64, Node}(), 
    Dict{Int64, History}(), 
    n, gs, u)

function infoset(::T, h::History, key::UInt64) where T <: AbstractFloat
    info = h.infosets
    
    if haskey(info, key)
        return h.infosets[key]
    else
        v = MVector{h.num_actions, T}((0, 0, 0))
        node = Node(v, similar(v), similar(v))
        h.infosets[key] = node
        return node
    end
end

function history(h::History, action::Int, num_actions::Int)
    return history(h, action, zeros(Float32, num_actions), num_actions)
end

function history(
    h::History, 
    action::UInt8, 
    utils::MVector{N, T}, 
    num_actions::UInt8) where T <: AbstractFloat
    
    hist = h.histories
    if haskey(hist, action)
        return hist[action]
    else
        hst = History(
            Dict{UInt64, Node}(), 
            Dict{UInt8, History}(), 
            num_actions,
            GameState(), 
            utils)

        hist[action] = hst
        
        return hst

    end
end
end
