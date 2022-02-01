using solving
using cfrplus
using mccfr
using infosets

@inline function infosets.infosetkey(gs::KUHNGameState, pl::Integer)
    return privatecards!(gs)[pl]
end

function solve(solver::CFRPlus{N, T}, itr::IterationStyle)
    
end

function solve(solver::MCCFR{N, T}, itr::IterationStyle)
end