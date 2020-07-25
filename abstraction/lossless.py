import math
from itertools import combinations

from tqdm import tqdm
#todo: implement game_shrink
# we will be using a utility function that assigns a probability value to
# a hand. The probability is conditional

from games.evaluation import evaluator
from games import card

# To build the information tree from top to bottom, then from the bottom, perform the
# game shrink algorithm.

#1) generate information tree

class UnionFind(object):
    def __init__(self, count, forest):
        self._count = count
        self._max = count
        self._sizes = {key:1 for key in forest.keys()}

    def find(self, hand, forest):
        path = [hand]
        while hand != forest[hand]:
            hand = forest[hand]
            path.append(hand)
        #link each encountered hand directly to the root
        for h in path:
            forest[h] = hand
        return hand

    def union(self, left, right, forest):

        l = self.find(left, forest)
        r = self.find(right, forest)
        sz = self._sizes
        #only connect when they are not already connected
        if l != r:
            # add node to tree
            if sz[l] < sz[r]:
                forest[l] = r
                sz[r] += sz[l]
            else:
                forest[r] = l
                sz[l] += sz[r]
            self._count -= 1
            print('Compressed to:', 100 * self._max/self._count)

    @property
    def count(self):
        return self._count

def count(iterable):
    i = 0
    for _ in iterable:
        i += 1
    return i

def brute_force(cards):
    combos = list(combinations(cards, 5))



    evl = evaluator.five
    lkp_tbl = evaluator._TABLE

    forest = {c: c for c in combinations(cards, 5)}
    uf = UnionFind(count(combinations(cards, 5)), forest)

    for lft in combos[0:len(combos)-1]:
        for rgt in combos[0:len(combos)-1]:
            if evl(lft, lkp_tbl) == evl(rgt, lkp_tbl):
                uf.union(lft, rgt, forest)
    return forest, uf.count



def river(cards):

    combos = list(combinations(cards, 5))


    #function for evaluating hands
    evl = evaluator.five
    lkp_tbl = evaluator._TABLE

    # map every combination of hands to itself
    # problem: the dict is huge!
    forest = {c:c for c in combinations(cards, 5)}
    uf = UnionFind(count(combinations(cards, 5)), forest)
    N = count(combinations(cards, 5))

    def shrink(combos, lo, mid, hi):
        j = mid+1

        for k in range(lo, j):
            for l in range(j, hi+1):
                lft = combos[k]
                rgt = combos[l]
                if evl(lft, lkp_tbl) == evl(rgt, lkp_tbl):
                    uf.union(lft, rgt, forest)

    sz = 1

    while sz <= N:
        lo = 0
        while lo < N - sz:
            shrink(combos, lo, lo+sz-1, min(lo+(2*sz)-1, N-1))
            lo += sz + sz
        sz += sz

    return forest, uf.count

def merge_sort(arr):
    N = len(arr)

    aux = [0] * N

    sz = 1

    def merge(arr, lo, mid, hi):
        i = lo
        j = mid + 1

        for k in range(lo, hi+1):
            aux[k] = arr[k]

        for k in range(lo, j):
            for l in range(j, hi + 1):
                lft = aux[k]
                rgt = aux[l]
                if lft == rgt:
                    arr[l] = lft

    while sz < N:
        lo = 0
        while lo < N - sz:
            print(arr[lo: min(lo+2*sz, N)])
            merge(arr, lo, lo + sz - 1, min(lo + (2 * sz) - 1, N - 1))
            lo += sz + sz
        sz += sz

    return arr

def turn(cards):
    pass

def flop(cards):
    pass

if __name__ == '__main__':
    river(card.get_deck())