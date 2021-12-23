module game_client

using ArgParse

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

struct LiveGame <: GameSetup
    client::PokerServiceBlockingClient
end

@inline function playing.updateprivatecards!(gs::GameState, g::Game{LiveGame, T}) where T <: GameMode
    data = shared(g)
    stp = setup(g)

    for ps in gs.players_states
        id = players.id(ps)
        
        if id != stp.main_player && ps.active == true
            data.privatecards[id] = getplayercards(stp.client, id - 1)
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
            ;round=PokerClients.BoardCardsRequest_Round.FLOP)
    elseif gs.round == 2
        request = PokerClients.BoardCardsRequest(
            ;round=PokerClients.BoardCardsRequest_Round.TURN)
    elseif gs.round == 3
        request = PokerClients.BoardCardsRequest(
            ;round=PokerClients.BoardCardsRequest_Round.RIVER)
    else
        error("Unsupported value", " ", gs.round)
    end
    
    response, future = PokerClients.GetBoardCards(stp.client, resquest)

    #todo: populate public cards array.
    #note: we can pre-allocate a size of five element to the array
    #todo: we need to remove the cards from the deck
    empty!(data.public_cards)
    append!(data.public_cards, fromcardsdata(response))
    
    #remove public cards from deck
    setdiff!(data.deck, data.public_cards)

    return data
end

@inline function playing.setpubliccards!(gs::GameState, g::Game{LiveGame, T}) where T <: GameMode
    #todo: fetch board cards from server

end

@inline function getplayercards(client::PokerServiceBlockingClient, player_id::Integer)
    cards_data, future = PokerClients.GetPlayerCards(
            client,
            PokerClients.PlayerData(position=UInt32(player_id)))

    return fromcardsdata(cards_data)
end

@inline function playing.postblinds!(gs::GameState, g::Game{LiveGame, U}) where U <: GameMode
    client = getclient!(setup(gs))

    data = shared(gs)

    sb = gs.players_states[1]
    bb = gs.players_states[2]

    #update blinds

    data.sb = PokerClients.GetBlinds(client, PlayersData[players.position(sb)])[1].value
    data.bb = PokerClients.GetBlinds(client, PlayersData[players.position(bb)])[1].value

    _postblinds!(gs, g)
end

@inline function getclient!(gs::LiveGame)
    return gs.client
end

