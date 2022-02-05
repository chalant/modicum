using nlthgames
using cfrplus
using mccfr
using infosets

@inline function NLTHGames.limit!(gs::NLTHGameState{A, P, DepthLimited{T}, U}) where {A, P, T<:Solver, U<:AbstractFloat}
    #override numrounds! functions for depth-limited game setups
    return setup(gs).limit
end

@inline function infosets.infosetkey(gs::NLTHGameState{A, P, S, T}) where {A, P, S<:GameSetup, T<:AbstractFloat}
    return 
end

function solve(solver::CFRPlus, itr::IterationStyle)
end

function solver(solver::MCCFR, itr::IterationStyle)
end