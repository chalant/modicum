module playing

export perform!
export start!
export sample
export amount
export activateplayers!
export putbackcards!
export distributecards!
export rotateplayers!
export betamount
export update!
export postblinds!
export _postblinds!

export callamount

using Random
using StaticArrays
using AbstractPlay

using games

using cards
using evaluator

using players
using actions

@inline function callamount(gs::GameState, ps::PlayerState)
    b = gs.last_bet - ps.bet
    return b >= 0 ? b : 0.0
end

@inline function allinamount(ps::PlayerState)
        return ps.chips
end

@inline function betamount(act::Action, gs::GameState, ps::PlayerState)
    if gs.round > 0
        return gs.pot_size * act.pot_multiplier + gs.last_bet + callamount(gs, ps)
    else
        return bigblind(gs) * act.blind_multiplier + gs.last_bet
    end
end

@inline function bigblindamount(gs::GameState, ps::PlayerState)
        return bigblind(gs)
end

@inline function smallblindamount(gs::GameState, ps::PlayerState)
        return smallblind(gs)
end

@inline function activateplayers!(gs::GameState)
    states = gs.players_states
    bb = bigblind(gs)

    a = 0

    #re-initialize players states
    for st in states

        if st.chips < bb
            st.active = false
        else
            st.active = true
            a += 1
        end
        st.bet = 0
        st.pot = 0
    end

    gs.active_players = a

    rotateplayers!(states, bb)

end

@inline function _setbetplayer!(gs::GameState, ps::PlayerState)
    if totalbet(gs.prev_player) < ps.total_bet
        gs.bet_player = ps
    end
end

function bet!(amt::Float32, gs::GameState, ps::PlayerState)
    r = _bet!(amt, gs, ps)

    _setbetplayer!(gs, ps)

    return r

end

@inline function _bet!(amt::Float32, gs::GameState, ps::PlayerState)
    ps.chips -= amt
    ps.bet = amt

    ps.total_bet += amt
    gs.pot_size += amt
    gs.total_bet += amt

    if gs.last_bet <= amt
        gs.last_bet = amt
    end

    return amt

end

@inline function nextround!(gs::GameState, ps::PlayerState)    
    return performchance!(gs, ps)
end

@inline function nextround!(gs::GameState{N, 2, Game{T}}, ps::PlayerState) where T <: GameSetup 

    state_id = performchance!(gs, ps)
    #reset position and current player 
    #so that next player to act is the first player in the queue
    gs.position = 1
    gs.player = gs.players_states[1]
    gs.state = state_id
    
    return state_id

end

@inline function update!(gs::GameState, action::Action, ps::PlayerState)
    #avoid infinit loop when all players went all-in
    np = nextplayer!(gs)

    if gs.active_players != gs.all_in
        gs.prev_player = ps

        update!(action, gs, np)

        gs.state = STARTED_ID

        return STARTED_ID
    else
        return nextround!(gs, np)
    end
end

@inline function _computepotentialearning!(pst::Vector{PlayerState} , ps::PlayerState)
    amt = ps.total_bet
    pot = ps.pot

    for opp in pst
        bt = opp.total_bet
        
        pot += (amt < bt) * amt + (amt >= bt) * bt

    end

    ps.pot = pot

    return pot
end

function _notlastround!(gs::GameState{A, P, Game{T}}) where {A, P, T<:GameSetup}
    # game did not go to the last round => all except one player
    # have folded
    
    results = @MVector zeros(Float32, P)
    
    i = 0
    states = gs.players_states
    #give all the chips to the only active player

    for ps in states
        i += 1
        
        if ps.active == true
            amt = _computepotentialearning!(states, ps)

            ps.chips += amt
            
            results[players.id(ps)] = amt

            println(
            "Winner! ", players.id(ps),
            " Amount ", amt,
            " Total Chips ", ps.chips)
        
        else
            amt = -ps.total_bet
            results[players.id(ps)] = amt
            ps.chips += amt
        end

        ps.pot = 0
        ps.bet = 0
        ps.total_bet = 0

    end

    gs.pot_size = 0

    bb = bigblind(gs)
    n = P

    # count remaining players
    for ps in states

        if ps.chips < bb
            n -= 1
        else
            ps.active = true
        end
    end

    gs.all_in = 0

    if n != 1
        gs.state = ENDED_ID
    else
        #game terminates when only one player remains
        gs.state = TERM_ID
    end

    return winners

end

