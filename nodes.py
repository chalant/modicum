class Root(object):
    __slots__ = ['children']
    def __init__(self):
        self.children = {}

class Node(object):
    __slots__ = [
        'action',
        'children',
        'actions',
        'strategy',
        'regret_sum',
        'strategy_sum',
        'avg_strategy',
        'player',
        'active_players',
        'public_cards',
        'utility_vector',
        'utility',
        'p0',
        'p1',
        'terminal',
        'chip_size',
        'player_idx'
    ]

    def __init__(self, action=-1):
        self.action = action
        self.children = {}
        self.regret_sum = []
        self.strategy_sum = []
        self.utility_vector = []
        self.actions = ()
        self.strategy = []
        self.player_idx = 0
        #players that are actually playing (not eliminated)
        self.active_players = set()
        #exposed cards from the deck
        self.public_cards = ()
        self.utility = 0
        self.p0 = 1
        self.p1 = 1
        self.terminal = False
        self.chip_size = 0

class TerminalNode(object):
    __slots__ = [
        'public_cards',
        'terminal',
        'children',
        'active_players'
    ]

    def __init__(self):
        #utilities is a vector indexed by player
        self.public_cards = ()
        self.terminal = True
        self.children = {}
        self.active_players = set()