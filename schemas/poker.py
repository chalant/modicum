from gscrap.data.properties import properties as pp
from gscrap.data import attributes

def build(builder):
    number = builder.label_type("Number")
    image = builder.label_type("Image")
    text = builder.label_type("Text")
    button = builder.label_type("Button")
    container = builder.label_type("Container")

    poker = builder.new_scene("poker")

    poker.add_label("Pot", number, capture=True)

    # state label where instances can be (active, inactive, ...)
    state_label = poker.add_label(
        "PlayerState",
        image,
        capture=True,
        classifiable=True)

    state_label.add_instance("Active")
    state_label.add_instance("Inactive")
    state_label.add_instance("Seated")
    state_label.add_instance("Unseated")
    state_label.add_instance("Null")

    # label where instances are (bet, call, fold, ...)
    poker_action_label = poker.add_label(
        "Action",
        text,
        capture=True,
        classifiable=True)

    poker_action_label.add_instance("Check")
    poker_action_label.add_instance("Call")
    poker_action_label.add_instance("Fold")
    poker_action_label.add_instance("Bet")
    poker_action_label.add_instance("All-In")
    poker_action_label.add_instance("Raise")
    poker_action_label.add_instance("Null")  # no action

    poker_act_btn_lbl = poker.add_label("PlayerAction", button, classifiable=True)

    poker_act_btn_lbl.add_instance("Call")
    poker_act_btn_lbl.add_instance("Fold")
    poker_act_btn_lbl.add_instance("Bet")
    poker_act_btn_lbl.add_instance("All-In")
    poker_act_btn_lbl.add_instance("Raise")
    poker_act_btn_lbl.add_instance("Null")

    poker_button = poker.add_label(
        "Button",
        image,
        capture=True,
        classifiable=True
    )

    poker_button.add_instance("Dealer")
    poker_button.add_instance("SmallBlind")
    poker_button.add_instance("BigBlind")
    poker_button.add_instance("Null")

    card = builder.get_label("card", "Card")

    position = builder.property_(pp.INTEGER, "Position")

    builder.property_attribute(position, attributes.DISTINCT)

    builder.incremental_value_generator(position)

    board_label = poker.add_label("Board", container)

    board_label.add_component(card)

    opponent = poker.add_label("Opponent", container)

    # components are used to track which component belongs to which element

    opponent.add_component(card)
    opponent.add_component(poker_action_label)
    opponent.add_component(state_label)
    opponent.add_component(poker_button)

    opponent.add_property(position)

    player = poker.add_label("Player", container)

    player.add_component(card)
    player.add_component(poker_act_btn_lbl)
    player.add_component(poker_button)
    player.add_component(state_label)

    player.add_property(position)