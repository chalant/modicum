import threading

from glog import poker_server_pb2_grpc as srv
from glog import poker_messages_pb2 as msg

from gscrap.image_capture import capture

from gscrap.labeling import labeling, labeler

from gscrap.data.labels import labels
from gscrap.data.filters import filters
from gscrap.data.rectangles import rectangles
from gscrap.data.properties import properties

_BET_ACTIONS = {'Bet', 'Call', 'Raise', 'All-In'}


class CaptureZone(object):
    __slots__ = ['bbox']

    def __init__(self, bbox):
        self.bbox = bbox


class Board(object):
    def __init__(self, flop_cards, turn_cards, river_cards):
        self.flop_cards = flop_cards
        self.turn_cards = turn_cards
        self.river_cards = river_cards


class Card(object):
    __slots__ = ['rank_bbox', 'suit_bbox']

    def __init__(self, rank_bbox, suit_bbox):
        self.rank_bbox = rank_bbox
        self.suit_bbox = suit_bbox


class Player(object):
    __slots__ = ['cards', 'bet_amount', 'position', 'dealer']

    def __init__(self, cards, bet_amount, dealer, position):
        self.cards = cards
        self.position = position
        self.bet_amount = bet_amount
        self.dealer = dealer


class Opponent(object):
    __slots__ = ['cards', 'action', 'bet_amount', 'state', 'position', 'dealer']

    def __init__(self, cards, action, bet_amount, state, dealer, position):
        self.cards = cards
        self.action = action
        self.bet_amount = bet_amount
        self.state = state
        self.position = position
        self.dealer = dealer


