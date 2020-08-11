import numba as nb

from utils import combinations
from games import card
from games.evaluation import lookup


@nb.njit(nogil=True)
def five(cards, flush_lookup, unsuited_lookup):
    """
    Performs an evaluation given cards in integer form, mapping them to
    a rank in the range [1, 7462], with lower ranks being more powerful.
    Variant of Cactus Kev's 5 card evaluator, though I saved a lot of memory
    space using a hash table and condensing some of the calculations.
    """
    # if flush
    if cards[0] & cards[1] & cards[2] & cards[3] & cards[4] & 0xF000:
        handOR = (cards[0] | cards[1] | cards[2] | cards[3] | cards[4]) >> 16
        prime = card.prime_product_from_rankbits(handOR)
        return flush_lookup[prime]

    # otherwise
    else:
        prime = card.prime_product_from_hand(cards)
        return unsuited_lookup[prime]


@nb.njit(nogil=True)
def six(cards, flush_lookup, unsuited_lookup):
    """
    Performs five_card_eval() on all (6 choose 5) = 6 subsets
    of 5 cards in the set of 6 to determine the best ranking,
    and returns this ranking.
    """
    minimum = lookup.MAX_HIGH_CARD

    for combo in combinations(cards, 5):

        score = five(combo, flush_lookup, unsuited_lookup)
        if score < minimum:
            minimum = score

    return minimum

@nb.njit(nogil=True)
def seven(cards, flush_lookup, unsuited_lookup):
    """
    Performs five_card_eval() on all (7 choose 5) = 21 subsets
    of 5 cards in the set of 7 to determine the best ranking,
    and returns this ranking.
    """
    minimum = lookup.MAX_HIGH_CARD

    # todo: this won't work in numba we need to generate combinations
    all5cardcombos = combinations(cards, 5)
    for combo in all5cardcombos:

        score = five(combo, flush_lookup, unsuited_lookup)
        if score < minimum:
            minimum = score

    return minimum


@nb.njit
def none(cards, flush_lookup, unsuited_lookup):
    return


# using a list takes less memory and index access is faster
_HAND_SIZE_MAP = [none] * 8
_HAND_SIZE_MAP[5] = five
_HAND_SIZE_MAP[6] = six
_HAND_SIZE_MAP[7] = seven


def evaluate(cards, board, hand_size_map):
    """
    This is the function that the user calls to get a hand rank.
    Supports empty board, etc very flexible. No input validation
    because that's cycles!
    """
    all_cards = cards + board
    return hand_size_map[len(all_cards)](all_cards)


def get_rank_class(hand_rank):
    """
    Returns the class of hand given the hand hand_rank
    returned from evaluate.
    """
    if hand_rank >= 0 and hand_rank <= lookup.MAX_STRAIGHT_FLUSH:
        return lookup.MAX_TO_RANK_CLASS[lookup.MAX_STRAIGHT_FLUSH]
    elif hand_rank <= lookup.MAX_FOUR_OF_A_KIND:
        return lookup.MAX_TO_RANK_CLASS[lookup.MAX_FOUR_OF_A_KIND]
    elif hand_rank <= lookup.MAX_FULL_HOUSE:
        return lookup.MAX_TO_RANK_CLASS[lookup.MAX_FULL_HOUSE]
    elif hand_rank <= lookup.MAX_FLUSH:
        return lookup.MAX_TO_RANK_CLASS[lookup.MAX_FLUSH]
    elif hand_rank <= lookup.MAX_STRAIGHT:
        return lookup.MAX_TO_RANK_CLASS[lookup.MAX_STRAIGHT]
    elif hand_rank <= lookup.MAX_THREE_OF_A_KIND:
        return lookup.MAX_TO_RANK_CLASS[lookup.MAX_THREE_OF_A_KIND]
    elif hand_rank <= lookup.MAX_TWO_PAIR:
        return lookup.MAX_TO_RANK_CLASS[lookup.MAX_TWO_PAIR]
    elif hand_rank <= lookup.MAX_PAIR:
        return lookup.MAX_TO_RANK_CLASS[lookup.MAX_PAIR]
    elif hand_rank <= lookup.MAX_HIGH_CARD:
        return lookup.MAX_TO_RANK_CLASS[lookup.MAX_HIGH_CARD]
    else:
        raise Exception("Invalid hand rank, cannot return rank class")


def class_to_string(class_int):
    """
    Converts the integer class hand score into a human-readable string.
    """
    return lookup.RANK_CLASS_TO_STRING[class_int]


def get_five_card_rank_percentage(hand_rank):
    """
    Scales the hand rank score to the [0.0, 1.0] range.
    """
    return float(hand_rank) / float(lookup.MAX_HIGH_CARD)


def hand_summary(board, hands):
    """
    Gives a sumamry of the hand with ranks as time proceeds.
    Requires that the board is in chronological order for the
    analysis to make sense.
    """

    assert len(board) == 5, "Invalid board length"
    for hand in hands:
        assert len(hand) == 2, "Invalid hand length"

    line_length = 10
    stages = ["FLOP", "TURN", "RIVER"]

    for i in range(len(stages)):
        line = "=" * line_length
        print("{} {} {}".format(line, stages[i], line))

        best_rank = 7463  # rank one worse than worst hand
        winners = []
        for player, hand in enumerate(hands):

            # evaluate current board position
            rank = evaluate(hand, board[:(i + 3)])
            rank_class = get_rank_class(rank)
            class_string = class_to_string(rank_class)
            percentage = 1.0 - get_five_card_rank_percentage(rank)  # higher better here
            print("Player {} hand = {}, percentage rank among all hands = {}".format(
                player + 1,
                class_string,
                percentage))

            # detect winner
            if rank == best_rank:
                winners.append(player)
                best_rank = rank
            elif rank < best_rank:
                winners = [player]
                best_rank = rank

        # if we're not on the river
        if i != stages.index("RIVER"):
            if len(winners) == 1:
                print("Player {} hand is currently winning.\n".format(winners[0] + 1))
            else:
                print("Players {} are tied for the lead.\n".format([x + 1 for x in winners]))

        # otherwise on all other streets
        else:
            hand_result = class_to_string(get_rank_class(evaluate(hands[winners[0]], board)))
            print("{} HAND OVER {}".format(line, line))
            if len(winners) == 1:
                print("Player {} is the winner with a {}\n".format(winners[0] + 1, hand_result))
            else:
                print("Players {} tied for the win with a {}\n".format([x + 1 for x in winners], hand_result))
