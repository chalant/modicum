module playing

export perform!
export start!
export sample
export amount
export initialize!
export putbackcards!
export distributecards!

include("games.jl")
include("evaluation/evaluator.jl")

using Reexport
using Random

using .evaluator

@reexport using .games

function amount(a::Call, g::Game, ps::PlayerState)
    b = g.last_bet - ps.bet
    return b >= 0 ? b : 0.0
end

amount(a::All, g::Game, ps::PlayerState) = ps.chips
amount(a::Bet, g::Game, ps::PlayerState) = bigblind(g.setup).amount * a.amount + g.last_bet
amount(a::Blind, g::Game, ps::PlayerState) = a.amount
amount(a::Raise, g::Game, ps::PlayerState) = g.pot_size * a.amount + g.last_bet

function bet!(a::All, g::Game, ps::PlayerState)
    #player might have less chips than the previous bet.
    amt = amount(a, g, ps)
    ps.bet += amt
    if g.last_bet > ps.bet
        lb = g.last_bet
    else
        lb = ps.bet
    end

    ps.chips -= amt
    g.pot_size += amt
    g.last_bet = lb
    ps.pot = g.pot_size
end

function bet!(amt::AbstractFloat, game::Game, ps::PlayerState)
    ps.chips -= amt
    ps.bet += amt
    game.pot_size += amt
    game.last_bet = ps.bet
    ps.pot = game.pot_size
end

bet!(a::AbstractBet, g::Game, ps::PlayerState) = bet!(amount(a, g, ps), g, ps)

_nextround!(g::Game, ps::PlayerState) = _nextround!(g, setup(g), ps)

function _nextround!(g::Game, stp::GameSetup, ps::PlayerState)
    # all players went all-in or checked
    g.round += 1
    if g.round < limit(g, stp)
        #store cumulative all-in, reset relative all-in
        g.all_in += g.r_all_in
        g.r_all_in = 0
        return perform!(CHANCE, g, ps)
    else
        st = g.ended
        g.state = st
        return st
    end
end

function update!(g::Game, action::Action, ps::PlayerState)
    ap = g.active_players
    all_in = g.all_in

    #avoid infinit loop when all players went all-in
    if g.active_players != g.r_all_in + g.all_in
        lp = position(ps)
        ps = nextplayer(g)
        #update actions for next player
        g.num_actions = update!(action, g, ps)
        g.player = ps
        st = g.started
        g.state = st

        if g.round == 0 && lp >= ap - all_in && g.turn == false
            # previous player was last =>
            # mark first turn of pre-flop as complete
            g.turn = true
        end

        return st
    else
        return _nextround!(g, ps)
    end
end

update!(g::Game, gs::GameState) = g.state

function _nlastround!(g::Game, gs::Ended, stp::GameSetup)
    # game did not go to the last round => all except one player
    # have folded

    #give all the chips to the only active player
    for ps in g.players_states
        if ps.active == true
            amt = ps.pot
            ps.chips += amt
            g.pot_size -= amt
            println("Winner! ", id(ps), " Amount ", amt)
        end
        ps.pot = 0
    end

    bb = bigblind(stp).amount
    n = stp.num_players

    # count remaining players
    for ps in g.players_states
        if ps.chips < bb
            n -= 1
        end
    end

    if n != 1
        g.state = g.ended
    else
        #game terminates when only one player remains
        g.state = g.terminated
    end
    return g.state
end

function _lastround!(g::Game, gs::Ended, stp::GameSetup)
    #called when the game has reached the last round
    data = shared(g)

    best_rk = MAX_RANK + 1

    #evaluate players hand ranks
    for ps in g.players_states
        if ps.active == true
            rank = evaluate(data.private_cards[id(ps)], data.public_cards)
            ps.rank = rank
            if rank < best_rk
                best_rk = rank
            end
        end
    end

    # count number of winners
    w = 0
    for ps in g.players_states
        if ps.rank == best_rk
            w += 1
        end
    end

    wn = 0
    #distribute earnings to the winners
    for ps in g.players_states
        if ps.active == true && ps.rank == best_rk
            amt = ps.pot/w
            ps.chips += amt
            g.pot_size -= amt
            wn += 1

            println("Winner! ", id(ps), " Amount ", amt)

            if w == wn
                break
            end

        end
        ps.pot = 0
    end

    stp = setup(g)
    bb = bigblind(stp).amount
    n = stp.num_players

    # distribute unclaimed chips to active (not folded) players equally
    # and count remaining players
    for ps in g.players_states
        if ps.active == true
            ps.chips += g.pot_size / g.active_players
        end
        if ps.chips < bb
            n -= 1
        end
    end

    if n != 1
        g.state = g.ended
    else
        #game terminates when only one player remains
        g.state = g.terminated
    end
    return g.state
