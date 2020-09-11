module evaluator

export evaluate
include("lookup.jl")
include("../cards.jl")

using .lookup
using .cards
using IterTools

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
    hand::Vector{UInt64},
    flush_lookup::Dict{UInt64, UInt64},
    unsuited_lookup::Dict{UInt64, UInt64})
    l = length(hand)
    # @assert l < 8 "Can't evaluate more than 7 cards"
    # @asset l
    if l == 5
        return five(hand, flush_lookup, unsuited_lookup)
    elseif l > 5 && l < 8
        minimum = lookup.MAX_HIGH_CARD

        for combo in subsets(hand, 5)
            score = five(combo, flush_lookup, unsuited_lookup)
            if score < minimum
                minimum = score
            end
        end
        return minimum
    end
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
    return h
    end
end

function ranks(hand, flush_lookup, unsuited_lookup)
    """
    Returns the all the rankings of the hand
    """
    return [five(c, flush_lookup, unsuited_lookup) for c in subsets(hand, 5)]
end
