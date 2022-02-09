module leduc

export LeDucAction
export LeDucChanceAction
export LeDucGame
export LeDucGameState
export LeDucPublicTree

export rotateplayers!
export reset!

export NULL_ID
export BET_ID
export CALL_ID
export CHECK_ID
export RAISE_ID
export FOLD_ID

using StaticArrays

using games
using actions
using playing

const NULL_ID = UInt8(0)
const BET_ID = UInt8(1)
const CALL_ID = UInt8(2)
const CHECK_ID = UInt8(3)
const RAISE_ID = UInt8(4)
const FOLD_ID = UInt8(5)

struct LeDucChanceAction{T<:Integer} <: ChanceAction
    idx::T
    public_idx::T
end

struct LeDucAction <: Action
    id::UInt64
end

@inline function Base.isless(a::LeDucAction, b::LeDucAction)
    return a.id < b.id
end

@inline function Base.:(==)(a::LeDucAction, b::LeDucAction)
    return a.id == b.id
end

@inline function Base.:(<)(a::LeDucAction, b::LeDucAction)
    return isless(a, b)
end

Base.hash(a::LeDucAction, h::UInt) = hash(a.id, hash(:LeDucAction, h))

mutable struct LeDucGame{T<:AbstractVector{<:Integer}}
    action_set::ActionSet{5}
    players::MVector{2, UInt8}

    deck::T
    pc_idx::UInt8
    private_cards::MVector{2, UInt8}
end

@inline function _creategame(deck::T) where {U<:Integer, T<:AbstractVector{U}}
    action_set = ActionSet{5, LeDucAction}(MVector{5, LeDucAction}([
        LeDucAction(CALL_ID), 
        LeDucAction(BET_ID),
        LeDucAction(FOLD_ID),
        LeDucAction(CHECK_ID),
        LeDucAction(RAISE_ID)]))
    
    players = @MVector UInt8[1, 2]
    private_cards = @MVector zeros(UInt8, 2)
    
    return LeDucGame{T}(
        action_set, 
        players, 
        deck,
        UInt8(0), 
        private_cards)
end

LeDucGame{T}(deck) where T<:AbstractVector{<:Integer} = _creategame(deck)

mutable struct LeDucGameState{S<:GameSetup} <: AbstractGameState{5, 2, S}
    action::UInt64
    position::UInt8
    pot::UInt8

    round::UInt8

    players_states::MVector{2, Bool}
    bets::MVector{2, UInt8}

    player::UInt8
    public_card::UInt8
    
    game::LeDucGame

end

LeDucGameState{S}(game) where S<:GameSetup = _creategamestate(S, game)

@inline function _creategamestate(::Type{S}, game) where S <: GameSetup
    states = @MVector [true, true]
    bets = @MVector zeros(UInt8, 2)
    
    return LeDucGameState{S}(
        NULL_ID,
        UInt8(1),
        UInt8(0),
        UInt8(1),
        states,
        bets,
        players!(game)[1],
        UInt8(0),
        game)
end

@inline function games.initialstate(gs::LeDucGameState)
    return INIT_ID
end

struct LeDucPublicTree{T<:Integer}
    n::T
    private_idx::T
    chance_action::LeDucChanceAction{T}
end

@inline Base.iterate(pt::LeDucPublicTree{T}) where T<:Integer = pt.chance_action

@inline function Base.iterate(pt::LeDucPublicTree{T}, a::LeDucChanceAction{T}) where T<:Integer
    if a.public_idx >= pt.n
        return nothing
    end
    
    i = a.public_idx + 1
    
    #exclude main player private card
    if pt.private_idx != i
        return KUHNChanceAction{T}(a.idx + 1, i)
    else
        i += 1
        return KUHNChanceAction{T}(a.idx + 2, i)
    end
end

@inline function games.chanceactions!(gs::LeDucGameState, a::LeDucChanceAction, pl::T) where T<:Integer
    return LeDucPublicTree(6, privatecards!(gs)[pl], a)
end

@inline function games.terminal!(gs::LeDucGameState, state::T) where T <: Integer
    return state == ENDED_ID
end

@inline game!(gs::LeDucGameState) = gs.game
@inline games.actions!(g::LeDucGame) = g.action_set
@inline games.actions!(gs::LeDucGameState) = actions!(gs.game)

