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
export action
export ended
export depthlimit
export chanceid

export INIT_ID
export STARTED_ID
export ENDED_ID
export TERM_ID
export CHANCE_ID

export ChanceAction

include("actions.jl")

using StaticArrays

using hermes_exceptions
using .actions

const INIT_ID = UInt8(0)
const STARTED_ID = UInt8(1)
const ENDED_ID = UInt8(2)
const TERM_ID = UInt8(3)
const CHANCE_ID = UInt8(4)

abstract type ChanceAction end
abstract type State end

abstract type GameSetup end

#A: number of actions, S: game setup, P: number of players
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

@inline function terminal!(gs::G) where G <: AbstractGameState
    throw(NotImplementedError())
end

@inline function ended(gs::AbstractGameState)
    throw(NotImplementedError())
end

@inline function depthlimit(gs::AbstractGameState)
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

@inline function chanceid(a::ChanceAction)
    throw(NotImplementedError())
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

function action(gs::AbstractGameState, idx::I) where I<:Integer
    throw(NotImplementedError())
end

function legalactions!(::Type{K}, mask::SVector{A, UInt8}, n_actions::T) where {A, K<:Integer, T<:Integer}
    # sorts actions such that the active ones are at the top 

    idx = StaticArrays.sacollect(SVector{A, K}, 1:A)
    
    #todo we might not need to copy the mask, since it gets overwritten anyway

    # j = K(1)

    # for i in 1:A
    #     m = mask[i]
    #     idx[j] = i * (m == 1) + (m == 0) * mask[j]
    #     j += m
    # end

    i = 1
    
    while i < n_actions + 1
        
        if mask[i] == 0
            j = i + 1
            
            while j < A + 1
                
                if mask[j] == 1
                    #permute index
                    k = idx[i]
                    # idx[i] = idx[j]
                    # idx[j] = k

                    idx = setindex(idx, idx[j], i)
                    idx = setindex(idx, k, j)
                    
                    mask = setindex(mask, 1, i)
                    mask = setindex(mask, 0, j)
                    
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