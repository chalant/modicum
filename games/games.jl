module games

export Game
export AbstractGameState
export GameState
export SharedData
export GameSetup
export Simulation
export LiveSimulation
export Estimation
export Normal
export HeadsUp
export State

export INIT_ID
export STARTED_ID
export ENDED_ID
export TERM_ID

export INIT
export STARTED
export ENDED
export TERMINATED

export game!
export gamestate!
export actionsmask!
export setup
export shared
export bigblind
export smallblind
export update!
export privatecards
export actions!
export chips
export limit
export playerstate
export stateid
export numplayers!
export numrounds!
export playersstates!

using Random
using Parameters
using StaticArrays

using players
using actions

abstract type GameSetup end

struct Simulation <: GameSetup
end

struct LiveSimulation <: GameSetup
end

const INIT_ID = UInt8(0)
const STARTED_ID = UInt8(1)
const ENDED_ID = UInt8(2)
const TERM_ID = UInt8(3)
const CHANCE_ID = UInt8(4)

struct State
    id::UInt8
end

const INIT = State(INIT_ID)
const STARTED = State(STARTED_ID)
const ENDED = State(ENDED_ID)
const TERM = State(TERM_ID)

#mutable shared data
mutable struct SharedData{P, T<:AbstractFloat}

    sb::T
    bb::T

    #updated once per round
    deck::Vector{UInt64}
    burned::Vector{UInt64}
    public_cards::Vector{UInt64}
    private_cards::SizedVector{P, MVector{2, UInt64}}

    deck_cursor::UInt8 # tracks position on deck
#     g::Game{T,U}# tracks root game

    SharedData{P, T}() where {P, T<:AbstractFloat} = new()

end

abstract type AbstractGameState{A, S, P} end

# todo: small blind and big blinds can change throughout a game
# move them to the game
struct Game{T<:GameSetup, N, A, U<:AbstractFloat}
    players::SVector{N, Player} #mapping of players
    main_player::Player

    game_setup::T
    
    shared_state::SharedData{N, U}

    num_rounds::UInt8
    num_private_cards::UInt8
    num_public_cards::UInt8
    chips::U

    actions::ActionSet{A}

    cards_per_round::SVector{3, UInt8}

    Game{T, N, A, U}() where {T<:GameSetup, N, A, U} = new()
end

#tracks game state.

mutable struct GameState{A, P, S<:GameSetup, T<:AbstractFloat} <: AbstractGameState{A, P, S}
    state::UInt8

    action::Action

    player::PlayerState
    prev_player::PlayerState
    bet_player::PlayerState

    players_states::SizedVector{P, PlayerState}
    actions_mask::MVector{A, Bool}

    active_players::UInt8 # players that have not folded
    round::UInt8
    position::UInt8 # tracks current turn
    all_in::UInt8 # players that went all-in
#     turn::Bool # flags if the small blind has played

    pot_size::T #
    last_bet::T # tracks last bet
    last_raise::T
    total_bet::T

    game::Game{S, P, A, T}

    GameState{A, P, S, T}() where {A, P, S<:GameSetup, T} = new()
end

@inline function stateid(st::State)
        return st.id
end

@inline function Base.:(==)(st1::State, st2::State)
    return st1.id == st2.id
end

@inline function limit(g::Game)
    return g.num_rounds
end

@inline game!(gs::GameState) = gs.game

@inline setup(game::Game) = game.game_setup
@inline setup(gs::GameState) = setup(gs.game)

@inline shared(game::Game) = game.shared_state
@inline shared(gs::GameState) = shared(gs.game)

@inline _privatecards(player::Player, data::SharedData) = data.private_cards[player.id]
@inline _privatecards(ps::PlayerState, data::SharedData) = data.private_cards[players.id(ps)]

@inline function privatecards(player::Player, g::Game)
    return _privatecards(player, shared(g))
end

@inline publiccards(sh::SharedData) = sh.public_cards
@inline publiccards(game::Game) = shared(game).public_cards
@inline publiccards(gs::GameState) = shared(gs.game)

@inline playersstates!(gs::GameState) = gs.players_states

@inline playerstate(gs::GameState) = gs.player
@inline chips(gs::GameState) = playerstate(gs).chips

@inline bigblind(sh::SharedData) = sh.bb
@inline bigblind(g::Game) = bigblind(shared(g))
@inline bigblind(gs::GameState) = bigblind(gs.game)

@inline smallblind(sh::SharedData) = sh.sb
@inline smallblind(g::Game) = smallblind(shared(g))
@inline smallblind(gs::GameState) = smallblind(shared(gs))

@inline numrounds!(g::Game) = g.num_rounds
@inline numrounds!(gs::GameState) = numrounds!(gs.game)

@inline limit!(g::Game) = g.num_rounds
@inline limit!(gs::GameState) = limit!(gs.game)

@inline gamemode!(g::Game) = g.game_mode

@inline numplayers!(gm::T) where T <: GameMode = gm.num_players
@inline numplayers!(g::Game) = numplayers!(gamemode!(g))
@inline numplayers!(gs::GameState) = numplayers!(gs.game)

@inline actions!(g::AbstractGame) = g.actions
@inline actions!(g::Game) = g.actions
@inline actions!(gs::GameState) = actions!(game!(gs))

@inline actionsmask!(gs::GameState) = gs.actions_mask

@inline function _copy!(dest::GameState, src::GameState)
    #referencess
    dest.state = src.state
    dest.game = game!(src)

    #values
    dest.active_players = src.active_players
    dest.round = src.round
    dest.position = src.position
    dest.pot_size = src.pot_size
    dest.last_bet = src.last_bet
    dest.all_in = src.all_in
    dest.actions_mask = copy(src.actions_mask)
#     dest.r_all_in = src.r_all_in
#     dest.turn = src.turn

end

# @inline function Base.copy(src::GameState)
#     #todo: we need the type of game state and 
#     dest = GameState()
#     _copy!(dest, src)
#     dest.players_states = copy(src.players_states)
#     return dest
# end

@inline function Base.copy!(dest::GameState, src::GameState)
    _copy!(dest, src)
    copy!(dest.players_states, src.players_states)
end

end