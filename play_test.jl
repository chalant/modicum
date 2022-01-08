push!(LOAD_PATH, join([pwd(), "games"], "/"))
push!(LOAD_PATH, join([pwd(), "cards"], "/"))
push!(LOAD_PATH, join([pwd(), "evaluation"], "/"))

using Random

using playing
using players
using cards
using games
using actions

@inline function createplayerstate(player::Player, chips::Float32)
    ps = PlayerState()

    ps.chips = chips
    ps.bet = 0
    ps.active = true
    ps.player = player
    ps.total_bet = 0

    return ps
end

function creategamestate(stp::T) where T <: AbstractGame

    g = GameState{T}()
    g.state = INIT
    g.started = STARTED
    g.ended = ENDED
    g.game = stp

    return g
end

@inline function initialize(
    shared::SharedData,
    stp::Game{T, U},
    cards_deck::Vector{UInt64},
    action_set::ActionSet) where {T <: GameSetup, U <: GameMode}

    gs = creategamestate(stp)
    stp.actions = action_set

    num_players = numplayers!(gs)
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

        st.bet = 0
        st.pot = 0

    end

    gs.actions_mask = trues(length(actions!(gs)))

    #shuffle players
    shuffle!(states)

    stp.players = players_list
    stp.actions = action_set
    gs.players_states = states
    gs.total_bet = 0

    gs.active_players = numplayers!(gs)
    gs.state = STARTED

    shared.private_cards = private_cards
    shared.deck = cards_deck
    shared.updates = Vector{Bool}([false for _ in 1:numrounds!(gs)])
    shared.public_cards = Vector{UInt64}()
    shared.deck_cursor = length(cards_deck)

    stp.shared_state = shared

    return gs

end

const DECK = get_deck()

const ACTS = ActionSet([
    CALL,
    FOLD,
    ALL,
    CHECK,
    Action(RAISE_ID, 0.5, 2),
    Action(RAISE_ID, 0.75, 3),
    Action(RAISE_ID, 1.0, 4),
    Action(BET_ID, 0.5, 2),
    Action(BET_ID, 0.75, 3),
    Action(BET_ID, 1.0, 4)])

function setup!(
    gm::T,
    sb::Float32,
    bb::Float32,
    shr::SharedData,
    num_private_cards::Int,
    num_public_cards::Int,
    num_rounds::Int,
    cards_per_round::Vector{UInt8},
    chips::Float32=1000) where T <: GameMode

    stp = Game{Simulation, T}()

    shr.sb = sb
    shr.bb = bb

    stp.num_private_cards = num_private_cards
    stp.num_public_cards = num_public_cards
    stp.num_rounds = num_rounds
    stp.chips = chips
    stp.cards_per_round = cards_per_round

    stp.game_mode = gm

    return stp
end

const SHARED = SharedData()

const SETUP = setup!(
    HeadsUp(),
    Float32(15.0),
    Float32(30.0),
    SHARED,
    2, 5, 4,
    [UInt8(3), UInt8(1), UInt8(1)],
    Float32(1000))

const GAMESTATE = initialize(SHARED, SETUP, DECK, ACTS)

@inline function message(action::Action, gs::GameState)
    id = action.id

    if id == CHECK_ID
        return string("Check")
    elseif id == RAISE_ID
        return string("Raise ", betamount(action, gs))
    elseif id == ALL_ID
        return string("Play all ", chips(gs))
    elseif id == FOLD_ID
        return string("Fold")
    elseif id == CALL_ID
        return string("Call ", callamount(gs, gs.player))
    elseif id == BET_ID
        return string("Bet ", betamount(action, gs))
    end
end

function Base.println(action::Action, gs::GameState)
    println(message(action, gs))
end

function Base.print(action::Action, gs::GameState)
    print(message(action, gs))
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

@inline function selectplayer(g::Game)
    players_queue = g.players

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

@inline function availableactions!(gs::GameState)
    
    actions_mask = actionsmask!(gs)
    actions = actions!(gs)

    out = Vector{String}()

    for i in 1:length(actions_mask)
        if actions_mask[i] != 0
            push!(
                out,
                message(actions[i], gs))
        end
    end

    return out
end

@inline function choose_action(gs::GameState, actions::ActionSet)
    # todo provide a function for displaying actions names
    println("Choose action ")

    #display available actions
    for (i, (act, j)) in enumerate(zip(actions!(gs), gs.actions_mask))
        if j == 1
            println("Press ", i, " to ", message(act, gs))
        end
    end

    try
        i = parse(Int, readline())
        if i > length(actions) || i < 1
            println("Invalid input ")
            return choose_action(gs, actions)
        else
            return i
        end
    catch
        println("Invalid input")
        return choose_action(gs, actions)
    end
end

# function cont(g::Game, s::Terminated)
#     if choice("New game ?") == true
#         # shuffle and distribute cards
#         start!(RUN_MODE, g, s)
#         return true
#     end
#     return false
# end

function cont(g::GameState, st::State)
    # update!(g, state)
    id = st.id

    if id == STARTED_ID
        return true
    elseif id == ENDED_ID
        if choice("Continue ?") == true
            data = shared(g)
            stp = game!(g)
            putbackcards!(g, stp, data)
            shuffle!(data.deck)
            activateplayers!(g)
            distributecards!(g, stp, data)
            start!(g)
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
        println("Dealer: ", players.id(last(playersstates!(GAMESTATE))))
        #user player
        player = selectplayer(GAMESTATE.game)

        distributecards!(GAMESTATE, SETUP, SHARED)
        start!(GAMESTATE)

        while true
            pl = GAMESTATE.player
            actions = SETUP.actions

            if pl == player
                #display available actions and wait for user input
                println("Your Turn")
                println(
                    "Public cards: ",
                    pretty_print_cards(SHARED.public_cards),
                    " Private cards: ",
                    pretty_print_cards(privatecards(player, SHARED)),
                    " Pot: ", GAMESTATE.pot_size)

                idx = choose_action(GAMESTATE, SETUP.actions)
                st = perform!(actions[idx], GAMESTATE, pl)
                pl.action = idx
            else
                # println(availableactions!(GAMESTATE))
                
                idx = sample(actionsmask!(GAMESTATE))
                act = actions[idx]
                
                println("Player", players.id(pl), ": ", message(act, GAMESTATE))
                
                st = perform!(act, GAMESTATE, pl)
                pl.action = act.id
            end

            # if it is not the players turn, perform random moves until it is
            # the users turn, display available actions, then wait for input

            if cont(GAMESTATE, update!(GAMESTATE, SETUP)) == false
                break
            end
        end
        #display end game results
    end
end

play()
