include("rpc/PokerClients.jl")
include("games/games.jl")

using .PokerClients
using .players

using ProtoBuf

const GAME_SETUP = GameSetup()

function start()

    #load blueprint strategy
    #load actions (we used to create the blueprint strategy)

    #read initial data from iostream

    data = read(stdin, )

    iob = PipeBuffer(data)

    append!(iob, data)

    data = readproto(data, InitialData())

    #establish connection with the rpc server

    client = PokerServiceBlockingClient(data.url)

    #initialize blinds

    #sort players by dealer, where the last player is the dealer and the first player
    # is the smallblind

    #if num players == 2, play in heads up mode.

    # get main player cards (remove them from our deck)

    ply_vec = Vector{PlayerState}()

    dealer = data.dealer
    dpos = dealer.position - 1

    num_players = length(data.players_state)

    #initialize players data (use data to create PlayerState struct)

    for ps in data.players_state
        pl = Player()
        pls = PlayerState()

        pls.player = pl
        pl.position = ps.player.position
        pls.chips = ps.chips #set initial chips
        pls.bet = 0.0
        pls.total_bet = 0.0
        pls.pot = 0.0
        pls.active = true

        push!(ply_vec, pls)
    end

    #rearrange so that the dealer is last.

    m = dealer.position + 1

    #only rearrange players if the dealer is not the last player
    if m != num_players
        for i in 1:num_players - m
            pushfirst!(a, pop!(ply_vec))
        end
    end

    a = Action_ActionType

    while true

        # if next player to act is us, perform action, else,
        # get opponents action.

        # g.player

        #this will block until we receive a response

        #note: map action types to internal action ids

        # create and send player data

        action, status_future = GetPlayerAction(client, PlayerData())

        if action.action_type == a.BET

        end

    end

end

start()