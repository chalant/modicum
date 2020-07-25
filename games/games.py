import nodes


class Game(object):
    max_raises = 4

    @staticmethod
    def start(players, players_queue, root, mappings, chip_size, cards):
        '''

        Parameters
        ----------
        players: typing.Tuple[int]
        players_queue: typing.Queue
        root: nodes.Root
        mappings: typing.List[typing.Dict]]
        cards: typing.Tuple[typing.Tuple[int]]

        Returns
        -------
        nodes.Node
        '''
        return

    @staticmethod
    def action_mappings():
        '''

        Returns
        -------
        typing.Tuple[Dict]
        '''
        return

    @staticmethod
    def payoff(node, cards, community_cards, players, player, hand_size_map):
        # todo: must evaluate the players cards
        # todo: we must evaluate each players cards and eventually split rewards if two players
        # have the same cards. For simplicity, we might consider this a "win" and we return the
        # same payoff as a win in case of a "draw".
        return

    @staticmethod
    def play(board_cards_cache,
             cards,
             players,
             current_node,
             children,
             action,
             p0,
             p1,
             max_raises,
             action_mappings,
             round_bet_map):
        '''

        Parameters
        ----------
        board_cards_cache: typing.Tuple[typing.Tuple[int]]
        cards: typing.Tuple[typing.Tuple[int]]
        players: typing.Deque[int]
        current_node: nodes.Node
        children: typing.Dict[str, nodes.Node]
        action: int
        p0: float
        p1: float
        action_mappings: dict
        round_bet_map: typing.Dict[int, int]

        Returns
        -------
        typing.Dict[str, nodes.Node]
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
    def community_cards(deck):
        return

    @staticmethod
    def distribute_cards(deck, players, player):
        # todo: distribute cards from deck, then return the current players private cards
        return