@inline function _lastround!(
    gs::GameState{A, 2, Game{T}}, 
    data::ShareData,
    mp::PlayerState, 
    mpc_rank::UInt64, 
    opp_pc::SizedArray{2, UInt64}) where {A, T<:GameSetup}
    
    opp_rank = evaluate(opp_pc, data.public_cards)
    best_rank = min(mpc_rank, opp_rank)

    has_best_rk = mpc_rank == best_rank
    
    earnings = _computepotentialearning!(gs.players_states, mp)

    return ((-(mpc_rank > best_rk)) + has_best_rk) * ((earnings >= gs.pot_size) * (earnings ^ 2) / (gs.pot_size * (1 + has_best_rk && opp_rank == best_rank))) + (earnings < gs.pot_size) * earnings
    
end

@inline function _nlastround!(
    gs::GameState{A, 2, Game{T}}, 
    data::ShareData, 
    mpc_rank::UInt64, 
    opp_pc::SizedArray{2, UInt64})



end

@inline function _lastround!(gs::GameState{A, P, Game{T}}) where {A, P, T<:GameSetup}
    #called when the game has reached the last round
    
    results = @MVector zeros(Float32, P)
    ranks = @MVector fill(MAX_RANK + 1, P)
    
    data = updateprivatecards!(gs, gs.game)

    best_rk = MAX_RANK + 1

    states = gs.players_states

    i = 1
    #evaluate players hand ranks
    for ps in states
        i += 1

        if ps.active == true
            rank = evaluate(data.private_cards[players.id(ps)], data.public_cards)
            
            ranks[i] = rank 
            best_rk = (rank < best_rk) * rank + (rank >= best_rk) * best_rk
        end
    end


    w = 0 # total winners

    for i in 1:P
        w += ranks[i] == best_rk
    end

    #todo: if there are two winners, select the player with the highest second private card
    claimed_amt = 0
    #distribute earnings to the winners
    i = 1

    #fixme: check earnings calculations
    
    for ps in states
        i += 1

        rank = ranks[i]

        earnings = _computepotentialearning!(states, ps)

        amt = ((earnings >= gs.pot_size) * (earnings ^ 2) / (gs.pot_size * w)) + (earnings < gs.pot_size) * earnings

        amt = ((-(rank > best_rk) && ps.active == true) + ((rank == best_rk) && ps.active == true)) * amt + (-1 * ps.active == false) * ps.total_bet

        #player receives the amount proportional to the potential gains he might make

        claimed_amt += amt
        ps.chips += amt

        ps.pot = !(ps.active == true && rank == best_rk) * ps.pot
        ps.total_bet = 0

        results[players.id(ps)] = amt
        
        println(
            "Winner: ", players.id(ps),
            " Amount: ", amt,
            " Total Chips: ", ps.chips,
            " Cards: ", pretty_print_cards(data.private_cards[players.id(ps)]),
            " ", pretty_print_cards(data.public_cards))

        ps.bet = 0

    end

    bb = bigblind(gs)
    n = P
    bp = countbetplayers!(states)

    # give back unclaimed chips

    df = bp - w

    for ps in states
        #redistribute unclaimed chips

        if ps.pot != 0
            if gs.pot_size - claimed_amt > 0
                amt = ((_computepotentialearning!(states, ps) - claimed_amt) ^ 2) / ((gs.pot_size - claimed_amt) * df)
                ps.chips += amt
                results[players.id(ps)] += amt
            end
            ps.pot = 0
        end

        if ps.chips < bb
            n -= 1
        else
            ps.active = true
        end
    end

    if n > 1
        gs.state = ENDED_ID
        gs.active_players = n
        gs.all_in = n

    else
        #game terminates when only one player remains
        gs.state = TERM_ID
    end

#     _revertplayersorder!(g.gm, g.players_states)

    return results

end

@inline function updateprivatecards!(gs::GameState, g::Game)
    #this function is used to 
    return shared(g)
end

@inline function updatepubliccards!(gs::GameState, g::Game)
    return shared(g)
end

@inline function showdown!(gs::GameState, g::Game)
    if gs.round >= numrounds!(g)
        # game has reached the last round
        return _lastround!(gs)
    else
        # all players except one have folded
        return _notlastround!(gs)
    end
end

@inline function showdown!(gs::GameState{A, 2, Game{T}}, g::Game{T}, mp::PlayerState, mpc_rank::UInt64, opp_pc::SizedArray{2, UInt64}) where T <: GameMode

    if gs.round >= numrounds!(g)
        # game has reached the last round
        return _lastround!(gs)
    else
        # all players except one have folded
        return _notlastround!(gs)
    end
end

@inline function update!(gs::GameState, g::Game)
    showdown!(gs, g)
    return gs.state
end

@inline function rotateplayers!(pls::SVector{N, PlayerState}, bb::AbstractFloat)
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

