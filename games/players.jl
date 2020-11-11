module players

using Reexport

include("actions.jl")

export Player
export PlayerState
export ID

export state
export position

@reexport using .actions

abstract type ID end

mutable struct PlayerState <: ID
    chips::Float16
    bet::Float16 # player current round bet
    pot::Float16 # player potential gain in case of a win
    position::UInt8 # player position
    id::UInt8 # player id
    active::Bool
    rank::UInt16 # player card rank
    actions_mask::Vector{Bool}

    PlayerState() = new()
end

mutable struct Player <: ID
    id::Int
    acts::ActionSet
end

function position(ps::PlayerState)
    return ps.position
end

function Base.:(==)(p1::Player, p2::Player)
    return p1.id == p2.id
end

Base.:(==)(a::ID, b::ID) = a.id == b.id

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
    p.rposition = s.rposition
    p.id = s.id
    p.active = s.active
    p.rank = s.rank
    p.actions_mask = copy(s.actions_mask)
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

@inline function id(pl::Player)
    return pl.id
end

@inline function id(pl::PlayerState)
    return pl.id
end

function Base.sort!(s::Vector{Player})
    return sort!(s, by=id)
end

function Base.sort!(s::Vector{PlayerState})
    return sort!(s, by=id)
end

function state(player::Player, states::Vector{PlayerState})
    return states[searchsortedfirst(states, player)]
end

@inline function viewactions(pl::Player)
    return pl.acts
end

@inline function actionsmask(ps::PlayerState)
        return ps.actions_mask
end

end
