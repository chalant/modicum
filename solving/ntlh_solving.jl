using nlthgames
using cfrplus
using mccfr
using infosets

@inline function NLTHGames.limit!(gs::NLTHGameState{A, P, DepthLimited{T}, U}) where {A, P, T<:Solver, U<:AbstractFloat}
    #override numrounds! functions for depth-limited game setups
    return setup(gs).limit
end

@inline function infosets.infosetkey(gs::NLTHGameState{A, P, S, U}) where {A, P, T<:Solver, U<:AbstractFloat}
    
end

function solve(solver::CFRPlus, itr::IterationStyle)
end

function solver(solver::MCCFR, itr::IterationStyle)
end