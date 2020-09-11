import math
from itertools import combinations
import time
from functools import partial

import numpy as np
from numba import typed, njit, types, jit
from scipy import special

from games.evaluation import lookup
from games.evaluation import evaluator
from games import card


# from utils import combinations

# import graph_tool as gt
# from graph_tool import topology

@njit(nogil=True)
def find(hand, forest):
    hd = hand
    # path = typed.List.empty_list(types.uint64)
    # path.append(hd)
    while hd != forest[hd]:
        hd = forest[hd]
        # path.append(hd)
    # link each encountered hand directly to the root
    # for h in path:
    #     forest[h] = hd
    return hd


@njit(nogil=True)
def find_without_compression(hand, forest):
    hd = hand
    while hd != forest[hd]:
        hd = forest[hd]
    return hd


@njit(nogil=True)
def union(u, v, forest, sizes):
    l = find(u, forest)
    r = find(v, forest)

    # only connect when they are not already connected
    if l != r:
        # add node to tree
        if sizes[l] < sizes[r]:
            forest[l] = r
            sizes[r] += sizes[l]
        else:
            forest[r] = l
            sizes[l] += sizes[r]
        return -1
    return 0


@njit(nogil=True)
def uni(array):
    dct = typed.Dict.empty(types.uint32, types.uint32)
    for i in array:
        if i not in dct:
            dct[i] = i
    return dct


def map_to_strength(cards):
    flh_lkp, uns_lkp = lookup.create_tables()
    array = np.array([evaluator.five(c, flh_lkp, uns_lkp) for c in combinations(cards, 5)], dtype='uint32')
    press = len(uni(array))
    print('Compression', 100 * press / special.binom(len(cards), 5))
    print(array)


@njit(nogil=True)
def unique(array, count):
    dct = typed.Dict.empty(types.uint32, types.uint32)
    otp = typed.List.empty_list(types.uint32, allocated=count)
    # j = 0
    for i in array:
        v = find_without_compression(i, array)
        if not v in dct:
            otp.append(v)
            dct[v] = v
            # j += 1
    return otp


@njit(nogil=True)
def compress_river(forest, flush_lookup, unsuited_lookup):
    '''
    Parameters
    ----------
    forest: numpy.ndarray
    Returns
    -------
    numba.typed.List
    '''

    # function for evaluating hands
    evl = evaluator.five

    N = len(forest)
    sizes = typed.List.empty_list(types.uint32, allocated=N)
    idx_arr = typed.List.empty_list(types.uint32, allocated=N)

    for i in range(N):
        sizes.append(1)
        idx_arr.append(i)

    combos = idx_arr.copy()

    # uf = UnionFind(N, sizes)
    count = N

    init_size = N

    # initial fast partial compression

    sz = 1

    while sz < N:
        lo = 0
        while lo < N - sz:
            mid = int(math.ceil(lo + sz - 1))
            hi = min(lo + (2 * sz) - 1, N - 1)
            j = mid + 1
            i = lo
            comps = (hi - mid) * (j - lo)

            # todo: we can further reduce comparisons
            for _ in range(comps):
                # lookup get the corresponding hand
                l = combos[i]
                r = combos[j]
                if evl(forest[l], flush_lookup, unsuited_lookup) \
                        == evl(forest[r], flush_lookup, unsuited_lookup):
                    count += union(l, r, idx_arr, sizes)
                j += 1
                if j > hi:
                    # reset j
                    j = mid + 1
                    i += 1

            lo += int(2 * sz)

        # combination list
        combos = unique(idx_arr, N)
        cz = len(combos)
        print("Size")
        sz = math.ceil(2 * (2 * sz - ((N - cz) * (sz / cz)))) / 2
        print("Size", sz, N, cz, N - cz)
        print('Compressed to ', 100 * count / init_size, '% of original size')

        N = cz

    # further compression (brute force)
    # todo: we could optimise this through divide and conquer
    lgh = len(combos) - 1
    i = 0
    j = 1

    while i < lgh:
        l = combos[i]
        while j < lgh:
            r = combos[j]
            if evl(forest[l],
                   flush_lookup,
                   unsuited_lookup) == \
                    evl(forest[r],
                        flush_lookup,
                        unsuited_lookup):
                count += union(l, r, idx_arr, sizes)
            j += 1

        i += 1
        j = i + 1

    print('Compressed to ', 100 * count / init_size, '% of original size')

    return idx_arr


