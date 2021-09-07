module games

export Game
export GameState
export SharedData
export GameSetup
export RunMode
export GameLength
export Full
export DepthLimited
export Simulation
export LiveSimulation
export Live
export Estimation
export Normal
export HeadsUp

export Initializing
export Started
export Ended
export Terminated

export INIT
export STARTED
export ENDED
export TERMINATED

export game
export creategame
export setup
export shared
export bigblind
export smallblind
export update!
export privatecards
export viewactions
export chips
export limit
export playerstate

using Reexport
using Random

include("players.jl")

@reexport using .players

abstract type GameLength end
abstract type RunMode end
abstract type Estimation end
abstract type GameMode end

struct Full <: GameLength
end

struct DepthLimited{T <: Estimation} <: GameLength
    limit::UInt8
    estimation::T # method for estimating utility (NN, MC Rollouts...)
end

struct Simulation <: RunMode
end

struct LiveSimulation <: RunMode
end

struct Live <: RunMode
end

struct HeadsUp <: GameMode
end

struct Normal <: GameMode
end

#invariant data (only created once)

# todo: small blind and big blinds can change throughout a game
# move them to the game
mutable struct GameSetup
    players::Vector{Player} #mapping of players
    main_player::Player

    sb::SmallBlind
    bb::BigBlind

    num_private_cards::Int
    num_public_cards::Int
    num_players::Int
    num_rounds::Int
    chips::Float32

    actions::ActionSet

    cards_per_round::Vector{UInt8}

    GameSetup() = new()
end

abstract type GameState end

struct Initializing <: GameState
end

struct Started <: GameState
end

struct Ended <: GameState
end

struct Terminated <: GameState
end

#mutable shared data
mutable struct SharedData
    #updated once per round
    deck::Vector{UInt64}
    public_cards::Vector{UInt64}
    private_cards::Vector{Vector{UInt64}}

    deck_cursor::UInt8 # tracks position on deck
#     g::Game{T,U}# tracks root game
    updates::Vector{Bool}

    SharedData()= new()

end

mutable struct Game
    state::GameState
    initializing::Initializing
    started::Started
    ended::Ended
    terminated::Terminated

    setup::GameSetup
    shared::SharedData

    action::Type{T} where T <: Action # previous action

    tp::GameLength
    gm::Type{T} where T <: GameMode

    player::PlayerState
    prev_player::PlayerState
    players_states::Vector{PlayerState}
    bet_player::PlayerState

    active_players::UInt8 # players that have not folded
    round::UInt8
    position::UInt8 # tracks current turn
    pot_size::Float32 #
    last_bet::Float32 # tracks last bet
    last_raise::Float32
    total_bet::Float32
    all_in::UInt8 # players that went all-in
#     turn::Bool # flags if the small blind has played

    Game() = new()
end

const INIT = Initializing()
const STARTED = Started()
const ENDED = Ended()
const TERMINATED = Terminated()

function limit(dl::DepthLimited, stp::GameSetup)
    return dl.limit
end

function limit(dl::Full, stp::GameSetup)
    return stp.num_rounds
end

function limit(game::Game, stp::GameSetup)
    return limit(game.tp, stp)
end

function creategame(
    data::SharedData,
    stp::GameSetup,
    tp::U) where U <: GameLength

    g = Game()
    g.state = INIT
    g.started = STARTED
    g.ended = ENDED
    g.setup = stp
    g.tp = tp

    if stp.num_players == 2
        g.gm = HeadsUp
    else
        g.gm = Normal
    end

    g.shared = data

    return g
end

function setup(
    ::Type{T},
    sb::SmallBlind,
    bb::BigBlind,
    num_private_cards::Int,
    num_public_cards::Int,
    num_players::Int,
    num_rounds::Int,
    cards_per_round::Vector{UInt8},
    chips::Float32=1000) where T <: RunMode

    stp = GameSetup()
    stp.sb = sb
    stp.bb = bb
    stp.num_private_cards = num_private_cards
    stp.num_public_cards = num_public_cards
    stp.num_players = num_players
    stp.num_rounds = num_rounds
    stp.chips = chips
    stp.cards_per_round = cards_per_round

    return stp
end

@inline setup(game::Game) = game.setup

@inline shared(game::Game) = game.shared

@inline privatecards(player::Player, data::SharedData) = data.private_cards[player.id]
@inline privatecards(ps::PlayerState, data::SharedData) = data.private_cards[id(ps)]

@inline publiccards(game::Game) = shared(game).public_cards

@inline playerstate(g::Game) = g.player

@inline chips(g::Game) = playerstate(g).chips

@inline bigblind(setup::GameSetup) = setup.bb
@inline bigblind(game::Game) = bigblind(game.setup)

@inline smallblind(setup::GameSetup) = setup.sb
@inline smallblind(game::Game) = smallblind(game.setup)

@inline function viewactions(game::Game)
    return setup(game).actions
end

@inline function viewactions(stp::GameSetup)
    return stp.actions
end

_copy!(dest::Game, src::Game) = _copy!(dest, src, src.shared, src.setup)

function _copy!(dest::Game, src::Game, sh::SharedData, stp::GameSetup)
    #referencess
    dest.state = src.state
    dest.setup = stp
    dest.shared = sh

    #values
    dest.active_players = src.active_players
    dest.round = src.round
    dest.position = src.position
    dest.pot_size = src.pot_size
    dest.last_bet = src.last_bet
    dest.all_in = src.all_in
#     dest.r_all_in = src.r_all_in
#     dest.turn = src.turn

end

Base.copy(g::Game) = copy(g, g.shared, g.setup)
Base.copy(g::Game, sh::SharedData) = copy(g, g.shared, g.setup)


function Base.copy(g::Game, sh::SharedData, stp::GameSetup)
    dest = Game()
    _copy!(c, game, sh, stp)
    dest.players_states = copy(game.players_states)
    return dest
end

function Base.copy!(dest::Game, src::Game, sh::SharedData, stp::GameSetup)
    _copy!(dest, src, sh, stp)
    copy!(dest.players_states, src.players_states)
end

function Base.copy!(dest::Game, src::Game, sh::SharedData)
    _copy!(dest, src, sh, src.setup)
    copy!(dest.players_states, src.players_states)
end

Base.copy!(dest::Game, src::Game) = copy!(dest, src, src.shared, src.setup)

function Base.copy(shr::SharedData, pl::PlayerState)
    return SharedData(
        setdiff(shr.deck, shr.public_cards, privatecards(pl, shr)),
        copy(shr.public_cards),
        copy(shr.private_cards),
        [false for _ in 1:length(shr.updated)])
end

end