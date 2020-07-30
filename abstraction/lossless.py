import math
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
    path = typed.List.empty_list(types.int32)
    path.append(hand)
    while hand != forest[hand]:
        hand = forest[hand]
        path.append(hand)
    # link each encountered hand directly to the root
    for h in path:
        forest[h] = hand
    return hand

@njit
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
    sizes = np.array([1 for _ in range(N)])
    idx_arr = np.array([i for i in range(N)])
    combos = idx_arr.copy()

    # uf = UnionFind(N, sizes)
    count = N

    init_size = N
    sz = 1
    total_comps = 0
    while sz < N:
        lo = 0
        while lo < N - sz:
            mid = int(math.ceil(lo + sz - 1))
            hi = min(lo + (2 * sz) - 1, N - 1)
            j = mid + 1
            i = lo
            comps = (hi - mid) * (j - lo)
            total_comps += comps
            #todo: comparisons takes the most computation, so parallelize it.
            for _ in range(comps):
                #lookup get the corresponding hand
                l = combos[i]
                r = combos[j]
                if evl(forest[l], flush_lookup, unsuited_lookup) \
                        == evl(forest[r], flush_lookup, unsuited_lookup):
                    count += union(l, r, idx_arr, sizes)
                    # uf.union(lft, rgt, forest)
                j += 1
                if j > hi:
                    # reset j
                    j = mid + 1
                    i += 1
                # j += 1
                # if j > hi:
                #     i += 1
                #     j = mid + 1
            # for i in range(lo, mid + 1):
            #     for j in range(mid + 1, hi + 1):
            #         lft = combos[i]
            #         rgt = combos[j]
            #         if evl(lft, lkp_tbl) == evl(rgt, lkp_tbl):
            #             uf.union(lft, rgt, forest)
            lo += int(2 * sz)
        # print(l1, mid, hi)
        # set the list to compressed version
        combos = np.unique(idx_arr)
        cz = len(combos)
        sz = int(math.ceil(2 * (2 * sz - ((N - cz) * (sz / cz)))) / 2)
        # sz = sz * 2
        # print('Compressed to {}% of original size\n'
        #       'Current size: {}, Initial size: {}\n'
        #       'Comparisons {}\n'
        #       'Comparison space {}\n'.format(
        #     100 * count / init_size,
        #     count,
        #     init_size,
        #     total_comps,
        #     sz))
        print(100 * count / init_size, "%\n")
        total_comps = 0
        N = cz
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
    river_input(card.get_deck())
