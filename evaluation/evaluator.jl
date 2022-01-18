module evaluator

export evaluate

include("lookup.jl")
include("concat.jl")
include("combinations.jl")

# using IterTools
using Reexport
using StaticArrays

using cards

@reexport using .lookup
using .combinations
using .concat

const LOOKUP = create_lookup_table()
#pre-allocate array for concatenation
const CONCAT = Dict{Int64, Vector{UInt64}}(
    5 => Vector{UInt64}(undef, 5),
    6 => Vector{UInt64}(undef, 6),
    7 => Vector{UInt64}(undef, 7)
)
#pre-allocate combinations
const COMBOS = subsets(Val(5), UInt64, MVector{5, UInt64})

function five(
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
    private_cards::Vector{UInt64},
    board_cards::Vector{UInt64},
    flush_lookup::Dict{UInt64, UInt64},
    unsuited_lookup::Dict{UInt64, UInt64},
)

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
        for i in 1:length(COMBOS, l)
            #concatenate in place
            concatenate!(conc, private_cards, board_cards)
            score = five(nextcombo!(conc, COMBOS), flush_lookup, unsuited_lookup)
            if score < minimum
                # j = i
                if i != 21
                    minimum = score
                end
            end
        end

        reset!(COMBOS)

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



@inline function evaluate(
    private_cards::StaticVector{2, T},
    public_cards::StaticVector{5, T})

    conc = @MVector zeros(UInt64, 7) 
    
    minimum = lookup.MAX_HIGH_CARD
    # j = 0
    for i in 1:length(COMBOS, 7)
        #concatenate in place
        concatenate!(conc, private_cards, public_cards)
        
        score = five(nextcombo!(conc, COMBOS), flush_lookup, unsuited_lookup)
        
        minimum = (score < minimum && i != 21) * score + (score >= minimum) * minimum
        
        # if score < minimum
        #     # j = i
        #     if i != 21
        #         minimum = score
        #     end
        # end
    end

    reset!(COMBOS)

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
    private_cards::StaticVector{2, T},
    public_cards::StaticVector{5, T},
    mask::StaticVector{5, T}) where T <: Unsigned

    l = sum(mask)

    conc = @MVector zeros(T, l) 
    
    minimum = lookup.MAX_HIGH_CARD
    # j = 0
    for i in 1:length(COMBOS, l)
        #concatenate in place
        concatenate!(conc, private_cards, public_cards)
        
        score = five(nextcombo!(conc, COMBOS, mask), flush_lookup, unsuited_lookup)
        
        minimum = (score < minimum && i != 21) * score + (score >= minimum) * minimum
    end

    reset!(COMBOS)

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

function evaluate(
    private_cards::Vector{UInt64},
    public_cards::Vector{UInt64},)
    return evaluate(private_cards, public_cards, LOOKUP)
end

function evaluate(
    private_cards::Vector{UInt64},
    public_cards::Vector{UInt64},
    lookup_tables::LookupTables,
)
    return evaluate(
        private_cards,
        public_cards,
        lookup_tables.flush,
        lookup_tables.unsuited)
end

function evaluate(
    hand::Vector{UInt64},
    lookup_tables::LookupTables,
)
    l = length(hand)
    # @assert l < 8 "Can't evaluate more than 7 cards"
    # @asset l
    if l == 5
        return five(
            vcat(private_cards, board_cards),
            flush_lookup,
            unsuited_lookup)
    elseif l > 5 && l < 8
        minimum = lookup.MAX_HIGH_CARD

        # j = 0
        for (i, combo) in enumerate(subsets(hand, 5))
            score = five(combo, flush_lookup, unsuited_lookup)
            if score < minimum
                # j = i
                if i != 21
                    minimum = score
                end
            end
        end
        return minimum
    end
end

function highest_hand(hand, flush_lookup, unsuited_lookup)
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

function ranks(hand, flush_lookup, unsuited_lookup)
    """
    Returns the all the rankings of the hand
    """
    return [five(c, flush_lookup, unsuited_lookup) for c in subsets(hand, 5)]
end

end
