push!(LOAD_PATH, join([pwd(), "games"], "/"))
push!(LOAD_PATH, join([pwd(), "glog"], "/"))

include("data_conversion.jl")
include("poker.jl")

using Games
using cards
using playing

using .poker
using .data_conversion

const PlayersData = Vector{PlayerData}()

struct LiveGame{T<:GameMode} <: GameSetup
    client::PokerServiceClient
    mode::T
end

@inline function postblinds!(gs::GameState, g::Game{LiveGame, U}) where U <: GameMode
    client = getclient!(setup(gs))

    data = shared(gs)

    sb = g.players_states[1]
    bb = g.players_states[2]

    data.sb = GetBlinds(client, PlayersData[sb.position])
    data.bb = GetBlinds(client, PlayersData[bb.position])

    _postblinds!(gs)
end

@inline function getclient!(run_mode::Live)
    return run_mode.client
end

@inline function setpubliccards!(g::Game{LiveGame}, data::SharedData)
        client = getclient!(g.game_setup)
        round = g.round

        if round == 1
            round_request = Round.FLOP
        elseif round == 2
            round_request = Round.TURN
        elseif round == 3
            round_request = Round.RIVER
        end

        board_cards = GetBoardCards(client, BoardCardsRequest(round=round_request))

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
        if pl.position == last_position
            break
        end

        idx += 1
    end

    for i in 1:length(pls) - idx
        pushfirst!(pls, pop!(pls))
    end

end

function creategamesetup!(v::Val{false})
    game_setup = GameSetup{HeadsUp}()
    game_mode = HeadsUp()

    game_setup.game_mode = game_mode
    game_setup.num_players = game_mode.num_players

    return game_setup

end

function creategamesetup!(v::Val{true})
    game_setup = GameSetup{Normal}()
    game_mode = Normal()

    game_setup.game_mode = game_mode
    game_setup.num_players = game_mode.num_players

    return game_setup

end

function start(
    server_url::String,
    chips::UInt32,
    num_players::UInt8,
    small_blind::Float32,
    big_blind::Float32)

    client = PokerServiceClient(server_url)

    live_game = Game{LiveGame}()

    live_game.run_mode = Live(client)

    shared_data = SharedData()

    #todo: should we include small blind data variation in the simulation?
    # it is either time based or round based? (maybe each 4 or 5 rounds?)

    #todo: action set should also be provided when we launch the game (note should
    # correspond to the one we trained with)

    #setup the game.

    game_setup = creategamesetup!(num_players > 2)

    #small blind and big blind are provided in the parameters

    game_setup.sb = small_blind
    game_setup.bb = big_blind

    game_setup.num_private_cards = 2
    game_setup.num_public_cards = 5
    game_setup.num_rounds = 4
    game_setup.chips = chips

    game_setup.cards_per_round = Vector{UInt8}([UInt8(3), UInt8(1), UInt8(1)])

    #todo: make a request to the server to know if we can start playing
    IsReady(client, Empty())

    dealer = GetDealer(client, Empty())

    players_vec = Vector{Player}(undef, num_players)
    players_states = Vector{PlayerState}(undef, num_players)
    private_cards = Vector{Vector{UInt64}}(undef, num_players)

    active_players = 0

    for player in 1:GetPlayers(client)
        push!(PlayersData, player)

        pos = player.position

        ply = Player(pos, pos)
        st = PlayerState()

        if pos == 0
            main_player = st
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

    #re-order players such that the dealer is last
    putlast!(states, UInt8(dealer.position))

    game_setup.players = players_vec
    game_setup.players_states = players_states

    live_game.total_bet = 0
    live_game.active_players = active_players

    shared_data.private_cards = private_cards

    #todo: need an action set (which should be the same as the blueprint model)
    # otherwise the performance would probably not be the same.

    # note: ideally, a blueprint strategy is trained against a certain game setup.
    # and is bound to that.
    # multiple games can share the same game setup

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

    sort!(action_set)

    game_setup.actions = action_set

    main_player_position = position(main_player)

    private_cards[main_player_position] = fromcardsdata(
        GetPlayerCards(
            client,
            PlayerData(position=UInt32(main_player_position))))

    #post blinds
    postblinds!(g, game_setup)

    # game loop.
    # note: loop breaks when the main player is eliminated or wins

    while true
        current_player = live_game.player

        if current_player == main_player
            #todo: choose an action from the action set them perform it
            act = action_set[sample(action_set, actionsmask(main_player))]

            perform!(
                act,
                live_game,
                main_player
            )

            PerformAction(client, toactiondata(act, live_game))
        else
            #wait for opponent to perform action
            opp_act = GetPlayerAction(client, PlayersData[cpl.position])
        end

        #todo: in certain game modes, (sit and go) we can quit any time at the end of a game.
        #todo: we need to implement a special initialization step fo

        game_state = update!(live_game, game_setup)

        state_id = game_state.id

        if state_id == TERM_ID
            break
        end

    end

end
