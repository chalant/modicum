module evaluator

export evaluate

include("lookup.jl")
include("../cards.jl")

using IterTools

using .lookup
using .cards

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

function evaluate(
    private_cards::Vector{UInt64},
    board_cards::Vector{UInt64},
    flush_lookup::Dict{UInt64, UInt64},
    unsuited_lookup::Dict{UInt64, UInt64},
)

    l = length(private_cards) + length(board_cards)
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
        for (i, combo) in enumerate(subsets(vcat(private_cards, board_cards), 5))
            score = five(combo, flush_lookup, unsuited_lookup)
            if score < minimum
                # j = i
                if i != 21
                    minimum = score
                end
            end
        end

        # if j != 21
        #     return minimum
        # else
        #     #if the best hand that does not include the private cards,
        #     #the highest hand wins
        #     return highest_card_score(private_cards)
        # end
        # return minimum
    end
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
