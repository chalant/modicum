# module strength_lookup
"""
Number of Distinct Hand Values:
Straight Flush   10
Four of a Kind   156      [(13 choose 2) * (2 choose 1)]
Full Houses      156      [(13 choose 2) * (2 choose 1)]
Flush            1277     [(13 choose 5) - 10 straight flushes]
Straight         10
Three of a Kind  858      [(13 choose 3) * (3 choose 1)]
Two Pair         858      [(13 choose 3) * (3 choose 2)]
One Pair         2860     [(13 choose 4) * (4 choose 1)]
High Card      + 1277     [(13 choose 5) - 10 straights]
-------------------------
TOTAL            7462
Here we create a lookup table which maps:
    5 card hand's unique prime product => rank in range [1, 7462]
Examples:
* Royal flush (best hand possible)          => 1
* 7-5-4-3-2 unsuited (worst hand possible)  => 7462
"""
module lookup

export create_lookup_table
export highest_card_score
export LookupTables

export MAX_RANK

include("../cards.jl")

using IterTools

using .cards

const MAX_STRAIGHT_FLUSH = UInt64(10)
const MAX_FOUR_OF_A_KIND = UInt64(166)
const MAX_FULL_HOUSE = UInt64(322)
const MAX_FLUSH = UInt64(1599)
const MAX_STRAIGHT = UInt64(1609)
const MAX_THREE_OF_A_KIND = UInt64(2467)
const MAX_TWO_PAIR = UInt64(3325)
const MAX_PAIR = UInt64(6185)
const MAX_HIGH_CARD = UInt64(7462)
const MAX_RANK = 7462

const MAX_TO_RANK_CLASS = Dict{UInt64,UInt64}(
    MAX_STRAIGHT_FLUSH => 1,
    MAX_FOUR_OF_A_KIND => 2,
    MAX_FULL_HOUSE => 3,
    MAX_FLUSH => 4,
    MAX_STRAIGHT => 5,
    MAX_THREE_OF_A_KIND => 6,
    MAX_TWO_PAIR => 7,
    MAX_PAIR => 8,
    MAX_HIGH_CARD => 9)

const RANK_CLASS_TO_STRING = Dict{UInt64,String}(
    1 => "Straight Flush",
    2 => "Four of a Kind",
    3 => "Full House",
    4 => "Flush",
    5 => "Straight",
    6 => "Three of a Kind",
    7 => "Two Pair",
    8 => "Pair",
    9 => "High Card"
)

struct BitSequence
    bits::UInt64
    limit::UInt64
end

function Base.iterate(sequence::BitSequence)
    bits = sequence.bits
    t = UInt64(bits | (bits - 1)) + 1
    nxt = UInt64((t | ((UInt64((t&-t)/(bits&-bits)) >> 1)  -1)))
    state = (nxt, UInt64(0))
    return nxt, state
end

function Base.iterate(sequence::BitSequence, state::Tuple{UInt64,UInt64})
    nxt, idx = state
    idx += UInt64(1)
    if idx == sequence.limit
        return nothing
    end
    t = UInt64((nxt | (nxt -1)) + 1)
    nxt = UInt64(t | ((((t & -t) ÷ (nxt & -nxt)) >> 1) - 1))
    state = (nxt, idx)
    return nxt, state
end

function straight_and_highcards(
    straights::Array{UInt64,1},
    highcards::Array{UInt64,1},
    unsuited_lookup::Dict{UInt64,UInt64})
    rank = MAX_FLUSH + 1
    for s in straights
        prime_product = prime_product_from_rankbits(s)
        unsuited_lookup[prime_product] = rank
        rank += 1
    end

    rank = MAX_PAIR + 1
    for h in highcards
        prime_product = prime_product_from_rankbits(h)
        unsuited_lookup[prime_product] = rank
        rank += 1
    end
    return unsuited_lookup
end

