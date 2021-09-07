module playing

export perform!
export start!
export sample
export amount
export initialize!
export putbackcards!
export distributecards!
export rotateplayers!

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


@inline function _setbetplayer!(g::Game, ps::PlayerState)
    try
        if totalbet(g.prev_player) < ps.total_bet
            g.bet_player = ps
        end
    catch e
    end
end

function bet!(a::AbstractBet, g::Game, ps::PlayerState)

    amt = amount(a, g, ps)

    ps.chips -= amt
    ps.bet = amt

    ps.total_bet += amt
    g.pot_size += amt
    g.total_bet += amt

    if g.last_bet <= amt
        g.last_bet = amt
    end

    _setbetplayer!(a, g, ps)

    return amt

end

_nextround!(g::Game, ps::PlayerState) = _nextround!(g, setup(g), ps)

@inline function _nextround!(g::Game, stp::GameSetup, ps::PlayerState)
    println("Next Round")

    g.round += 1
    if g.round < limit(g, stp)
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
    if g.active_players != g.all_in
        g.prev_player = ps
        ps = nextplayer(g)
        #update actions for next player
        update!(action, g, ps)
        g.player = ps
        st = g.started
        g.state = st

        return st
    else
        return _nextround!(g, ps)
    end
end

update!(g::Game, gs::GameState) = g.state

@inline function _computepotentialearning!(pst::Vector{PlayerState} , ps::PlayerState)
    amt = ps.total_bet
    pot = ps.pot

    for opp in pst
        bt = opp.total_bet

        if amt <= bt
            pot += amt
        else
            pot += bt
        end
    end

    ps.pot = pot

    return pot
end

function _nlastround!(g::Game, gs::Ended, stp::GameSetup)
    # game did not go to the last round => all except one player
    # have folded
    states = g.players_states
    #give all the chips to the only active player
    for ps in states
        if ps.active == true
            amt = _computepotentialearning!(states, ps)

            ps.chips += amt

            println(
            "Winner! ", id(ps),
            " Amount ", amt,
            " Total Chips ", ps.chips)

        end


        ps.pot = 0
        ps.bet = 0
        ps.total_bet = 0

    end

    g.pot_size = 0

    bb = bigblind(stp).amount
    n = stp.num_players

    # count remaining players
    for ps in states

        if ps.chips < bb
            n -= 1
        else
            ps.active = true
        end
    end

    g.all_in = n

    if n != 1
        g.state = g.ended
    else
        #game terminates when only one player remains
        g.state = g.terminated
    end

    if g.round >= 2
        _revertplayersorder!(g.gm, states)
    end

    return g.state

end

function _lastround!(g::Game, gs::Ended, stp::GameSetup)
    #called when the game has reached the last round
    data = shared(g)

    best_rk = MAX_RANK + 1

    states = g.players_states

    #evaluate players hand ranks
    for ps in states
        if ps.active == true
            rank = evaluate(data.private_cards[id(ps)], data.public_cards)
            ps.rank = rank
            if rank < best_rk
                best_rk = rank
            end
        end
    end


    w = 0 # total winners
    htb = 0 # highest total bet

    for ps in states
        if ps.rank == best_rk
            w += 1
        end

    end

    #todo: if there are two winners, select the player with the highest second private card
    claimed_amt = 0
    #distribute earnings to the winners
    for ps in states
        if ps.active == true && ps.rank == best_rk

            #player receives the amount proportional to the potential gains he might make
            earnings = _computepotentialearning!(states, ps)

            if earnings >= g.pot_size
                amt = (earnings ^ 2) / (g.pot_size * w)
            else
                amt = earnings
            end

            println("Earnings ", earnings)
            println(" Pot ", g.pot_size)

            claimed_amt += amt
            ps.chips += amt

            ps.pot = 0
            ps.total_bet = 0

            println(
            "Winner: ", id(ps),
            " Amount: ", amt,
            " Total Chips: ", ps.chips,
            " Cards: ", pretty_print_cards(data.private_cards[id(ps)]),
            " ", pretty_print_cards(data.public_cards))

        end

        ps.bet = 0

    end

    bb = bigblind(setup(g)).amount
    n = length(states)
    bp = countbetplayers(states)

    # give back unclaimed chips

    df = bp - w

    for ps in states
        #redistribute unclaimed chips

        if ps.pot != 0
            if g.pot_size - claimed_amt > 0
                ps.chips += ((_computepotentialearning!(states, ps) - claimed_amt) ^ 2) / ((g.pot_size - claimed_amt) * df)
            end
            ps.pot = 0
        end

        if ps.chips < bb
            n -= 1
        else
            ps.active = true
        end
    end

    #reset total bets
    for ps in states
        ps.total_bet = 0
    end


    if n > 1
        g.state = g.ended
        g.active_players = n
        g.all_in = n

    else
        #game terminates when only one player remains
        g.state = g.terminated
    end

    _revertplayersorder!(g.gm, g.players_states)

    return g.state


