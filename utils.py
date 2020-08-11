from numba import njit, typed, types, jit, cfunc
import numpy as np
from scipy import special

#
# binom = getattr(sc, signatures.name_to_numba_signatures['binom'])
# print(binom)

''' Equivalent to:
        def combinations_with_replacement(iterable, r):
            "combinations_with_replacement('ABC', 2) --> AA AB AC BB BC CC"
            # number items returned:  (n+r-1)! / r! / (n-1)!
            pool = tuple(iterable)
            n = len(pool)
            indices = [0] * r
            yield tuple(pool[i] for i in indices)
            while 1:
                for i in reversed(range(r)):
                    if indices[i] != n - 1:
                        break
                else:
                    return
                indices[i:] = [indices[i] + 1] * (r - i)
                yield tuple(pool[i] for i in indices)
'''

@jit('uint32(uint32)', nopython=True, nogil=True)
def factorial(n):
    prd = 1
    if n == 0:
        return 1

    while n > 0:
        prd *= n
        n = n - 1
    return prd

@jit('uint32(uint32, uint32)', nogil=True)
def binomial(n, k):
    if n > 12:
        raise Exception
    if k > n:
        return 0
    return factorial(n) / (factorial(k) * factorial(n - k))

@njit(nogil=True)
def combinations(cards, r):
    # combinations('ABCD', 2) --> AB AC AD BC BD CD
    # combinations(range(4), 3) --> 012 013 023 123
    n = len(cards)
    # print(len(cards))
    # print('J', factorial(n))
    # print('N', int(factorial(n) / (factorial(r) * factorial(n - r))))
    combos = np.empty(shape=(binomial(n, r), r), dtype=np.uint32)
    pool = np.empty(shape=(n,), dtype=np.uint32)
    # pool = []
    l = 0
    for c in cards:
        pool[l] = c
        l += 1

        # allocated=int(factorial(n)/(factorial(r)*factorial(n - r))))
    # lst = []
    r = 5
    if r > n:
        return combos

    indices = np.empty(shape=(r,))
    # indices = []
    for i in range(r):
        indices[i] = i

    for i in indices:
        i = int(i)
        combos[0][i] = pool[i]

    k = 1
    while True:
        i = r
        # for i in reversed(range(r)):
        while i > 0:
            i -= 1
            if indices[i] != i + n - r:
                break
        else:
            return combos

        indices[i] += 1
        for j in range(i+1, r):
            indices[j] = indices[j-1] + 1

        m = 0
        for i in indices:
            i = int(i)
            combos[k][m] = pool[i]
            m += 1
        k += 1