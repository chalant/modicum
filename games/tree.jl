struct Node
    strategy::Vector{Float32}
    avg_strategy::Vector{Float32}
end

struct History
    infosets::Dict{UInt64, Node}
    histories::Dict{Int, History}
    num_actions::Int
end

History(x) = History(Dict{UInt64, Node}(), Dict{Int, History}(), x)

function infoset(h::History, key::UInt64)
    info = h.infosets
    if haskey(info, key)
        return h.infosets[key]
    else
        v = Vector{Float64}(undef, h.num_actions)
        node = Node(v, similar(v))
        h.infosets[key] = node
        return node
    end
end

function history(h::History, action::Int, num_actions::Int)
    hist = h.histories
    if haskey(hist, action)
        return hist[action]
    else
        hst = History(num_actions)
        hist[action] = hst
        return hst
    end
end
