from enum import IntEnum

import numpy as np

from games import games
import nodes
from games.evaluation import evaluator


class Actions(IntEnum):
    FOLD = 0
    CHECK = 1
    CALL = 2
    SMALL_RAISE = 3
    BIG_RAISE = 4
    SMALL_BLIND = 5
    BIG_BLIND = 6
    SKIP = 7


class LimitTexasHold_em(games.Game):
    max_raises = 4

    # 0: pre-flop, 3: flop, 4: turn, 5: river
    # sizes of raises are doubled on the turn and the river

    round_bet_map = [1] * 6
    round_bet_map[3] = 1
    round_bet_map[4] = 2
    round_bet_map[5] = 2

    hand_size_map = evaluator._HAND_SIZE_MAP

    @staticmethod
    def action_mappings():
        def _fold(node, active_players, parent_idx, child_idx, player, raises, bet_multiplier):
            # remove player from active players and return proper index
            active_players.pop(parent_idx)
            node.active_players = active_players
            node.raises = raises
            # if the child_idx is after the parent_idx and the parent_idx
            # has folded, keep the parent_idx
            # the child_idx could be 0 if the parend_idx was the last.
            return parent_idx if parent_idx < child_idx else child_idx

        def _small_raise(node, active_players, parent_idx, child_idx, player, raises, bet_multiplier):
            node.active_players = active_players
            node.raises = raises + 1
            # bet size increases each round
            node.bet_sizes[player] += 1 * bet_multiplier
            return child_idx

        def _big_raise(node, active_players, parent_idx, child_idx, player, raises, bet_multiplier):
            node.active_players = active_players
            node.raises = raises + 1
            # bet size increases each round
            node.bet_sizes[player] += 2 * bet_multiplier
            return child_idx

        def _check(node, active_players, parent_idx, child_idx, player, raises, bet_multiplier):
            node.active_players = active_players
            node.raises = raises
            return child_idx

        def _small_blind(node, active_players, parent_idx, child_idx, player, raises, bet_multiplier):
            node.active_players = active_players
            node.raises = raises
            node.bet_sizes[player] += 1
            return child_idx

        def _big_blind(node, active_players, parent_idx, child_idx, player, raises, bet_multiplier):
            node.active_players = active_players
            node.raises = raises
            node.bet_sizes[player] += 2
            return child_idx

        _call = _check

        # BMR: Before Max Raises
        # AMR: At Max Raises
        _bmr_after_raise_actions = (
            Actions.FOLD,
            Actions.CALL,
            Actions.SMALL_RAISE,
            Actions.BIG_RAISE
        )

        _bmr_after_check_actions = (
            Actions.CHECK,
            Actions.SMALL_RAISE,
            Actions.BIG_RAISE
        )

        _bmr_action_mappings = [()] * 9
        _bmr_action_mappings[Actions.SMALL_BLIND] = ((Actions.BIG_BLIND,), _small_blind)
        _bmr_action_mappings[Actions.BIG_BLIND] = (_bmr_after_raise_actions, _big_blind)
        _bmr_action_mappings[Actions.FOLD] = (_bmr_after_raise_actions, _fold)
        _bmr_action_mappings[Actions.BIG_RAISE] = (_bmr_after_raise_actions, _big_raise)
        _bmr_action_mappings[Actions.SMALL_RAISE] = (_bmr_after_raise_actions, _small_raise)
        _bmr_action_mappings[Actions.CALL] = (_bmr_after_raise_actions, _call)
        _bmr_action_mappings[Actions.CHECK] = (_bmr_after_check_actions, _check)
        _bmr_action_mappings[Actions.SKIP] = (_bmr_after_raise_actions, _check)

        _amr_after_raise_actions = (
            Actions.FOLD,
            Actions.CALL
        )

        _amr_after_check_actions = (
            Actions.CHECK,
        )

        _amr_action_mappings = [()] * 5
        _amr_action_mappings[Actions.FOLD] = (_amr_after_raise_actions, _fold)
        _bmr_action_mappings[Actions.BIG_RAISE] = (_amr_after_raise_actions, _big_raise)
        _bmr_action_mappings[Actions.SMALL_RAISE] = (_amr_after_raise_actions, _small_raise)
        _bmr_action_mappings[Actions.CALL] = (_amr_after_raise_actions, _call)
        _bmr_action_mappings[Actions.CHECK] = (_amr_after_check_actions, _check)

        return (_bmr_action_mappings, _amr_action_mappings)

    @staticmethod
    def start(players, players_queue, root, mappings, chip_size, cards):
        # initial action
        a = Actions.SMALL_BLIND
        children = root.children
        player = players[0]

        # we use a dict so that we can check if a player is in the set fast
        # and the cost of index lookup isn't much more than arrays

        active = {i: p for i, p in enumerate(players)}
        num_pl = len(players)
        bet_sizes = [0] * num_pl
        public_cards = ()
        # each sub-node is mapped to public info (cards, active players,
        # action, player and raises)

        # todo: we should bucket with less elements to avoid having too many nodes
        #  here we already have wayyyy too many possible combinations of tuples
        #  we can use a function that, for a given private_cards and public_cards pair
        #  returns a unique key (a float, int or string)
        # key = str((public_cards, active, a, player, 0, bet_sizes))
        # todo use the private cards of the current player!
        key = str((public_cards + cards[player], a))
        sub_node = children.get(key, None)
        if not sub_node:
            root.children[key] = sub_node = nodes.Node(a)
            # subsequent action is a big_blind
            sub_node.actions = mappings[Actions.BIG_BLIND][0]
            sub_node.active_players = active
            sub_node.player_idx = 0
            sub_node.public_cards = public_cards
            sub_node.raises = 0
            # mapping of player and bet size
            sub_node.bet_sizes = bet_sizes
            sub_node.p0 = 1
            sub_node.p1 = 1
            sub_node.chip_sizes = [chip_size] * num_pl
        return sub_node

    @staticmethod
    def payoff(node, cards, community_cards, players, player, hand_size_map):
        chip_sizes = node.chip_sizes
        ranks = np.array([] * len(players), dtype='int64')
        i = 0
        # todo: don't call function within the loop
        for pl in players:
            ranks[i] = evaluator.evaluate(
                cards[pl],
                community_cards,
                hand_size_map)
            i += 1

        # highest ranked card
        winner = min(ranks)
        winners = np.where(ranks == winner)[0]
        losers = np.where(ranks != winner)[0]

        bet_sizes = node.bet_sizes

        res = sum(bet_sizes) / len(winners)

        # update all players chips
        for w in winners:
            chip_sizes[w] += res

        for l in losers:
            # losers lose the amount of there bets
            chip_sizes[l] -= bet_sizes[l]

        if ranks[player] == winner:
            if player not in players:
                # should the regret be bigger if the player folded with winning cards?
                return -bet_sizes[player]
            # the payoff is the pot size divided by the number of winners
            return res

        return -bet_sizes[player]

    @staticmethod
    def play(board_cards_cache,
             cards,
             players,
             current_node,
             children,
             actions,
             p0,
             p1,
             max_raises,
             action_mappings,
             round_bet_map):

        # get available actions from environment
        c_plr_idx = current_node.player_idx

        active = current_node.active_players
        c_player = active[c_plr_idx]
        # increment player
        plr_idx = c_plr_idx + 1

        num_players = len(active)
        if plr_idx >= num_players:
            # first player turn
            plr_idx = 0

        player = active[plr_idx]
        last_player = active[-1]

        # child nodes are stored by public info
        public_cards = current_node.public_cards
        raises = current_node.raises

        lp = len(public_cards)
        # add raises since its public info
        # key = str((public_cards, active, action, player, raises, bet_sizes))

        # todo: pre-flop stores private cards and action
        #  subsequent rounds (flop, turn, river) use a bucketing function

        sub_nodes = [] * len(actions)
        i = 0
        for action in actions:
            # explored nodes are stored by public cards, private cards and action
            key = str((public_cards, cards[player], action))
            sub_node = children.get(key, None)

            #todo: should we reset the node variables?

            # create sub_node if it does not exist
            if not sub_node:
                # todo: re-order if statements so that the most frequent
                #  occurrence is first.

                # todo: if the "traverser" is not in the hand, create a terminal node?
                #  or continue the game since there might be some useful information
                #  to learn from? => the payoff would be bad if the player folded but
                #  could have won.
                #  if the traverser has no more "chips" then it is terminal
                #  note: chip size is part of the public info as well.
                if c_player == last_player:
                    if action == Actions.CHECK or raises >= max_raises:
                        if lp == 5:
                            # if it happens after the river, then the game is over
                            children[key] = sub_node = nodes.TerminalNode()
                        else:
                            # move to flop, turn or river
                            children[key] = sub_node = nodes.Chance(action)
                    else:
                        children[key] = sub_node = nodes.Node(action)
                elif num_players == 1:
                    # happens if all previous players have folded
                    children[key] = sub_node = nodes.TerminalNode()
                else:
                    children[key] = sub_node = nodes.Node(action)

            type_ = sub_node.type
            # child references bet_sizes
            sub_node.bet_sizes = current_node.bet_sizes

            # player node is the node that occurs the most, so put it first
            if type_ == nodes.PLAYER:
                # set node actions
                actions, f = action_mappings[action]
                # update child_idx in case the parent node has folded
                sub_node.player_idx = f(
                    sub_node,
                    active,
                    c_plr_idx,
                    plr_idx,
                    player,
                    raises,
                    round_bet_map[lp])

                sub_node.actions = actions
                sub_node.public_cards = public_cards
                sub_node.p0 = p0
                sub_node.p1 = p1

            elif type_ == nodes.CHANCE:
                # chance node updates the public cards
                # resets the number of raises
                # and resets player_idx
                sub_node.actions = action_mappings[action][0]
                sub_node.active_players = active
                sub_node.public_cards = board_cards_cache[lp]
                sub_node.player_idx = 0
                sub_node.raises = 0
                sub_node.p0 = p0
                sub_node.p1 = p1


            elif type_ == nodes.TERMINAL:
                sub_node.active_players = active
                sub_node.raises = raises
                sub_node.public_cards = public_cards

            sub_nodes[i] = sub_node
            i += 1
        return sub_nodes

    @staticmethod
    def arrange_players(players):
        '''

        Parameters
        ----------
        players: collections.deque

        Returns
        -------
        collections.deque
        '''
        players.append(players.popleft())
        return players

    @staticmethod
    def community_cards(deck):
        flop = deck[1:4]
        turn = flop + deck[5:6]
        a = [()] * 5
        # indexed by number of public cards
        a[0] = flop
        a[3] = turn
        a[4] = turn + deck[7:8]
        return tuple(a)

    @staticmethod
    def distribute_cards(deck, players, player):
        # this function is called once per game
        # the order of distribution is always the same
        lp = len(players)
        private_cards = [[]] * lp
        j = 0
        # distribute one card per player twice
        for i in range(2):
            for p in range(lp):
                private_cards[p].append(deck[j])
                j += 1
        return tuple(private_cards)