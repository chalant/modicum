module games

export Game
export GameState
export Started
export Ended
export SharedData
export GameSetup
export game

export setup
export shared
export bigblind
export smallblind
export update!
export privatecards
export viewactions

using Reexport
using Random

include("../games/players.jl")
include("../games/actions.jl")

@reexport using .actions
@reexport using .players

#invariant data (only created once)
struct GameSetup
    small_blind::SmallBlind
    big_blind::BigBlind
    actions::Tuple{Vararg{Action}}

    num_private_cards::Int
    num_public_cards::Int
    num_players::Int
    num_rounds::Int
end

#mutable shared data
mutable struct SharedData
    #updated once per round
    deck::Vector{UInt64}
    public_cards::Vector{UInt64}
    private_cards::Dict{Int, Vector{UInt64}}
    updates::Vector{Bool}
    players_queue::Vector{Player}
end

abstract type GameState end

struct Initializing <: GameState
end

struct Started <: GameState
end

struct Ended <: GameState
end

mutable struct Game
    state::GameState
    initializing::Initializing
    started::Started
    ended::Ended

    setup::GameSetup
    shared::SharedData

    action::Action
    actions_mask::BitArray

    deck_cursor::Int

    player::Player
    active_players::Int
    players_states::Vector{PlayerState}

    round::Int
    position::Int
    pot_size::Float32
    last_bet::Float32
    num_actions::Int
    turns::Int

    Game() = new()
end

const INIT = Initializing()
const STARTED = Started()
const ENDED = Ended()

function shared(setup::GameSetup, deck::Vector{UInt64})
    players_queue = Vector{Player}(undef, setup.num_players)

    for i in 1:setup.num_players
        player = Player(i)
        players_queue[i] = player
    end

    return SharedData(
        deck,
        Vector{UInt64}(),
        Dict{Int, Vector{UInt64}}([
            (player.id, Vector{UInt64}(undef, setup.num_private_cards))
            for player in  players_queue]),
        Vector{Bool}([false for _ in 1:setup.num_rounds]),
        players_queue,
    )
end

function game(setup::GameSetup, shared_data::SharedData)
    g = Game()
    g.state = INIT
    g.started = STARTED
    g.ended = ENDED
    g.setup = setup
    g.shared = shared_data

    states = Vector{PlayerState}(undef, length(shared_data.players_queue))

    for (i, pl) in enumerate(shared_data.players_queue)
        ps = PlayerState()
        ps.id = pl.id
        ps.active = true
        states[i] = ps
    end

    g.players_states = states

    return g
end

function setup(
    sb::SmallBlind,
    bb::BigBlind,
    actions::Vector{Action},
    num_private_cards::Int,
    num_public_cards::Int,
    num_players::Int,
    num_rounds::Int
)
    sort!(actions)
    return GameSetup(
        sb,
        bb,
        tuple(actions...),
        num_private_cards,
        num_public_cards,
        num_players,
        num_rounds
    )
end

function setup(game::Game)
    return game.setup
end

function shared(game::Game)
    return game.shared
end

function privatecards(player::Player, data::SharedData)
    return data.private_cards[player.id]
end

function publiccards(game::Game)
    return shared(game).public_cards
end

function bigblind(setup::GameSetup)
    return setup.big_blind
end

function bigblind(game::Game)
    return bigblind(game.setup)
end

function smallblind(setup::GameSetup)
    return setup.small_blind
end

function smallblind(game::Game)
    return smallblind(game.setup)
end

function viewactions(game::Game)
    return setup(game).actions
end

function _copy!(dest::Game, src::Game)
    dest.state = game.state
    dest.setup = game.setup
    dest.shared = game.shared
    dest.deck_cursor = game.deck_cursor
end

function Base.copy(game::Game)
    c = Game()
    _copy!(c, game)
    c.actions_mask = copy(actions_mask)
    c.players_states = copy(game.players_states)
    return c
end

function Base.copy!(dest::Game, src::Game)
    _copy!(dest, src)
    copy!(dest.actions_mask, src.actions_mask)
    copy!(dest.players_states, game.players_states)
end

function update!(game::Game, data::SharedData, state::Started)
end

function update!(game::Game, data::SharedData, state::Ended)
    #re-arrange players
    queue = data.players_queue
    push!(queue, popfirst!(queue))
end

function update!(game::Game, state::Started)

end

function update!(game::Game, state::Ended)
    update!(game, shared(game), state)
end

end
