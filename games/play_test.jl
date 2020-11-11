include("games/playing.jl")
include("games/cards.jl")

using Random

using .playing
using .cards

const DECK = get_deck()
const SETUP = setup(
    Simulation,
    SmallBlind(1.0),
    BigBlind(2.0),
    2, 5, 4, 4,
    [3,1,1],
    Float32(100))

const ACTS = ActionSet([
    CALL, FOLD, ALL, CHECK,
    Raise(0.5), Raise(0.75), Raise(1.0),
    Bet(1.0), Bet(2.0), Bet(3.0)])

# set players actions
for p in values(SETUP.players)
    p.actions = ACTS
end

function message(action::Check, game::Game)
    return string("Check")
end

function message(action::Raise, game::Game)
    return string("Raise ", action.amount * game.pot_size + game.last_bet)
end

function message(action::All, game::Game)
    return string("Play all ", chips(game))
end

function message(action::Fold, game::Game)
    return string("Fold")
end

function message(action::Call, game::Game)
    return string("Call ", amount(action, game, game.player))
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
        ps.chips = 100
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

function selectplayer(gm::Game)
    players_queue = values(setup(gm).players)
    println("Player selection ")
    i = selectplayer(sort(players_queue))
    println("You've chosen player ", i)

    for pl in players_queue
        if pl.id == i
            return pl
        end
    end
end

function availableactions!(game::Game, data::SharedData, stp::GameSetup, out::Array{Action})
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
    # todo provide a function for displaying actions names
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

function cont(g::Game, s::Terminated)
    if choice("New game ?") == true
        # shuffle and distribute cards
        start!(g, s)
        return true
    end
    return false
end

function cont(g::Game, s::Ended)
    # wait for player input (y/n)
    # update!(g, s)
    if choice("Continue ?") == true
        data = shared(g)
        shuffle!(data.deck)
        start!(g, s)
        return true
    end
    return false
end

function cont(g::Game, s::Started)
    # update!(g, state)
    return true
end

function play()
    if choice("Start game ?") == true
        SHARED = shared(SETUP, DECK)
        GAME = game(SETUP, SHARED, Full())

        shuffle!(DECK)
        #user player
        player = selectplayer(GAME)

        initplayersstate!(GAME)
        start!(GAME)

        while true
            pl = GAME.player
            if pl == player
                #display available actions and wait for user input
                println("Your Turn")
                println(
                    "Public cards: ",
                    pretty_print_cards(SHARED.public_cards),
                    " Private cards: ",
                    pretty_print_cards(privatecards(player, SHARED)),
                    " Pot: ",
                    GAME.pot_size)
                st = perform!(choose_action(GAME, setup(GAME).actions), GAME, pl)
            else
                act = sample(setup(GAME).actions, actionsmask(pl))
                println("Player", pl.id, ": ", message(act, GAME))
                st = perform!(act, GAME, pl)
            end
            # if it is not the players turn, perform random moves until it is
            # the users turn, display available actions, then wait for input
            if cont(GAME, update!(GAME, st)) == false
                break
            end
        end
        #display end game results
    end
end

play()
