push!(LOAD_PATH, join([pwd(), "utils"], "/"))
# push!(LOAD_PATH, pwd())
push!(LOAD_PATH, join([pwd(), "games"], "/"))
push!(LOAD_PATH, join([pwd(), "games/kuhn"], "/"))

using kuhn
using games

using Random
using IterTools
using StatsBase
using StaticArrays

mutable struct Test <: GameSetup
    chips::Float32
end

@inline function message(action::KUHNAction)
    id = action.id

    if id == CHECK_ID
        return string("Check")
    elseif id == FOLD_ID
        return string("Fold")
    elseif id == CALL_ID
        return string("Call ", 1)
    elseif id == BET_ID
        return string("Bet ", 1)
    end
end

@inline function chooseaction!(gs::KUHNGameState{Test})
    # todo provide a function for displaying actions names
    println("Choose action ")
    acts = actions!(gs)

    println(gs.actions_mask)

    #display available actions
    for (i, (act, j)) in enumerate(zip(acts, gs.actions_mask))
        if j == 1
            println("Press ", i, " to ", message(act))
        end
    end

    try
        i = parse(Int, readline())
        if i > 4 || i < 1
            println("Invalid input ")
            return chooseaction!(gs)
        else
            return acts[i]
        end
    catch
        println("Invalid input")
        return chooseaction!(gs)
    end
end

@inline function sampleaction!(wv::AbstractVector{Bool})
    n = length(wv)
    t = rand()
    i = 1
    cw = 0

    #count active actions (could use game.num_actions instead)
    c = 0
    
    for j in 1:n
        if @inbounds wv[j] == 1
            c += 1
        end
    end

    while i < n
        @inbounds cw += wv[i]/c

        if t < cw
            break
        end

        i += 1
    end

    return i
end

function start()

    game = KUHNGame()

    stp = Test(10)
    gs = KUHNGameState{Test}(game)

    mp = gs.players_states[1]

    shuffle!(gs.players_states)

    gs.player = gs.players_states[1]

    println("Players States ", gs.players_states)
    
    acts = actions!(game)

    deck = getdeck()

    shuffle!(deck)
    
    cards = @MVector zeros(UInt8, 2)

    sample!(deck, cards)
    
    private_cards = @MVector zeros(UInt8, 2)

    i = 1
    
    for ps in gs.players_states
        private_cards[ps.id] = cards[i]
        
        i += 1
    end

    while true
        cp = gs.player
        println("Current Player ", Int(cp.id))
        
        if cp == mp
            a = chooseaction!(gs)
        else
            a = acts[sampleaction!(gs.actions_mask)]
        end

        println("Performed ", message(a))

        perform!(a, gs, cp)

        if terminal!(gs) == true

            c1 = private_cards[1]
            c2 = private_cards[2]

            if c1 > c2
                println("You Won! ", gs.pot)
            elseif c1 < c2
                println(("You Lost! ", mp.bet))
            else
                println("Draw! ", gs.pot/2)
            end
            
            rotateplayers!(gs)

            sample!(deck, cards)
    
            i = 1
            
            for ps in gs.players_states
                private_cards[ps.id] = cards[i]
                
                i += 1
            end

            gs.state = STARTED_ID
            gs.pot = 0
            mp.bet = 0

            gs.player = gs.players_states[1]
            gs.action = NULL_ID
            
            gs.actions_mask[1] = 1
            gs.actions_mask[2] = 0
            gs.actions_mask[3] = 1
            gs.actions_mask[4] = 0
            
            gs.position = UInt8(1)

        end

    end
    

end