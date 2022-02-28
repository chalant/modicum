module kuhn

using StaticArrays

using games
using actions

export getdeck
export getcompresseddeck
export perform!
export rotateplayers!
export reset!
export initialstate
export privatecards!
export game!
export deck!

export KUHNGame
export KUHNGameState
export KUHNAction
export KUHNChanceAction

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

struct KUHNChanceAction{T<:Integer} <: games.ChanceAction
    idx::T
    p_idx::T
    opp_idx::T
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
    action_set::ActionSet{4, KUHNAction}

    players::MVector{2, UInt8}
    
    deck::T
    private_cards::MVector{2, UInt8}
end

@inline function _creategame(deck::T) where {U<:Integer, T<:AbstractVector{U}}
    action_set = ActionSet(SizedVector{4, KUHNAction}(
        KUHNAction(CALL_ID), 
        KUHNAction(BET_ID),
        KUHNAction(FOLD_ID),
        KUHNAction(CHECK_ID)))
    
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

struct KUHNGameState{S<:GameSetup} <: AbstractGameState{4, S, 2}
    action::UInt8
    position::UInt8
    pot::UInt8
    player::UInt8
    game_state::UInt8
    
    players_states::MVector{2, Bool}
    bets::MVector{2, UInt8}
    
    game::KUHNGame

end

KUHNGameState{S}(game::KUHNGame) where S <: GameSetup = _creategamestate(S, game)

@inline function _creategamestate(::Type{S}, game) where S <: GameSetup
    states = @MVector Bool[1, 1]
    bets = @MVector zeros(UInt8, 2)
    
    return KUHNGameState{S}(
        NULL_ID,
        UInt8(1),
        UInt8(0),
        players!(game)[1],
        CHANCE_ID,
        states,
        bets,
        game)
end

@inline function games.initialstate(gs::KUHNGameState)
    return CHANCE_ID
end

@inline function games.initialactionsmask(gs::KUHNGameState)
    return @MVector Bool[1, 0, 1, 0]
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

@inline function games.initialchanceaction(::Type{T}, gs::KUHNGameState) where T<:Integer
    return KUHNChanceAction{T}(1, 1, 2)
end

@inline function games.performchance!(a::KUHNChanceAction{T}, gs::KUHNGameState{S}, pl::T) where {T<:Integer, S<:GameSetup}
    return KUHNGameState{S}(
        gs.action,
        gs.position,
        gs.pot,
        gs.player,
        STARTED_ID,
        copy(gs.players_states),
        copy(gs.bets),
        gs.game)
end

@inline function games.chance!(gs::KUHNGameState)
    return gs.game_state == CHANCE_ID
end

@inline function games.chanceprobability!(::Type{T}, gs::KUHNGameState, ca::KUHNChanceAction) where T <: AbstractFloat
    return T(1/6)
end

@inline Base.iterate(pt::KUHNPublicTree{T}) where T<:Integer = (pt.chance_action, (T(2), T(1), T(3)))

@inline function Base.iterate(pt::KUHNPublicTree{T}, state::Tuple{T, T, T}) where T<:Integer
    idx, p_idx, opp_idx = state

    if p_idx >= pt.n
        return nothing
    end
    
    if opp_idx >= pt.n
        i  = p_idx + 1
        j = 1
    else
        i = p_idx
        j = opp_idx + 1
        j = (j == i) * (j + 1) + (j != i) * j
    end

    return (KUHNChanceAction{T}(idx, p_idx, opp_idx), (T(idx + 1), T(i), T(j)))
end

@inline function games.chanceactions!(gs::KUHNGameState, a::KUHNChanceAction{T}) where T<:Integer
    return KUHNPublicTree{T}(length(deck!(gs)), a)
end

@inline games.players!(g::KUHNGame) = g.players 
@inline games.players!(gs::KUHNGameState) = players!(gs.game)

@inline function nextplayer!(position::I) where I <: Integer
    return (position == 2) * 1 + (position == 1) * 2
end

@inline function rotateplayers!(game::KUHNGame)
    players = game.players

    ps = players[1]
    players[1] = players[2]
    players[2] = ps

end

@inline function games.terminal!(gs::KUHNGameState)
    return gs.game_state == ENDED_ID
end

@inline games.actions!(g::KUHNGame) = g.action_set
@inline games.actions!(gs::KUHNGameState) = actions!(gs.game)

@inline game!(gs::KUHNGameState) = gs.game
@inline privatecards!(g::KUHNGame) = g.private_cards
@inline privatecards!(gs::KUHNGameState) = privatecards!(game!(gs))
@inline deck!(g::KUHNGame) = g.deck
@inline deck!(gs::KUHNGameState) = deck!(game!(gs))

@inline function Base.copy!(dest::KUHNGameState{S}, src::KUHNGameState{S}) where S <: GameSetup
    dest.action = src.action
    dest.players_states = copy(src.players_states)
    dest.bets = copy(src.bets)
    
    dest.player = dest.player

    dest.game = src.game

end

@inline function reset!(gs::KUHNGameState{S}) where S<:GameSetup
    gs.pot = 0
    
    bets = gs.bets
    
    for i in eachindex(bets)
        bets[i] = 0
    end

    gs.player = players!(gs)[1]
    gs.action = NULL_ID
    
    gs.position = 1

end

@inline function games.perform(
    a::KUHNAction, 
    gs::KUHNGameState{S}, 
    pl::UInt8) where {S<:GameSetup}

    #perform move and update gamestate
    
    id_ = a.id
    pa = gs.action

    p_is_bet = pa == BET_ID
    p_is_check = pa == CHECK_ID
    folded = id_ == FOLD_ID

    players_states = copy(gs.players_states)
    players_states[pl] = folded * false + !folded * true

    is_bet = id_ == BET_ID
    is_call = id_ == CALL_ID

    bet = (is_bet || is_call) * UInt8(1)

    # gs.pot += bet
    # gs.bets[p] += bet

    bets = copy(gs.bets)
    bets[pl] += bet

    position = nextplayer!(gs.position)
    # gs.action = id_

    end_cond = (p_is_bet && (id_ == BET_ID || folded || is_call)) || (p_is_check && id_ == CHECK_ID) 

    # return end_cond * ENDED_ID + !end_cond * STARTED_ID 

    return KUHNGameState{S}(
        id_, position, 
        gs.pot + bet, 
        players!(gs)[position],
        end_cond * ENDED_ID + !end_cond * STARTED_ID,
        players_states,
        bets,
        game!(gs))

end

end