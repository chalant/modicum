include("../games/tree.jl")
include("../games/games.jl")

using .tree
using .games

function cfr(h::History, game::Game, state::GameState, player::Int, p0::Float32, p1::Float32)
    return cfr(h, game, state, p0, p1)
end

function solve(game::Game)
    h = History(length(game.actions))
    state = start(game)
    cfr(h, game, state)
end

function cfr(h::History, game::Game, state::Chance, player::Player, p0::Float32, p1::Float32)
    #todo sample
    return cfr(h, game, play(game, state), p0, p1)
end

function cfr(h::History, game::Game, state::Ended, player::Player, p0::Float32, p1::Float32)
    return evaluate(game, player)
end

function cfr(h::History, game::Game, state::Started, player::Player, p0::Float32, p1::Float32)
    for a in game.actions
        if game.player == player
        else
        end
    end
    state = play(cfr, game, state)
    return cfr(history(h, state.action, length(state.actions)), game, state, p0, p1)
end

function cfr(h::History, game::Game, state::Initializing, player::Player, p0::Float32, p1::Float32)
    throw("Cannot compute unitialized game")
end