end

function update!(g::Game, gs::Ended)::GameState

    stp = setup(g)
    if g.round >= stp.num_rounds
        # game has reached the last round
        return _lastround!(g, gs, stp)
    else
        # all players except one have folded
        return _nlastround!(g, gs, stp)
    end
end

function perform!(a::Chance, g::Game{Full, U}, ps::PlayerState) where U <: GameMode
    data = shared(g)
    round = g.round
    #update once per round
    updates = data.updates

#     println("Active Players!!! ", [id(player) for player in g.players_states if player.active == true])

    println("Cards Per Round ", length(data.deck))

    if !updates[round]
        for i in 1:setup(g).cards_per_round[round]
            append!(data.public_cards, pop!(data.deck))
            data.deck_cursor -= 1
        end
        #next player will be player 1
        # g.position = setup(g).num_players
        updates[round] = true

        #reset all bets
        for ps in g.players_states
            ps.bet = 0
        end

        #reset last bet
        g.last_bet = 0
    end

    ap = g.active_players
    all_in = g.all_in

    if ap - all_in == 1 || g.r_all_in + all_in == ap
        # all players have played (all-in or call) or all went all-in
        return _nextround!(g, ps)
    end
    #update available actions
    return update!(g, a, ps)
end

perform!(a::Action, g::Game, ps::PlayerState) = update!(g, a, ps)

function perform!(a::AbstractBet, g::Game, ps::PlayerState)
    bet!(a, g, ps)
    return update!(g, a, ps)
end

function perform!(a::All, g::Game, ps::PlayerState)
    bet!(a, g, ps)
    # add all-in players
    g.r_all_in += 1
    if g.active_players <= g.r_all_in + g.all_in
        # all players went all-in, move to the next round
        return _nextround!(g, ps)
    end
    return update!(g, a, ps)
end

function perform!(a::Check, g::Game, ps::PlayerState)
    #move to chance if we haven't reached the last round
    # if it is the last player that checks => move to next round
    if ps.position >= g.active_players - (g.all_in + g.r_all_in)
        # if the last player checks, move to next round
        return _nextround!(g, ps)
    end
    return update!(g, a, ps)
end

function perform!(a::Fold, g::Game, ps::PlayerState)
    ps.active = false
    g.active_players -= 1
    stp = setup(g)

     # if only one player remains the game ends

    if g.active_players == 1
        st = g.ended
        g.state = st
        return st
    end

    # drop relative position by one
    for p in g.players_states
        if p.position > ps.position
            p.position -= 1
        end
    end

    if g.active_players - g.all_in == 1
        # some players might have went all_in the previous round.
        return _nextround!(g, ps)
    end

    return update!(g, a, ps)
end

function perform!(a::Call, g::Game, ps::PlayerState)
    bet!(a, g, ps)
    d = g.active_players - g.all_in

    if d - g.r_all_in == 1
        # if it is the last player to call and all the other players went all-in
        # consider it as an all-in
        g.r_all_in += 1
        return _nextround!(g, ps)

    elseif g.turn == true && ps.position >= d
        # small blind has played and last player to call
        return _nextround!(g, ps)
    end

    return update!(g, a, ps)
end

function _nextplayer(g::Game, n::Int)
    g.position == n ? g.position = 1 : g.position += 1
    # get the state with the corresponding position
    # players are arranged by position
    return g.players_states[g.position]
end

function nextplayer(g::Game)
    stp = setup(g)
    n = stp.num_players
    st = _nextplayer(g, n)

    while !st.active || st.chips == 0
        st = _nextplayer(g, n)
    end

    return st
end

start!(g::Game) = start!(g, g.state)
start!(g::Game, gs::Started) = start!(g, shared(g))