class PokerTableServer(srv.PokerServiceServicer):
    def __init__(self, scene, settings, filter_pipelines, antes_increase):
        """

        Parameters
        ----------
        scene: gscrap.projects.scenes.scenes._Scene
        settings:
        filter_pipelines: gscrap.data.filters.filter_pipelines.FilterPipelines
        """

        num_players = settings['num_players']

        self._scene = scene

        self._players = players = [None] * num_players

        self._filter_pipelines = filter_pipelines

        self._is_ready = threading.Event()

        card_label = labels.Label("Container", "Card")

        flop_label = labels.Label("Container", "Flop")
        turn_label = labels.Label("Container", "Turn")
        river_label = labels.Label("Container", "River")

        player_label = labels.Label("Container", "Player")
        opponent_label = labels.Label("Container", "Opponent")

        action_label = labels.Label("Text", "Action")
        bet_amount_label = labels.Label("Number", "BetAmount")

        with scene.connect() as connection:
            dealer_label = labels.Label("Image", "Button")
            rank_label = labels.get_label(connection, "Image", "Rank", scene.name)
            suit_label = labels.get_label(connection, "Image", "Suit", scene.name)
            player_state_label = labels.Label("Image", "PlayerState")

            dealer_rct = rectangles.get_rectangle_with_label(connection, scene, dealer_label)

            rank_rct = rectangles.get_rectangle_with_label(connection, scene, rank_label)
            suit_rct = rectangles.get_rectangle_with_label(connection, scene, suit_label)

            action_rct = rectangles.get_rectangle_with_label(connection, scene, action_label)
            bet_amount_rct = rectangles.get_rectangle_with_label(connection, scene, bet_amount_label)

            player_state_rct = rectangles.get_rectangle_with_label(connection, scene, player_state_label)

            self._dealer_labeler = self._create_labeler(
                connection,
                scene,
                dealer_label,
                dealer_rct
            )

            self._rank_labeler = self._create_labeler(
                connection,
                scene,
                rank_label,
                rank_rct)

            self._suit_labeler = self._create_labeler(
                connection,
                scene,
                suit_label,
                suit_rct)

            self._action_labeler = self._create_labeler(
                connection,
                scene,
                action_label,
                action_rct
            )

            self._amount_labeler = self._create_labeler(
                connection,
                scene,
                bet_amount_label,
                bet_amount_rct
            )

            player_ist = next(self._get_rectangle_instances(connection, scene, player_label))

            position_property = properties.Property(properties.INTEGER, "Position")

            position = int(rectangles.get_property_value_of_rectangle_instance(
                connection,
                player_ist,
                position_property
            ).value)

            card_rct = rectangles.get_rectangle_with_label(connection, scene, card_label)

            self._player = player = Player(
                list(self._get_cards_zone(connection, player_ist, card_rct, rank_rct, suit_rct)),
                self._get_capture_zone(connection, player_ist, bet_amount_rct),
                self._get_capture_zone(connection, player_ist, dealer_rct),
                position
            )

            players[position] = player

            for opponent_ist in self._get_rectangle_instances(connection, scene, opponent_label):
                position = int(rectangles.get_property_value_of_rectangle_instance(
                    connection,
                    opponent_ist,
                    position_property
                ).value)

                players[position] = Opponent(
                    list(self._get_cards_zone(connection, opponent_ist, card_rct, rank_rct, suit_rct)),
                    self._get_capture_zone(connection, opponent_ist, action_rct),
                    self._get_capture_zone(connection, opponent_ist, bet_amount_rct),
                    self._get_capture_zone(connection, opponent_ist, player_state_rct),
                    self._get_capture_zone(connection, opponent_ist, dealer_rct),
                    position
                )

            # build board

            flop_ist = next(self._get_rectangle_instances(connection, scene, flop_label))
            turn_ist = next(self._get_rectangle_instances(connection, scene, turn_label))
            river_ist = next(self._get_rectangle_instances(connection, scene, river_label))

            self._board = Board(
                list(self._get_cards_zone(connection, flop_ist, card_rct, rank_rct, suit_rct)),
                list(self._get_cards_zone(connection, turn_ist, card_rct, rank_rct, suit_rct)),
                list(self._get_cards_zone(connection, river_ist, card_rct, rank_rct, suit_rct)))

        self._previous_action = ""
        self._previous_amount = 0.0
        self._previous_round = 0
        self._antes_increase = antes_increase

    def _get_capture_zone(self, connection, target_instance, target_rectangle):
        bbox = next(
            rectangles.get_components_that_are_instances_of_rectangle(
                connection,
                target_instance,
                target_rectangle)).bbox

        return CaptureZone(bbox)

    def _get_dealer_zone(self, connection, target_instance, dealer_rectangle):
        dealer_bbox = next(
            rectangles.get_components_that_are_instances_of_rectangle(
                connection,
                target_instance,
                dealer_rectangle)).bbox

        return CaptureZone(dealer_bbox)

    def _get_rectangle_instances(self, connection, scene, label):
        return rectangles.get_rectangle_with_label(
            connection,
            scene,
            label).get_instances(connection)

    def _get_state_zone(self, connection, opponent_instance, state_rectangle):
        player_state_bbox = next(rectangles.get_components_that_are_instances_of_rectangle(
            connection,
            opponent_instance,
            state_rectangle
        ))
        return CaptureZone(player_state_bbox)

    def _get_action_zone(self, connection, opponent_instance, action_rectangle):
        action_bbox = next(rectangles.get_components_that_are_instances_of_rectangle(
            connection,
            opponent_instance,
            action_rectangle
        )).bbox

        return CaptureZone(action_bbox)

    def _get_amount_zone(self, connection, opponent_instance, amount_rectangle):
        amount_bbox = next(rectangles.get_components_that_are_instances_of_rectangle(
            connection,
            opponent_instance,
            amount_rectangle
        )).bbox

        return CaptureZone(amount_bbox)

    def _get_cards_zone(
            self,
            connection,
            container_instance,
            card_rectangle,
            rank_rectangle,
            suit_rectangle):

        for card in rectangles.get_components_that_are_instances_of_rectangle(
                connection,
                container_instance,
                card_rectangle):
            rank_ist = next(rectangles.get_components_that_are_instances_of_rectangle(
                connection,
                card,
                rank_rectangle
            ))

            suit_ist = next(rectangles.get_components_that_are_instances_of_rectangle(
                connection,
                card,
                suit_rectangle
            ))

            yield Card(rank_ist.bbox, suit_ist.bbox)

    def _load_filters(self, connection, group_id, parameter_id):
        for res in filters.load_filters(connection, group_id, parameter_id):
            type_ = res["type"]
            name = res["name"]
            position = res["position"]

            filter_ = filters.create_filter(type_, name, position)
            filter_.load_parameters(connection, group_id, parameter_id)

            yield filter_

    def _get_dimensions(self, bbox):
        return bbox[2] - bbox[0], bbox[3] - bbox[1]

    def _create_labeler(self, connection, scene, label, rectangle):
        filter_pipeline = self._filter_pipelines.get_filter_pipeline(
            connection,
            label,
            scene)

        return labeler.create_labeler(
            connection,
            scene,
            label,
            rectangle,
            filter_pipeline)

    def _detect_cards(self, window, cards):
        results = []

        rank_labeler = self._rank_labeler
        suit_labeler = self._suit_labeler

        for card in cards:
            while True:
                rank_label = labeler.label(
                    rank_labeler,
                    window.capture(card.rank_bbox))

                if rank_label:
                    if rank_label == "10":
                        rank_label = "T"
                    break

            while True:
                suit_label = labeler.label(
                    suit_labeler,
                    window.capture(card.suit_bbox))

                if suit_label:
                    break

            results.append(msg.CardData(
                suit=suit_label,
                rank=rank_label))

        return msg.CardsData(cards=results)

    def _detect_action(self, window, action):
        action_labeler = self._action_labeler

        res = labeler.label(
            action_labeler,
            window.capture(action.bbox))

        while not res:
            res = labeler.label(
                action_labeler,
                window.capture(action.bbox))

        return res

    def _detect_opponent_action(self, window, opponent, rd):
        while True:
            action = self._detect_action(window, opponent.action)
            if action in _BET_ACTIONS:
                amount = self._detect_bet_amount(window, opponent.bet_amount)
                while not amount:
                    amount = self._detect_bet_amount(window, opponent.bet_amount)
            else:
                amount = 0.0

            if action != self._previous_action:
                self._previous_amount = amount
                self._previous_round = rd
                self._previous_action = action

                return msg.ActionData(
                    action_type=self._get_action_type(action),
                    multiplier=1.0,
                    amount=amount)

            elif action == self._previous_action:
                if amount != self._previous_amount:

                    self._previous_amount = amount
                    self._previous_round = rd
                    self._previous_action = action

                    return msg.ActionData(
                        action_type=self._get_action_type(action),
                        multiplier=1.0,
                        amount=amount)

                elif rd != self._previous_round:
                    self._previous_amount = amount
                    self._previous_round = rd
                    self._previous_action = action

                    return msg.ActionData(
                        action_type=self._get_action_type(action),
                        multiplier=1.0,
                        amount=amount)

    def _detect_bet_amount(self, window, amount):
        amount_labeler = self._amount_labeler

        res = labeler.label(
            amount_labeler,
            window.capture(amount.bbox))

        if res:
            return float(res)
        else:
            return

    def _get_action_type(self, action):
        if action == 'Call':
            return msg.ActionData.CALL
        elif action == 'Bet':
            return msg.ActionData.BET
        elif action == 'All-In':
            return msg.ActionData.ALL_IN
        elif action == 'Fold':
            return msg.ActionData.FOLD
        elif action == 'Raise':
            return msg.ActionData.RAISE
        elif action == 'Check':
            return msg.ActionData.CHECK

    def _detect_dealer(self, window, dealer):
        return labeler.label(
            self._dealer_labeler,
            window.capture(dealer.bbox))

    def set_to_ready(self):
        #start antes increase thread
        self._antes_increase.start()
        self._is_ready.set()

    def set_window(self, window):
        self._window = window

    def IsReady(self, request, context):
        self._is_ready.wait()

        return msg.Empty()

    def GetBlinds(self, request, context):
        with capture.capture_context(self._window) as cm:
            self._antes_increase.set_hands_number(request.num_hands)

            # while True:
            #     bet_amount = self._detect_bet_amount(cm, self._players[player.position].bet_amount)
            #
            #     if bet_amount:
            #         return msg.Amount(
            #             value=bet_amount)

            return msg.Blinds(
                small_blind=self._antes_increase.small_blind,
                big_blind=self._antes_increase.big_blind
            )

    def GetBoardCards(self, request, context):
        with capture.capture_context(self._window) as cm:
            board = self._board

            if request.round == msg.FLOP:
                return self._detect_cards(cm, board.flop_cards)
            elif request.round == msg.TURN:
                return self._detect_cards(cm, board.turn_cards)
            elif request.round == msg.RIVER:
                return self._detect_cards(cm, board.river_cards)

    def GetPlayerAction(self, request, context):
        player = request.player_data

        with capture.capture_context(self._window) as cm:
            return self._detect_opponent_action(
                cm,
                self._players[player.position],
                request.round)

    def GetPlayerCards(self, request, context):
        with capture.capture_context(self._window) as ch:
            return self._detect_cards(ch, self._players[request.position].cards)

    def GetPlayers(self, request, context):
        for player in self._players:
            pos = player.position
            if pos == 0:
                pt = msg.PlayerData.MAIN
            else:
                pt = msg.PlayerData.OPPONENT

            yield msg.PlayerData(
                position=player.position,
                player_type=pt,
                is_active=True
            )

    def GetDealer(self, request_iterator, context):
        players = list(request_iterator)
        pls = self._players
        # loop multiple times between players until a dealer is found.

        with capture.capture_context(self._window) as cm:
            while True:
                for pl in players:
                    if pl.is_active == True:
                        if self._detect_dealer(cm, pls[pl.position].dealer) == "Dealer":
                            return pl

    def PerformAction(self, request, context):
        # todo: should maybe return a status so that we know if the action was executed

        print(
            "Action ", request.action_type,
            "Multiplier ", request.multiplier,
            "Amount ", request.amount)

        print("Press Any Key...")

        if input():
            return msg.Empty()
