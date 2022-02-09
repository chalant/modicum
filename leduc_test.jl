push!(LOAD_PATH, join([pwd(), "utils"], "/"))
# push!(LOAD_PATH, pwd())
push!(LOAD_PATH, join([pwd(), "games"], "/"))

using StaticArrays
using Random

using leduc
using games
using playing

mutable struct Test <: GameSetup
    chips::Float32
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

@inline function message(action::LeDucAction, gs::LeDucGameState)
    id = action.id

    if id == CHECK_ID
        return string("Check")
    elseif id == FOLD_ID
        return string("Fold")
    elseif id == CALL_ID
        return string("Call ", gs.round * 2)
    elseif id == BET_ID
        return string("Bet ", gs.round * 2)
    elseif id == RAISE_ID
        return string("RAISE ", gs.round * 2)
    end
end

@inline function chooseaction!(gs::LeDucGameState{Test}, mask::MVector{5, Bool})
    # todo provide a function for displaying actions names
    println("Choose action ")
    acts = actions!(gs)

    println(mask)

    #display available actions
    for (i, (act, j)) in enumerate(zip(acts, mask))
        if j == 1
            println("Press ", i, " to ", message(act, gs))
        end
    end

    try
        i = parse(Int, readline())
        if i > 5 || i < 1
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

function start()
    stp = Test(10)
    deck = @SVector UInt8[1, 1, 2, 2, 3, 3]

    game = LeDucGame{SVector{6, UInt8}}(deck)
    gs = LeDucGameState{Test}(game)

    mp = game.players[1]

    shuffle!(game.players)

    gs.player = game.players[1]
    
    acts = actions!(game)

    deck_idx = collect(1:6)

    shuffle!(deck_idx)

    private_cards = game.private_cards
    
    i = 1

    for ps in game.players
        private_cards[ps] = deck[deck_idx[i]]

        if ps == mp
            game.pc_idx = deck_idx[i]
        end
        
        i += 1
    end

    println("Cards: ", private_cards[1], " ", private_cards[2])
    
    state = initialstate(gs)
    mask = actionsmask!(gs)

    gs.pot += 2
    
    for i in eachindex(gs.bets)
        gs.bets[i] += 1
    end

    #todo: must post blinds!

    while true

        cp = gs.player

        if cp == mp
            a = chooseaction!(gs, mask)
        else
            a = acts[sampleaction!(mask)]
        end

        println("Player ", Int(cp), " Performed ", message(a, gs))

        state = perform!(a, gs, cp)

        if terminal!(gs, state) == true
            states = gs.players_states

            c1 = private_cards[1]
            c2 = private_cards[2]
            public_card = gs.public_card

            println("Board ", public_card)

            if c1 == public_card || states[1] == true && states[2] == false || c1 > c2
                println("You Won! ", Int(gs.pot))
            elseif c2 == public_card || states[1] == false && states[2] == true || c1 < c2
                println("You Lost! ", Int(gs.bets[1]))
            elseif c1 == c2
                println("Draw! ", gs.pot/2)
            end
            
            rotateplayers!(game)

            reset!(gs)
    
            shuffle!(deck_idx)
            
            i = 1

            for ps in game.players
                private_cards[ps] = deck[deck_idx[i]]

                if ps == mp
                    game.pc_idx = deck_idx[i]
                end
                
                i += 1
            end

            gs.pot += 2
            
            for i in eachindex(gs.bets)
                gs.bets[i] += 1
            end

        end

        if chance!(gs, state) == true
            performchance!(LeDucChanceAction(1, deck_idx[4]), gs, cp)
        end

        mask = actionsmask!(gs)
    end
end