module data_conversion

    using games
    using poker
    using cards

    export toactiondata
    export fromcardsdata

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

    @inline function getmultiplier(act::Action, gs::GameState)
        #TODO: also check if the player is the first to bet.
        if g.round > 0
            return act.pot_multiplier
        else
            return act.blind_multiplier
        end
    end

    @inline function toactiondata(act::Action, gs::GameState, ps::PlayerState)
        action_id = act.action_id
        if action_id == BET_ID
            return ActionData(
            action_type=ActionData_ActionType.BET,
            multiplier=getmultiplier(act, gs),
            amount=betamount(act, gs, ps))
        elseif action_id == CALL_ID
            return ActionData(
                action_type=ActionData_ActionType.CALL)
        elseif action_id == CHECK_ID
            return ActionData(
                action_type=ActionData_ActionType.CHECK)
        elseif action_id == RAISE_ID
            return ActionData(
                action_type=ActionData_ActionType.RAISE,
                multiplier=getmultiplier(act, gs),
                amount=betamount(act, gs, ps))
        elseif action_id == ALL_ID
            return ActionData(
                action_type=ActionData_ActionType.ALL_IN)
        elseif action_id == FOLD_ID
            return ActionData(
                action_type=ActionData_ActionType.FOLD)
        end
    end

    @inline function fromactiondata(act::ActionData, gs::GameState, ps::PlayerState)
        act_type = act.action_type
        
        #TODO: we should have an objects cache if the action doesn't exist,
        # instanciate it.

        #FIXME: we are assuming that pre flop action is 4 times the pot size bet (parametrize this)

        if gs.round > 0
            multiplier = (act.amount - gs.last_bet)/(gs.pot_size - callamount(gs, ps))
            return Action(FROM_ACTION_DATA_MAP[act_type], multiplier, 4*multiplier)
        else
            multiplier = act.amount/bigblind(gs)
            return Action(FROM_ACTION_DATA_MAP[act_type], multiplier/4, multiplier)
        end
        

    end

    @inline function fromcardsdata(card_data::CardsData)
        return new_card(card_data.rank, card_data.suit)
    end

end