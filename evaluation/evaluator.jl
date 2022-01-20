module evaluator

export evaluate
export evaluateterminal

include("lookup.jl")
include("concat.jl")
include("combinations.jl")

# using IterTools
using Reexport
using StaticArrays

using cards
using combinations

@reexport using .lookup

using .concat

const LOOKUP = create_lookup_table()
#pre-allocate array for concatenation
const CONCAT = Dict{Int64, Vector{UInt64}}(
    5 => SizedVector{5, UInt64}(zeros(UInt64, 5)),
    6 => SizedVector{6, UInt64}(zeros(UInt64, 6)),
    7 => SizedVector{7, UInt64}(zeros(UInt64, 7)),
)

# #pre-allocate combinations
# const COMBOS = subsets(StaticBinomial{K, T})

@inline function five(
    hand::Vector{UInt64},
    flush_lookup::Dict{UInt64, UInt64},
    unsuited_lookup::Dict{UInt64, UInt64})
    #if flush

    if hand[1] & hand[2] & hand[3] & hand[4] & hand[5] & 0xF000 != 0
        handOR = (hand[1] | hand[2] | hand[3] | hand[4] | hand[5]) >> 16
        prime = prime_product_from_rankbits(handOR)
        return flush_lookup[prime]
    else
        prime = prime_product_from_hand(hand)
        return unsuited_lookup[prime]
    end
end

@inline function evaluate(
    ncomb::U,
    private_cards::Vector{UInt64},
    board_cards::Vector{UInt64},
    flush_lookup::Dict{UInt64, UInt64},
    unsuited_lookup::Dict{UInt64, UInt64}) where U <: Integer

    idx = StaticArrays.sacollect(MVector{2, Int64}, 1:2)
    dest = @MVector zeros(UInt64, 2)

    l = length(private_cards) + length(board_cards)
    # @assert l < 8 "Can't evaluate more than 7 cards"
    # @assert l
    conc = CONCAT[l]
    
    if l == 5
        #concatenate in place
        concatenate!(conc, private_cards, board_cards)
        return five(
            conc,
            flush_lookup,
            unsuited_lookup)

    elseif l > 5 && l < 8
        minimum = lookup.MAX_HIGH_CARD
        # j = 0
        for i in 1:ncomb
            #concatenate in place
            concatenate!(conc, private_cards, board_cards)
            score = five(nextcombo!(l, conc, dest, idx), flush_lookup, unsuited_lookup)
            if score < minimum
                # j = i
                if i != 21
                    minimum = score
                end
            end
        end

        # reset!(COMBOS)

        # if j != 21
        #     return minimum
        # else
        #     #if the best hand does not include the private cards,
        #     #the highest hand wins
        #     return highest_card_score(private_cards)
        # end
        # return minimum
        return minimum
    end
end

@inline function evaluateterminal(
    private_cards::AbstractVector{UInt64},
    public_cards::Vector{UInt64})

    conc = @MVector zeros(UInt64, 7)
    dest = @MVector zeros(UInt64, 2)
    
    idx = StaticArrays.sacollect(MVector{2, Int64}, 1:2) 
    
    minimum = lookup.MAX_HIGH_CARD
    # j = 0
    for i in 1:21
        #concatenate in place
        concatenate!(conc, private_cards, public_cards)
        
        score = five(
            nextcombo!(Val(7), conc, dest, idx), 
            flush_lookup, 
            unsuited_lookup)
        
        minimum = (score < minimum && i != 21) * score + (score >= minimum) * minimum
        
        # if score < minimum
        #     # j = i
        #     if i != 21
        #         minimum = score
        #     end
        # end
    end

    # reset!(COMBOS)

    # if j != 21
    #     return minimum
    # else
    #     #if the best hand does not include the private cards,
    #     #the highest hand wins
    #     return highest_card_score(private_cards)
    # end
    # return minimum
    return minimum

end

@inline function evaluate(
    ncomb::U,
    private_cards::Vector{UInt64},
    public_cards::Vector{UInt64}) where U <: Integer
    
    return evaluate(ncomb, private_cards, public_cards, LOOKUP)
end

@inline function evaluate(
    ncomb::U,
    private_cards::Vector{UInt64},
    public_cards::Vector{UInt64},
    lookup_tables::LookupTables) where U <: Integer

    return evaluate(
        ncomb,
        private_cards,
        public_cards,
        lookup_tables.flush,
        lookup_tables.unsuited)
end

@inline function highest_hand(
    hand::Vector{UInt64}, 
    flush_lookup::Dict{UInt64, UInt64},
    unsuited_lookup::Dict{UInt64, UInt64})
    
    """
    Returns a hand of 5 cards with the highest score
    """

    h = hand
    if length(hand) > 5
        for combo in subsets(hand, 5)
            score = five(combo, flush_lookup, unsuited_lookup)
            if score < minimum
                minimum = score
                h = combo
            end
        end
    end
    return h
end

@inline function ranks(
    hand::Vector{UInt64}, 
    flush_lookup::Dict{UInt64, UInt64}, 
    unsuited_lookup::Dict{UInt64, UInt64})
    
    """
    Returns the all the rankings of the hand
    """
    return [five(c, flush_lookup, unsuited_lookup) for c in subsets(hand, 5)]
end

end
