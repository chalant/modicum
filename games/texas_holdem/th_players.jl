module THPlayers

using Players

mutable struct THPlayerState{T<:AbstractFloat} <: PlayerState
    chips::T
    bet::T # player current round bet
    total_bet::T # player game total bet
    pot::T # player potential gain in case of a win
    active::Bool
    action::UInt8
    
    id::UInt8

    PlayerState{T}(chips, id) where T <: AbstractFloat = new(chips, 0, 0, true, UInt8(0), id)
end

@inline function Base.copy!(p::THPlayerState{T}, s::THPlayerState{T}) where T <: AbstractFloat
    p.chips = s.chips
    p.bet = s.bet
    p.total_bet = s.total_bet
    p.pot = s.pot
    p.active = s.active
    p.rank = s.rank
    p.action = s.action
    
    return p
end

@inline function Base.copy(s::THPlayerState{T}) where T <: AbstractFloat
    return copy!(THPlayerState{T}(s.chips, s.id), s)
end

@inline function Base.copy!(p::SizedVector{N, THPlayerState}, s::SizedVector{N, THPlayerState}) where N
    for i in 1:N
        copy!(p[i], s[i])
    end
end

@inline function Base.copy(s::SizedVector{N, PlayerState}) where N
    v = SizedVector{N, PlayerState}(undef)

    i = 1
    
    for state in s
        v[i] = copy(state)
        i += 1
    end
    
    return v
end

@inline function position(ps::THPlayerState)
    return position(ps.player)
end

@inline function Base.position(ps::THPlayerState)
    return position(ps.player)
end

Base.:(==)(a::ID, b::ID) = id(a) == id(b)

@inline function Base.:(==)(p1::THPlayerState, p2::THPlayerState)
    return p1.id == p2.id
end

@inline function Base.:(==)(p1::THPlayerState, p2::Player)
    return id(p1) == p2.id
end

@inline function Base.:(==)(p1::Player, p2::THPlayerState)
    return p1.id == id(p2)
end

@inline function Base.isless(p1::THPlayerState, p2::Player)
    return p1.id < p2.id
end

@inline function Base.isless(p1::Player, p2::THPlayerState)
    return p1.id < p2.id
end

@inline function Base.isless(p1::THPlayerState, p2::Int)
    return p1.id < p2
end

@inline function id(pl::Player)
    return pl.id
end

@inline function id(pl::THPlayerState)
    return id(pl)
end

@inline function Base.sort!(s::SizedVector{N, Player})
    return sort!(s, by=id)
end

@inline function Base.sort!(s::SizedVector{N, PlayerState})
    return sort!(s, by=id)
end

@inline function state(player::Player, states::SizedVector{PlayerState})
    return states[searchsortedfirst(states, player)]
end

@inline function player(state::THPlayerState)
    return state.player
end

@inline function totalbet(state::THPlayerState)
    return state.total_bet
end

@inline function action(state::THPlayerState)
    return state.action
end

@inline function setaction!(state::THPlayerState, a::UInt8)
    state.action = a
end

end