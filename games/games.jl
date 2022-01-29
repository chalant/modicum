module games

export AbstractGameState
export GameSetup

export State

export actions!
export terminal!
export actionsmask!
export evaluateterminal!
export limit!

export INIT_ID
export STARTED_ID
export ENDED_ID
export TERM_ID

export INIT
export STARTED
export ENDED
export TERMINATED

const INIT_ID = UInt8(0)
const STARTED_ID = UInt8(1)
const ENDED_ID = UInt8(2)
const TERM_ID = UInt8(3)
const CHANCE_ID = UInt8(4)

using hermes_exceptions

struct State
    id::UInt8
end

const INIT = State(INIT_ID)
const STARTED = State(STARTED_ID)
const ENDED = State(ENDED_ID)
const TERM = State(TERM_ID)

abstract type GameSetup end
abstract type AbstractGameState{A, S, P} end

# @inline playersstates!(gs::AbstractGameState) = gs.players_states

# @inline playerstate(gs::AbstractGameState) = gs.player

# @inline numrounds!(g::Game) = g.num_rounds
# @inline numrounds!(gs::AbstractGameState) = numrounds!(gs.game)

# @inline limit!(g::Game) = g.num_rounds
# @inline limit!(gs::GameState) = limit!(gs.game)

@inline function actions!(gs::AbstractGameState)
    throw(NotImplementedError()) 
end

@inline function actionsmask!(gs::AbstractGameState)
    throw(NotImplementedError())
end

@inline function terminal!(gs::AbstractGameState)
    throw(NotImplementedError())
end

@inline function evaluateterminal!(gs::AbstractGameState)
    throw(NotImplementedError()) 
end

@inline function limit!(gs::AbstractGameState)
    throw(NotImplementedError())
end

end