def create_river_mapping(cards):
    # this function just passes the input to a numba function since combinations
    # isn't supported
    flh_lkp, uns_lkp = lookup.create_tables()
    array = combinations(cards, 5)
    idx = compress_river(array, flh_lkp, uns_lkp)
    return array, idx


@njit(nogil=True, cache=True)
def river_compression(forest, flush_lkp, unsuited_lkp):
    evl = evaluator.five
    utilities = np.array([evl(c, flush_lkp, unsuited_lkp) for c in forest], dtype=np.uint32)

    # the index maps a hand to an equivalent hand.
    N = len(forest)
    count = N
    idx_array = np.array([i for i in range(N)], dtype=np.uint32)
    sizes = np.array([1 for _ in range(N)], dtype=np.uint32)

    i = 0
    j = 1

    while j < N:
        if utilities[i] == utilities[j]:
            count += union(i, j, idx_array, sizes)
        i += 1
        j += 1

    print('Compression', 100 * count / N)
    print('Count', count)

@jit(nogil=True, cache=True, nopython=True)
def strength_array(hand, cards, flush_lkp, unsuited_lkp):
    lst = typed.List.empty_list(types.uint32)
    for c in cards - set(hand):
        lst.append(c)

    N = len(lst)
    valid_cards = np.array([[lst[c]] for c in range(N)], np.uint32)
    hands = np.array([np.concatenate((hand, valid_cards[i])) for i in range(N)], np.uint32)
    return np.sort(np.array(
        [evaluator.six(hands[i], flush_lkp, unsuited_lkp)
         for i in range(N)], np.uint32)), N

@jit(nogil=True, cache=True, nopython=True)
def turn_compression(forest, flush_lkp, unsuited_lkp):
    cards = set(card.get_deck())
    evl7 = evaluator.seven
    for hand in forest:
        arr, N = strength_array(hand, cards, flush_lkp, unsuited_lkp)
        i = 0
        j = 1

        while j < N:
            u = arr[i]
            v = arr[j]
            if u == v:
                broke = False
                x = np.array([u], np.uint32)
                y = np.array([v], np.uint32)
                for c in set(np.concatenate((
                        hands[i],
                        hands[j]))):
                    c = np.array([c], np.uint32)
                    h1 = evl7(
                        np.concatenate((x, c)),
                        flush_lkp,
                        unsuited_lkp)
                    h2 = evl7(
                        np.concatenate((y, c)),
                        flush_lkp,
                        unsuited_lkp)
                    if h1 != h2:
                        broke = True
                        break
                if not broke:
                    pass
            i += 1
            j += 1


def time_it(f, *args):
    t0 = time.time()
    f(*args)
    print('Took ', time.time() - t0)


def compress_flop(cards):
    pass


@njit
def test():
    lst = [1, 2, 3, 4, 5, 6]
    arr = np.array([lst[i] for i in range(len(lst))])
    arr1 = np.array([lst[i] for i in range(len(lst))])
    return np.concatenate((arr, arr1))


if __name__ == '__main__':
    # create_turn_mapping(card.get_deck()[0:21])
    a, b = lookup.create_tables()
    # np.array([c for c in combinations(card.get_deck(), 6)], 'uint32')
    # # hands are sorted by strength
    hands = np.array(sorted(
        combinations(card.get_deck(), 5),
        key=partial(evaluator.five, flush_lookup=a, unsuited_lookup=b)),
        'uint32')
    time_it(compress_river, hands, a, b)
    # # time_it(turn_compression, hands, a, b)
    # turn_compression(hands, a, b)
    # time_it(turn_compression, hands, a, b)
    # print(len(sorted([k for k in b.keys()])), len(sorted([k for k in a.keys()])))
