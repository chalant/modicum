module players

export Player
export PlayerState
export ID

export actionsmask
export id
export player

export state
export position
export totalbet
export action
export setaction!


abstract type ID end

struct Player <: ID
    id::UInt8
    position::UInt8

    Player(id, position) = new(id, position)
end

mutable struct PlayerState <: ID
    chips::Float32
    bet::Float32 # player current round bet
    total_bet::Float32 # player game total bet
    pot::Float32 # player potential gain in case of a win
    active::Bool
    rank::UInt16 # player card rank
    actions_mask::Vector{Bool}
    action::UInt8

    player:: Player

    PlayerState() = new()
end

@inline function Base.position(ps::PlayerState)
    return position(ps.player)
end

@inline function Base.position(player::Player)
    return player.position
end

@inline function Base.:(==)(p1::Player, p2::Player)
    return p1.id == p2.id
end

Base.:(==)(a::ID, b::ID) = id(a) == id(b)

@inline function Base.:(==)(p1::PlayerState, p2::PlayerState)
    return id(p1) == id(p2)
end

@inline function Base.:(==)(p1::PlayerState, p2::Player)
    return id(p1) == p2.id
end

@inline function Base.:(==)(p1::Player, p2::PlayerState)
    return p1.id == id(p2)
end

@inline function Base.isless(p1::PlayerState, p2::Player)
    return p1.id < p2.id
end

@inline function Base.isless(p1::Player, p2::PlayerState)
    return p1.id < p2.id
end

@inline function Base.isless(p1::PlayerState, p2::Int)
    return p1.id < p2
end

@inline function position(ps::PlayerState)
    return position(ps.player)
end

@inline function position(ps::Player)
    return ps.position
end

@inline function Base.copy!(p::PlayerState, s::PlayerState)
    p.player = s.player
    p.chips = s.chips
    p.bet = s.bet
    p.total_bet = s.total_bet
    p.pot = s.pot
    p.active = s.active
    p.rank = s.rank
    p.actions_mask = copy(s.actions_mask)
    p.action = s.action
    return p
end

@inline function Base.copy(s::PlayerState)
    p = PlayerState()
    copy!(p, s)
    return p
end

@inline function Base.copy!(p::Vector{PlayerState}, s::Vector{PlayerState})
    for i in length(p)
        copy!(p[i], s[i])
    end
end

@inline function Base.copy(s::Vector{PlayerState})
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
    return id(pl.player)
end

@inline function Base.sort!(s::Vector{Player})
    return sort!(s, by=id)
end

@inline function Base.sort!(s::Vector{PlayerState})
    return sort!(s, by=id)
end

@inline function state(player::Player, states::Vector{PlayerState})
    return states[searchsortedfirst(states, player)]
end

function player(state::PlayerState)
    return state.player
end

@inline function totalbet(state::PlayerState)
    return state.total_bet
end

@inline function action(state::PlayerState)
    return state.action
end

@inline function setaction!(state::PlayerState, a::UInt8)
    state.action = a
end

@inline function viewactions(pl::Player)
    return pl.acts
end

@inline function actionsmask(ps::PlayerState)
        return ps.actions_mask
end

end