function multiples(unsuited_lookup)
    backwards_ranks::Array{UInt64,1} = reverse([i for i in 0:12])
    rank = MAX_STRAIGHT_FLUSH + UInt64(1)

    # 1) Four a Kind

    for i in backwards_ranks
        kickers::Array{UInt64,1} = copy(backwards_ranks)
        filter!(e->e!=i,kickers)
        for k in kickers
            product = (PRIMES[i + 1] ^ 4) * PRIMES[k + 1]
            unsuited_lookup[product] = rank
            rank += 1
        end
    end

    # 2) Full House
    rank = MAX_FOUR_OF_A_KIND + 1

    for i in backwards_ranks
        pair_ranks::Array{UInt64,1} = copy(backwards_ranks)
        filter!(e->e!=i,pair_ranks)
        for k in pair_ranks
            product = (PRIMES[i + 1] ^ 3) * (PRIMES[k + 1] ^ 2)
            unsuited_lookup[product] = rank
            rank += 1
        end
    end

    # 3) Three of a Kind

    rank = MAX_STRAIGHT + 1

    # pick three of one rank
    for r in backwards_ranks
        kickers::Array{UInt64,1} = copy(backwards_ranks)
        filter!(e->e!=r,kickers)
        for kck in subsets(kickers, 2)
            c1, c2 = kck
            product = (PRIMES[r + 1] ^ 3) * (PRIMES[c1 + 1] * PRIMES[c2 + 1])
            unsuited_lookup[product] = rank
            rank += 1
        end
    end

    # 4) Two Pair

    rank = MAX_THREE_OF_A_KIND + 1
    for tp in subsets(backwards_ranks, 2)
        pair1, pair2 = tp
        kickers::Array{UInt64,1} = copy(backwards_ranks)
        filter!(e->e!=pair1,kickers)
        filter!(e->e!=pair2,kickers)
        for kicker in kickers
            product = PRIMES[pair1 + 1] ^ 2 * PRIMES[pair2 + 1] ^ 2 *
            PRIMES[kicker + 1]
            unsuited_lookup[product] = rank
            rank += 1
        end
    end

    # 5) Pair
    rank = MAX_TWO_PAIR + 1
    for pair_rank in backwards_ranks
        kickers::Array{UInt64,1} = copy(backwards_ranks)
        filter!(e->e!=pair_rank,kickers)

        for kickers in subsets(kickers, 3)
            k1, k2, k3 = kickers
            product = PRIMES[pair_rank + 1] ^ 2 * PRIMES[k1 + 1] *
            PRIMES[k2 + 1] * PRIMES[k3 + 1]
            unsuited_lookup[product] = rank
            rank += 1
        end
    end
    return unsuited_lookup
end

function highest_card_score(hand::Vector{UInt64})
    h1 = prime_product_from_hand(hand[1])
    h2 = prime_product_from_hand(hand[2])
    if h1 >= h2
        value = h1*10 + h2
    else
        value = h2*10 + h1
    end
    return MAX_HIGH_CARD + (1326 - value)
end

mutable struct LookupTables
    flush::Dict{UInt64,UInt64}
    unsuited::Dict{UInt64,UInt64}
end

function create_lookup_table()
    lkp = LookupTables(Dict(), Dict())

    straight_flushes::Array{UInt64,1} = [
        7936,  # royal flush
        3968,
        1984,
        992,
        496,
        248,
        124,
        62,
        31,
        4111 # 5 high
    ]

    flh::Array{UInt64,1} = []
    for f in BitSequence(0b11111, 1277 + length(straight_flushes)-1)
        notSF = true
        for sf in straight_flushes
            if xor(f,sf) == 0
                notSF = false
            end
        end
        if notSF == true
            append!(flh, f)
        end
    end

    flh = reverse(flh)
    rank = UInt64(1)
    for sf in straight_flushes
        prime_product = prime_product_from_rankbits(sf)
        lkp.flush[prime_product] = rank
        rank += 1
    end

    # we start the counting for flushes on max full house, which
    # is the worst rank that a full house can have (2,2,2,3,3)
    rank = MAX_FULL_HOUSE + 1
    for f in flh
        prime_product = prime_product_from_rankbits(f)
        lkp.flush[prime_product] = rank
        rank += 1
    end

    lkp.unsuited = straight_and_highcards(
        straight_flushes,
        flh,
        lkp.unsuited)
    lkp.unsuited = multiples(lkp.unsuited)

    # m = MAX_HIGH_CARD
    # highest_card_key(hand)
    # for hand in subsets(get_deck(), 2)
    #     if !haskey(highest_card_lookup, highest_card_score(hand))
    #         highest_card_lookup[key] = m
    #         m -= 1
    #     end
    # end

    return lkp
end
end
