CHANCE = 0
TERMINAL = 1


class Iterator(object):
    def __init__(self, info_set):
        self._stack = stack = []
        stack.append(info_set)

    def __iter__(self):
        return self

    def __next__(self):
        stack = self._stack
        if len(stack) == 0:
            raise StopIteration
        curr = stack[-1]
        if curr.children:
            pass


class Node(object):
    __slots__ = [
        'history',
        'children',
        'actions',
        'strategy',
        'regret_sum',
        'strategy_sum',
        'avg_strategy',
        'player',
        'cards',
        'utility_vector',
        'utility',
        'p0',
        'p1'
    ]

    def __init__(self, player, history=-1):
        self.history = history
        self.children = {}
        self.regret_sum = []
        self.strategy_sum = []
        self.utility_vector = []
        self.actions = []
        self.strategy = []
        self.player = player
        self.cards = []
        self.utility = 0
        self.p0 = 1
        self.p1 = 1


def get_strategy(realization_weight, node):
    '''

    Parameters
    ----------
    realization_weight: float
    node: Node

    Returns
    -------

    '''
    actions = node.actions
    strategy = node.strategy
    str_sum = node.strategy_sum
    normalizing_sum = 0
    for a in actions:
        r_sum = node.regret_sum[a]
        node.strategy[a] = r_sum if r_sum > 0 else 0
        normalizing_sum += strategy[a]

    for a in actions:
        if (normalizing_sum > 0):
            strategy[a] /= normalizing_sum
        else:
            strategy[a] = 1.0 / len(a)
        str_sum[a] += realization_weight * strategy[a]
    return strategy


def train(players, iterations):
    '''

    Parameters
    ----------
    players: frozenset
    iterations

    Returns
    -------

    '''
    # todo: set initial player
    root = Node(0) #0 is chance
    # todo: set initial actions
    root.actions = []
    util = 0
    stack = []
    stack.append(root)

    # reach probabilities

    def select_action(policy, actions):
        # policy is the strategy
        # todo: an action selected using policy
        return 1

    def get_strategy(reach_p, node, actions):
        strategy = node.strategy
        regret_sum = node.regret_sum
        normalizer = 0
        for a in actions:
            strategy[a] = stg = regret_sum[a] if regret_sum[a] > 0 else 0
            normalizer += stg

        num_act = len(actions)
        for a in actions:
            if normalizer > 0:
                strategy[a] /= normalizer
            else:
                strategy[a] = 1.0 / num_act
            node.strategy_sum[a] = reach_p * strategy[a]
        return strategy

    def play(nodes, action, cards, player, p0, p1, game):
        p_cards = cards[player]
        key = str((p_cards, action))
        sub_node = nodes.get(key, None)
        # get available actions from environment
        node = game.play(action, cards, player)
        if not node:
            # map cards and actions to Node
            sub_node[key] = node = Node(player, action)
            sub_node.actions = actions
            if node != TERMINAL:
                node.p0 = p0
                node.p1 = p1

    game = None  # todo: set-up a game
    # todo: at each node, players alternate depending on the game rules, so once a player
    # performs an action, it is another players turn an so on...
    for t in iterations:
        cards = []  # todo shuffle cards and distribute to each player
        for player in players:
            nodes = [root]
            nodes_itr = [iter(root.children)]

            # todo: initial action is determined by the game rules

            while True:
                if len(nodes_itr) == 0:
                    # stop if there is no more iterators in the stack
                    break
                try:
                    nodes.append(next(nodes_itr[-1]))
                except StopIteration:
                    nodes_itr.pop()

                    if len(nodes) == 1:
                        # skip since there is no child node
                        continue

                    curr_node = nodes.pop()

                    # todo: add create and update strategy functions
                    p_node = nodes[-1]
                    h = curr_node.history

                    p_node.utility_vector[h] = curr_node.utility

                    # reach probabilities are products of all actions probabilities prior to
                    # current state, including chance

                    # counter-factual utility is then weighted sum of utilities for subgames
                    # (each rooted in single game state) from current information set with
                    # weights being normalized counter-factual probabilities of reaching these
                    # states.
                    strategy = p_node.strategy[h]
                    pl = p_node.player

                    # note: the terminal strategy is 1
                    c_utility = curr_node.utility
                    p_node.utility += strategy * c_utility

                    p0 = p_node.p0
                    p1 = p_node.p1

                    p_node.strategy_sum[h] += strategy * p0 if pl == player else p1
                    p_node.regret_sum[h] += (c_utility - p_node.utility) * p1 if pl == player else p0

                    # set parent utility at index of history
                    continue

                curr_node = nodes[-1]
                opp = curr_node.player
                actions = curr_node.actions
                sub_nodes = curr_node.children

                if opp == player:
                    p0 = curr_node.p0
                    strategy = get_strategy(p0, curr_node, actions)
                    # play each action
                    for a in actions:
                        play(
                            sub_nodes,
                            a,
                            cards,
                            player,
                            p0 * strategy[a],
                            curr_node.p1,
                            game)

                    nodes_itr.append(iter(sub_nodes))
                    continue

                # note this depends on the method (external sampling, outcome sampling, pure...)

                # only sample action if it is a different player (chance of opponent)
                if opp != player:
                    # select action based on policy
                    a = select_action(curr_node.strategy, actions)
                    p1 = curr_node.p1
                    strategy = get_strategy(p1, curr_node, [a])
                    play(
                        curr_node.children,
                        a,
                        cards,
                        opp,
                        curr_node.p0,
                        p1 * strategy[a],
                        game)
                    # add iterator to the iterator stack
                    nodes_itr.append(iter(sub_nodes))
                    continue
