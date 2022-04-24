module kuhn

using StaticArrays
using TimerOutputs
using FunctionWrappers

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

const BET_ID = UInt8(1)
# const CALL_ID = UInt8(2)
const CHECK_ID = UInt8(2)
# const FOLD_ID = UInt8(4)
const NULL_ID = UInt8(3)

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
    action_set::ActionSet{2, KUHNAction{UInt8}}

    players::MVector{2, UInt8}
    
    deck::T
    private_cards::MVector{2, UInt8}
end

@inline function _creategame(deck::T) where {U<:Integer, T<:AbstractVector{U}}

    action_set = ActionSet(SizedVector{2, KUHNAction{UInt8}}(
        KUHNAction{UInt8}(BET_ID),
        KUHNAction{UInt8}(CHECK_ID)))
    
    players = @MVector UInt8[1, 2]
    private_cards = @MVector zeros(UInt8, 2)
    
    return KUHNGame{T}(
        action_set, 
        players, 
        deck, 
        private_cards)
end

KUHNGame{T}() where {U<:Integer, T<:AbstractVector{U}} = _creategame(getdeck(T))
KUHNGame{T}(deck::T) where {U<:Integer, T<:AbstractVector{U}} = _creategame(deck)

struct KUHNGameState{S<:GameSetup} <: AbstractGameState{2, S, 2}
    action::UInt8
    position::UInt8
    pot::Float32
    player::UInt8
    game_state::UInt8

    num_actions::UInt8
    action_sequence::SVector{3, UInt8}
    
    players_states::SVector{2, Bool}
    bets::SVector{2, Float32}
    
    game::KUHNGame{MVector{3, UInt8}}

end

KUHNGameState{S}(game::KUHNGame) where S <: GameSetup = _creategamestate(S, game)

