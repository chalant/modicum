module hands_indexer

export Indexer
export get_indexer
export get_hand_index

struct Indexer
    leap::Int64
    hand_length::Int64
    outer_length::Int64
    inner_length::Int64
    cards::Vector{UInt64}
    missing_index::Vector{Int64}
    deck_length::Int64
end

function get_indexer(
    cards::Vector{UInt64},
    outer_length::Int64,
    inner_length::Int64
)
end

function get_indexer(
        cards::Vector{UInt64},
        outer_length::Int64,
        inner_length::Int64,
        leap::Bool=true,
)

    if leap == true
        l = binomial(nc - outer_length, inner_length)
    else
        l = 1
    end

    nc = length(cards)
    return Indexer(
        l,
        outer_length + inner_length,
        outer_length,
        inner_length,
        cards,
        Vector{Int64}(undef, outer_length),
        nc
    )
end

function get_hand_index(
    indexer::Indexer,
    hand::Vector{UInt64},
)
    deck_length = indexer.deck_length
    hand_length = indexer.outer_length

    a = binomial(deck_length, hand_length)
    i = 0

    for h in hand
        a -= binomial(deck_length - searchsortedfirst(indexer.cards, h),
                hand_length - i)
        i += 1
    end
    return a
end

function get_hand_index(
    indexer::Indexer,
    hand::Vector{UInt64},
    missing_idx::Vector{Int64},
)

    deck_length = indexer.deck_length - indexer.outer_length

    a = binomial(deck_length, indexer.inner_length)
    i = 0
    for h in hand
        f = searchsortedfirst(indexer.cards, h)
        for m in missing_idx
            if f >= m
                f -= 1
            end
        end

        a -= binomial(deck_length - f, indexer.inner_length - i)
        i += 1
    end
    return a
end

function get_hand_index(
    indexer::Indexer,
    inner_hand::Vector{UInt64},
    missing_index::Vector{Int64},
    outer_hand_index::Int64,
)
    return (outer_hand_index - 1) * indexer.leap + get_hand_index(
        indexer,
        inner_hand,
        missing_index,
    )

end

function get_hand_index(
    indexer::Indexer,
    outer_hand::Vector{UInt64},
    inner_hand::Vector{UInt64},
)

    a = get_hand_index(indexer, outer_hand)
    missing_index = get_missing_index(
        indexer.cards,
        outer_hand,
        indexer.missing_index,
        indexer.outer_length,
    )

    return (a - 1) * indexer.leap + get_hand_index(
        indexer, inner_hand, missing_index
    )
end

function get_missing_index(
    cards::Vector{UInt64},
    hand::Vector{UInt64},
    missing_index::Vector{Int64},
    hand_length::Int64,
)
    for i in 1:hand_length
        missing_index[i] = searchsortedfirst(cards, hand[hand_length - i + 1])
    end
    return missing_index
end
end
