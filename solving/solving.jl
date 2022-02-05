include("infosets.jl")
include("../abstraction/filtering.jl")

using .tree
using .games
using .filtering

# todo add compression data to resources folder
# filter for private cards
const PreFlopFilter = Filter(indexdata(
    IndexData, 
    "/resources/lossless/pre_flop"))

function key(pr::Vector{UInt64}, cc::Vector{UInt64})
    #returns a unique key for a combination of private and public hands
    if length(cc) == 0
        # return equivalent index (after compression)
        return filterindex(PreFlopFilter, pr)
    end
    return evaluate(pr, cc)
end
