module hands_filter

struct Indexer
    leap::Int64
    hand_length::Int64
    private_cards_length::Int64
    board_cards_length::Int64
    cards::Vector{UInt64}
    missing_index::Vector{Int64}
    deck_length::Int64
end

function get_indexer(
        cards::Vector{UInt64},
        private_cards_length::Int64,
        board_cards_length::Int64,
)

    nc = length(cards)
    return Indexer(
        binomial(nc - 2, board_cards_length),
        private_cards_length + board_cards_length,
        private_cards_length,
        board_cards_length,
        cards,
        Vector{Int64}(undef, private_cards_length),
        nc
    )
end

function get_hand_index(
    indexer::Indexer,
    hand::Vector{UInt64},
)
    deck_length = indexer.deck_length
    hand_length = indexer.hand_length

    a = binomial(deck_length, hand_length)
    i = 0

    for h in hand
        a -=
            binomial(deck_length - searchsortedfirst(cards, h), hand_length - i)
        i += 1
    end
    return a
end

function get_hand_index(
    indexer::Indexer,
    hand::Vector{UInt64},
    missing_idx::Vector{Int64},
)

    deck_length = indexer.deck_length - indexer.private_cards_length
    hand_length = indexer.hand_length - indexer.private_cards_length

    a = binomial(deck_length, hand_length)
    i = 0
    for h in hand
        f = searchsortedfirst(cards, h)

        for m in missing_idx
            if f > m
                f -= 1
            end
        end

        a -= binomial(deck_length - f,
            hand_length - i)
        i += 1
    end
    return a
end

function get_hand_index(
    indexer::Indexer,
    public_hand::Vector{UInt64},
    missing_index::Vector{Int64},
    private_hand_index::Int64,
)
    return (private_hand_index - 1) * indexer.leap + get_hand_index(
        indexer,
        public_hand,
        missing_index,
    )

end

function get_hand_index(
    indexer::Indexer,
    private_hand::Vector{UInt64},
    public_hand::Vector{UInt64},
    missing_index::Vector{Int64},
)

    a = get_hand_index(indexer, private_hand)
    missing_index = get_missing_index(
        indexer.cards,
        private_hand,
        indexer.missing_index)

    return (a - 1) * indexer.leap + get_hand_index(
        indexer, public_hand, missing_index
    )
end

function get_missing_index(
    cards::Vector{UInt64},
    hand::Vector{UInt64},
    missing_index::Vector{Int64},
    hand_length::Int64,
)

    for i in 1:hand_length
        # missing_index[2] = searchsortedfirst(cards, hand[1])
        missing_index[(hand_length - i) + 1] = searchsortedfirst(cards, hand[i])
    return missing_index
end

end
end
