from enum import IntEnum

import nodes

CHANCE = 0
TERMINAL = 1


class KuhnPoker(object):
    @staticmethod
    def play(round, deck, current_node,
             children, action, cards,
             players, player, p0, p1):
        pass


# todo: there is also the amount to "raise" by
class Actions(IntEnum):
    FOLD = 1
    CHECK = 2
    CALL = 3
    SMALL_RAISE = 4
    BIG_RAISE = 5
    SMALL_BLIND = 6
    BIG_BLIND = 7
    SKIP = 8


class Game(object):
    # todo: bet sizes ?
    # if the player raises, must determine by what amount. In limit texas there is some
    # pre-defined max bet size that can increase as the game goes on...
    # there are two "stages" for betting first round are the small bets and last two rounds
    # are the big bets => actions depends on rounds.
    # todo: we can "abstract" the concept of raise betsize (equal,small,big) per round.
    # The payoff for each betsize is proportional to the "size" and must always be the same
    # regardless of the amount.
    @property
    def max_plays(self):
        return 3

    @property
    def max_rounds(self):
        return 3

    @staticmethod
    def start(players, root):
        return

    @staticmethod
    def payoff(parent_node, child_node, cards, players):
        # todo: must evaluate the players cards
        # todo: we must evaluate each players cards and evantually split rewards if two players
        # have the same cards. For simplicity, we might consider this a "win" and we return the
        # same payoff as a win in case of a "draw".
        return

    @staticmethod
    def play(public_cards, players, rounds, plays, current_node, children, action, p0, p1):
        '''

        Parameters
        ----------
        deck: typing.Tuple[str]
        current_node: nodes.Node
        children: typing.Dict[str, nodes.Node]
        action: int
        cards: typing.List[int]
        players: typing.Deque[int]
        player: int
        p0: float
        p1: float

        Returns
        -------
        None
        '''
        pass

    @staticmethod
    def arrange_players(players):
        '''

        Parameters
        ----------
        players: typing.Deque[int]

        Returns
        -------
        typing.Deque[int]
        '''
        return

    @staticmethod
    def flop(deck, public_cards, rounds):
        return

    @staticmethod
    def distribute_cards(deck, players, player):
        # todo: distribute cards from deck, then return the current players private cards
        return


class LimitTexasHold_em(object):
    # todo: bet sizes ?
    # if the player raises, must determine by what amount. In limit texas there is some
    # pre-defined max bet size that can increase as the game goes on...
    # there are two "stages" for betting first round are the small bets and last two rounds
    # are the big bets => actions depends on rounds.
    # todo: we can "abstract" the concept of raise betsize (equal,small,big) per round.
    # The payoff for each betsize is proportional to the "size" and must always be the same
    # regardless of the amount.
    ACTIONS = [
        Actions.FOLD,
        Actions.CHECK,
        Actions.SMALL_RAISE,
        Actions.BIG_RAISE,
        Actions.SMALL_BLIND,
        Actions.BIG_BLIND,
        Actions.SKIP
    ]

    @property
    def max_plays(self):
        return 3

    @property
    def max_rounds(self):
        return 3

    @staticmethod
    def start(players, root):
        '''

        Parameters
        ----------
        players
        root: nodes.Root

        Returns
        -------

        '''
        a = Actions.SMALL_BLIND
        children = root.children
        player = players[0]
        active = set(players)
        key = str(((), active, a, player))
        sub_node = children.get(key, None)
        if not sub_node:
            root.children[key] = sub_node = nodes.Node(a)
            #subsequent action is a big_blind
            sub_node.actions = (Actions.BIG_BLIND,)
            sub_node.active_players = active
            sub_node.player_idx = 0
        return sub_node

    @staticmethod
    def payoff(parent_node, child_node, cards, players, player):
        # todo: must evaluate the players cards
        # todo: we must evaluate each players cards and evantually split rewards if two players
        # have the same cards. For simplicity, we might consider this a "win" and we return the
        # same payoff as a win in case of a "draw".
        return

    @staticmethod
    def play(public_cards, players, rounds, plays, current_node, children, action, p0, p1):
        '''

        Parameters
        ----------
        deck: typing.Tuple[str]
        current_node: nodes.Node
        children: typing.Dict[str, nodes.Node]
        action: int
        cards: typing.List[int]
        players: typing.Queue[int]
        player: int
        p0: float
        p1: float

        Returns
        -------

        '''

        # get available actions from environment
        c_plr_idx = current_node.player_idx
        # increment player
        plr_idx = c_plr_idx + 1
        active = current_node.active_players

        if plr_idx == len(players):
            # first player turn
            plr_idx = 0

        player = players[plr_idx]

        # child nodes are stored by public info
        key = str((public_cards, active, action, player))
        sub_node = children.get(key, None)

        if not sub_node:
            if rounds == 4:
                # end of hand => terminal node
                # map cards and actions to Node
                children[key] = sub_node = nodes.TerminalNode()
                sub_node.terminal = True
            else:
                children[key] = sub_node = nodes.Node(action)

        sub_node.player_idx = plr_idx

        if action == Actions.FOLD:
            #create a new set by removing the parent node's player
            sub_node.active_players = current_node.active_players - players[c_plr_idx]
        else:
            sub_node.active_players = current_node.active_players

        if player not in active:
            #if the next player has folded, (not active) he can only skip his turn
            sub_node.actions = (Actions.SKIP,)
        else:
            if plays > 3:
                sub_node.actions = (Actions.SKIP,)

            elif action == Actions.BIG_BLIND:
                sub_node.actions = (
                    Actions.FOLD,
                    Actions.CALL,
                    Actions.BIG_RAISE,
                    Actions.SMALL_RAISE)
            #todo: can only raise twice?
            elif action == Actions.SMALL_RAISE:
                sub_node.actions = (
                    Actions.FOLD,
                    Actions.CALL,
                    Actions.BIG_RAISE,
                    Actions.SMALL_RAISE)

            elif action == Actions.BIG_RAISE:
                sub_node.actions = (
                    Actions.FOLD,
                    Actions.CALL,
                )


        if sub_node.terminal != True:
            sub_node.p0 = p0
            sub_node.p1 = p1

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
    def flop(deck, public_cards, rounds):
        if rounds == 1:
            # we don't consider the first card of the deck since it is
            # burned
            return deck[1:4]
            # create actions based on current history (round, plays)
        elif rounds == 2:
            # burn and draw one card from the deck
            return public_cards + deck[5:6]
        elif rounds == 3:
            # final round
            return public_cards + deck[7:8]
        else:
            return public_cards

    @staticmethod
    def distribute_cards(deck, players, player):
        # todo: distribute cards from deck, then return the current players private cards
        return ()
