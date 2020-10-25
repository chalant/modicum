module playing

export perform!
export start!
export sample
export amount

include("../games/games.jl")

using Reexport

@reexport using .games

function perform!(action::Chance, game::Game, ps::PlayerState)
    data = shared(game)
    round = game.round
    #update once per round
    updates = data.updates
    if !updates[round]
        if round == 1
            for i in 1:3
                append!(data.public_cards, data.deck[game.deck_cursor])
                game.deck_cursor -= 1
            end
        else
            append!(data.public_cards, data.deck[game.deck_cursor])
            game.deck_cursor -= 1
        end
        if game.active_players == 2
            #next player to play will be the first in the queue
            #update the position to be the last active player
            game.position = data.num_players
        else
            #reset the game position
            game.position = 1
        end
        updates[round] = true
    end
    #update available actions
    update!(game, action)
    # game.player = nextplayer(game, game.player)
    return game.started
end

function amount(a::Call, g::Game, ps::PlayerState)
    b = g.last_bet - ps.bet
    if b > 0
        return b
    else
        return 0
    end
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

function bet!(amt::AbstractFloat, game::Game, ps::PlayerState)
    ps.chips -= amt
    ps.bet += amt
    game.pot_size += amt
    game.last_bet = amt
end

function bet!(a::Action, game::Game, ps::PlayerState)
    #does nothing
end

function bet!(a::AbstractBet, game::Game, ps::PlayerState)
    #update chips size
    amt = amount(a, game, ps)
    ps.chips -= amt
    ps.bet += amt
    game.pot_size += amt
    game.last_bet = amt
end

function update!(game::Game, action::Action)
    player, st = nextplayer(game, shared(game))
    #update actions for next player
    game.num_actions = update!(action, game, st)
    game.player = player
end


function perform!(a::Action, game::Game, ps::PlayerState)
    bet!(a, game, ps)
    update!(game, a)
    return game.started
end

#note behavior may change based on the game type
function perform!(a::Call, g::Game, ps::PlayerState)
    bet!(a, g, ps)
    pl, st = nextplayer(g, shared(g))
    #check the next player can afford to call
    # if he can't, then he can only check, fold or go all-in
    b = amount(a, g, st)
    if b != 0
        g.num_actions = update!(a, g, st)
    else
        g.num_actions = _update!(viewactions(g),
            g.actions_mask, ACTION_SET3, g, st)
    end
    g.player = pl
    return g.started
end

function perform!(action::Check, game::Game, ps::PlayerState)
    #move to chance if we haven't reached the last round
    # if it is the last player that checks => move to next round

    if ps.position == game.active_players
        if setup(game).num_rounds == game.round
            return game.ended
        end
        #perform chance action
        game.round += 1
        return perform!(CHANCE, game, ps)
    end
    #updates game state (actions, player, etc.)
    update!(game, action)
    return game.started
end

function perform!(action::Fold, game::Game, ps::PlayerState)
    # if only one player remains the game ends

    game.active_players -= 1
    if game.active_players == 1
        return game.ended
    end
    # shift positions
    for st in game.players_states
        st.position -= 1
    end
    ps.active = false
    update!(game, action)
    return game.started
end

function _nextplayer(game::Game, data::SharedData)
    game.position == setup(game).num_players ? game.position = 1 : game.position += 1
    return data.players_queue[game.position]
end

function nextplayer(game::Game)
    return nextplayer(game, shared(game))
end


function nextplayer(game::Game, data::SharedData)
    #returns the next active player
    # for i in game.num_players
    #     if player.active == true
    #         return player
    #     else
    #         player = nextplayer(game)
    #     end
    # end

    #todo: must prevent infinit loop
    # raise an error if we do more than one lopp
    # this should never happen. There should always be at least one
    # active player
    player = _nextplayer(game, data)
    st = state(player, game.players_states)
    while st.active != true
        player = _nextplayer(game, data)
        st = state(player, game.players_states)
    end
    return (player, st)
end

function start!(game::Game)
    data = shared(game)
    deck = data.deck
    n = length(deck)
    stp = setup(game)

    players_queue = data.players_queue

    j = 0
    for i in 1:stp.num_private_cards
        for player in players_queue
            privatecards(player, data)[i] = deck[n-j]
            j += 1
        end
    end

    states = game.players_states

    #update players states
    for (i, player) in enumerate(players_queue)
        st = state(player, states)
        st.position = i
        st.bet = 0
    end

    #reset tracker array
    updates = data.updates
    for i in 1:length(updates)
        updates[i] = false
    end

    game.deck_cursor = length(deck)
    game.deck_cursor -= j

    game.active_players = stp.num_players
    game.state = game.started
    game.round = 0
    game.last_bet = 0
    game.pot_size = 0
    game.num_actions = length(stp.actions)
    game.position = 1
    game.turns = 0

    game.actions_mask = BitArray(ones(Int, game.num_actions))

    if stp.num_players == 2
        perform!(stp.big_blind, game, state(players_queue[1], states))
        perform!(stp.small_blind, game, state(players_queue[2], states))
        # next player to play will be the last in the queue
        game.position = 1
    else
        perform!(stp.small_blind, game, state(players_queue[1], states))
        perform!(stp.big_blind, game, state(players_queue[2], states))
        game.position = 2
    end
    game.player, st = nextplayer(game, data)

end

function sample(a::Tuple{Vararg{Action}}, wv::BitArray)
    t = rand() * sum(wv)
    n = length(wv)
    i = 1
    cw = wv[1]
    while cw < t && i < n
        i += 1
        @inbounds cw += wv[i]
    end
    return a[i]
end

function _activate(action::AbstractBet, g::Game, ps::PlayerState)
    amt = amount(action, g, ps)
    if amt > ps.chips || amt == 0
        return 0
    else
        return 1
    end
end

function _activate(action::Action, g::Game, ps::PlayerState)
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