@inline function countbetplayers!(pls::Vector{PlayerState})
        i = 0

        for ps in pls
            if ps.pot != 0
                i += 1
            end
        end

        return i
end

@inline function performallin!(a::Action, gs::GameState, ps::PlayerState)
    bet!(ps.chips, gs, ps)

    # add all-in players
    # g.r_all_in += 1

    gs.all_in += 1

    if gs.active_players == gs.all_in
        # all players went all-in, move to the next round
        return nextround!(gs, ps)
    end

    return update!(gs, a, ps)
end

@inline function performraise!(a::Action, gs::GameState, ps::PlayerState)
    bet!(betamount(a, gs, ps), gs, ps)
    return update!(gs, a, ps)
end

@inline function performcheck!(a::Action, gs::GameState, ps::PlayerState)
    #if the player that checks is the one that bet, move to next round
    if gs.bet_player == ps
        return nextround!(gs, ps)
    elseif ps.action == BB_ID
        #if players previous action was a bigblind
        return nextround!(gs, ps)
    end

    return update!(gs, a, ps)
end

@inline function onbetactionperformed!(gs::GameState)

end

@inline function performcall!(a::Action, gs::GameState, ps::PlayerState)
    if gs.active_players - gs.all_in == 1
        # if all the other players went all-in, move to next round
        # g.r_all_in += 1
        _bet!(callamount(gs, ps), gs, ps)
        onbetactionperformed!(gs)
        return nextround!(gs, ps)
    else
        np = peekplayer(gs)

        if gs.bet_player == np && np.action != BB_ID
            bet!(callamount(gs, ps), gs, ps)
            onbetactionperformed!(gs)
            # if it is the next player that bet, move to the next round
            return nextround!(gs, ps)
        end
    end

    bet!(callamount(gs, ps), gs, ps)
    return update!(gs, a, ps)
end

@inline function performfold!(a::Action, gs::GameState, ps::PlayerState)
    ps.active = false
    gs.active_players -= 1

    # if only one player remains the game ends
    if gs.active_players == 1
        gs.state = ENDED_ID
        return ENDED_ID

    elseif gs.all_in == gs.active_players
        return nextround!(gs, ps)
    end

    return update!(gs, a, ps)
end

@inline function setpubliccards!(gs::GameState, g::Game{T}) where {T <: GameSetup}
    data = shared(g)

    for i in 1:g.cards_per_round[gs.round]
        push!(data.public_cards, pop!(data.deck))
        data.deck_cursor -= 1
    end

    return data

end

@inline function beforechancereset!(gs::GameState, g::Game)
end

@inline function endhand!(gs::GameState, gm::Game)
    
    while gs.round < numround!(gs)
        setpubliccards!(gs, gm)
        gs.round += 1

    gs.state = ENDED_ID
    return ENDED_ID

    end
end

@inline function performchance!(gs::GameState, ps::PlayerState)
    #update once per round
    #updates = data.updates

    states = gs.players_states

    ap = gs.active_players
    gm = game!(gs)

    setpubliccards!(gs, gm)

    for ps in states
        # assign potential earnings to each active player
        # potential earnings is the amount the player might win

        if ps.active == true
            _computepotentialearning!(states, ps)
        end

    end

    beforechancereset!(gs, gm)

    for ps in states
        ps.bet = 0
        ps.total_bet = 0
    end

    #reset last bet
    gs.last_bet = 0
    gs.total_bet = 0

    ap = gs.active_players
    all_in = gs.all_in

    # all went all-in or all except one went all-in

    if all_in == ap || (ap - all_in) == 1
        return endhand!(gs, gm)
    end

    gs.round += 1

    if gs.round >= limit!(gs)
        gs.state = ENDED_ID
        return ENDED_ID
    end

    return update!(gs, CHANCE, ps)
    
end

@inline function perform!(a::Action, gs::GameState, ps::PlayerState)
    id = a.id

    if id == ALL_ID
        return performallin!(a, gs, ps)
    elseif id == BET_ID || id == RAISE_ID
        bet!(betamount(a, gs, ps), gs, ps)
        onbetactionperformed!(gs)
        return update!(gs, a, ps)
    elseif id == CHECK_ID
        return performcheck!(a, gs, ps)
    elseif id == CALL_ID
        return performcall!(a, gs, ps)
    elseif id == FOLD_ID
        return performfold!(a, gs, ps)
    # elseif id == CHANCE_ID
    #     return performchance!(a, gs, ps)
    end

    return update!(gs, a, ps)
end

@inline function _nextplayer!(state::GameState, n::Int)

    state.position == n ? state.position = 1 : state.position += 1
    # get the state with the corresponding position
    # players are arranged by position
    return state.players_states[state.position]
