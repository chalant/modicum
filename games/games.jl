module games

export Game
export GameState
export SharedData
export GameSetup
export GameMode
export GameType
export Full
export DepthLimited
export Simulation
export RealTime
export Estimation

export Initializing
export Started
export Ended
export Terminated

export game
export setup
export shared
export bigblind
export smallblind
export update!
export privatecards
export viewactions
export chips
export limit

using Reexport
using Random

include("players.jl")

@reexport using .players

abstract type GameType end
abstract type GameMode end
abstract type Estimation end

struct Full <: GameType
end

struct DepthLimited{T<:Estimation} <: GameType
    limit::UInt8
    estimation::T # method for estimating utility (NN, MC Rollouts...)
end

struct Simulation <: GameMode
end

struct LiveSimulation <: GameMode
end

struct Live <: GameMode
end
#invariant data (only created once)

# todo: small blind and big blinds can change throughout a game
# move them to the game
mutable struct GameSetup{T<:GameMode}
    players::Dict{ID, Player} #list of players
    main_player::Player

    sb::SmallBlind
    bb::BigBlind

    num_private_cards::Int
    num_public_cards::Int
    num_players::Int
    num_rounds::Int
    chips::Float32

    cards_per_round::Vector{UInt8}

    GameSetup{T}() = new()
end

#mutable shared data
mutable struct SharedData{T<:GameType, U<:GameMode}
    #updated once per round
    deck::Vector{UInt64}
    public_cards::Vector{UInt64}
    private_cards::Dict{ID, Vector{UInt64}}

    deck_cursor::UInt8 # tracks position on deck
    g::Game{T,U} # tracks root game
    updates::Vector{Bool}
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

struct Game{T<:GameType, U<:GameMode}
    state::GameState
    initializing::Initializing
    started::Started
    ended::Ended
    terminated::Terminated

    setup::GameSetup{U} # game setup (invariant)
    shared::SharedData # data shared by all games

    action::Action # previous action
    tp::T

    player::PlayerState
    players_states::Vector{PlayerState}

    active_players::UInt8 # players that have not folded
    round::UInt8
    position::UInt8 # tracks current turn
    pot_size::Float32 #
    last_bet::Float32
    num_actions::UInt8
    all_in::UInt8 # cumulative all-ins (updated at the end of a round)
    r_all_in::UInt8 # current round all ins
    turn::Bool # flags if the small blind has played

    Game{T,U}() = new()
end

const INIT = Initializing()
const STARTED = Started()
const ENDED = Ended()
const TERMINATED = Terminated()

function limit(dl::DepthLimited{T}, stp::GameSetup{U}) where {T<:Estimation, U<:GameMode}
    return dl.limit
end

function limit(dl::Full, stp::GameSetup{U}) where {U<:GameMode}
    return stp.num_rounds
end

function shared(
    g::Game{T,U},
    stp::GameSetup{U},
    deck::Vector{UInt64}) where {T<:GameType, U<:GameMode}

    return SharedData{T,U}(
        deck,
        Vector{UInt64}(),
        Dict{ID, Vector{UInt64}}([(p, Vector{UInt64}(undef, stp.num_private_cards)) for p in keys(stp.players)]),
        length(deck),
        g,
        Vector{Bool}([false for _ in 1:stp.num_rounds]))
end

function game(::Type{U}, gt::T) where {T<:GameType,U<:GameMode}
    g = Game{T,U}()
    g.state = INIT
    g.started = STARTED
    g.ended = ENDED
    g.setup = stp
    g.shared = data
    g.tp = gt
end

function game(data::SharedData)
    return data.g
end

function game(stp::GameSetup{U}, gt::T) where {T <: GameType, U <: GameMode}
    states = Vector{PlayerState}(undef, length(stp.players))
    g = game(U,gt)
    i = 1
    for pl in keys(stp.players)
        ps = PlayerState()
        ps.id = pl
        ps.active = true
        ps.rank = Int16(7463)
        states[i] = ps
        i += 1
    end
    g.players_states = states
    return g
end


function game(stp::GameSetup{U}, data::SharedData{T,U}, tp::T) where {T <: GameType, U <: GameMode}
    g = game(U,gt)
    g.players_states = game(data).players_states
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
    chips::Float32=1000) where T<:GameMode

    stp = GameSetup{T}()
    stp.sb = sb
    stp.bb = sb
    stp.t = t
    stp.num_private_cards = num_private_cards
    stp.num_public_cards = num_public_cards
    stp.num_players = num_players
    stp.num_rounds = num_rounds
    stp.chips = chips
    stp.cards_per_round

    return stp
end

setup(game::Game) = game.setup

shared(game::Game) = game.shared

privatecards(player::Player, data::SharedData) = data.private_cards[player.id]
privatecards(ps::PlayerState, data::SharedData) = data.private_cards[ps.id]

publiccards(game::Game) = shared(game).public_cards

playerstate(g::Game) = g.player

chips(g::Game) = playerstate(g).chips

bigblind(setup::GameSetup) = setup.big_blind
bigblind(game::Game) = bigblind(game.setup)

smallblind(setup::GameSetup) = setup.small_blind
smallblind(game::Game) = smallblind(game.setup)

viewactions(g::Game, ps::PlayerState) = viewactions(setup(g).players[ps.id])

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
    dest.r_all_in = src.r_all_in
    dest.turn = src.turn

end

Base.copy(g::Game) = copy(g, g.shared, g.setup)
Base.copy(g::Game, sh::SharedData) = copy(g, g.shared, g.setup)


function Base.copy(g::Game{T}, sh::SharedData{T,U}, stp::GameSetup{U}) where {T<:GameType, U<:GameMode}
    dest = Game{T,U}()
    _copy!(c, game, sh, stp)
    dest.players_states = copy(game.players_states)
    return dest
end

function Base.copy!(dest::Game, src::Game, sh::SharedData, stp::GameSetup)
    _copy!(dest, src, sh, stp)
    copy!(dest.players_states, src.players_states)
end

function Base.copy!(dest::Game, src::Game, sh::SharedData) T<:GameType
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