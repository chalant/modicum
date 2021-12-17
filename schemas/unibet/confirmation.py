def build(builder):
    confirmation = builder.scene()

    button = builder.label_type("Button")
    num_games = builder.label_type("NumberOfGames")

    one = confirmation.add_label("1", num_games)
    two = confirmation.add_label("2", num_games)
    three = confirmation.add_label("3", num_games)
    four = confirmation.add_label("4", num_games)

    num_games.add_component(one)
    num_games.add_component(two)
    num_games.add_component(three)
    num_games.add_component(four)

    confirmation.add_label(
        "Quit",
        button
    )

    register = confirmation.add_label(
        "Register",
        button,
        capture=True,
        classifiable=True
    )

    register.add_instance("True")
    register.add_instance("Null")

