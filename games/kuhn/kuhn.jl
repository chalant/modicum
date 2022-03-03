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

export T2

const BET_ID = UInt8(1)
const CALL_ID = UInt8(2)
const CHECK_ID = UInt8(3)
const FOLD_ID = UInt8(4)
const NULL_ID = UInt8(5)

const T2 = TimerOutput()

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
    pot::Float32
    player::UInt8
    game_state::UInt8
    
    players_states::SVector{2, Bool}
    bets::SVector{2, Float32}
    
    game::KUHNGame{MVector{3, UInt8}}

end

KUHNGameState{S}(game::KUHNGame) where S <: GameSetup = _creategamestate(S, game)

@inline function _creategamestate(::Type{S}, game) where S <: GameSetup
    states = @SVector Bool[1, 1]
    bets = @SVector zeros(Float32, 2)
    
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
    mask = @SVector zeros(K, 4)

    action = gs.action

    bet_cond = (action == CHECK_ID)
    call_cond = (action == BET_ID)
    reset_cond = (action == NULL_ID)

    j = 1

    # action_set = actions!(gs)

    for i in 1:5
        if (bet_cond == true && (i == BET_ID || i == CHECK_ID)) || (call_cond == true && (i == CALL_ID || i == FOLD_ID)) || (reset_cond == true && (i == 1 || i == 3))
            mask = setindex(mask, i, j)
            j += 1
        end
        # if bet_cond == true && (i == BET_ID || i == CHECK_ID)
        #     # mask[j] = i
        #     mask = setindex(mask, i, j)
        #     j += 1
        # elseif call_cond == true && (i == CALL_ID || i == FOLD_ID)
        #     # mask[j] = i
        #     mask = setindex(mask, i, j)
        #     j += 1
        # elseif reset_cond == true && (i == 1 || i == 3)
        #     mask = setindex(mask, i, j)
        #     # mask[j] = i
        #     j += 1
        # end
    end

    # println("MASK!! ", mask)

    return (mask, j - 1)

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

    if p_idx > pt.n
        return nothing
    end
    
    if opp_idx >= pt.n
        i  = p_idx + 1
        
        if i > pt.n
            return nothing
        end
        
        j = 1
    else
        i = p_idx
        j = opp_idx + 1
        j = (j == i) * (j + 1) + (j != i) * j
    end

    return (KUHNChanceAction{T}(idx, p_idx, opp_idx), (T(idx + 1), T(i), T(j)))
end

@inline function games.chanceactions!(gs::KUHNGameState, a::KUHNChanceAction{T}) where T<:Integer
    return KUHNPublicTree{T}(3, a)
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
    gs.pot = 0
    
    bets = gs.bets
    
    for i in eachindex(bets)
        bets[i] = 0
    end

    gs.player = players!(gs)[1]
    gs.action = NULL_ID
    
    gs.position = 1

end

@inline function increment!(arr::V, pl::I, i::I, p::T) where {V<:StaticVector, I<:Integer, T<:Real}
    return arr[pl] + (p * (pl == i) + (pl != i) * 0)
end

@inline function set!(arr::V, pl::I, i::I, p::T) where {V<:StaticVector, I<:Integer, T<:Real}
    return p * (pl == i) + (pl != i) * arr[pl]
end


function incrementforplayer!(arr::V, pl::I, value::F) where {A, F<:Real, V<:StaticVector{A, F}, I<:Integer}
    m = MVector{A, F}(arr)
    m[pl] += value
    return SVector{A, F}(m)
end

function setforplayer!(arr::V, pl::I, value::Bool) where {A, V<:StaticVector{A, Bool}, I<:Integer}
    return setindex(arr, value, pl)
end


function games.perform(
    a::KUHNAction, 
    gs::KUHNGameState{S}, 
    pl::UInt8) where {S<:GameSetup}

    #perform move and update gamestate
    
    id_ = a.id
    pa = gs.action

    p_is_bet = pa == BET_ID
    p_is_check = pa == CHECK_ID
    folded = id_ == FOLD_ID
    
    players_states = setindex(gs.players_states, !folded, Int64(pl))
    # players_states[pl] = folded * false + !folded * true

    is_bet = id_ == BET_ID
    is_call = id_ == CALL_ID

    bet = (is_bet || is_call) * oneunit(Float32)

    # gs.pot += bet
    # gs.bets[p] += bet

    bets = incrementforplayer!(gs.bets, pl, bet)

    position = nextplayer!(gs.position)
    # gs.action = id_

    #todo: make function for this
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