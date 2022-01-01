def build(builder):
    control = builder.scene()

    input_box = builder.label_type("InputBox")
    button = builder.label_type("Button")

    control.add_label("Bet", button)
    control.add_label("Raise", button)
    control.add_label("Call", button)
    control.add_label("Fold", button)
    control.add_label("Check", button)
    control.add_label("All-In", button)

    control.add_label("AmountInput", input_box)