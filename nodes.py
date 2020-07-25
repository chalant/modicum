ROOT = 0
CHANCE = 1
TERMINAL = 2
PLAYER = 3


class Root(object):
    __slots__ = [
        'children',
        'type',
        'strategy'
    ]

    def __init__(self):
        self.children = {}
        self.type = ROOT

class Chance(object):
    __slots__ = [
        'action',
        'public_cards',
        'active_players',
        'type'
    ]

    def __init__(self, action):
        self.action = action
        self.public_cards = ()
        self.active_players = {}
        self.type = CHANCE


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
        'player_idx',
        'type',
        'raises',
        'round',
        'bet_sizes',
        'chip_sizes',
        'explorations'
    ]

    def __init__(self, action):
        self.action = action
        self.children = {}
        self.regret_sum = []
        self.strategy_sum = []
        self.utility_vector = []
        self.actions = ()
        self.strategy = []
        self.player_idx = 0
        self.utility = 0
        self.type = PLAYER
        self.explorations = 0

class TerminalNode(object):
    __slots__ = [
        'public_cards',
        'terminal',
        'children',
        'active_players',
        'type',
        'bet_sizes',
        'chip_sizes'
    ]

    def __init__(self):
        # utilities is a vector indexed by player
        self.terminal = True
        self.children = {}
        self.type = TERMINAL
