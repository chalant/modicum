module games

export Game
export GameState
export SharedData
export GameSetup

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

using Reexport
using Random
using Classes

include("players.jl")
include("actions.jl")

@reexport using .actions
@reexport using .players

#invariant data (only created once)

# todo: small blind and big blinds can change throughout a game
# move them to the game
struct GameSetup
    small_blind::SmallBlind
    big_blind::BigBlind
    actions::Vector{Action}
    players::Vector{Player} #list of players

    num_private_cards::Int
    num_public_cards::Int
    num_players::Int
    num_rounds::Int
    chips::Int
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

struct Terminated <: GameState
end

abstract type GameMode end

struct Game{T<:GameMode}
    state::GameState
    initializing::Initializing
    started::Started
    ended::Ended
    terminated::Terminated

    setup::GameSetup # game setup (invariant)
    shared::SharedData # data shared by all games
    mode::T

    action::Action
    actions_mask::BitArray

    player::PlayerState
    players_states::Vector{PlayerState}

    deck_cursor::UInt8 # tracks position on deck
    active_players::UInt8 # players that have not folded
    round::UInt8
    position::UInt8 # tracks current turn
    pot_size::Float32 #
    last_bet::Float32
    num_actions::UInt8
    all_in::UInt8 # cumulative all-ins (updated at the end of a round)
    r_all_in::UInt8 # current round all ins
    turn::Bool # flags if the small blind has played

    Game{T}() = new()
end

struct DepthLimited <: GameMode
    limit::UInt8
end

struct Normal <: GameMode
end

const INIT = Initializing()
const STARTED = Started()
const ENDED = Ended()
const TERMINATED = Terminated()

@inline function shared(st::GameSetup, deck::Vector{UInt64})
    return SharedData(
        deck,
        Vector{UInt64}(),
        Dict{Int, Vector{UInt64}}([
            (p.id, Vector{UInt64}(undef, stp.num_private_cards))
            for p in stp.players]),
        Vector{Bool}([false for _ in 1:stp.num_rounds]))
end

function game(stp::GameSetup, data::SharedData, mode::T=Normal()) where T <: GameMode
    # note: each root game should have its own shared data, copies of the root
    # share the same data
    g = Game{T}()
    g.state = INIT
    g.started = STARTED
    g.ended = ENDED
    g.setup = stp
    g.shared = data

    states = Vector{PlayerState}(undef, length(data.players_queue))

    i = 1
    for pl in keys(data.private_cards)
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

function setup(
    sb::SmallBlind,
    bb::BigBlind,
    actions::Vector{Action},
    num_private_cards::Int,
    num_public_cards::Int,
    num_players::Int,
    num_rounds::Int,
    chips::Int=1000,
)
    sort!(actions)
    return GameSetup(
        sb,
        bb,
        actions,
        num_private_cards,
        num_public_cards,
        num_players,
        num_rounds,
        chips
    )
end

@inline function setup(game::Game)
    return game.setup
end

@inline function setup(g::GameExtension)
    return setup(g.g)
end

@inline function shared(g::GameExtension)
    return shared(g.g)
end

@inline function shared(game::Game)
    return game.shared
end

@inline function privatecards(player::Player, data::SharedData)
    return data.private_cards[player.id]
end

@inline function privatecards(ps::PlayerState, data::SharedData)
    return data.private_cards[ps.id]
end

@inline function publiccards(game::Game)
    return shared(game).public_cards
end


@inline function playerstate(g::Game)
    return g.player
end

@inline function chips(g::Game)
    return playerstate(g).chips
end

@inline function bigblind(setup::GameSetup)
    return setup.big_blind
end

@inline function bigblind(game::Game)
    return bigblind(game.setup)
end

@inline function smallblind(setup::GameSetup)
    return setup.small_blind
end

@inline function smallblind(game::Game)
    return smallblind(game.setup)
end

@inline function viewactions(game::Game)
    return setup(game).actions
end

function _copy!(dest::Game, src::Game)
    _copy!(dest, src, src.shared, src.setup)
end

function _copy!(dest::Game, src::Game, sh::SharedData, stp::GameSetup)
    #referencess
    dest.state = src.state
    dest.setup = stp
    dest.shared = sh
    dest.mode = src.mode

    #values
    dest.deck_cursor = src.deck_cursor
    dest.active_players = src.active_players
    dest.round = src.round
    dest.position = src.position
    dest.pot_size = src.pot_size
    dest.last_bet = src.last_bet
    dest.all_in = src.all_in
    dest.r_all_in = src.r_all_in
    dest.turn = src.turn

end

function Base.copy(game::Game)
    return copy(game, game.shared, game.setup)
end

function Base.copy(g::Game, sh::SharedData, stp::GameSetup)
    dest = Game()
    _copy!(c, game, sh, stp)
    dest.actions_mask = copy(game.actions_mask)
    dest.players_states = copy(game.players_states)
    return dest
end

function Base.copy(g::Game, sh::SharedData,)
    dest = Game()
    _copy!(c, game, sh, g.setup)
    dest.actions_mask = copy(game.actions_mask)
    dest.players_states = copy(game.players_states)
    return dest
end

function Base.copy!(dest::Game, src::Game, sh::SharedData, stp::GameSetup)
    _copy!(dest, src, sh, stp)
    copy!(dest.actions_mask, src.actions_mask)
    copy!(dest.players_states, game.players_states)
end

function Base.copy!(dest::Game, src::Game, sh::SharedData)
    _copy!(dest, src, sh, src.setup)
    copy!(dest.actions_mask, src.actions_mask)
    copy!(dest.players_states, game.players_states)
end

function Base.copy!(dest::Game, src::Game)
    copy!(dest, src, src.shared, src.setup)
end

function Base.copy(shr::SharedData)
    return SharedData(
        setdiff(shr.deck, shr.public_cards),
        copy(shr.public_cards),
        copy(private_cards),
        [false for _ in 1:length(shr.updated)])
end

end