function start!(g::Game, s::Terminated)
    data = shared(g)
    stp = setup(g)
    states = g.players_states

    #re-initialize players states
    for st in states
        p = st.position
        #shift player position by one place to the right
        if p == stp.num_players
            st.position = 1
        else
            st.position += 1
        end
        st.chips = stp.chips # reset chips
        st.active = true
        st.bet = 0
    end
    #set the number of active players
    g.active_players = stp.num_players

    start!(g, shared(g))
end

function start!(g::Game, s::Ended)
    stp = setup(g)
    states = g.players_states
    bb = bigblind(stp).amount

    a = 0
    #re-initialize players states
    for st in states
        p = st.position
        #shift player position by one place to the right
        if p == stp.num_players
            st.position = 1
        else
            st.position += 1
        end
        #set player with enough chips to active
        if st.chips < bb
            st.active = false
        else
            st.active = true
            a += 1
        end
        st.bet = 0
        st.pot = 0
    end

    if a != 1
        #set the number of active players

        g.active_players = a
        pushfirst!(g.players_states, pop!(g.players_states))

        # set relative positions
        i = 1
        for st in states
           if st.active == true
               st.position = i
           end
           i += 1
        end
        return start!(g, shared(g))
    else
        #game terminates if there is only one player left
        st = g.terminated
        g.state = st
        return st
    end
end

function start!(g::Game, st::Initializing)
    error("Cannot start an unnitialized game!")
end

function initialize!(
    g::Game{T, Simulation},
    data::SharedData{T, Simulation},
    stp::GameSetup{Simulation}) where T <: GameType

    #initialization function for simulations
    stp = setup(g)

    #initialize players states
    i = 1
    for st in g.players_states
        st.bet = 0
        st.pot = 0
        st.actions_mask = trues(length(stp.actions))
        i += 1
    end

#     function position(ps::PlayerState)
#         return position(ps.player)
#     end
#
#     #order states by position
#     sort!(states, by=position)
    g.active_players = stp.num_players
    #create actions_mask array
    return start!(g, shared(g))
end

function distributecards!(
    g::Game{T, LiveSimulation},
    stp::GameSetup{LiveSimulation},
    data::SharedData{T, LiveSimulation}) where T <: GameType

    deck = data.deck

    #distribute private cards
    main = stp.main_player
    for i in 1:stp.num_private_cards
        for state in g.players_states
            #only distribute to opponents and active players
            if main != state && state.active == true
                privatecards(state, data)[i] = pop!(deck)
            end
        end
    end
end

function distributecards!(
    g::Game{T, Simulation},
    stp::GameSetup{Simulation},
    data::SharedData{T, Simulation}) where T <: GameType

    deck = data.deck
    #distribute private cards
    for i in 1:stp.num_private_cards
        for state in g.players_states
            if state.active == true
                privatecards(state, data)[i] = pop!(deck)
            end
        end
    end
end

function putbackcards!(
    g::Game{T, LiveSimulation},
    stp::GameSetup{LiveSimulation},
    data::SharedData{T, LiveSimulation}) where T <: GameType

    main = stp.main_player
    for state in g.players_states
        #only distribute to opponents and active players
        if main != state && state.active == true
            append!(deck, privatecards(state, data))
        end
    end
    #remove public cards up until the relative root game round
    n = stp.card_per_round[g.round] - stp.cards_per_round[data.round]
    for i in 1:n
        push!(data.deck, pop!(data.public_cards))
    end
end

function putbackcards!(
    g::Game{T, Simulation},
    stp::GameSetup{Simulation},
    data::SharedData{T, Simulation}) where T <: GameType

    for state in g.players_states
        if state.active == true
            pvt_cards = privatecards(state, data)
            append!(data.deck, pvt_cards)
        end
    end

    append!(data.deck, data.public_cards)
    empty!(data.public_cards)
end

function start!(
    g::Game{T, LiveSimulation},
    data::SharedData{T, LiveSimulation}) where T <: GameType

    deck = data.deck
    n = length(deck)
    stp = setup(g)

    states = g.players_states

    #reset tracker array
    updates = data.updates
    for i in 1:length(updates)
        updates[i] = false
    end
    # reset data from last root game
    copy!(g, game(dg), data, stp)
    return g.state
end

