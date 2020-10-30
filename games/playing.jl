module playing

export perform!
export start!
export sample
export amount

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

function amount(a::Raise, g::Game, ps::PlayerState)
    return g.pot_size * a.amount + g.last_bet
end

function amount(a::All, g::Game, ps::PlayerState)
    return ps.chips
end

function amount(a::Bet, g::Game, ps::PlayerState)
    return bigblind(g.setup).amount * a.amount
end

function amount(a::Blind, g::Game, ps::PlayerState)
    return a.amount
end

@inline function bet!(a::All, g::Game, ps::PlayerState)
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

@inline function bet!(amt::AbstractFloat, game::Game, ps::PlayerState)
    ps.chips -= amt
    ps.bet += amt
    game.pot_size += amt
    game.last_bet = ps.bet
    ps.pot = game.pot_size
end

@inline function bet!(a::AbstractBet, g::Game, ps::PlayerState)
    #update chips size
    bet!(amount(a, g, ps), g, ps)
end

@inline function _nextround!(g::Game, ps::PlayerState)
    _nextround!(g, setup(g), ps)
end

@inline function _nextround!(g::Game, stp::GameSetup, ps::PlayerState)
    # all players went all-in or
    g.round += 1
    if g.round < stp.num_rounds
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
    if g.active_players != g.r_all_in + g.all_in
        ps = nextplayer(g)
        #update actions for next player
        g.num_actions = update!(action, g, ps)
        g.player = ps
        st = g.started
        g.state = st
        return st
    else
        return _nextround!(g, ps)
    end
end

function update!(g::Game, gs::GameState)::GameState
    return g.state
end

@inline function _nlastround!(g::Game, gs::Ended, stp::GameSetup)
    # game did not go to the last round => all except one player
    # have folded
    for ps in g.players_states
        if ps.active == true
            amt = ps.pot
            ps.chips += amt
            g.pot_size -= amt
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

@inline function _lastround!(g::Game, gs::Ended, stp::GameSetup)
    #called when the game has reached the last round
    data = shared(g)

    best_rk = MAX_RANK + 1

    #evaluate players hand ranks
    for ps in g.players_states
        if ps.active == true
            rank = evaluate(data.private_cards[ps.id], data.public_cards)
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

function perform!(a::Chance, g::Game, ps::PlayerState)
    data = shared(g)
    round = g.round
    #update once per round
    updates = data.updates
    if !updates[round]
        if round == 1
            for i in 1:3
                append!(data.public_cards, data.deck[g.deck_cursor])
                g.deck_cursor -= 1
            end
        else
            append!(data.public_cards, data.deck[g.deck_cursor])
            g.deck_cursor -= 1
        end
        #next player will be player 1
        g.position = setup(g).num_players
        updates[round] = true

        #reset all bets
        for ps in g.players_states
            ps.bet = 0
        end
    end
    if g.active_players == 1 || g.r_all_in + g.all_in == g.active_players
        # all players have played (all-in or call) or all except one have
        # folded
        return _nextround!(g, ps)
    end
    #update available actions
    return update!(g, a, ps)
end

function perform!(a::Action, g::Game, ps::PlayerState)
    return update!(g, a, ps)
end

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
    stp = setup(g)
    if ps.position >= g.active_players - g.all_in
        # if the last player checks, move to next round
        return _nextround!(g, stp, ps)
    end
    return update!(g, a, ps)
end

function perform!(a::Fold, g::Game, ps::PlayerState)
    # if only one player remains the game ends
    ps.active = false
    g.active_players -= 1
    stp = setup(g)
    if g.active_players - g.all_in == 1
        # some players might have went all_in the previous round.
        # => we compute the players that folded during this round
        return _nextround!(g, ps)
    end
    return update!(g, a, ps)
end

function perform!(a::Call, g::Game, ps::PlayerState)
    bet!(a, g, ps)
    stp = setup(g)
    if g.active_players - (g.all_in + g.r_all_in) == 1
        # if it is the last player to call and all the other players went all-in
        g.r_all_in += 1 #consider it as an all-in
        return _nextround!(g, ps)
    end
    return update!(g, a, ps)
end

@inline function _nextplayer(g::Game, n::Int)
    g.position == n ? g.position = 1 : g.position += 1
    # get the state with the corresponding position
    # players are arranged by position
    return g.players_states[g.position]
end

@inline function nextplayer(g::Game)
    stp = setup(g)
    n = stp.num_players
    st = _nextplayer(g, n)
    while !st.active || st.chips == 0
        st = _nextplayer(g, n)
    end
    return st
end