end

function update!(g::Game, gs::Ended) :: GameState

    stp = setup(g)
    if g.round >= stp.num_rounds
        # game has reached the last round
        return _lastround!(g, gs, stp)
    else
        # all players except one have folded
        return _nlastround!(g, gs, stp)
    end
end

@inline function rotateplayers!(pls::Vector{PlayerState}, bb::AbstractFloat)
    i = 1

    for ps in pls

        if ps.chips >= bb
             break
        end

        i += 1
    end

    ps = pls[i]
    deleteat!(pls, i)
    push!(pls, ps)

end

@inline function countbetplayers(pls::Vector{PlayerState})
        i = 0

        for ps in pls
            if ps.pot != 0
                i += 1
            end
        end

        return i
end

function perform!(a::Chance, g::Game, ps::PlayerState)
    data = shared(g)
    round = g.round
    #update once per round
#     updates = data.updates
    states = g.players_states

    ap = g.active_players

    for i in 1:setup(g).cards_per_round[round]
        append!(data.public_cards, pop!(data.deck))
        data.deck_cursor -= 1
    end

    for ps in states
        #assign potential earnings to each player

        # potential earnings is the amount the player bet at this
        # round times the number of active players

        if ps.active == true
            _computepotentialearning!(states, ps)
        end

    end

#     if round == 1
#         println("ROTATE!!!")
#         rotateplayers!(states, bigblind(setup(g)).amount)
#     end

    for ps in states
        ps.bet = 0
        ps.total_bet = 0
    end

    #reset last bet
    g.last_bet = 0
    g.total_bet = 0

    ap = g.active_players
    all_in = g.all_in

#     ap - all_in == 1 || g.r_all_in +

    if all_in == ap || (ap - all_in) == 1
        # all went all-in or all except one went all-in
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
    # g.r_all_in += 1

    g.all_in += 1

    if g.active_players == g.all_in
        # all players went all-in, move to the next round
        return _nextround!(g, ps)
    end

    return update!(g, a, ps)
end

function perform!(a::Check, g::Game, ps::PlayerState)

#     if ps.position >= g.active_players - g.all_in
#         # if the last player checks, move to next round
#         return _nextround!(g, ps)
    #if it is the player that has bet last that checks, we move to the next round

    #if the player that checks is the one that bet, move to next round
    if g.bet_player == ps
        return _nextround!(g, ps)
    elseif ps.action == BB_ID
        #if players previous action was a bigblind
        return _nextround!(g, ps)
    end

    return update!(g, a, ps)
end

function perform!(a::Fold, g::Game, ps::PlayerState)
    ps.active = false
    g.active_players -= 1

#      # drop relative position by one
#     for p in g.players_states
#         if p.position > ps.position
#             p.position -= 1
#         end
#     end

    # if only one player remains the game ends
    if g.active_players == 1
        st = g.ended
        g.state = st
        return st

    elseif g.all_in == g.active_players
        return _nextround!(g, setup(g), ps)
    end

    return update!(g, a, ps)
end

function perform!(a::Call, g::Game, ps::PlayerState)
#     d = g.active_players - g.all_in

    if g.active_players - g.all_in == 1
        # if all the other players went all-in, move to next round
        # g.r_all_in += 1
        bet!(a, g, ps)
        return _nextround!(g, ps)

    else
        np = peekplayer(g)

        if g.bet_player == np && np.action != BB_ID
            bet!(a, g, ps)
            # if it is the next player that bet, move to the next round
            return _nextround!(g, ps)
        end
    end

    bet!(a, g, ps)
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
    n = length(g.players_states)
    st = _nextplayer(g, n)

    while !st.active || st.chips == 0
        st = _nextplayer(g, n)
    end

    return st
