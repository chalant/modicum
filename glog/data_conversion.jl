module data_conversion

    using games
    using poker
    using cards

    export toactiondata
    export fromcardsdata

    @inline function getmultiplier(act::Action, g::Game)
        if g.round > 0
            return act.pot_multiplier
        else
            return act.blind_multiplier
        end
    end

    @inline function toactiondata(act::Action, g::Game)
        action_id = act.action_id
        if action_id == BET_ID
            return ActionData(
            action_type=ActionData_ActionType.BET,
            multiplier=getmultiplier(act, g),
            amount=betamount(act, g))
        elseif action_id == CALL_ID
            return ActionData(
                action_type=ActionData_ActionType.CALL)
        elseif action_id == CHECK_ID
            return ActionData(
                action_type=ActionData_ActionType.CHECK)
        elseif action_id == RAISE_ID
            return ActionData(
                action_type=ActionData_ActionType.RAISE,
                multiplier=getmultiplier(act, g),
                amount=betamount(act, g))
        elseif action_id == ALL_ID
            return ActionData(
                action_type=ActionData_ActionType.ALL_IN)
        elseif action_id == FOLD_ID
            return ActionData(
                action_type=ActionData_ActionType.FOLD)
        end
    end

    @inline function fromcardsdata(card_data::CardsData)
        return new_card(card_data.rank, card_data.suit)
    end

end