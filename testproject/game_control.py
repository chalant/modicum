from gscrap.data.labels import labels
from gscrap.data.rectangles import rectangles

class InteractionZone(object):
    def __init__(self, bbox):
        self.bbox = bbox

class GameController(object):
    def __init__(self, scene):
        with scene.connect() as connection:
            bet_label = labels.Label("Button", "Bet")
            raise_label = labels.Label("Button", "Raise")
            call_label = labels.Label("Button", "Call")
            fold_label = labels.Label("Button", "Fold")
            check_label = labels.Label("Button", "Check")
            all_in_label = labels.Label("Button", "All-In")

            amount_input_label = labels.Label("AmountInput", "InputBox")

            self._amount_input = self._get_interaction_zone(
                connection,
                scene,
                amount_input_label
            )

            self._bet = self._get_interaction_zone(
                connection,
                scene,
                bet_label
            )

            self._raise = self._get_interaction_zone(
                connection,
                scene,
                raise_label
            )

            self._call = self._get_interaction_zone(
                connection,
                scene,
                call_label
            )

            self._fold = self._get_interaction_zone(
                connection,
                scene,
                fold_label
            )

            self._check = self._get_interaction_zone(
                connection,
                scene,
                check_label
            )

            self._all_in = self._get_interaction_zone(
                connection,
                scene,
                all_in_label
            )

    def _get_interaction_zone(self, connection, scene, label):
        return InteractionZone(next(rectangles.get_rectangle_with_label(
            connection,
            scene,
            label).get_instances(connection)).bbox)

    def perform_action(self, action):
        #todo: select a destination point within the "capture zone" to click.
        #todo: input the action amount in the text box (double click in the text box then type)

        pass