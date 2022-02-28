module games

export AbstractGameState
export GameSetup

export State

export actions!
export terminal!
export actionsmask!
export evaluateterminal!
export limit!
export initialactionsmask
export initialstate
export initialchanceaction
export chance!
export nextround!
export performchance!
export perform
export perform!
export players!
export legalactions!
export chanceactions!
export chanceprobability!

export INIT_ID
export STARTED_ID
export ENDED_ID
export TERM_ID
export CHANCE_ID

include("actions.jl")

using StaticArrays

using hermes_exceptions
using .actions

const INIT_ID = UInt8(0)
const STARTED_ID = UInt8(1)
const ENDED_ID = UInt8(2)
const TERM_ID = UInt8(3)
const CHANCE_ID = UInt8(4)

abstract type State end

abstract type GameSetup end
abstract type AbstractGameState{A, S, P} end

# @inline playersstates!(gs::AbstractGameState) = gs.players_states

# @inline playerstate(gs::AbstractGameState) = gs.player

# @inline numrounds!(g::Game) = g.num_rounds
# @inline numrounds!(gs::AbstractGameState) = numrounds!(gs.game)

# @inline limit!(g::Game) = g.num_rounds
# @inline limit!(gs::GameState) = limit!(gs.game)

@inline function initialstate(gs::AbstractGameState)
    throw(NotImplementedError())
end

@inline function actions!(gs::AbstractGameState)
    throw(NotImplementedError()) 
end

@inline function initialactionsmask(gs::AbstractGameState)
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

@inline function nextround!(gs::AbstractGameState)
end

@inline function performchance!(a::ChanceAction, gs::AbstractGameState)
    throw(NotImplementedError())
end

@inline function chanceactions!(gs::AbstractGameState, ca::ChanceAction)
    throw(NotImplementedError())
end

@inline function initialchanceaction(gs::AbstractGameState)
    throw(NotImplementedError())
end

@inline function chance!(gs::AbstractGameState)
    return false
end

@inline function chanceprobability!(::Type{T}, gs::AbstractGameState, ca::Action) where T <: AbstractFloat
    throw(NotImplementedError())
end

@inline function perform(a::Action, gs::AbstractGameState, pl::I) where I <: Integer
    throw(NotImplementedError())
end

@inline function perform!(a::Action, dest::AbstractGameState, src::AbstractGameState, pl::I) where I <: Integer
end

@inline function perform!(a::Action, gs::AbstractGameState, pl::I) where I <: Integer
    throw(NotImplementedError())
end

@inline function players!(gs::AbstractGameState)
end

@inline function legalactions!(::Type{K}, mask::MVector{A, Bool}, n_actions::T) where {A, K<:Integer, T<:Integer}
    # sorts actions such that the active ones are at the top 

    idx = StaticArrays.sacollect(MVector{A, K}, 1:A)
    
    #todo we might not need to copy the mask, since it gets overwritten anyway
    
    i = 1

    while i < n_actions + 1
        
        if mask[i] == 0
            j = i + 1
            
            while j < A + 1
                
                if mask[j] == 1
                    #permute index
                    k = idx[i]
                    idx[i] = idx[j]
                    idx[j] = k
                    mask[i] = 1
                    mask[j] = 0
                    
                    break
                
                end

                j += 1

            end
        end

        i += 1
    end

    return idx

end

end