module tree

export History
export infoset
export history

struct Node
    cum_strategy::Vector{Float32} # cumulative strategy
    cum_regret::Vector{Float32} #cumulative regret
    stg_profile::Vector{Float32} #strategy profile
end

struct History
    infosets::Dict{UInt64, Node}
    histories::Dict{Int, History}
    num_actions::UInt8
    game::Game # history keeps a reference to a game state data
    util::Vector{Float32} # cache a vector for lazy instanciation
end

History(n::UInt8, g::Game, s::Vector{Float32}, u::Vector{Float32}) = History(
    Dict{UInt64, Node}(), Dict{Int, History}(), n, g, u)

function infoset(h::History, key::UInt64)
    info = h.infosets
    if haskey(info, key)
        return h.infosets[key]
    else
        node = Node(Vector{Float64}(undef, h.num_actions), similar(v))
        h.infosets[key] = node
        return node
    end
end

function history(h::History, action::Int, num_actions::Int)
    return history(h, action, zeros(Float32, num_actions), num_actions)
end

function history(h::History, action::Int, utils::Vector{Float32}, num_actions::Int)
    hist = h.histories
    if haskey(hist, action)
        return hist[action]
    else
        hst = History(Dict{UInt64, Node}(), Dict{Int, History}(), num_actions,
            Game(), utils)
        hist[action] = hst
        return hst
    end
end
end
