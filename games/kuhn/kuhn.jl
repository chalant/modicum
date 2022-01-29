module kuhn

using StaticArrays

using games
using playing
using actions

export getdeck
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

struct KUHNState <: State
    id::UInt8
    mask::MVector{4, Bool}
end

@inline function initialstate()
    mask = @MVector Bool[1,0,1,0]

    return KUHNState(INIT_ID, mask)
end

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
    
    players::MVector{2, UInt8}
    players_states::MVector{2, Bool}
    bets::MVector{2, UInt8}
    
    player::UInt8
    
    game::KUHNGame

end

KUHNGameState{S}(game) where S <: GameSetup = _creategamestate(S, game)

@inline function _creategamestate(::Type{S}, game) where S <: GameSetup
    players = @MVector [UInt8(1), UInt8(2)]
    states = @MVector [true, true]
    bets = @MVector zeros(UInt8, 2)
    
    mask = @MVector Bool[1, 0, 1, 0]
    
    return KUHNGameState{S}(
        NULL_ID,
        mask, 
        INIT_ID,
        UInt8(1),
        UInt8(0),
        players,
        states,
        bets,
        players[1],
        game)
end

@inline function nextplayer!(gs::KUHNGameState)
    n = gs.position 

    n = (n == 2) * 1 + (n == 1) * 2

    gs.position = n

    return gs.players[n]

end

@inline function rotateplayers!(gs::KUHNGameState)
    players = gs.players

    ps = players[1]
    players[1] = players[2]
    players[2] = ps

end

@inline function games.terminal!(state::KUHNState)
    return state.id == ENDED_ID
end

@inline games.actions!(g::KUHNGame) = g.action_set
@inline games.actions!(gs::KUHNGameState) = actions!(gs.game)

@inline privatecards!(g::KUHNGame) = g.private_cards
@inline privatecards!(gs::KUHNGameState) = privatecards!(game!(gs))

@inline function Base.copy!(dest::KUHNGameState{S}, src::KUHNGameState{S}) where S <: GameSetup
    dest.action = src.action
    dest.actions_mask = copy(src.actions_mask)
    dest.players_states = copy(src.players_states)
    dest.players = copy(src.players)
    dest.bets = copy(src.bets)
    

    dest.game = src.game

end

@inline function reset!(gs::KUHNGameState)
    gs.state = STARTED_ID
    gs.pot = 0
    
    bets = gs.bets
    
    for i in eachindex(bets)
        bets[i] = 0
    end

    gs.player = gs.players[1]
    gs.action = NULL_ID
    
    mask = gs.actions_mask

    mask[1] = 1
    mask[2] = 0
    mask[3] = 1
    mask[4] = 0
    
    gs.position = 1
end

@inline function playing.perform!(
    a::KUHNAction, 
    gs::KUHNGameState{S}, 
    p::UInt8) where {S<:GameSetup}
    
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

    end_cond = (p_is_bet && (id_ == BET_ID || id_ == FOLD_ID || id_ == folded || is_call)) || (p_is_check && id_ == CHECK_ID)

    state = end_cond * ENDED_ID + !end_cond * STARTED_ID 

    mask = @MVector zeros(Bool, 4)

    if state == ENDED_ID
        return KUHNState(id, mask)
    end

    #update action mask


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

    gs.player = nextplayer!(gs)
    gs.action = id_

    return KUHNState(state, mask)

end

end