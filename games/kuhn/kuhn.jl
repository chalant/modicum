module kuhn

using StaticArrays

using games
using playing
using players
using actions

export getdeck
export perform!
export rotateplayers!

export KUHNGame
export KUHNGameState
export KUHNPlayerState
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


@inline function getdeck()
    res = SizedVector{52, UInt8}(zeros(UInt8, 52))
    
    i = 1
    for c in 1:13
        for _ in 1:4
            res[i] = c
            i += 1
        end
    end

    return res

end

struct KUHNAction <: Action
    id::UInt8
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

mutable struct KUHNPlayerState <: PlayerState
    active::Bool
    id::UInt8

    bet::UInt8

    KUHNPlayerState(id) = new(true, id)
end


@inline function Base.:(==)(a::KUHNPlayerState, b::KUHNPlayerState)
    return a.id == b.id
end

mutable struct KUHNGame
    action_set::ActionSet{4}
    
    deck::Vector{UInt64}
    private_cards::MVector{2, UInt64}
    
    KUHNGame() = new(ActionSet{4, KUHNAction}(MVector{4, KUHNAction}([
        KUHNAction(CALL_ID), 
        KUHNAction(BET_ID),
        KUHNAction(FOLD_ID),
        KUHNAction(CHECK_ID)])))
end

mutable struct KUHNGameState{S<:GameSetup} <: AbstractGameState{4, 2, S}
    action::UInt8
    actions_mask::MVector{4, Bool}
    state::UInt8

    position::UInt8
    pot::UInt8
    
    players_states::SizedVector{2, KUHNPlayerState}
    
    player::KUHNPlayerState
    
    game::KUHNGame

end

KUHNGameState{S}(game) where S <: GameSetup = _creategamestate(S, game)

@inline function _creategamestate(::Type{S}, game) where S <: GameSetup
    states = SizedVector{2, KUHNPlayerState}(KUHNPlayerState(UInt8(1)), KUHNPlayerState(UInt8(2)))
    mask = @MVector Bool[1, 0, 1, 0]
    
    return KUHNGameState{S}(
        NULL_ID,
        mask, 
        INIT_ID,
        UInt8(1),
        UInt8(0),
        states,
        states[1],
        game)
end

@inline function nextplayer!(gs::KUHNGameState)
    n = gs.position 

    n = (n == 2) * 1 + (n == 1) * 2

    gs.position = n

    return gs.players_states[n]

end

@inline function rotateplayers!(gs::KUHNGameState)
    states = gs.players_states

    ps = states[1]
    states[1] = states[2]
    states[2] = ps

end

@inline function games.terminal!(gs::KUHNGameState)
    return gs.state == ENDED_ID
end

@inline games.actions!(g::KUHNGame) = g.action_set
@inline games.actions!(gs::KUHNGameState) = actions!(gs.game)

@inline privatecards!(g::KUHNGame) = g.private_cards
@inline privatecards!(gs::KUHNGameState) = privatecards!(game!(gs))

@inline function Base.copy!(dest::KUHNGameState{S}, src::KUHNGameState{S}) where S <: GameSetup
    dest.action = src.action
    dest.actions_mask = copy(src.actions_mask)

    dest.game = src.game

end

@inline function playing.perform!(
    a::KUHNAction, 
    gs::KUHNGameState{S}, 
    ps::KUHNPlayerState) where {S<:GameSetup}
    
    id_ = a.id
    pa = gs.action

    p_is_bet = pa == BET_ID
    p_is_check = pa == CHECK_ID
    folded = id_ == FOLD_ID

    ps.active = folded * false + !folded * true

    is_bet = id_ == BET_ID
    is_call = id_ == CALL_ID

    bet = (is_bet || is_call) * UInt8(1)

    gs.pot += bet
    ps.bet += bet

    end_cond = (p_is_bet && (id_ == BET_ID || id_ == FOLD_ID || id_ == folded || is_call)) || (p_is_check && id_ == CHECK_ID)

    state = end_cond * ENDED_ID + !end_cond * STARTED_ID 

    if state == ENDED_ID
        gs.state = ENDED_ID
        return gs
    end

    #update action mask

    mask = gs.actions_mask

    bet_cond = id_ == CHECK_ID
    call_cond = id_ == BET_ID

    action_set = actions!(gs)

    for i in 1:4
        aid = action_set[i].id

        is_bet = aid == BET_ID
        is_check = aid == CHECK_ID
        
        mask[i] = bet_cond * (is_bet + is_check) +
            call_cond * ((aid == CALL_ID) + (aid == FOLD_ID))
            # * ((is_bet && pa == CALL_ID) +
            # (is_bet && p_is_bet) +
            # (is_bet && pa == FOLD_ID) +
            # (is_check && p_is_check) +
            # (is_check && p_is_bet))
            
    end

    println("Mask! ", mask)

    gs.player = nextplayer!(gs)
    gs.action = id_

    return gs

end

end