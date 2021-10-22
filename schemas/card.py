def build(builder):
    cards = builder.scene()

    image = builder.label_type("Image")
    container = builder.label_type("Container")

    card_state = cards.add_label(
        "CardState",
        image,
        3,
        capture=True,
        classifiable=True)

    card_state.add_instance("Hidden")
    card_state.add_instance("Shown")
    card_state.add_instance("Null")

    card_label = cards.add_label("Card", container)

    rank_label = cards.add_label(
        "Rank",
        image,
        13,
        capture=True,
        classifiable=True)

    suit_label = cards.add_label(
        "Suit",
        image,
        4,
        capture=True,
        classifiable=True)

    rank_label.add_instance("A")
    rank_label.add_instance("K")
    rank_label.add_instance("Q")
    rank_label.add_instance("J")
    rank_label.add_instance("10")
    rank_label.add_instance("9")
    rank_label.add_instance("8")
    rank_label.add_instance("7")
    rank_label.add_instance("6")
    rank_label.add_instance("5")
    rank_label.add_instance("4")
    rank_label.add_instance("3")
    rank_label.add_instance("2")
    rank_label.add_instance("Null")

    suit_label.add_instance("Heart")
    suit_label.add_instance("Diamond")
    suit_label.add_instance("Spade")
    suit_label.add_instance("Club")
    suit_label.add_instance("Null")

    card_label.add_component(rank_label)
    card_label.add_component(suit_label)

