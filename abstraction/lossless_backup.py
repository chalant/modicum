
import math
from itertools import combinations

import numpy as np
from numba import typed, njit, types

from games.evaluation import lookup
from games.evaluation import evaluator
from games import card



# To build the information tree from top to bottom, then from the bottom, perform the
# game shrink algorithm.

@njit(nogil=True)
def find(hand, forest):
    hd = hand
    path = typed.List.empty_list(types.uint64)
    path.append(hd)
    while hd != forest[hd]:
        hd = forest[hd]
        path.append(hd)
    # link each encountered hand directly to the root
    for h in path:
        forest[h] = hd
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
def unique(array, count):
    dct = typed.Dict.empty(types.uint64, types.uint64)
    otp = typed.List.empty_list(types.uint64, allocated=count)
    # j = 0
    for i in array:
        v = find_without_compression(i, array)
        if not v in dct:
            otp.append(v)
            dct[v] = v
            # j += 1
    return otp

@njit(nogil=True)
def find_index(dct, start, limit):
    i = start
    while i < limit + 1:
        try:
            return dct[i], i
        except Exception:
            i += 1
    return -1, -1

@njit(nogil=True)
def river(forest, flush_lookup, unsuited_lookup):
    '''

    Parameters
    ----------
    forest: numpy.ndarray

    Returns
    -------

    '''
    # function for evaluating hands
    evl = evaluator.five

    N = len(forest)
    sizes = typed.List.empty_list(types.uint64, allocated=N)
    idx_arr = typed.List.empty_list(types.uint64, allocated=N)

    for i in range(N):
        sizes.append(1)
        idx_arr.append(i)

    combos = idx_arr.copy()

    # uf = UnionFind(N, sizes)
    count = N

    init_size = N
    sz = 1
    total_comps = 0
    full_comps = 0
    iterations = 0
    while sz < N:
        lo = 0

        print('Iterations', iterations)
        #copy combos
        dct = typed.Dict.empty(types.uint64, types.uint64)
        for i in range(len(combos)):
            dct[i] = combos[i]

        while lo < N - sz:
            mid = int(math.ceil(lo + sz - 1))
            hi = min(lo + (2 * sz) - 1, N - 1)
            j = mid + 1
            i = lo

            # print('Start', i, j)
            comps = (hi - mid) * (j - lo)
            full_comps += comps
            # total_comps += comps
            while True:
                #lookup get the corresponding hand
                l = combos[i]

                while j < hi:
                    try:
                        r = dct[i]
                        break
                    except Exception:
                        j += 1

                #all right elements have been exhausted
                i += 1
                if i > mid:
                    break
                # j = mid + 1
                total_comps += 1
                # print('Found', i, j, mid, hi)
                if evl(forest[l], flush_lookup, unsuited_lookup) \
                        == evl(forest[r], flush_lookup, unsuited_lookup):
                    count += union(l, r, idx_arr, sizes)
                    dct.pop(j)
                    i += 1
                    if i > mid:
                        break
                    j = mid + 1 #reset j
                else:
                    j += 1
                    if j > hi:
                        i += 1
                        if i > mid:
                            break
                        j = mid + 1
                        # we've reached the end of right array without any match
            lo += int(2 * sz)
        combos = unique(idx_arr, N)
        cz = len(combos)
        sz = math.ceil(2 * (2 * sz - ((N - cz) * (sz / cz)))) / 2
        print('Compressed to', 100 * count / init_size, "%\n",
              'Size', sz)
        print('Comps', total_comps, 'Brute Comps', full_comps, 'Difference', full_comps-total_comps)
        print('Current size', cz, count)
        total_comps = 0
        full_comps = 0
        N = cz
        iterations += 1
    return forest, count

def river_input(cards):
    # this function just passes the input to a numba function since combinations
    # isn't supported
    flh_lkp, uns_lkp = lookup.create_tables()
    river(np.array([c for c in combinations(cards, 5)], dtype='int64'), flh_lkp, uns_lkp)


def turn(cards):
    pass


def flop(cards):
    pass


if __name__ == '__main__':
    river_input(card.get_deck()[0:20])