end

@inline function nextplayer!(gs::GameState)
    n = length(gs.players_states)
    st = _nextplayer!(gs, n)
    
    while !st.active || st.chips == 0
        st = _nextplayer!(gs, n)
    end

    gs.player = st

    return st
end

@inline function peekplayer(gs::GameState)
    n = length(gs.players_states)

    position = gs.position

    players_states = gs.players_states

    position == n ? position = 1 : position += 1

    st = players_states[position]

    while !st.active || st.chips == 0

        position == n ? position = 1 : position += 1
        st = players_states[position]

    end

    return st
end

@inline function start!(gs::GameState)
    id = stateid(gs.state)

    if id == TERM_ID
        data = shared(gs)
        stp = game!(gs)
        states = gs.players_states

        #re-initialize players states
        for st in states
            st.chips = stp.chips # reset chips
            st.active = true
            st.bet = 0
        end
        #set the number of active players
        gs.active_players = numplayers!(gs)

        return _start!(gs, data)

    elseif id == ENDED_ID
        return _start!(gs, shared(gs))

    elseif id == INIT_ID
        error("Cannot start an un-initialized game!")
    elseif id == STARTED_ID
        return _start!(gs, shared(gs))
    else
        error("Undefined State")
    end
end

function distributecards!(
    gs::GameState,
    g::Game{LiveSimulation},
    data::SharedData)

    deck = data.deck

    #distribute private cards
    main = stp.main_player
    for i in 1:g.num_private_cards
        for state in gs.players_states
            #only distribute to opponents and active players
            if main != state && state.active == true
                privatecards(state, data)[i] = pop!(deck)
            end
        end
    end
end

function distributecards!(
    gs::GameState,
    g::Game,
    data::SharedData)

    deck = data.deck
    #distribute private cards
    for i in 1:g.num_private_cards
        for state in gs.players_states
            if state.active == true
                push!(privatecards(state, data), pop!(deck))
            end
        end
    end
end

function putbackcards!(
    gs::GameState,
    g::Game{LiveSimulation},
    data::SharedData)

    main = g.main_player

    for state in gs.players_states
        if main != state && state.active == true
            append!(deck, privatecards(state, data))
        end
    end

    #remove public cards up until the relative root game round
    
    for _ in 1:sum(g.cards_per_round[1:data.round]) - g.cards_per_round[data.round]
        push!(data.deck, pop!(data.public_cards))
    end
end

function putbackcards!(
    gs::GameState,
    g::Game,
    data::SharedData)

    for state in gs.players_states
        pvt_cards = privatecards(state, data)
        append!(data.deck, pvt_cards)
        empty!(pvt_cards)
    end

    append!(data.deck, data.public_cards)
    empty!(data.public_cards)
end

@inline function _start!(
    gs::GameState,
    g::Game{LiveSimulation},
    data::SharedData)

    deck = data.deck
    n = length(deck)

    states = g.players_states

    # reset data from last root game
    copy!(g, game!(dg), data, g)
    return gs.state
end

@inline function performsmallblind!(gs::GameState)
    ps = gs.player

    _bet!(smallblind(gs), gs, ps)
#     _update!(viewactions(stp), AFTER_SB, g, ps)
    setaction!(gs.player, SB_ID)

    gs.prev_player = ps
    nextplayer!(gs)
end

@inline function performbigblind!(gs::GameState)
    ps = g.player

    _bet!(bigblind(gs), gs, ps)
    _update!(actions!(gs), AFTER_BB, gs, ps)
    setaction!(ps, BB_ID)

    gs.bet_player = ps
    gs.prev_player = ps
    nextplayer!(gs)

end

@inline function postblinds!(gs::GameState, g::Game)
    _postblinds!(gs, g)
end

@inline function _headsupblinds!(gs::GameState)

    #first player posts bigblind
    ps = gs.player

    # println("Big Blind ", players.id(gs.player))

    np = nextplayer!(gs)

    #first player to act is the dealer (second player)

    _bet!(smallblind(gs), gs, np)
    # println("Small Blind ", players.id(gs.player))
    setaction!(ps, BB_ID)
    _bet!(bigblind(gs), gs, ps)
    gs.bet_player = ps
    gs.prev_player = ps

    _update!(actions!(gs), AFTER_BB, gs, np)

end

@inline function _postblinds!(gs::GameState{N, P, Game{T}}, g::Game{T}) where T <: GameSetup
    if numplayers!(g) > 2
        println("SmallBlind ", players.id(gs.player))
        performsmallblind!(gs)
        println("Big Blind ", players.id(gs.player))
        performbigblind!(gs)
    else
        _headsupblinds!(gs)
    end
