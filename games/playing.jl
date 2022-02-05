module playing

export perform!
export start!
export sample
export amount
export activateplayers!
export putbackcards!
export distributecards!
export rotateplayers!
export betamount
export update!
export postblinds!
export _postblinds!
export _computepotentialearning!

export callamount

using Random
using StaticArrays

using games

using hermes_exceptions
using players
using actions


@inline function perform!(a::Action, gs::AbstractGameState, pl::T) where T <: Integer
    throw(NotImplementedError())
end

end