end

@inline function peekplayer(g::Game)
    stp = setup(g)
    n = length(g.players_states)

    position = g.position

    players_states = g.players_states

    position == n ? position = 1 : position += 1

    st = players_states[position]

    while !st.active || st.chips == 0

        position == n ? position = 1 : position += 1
        st = players_states[position]

    end

    return st
end


start!(::Type{T}, g::Game) where T <: RunMode = start!(T, g, g.state)
start!(::Type{T}, g::Game, gs::Started) where T <: RunMode = start!(T, g, shared(g))

function start!(::Type{T}, g::Game, s::Terminated) where T <: RunMode
    data = shared(g)
    stp = setup(g)
    states = g.players_states

    #re-initialize players states
    for st in states
        st.chips = stp.chips # reset chips
        st.active = true
        st.bet = 0
    end
    #set the number of active players
    g.active_players = stp.num_players

    start!(g, shared(g))
end

function start!(::Type{T}, g::Game, s::Ended) where T <: RunMode
    start!(T, g, shared(g))
end

function start!(g::Game, s::Terminated)
    error("Cannot start a terminated game")
end

function start!(g::Game, st::Initializing)
    error("Cannot start an unnitialized game!")
end

function initialize!(
    ::Type{Simulation},
    g::Game,
    data::SharedData,
    stp::GameSetup)

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
    g.state = STARTED

    return STARTED
end

function distributecards!(
    ::Type{LiveSimulation},
    g::Game,
    stp::GameSetup,
    data::SharedData)

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
    ::Type{Simulation},
    g::Game,
    stp::GameSetup,
    data::SharedData)

    deck = data.deck
    #distribute private cards
    for i in 1:stp.num_private_cards
        for state in g.players_states
            if state.active == true
                push!(privatecards(state, data), pop!(deck))
            end
        end
    end
end

function putbackcards!(
    ::Type{LiveSimulation},
    g::Game,
    stp::GameSetup,
    data::SharedData)

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
    ::Type{Simulation},
    g::Game,
    stp::GameSetup,
    data::SharedData)

    for state in g.players_states
        pvt_cards = privatecards(state, data)
        append!(data.deck, pvt_cards)
        empty!(pvt_cards)
    end

    append!(data.deck, data.public_cards)
    empty!(data.public_cards)
end

function start!(
    ::Type{LiveSimulation},
    g::Game,
    data::SharedData)

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
    ::Type{Simulation},
    g::Game,
    data::SharedData)

    stp = setup(g)
#     distributecards!(g, stp, data)

    g.state = g.started
    g.round = 0
    g.last_bet = 0
    g.pot_size = 0
    g.position = 1
    g.all_in = 0
    g.player = g.players_states[1]

    updates = data.updates

    for i in 1:length(updates)
        updates[i] = false
    end

    # skip the first player since it is the dealer
#     st = nextplayer(g)
#     g.player = st

    if g.active_players == 2
        #first player posts the bigblind
        g.bet_player = g.player
        setaction!(g.player, BB_ID)
        perform!(stp.bb, g, g.player)
        setaction!(g.player, SB_ID)
        perform!(stp.sb, g, g.player)

        # go back to first player
        g.player = nextplayer(g)

        g.gm = HeadsUp
    else
        println("Small Blind ", stp.sb.amount, " Player ", id(g.player))
        setaction!(g.player, SB_ID)
        perform!(stp.sb, g, g.player)
        println("Big Blind ", stp.bb.amount, " Player ", id(g.player))
        setaction!(g.player, BB_ID)
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

    while i < n
        @inbounds cw += wv[i]/c

        if t < cw
            break
        end

        i += 1
    end

    return i
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
    if ps.bet >= g.last_bet
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
    # in case it is equal, then it will be an all-in
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
    g::Game,
    ps::PlayerState)

    actions_mask = ps.actions_mask

    iid = 1
    ia = 1
    l = length(ids)
    n = length(actions_mask)
#     c = 0

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
#             c += 1
            ia += 1
            a = acts[ia]
        end

        iid += 1
    end

    #update last element
    a = acts[ia]
    if ids[l] == a.id
        actions_mask[ia] = _activate(a, g, ps)
#         c += 1
    end

#     return c
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