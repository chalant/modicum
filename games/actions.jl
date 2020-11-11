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
export ActionSet

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

const CALL_ID = UInt8(1)
const FOLD_ID = UInt8(2)
const CHECK_ID = UInt8(3)
const RAISE_ID =  UInt8(4)
const BET_ID =  UInt8(5)
const SB_ID =  UInt8(6)
const BB_ID =  UInt8(7)
const CHANCE_ID =  UInt8(8)
const ALL_ID =  UInt8(9)

const ACTION_SET1 = Vector{UInt8}([CALL_ID, FOLD_ID, RAISE_ID, ALL_ID])
const ACTION_SET2 = Vector{UInt8}([FOLD_ID, CHECK_ID, BET_ID, ALL_ID])
const ACTION_SET3 = Vector{UInt8}([CHECK_ID, RAISE_ID, ALL_ID])

const AFTER_CALL = Vector{UInt8}([CALL_ID, FOLD_ID, CHECK_ID, RAISE_ID, ALL_ID])
const AFTER_RAISE = ACTION_SET1
const AFTER_CHECK = ACTION_SET2
const AFTER_BET = ACTION_SET1
const AFTER_FOLD = AFTER_CALL
const AFTER_CHANCE = ACTION_SET2
const AFTER_BB = ACTION_SET1
const AFTER_ALL = Vector{UInt8}([CALL_ID, FOLD_ID, CHECK_ID, ALL_ID])
const AFTER_SB = Vector{UInt8}([BB_ID])

abstract type Action end
abstract type AbstractBet <: Action end
abstract type Blind <: AbstractBet end

struct Call <: AbstractBet
    id::UInt8
    Call() = new(CALL_ID)
end

struct Fold <: Action
    id::UInt8
    Fold() = new(FOLD_ID)
end

struct Check <: Action
    id::UInt8
    Check() = new(CHECK_ID)
end

struct Chance <: Action
    id::UInt8
    Chance() = new(CHANCE_ID)
end

struct Raise <: AbstractBet
    id::UInt8
    amount::Float16
    Raise(x::AbstractFloat) = new(RAISE_ID, x)
end

struct Bet <: AbstractBet
    id::UInt8
    amount::Float16
    Bet(x::AbstractFloat) = new(BET_ID, x)
end

struct All <: AbstractBet
    id::UInt8
    All() = new(ALL_ID)
end

struct SmallBlind <: Blind
    id::UInt8
    amount::Float16
    SmallBlind(x::AbstractFloat) = new(SB_ID, x)
end

struct BigBlind <: Blind
    id::UInt8
    amount::Float16
    BigBlind(x::AbstractFloat) = new(BB_ID, x)
end

struct ActionSet
    actions::Vector{Action}
    sorted::Bool
end

ActionSet(acts::Vector{Action}) = ActionSet(acts::Vector{Action}, false)

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

function Base.:(<)(p1::Action, p2::Action)
    return isless(p1, p2)
end

function Base.sort!(s::ActionSet)
    if s.sorted != true
        sort!(s.actions)
        s.sorted = false
    end
end

function Base.push!(s::ActionSet, a::Action)
    # add element by maintaining order.
    sort!(s)
    i = 1
    for k in s
        if a < k
            # insert element in a sorted array
            insert!(s.actions, i, a)
        end
        i += 1
    end
end

function Base.iterate(a::ActionSet, i::Int)
    return iterate(a.actions, i)
end
end
