def start():
    # we have an initial scene (we can start from an arbitrary scene, preferably a confirmation scene),

    # and a last scene (the last scene prompts us to launch a new game or to quit)
    # the first scene and last scene are controlled by the code logic (ex:
    # the logger controls when the game starts and when to quit.
    # note: we need to wait for an opponent sometimes... we an opponent is found, a message
    # appears, we could also detect when a player is seated or not...

    # todo: 1) prompt user to select game window
    #         1.1) should specify additional data manually (num_players?)
    #         1.2) should launch a detection loop to detect the first scene.
    #              once the first scene has been detected, the logger is ready to start.
    #      2) launch game solver process with known initial data (game type, chips etc.) as argument
    #             the solver will make a request to the server and will block until it receives
    #             the initial data (use threading.Event())
    #      3) launch detection to create initial data (private cards etc.)
    #           note: some data can already be set manually (
    #           like chips,
    #           number of players, ...)
    #           we only need to detect who is the dealer in order to determine players turn
    #      4) ...

    # could pass in "known" data like number of players, chips and blind amounts (which are the initial game settings)
    pass