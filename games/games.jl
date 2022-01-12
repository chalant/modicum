module games

export AbstractGame
export Game
export GameState
export SharedData
export GameSetup
export GameMode
export GameLength
export Full
export DepthLimited
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

abstract type GameLength end
abstract type RunMode end
abstract type Estimation end
abstract type GameMode  end

struct Full <: GameLength
end


abstract type GameSetup end

struct HeadsUp <: GameMode
    num_players::UInt8

    HeadsUp() = new(UInt8(2))
end

struct Normal <: GameMode
    num_players::UInt8

    Normal(num_players) = num_players == 2 ? HeadsUp() : new(num_players)

end

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
mutable struct SharedData

    sb::Float32
    bb::Float32

    #updated once per round
    deck::Vector{UInt64}
    public_cards::Vector{UInt64}
    private_cards::Vector{Vector{UInt64}}

    deck_cursor::UInt8 # tracks position on deck
#     g::Game{T,U}# tracks root game
    updates::Vector{Bool}

    SharedData()= new()

end

abstract type AbstractGame end
abstract type AbstractGameState end

# todo: small blind and big blinds can change throughout a game
# move them to the game
mutable struct Game{T<:GameSetup} <: AbstractGame
    players::Vector{Player} #mapping of players
    main_player::Player

    game_setup::T
    
    shared_state::SharedData

    num_rounds::UInt8
    num_private_cards::UInt8
    num_public_cards::UInt8
    chips::Float32

    actions::ActionSet

    cards_per_round::Vector{UInt8}

    Game{T, U}() where {T<:GameSetup, U <: GameMode} = new()
end

#tracks game state.

mutable struct GameState{A, P, T<:AbstractGame} <: AbstractGameState
    state::UInt8

    action::Action

    player::PlayerState
    prev_player::PlayerState
    bet_player::PlayerState

    players_states::SizedArray{P, PlayerState}
    actions_mask::MVector{A, Bool}

    active_players::UInt8 # players that have not folded
    round::UInt8
    position::UInt8 # tracks current turn
    all_in::UInt8 # players that went all-in
#     turn::Bool # flags if the small blind has played

    pot_size::Float32 #
    last_bet::Float32 # tracks last bet
    last_raise::Float32
    total_bet::Float32

    game::T

    GameState{N, T}() where T <: AbstractGame = new()
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

@inline function privatecards(player::Player, g::Game{T, U}) where {T <: GameSetup, U <: GameMode}
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

@inline function Base.copy(shr::SharedData, pl::PlayerState)
    return SharedData(
        setdiff(shr.deck, shr.public_cards, privatecards(pl, shr)),
        copy(shr.public_cards),
        copy(shr.private_cards),
        [false for _ in 1:length(shr.updated)])
end

end