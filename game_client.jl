include("glog/poker.jl")

include("games/playing.jl")
include("games/cards.jl")
include("games/games.jl")

using .cards
using .playing
using .poker
using .games

const PlayersData = Vector{PlayerData}()

struct Live <: RunMode
    client::PokerServiceClient
end

@inline function postblinds!(g::Game{Live}, stp::GameSetup{HeadsUp})
        client = getclient!(g.run_mode)

        sb = g.players_states[1]
        bb = g.players_states[2]

        stp.sb = GetBlinds(client, PlayersData[sb.position])
        stp.bb = GetBlinds(client, PlayersData[bb.position])

        _headsupblinds!(g, stp)
end

@inline function getclient!(run_mode::Live)
    return run_mode.client
end

@inline function setpubliccards!(g::Game{Live}, data::SharedData)
        client = getclient!(g.run_mode)
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
    small_blind::UInt32,
    big_blind::UInt32)

    client = PokerServiceClient(server_url)

    live_game = Game{Live}()

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
        append!(PlayersData, player)

        pos = player.position

        ply = Player(pos, pos)
        st = PlayerState()

        if pos == 0
            main_player = ply
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

    cards_data = GetPlayerCards(
        client,
        PlayerData(position=UInt32(main_player.position)))

    #todo: convert cards to local data structure
    private_cards[main_player] = cards_data

    #post blinds
    postblinds!(g, game_setup)

    # game loop.
    # note: loop breaks when the main player is eliminated or wins

    while true
        current_player = live_game.player

        if current_player == main_player
            #todo: choose an action from the action set them perform it
            perform!()
            #todo: need a function for performing action on the server
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
