import itertools

from numba import typed, types

from games import card

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

MAX_STRAIGHT_FLUSH = 10
MAX_FOUR_OF_A_KIND = 166
MAX_FULL_HOUSE = 322
MAX_FLUSH = 1599
MAX_STRAIGHT = 1609
MAX_THREE_OF_A_KIND = 2467
MAX_TWO_PAIR = 3325
MAX_PAIR = 6185
MAX_HIGH_CARD = 7462

MAX_TO_RANK_CLASS = {
    MAX_STRAIGHT_FLUSH: 1,
    MAX_FOUR_OF_A_KIND: 2,
    MAX_FULL_HOUSE: 3,
    MAX_FLUSH: 4,
    MAX_STRAIGHT: 5,
    MAX_THREE_OF_A_KIND: 6,
    MAX_TWO_PAIR: 7,
    MAX_PAIR: 8,
    MAX_HIGH_CARD: 9
}

RANK_CLASS_TO_STRING = {
    1: "Straight Flush",
    2: "Four of a Kind",
    3: "Full House",
    4: "Flush",
    5: "Straight",
    6: "Three of a Kind",
    7: "Two Pair",
    8: "Pair",
    9: "High Card"
}

# FLUSH_LOOKUP = typed.Dict.empty(types.int64, types.int32)
# UNSUITED_LOOKUP = typed.Dict.empty(types.int64, types.int32)

def straight_and_highcards(straights, highcards, unsuited_lookup):
    """
    Unique five card sets. Straights and highcards.
    Reuses bit sequences from flush calculations.
    """
    rank = MAX_FLUSH + 1

    for s in straights:
        prime_product = card.prime_product_from_rankbits(s)
        unsuited_lookup[prime_product] = rank
        rank += 1

    rank = MAX_PAIR + 1
    for h in highcards:
        prime_product = card.prime_product_from_rankbits(h)
        unsuited_lookup[prime_product] = rank
        rank += 1

