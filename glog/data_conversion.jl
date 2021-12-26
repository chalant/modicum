module data_conversion

    using games
    using poker
    using cards
    using actions
    using players
    using playing

    using PokerClients

    export toactiondata
    export fromactiondata
    export fromcardsdata
    export toplayerdata

    const ACTION_MAPPINGS = Dict{UInt8, Int32}(
        BET_ID => ActionData_ActionType.BET, 
        CALL_ID => ActionData_ActionType.CALL,
        RAISE_ID => ActionData_ActionType.RAISE,
        FOLD_ID => ActionData_ActionType.FOLD,
        ALL_ID => ActionData_ActionType.ALL_IN,
        CHECK_ID => ActionData_ActionType.CHECK)
    
    const FROM_ACTION_DATA_MAP = Dict{Int32, UInt8}(
        ActionData_ActionType.BET => BET_ID,
        ActionData_ActionType.CALL => CALL_ID,
        ActionData_ActionType.RAISE => RAISE_ID,
        ActionData_ActionType.FOLD => FOLD_ID,
        ActionData_ActionType.ALL_IN => ALL_ID,
        ActionData_ActionType.CHECK => CHECK_ID,
    )

    const FROM_CARDS_DATA_SUIT = Dict{String, String}(
        "Diamond" => "d",
        "Heart" => "h",
        "Spade" => "s",
        "Club" => "c"
    )

    @inline function _get_player_type(pos::UInt8)
        if pos == 0
            return PlayerData_PlayerType.MAIN
        else
            return PlayerData_PlayerType.OPPONENT
        end
    end

    @inline function toplayerdata(ps::PlayerState)
        pos = UInt8(players.position(ps) - 1)
        
        return PokerClients.PlayerData(;
            position=pos,
            player_type=_get_player_type(pos),
            is_active=ps.active)

        return pd
    end

    @inline function getmultiplier(act::Action, gs::GameState)
        #TODO: also check if the player is the first to bet.
        if gs.round > 0
            return act.pot_multiplier
        else
            return act.blind_multiplier
        end
    end

    @inline function toactiondata(act::Action, gs::GameState, ps::PlayerState)
        action_id = act.id
        if action_id == BET_ID
            return PokerClients.ActionData(;
            action_type=ActionData_ActionType.BET,
            multiplier=getmultiplier(act, gs),
            amount=betamount(act, gs, ps))
        elseif action_id == CALL_ID
            return PokerClients.ActionData(;
                action_type=ActionData_ActionType.CALL,
                multiplier=0,
                amount=0)
        elseif action_id == CHECK_ID
            return PokerClients.ActionData(;
                action_type=ActionData_ActionType.CHECK,
                multiplier=0,
                amount=0)
        elseif action_id == RAISE_ID
            return PokerClients.ActionData(;
                action_type=ActionData_ActionType.RAISE,
                multiplier=getmultiplier(act, gs),
                amount=betamount(act, gs, ps))
        elseif action_id == ALL_ID
            return PokerClients.ActionData(;
                action_type=ActionData_ActionType.ALL_IN,
                multiplier=0,
                amount=0)
        elseif action_id == FOLD_ID
            return PokerClients.ActionData(;
                action_type=ActionData_ActionType.FOLD,
                multiplier=0,
                amount=0)
        end
    end

    @inline function fromactiondata(
        act::PokerClients.ActionData, 
        gs::GameState, 
        ps::PlayerState)

        act_type = act.action_type
        
        #TODO: we should have an objects cache if the action doesn't exist,
        # instanciate it.

        #FIXME: we are assuming that pre flop action is 4 times the pot size bet (parametrize this)

        if gs.round > 0
            multiplier = (act.amount - gs.last_bet)/(gs.total_bet - callamount(gs, ps))
            
            return Action(
                FROM_ACTION_DATA_MAP[act_type], 
                multiplier, 
                4*multiplier)
        else
            multiplier = act.amount/bigblind(gs)
            
            return Action(
                FROM_ACTION_DATA_MAP[act_type], 
                multiplier/4, 
                multiplier)
        end

        println("Multiplier! ", multiplier)

    end

    @inline function fromcardsdata(cards_data::PokerClients.CardsData)
        cards = Vector{UInt64}()
        
        for card in cards_data.cards
            push!(cards, new_card(card.rank, FROM_CARDS_DATA_SUIT[card.suit]))
        end

        return cards

    end

end