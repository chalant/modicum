module actions

export Action
export ActionSet

export SB_ID
export BB_ID
export CALL_ID
export CHECK_ID
export FOLD_ID
export BET_ID
export ALL_ID
export RAISE_ID
export CHANCE_ID

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

export viewactions
export amount
export id
export bigblingamount
export smallblindamount
export raiseamount
export betamount

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

struct Action
    id::UInt8
    amount::Float32
end

mutable struct ActionSet
    actions::Vector{Action}
    sorted::Bool
end

const CALL = Action(CALL_ID, 0)
const FOLD = Action(FOLD_ID, 0)
const CHECK = Action(CHECK_ID, 0)
const ALL = Action(ALL_ID, 0)
const CHANCE = Action(CHANCE_ID, 0)

ActionSet(acts::Vector{Action}) = ActionSet(acts::Vector{Action}, false)

@inline function id(a::Action)
    return a.id
end

@inline function amount(action::Action)
    return action.amount
end

@inline function Base.getindex(actions::ActionSet, index::Int)
    return actions.actions[index]
end

@inline function Base.length(actions::ActionSet)
    return length(actions.actions)
end

@inline function Base.:(==)(p1::Action, p2::Action)
    return p1.id == p2.id && p1.amount == p2.amount
end

@inline function Base.isless(p1::Action, p2::Action)
    if p1.id == p2.id
        return p1.amount <= p2.amount
    end
    return p1.id < p2.id
end

@inline function Base.:(<)(p1::Action, p2::Action)
    return isless(p1, p2)
end

@inline function Base.sort!(s::ActionSet)
    if s.sorted != true
        sort!(s.actions)
        s.sorted = false
    end
end

@inline function Base.push!(s::ActionSet, a::Action)
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

@inline function Base.iterate(a::ActionSet, i::Int)
    return iterate(a.actions, i)
end

@inline function Base.iterate(a::ActionSet)
    return iterate(a, 1)
end

@inline function viewactions(a::ActionSet)
    return a.actions
end

end
