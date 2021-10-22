import poker_server_pb2_grpc as srv
import poker_messages_pb2 as msg

from gscrap.labeling import labeling, labeler

from gscrap.data.labels import labels
from gscrap.data.filters import filters
from gscrap.data.rectangles import rectangles
from gscrap.data.properties import properties

from gscrap.samples import source as sc

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
    def __init__(self, scene, window, settings):
        """

        Parameters
        ----------
        scene: gscrap.projects.scenes.scenes._Scene
        """
        self._scene = scene

        self._opponents = opponents = [None] * (settings.num_players - 1)

        self._players = players = [None] * settings.num_players

        self._filter_pipelines = {}
        self._window = window

        card_label = labels.Label("Container", "Card")

        flop_label = labels.Label("Container", "Flop")
        turn_label = labels.Label("Container", "Turn")
        river_label = labels.Label("Container", "River")

        player_label = labels.Label("Container", "Player")
        opponent_label = labels.Label("Container", "Opponent")

        action_label = labels.Label("Image", "Action")
        bet_amount_label = labels.Label("Number", "BetAmount")

        with scene.connect() as connection:
            dealer_label = labels.Label("Image", "Dealer")
            rank_label = labels.get_label(connection, "Image", "Rank", scene)
            suit_label = labels.get_label(connection, "Image", "Suit", scene)
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
                (dealer_rct.width, dealer_rct.height)
            )

            self._rank_labeler = self._create_labeler(
                connection,
                scene,
                rank_label,
                (rank_rct.width, rank_rct.height))

            self._suit_labeler = self._create_labeler(
                connection,
                scene,
                suit_label,
                (suit_rct.width, suit_rct.height))

            self._action_labeler = self._create_labeler(
                connection,
                scene,
                action_label,
                (action_rct.width, action_rct.height)
            )

            self._amount_labeler = self._create_labeler(
                connection,
                scene,
                bet_amount_label,
                (bet_amount_rct.width, bet_amount_rct.height)
            )

            player_ist = next(self._get_rectangle_instances(connection, scene, player_label))

            position_property = properties.Property(properties.INTEGER, "Position")

            position = rectangles.get_property_value_of_rectangle_instance(
                connection,
                player_ist,
                position_property
            ).value

            card_rct = rectangles.get_rectangle_with_label(connection, scene, card_label)

            self._player = player = Player(
                list(self._get_cards_zone(connection, player_ist, card_rct, rank_rct, suit_rct)),
                self._get_amount_zone(connection, player_ist, bet_amount_rct),
                position
            )

            players[position] = player

            for opponent_ist in self._get_rectangle_instances(connection, scene, opponent_label):
                position = rectangles.get_property_value_of_rectangle_instance(
                    connection,
                    opponent_ist,
                    position_property
                ).value

                opponents[position] = Opponent(
                    list(self._get_cards_zone(connection, opponent_ist, card_rct, rank_rct, suit_rct)),
                    self._get_action_zone(connection, opponent_ist, action_rct),
                    self._get_amount_zone(connection, opponent_ist, bet_amount_rct),
                    self._get_state_zone(connection, opponent_ist, player_state_rct),
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

    def _create_labeler(self, connection, scene, label, dimensions):
        model = labeler.Labeler()

        filter_pipelines = self._filter_pipelines

        filter_group = filters.get_filter_group(
            connection,
            label.label_name,
            label.label_type,
            scene.name)

        group_id = filter_group['group_id'] + filter_group['parameter_id']

        if group_id not in filter_pipelines:
            # this will be displayed on the filters canvas.
            filter_pipeline = list(self._load_filters(
                connection,
                filter_group['group_id'],
                filter_group['parameter_id']
            ))
        else:
            filter_pipeline = filter_pipelines[group_id]

        meta = labeling.load_labeling_model_metadata(
            connection,
            label,
            scene.name)

        sample_source = sc.SampleSource(
            scene.name,
            label.label_type,
            label.label_name,
            dimensions,
            filter_pipeline
        )

        labeling_model = labeling.get_labeling_model(
            meta['model_type'],
            label.label_type).load(
            connection,
            meta['model_name'])

        labeling_model.set_samples_source(sample_source)

        sc.load_samples(sample_source, connection, scene)

        model.set_model(labeling_model)
        model.set_filter_pipeline(filter_pipeline)

        return model

    def _detect_cards(self, cards):
        window = self._window
        results = []

        rank_labeler = self._rank_labeler
        suit_labeler = self._suit_labeler

        for card in cards:
            rank_image = window.capture(card.rank_bbox)
            suit_image = window.capture(card.suit_bbox)

            rank_label = labeler.label(rank_labeler, rank_image)
            suit_label = labeler.label(suit_labeler, suit_image)

            results.append(msg.CardData(
                suit=suit_label,
                rank=rank_label))

        return msg.CardsData(cards=results)

    def _detect_action(self, window, action):
        action_labeler = self._action_labeler

        res = labeler.label(
            action_labeler,
            window.capture(action.bbox))

        while res == 'N/A':
            labeler.label(
                action_labeler,
                window.capture(action.bbox))

        return res


    def _detect_opponent_action(self, opponent):
        window = self._window

        action = self._detect_action(window, opponent.action)

        if action in _BET_ACTIONS:
            amount = self._detect_bet_amount(window, opponent.bet_amount)
        else:
            amount = 0.0

        return msg.ActionData(
            action=action,
            amount=amount)

    def _detect_bet_amount(self, window, amount):
        return float(labeler.label(
            self._amount_labeler,
            window.capture(amount.bbox)))

    def _detect_dealer(self, window, dealer):
        return labeler.label(
            self._dealer_labeler,
            window.capture(dealer.bbox))

    def GetBlinds(self, request, context):
        player = request.player_data
        #get the bet amount of the player in position

        return msg.Amount(value=self._detect_bet_amount(
            self._window,
            self._players[player.position].bet_amount))


    def GetBoardCards(self, request, context):
        board = self._board

        if request.round == msg.FLOP:
            return self._detect_cards(board.flop_cards)
        elif request.round == msg.TURN:
            return self._detect_cards(board.turn_cards)
        elif request.round == msg.RIVER:
            return self._detect_cards(board.river_cards)

    def GetPlayerAction(self, request, context):
        return self._detect_opponent_action(self._opponents[request.position])

    def GetPlayerCards(self, request, context):
        return self._detect_cards(self._player.cards)

    def GetDealer(self, request_iterator, context):
        window = self._window

        players = list(request_iterator)

        #loop multiple times between players until a dealer is found.

        while True:
            for player in players:
                if self._detect_dealer(window, player.dealer) == 'Dealer':
                    return player
