module indexing

export Indexer
export indexer
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

function indexer(
        cards::Vector{UInt64},
        outer_length::Int64,
        inner_length::Int64,
        leap::Bool=true,
)

    nc = length(cards)

    if leap == true
        l = binomial(nc - outer_length, inner_length)
    else
        l = 1
    end

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

function handindex(
    idxr::Indexer,
    hand::Vector{UInt64},
)
    deck_length = idxr.deck_length
    hand_length = idxr.outer_length

    a = binomial(deck_length, hand_length)
    i = 0

    for h in hand
        a -= binomial(deck_length - searchsortedfirst(idxr.cards, h),
                hand_length - i)
        i += 1
    end
    return a
end

function handindex(
    idxr::Indexer,
    hand::Vector{UInt64},
    missing_idx::Vector{Int64},
)

    deck_length = idxr.deck_length - idxr.outer_length

    a = binomial(deck_length, idxr.inner_length)
    i = 0
    for h in hand
        f = searchsortedfirst(idxr.cards, h)
        for m in missing_idx
            if f >= m
                f -= 1
            end
        end

        a -= binomial(deck_length - f, idxr.inner_length - i)
        i += 1
    end
    return a
end

function handindex(
    idxr::Indexer,
    inner_hand::Vector{UInt64},
    missing_index::Vector{Int64},
    outer_hand_index::Int64,
)
    return (outer_hand_index - 1) * idxr.leap + get_hand_index(
        idxr,
        inner_hand,
        missing_index,
    )

end

function handindex(
    idxr::Indexer,
    outer_hand::Vector{UInt64},
    inner_hand::Vector{UInt64},
)

    a = get_hand_index(idxr, outer_hand)
    missing_index = missingindex!(
        idxr.cards,
        outer_hand,
        idxr.missing_index,
        idxr.outer_length,
    )

    return (a - 1) * idxr.leap + get_hand_index(
        idxr, inner_hand, missing_index
    )
end

function missingindex!(
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