@inline function _creategamestate(::Type{S}, game) where S <: GameSetup
    states = @SVector Bool[1, 1]
    bets = @SVector ones(Float32, 2)
    
    return KUHNGameState{S}(
        NULL_ID,
        UInt8(1),
        UInt8(0),
        players!(game)[1],
        CHANCE_ID,
        UInt8(0),
        SVector{3, UInt8}(0, 0, 0),
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


@inline function _actionmask!(bet_cond::I, call_cond::I, reset_cond::I, aid::K, i::L) where {I<:Integer, K<:Integer, L<:Integer}
    # return bet_cond && ((aid == BET_ID) || (aid == CHECK_ID)) ||
    #     call_cond && ((aid == CALL_ID) || (aid == FOLD_ID)) ||
    #     reset_cond && ((i == 1) || (i != 2) || (i == 3) || (i != 4))
    if bet_cond == true
        return (aid == BET_ID) + (aid == CHECK_ID)
    elseif call_cond == true
        return (aid == CALL_ID) + (aid == FOLD_ID)
    elseif reset_cond == true
        return (i == 1) + (i == 2) * false + (i == 3) + (i == 4) * false
    else
        return false 
    end
end

function games.action(gs::KUHNGameState{S}, idx::I) where {S<:GameSetup, I<:Integer}
    return KUHNAction{I}(idx)
end

# const f = FunctionWrappers.FunctionWrapper{Bool, Tuple{UInt8, UInt8, UInt8, UInt8, Int}}(_actionmask!)

function games.legalactions!(::Type{K}, gs::KUHNGameState{S}) where {S<:GameSetup, K<:Integer}
    # mask = @SVector zeros(K, 2)

    # action = gs.action

    # bet_cond = (action == CHECK_ID)
    # call_cond = (action == BET_ID)
    # reset_cond = (action == NULL_ID)

    # j = 1

    # # action_set = actions!(gs)

    # for i in 1:2
    #     if (bet_cond == true && (i == BET_ID || i == CHECK_ID)) || (call_cond == true && (i == BET_ID || i == CHECK_ID)) || (reset_cond == true && (i == 1 || i == 2))
    #         mask = setindex(mask, i, j)
    #         j += 1
    #     end
    # end

    # println("Mask ", mask)

    # return (mask, j - 1)

    return (SVector{2, K}(1, 2), 2)

end

struct KUHNChanceAction{T<:Integer} <: games.ChanceAction
    idx::T
    arr::Tuple{T, T}
end

@inline function games.chanceid(gs::KUHNGameState, a::KUHNChanceAction)
    return a.idx
end

@inline function games.performchance!(a::KUHNChanceAction{T}, gs::KUHNGameState{S}, pl::T) where {T<:Integer, S<:GameSetup}
    return KUHNGameState{S}(
        gs.action,
        gs.position,
        gs.pot,
        gs.player,
        STARTED_ID,
        UInt8(0),
        gs.action_sequence,
        gs.players_states,
        gs.bets,
        gs.game)
end

@inline function games.performchance!(gs::KUHNGameState{S}) where {T<:Integer, S<:GameSetup}
    return KUHNGameState{S}(
        gs.action,
        gs.position,
        gs.pot,
        gs.player,
        STARTED_ID,
        UInt8(0),
        gs.action_sequence,
        copy(gs.players_states),
        copy(gs.bets),
        gs.game)
end

@inline function games.chance!(gs::KUHNGameState)
    return gs.game_state == CHANCE_ID
end

@inline games.players!(g::KUHNGame) = g.players 
@inline games.players!(gs::KUHNGameState) = players!(gs.game)

@inline function nextplayer!(position::I) where I <: Integer
    return (position == 2) * 1 + (position == 1) * 2
end

@inline function rotateplayers!(gs::KUHNGameState{S}) where S <: GameSetup

    game = game!(gs)
    
    players = game.players

    ps = players[1]
    players[1] = players[2]
    players[2] = ps

    return KUHNGameState{S}(
        gs.action,
        gs.position,
        gs.pot,
        players[1],
        gs.game_state,
        UInt8(0),
        gs.action_sequence,
        copy(gs.players_states),
        copy(gs.bets),
        game
    )

end



@inline function games.terminal!(gs::KUHNGameState)
    return gs.game_state == ENDED_ID
end


function games.actions!(g::KUHNGame) 
     return g.action_set
end

function games.actions!(gs::KUHNGameState)
    return actions!(gs.game)
end

@inline game!(gs::KUHNGameState) = gs.game
@inline privatecards!(g::KUHNGame{T}) where T <: AbstractVector = g.private_cards
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
    return KUHNGameState{S}(
        NULL_ID,
        UInt8(1),
        UInt8(0),
        players!(gs)[1],
        INIT_ID,
        UInt8(0),
        SVector{3, UInt8}(0, 0, 0),
        SVector{2, Bool}(true, true),
        SVector{2, Float32}(0, 0),
        game!(gs))
end

@inline function increment!(arr::V, pl::I, i::I, p::T) where {V<:StaticVector, I<:Integer, T<:Real}
    return arr[pl] + (p * (pl == i) + (pl != i) * 0)
end

@inline function set!(arr::V, pl::I, i::I, p::T) where {V<:StaticVector, I<:Integer, T<:Real}
    return p * (pl == i) + (pl != i) * arr[pl]
end

@inline function incrementforplayer!(arr::V, pl::I, value::F) where {A, F<:Real, V<:StaticVector{A, F}, I<:Integer}
    return setindex(arr, value + arr[pl], Int64(pl))
end

@inline function setforplayer!(arr::V, pl::I, value::Bool) where {A, V<:StaticVector{A, Bool}, I<:Integer}
    return setindex(arr, value, pl)
end

function games.perform(
    a::KUHNAction, 
    gs::KUHNGameState{S}, 
    pl::UInt8) where {S<:GameSetup}

    #perform move and update gamestate
    
    num_actions = gs.num_actions + 1

    id_ = a.id
    pa = gs.action

    p_is_bet = pa == BET_ID
    p_is_check = pa == CHECK_ID
    folded = p_is_bet && id_ == CHECK_ID
    
    players_states = setindex(gs.players_states, !folded, Int64(pl))
    # players_states[pl] = folded * false + !folded * true
    action_sequence = setindex(gs.action_sequence, id_ , Int64(num_actions))

    is_bet = id_ == BET_ID
    # is_call = id_ == CALL_ID

    # bet = (is_bet || is_call) * oneunit(Float32)
    bet = Float32(0)

    # pot = gs.pot
    # # gs.pot += bet
    # # gs.bets[p] += bet
    # if id_ == CHECK_ID || id_ == FOLD_ID
    #     bet = Float32(1)
    # elseif is_call || is_bet
    #     bet = Float32(2)
    # end

    # if num_actions == 3 && id_ == FOLD_ID
    #     pot -= 1
    #     bet -= 1
    # end

    position = nextplayer!(gs.position)
    # gs.action = id_

    if is_bet
        bets = incrementforplayer!(gs.bets, gs.player, Float32(1))
    else
        bets = gs.bets
    end

    #todo: make function for this
    end_cond = (p_is_bet && is_bet) || (p_is_check && id_ == CHECK_ID) || folded

    # if p_is_check && id_ == CHECK_ID
    #     println("Ended! ", p_is_bet && (id_ == BET_ID || folded || is_call))
    # end

    # return end_cond * ENDED_ID + !end_cond * STARTED_ID

    # pot = pot + bet

    return KUHNGameState{S}(
        id_, 
        position, 
        gs.pot, 
        players!(gs)[position],
        end_cond * ENDED_ID + !end_cond * STARTED_ID,
        num_actions,
        action_sequence,
        players_states,
        bets,
        game!(gs))

end

end