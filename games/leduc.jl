module leduc

export LeDucAction
export LeDucChanceAction
export LeDucGame
export LeDucGameState
export LeDucPublicTree

export rotateplayers!
export setplayer
export placebets
export reset
export chanceid
export ranks
export deck!
export nextround!

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
using dataindex

const NULL_ID = UInt8(0)
const BET_ID = UInt8(1)
const CALL_ID = UInt8(2)
const CHECK_ID = UInt8(3)
const RAISE_ID = UInt8(4)
const FOLD_ID = UInt8(5)

struct LeDucAction{T<:Integer} <: Action
    id::T
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

mutable struct LeDucGame
    action_set::ActionSet{5, LeDucAction{UInt8}}
    players::MVector{2, UInt8}

    deck::SizedVector{6, UInt8}
    private_cards::MVector{2, UInt8}
end

@inline function _creategame(::Type{V}, deck::T) where {V<:Integer, U<:Integer, T<:AbstractVector{U}}
    action_set = ActionSet(SizedVector{5, LeDucAction{V}}(
        LeDucAction{V}(CALL_ID), 
        LeDucAction{V}(BET_ID),
        LeDucAction{V}(FOLD_ID),
        LeDucAction{V}(CHECK_ID),
        LeDucAction{V}(RAISE_ID)))
    
    players = @MVector UInt8[1, 2]
    private_cards = @MVector zeros(UInt8, 2)
    
    return LeDucGame(
        action_set, 
        players, 
        deck,
        private_cards)
end

LeDucGame(::Type{V}, deck::T) where {V<:Integer, T<:AbstractVector{<:Integer}} = _creategame(V, deck)

struct LeDucGameState{S<:GameSetup} <: AbstractGameState{5, S, 2}
    action::UInt8
    position::UInt8
    pot::UInt8

    state::UInt8
    round::UInt8

    players_states::SVector{2, Bool}
    bets::SVector{2, UInt8}

    player::UInt8
    
    game::LeDucGame
    setup::S

end

LeDucGameState(game::LeDucGame, setup::S) where S<:GameSetup = _creategamestate(game, setup)

@inline function _creategamestate(game::LeDucGame, setup::S) where S <: GameSetup
    states = @SVector [true, true]
    bets = @SVector zeros(UInt8, 2)
    
    return LeDucGameState{S}(
        NULL_ID,
        UInt8(1),
        UInt8(0),
        CHANCE_ID,
        UInt8(0),
        states,
        bets,
        players!(game)[1],
        game,
        setup)
end

function ranks(::Type{T}) where T <: Integer
    return Vector{T}(T(1), T(1), T(2), T(2), T(3), T(3))
end

struct LeDucChanceAction{T<:Integer} <: ChanceAction
    id::T
    cards_idx::SVector{3, T}
    index::Union{Index{SVector{3, T}}, LeafIndex{SVector{3, T}}, Nothing}
end

# LeDucChanceAction(id::T, cards_idx::SVector{3, T}, index::Union{Index{SVector{3, T}}, LeafIndex{SVector{3, T}}}) where T<:Integer = LeDucChanceAction{T}(id, cards_idx, index)

@inline function games.terminal!(gs::LeDucGameState)
    return gs.state == ENDED_ID
end

@inline game!(gs::LeDucGameState) = gs.game
@inline games.actions!(g::LeDucGame) = g.action_set
@inline games.actions!(gs::LeDucGameState) = actions!(gs.game)

@inline deck!(g::LeDucGame) = g.deck
@inline deck!(gs::LeDucGameState) = deck!(game!(gs))

@inline function games.chanceid(gs::LeDucGameState, a::LeDucChanceAction{T}) where T<:Integer
    if a.id == 0
        return a.id
    end
    return deck!(gs)[a.id]
end

@inline function games.legalactions!(::Type{K}, gs::LeDucGameState{S}) where {K<:Integer, S<:GameSetup}
    #todo: accessing action_set index allocates memory!

    mask = @SVector zeros(K, 5)

    action = gs.action

    bet_cond = action == CHECK_ID
    call_cond = action == BET_ID || action == RAISE_ID
    raise_cond = action == BET_ID
    reset_cond = action == NULL_ID

    # action_set = actions!(gs)

    #todo: first player to act at the start of any round cannot fold

    j = 1

    for i in 1:5
        if ((bet_cond && (i == BET_ID || i == CHECK_ID)) || (call_cond && (i == CALL_ID || i == FOLD_ID)) || (raise_cond && i == RAISE_ID) || (reset_cond && (i == BET_ID || i == CHECK_ID)))
            mask = setindex(mask, i, j)
            j += 1
        end
    end

    # for i in 1:5
    #     aid = action_set[i].id
    #     mask[i] = bet_cond * ((aid == BET_ID) + (aid == CHECK_ID)) +
    #         call_cond * ((aid == CALL_ID) + (aid == FOLD_ID)) +
    #         raise_cond * (aid == RAISE_ID) + 
    #         reset_cond * ((i == 1) * 1 + (i == 2) * 0 + (i == 3) * 1 + (i == 4) * 0 + (i == 5) * 0)
    #         # * ((is_bet && pa == CALL_ID) +
    #         # (is_bet && p_is_bet) +
    #         # (is_bet && pa == FOLD_ID) +
    #         # (is_check && p_is_check) +
    #         # (is_check && p_is_bet))
    # end

    return (mask, j - 1)

