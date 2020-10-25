module actions

export Action
export SmallBlind
export BigBlind
export Fold
export Call
export Raise
export Check
export Chance
export Bet
export All
export Blind
export AbstractBet

export CALL
export FOLD
export CHECK
export CHANCE
export ALL

export AFTER_CALL
export AFTER_RAISE
export AFTER_CHECK
export AFTER_BET
export AFTER_FOLD
export AFTER_CHANCE
export AFTER_BB
export AFTER_ALL
export AFTER_SB
export ACTION_SET3

export update!

const CALL_ID = 1
const FOLD_ID = 2
const CHECK_ID = 3
const RAISE_ID = 4
const BET_ID = 5
const SB_ID = 6
const BB_ID = 7
const CHANCE_ID = 8
const ALL_ID = 9

const ACTION_SET1 = Tuple{Vararg{Int8}}([CALL_ID, FOLD_ID, RAISE_ID, ALL_ID])
const ACTION_SET2 = Tuple{Vararg{Int8}}([CHECK_ID, BET_ID, ALL_ID])
const ACTION_SET3 = Tuple{Vararg{Int8}}([CHECK_ID, RAISE_ID, ALL_ID])

const AFTER_CALL = ACTION_SET1
const AFTER_RAISE = ACTION_SET1
const AFTER_CHECK = ACTION_SET2
const AFTER_BET = ACTION_SET1
const AFTER_FOLD = ACTION_SET1
const AFTER_CHANCE = ACTION_SET2
const AFTER_BB = ACTION_SET1
const AFTER_ALL = Tuple{Vararg{Int8}}([CALL_ID, FOLD_ID])
const AFTER_SB = Tuple{Vararg{Int8}}([BB_ID])

abstract type Action end
abstract type AbstractBet <: Action end
abstract type Blind <: AbstractBet end

struct Call <: AbstractBet
    id::Int
    Call() = new(CALL_ID)
end

struct Fold <: Action
    id::Int
    Fold() = new(FOLD_ID)
end

struct Check <: Action
    id::Int
    Check() = new(CHECK_ID)
end

struct Chance <: Action
    id::Int
    Chance() = new(CHANCE_ID)
end

struct Raise <: AbstractBet
    id::Int
    amount::AbstractFloat
    Raise(x::AbstractFloat) = new(RAISE_ID, x)
end

struct Bet <: AbstractBet
    id::Int
    amount::AbstractFloat
    Bet(x::AbstractFloat) = new(BET_ID, x)
end

struct All <: AbstractBet
    id::Int
    All() = new(ALL_ID)
end

struct SmallBlind <: Blind
    id::Int
    amount::AbstractFloat
    SmallBlind(x::AbstractFloat) = new(SB_ID, x)
end

struct BigBlind <: Blind
    id::Int
    amount::AbstractFloat
    BigBlind(x::AbstractFloat) = new(BB_ID, x)
end

const CALL = Call()
const FOLD = Fold()
const CHECK = Check()
const CHANCE = Chance()
const ALL = All()

function amount(action::AbstractBet)
    return action.amount
end

function Base.:(==)(p1::Action, p2::Action)
    return p1.id == p2.id
end

function Base.:(==)(a1::AbstractBet, a2::AbstractBet)
    return a1.id == a2.id && a1.amount == a2.amount
end

function Base.isless(p1::Action, p2::Action)
    return p1.id < p2.id
end

function Base.isless(a1::AbstractBet, a2::AbstractBet)
    if a1.id == a2.id
        return a1.amount < a2.amount
    end
    return a1.id < a2.id
end

end
