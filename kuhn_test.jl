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

@inline function message(id::UInt8)

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

@inline function chooseaction!(gs::KUHNGameState{Test}, mask::SVector{4, UInt8})
    # todo provide a function for displaying actions names
    println("Choose action ")

    println(mask)

    #display available actions
    for (i, j) in enumerate(mask)
        if j == 1
            println("Press ", i, " to ", message(j))
        end
    end

    try
        i = parse(Int, readline())
        if i > 4 || i < 1
            println("Invalid input ")
            return chooseaction!(gs, mask)
        else
            return action(gs, mask[i])
        end
    catch
        println("Invalid input")
        return chooseaction!(gs, mask)
    end
end

@inline function sampleaction!(acts::SVector{4, UInt8})
    t = rand()

    a = 1
    cum_prob = 0.0

    while a < 2
        cum_prob += 0.5

        if t < cum_prob
            break
        end

        a += 1
    end

    return acts[a]

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

    game = KUHNGame{MVector{3, UInt8}}(MVector{3, UInt8}(1, 2, 3))

    stp = Test(10)

    mp = game.players[1]

    shuffle!(game.players)

    gs = KUHNGameState{Test}(game)
    
    acts = actions!(game)

    deck = copy(game.deck)

    shuffle!(deck)
    
    cards = @MVector zeros(UInt8, 2)
    
    private_cards = game.private_cards

    sample!(deck, cards)

    println("Cards ", cards)

    i = 1
    
    for ps in game.players
        private_cards[ps] = cards[i]
        
        i += 1
    end

    println("Cards: ", private_cards[1], " ", private_cards[2])
    
    mask, n_actions = legalactions!(UInt8, gs)

    while true

        cp = gs.player
        
        println("Current Player ", Int(cp))

        if cp == mp
            a = chooseaction!(gs, mask)
        else
            a = action(gs, sampleaction!(mask))
        end

        println("Performed ", a)

        gs = perform(a, gs, cp)

        if terminal!(gs) == true

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
            
            gs = rotateplayers!(gs)

            sample!(deck, cards)

            gs = reset!(gs)
    
            i = 1
            
            for ps in game.players
                private_cards[ps] = cards[i]
                
                i += 1
            end
        end

        mask, n_actions = legalactions!(UInt8, gs)

    end
    

end