end

@inline function _postblinds!(gs::GameState{N, 2, Game{T}}, g::Game{T}) where T <: GameSetup
    _headsupblinds!(gs)
end

@inline function _start!(
    gs::GameState,
    data::SharedData)

#     distributecards!(g, stp, data)

    gs.state = STARTED_ID
    gs.round = 0
    gs.last_bet = 0
    gs.pot_size = 0
    gs.position = 1
    gs.all_in = 0
    gs.player = gs.players_states[1]

#     updates = data.updates
#
#     for i in 1:length(updates)
#         updates[i] = false
#     end

    # skip the first player since it is the dealer
#     st = nextplayer(g)
#     g.player = st

    postblinds!(gs, game!(gs))

    return gs.state
end

@inline function sample(wv::Vector{Bool})
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

@inline function _activateabstractbet(amt::Float32, ps::PlayerState)
    if amt > ps.chips || amt == 0
        return 0
    end

    return 1
end

@inline function _activatesmallblind(gs::GameState, ps::PlayerState)
    return _activateabstractbet(smallblindamount(gs, ps), ps)
end

@inline function _activatebigblind(gs::GameState, ps::PlayerState)
    return _activateabstractbet(bigblindamount(gs, ps), ps)
end

@inline function _activateallin(gs::GameState, ps::PlayerState)
    if ps.chips != 0
        return 1
    end

    return 0
end

@inline function _activatecheck(gs::GameState, ps::PlayerState)
    if ps.bet >= gs.last_bet
        return 1
    end

    return 0
end

@inline function _activateaction(gs::GameState, ps::PlayerState)
    return 1
end

@inline function _activatefold(gs::GameState, ps::PlayerState)
    #the player can't fold if he's all-in
    if ps.bet > 0 && ps.chips == 0
        return 0
    end

    return 1
end

@inline function _activatecall(gs::GameState, ps::PlayerState)
    # in case it is equal, then it will be an all-in
    if ps.chips <= gs.last_bet
        return 0
    elseif ps.bet == gs.last_bet
        return 0
    end

    return 1
end

@inline function _update!(
    acts::ActionSet,
    ids::SVector{UInt8},
    gs::GameState,
    ps::PlayerState)

    actions_mask = gs.actions_mask

    ia = 1
    l = length(ids)
    n = length(actions_mask)
#     c = 0

    #disable all actions
    for i in 1:n
        actions_mask[i] = 0
    end
    
    for iid in 1:l
    # while iid < l + 1
        id = ids[iid]
        a = acts[ia]

        #skip elements that are not in available actions
        while id != a.id && ia < n
            ia += 1
            a = acts[ia]
        end

        #activate actions
        while id == a.id && ia < n
            actions_mask[ia] = _activateaction!(a, gs, ps)
#             c += 1
            ia += 1
            a = acts[ia]
        end

        # iid += 1
    end

    #update last element
    a = acts[ia]

    if ids[l] == a.id
        actions_mask[ia] = _activateaction!(a, gs, ps)
#         c += 1
    end

#     return c
end

@inline function update!(action::Action, gs::GameState, ps::PlayerState)
    id = action.id

    if id == BET_ID || id == RAISE_ID || id == BB_ID
        _update!(actions!(gs), ACTION_SET1, gs, ps)
    elseif id == CALL_ID || id == FOLD_ID
        _update!(actions!(gs), AFTER_CALL, gs, ps)
    elseif id == CHECK_ID || id == CHANCE_ID
        _update!(actions!(gs), ACTION_SET2, gs, ps)
    elseif id == ALL_ID
        _update!(actions!(gs), AFTER_ALL, gs, ps)
    elseif id == SB_ID
        _update!(actions!(gs), AFTER_SB, gs, ps)
    end

    return gs.state
end

@inline function _activateaction!(a::Action, gs::GameState, ps::PlayerState)
    ai = a.id

    if ai == CALL_ID
        return _activatecall(gs, ps)
    elseif ai == FOLD_ID
        return _activatefold(gs, ps)
    elseif ai == ALL_ID
        return _activateallin(gs, ps)
    elseif ai == RAISE_ID || ai == BET_ID
        return _activateabstractbet(betamount(a, gs, ps), ps)
    elseif ai == SB_ID
        return _activateabstractbet(smallblindamount(gs, ps), ps)
    elseif ai == BB_ID
        return _activateabstractbet(bigblindamount(gs, ps), ps)
    elseif ai == CHECK_ID
        return _activatecheck(gs, ps)
    end

end

end