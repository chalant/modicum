from itertools import combinations

import numpy as np
from numba import typed, njit, types

from games.evaluation import lookup
from games.evaluation import evaluator
from games import card


# To build the information tree from top to bottom, then from the bottom, perform the
# game shrink algorithm.

# 1) generate information tree

class UnionFind(object):
    def __init__(self, count, sizes):
        self._count = count
        self._sizes = sizes

    def find(self, hand, forest):
        path = [hand]
        while hand != forest[hand]:
            hand = forest[hand]
            path.append(hand)
        # link each encountered hand directly to the root
        for h in path:
            forest[h] = hand
        return hand

    def union(self, left, right, forest):

        l = self.find(left, forest)
        r = self.find(right, forest)
        sz = self._sizes
        # only connect when they are not already connected
        if l != r:
            # add node to tree
            if sz[l] < sz[r]:
                forest[l] = r
                sz[r] += sz[l]
            else:
                forest[r] = l
                sz[l] += sz[r]
            self._count -= 1
            # compression = 100 * self._count / self._max
            # if not compression % 10:
            #     print('Compressed to {}% of original size'.format(compression))
            # elif compression < 10:
            #     if not compression % 1:
            #         print('Compressed to {}% of original size'.format(compression))

    @property
    def count(self):
        return self._count

@njit
def find(hand, forest):
    path = typed.List.empty_list(types.uint32)
    path.append(hand)
    while hand != forest[hand]:
        hand = forest[hand]
        path.append(hand)
    # link each encountered hand directly to the root
    for h in path:
        forest[h] = hand
    return hand

@njit(nogil=True)
def find_without_compression(hand, forest):
    hd = hand
    while hd != forest[hd]:
        hd = forest[hd]
    return hd

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
    sizes = typed.List.empty_list(types.uint32, allocated=N)
    idx_arr = typed.List.empty_list(types.uint32, allocated=N)

    for i in range(N):
        sizes.append(1)
        idx_arr.append(i)

    combos = idx_arr.copy()

    # uf = UnionFind(N, sizes)
    count = N

    init_size = N
    total_comps = 0

    lgh = len(combos) - 1
    i = 0
    j = 1
    iterations = 0

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
            total_comps += 1
            iterations += 1

        i += 1
        j = i + 1
        # combos = unique(idx_arr, N)
        # lc = len(combos)
        # lgh = lc - 1
        # N = lc

        compression = 100 * count /init_size
        print(compression)

    return forest, count

def river_input(cards):
    # this function just passes the input to a numba function since combinations
    # isn't supported
    flh_lkp, uns_lkp = lookup.create_tables()
    river(np.array([c for c in combinations(cards, 5)], dtype='uint32'), flh_lkp, uns_lkp)


def turn(cards):
    pass


def flop(cards):
    pass


if __name__ == '__main__':
    river_input(card.get_deck())