end

@inline privatecards!(g::LeDucGame) = g.private_cards
@inline privatecards!(gs::LeDucGameState) = privatecards!(game!(gs))

@inline players!(g::LeDucGame) = g.players 
@inline players!(gs::LeDucGameState) = players!(gs.game)

@inline function reset(gs::LeDucGameState{S}) where {S<:GameSetup}
    return LeDucGameState{S}(
        NULL_ID,
        UInt8(1),
        UInt8(0),
        INIT_ID,
        UInt8(1),
        SVector{2, Bool}(false, false),
        SVector{2, UInt8}(0, 0),
        players!(gs)[1],
        gs.game,
        gs.setup
    )
end

@inline function setplayer(gs::LeDucGameState{S}, pl::I) where {S<:GameSetup, I<:Integer}
    return LeDucGameState{S}(
        gs.action,
        gs.position,
        gs.pot,
        gs.state,
        gs.round,
        gs.players_states,
        gs.bets,
        pl,
        gs.game,
        gs.setup
    )
end

@inline function placebets(gs::LeDucGameState{S}, values::SVector{2, UInt8}) where {S<:GameSetup}
    return LeDucGameState{S}(
        gs.action,
        gs.position,
        gs.pot + sum(values),
        gs.state,
        gs.round,
        gs.players_states,
        gs.bets + values,
        gs.player,
        gs.game,
        gs.setup
    )
end

function games.action(gs::LeDucGameState{S}, idx::I) where {S<:GameSetup, I<:Integer}
    return LeDucAction{I}(idx)
end

@inline function nextplayer!(position::I) where I <: Integer
    return I((position == 2) * 1 + (position == 1) * 2)
end

@inline function nextround!(gs::LeDucGameState{S}, pl::T) where {S<:GameSetup, T<:Integer}
    #todo: who is the next player? (reset players?)

    return LeDucGameState{S}(
        NULL_ID,
        UInt8(1),
        gs.pot,
        (gs.round == 1) * INIT_ID + (gs.round > 1) * STARTED_ID,
        gs.round + 1,
        gs.players_states,
        gs.bets,
        players!(gs)[1],
        gs.game,
        gs.setup)
end

@inline function games.performchance!(a::LeDucChanceAction, gs::LeDucGameState{S}, pl::U) where {S<:GameSetup, U<:Integer}  
    return LeDucGameState{S}(
        NULL_ID,
        UInt8(1),
        gs.pot,
        (gs.round == 0) * INIT_ID + (gs.round > 0) * STARTED_ID,
        gs.round + 1,
        gs.players_states,
        gs.bets,
        players!(gs)[1],
        gs.game,
        gs.setup)
end

@inline function games.chance!(gs::LeDucGameState)
    return gs.state == CHANCE_ID
end

@inline function games.perform(
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

    is_raise = id_ == RAISE_ID
    is_bet = id_ == BET_ID
    is_call = id_ == CALL_ID

    not_last_round = gs.round < 2

    amount = gs.round * 2

    bet = (is_bet || is_call || is_raise) * amount

    both_checked = (p_is_check && id_ == CHECK_ID)

    nr_cond = (((p_is_raise || p_is_bet) && is_call) || both_checked) && not_last_round

    #todo: we need to return chance id as state!

    position = nextplayer!(gs.position)

    # gs.round += nr_cond * 1

    ended = gs.round >= 2

    end_cond = (((p_is_raise || p_is_bet) && (folded || (is_call && ended))) || (both_checked && ended))

    return LeDucGameState{S}(
        id_,
        position,
        UInt8(gs.pot + bet),
        end_cond * ENDED_ID + !end_cond * (!nr_cond * STARTED_ID + nr_cond * CHANCE_ID),
        gs.round,
        setindex(gs.players_states, folded * false + !folded * true, Int64(pl)),
        setindex(gs.bets, gs.bets[pl] + bet, Int64(pl)),
        players!(gs)[position],
        gs.game,
        gs.setup)
end

@inline function rotateplayers!(game::LeDucGame)
    players = game.players

    ps = players[1]
    players[1] = players[2]
    players[2] = ps

end

@inline function Base.copy!(dest::LeDucGameState{S}, src::LeDucGameState{S}) where S <: GameSetup
    dest.action = src.action
    dest.players_states = copy(src.players_states)
    dest.bets = copy(src.bets)
    
    dest.player = dest.player

    dest.game = src.game

end
end