function start!(g::Game, s::Terminated)
    #reactivate all players
    data = shared(g)
    stp = setup(g)
    states = g.players_states

    a = 0
    #re-initialize players states
    for st in states
        p = st.position
        #shift player position by one place to the right
        if p == stp.num_players
            st.position = p
        else
            st.position += 1
        end
        #set player with enough chips to active
        st.chips = stp.chips
        st.active = true
        a += 1
        st.bet = 0
    end
    #set the number of active players
    g.active_players = a
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
            st.position = p
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
        return start!(g, shared(g))
    else
        #game terminates if there is only one player left
        st = g.terminated
        g.state = st
        return st
    end
end

function start!(game::Game)
    return start!(game, game.state)
end

function start!(g::Game, gs::Initializing)
    #called only once
    data = shared(g)
    stp = setup(g)

    shuffle!(data.deck)

    states = g.players_states
    shuffle!(states)
    println("Dealer ", last(states).id)
    println("Players Order ", [p.id for p in states])

    n = length(states)

    #initialize players states
    i = 1
    for st in states
        st.position = i
        st.bet = 0
        st.pot = 0
        i += 1
    end

    function position(ps::PlayerState)
        return ps.position
    end

    #order states by position
    sort!(states, by=position)
    g.active_players = stp.num_players
    #create actions_mask array
    g.actions_mask = BitArray(ones(Int, length(stp.actions)))
    return start!(g, data)

end

function start!(g::Game, gs::Started)
    return start!(g::Game, shared(data))
end

function start!(g::Game, data::SharedData)
    deck = data.deck
    n = length(deck)
    stp = setup(g)

    states = g.players_states

    #distribute private cards
    j = 0
    for i in 1:stp.num_private_cards
        for state in states
            privatecards(state, data)[i] = deck[n-j]
            j += 1
        end
    end

    #reset tracker array
    updates = data.updates
    for i in 1:length(updates)
        updates[i] = false
    end

    #clear public cards array
    empty!(data.public_cards)

    g.deck_cursor = length(deck)
    g.deck_cursor -= j

    g.state = g.started
    g.round = 0
    g.last_bet = 0
    g.pot_size = 0
    g.num_actions = length(stp.actions)
    g.position = 0
    g.all_in = 0
    g.r_all_in = 0

    #get next available player
    st = nextplayer(g)

    if stp.num_players == 2
        #first player posts the bigblind
        perform!(stp.big_blind, g, st)
        perform!(stp.small_blind, g, g.player)
        # next player to play will be the dealer
        g.position = 1
    else
        perform!(stp.small_blind, g, st)
        perform!(stp.big_blind, g, g.player)
    end

    return g.state
end

function sample(a::Tuple{Vararg{Action}}, wv::BitArray)
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
    return a[i]
end

function _activate(action::AbstractBet, g::Game, ps::PlayerState)
    amt = amount(action, g, ps)
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
    actions::Tuple{Vararg{Action}},
    actions_mask::BitArray,
    ids::Tuple{Vararg{Int8}},
    g::Game,
    ps::PlayerState)

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
        a = actions[ia]

        #skip elements that are not in available actions
        while id != a.id && ia < n
            ia += 1
            a = actions[ia]
        end

        #activate actions
        while id == a.id && ia < n
            actions_mask[ia] = _activate(a, g, ps)
            c += 1
            ia += 1
            a = actions[ia]
        end

        iid += 1
    end

    #update last element
    a = actions[ia]
    if ids[l] == a.id
        actions_mask[ia] = _activate(a, g, ps)
        c += 1
    end

    return c
end

function update!(action::Call, g::Game, ps::PlayerState)
    return _update!(viewactions(g), g.actions_mask, AFTER_CALL, g, ps)
end

function update!(action::All, g::Game, ps::PlayerState)
    return _update!(viewactions(g), g.actions_mask, AFTER_ALL, g, ps)
end

function update!(action::Fold, g::Game, ps::PlayerState)
    return _update!(viewactions(g), g.actions_mask, AFTER_FOLD, g, ps)
end

function update!(action::Raise, g::Game, ps::PlayerState)
    return _update!(viewactions(g), g.actions_mask, AFTER_RAISE, g, ps)
end

function update!(action::Bet, g::Game, ps::PlayerState)
    return _update!(viewactions(g), g.actions_mask, AFTER_BET, g, ps)
end

function update!(action::Check, g::Game, ps::PlayerState)
    return _update!(viewactions(g), g.actions_mask, AFTER_CHECK, g, ps)
end

function update!(action::Chance, g::Game, ps::PlayerState)
    return _update!(viewactions(g), g.actions_mask, AFTER_CHANCE, g, ps)
end

function update!(action::BigBlind, g::Game, ps::PlayerState)
    return _update!(viewactions(g), g.actions_mask, AFTER_BB, g, ps)
end

function update!(action::SmallBlind, g::Game, ps::PlayerState)
    return _update!(viewactions(g), g.actions_mask, AFTER_SB, g, ps)
end

end
