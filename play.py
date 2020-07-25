import random
from collections import deque

from games import card
import nodes as nd

def simulate(game, root, deck, players, iterations, action_sampler):
    #plays a game starting from the "root" which represents a certain
    #state

    # def shuffle(deck):
    #     random.shuffle(deck)

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

    #functions
    play = game.simulate
    compute_payoff = game.payoff
    start = game.start
    arrange_players = game.arrange_players
    community_cards = game.community_cards
    distribute_cards = game.distribute_cards

    #properties
    max_raises = game.max_raises
    action_mappings = game.action_mappings()
    round_bet_map = game.round_bet_map
    hand_size_map = game.hand_size_map

    for t in range(iterations):
        # players must be arranged by playing order
        players_queue = deque(players)

        # note: each player plays a hand at each iteration
        # todo: should a player be eliminated if it has not enough chips?
        for player in players:
            #todo: we don't need a deck if the root is not a new game
            deck = card.get_deck()
            random.shuffle(deck)
            #the order of distribution is always the same
            private_cards = distribute_cards(deck, players, player)
            nodes = [start(players, players_queue, root, action_mappings)]
            nodes_itr = [iter(root.children)]
            cards_cache = community_cards(deck)

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

                    curr_node = nodes.pop()

                    # compute payoff if we've reached the end of a hand
                    # else use the current node utility
                    c_utility = compute_payoff(
                            curr_node,
                            private_cards,
                            curr_node.community_cards,
                            curr_node.active_players,
                            player,
                            hand_size_map
                        ) \
                        if curr_node.type == nd.TERMINAL else curr_node.utility

                    parent_node = nodes[-1]
                    pl = parent_node.active_players[parent_node.player_idx]

                    a = curr_node.action

                    parent_node.utility_vector[a] = c_utility

                    # reach probabilities are products of all actions probabilities prior to
                    # current state, including chance

                    # counter-factual utility is the weighted sum of utilities for sub-games
                    # (each rooted in single game state) from current information set with
                    # weights being normalized counter-factual probabilities of reaching these
                    # states.

                    strategy = parent_node.strategy[a]

                    is_player = pl == player

                    p_util = parent_node.utility
                    #update utility if it is the current player, else, it is 0
                    p_util += strategy * c_utility * int(is_player)

                    p0 = parent_node.p0
                    p1 = parent_node.p1

                    parent_node.strategy_sum[a] += strategy * p0 if is_player else p1
                    parent_node.regret_sum[a] += (c_utility - p_util) * p1 if is_player else p0
                    parent_node.utility = p_util
                    # set parent utility at index of history
                    continue

                curr_node = nodes[-1]

                opp = curr_node.active_players[curr_node.player_idx]
                actions = curr_node.actions
                sub_nodes = curr_node.children

                action_map = action_mappings[curr_node.raises < curr_node.max_raises]

                if opp == player:
                    p0 = curr_node.p0
                    strategy = get_strategy(p0, curr_node, curr_node.strategy, actions)
                    nodes_itr.append(
                        iter(play(
                            cards_cache,
                            players_queue,
                            curr_node,
                            sub_nodes,
                            actions,
                            p0 * strategy[a],
                            curr_node.p1,
                            max_raises,
                            action_map,
                            round_bet_map)))
                    continue

                # only sample action if it is a different player (chance or opponent)
                elif opp != player:
                    # sample action using previous policy (strategy)
                    strategy = curr_node.strategy
                    sample = action_sampler(curr_node, strategy, actions)
                    p1 = curr_node.p1
                    strategy = get_strategy(p1, curr_node, strategy, sample)

                    # add iterator to the iterator stack
                    nodes_itr.append(iter(play(
                        cards_cache,
                        players_queue,
                        curr_node.children,
                        sample,
                        curr_node.p0,
                        p1 * strategy[a],
                        max_raises,
                        action_map,
                        round_bet_map)))
                    continue

            players_queue = arrange_players(players_queue)
            # todo: check players chip_size if it is 0, remove the player from the players ?
            #  note: if it is a cash game, players can come and go, so the number of players
            #  may vary and players can re-cave up to a maximum number of times (can be infinite).
            #  in a tournament, players can't re-cave, so they are eliminated if they have not enough
            #  chips (not enough for the small blind or the big blind)
            #  depending on the type of "game"
    return root