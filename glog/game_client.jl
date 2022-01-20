module game_client

using Random

using ArgParse
using StaticArrays

using games
using cards
using playing
using players
using actions

using PokerClients
using data_conversion

export start
export parse_commandline

const PlayersData = Vector{PokerClients.PlayerData}()

mutable struct LiveGame <: GameSetup
    client::PokerServiceBlockingClient
    num_hands::UInt64
    pot::Float32
    last_bet::Float32
end

@inline function message(action::Action, gs::GameState)
    id = action.id

    if id == CHECK_ID
        return string("Check")
    elseif id == RAISE_ID
        return string("Raise ", betamount(action, gs, gs.player))
    elseif id == ALL_ID
        return string("Play all ", chips(gs))
    elseif id == FOLD_ID
        return string("Fold")
    elseif id == CALL_ID
        return string("Call ", callamount(gs, gs.player))
    elseif id == BET_ID
        return string("Bet ", betamount(action, gs, gs.player))
    end
end

@inline function playing.onbetactionperformed!(gs::GameState{Game{LiveGame, T}}) where T <: GameMode
    stp = setup(gs.game)
    
    stp.pot = gs.total_bet
    stp.last_bet = stp.last_bet
end

@inline function playing.beforechancereset!(gs::GameState, gm::Game{LiveGame, T}) where T <: GameMode
    stp = setup(gm)
    
    stp.pot = gs.total_bet
    stp.last_bet = 0
end

@inline function getplayeraction(stp::LiveGame, gs::GameState, player::PlayerState, new_hand::Bool)
    return fromactiondata(PokerClients.GetPlayerAction(
                    stp.client,
                    PokerClients.PlayerActionRequest(
                        ;round=gs.round, 
                        player_data=PlayersData[players.position(player)], 
                        new_hand=new_hand))[1], 
                    gs, 
                    player,
                    stp.last_bet,
                    stp.pot)
end

@inline function playing.updateprivatecards!(gs::GameState, g::Game{LiveGame, T}) where T <: GameMode
    data = shared(g)
    stp = setup(g)

    for ps in gs.players_states
        id = players.id(ps)
        
        if ps != g.main_player && ps.active == true
            data.private_cards[id] = getplayercards(stp.client, id - 1, gs, g)
            println("Updated Cards:", pretty_print_cards(data.private_cards[id]), " ID ", id)
        end
    end

    return data

end

@inline function playing.setpubliccards!(gs::GameState, g::Game{LiveGame, T}) where T <: GameMode
    data = shared(g)
    stp = setup(g)
    #todo fetch board cards, remove them from internal deck (so that when we simulate, 
    # we don't take those cards into account)
    local request::PokerClients.BoardCardsRequest

    if gs.round == 1
        request = PokerClients.BoardCardsRequest(
            ;round=PokerClients.Round.FLOP)
    elseif gs.round == 2
        request = PokerClients.BoardCardsRequest(
            ;round=PokerClients.Round.TURN)
    elseif gs.round == 3
        request = PokerClients.BoardCardsRequest(
            ;round=PokerClients.Round.RIVER)
    else
        error("Unsupported value", " ", gs.round)
    end
    
    response, future = PokerClients.GetBoardCards(stp.client, request)

    i = 1
    board = data.public_cards
    mask = data.pbl_cards_mask

    for card in fromcardsdata(response)
        board[i] = card
        mask[i] = 1

        data.deck_cursor -= 1

        i += 1
    end

    println("Public Cards:", pretty_print_cards(data.public_cards))
    
    #remove public cards from deck
    setdiff!(data.deck, data.public_cards)

    return data
end

@inline function getplayercards(client::PokerServiceBlockingClient, player_id::Integer, gs::GameState, g::Game)
    return fromcardsdata(PokerClients.GetPlayerCards(
        client,
        PokerClients.PlayerCardsRequest(;
            new_hand=gs.state == ENDED_ID,
            showdown=gs.round >= g.num_rounds,
            player=PokerClients.PlayerData(position=UInt32(player_id))))[1])
end

@inline function playing.postblinds!(gs::GameState, g::Game{LiveGame, T}) where T <: GameMode
    client = getclient!(setup(g))

    data = shared(g)

    #update blinds

    blinds = PokerClients.GetBlinds(client, PokerClients.BlindsRequest(;num_hands=setup(g).num_hands))[1]

    data.sb = blinds.small_blind
    data.bb = blinds.big_blind

    println(
        "Posting Blinds ", 
        data.sb, " ", 
        data.bb)

    _postblinds!(gs, g)