@inline function playing.setpubliccards!(gs::GameState, g::Game{LiveGame, U}) where U <: GameMode
        client = getclient!(game!(gs))

        data = shared(gs)
        
        round = gs.round

        if round == 1
            round_request = Round.FLOP
        elseif round == 2
            round_request = Round.TURN
        elseif round == 3
            round_request = Round.RIVER
        end

        board_cards = PokerClients.GetBoardCards(
            client, 
            PokerClients.BoardCardsRequest(round=round_request))

        for card in board_cards.cards
            #todo convert card to internal data structure
            append!(data.public_cards, card)
            #todo find and remove card from local deck
            data.deck_cursor -= 1
        end

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
    gm::T, 
    server_url::String, 
    small_blind::Float32, 
    big_blind::Float32, 
    chips::UInt32) where T <: GameMode

    client = PokerServiceBlockingClient(server_url)

    game = Game{LiveGame, T}()
    game.game_setup = LiveGame(client)

    lgs = GameState{Game{LiveGame, T}}()
    lgs.game = game

    shared_data = SharedData()

    #todo: should we include small blind data variation in the simulation?
    # it is either time based or round based? (maybe each 4 or 5 rounds?)

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

    game.cards_per_round = Vector{UInt8}([UInt8(3), UInt8(1), UInt8(1)])

    #todo: make a request to the server to know if we can start playing
    PokerClients.IsReady(client, PokerClients.Empty()) 

    num_players = gm.num_players

    players_vec = Vector{Player}(undef, num_players)
    players_states = Vector{PlayerState}(undef, num_players)
    private_cards = Vector{Vector{UInt64}}(undef, num_players)

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
            game.main_player = main_player
        end

        st.chips = chips
        st.bet = 0
        is_active = player.is_active

        if is_active == true
            active_players += 1
        end

        st.active = is_active
        st.player = ply
        st.total_bet = 0

        players_vec[p] = ply
        players_states[p] = st

        st.rank = Int16(7463)
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
    putlast!(players_states, UInt8(dealer.position))

    println("Done")
    
    #set first player to act
    lgs.player = players_states[1]
    lgs.position = 1

    lgs.actions_mask = trues(length(actions!(lgs)))
    lgs.active_players = num_players
    lgs.state = STARTED

    game.players = players_vec
    lgs.players_states = players_states

    lgs.total_bet = 0
    lgs.active_players = active_players

    #todo: need an action set (which should be the same as the blueprint model)
    # otherwise the performance would probably not be the same.

    # note: ideally, a blueprint strategy is trained against a certain game setup.
    # and is bound to that.
    # multiple games can share the same game setup
    
    #TODO: a strategy should be a "bundle" with action set etc.

    action_set = ActionSet([
        CALL,
        FOLD,
        ALL,
        CHECK,
        Action(RAISE_ID, 0.5, 2),
        Action(RAISE_ID, 0.75, 3),
        Action(RAISE_ID, 1, 4),
        Action(BET_ID, 0.5, 2),
        Action(BET_ID, 0.75, 3),
        Action(BET_ID, 1, 4)]
    )

    game.actions = action_set

    main_player_position = players.position(main_player)

    #post blinds
    postblinds!(lgs, game)

    previous_action_id::UInt32 = 6
    previous_action_amount::UInt32 = 0

    #initialize main player cards and deck

    mp_private_cards = getplayercards(
        client, 
        players.id(main_player) - 1)

    private_cards[main_player_position] = mp_private_cards

    shared_data.private_cards = private_cards
    
    cards_deck = get_deck()
    
    #remove private cards from deck
    setdiff!(cards_deck, mp_private_cards)

    shared_data.deck = shuffle!(cards_deck)

    # game loop.
    # note: loop breaks when the main player is eliminated or wins

    while true
        
        current_player = lgs.player

        if current_player == main_player
            #todo: choose an action from the action set then perform it
            act = action_set[sample(action_set, actionsmask(main_player))]

            perform!(
                act,
                lgs,
                main_player
            )

            PokerClients.PerformAction(client, toactiondata(act, lgs))
        else
            local opp_act::PokerClients.ActionData
            
            # loop until the action has changed

            while true
                opp_act = PokerClients.GetPlayerAction(client, PlayersData[cpl.position])
                
                if previous_action_id != opp_act.action_type
                    previous_action_id  = opp_act.action_type
                    previous_action_amount = opp_act.amount
                    break

                elseif previous_action_id == opp_act.action_type
                    if opp_act.amount != previous_action_amount
                        previous_action_id  = opp_act.action_type
                        previous_action_amount = opp_act.amount
                        break
                    end
                end
            end
            
            opp_action = fromactiondata(opp_act, lgs, current_player)

            if !(opp_action in action_set)
                #TODO: if the opponent action is not in the action set, start sub-game solving
                # with a limited time. (20 seconds for instance)
                
                #NOTE: we start from a copy if the live game state.

                println(
                    "Action", 
                    opp_action.pot_multiplier, 
                    opp_action.blind_multiplier, 
                    "Not in set")
            end

            perform!(
                opp_action,
                lgs,
                current_player)
        end

        state = update!(lgs, game)

        state_id = state.id

        #todo: in certain game modes, (sit and go) we can quit any time at the end of a game.
        #todo: we need to implement a special initialization step for games modes...
        
        #todo: if the state_id is ended, fetch private cards, then suffle

        if state_id == TERM_ID
            #todo: maybe wait for server input... and call IsReady
            break
        elseif state_id == ENDED
            # perform some initialization after the game ended
            # put back private cards in the deck,
            # fetch private cards from server
            # remove them from deck, shuffle
            # fetch private cards, then suffle
            
        end
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