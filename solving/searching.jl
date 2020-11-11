include("games/games.jl")

using .games

# this function is called after the opponent moves and we don't have the action
# in our abstraction. The game state is set right before the opponent has taken
# the action
function search(g::Game, h::History, act::Action, info::Node, p0::Float32, p1::Float32)
    # start from some state: create game from a copy of the original
    # then solve for x iterations. Note: solving isn't performed until the
    # end of the game but until some depth limit
    stp = setup(g)
    l = stp.num_rounds
    if g.round == l - 2
        tp = Full() # solve until the end if only 2 rounds remain
    else
        tp = DepthLimited(g.round + 1)
    end
    # create a game in depth limited mode
    # copy shared data to avoid overwriting while solving
    # todo: we also need to remove main player private cards from the deck in the shared data
    root = game(setup(g), tp)
    copy!(root, g) # copy current game state (before opponent action)
    profile = info.stg_profile

    s::Float32 = 0
    # todo: we need a new setup where the action is included

    # todo: extend actions array and mask note: Must sort the array.

    #sum of reach probabilities for opponent
    for a in 1:stp.actions
        i = a.id
        if g.actions_mask[i] == 1
            s += p1 * profile[i]
        end
    end
    util = 0 # zero or previous util?
    ####### while (condition)...
        # NOTE: implementation is similar to "train function"
        # we could limit the training by number of iterations or by time.
        # note: if it is time limited, we measure the time it takes to make a single
        # loop on average and predict when to stop.
    data = shared(root)
    shuffle!(data.deck)
    distributecards!(root, stp, data)
    for p in stp.players
        util += solve(h, root, start!(root), root.player, p0/s, p1/s)
    end
    putbackcards!(root, stp, data)
    #######

end
