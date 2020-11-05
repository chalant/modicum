

function search(g::Game)
    # start from some state: create game from a copy of the original
    # then solve for x iterations. Note: solving isn't performed until the
    # end of the game but until some depth limit
    l = setup(g).num_rounds
    if g.round == l - 2
        dl::UInt8 = l # play until the end if we reach turn round
    else
        dl = g.round + 1
    end

    # create a game in depth limited mode
    # copy shared data to avoid overwriting while solving
    root = game(copy(shared), setup(g), DepthLimited(dl))

    # todo: need history and infosets
    solve(root)

end
