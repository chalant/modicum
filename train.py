from collections import deque

import nodes as nd

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


def train(players, iterations, game):
    '''

    Parameters
    ----------
    players: tuple
    iterations: int
    game: games.Game

    Returns
    -------

    '''

    def sample_actions(node, policy, actions):
        # policy is the strategy
        # todo: an action selected using policy
        # todo: use epsilon-greedy
        # must return an array
        return []

    def get_strategy(reach_p, node, strategy, actions):
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

    play = game.play
    compute_payoff = game.payoff
    start = game.start
    max_plays = game.max_plays
    arrange_players = game.arrange_players
    flop = game.flop
    distribute_cards = game.distribute_cards

    root = nd.Root()

    for t in range(iterations):
        #players must be arranged by playing order
        players_queue = deque(players)

        # note: each player plays a hand at each iteration
        #todo: should a player be eliminated if it has not enough chips?
        for player in players:
            #todo: shuffle cards
            deck = []
            public_cards = ()
            private_cards = distribute_cards(deck, players, player)
            nodes = [start(players_queue, root)]
            nodes_itr = [iter(root.children)]
            plays = 0
            rounds = 0

            # todo: initial action is determined by the game rules
            #play a hand
            while True:
                if len(nodes_itr) == 0:
                    # stop if there is no more iterators in the stack
                    break
                try:
                    nodes.append(next(nodes_itr[-1]))
                except StopIteration:
                    nodes_itr.pop()

                    if len(nodes) == 0:
                        # skip since there is no child node
                        continue

                    parent_node = nodes[-1]
                    curr_node = nodes.pop()
                    pl = parent_node.player

                    # decrement plays, since we're going back up the tree
                    plays -= 1
                    plays = plays if plays >=0 else 0

                    #decrement rounds if we reach the first player
                    if plays == 0 and pl == players_queue[0]:
                        rounds -= 1

                    if curr_node.terminal:
                        #we've reached a terminal node, this means that
                        #we've reached the end of a hand
                        c_utility = compute_payoff(
                            parent_node,
                            curr_node,
                            private_cards,
                            curr_node.active_players)
                    else:
                        c_utility = curr_node.utility

                    a = curr_node.action

                    parent_node.utility_vector[a] = c_utility

                    # reach probabilities are products of all actions probabilities prior to
                    # current state, including chance

                    # counter-factual utility is then weighted sum of utilities for sub-games
                    # (each rooted in single game state) from current information set with
                    # weights being normalized counter-factual probabilities of reaching these
                    # states.

                    strategy = parent_node.strategy[a]

                    # note: the terminal strategy is 1
                    parent_node.utility += strategy * c_utility

                    p0 = parent_node.p0
                    p1 = parent_node.p1

                    parent_node.strategy_sum[a] += strategy * p0 if pl == player else p1
                    parent_node.regret_sum[a] += (c_utility - parent_node.utility) * p1 if pl == player else p0

                    # set parent utility at index of history
                    continue

                curr_node = nodes[-1]
                opp = curr_node.player
                actions = curr_node.actions
                sub_nodes = curr_node.children

                plays += 1
                plays = plays if plays <= max_plays else 0
                if opp == players_queue[-1] and plays == max_plays:
                    rounds += 1

                public_cards = flop(deck, public_cards, rounds)

                if opp == player:
                    p0 = curr_node.p0
                    strategy = get_strategy(p0, curr_node, curr_node.strategy, actions)
                    # play each action
                    for a in actions:
                        play(
                            public_cards,
                            players_queue,
                            rounds,
                            plays,
                            curr_node,
                            sub_nodes,
                            a,
                            p0 * strategy[a],
                            curr_node.p1)

                    nodes_itr.append(iter(sub_nodes))
                    continue

                # only sample action if it is a different player (chance or opponent)
                if opp != player:
                    # sample action using previous policy (strategy)
                    strategy = curr_node.strategy
                    sample = sample_actions(curr_node, strategy, actions)
                    p1 = curr_node.p1
                    strategy = get_strategy(p1, curr_node, strategy, sample)
                    for a in sample:
                        play(
                            public_cards,
                            players_queue,
                            rounds,
                            plays,
                            curr_node.children,
                            a,
                            curr_node.p0,
                            p1 * strategy[a])

                    # add iterator to the iterator stack
                    nodes_itr.append(iter(sub_nodes))
                    continue

            players_queue = arrange_players(players_queue)