def get_lexographically_next_bit_sequence(bits):
    """
    Bit hack from here:
    http://www-graphics.stanford.edu/~seander/bithacks.html#NextBitPermutation
    Generator even does this in poker order rank
    so no need to sort when done! Perfect.
    """
    t = int((bits | (bits - 1))) + 1
    next = t | ((int(((t & -t) / (bits & -bits))) >> 1) - 1)
    yield next
    while True:
        t = (next | (next - 1)) + 1
        next = t | ((((t & -t) // (next & -next)) >> 1) - 1)
        yield next

def create_tables():
    """
    Straight flushes and flushes.
    Lookup is done on 13 bit integer (2^13 > 7462):
    xxxbbbbb bbbbbbbb => integer hand index
    """

    flush_lookup = typed.Dict.empty(types.int64, types.int64)
    unsuited_lookup = typed.Dict.empty(types.int64, types.int64)
    # straight flushes in rank order
    straight_flushes = [
        7936,  # int('0b1111100000000', 2), # royal flush
        3968,  # int('0b111110000000', 2),
        1984,  # int('0b11111000000', 2),
        992,  # int('0b1111100000', 2),
        496,  # int('0b111110000', 2),
        248,  # int('0b11111000', 2),
        124,  # int('0b1111100', 2),
        62,  # int('0b111110', 2),
        31,  # int('0b11111', 2),
        4111  # int('0b1000000001111', 2) # 5 high
    ]

    # now we'll dynamically generate all the other
    # flushes (including straight flushes)
    flh = []
    gen = get_lexographically_next_bit_sequence(int('0b11111', 2))

    # 1277 = number of high cards
    # 1277 + len(str_flushes) is number of hands with all cards unique rank
    for i in range(1277 + len(straight_flushes) - 1):  # we also iterate over SFs
        # pull the next flush pattern from our generator
        f = next(gen)

        # if this flush matches perfectly any
        # straight flush, do not add it
        notSF = True
        for sf in straight_flushes:
            # if f XOR sf == 0, then bit pattern
            # is same, and we should not add
            if not f ^ sf:
                notSF = False

        if notSF:
            flh.append(f)

    # we started from the lowest straight pattern, now we want to start ranking from
    # the most powerful hands, so we reverse
    flh.reverse()

    # now add to the lookup map:
    # start with straight flushes and the rank of 1
    # since it is the best hand in poker
    # rank 1 = Royal Flush!
    rank = 1
    for sf in straight_flushes:
        prime_product = card.prime_product_from_rankbits(sf)
        flush_lookup[prime_product] = rank
        rank += 1

    # we start the counting for flushes on max full house, which
    # is the worst rank that a full house can have (2,2,2,3,3)
    rank = MAX_FULL_HOUSE + 1
    for f in flh:
        prime_product = card.prime_product_from_rankbits(f)
        unsuited_lookup[prime_product] = rank
        rank += 1

    # we can reuse these bit sequences for straights
    # and high cards since they are inherently related
    # and differ only by context
    straight_and_highcards(straight_flushes, flh, unsuited_lookup)
    multiples(unsuited_lookup)
    return flush_lookup, unsuited_lookup

def multiples(unsuited_lookup):
    """
    Pair, Two Pair, Three of a Kind, Full House, and 4 of a Kind.
    """
    backwards_ranks = list(range(len(card.INT_RANKS) - 1, -1, -1))

    # 1) Four of a Kind
    rank = MAX_STRAIGHT_FLUSH + 1

    # for each choice of a set of four rank
    for i in backwards_ranks:

        # and for each possible kicker rank
        kickers = backwards_ranks[:]
        kickers.remove(i)
        for k in kickers:
            product = card.PRIMES[i] ** 4 * card.PRIMES[k]
            unsuited_lookup[product] = rank
            rank += 1

    # 2) Full House
    rank = MAX_FOUR_OF_A_KIND + 1

    # for each three of a kind
    for i in backwards_ranks:

        # and for each choice of pair rank
        pairranks = backwards_ranks[:]
        pairranks.remove(i)
        for pr in pairranks:
            product = card.PRIMES[i] ** 3 * card.PRIMES[pr] ** 2
            unsuited_lookup[product] = rank
            rank += 1

    # 3) Three of a Kind
    rank = MAX_STRAIGHT + 1

    # pick three of one rank
    for r in backwards_ranks:

        kickers = backwards_ranks[:]
        kickers.remove(r)
        gen = itertools.combinations(kickers, 2)

        for kickers in gen:
            c1, c2 = kickers
            product = card.PRIMES[r] ** 3 * card.PRIMES[c1] * card.PRIMES[c2]
            unsuited_lookup[product] = rank
            rank += 1

    # 4) Two Pair
    rank = MAX_THREE_OF_A_KIND + 1

    tpgen = itertools.combinations(backwards_ranks, 2)
    for tp in tpgen:

        pair1, pair2 = tp
        kickers = backwards_ranks[:]
        kickers.remove(pair1)
        kickers.remove(pair2)
        for kicker in kickers:
            product = card.PRIMES[pair1] ** 2 * card.PRIMES[pair2] ** 2 * card.PRIMES[kicker]
            unsuited_lookup[product] = rank
            rank += 1

    # 5) Pair
    rank = MAX_TWO_PAIR + 1

    # choose a pair
    for pairrank in backwards_ranks:

        kickers = backwards_ranks[:]
        kickers.remove(pairrank)
        kgen = itertools.combinations(kickers, 3)

        for kickers in kgen:
            k1, k2, k3 = kickers
            product = card.PRIMES[pairrank] ** 2 * card.PRIMES[k1] \
                      * card.PRIMES[k2] * card.PRIMES[k3]
            unsuited_lookup[product] = rank
            rank += 1

def write_table_to_disk(table, filepath):
    """
    Writes lookup table to disk
    """
    with open(filepath, 'w') as f:
        for prime_prod, rank in table.iteritems():
            f.write(str(prime_prod) + "," + str(rank) + '\n')

#todo: if the dict is not found on disk, create it.

#initialize lookup dict
# flushes()
# multiples()