end

@inline function getclient!(stp::LiveGame)
    return stp.client
end

@inline function putlast!(pls::Vector{PlayerState}, last_position::UInt8)

    idx = 1

    for pl in pls
        if players.position(pl) == last_position
            break
        end

        idx += 1
    end

    for i in 1:length(pls) - idx
        pushfirst!(pls, pop!(pls))
    end

end

function start(
    ::Val{N},
    server_url::String, 
    small_blind::Float32, 
    big_blind::Float32, 
    chips::UInt32) where {N, A}

    client = PokerServiceBlockingClient(server_url)

    game = Game{LiveGame, N, 3}()
    game_setup = LiveGame(client, 0, 0, 0)
    
    game.game_setup = game_setup

    shared_data = SharedData{N}()

    #todo: action set should also be provided when we launch the game (note should
    # correspond to the one we trained with)

    #setup the game.

    game.game_mode = gm
    game.shared_state = shared_data


    #small blind and big blind are provided in the parameters

    shared_data.sb = small_blind
    shared_data.bb = big_blind

    game.num_private_cards = 2
    game.num_public_cards = 5
    game.num_rounds = 4
    game.chips = chips

    game.cards_per_round = @SVector [UInt8(3), UInt8(1), UInt8(1)]

    #todo: need an action set (which should be the same as the blueprint model)
    # otherwise the performance would probably not be the same.

    # note: ideally, a blueprint strategy is trained against a certain game setup.
    # and is bound to that.
    # multiple games can share the same game setup
    
    #TODO: a strategy should be a "bundle" with action set etc.

    action_set = ActionSet{11}([
        CALL,
        FOLD,
        ALL,
        CHECK,
        Action(RAISE_ID, 0.5, 2),
        Action(RAISE_ID, 0.75, 3),
        Action(RAISE_ID, 1, 4),
        Action(BET_ID, 0, 1),
        Action(BET_ID, 0.5, 2),
        Action(BET_ID, 0.75, 3),
        Action(BET_ID, 1, 4)])

    lgs = GameState{A, N, Game{LiveGame}}()

    lgs.actions_mask = @MVector ones(Bool, A)
    
    lgs.game = game

    game.actions = action_set

    #todo: make a request to the server to know if we can start playing
    PokerClients.IsReady(client, PokerClients.Empty()) 

    num_players = gm.num_players

    players_vec = SizedVector{N, Player}(undef)
    players_states = SizedVector{N, PlayerState}(undef)
    private_cards = SizedVector{N}(Vector{UInt64}(undef, num_players))
    public_cards = Vector{UInt64}()

    active_players = 0

    #keep a reference to the main player
    local main_player::PlayerState

    out_channel, status_future = PokerClients.GetPlayers(
        client, 
        PokerClients.Empty())

    println("Fetching Players...")
    
    for player in out_channel
        push!(PlayersData, player)

        pos = player.position
        p = pos + 1

        #increment position to one since julia indexing starts
        #from 1

        ply = Player(p, p)
        st = PlayerState()

        if pos == 0
            main_player = st
            game.main_player = ply
        end

        st.chips = chips
        st.bet = 0
        st.pot = 0
        is_active = player.is_active

        if is_active == true
            active_players += 1
        end

        st.active = is_active
        st.player = ply
        st.total_bet = 0

        players_vec[p] = ply
        players_states[p] = st

        private_cards[p] = Vector{UInt64}()
    end

    sort!(PlayersData, by = x -> x.position)

    println("Fetching Dealer...")
    
    player_stream = Channel{PokerClients.PlayerData}(1) do ch 
        for ps in players_states
            put!(ch, toplayerdata(ps))
        end
        close(ch)
    end

    dealer, future = PokerClients.GetDealer(
            client, 
            player_stream)

    #re-order players such that the dealer is last
    putlast!(players_states, UInt8(dealer.position + 1))

    println("Done")
    
    #set first player to act
    lgs.player = players_states[1]
    lgs.position = 1

    println("First Player ", players.id(lgs.player), " ", players.id(main_player))

    lgs.active_players = num_players

    game.players = players_vec
    lgs.players_states = players_states

    lgs.total_bet = 0
    lgs.active_players = active_players

    lgs.round = 0
    lgs.last_bet = 0
    lgs.pot_size = 0
    lgs.position = 1
    lgs.all_in = 0


    main_player_position = players.position(main_player)

    #initialize main player cards and deck

    println("Fetching Cards...")

    mp_private_cards = getplayercards(
        client, 
        players.id(main_player) - 1, 
        lgs, 
        game)

    private_cards[main_player_position] = mp_private_cards

    shared_data.private_cards = private_cards
    shared_data.public_cards = public_cards
    
    cards_deck = get_deck()
    
    #remove private cards from deck
    setdiff!(cards_deck, mp_private_cards)

    shared_data.deck = shuffle!(cards_deck)

    println("Done")

    lgs.state = STARTED_ID

    #post blinds
    postblinds!(lgs, game)

    # game loop.
    # note: loop breaks when the main player is eliminated or wins

    previous_round = lgs.round

    new_hand = true

    while true
        
        current_player = lgs.player

        if current_player == main_player
            #todo: choose an action from the action set then perform it
            act = action_set[sample(actionsmask!(lgs))]

            println("You should play: ", message(act, lgs))
            
            #blocks until player performed the action.
            PokerClients.PerformAction(client, toactiondata(act, lgs, current_player))

            perform!(
                act,
                lgs,
                main_player
            )

            current_player.action = act.id

        else
            # local opp_act::PokerClients.ActionData
            
            println("Waiting for Opponent action...")
            
            opp_action = getplayeraction(
                game_setup, 
                lgs, 
                current_player,
                new_hand
            )

            new_hand = false
            
            println("Opponent performed: ", message(opp_action, lgs))

            if !(opp_action in action_set)
                #TODO: if the opponent action is not in the action set, start sub-game solving
                # with a limited time. (20 seconds for instance)
                
                #NOTE: we start from a copy if the live game state.

                println(
                    "Action ", 
                    message(opp_action, lgs),
                    " ",
                    opp_action.pot_multiplier,
                    " ", 
                    opp_action.blind_multiplier,
                    " ", 
                    "Not in set")
            end

            perform!(
                opp_action,
                lgs,
                current_player)
            
            current_player.action = opp_action.id
        end

        # #we compute winner here!
        # state_id = update!(lgs, game)

        #todo: we need to implement a special initialization step for games modes...
        
        #todo: if the state_id is ended, fetch private cards, then suffle

        if state_id == TERM_ID
            #todo: maybe wait for server input to know if game should end
            #and call IsReady
            break
        
        elseif state_id == ENDED_ID
            #todo: in certain game modes, (sit and go) 
            # we can quit any time at the end of a game.
            # maybe wait for server input... and call IsReady
            
            winner = computewinner!(lgs, g)

            #reset some game state variables
            lgs.round = 0
            lgs.last_bet = 0
            lgs.pot_size = 0
            lgs.position = 1
            lgs.all_in = 0
            lgs.total_bet = 0
            
            #put back public cards
            for _ in 1:length(public_cards)
                push!(cards_deck, pop!(public_cards))
            end

            #put back private cards
            for ps in players_states
                pc = private_cards[players.position(ps)]

                for _ in 1:length(pc)
                    push!(cards_deck, pop!(pc))
                end 

            end
            
            #update player positions and reset variables
            activateplayers!(lgs)
            
            #set current player
            lgs.player = lgs.players_states[1]

            println("ENDED!", " ", players.id(lgs.player))

            pc = getplayercards(
                client, 
                players.id(main_player) - 1,
                lgs,
                game)

            private_cards[main_player_position] = pc

            println("Private Cards: ", pretty_print_cards(pc), " ")
            
            #remove private cards from deck and shuffle
            setdiff!(cards_deck, pc)
            shuffle!(cards_deck)
            
            lgs.state = STARTED_ID
            
            #increase number of hands
            game_setup.num_hands += 1

            postblinds!(lgs, game)

            new_hand = true

        end

        previous_round = lgs.round

    end

end

function parse_commandline()
    settings = ArgParseSettings()

    @add_arg_table! settings begin
        "--server_url"
            required = true
            arg_type = String
        "--num_players"
            required = true
            arg_type = Int
        "--chips"
            required = true
            arg_type = Int
        "--small_blind"
            required = true
            arg_type = Float32
        "--big_blind"
            required = true
            arg_type = Float32
        "--time_per_turn"
            required = true
            arg_type = Float32
    end

    return parse_args(ARGS, settings)

end

end