include("games/playing.jl")
include("games/cards.jl")

using Random

using .playing
using .cards

@inline function createplayerstate(player::Player, chips::Float32)
    ps = PlayerState()

    ps.chips = chips
    ps.bet = 0
    ps.active = true
    ps.player = player
    ps.total_bet = 0

    return ps
end

@inline function initialize(
    game::Game,
    shared::SharedData,
    stp::GameSetup,
    cards_deck::Vector{UInt64},
    action_set::ActionSet)

    num_players = stp.num_players
    chips = stp.chips

    players_list = Vector{Player}(undef, num_players)
    states = Vector{PlayerState}(undef, num_players)
    private_cards = Vector{Vector{UInt64}}(undef, num_players)

    for p in 1:num_players
        ply = Player(p, p)
        st = createplayerstate(ply, chips)
        players_list[p] = ply
        states[p] = st
        st.rank = Int16(7463)
        private_cards[p] = Vector{UInt64}()
    end

    stp.players = players_list
    stp.actions = action_set
    game.players_states = states
    game.total_bet = 0

    shared.private_cards = private_cards
    shared.deck = cards_deck
    shared.updates = Vector{Bool}([false for _ in 1:stp.num_rounds])
    shared.public_cards = Vector{UInt64}()
    shared.deck_cursor = length(cards_deck)
end

const DECK = get_deck()

const ACTS = ActionSet([
    CALL, FOLD, ALL, CHECK,
    Action(RAISE_ID, 0.5), Action(RAISE_ID, 0.75), Action(RAISE_ID, 1.0),
    Action(BET_ID, 1.0), Action(BET_ID, 2.0), Action(BET_ID, 3.0)])

sort!(ACTS)

const SETUP = setup(
    Simulation,
    Action(SB_ID, 1.0),
    Action(BB_ID, 2.0),
    2, 5, HeadsUp(), 4,
    [UInt8(3), UInt8(1), UInt8(1)],
    Float32(1000))

const SHARED = SharedData()
const RUN_MODE = Simulation
const GAME = creategame(SHARED, SETUP, Full())

#intialize game
initialize(GAME, SHARED, SETUP, DECK, ACTS)

@inline function message(action::Action, game::Game)
    id = action.id

    if id == CHECK_ID
        return string("Check")
    elseif id == RAISE_ID
        return string("Raise ", action.amount * game.pot_size + game.last_bet)
    elseif id == ALL_ID
        return string("Play all ", chips(game))
    elseif id == FOLD_ID
        return string("Fold")
    elseif id == CALL_ID
        return string("Call ", callamount(game, game.player))
    elseif id == BET_ID
        return string("Bet ", action.amount * bigblind(game.setup).amount)
    end
end

function Base.println(action::Action, game::Game)
    println(message(action, game))
end

function Base.print(action::Action, game::Game)
    print(message(action, game))
end

function choice(message::AbstractString)
    println(message, " (y/n)")

    r = readline()

    if r == "y"
        return true
    elseif r == "n"
        return false
    else
        println("Invalid choice, press y to continue or n to stop")
        return choice(message)
    end
end

@inline function selectplayer(choices::Vector{Int})
    println("Select any number ", choices)

    try
        return parse(Int, readline())
    catch
        println("Invalid Input ")
        return selectplayer(choices)
    end
end

@inline function selectplayer(gm::Game)
    players_queue = setup(gm).players

    println("Player selection ")

    ids = Vector{Int}(undef, length(players_queue))

    i = 1

    for player in players_queue
        ids[i] = player.id
        i += 1
    end

    i = selectplayer(sort(ids))

    println("You've chosen player ", i)

    for pl in players_queue
        if pl.id == i
            return pl
        end
    end
end

@inline function availableactions!(game::Game, data::SharedData, stp::GameSetup, out::Array{Action})
    actions_mask = data.actions_mask
    acts = stp.actions

    for i in 1:length(acts)
        a = actions_mask[i]
        if a == 1
            out[i] = acts[i]
        end
    end
    return arr
end

@inline function choose_action(game::Game, actions::ActionSet)
    # todo provide a function for displaying actions names
    println("Choose action ")
    ply = playerstate(game)

    #display available actions
    for (i, (act, j)) in enumerate(zip(viewactions(game), ply.actions_mask))
        if j == 1
            println("Press ", i, " to ", message(act, game))
        end
    end

    try
        i = parse(Int, readline())
        if i > length(actions) || i < 1
            println("Invalid input ")
            return choose_action(game, actions)
        else
            return i
        end
    catch
        println("Invalid input")
        return choose_action(game, actions)
    end
end

function random_action(game::Game)
    return sample(viewactions(game), game.actions_mask)
end

# function cont(g::Game, s::Terminated)
#     if choice("New game ?") == true
#         # shuffle and distribute cards
#         start!(RUN_MODE, g, s)
#         return true
#     end
#     return false
# end

function cont(g::Game, st::State)
    # update!(g, state)
    id = st.id

    if id == STARTED_ID
        return true
    elseif id == ENDED_ID
        if choice("Continue ?") == true
            data = shared(g)
            stp = setup(g)
            putbackcards!(RUN_MODE, g, stp, data)
            shuffle!(data.deck)
            activateplayers!(g, stp)
            distributecards!(RUN_MODE, g, stp, data)
            start!(RUN_MODE, g)
            return true
        end
        return false

    elseif id == TERM_ID
        println("Game Over!")
        return false
    else
        return false
    end
end

function play()
    if choice("Start game ?") == true
        shuffle!(DECK)
        #user player
        player = selectplayer(GAME)

        initialize!(RUN_MODE, GAME, SHARED, SETUP)
        distributecards!(RUN_MODE, GAME, SETUP, SHARED)
        start!(RUN_MODE, GAME)

        while true
            pl = GAME.player
            actions = setup(GAME).actions

            if pl == player
                #display available actions and wait for user input
                println("Your Turn")
                println(
                    "Public cards: ",
                    pretty_print_cards(SHARED.public_cards),
                    " Private cards: ",
                    pretty_print_cards(privatecards(player, SHARED)),
                    " Pot: ", GAME.pot_size)
                idx = choose_action(GAME, setup(GAME).actions)
                st = perform!(actions[idx], GAME, pl)
            else
                # opponents turn
                idx = sample(setup(GAME).actions, actionsmask(pl))
                act = actions[idx]
                println("Player", id(pl), ": ", message(act, GAME))
                st = perform!(act, GAME, pl)
                pl.action = idx
            end

            pl.action = idx

            # if it is not the players turn, perform random moves until it is
            # the users turn, display available actions, then wait for input

            if cont(GAME, update!(GAME)) == false
                break
            end
        end
        #display end game results
    end
end

play()