function start!(
    g::Game{T, Simulation},
    data::SharedData{T, Simulation}) where T <: GameType

    stp = setup(g)
    distributecards!(g, stp, data)

    g.state = g.started
    g.round = 0
    g.last_bet = 0
    g.pot_size = 0
    g.num_actions = length(stp.actions)
    g.position = 0
    g.all_in = 0
    g.r_all_in = 0
    g.turn = false #reset smallblind flag

    updates = data.updates

    for i in 1:length(updates)
        updates[i] = false
    end

    #get next available player from position 0
    st = nextplayer(g)

    if stp.num_players == 2
        #first player posts the bigblind
        perform!(stp.bb, g, st)
        perform!(stp.sb, g, g.player)
        # next player to play will be the dealer
        g.position = 1
    else
        perform!(stp.sb, g, st)
        perform!(stp.bb, g, g.player)
    end

    return g.state
end

function sample(a::ActionSet, wv::Vector{Bool})
    n = length(wv)
    t = rand()
    i = 1
    cw = 0

    #count active actions (could use game.num_actions instead)
    c = 0
    for j in 1:n
        if @inbounds wv[j] == 1
            c += 1
        end
    end

    while i < n + 1
        @inbounds cw += wv[i]/c
        if t < cw
            break
        end
        i += 1
    end
    return a.actions[i]
end

function _activate(act::AbstractBet, g::Game, ps::PlayerState)
    amt = amount(act, g, ps)

    if amt > ps.chips || amt == 0
        return 0
    end

    return 1
end

function _activate(a::All, g::Game, ps::PlayerState)
    if ps.chips != 0
        return 1
    end
    return 0
end

function _activate(a::Check, g::Game, ps::PlayerState)
    if ps.bet == g.last_bet
        return 1
    end
    return 0
end

function _activate(action::Action, g::Game, ps::PlayerState)
    return 1
end

function _activate(a::Fold, g::Game, ps::PlayerState)
    #the player can't fold if he's all-in
    if ps.bet > 0 && ps.chips == 0
        return 0
    end
    return 1
end

function _activate(a::Call, g::Game, ps::PlayerState)
    if ps.chips <= g.last_bet
        return 0
    elseif ps.bet == g.last_bet
        return 0
    end
    return 1
end

function _update!(
    acts::ActionSet,
    ids::Vector{UInt8},
    g::Game{T,U},
    ps::PlayerState) where {T<:GameType, U<:GameMode}

    actions_mask = ps.actions_mask
    sort!(acts) # lazy sort
    iid = 1
    ia = 1
    l = length(ids)
    n = length(actions_mask)
    c = 0

    #disable all actions
    for i in 1:n
        actions_mask[i] = 0
    end

    while iid < l + 1
        id = ids[iid]
        a = acts[ia]

        #skip elements that are not in available actions
        while id != a.id && ia < n
            ia += 1
            a = acts[ia]
        end

        #activate actions
        while id == a.id && ia < n
            actions_mask[ia] = _activate(a, g, ps)
            c += 1
            ia += 1
            a = acts[ia]
        end

        iid += 1
    end

    #update last element
    a = acts[ia]
    if ids[l] == a.id
        actions_mask[ia] = _activate(a, g, ps)
        c += 1
    end

    return c
end

update!(action::Bet, g::Game, ps::PlayerState)=_update!(viewactions(g.setup), AFTER_BET, g, ps)
update!(action::All, g::Game, ps::PlayerState)= _update!(viewactions(g.setup), AFTER_ALL, g, ps)
update!(action::Call, g::Game, ps::PlayerState)=_update!(viewactions(g.setup), AFTER_CALL, g, ps)
update!(action::Fold, g::Game, ps::PlayerState)=_update!(viewactions(g.setup), AFTER_FOLD, g, ps)
update!(action::Raise, g::Game, ps::PlayerState)=_update!(viewactions(g.setup), AFTER_RAISE, g, ps)
update!(action::Check, g::Game, ps::PlayerState)=_update!(viewactions(g.setup), AFTER_CHECK, g, ps)
update!(action::Chance, g::Game, ps::PlayerState)=_update!(viewactions(g.setup), AFTER_CHANCE, g, ps)
update!(action::BigBlind, g::Game, ps::PlayerState)=_update!(viewactions(g.setup), AFTER_BB, g, ps)
update!(action::SmallBlind, g::Game, ps::PlayerState)=_update!(viewactions(g.setup), AFTER_SB, g, ps)

end