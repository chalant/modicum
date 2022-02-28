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

@inline function chooseaction!(gs::KUHNGameState{Test}, mask::MVector{4, Bool})
    # todo provide a function for displaying actions names
    println("Choose action ")
    acts = actions!(gs)

    println(mask)

    #display available actions
    for (i, (act, j)) in enumerate(zip(acts, mask))
        if j == 1
            println("Press ", i, " to ", message(act))
        end
    end

    try
        i = parse(Int, readline())
        if i > 4 || i < 1
            println("Invalid input ")
            return chooseaction!(gs, mask)
        else
            return acts[i]
        end
    catch
        println("Invalid input")
        return chooseaction!(gs, mask)
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

    mp = game.players[1]

    shuffle!(game.players)

    gs.player = game.players[1]
    
    acts = actions!(game)

    deck = game.deck

    shuffle!(deck)
    
    cards = @MVector zeros(UInt8, 2)
    
    private_cards = game.private_cards

    sample!(deck, cards)

    i = 1
    
    for ps in game.players
        private_cards[ps] = cards[i]
        
        i += 1
    end

    println("Cards: ", private_cards[1], " ", private_cards[2])
    
    state = initialstate()
    mask = actionsmask!(gs)

    while true

        cp = gs.player
        
        println("Current Player ", Int(cp))

        if cp == mp
            a = chooseaction!(gs, mask)
        else
            a = acts[sampleaction!(mask)]
        end

        println("Performed ", message(a))

        state = perform(a, gs, cp)

        if terminal!(state) == true

            states = gs.players_states

            c1 = private_cards[1]
            c2 = private_cards[2]

            if states[1] == true && states[2] == false || c1 > c2
                println("You Won! ", Int(gs.pot))
            elseif states[1] == false && states[2] == true || c1 < c2
                println("You Lost! ", Int(gs.bets[1]))
            elseif c1 == c2
                println("Draw! ", gs.pot/2)
            end
            
            rotateplayers!(game)

            sample!(deck, cards)

            reset!(gs)
    
            i = 1
            
            for ps in game.players
                private_cards[ps] = cards[i]
                
                i += 1
            end
        end

        mask = actionsmask!(gs)
    
    end
    

end