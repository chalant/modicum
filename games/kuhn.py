from enum import IntEnum

from games import games

class Actions(IntEnum):
    FOLD = 1
    CHECK = 2
    CALL = 3

class Kuhn(games.Game):
    max_raises = 0

    @staticmethod
    def action_mappings():
        pass

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
        pass

    @staticmethod
    def start(players, players_queue, root, mappings, chip_size, cards):
        pass

    @staticmethod
    def payoff(node, cards, community_cards, players, player, hand_size_map):
        pass

    @staticmethod
    def arrange_players(players):
        players.append(players.popleft())
        return players

    @staticmethod
    def community_cards(deck):
        return

    @staticmethod
    def distribute_cards(deck, players, player):
        return


