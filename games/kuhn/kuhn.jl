module kuhn

using StaticArrays

using games
using playing
using actions

export getdeck
export getcompresseddeck
export perform!
export rotateplayers!
export reset!
export initialstate

export KUHNGame
export KUHNGameState
export KUHNAction

export NULL_ID
export BET_ID
export CALL_ID
export CHECK_ID
export FOLD_ID

const NULL_ID = UInt8(0)
const BET_ID = UInt8(1)
const CALL_ID = UInt8(2)
const CHECK_ID = UInt8(3)
const FOLD_ID = UInt8(4)

struct KUHNChanceAction{T<:Integer} <: ChanceAction
    idx::T
    p_idx::T
    opp_idx::T
end

@inline function games.initialstate(gs::KUHNGameState)
    return INIT_ID
end

@inline function games.initialactionsmask(gs::KUHNGameState)
    return @MVector Bool[1, 0, 1, 0]
end

@inline function getdeck(::Type{T}) where {U<:Integer, T<:AbstractVector{U}}
    res = zeros(U, 52)
    
    i = 1
    
    for c in 1:13
        for _ in 1:4
            res[i] = c
            i += 1
        end
    end

    return res

end

@inline function getcompresseddeck(::Type{T}) where {U<:Integer, T<:AbstractVector{U}}
    res = zeros(U, 13)
    
    for c in 1:13
        res[c] = c
    end

    return res
end

struct KUHNAction{T<:Unsigned} <: Action
    id::T
end

@inline function Base.isless(a::KUHNAction, b::KUHNAction)
    return a.id < b.id
end

@inline function Base.:(==)(a::KUHNAction, b::KUHNAction)
    return a.id == b.id
end

@inline function Base.:(<)(a::KUHNAction, b::KUHNAction)
    return isless(a, b)
end

Base.hash(a::KUHNAction, h::UInt) = hash(a.id, hash(:KUHNAction, h))

mutable struct KUHNGame{T<:AbstractVector}
    action_set::ActionSet{4}

    players::MVector{2, UInt8}
    
    deck::T
    private_cards::MVector{2, UInt8}
end

@inline function _creategame(deck::T) where {U<:Integer, T<:AbtractVector{U}}
    action_set = ActionSet{4, KUHNAction}(MVector{4, KUHNAction}([
        KUHNAction(CALL_ID), 
        KUHNAction(BET_ID),
        KUHNAction(FOLD_ID),
        KUHNAction(CHECK_ID)]))
    
    players = @MVector UInt8[1, 2]
    private_cards = @MVector zeros(UInt8, 2)
    
    return KUHNGame{T}(
        action_set, 
        players, 
        deck, 
        private_cards)
end

KUHNGame{T}() where {U<:Integer, T<:AbstractVector{U}} = _creategame(getdeck(T))
KUHNGame{T}(deck) where {U<:Integer, T<:AbstractVector{U}} = _creategame(deck)

mutable struct KUHNGameState{S<:GameSetup} <: AbstractGameState{4, 2, S}
    action::UInt8

    position::UInt8
    pot::UInt8
    
    players_states::MVector{2, Bool}
    bets::MVector{2, UInt8}
    
    player::UInt8
    
    game::KUHNGame

end

KUHNGameState{S}(game) where S <: GameSetup = _creategamestate(S, game)

@inline function _creategamestate(::Type{S}, game) where S <: GameSetup
    states = @MVector Bool[1, 1]
    bets = @MVector zeros(UInt8, 2)
    
    return KUHNGameState{S}(
        NULL_ID,
        UInt8(1),
        UInt8(0),
        states,
        bets,
        players!(game)[1],
        game)
end

@inline function games.actionsmask!(gs::KUHNGameState{S}) where S<:GameSetup
    mask = @MVector zeros(Bool, 4)

    action = gs.action

    bet_cond = action == CHECK_ID
    call_cond = action == BET_ID
    reset_cond = action == NULL_ID

    action_set = actions!(gs)

    for i in 1:4
        aid = action_set[i].id
        
        mask[i] = bet_cond * ((aid == BET_ID) + (aid == CHECK_ID)) +
            call_cond * ((aid == CALL_ID) + (aid == FOLD_ID)) + 
            reset_cond * ((i == 1) + (i == 2) * 0 + (i == 3) + (i == 4) * 0)
            # * ((is_bet && pa == CALL_ID) +
            # (is_bet && p_is_bet) +
            # (is_bet && pa == FOLD_ID) +
            # (is_check && p_is_check) +
            # (is_check && p_is_bet))
    end

    return mask

