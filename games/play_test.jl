include("../games/playing.jl")
include("../games/cards.jl")

using Random

using .playing
using .cards

const DECK = get_deck()
const SETUP = setup(
    SmallBlind(1.0),
    BigBlind(2.0),
    [CALL, FOLD, ALL, CHECK,
    Raise(0.5), Raise(0.75), Raise(1.0),
    Bet(1.0), Bet(2.0), Bet(3.0)],
    2, 5, 4, 4)

function message(action::Check, game::Game)
    return string("Check")
end

function message(action::Raise, game::Game)
    return string("Raise ", action.amount * game.pot_size + game.last_bet)
end

function message(action::All, game::Game)
    return string("Play all ", state(game.player, game.players_states).chips)
end

function message(action::Fold, game::Game)
    return string("Fold")
end

function message(action::Call, game::Game)
    return string(
        "Call ",
        amount(action, game, state(game.player, game.players_states)))
end

function message(action::Bet, game::Game)
    string("Bet ", action.amount * bigblind(game.setup).amount)
end

function Base.println(action::Action, game::Game)
    println(message(action, game))
end

function Base.print(action::Action, game::Game)
    print(message(action))
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

function initplayersstate!(game::Game)
    for ps in game.players_states
        ps.chips = 1000
    end
end

function selectplayer(choices::Vector{Int})
    println("Select any number ", choices)
    try
        return parse(Int, readline())
    catch
        println("Invalid Input ")
        return selectplayer(choices)
    end
end

function selectplayer(game::Game)
    # display players
    # wait for user input
    players_queue = shared(game).players_queue
    println("Player selection ")
    i = selectplayer(sort([pl.id for pl in players_queue]))
    println("You've chosen player ", i)

    for pl in players_queue
        if pl.id == i
            return pl
        end
    end
end

function availableactions!(game::Game, data::SharedData, stp::GameSetup, out::Array{playing.Action})
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

function choose_action(game::Game, actions::Tuple{Vararg{Action}})
    #provide a function for displaying actions names
    println("Choose action ")
    #display available actions
    for (i, (act, j)) in enumerate(zip(viewactions(game), game.actions_mask))
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
            return actions[i]
        end
    catch
        println("Invalid input")
        return choose_action(game, actions)
    end
end

function random_action(game::Game)
    return sample(viewactions(game), game.actions_mask)
end

function turn(g::Game, state::Ended)
    # wait for player input (yes/no)
    if choice("Continue ?") == true
        update!(g, state)
        start!(g)
    else
        return false
    end
end

function turn(g::Game, state::Started)
    # update!(g, state)
    return true
end

function play()
    if choice("Start game ?") == true
        SHARED = shared(SETUP, DECK)
        GAME = game(SETUP, SHARED)

        shuffle!(DECK)
        shuffle!(SHARED.players_queue)

        #user player
        player = selectplayer(GAME)

        initplayersstate!(GAME)
        start!(GAME)

        println("Players order: ", SHARED.players_queue)
        println("Dealer: ", last(SHARED.players_queue))

        while true
            pl = GAME.player
            if pl == player
                #display available actions and wait for user input
                println("Your Turn")
                println(
                    "Public cards: ", pretty_print_cards(SHARED.public_cards),
                    "Private cards: ", pretty_print_cards(privatecards(player, SHARED)),
                    "Pot: ", GAME.pot_size)
                st = perform!(
                        choose_action(GAME, setup(GAME).actions),
                        GAME,
                        state(pl, GAME.players_states))
            else
                act = sample(setup(GAME).actions, GAME.actions_mask)
                println("Player ", pl, ": ", message(act, GAME))
                st = perform!(act, GAME, state(pl, GAME.players_states))
            end
            # if it is not the players turn, perform random moves until it is
            # the users turn, display available actions, then wait for input
            GAME.state = st
            if turn(GAME, st) == false
                break
            end
        end
        #display end game results
    end
end

play()