@inline function games.actionsmask!(gs::LeDucGameState)
    mask = @MVector zeros(Bool, 5)

    action = gs.action

    bet_cond = action == CHECK_ID
    call_cond = action == BET_ID || action == RAISE_ID
    raise_cond = action == BET_ID
    reset_cond = action == NULL_ID

    action_set = actions!(gs)

    #todo: first player to act at the start of any round cannot fold

    for i in 1:5
        aid = action_set[i].id
        mask[i] = bet_cond * ((aid == BET_ID) + (aid == CHECK_ID)) +
            call_cond * ((aid == CALL_ID) + (aid == FOLD_ID)) +
            raise_cond * (aid == RAISE_ID) + 
            reset_cond * ((i == 1) + (i == 2) * 0 + (i == 3) + (i == 4) * 0 + (i == 5) * 0)
            # * ((is_bet && pa == CALL_ID) +
            # (is_bet && p_is_bet) +
            # (is_bet && pa == FOLD_ID) +
            # (is_check && p_is_check) +
            # (is_check && p_is_bet))
    end

    return mask

end

@inline privatecards!(g::LeDucGame) = g.private_cards
@inline privatecards!(gs::LeDucGameState) = privatecards!(game!(gs))

@inline players!(g::LeDucGame) = g.players 
@inline players!(gs::LeDucGameState) = players!(gs.game)

@inline function nextplayer!(gs::LeDucGameState)
    n = gs.position 

    n = (n == 2) * 1 + (n == 1) * 2

    gs.position = n

    return players!(gs)[n]

end

@inline function nextround!(gs::LeDucGameState{S}, pl::T) where {S<:GameSetup, T<:Integer}
    gs.round += 1
    gs.action = NULL_ID
end

@inline function games.performchance!(a::LeDucChanceAction, gs::LeDucGameState{S}, pl::U) where {S<:GameSetup, U<:Integer}
    gs.public_card = game!(gs).deck[a.public_idx]
    nextround!(gs, pl)
end

@inline function games.chance!(gs::LeDucGameState, state::T) where T <: Integer
    return state == CHANCE_ID
end

@inline function playing.perform!(
    a::LeDucAction, 
    gs::LeDucGameState{S}, 
    pl::T) where {S<:GameSetup, T<:Integer}

    #perform move and update gamestate
    
    id_ = a.id
    pa = gs.action

    p_is_bet = pa == BET_ID
    p_is_raise = pa == RAISE_ID
    p_is_check = pa == CHECK_ID
    folded = id_ == FOLD_ID

    gs.players_states[pl] = folded * false + !folded * true

    is_raise = id_ == RAISE_ID
    is_bet = id_ == BET_ID
    is_call = id_ == CALL_ID

    not_last_round = gs.round < 2

    amount = gs.round * 2

    bet = (is_bet || is_call || is_raise) * amount

    gs.pot += bet
    gs.bets[pl] += bet

    both_checked = (p_is_check && id_ == CHECK_ID)

    nr_cond = (((p_is_raise || p_is_bet) && is_call) || both_checked) && not_last_round

    #todo: we need to return chance id as state!

    gs.action = id_

    gs.player = nextplayer!(gs)

    # gs.round += nr_cond * 1

    ended = gs.round >= 2

    end_cond = (((p_is_raise || p_is_bet) && (folded || (is_call && ended))) || (both_checked && ended))

    return end_cond * ENDED_ID + !end_cond * (!nr_cond * STARTED_ID + nr_cond * CHANCE_ID)

end

@inline function rotateplayers!(game::LeDucGame)
    players = game.players

    ps = players[1]
    players[1] = players[2]
    players[2] = ps

end

@inline function reset!(gs::LeDucGameState)
    gs.pot = 0
    
    bets = gs.bets
    
    for i in eachindex(bets)
        bets[i] = 0
    end

    gs.player = players!(gs)[1]
    gs.action = NULL_ID
    gs.round = 1
    
    gs.position = 1
end

@inline function Base.copy!(dest::LeDucGameState{S}, src::LeDucGameState{S}) where S <: GameSetup
    dest.action = src.action
    dest.players_states = copy(src.players_states)
    dest.bets = copy(src.bets)
    
    dest.player = dest.player

    dest.game = src.game

end
end