end

struct KUHNPublicTree{T<:Integer}
    n::T
    chance_action::KUHNChanceAction{T}
end

@inline function games.performchance!(a::KUHNChanceAction{T}, gs::KUHNGameState, pl::T) where T<:Integer
    
end

@inline function games.chance!(gs::KUHNGameState, state::T) where T <: Integer
    return state == CHANCE_ID
end

@inline function games.chanceprobability!(gs::KUHNGameState, ca::KUHNChanceAction)
    l = length(game!(gs).deck)
    return binomial(l, 1) * binomial(l-1, 1)
end

@inline Base.iterate(pt::KUHNPublicTree{T}) = pt.chance_action

@inline function Base.iterate(pt::KUHNPublicTree{T}, a::KUHNChanceAction{T}) where T<:Integer
    if a.p_idx >= pt.n
        return nothing
    end
    
    if a.opp_idx >= n
        i  = a.p_idx + 1
        j = 1
    else
        i = a.p_idx
        j = a.opp_idx + 1
        j = (j == i) * (j + 1) + (j != i) * j
    end

    return KUHNChanceAction{T}(a.idx + 1, i, j)
end

@inline function games.chanceactions!(gs::KUHNGameState, a::KUHNChanceAction{T}) where T<:Integer
    return KUHNPublicTree{T}(length(game!(gs).deck), a)
end

@inline players!(g::KUHNGame) = g.players 
@inline players!(gs::KUHNGameState) = players!(gs.game)

@inline function nextplayer!(gs::KUHNGameState)
    n = gs.position 

    n = (n == 2) * 1 + (n == 1) * 2

    gs.position = n

    return players!(gs)[n]

end

@inline function rotateplayers!(game::KUHNGame)
    players = game.players

    ps = players[1]
    players[1] = players[2]
    players[2] = ps

end

@inline function games.terminal!(gs::KUHNGameState, state::T) where T <: Integer
    return state == ENDED_ID
end

@inline games.actions!(g::KUHNGame) = g.action_set
@inline games.actions!(gs::KUHNGameState) = actions!(gs.game)

@inline privatecards!(g::KUHNGame) = g.private_cards
@inline privatecards!(gs::KUHNGameState) = privatecards!(game!(gs))

@inline function Base.copy!(dest::KUHNGameState{S}, src::KUHNGameState{S}) where S <: GameSetup
    dest.action = src.action
    dest.players_states = copy(src.players_states)
    dest.bets = copy(src.bets)
    
    dest.player = dest.player

    dest.game = src.game

end

@inline function reset!(gs::KUHNGameState)
    gs.pot = 0
    
    bets = gs.bets
    
    for i in eachindex(bets)
        bets[i] = 0
    end

    gs.player = players!(gs)[1]
    gs.action = NULL_ID
    
    gs.position = 1
end

@inline function playing.perform!(
    a::KUHNAction, 
    gs::KUHNGameState{S}, 
    p::UInt8) where {S<:GameSetup}

    #perform move and update gamestate
    
    id_ = a.id
    pa = gs.action

    p_is_bet = pa == BET_ID
    p_is_check = pa == CHECK_ID
    folded = id_ == FOLD_ID

    gs.players_states[p] = folded * false + !folded * true

    is_bet = id_ == BET_ID
    is_call = id_ == CALL_ID

    bet = (is_bet || is_call) * UInt8(1)

    gs.pot += bet
    gs.bets[p] += bet

    gs.player = nextplayer!(gs)
    gs.action = id_

    end_cond = (p_is_bet && (id_ == BET_ID || folded || is_call)) || (p_is_check && id_ == CHECK_ID)

    return end_cond * ENDED_ID + !end_cond * STARTED_ID 

end

end