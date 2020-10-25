module players

export Player
export PlayerState
export state

mutable struct PlayerState
    chips::AbstractFloat
    bet::AbstractFloat
    position::Int
    id::Int
    active::Bool
    PlayerState() = new()
end

struct Player
    id::Int
end

function Base.:(==)(p1::Player, p2::Player)
    return p1.id == p2.id
end

function Base.:(==)(p1::PlayerState, p2::PlayerState)
    return p1.id == p2.id
end

function Base.:(==)(p1::PlayerState, p2::Player)
    return p1.id == p2.id
end

function Base.:(==)(p1::Player, p2::PlayerState)
    return p1.id == p2.id
end

function Base.isless(p1::PlayerState, p2::Player)
    return p1.id < p2.id
end

function Base.isless(p1::Player, p2::PlayerState)
    return p1.id < p2.id
end

function Base.isless(p1::PlayerState, p2::Int)
    return p1.id < p2
end

function Base.copy!(p::PlayerState, s::PlayerState)
    p.chips = s.chips
    p.bet = s.bet
    p.position = s.position
    p.id = s.id
    p.active = s.active
    return p
end

function Base.copy(s::PlayerState)
    p = PlayerState()
    copy!(p, s)
    return p
end

function Base.copy!(p::Vector{PlayerState}, s::Vector{PlayerState})
    for i in length(p)
        copy!(p[i], s[i])
    end
end

function Base.copy(s::Vector{PlayerState})
    l = length(s)
    v = Vector{PlayerState}(undef, l)

    i = 1
    for state in s
        v[i] = copy(state)
        i += 1
    end
    return v
end

function state(player::Player, states::Vector{PlayerState})
    return states[searchsortedfirst(states, player)]
end

end
