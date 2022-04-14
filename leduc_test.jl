push!(LOAD_PATH, join([pwd(), "utils"], "/"))
# push!(LOAD_PATH, pwd())
push!(LOAD_PATH, join([pwd(), "games"], "/"))
push!(LOAD_PATH, join([pwd(), "solving"], "/"))

using StaticArrays
using Random
using Setfield

using leduc
using games
using playing

struct Test <: GameSetup
end

@inline function message(id::UInt8, gs::LeDucGameState)

    if id == CHECK_ID
        return string("Check")
    elseif id == FOLD_ID
        return string("Fold")
    elseif id == CALL_ID
        return string("Call ")
    elseif id == BET_ID
        return string("Bet ", gs.round * 2)
    elseif id == RAISE_ID
        return string("Raise ", gs.round * 2)
    end
end

@inline function sampleaction!(acts::StaticVector{A, T}) where {A, T<:Integer}
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

@inline function chooseaction!(gs::LeDucGameState{Test}, mask::SVector{5, UInt8})
    # todo provide a function for displaying actions names
    println("Choose action ")
    acts = actions!(gs)

    println(mask)

    #display available actions
    for (i, j) in enumerate(mask)
        if j != 0
            println("Press ", i, " to ", message(j, gs))
        end
    end

    try
        i = parse(Int, readline())
        if i > 5 || i < 1
            println("Invalid input ")
            return chooseaction!(gs, mask)
        else
            return mask[i]
        end
    catch
        println("Invalid input")
        return chooseaction!(gs, mask)
    end
end

const RANKS = Dict{UInt8, UInt8}(1=>1, 2=>1, 3=>2, 4=>2, 5=>3, 6=>3)

function start()
    deck = @SVector UInt8[1, 1, 2, 2, 2, 2]

    game = LeDucGame(UInt8, deck)
    gs = LeDucGameState(game, Test())

    mp = game.players[1]

    game.players = shuffle(game.players)

    println("Players ", game.players)

    gs = setplayer(gs, game.players[1])

    deck_idx = collect(1:6)

    shuffle!(deck_idx)

    private_cards = game.private_cards
    
    i = 1

    for ps in game.players
        private_cards[ps] = deck[deck_idx[i]]

        # if ps == mp
        #     game.pc_idx = deck_idx[i]
        # end
        
        i += 1
    end

    println("Cards: ", private_cards[1], " ", private_cards[2])
    
    actions, n_actions = legalactions!(UInt8, gs)

    gs = placebets(gs, SVector{2, UInt8}(1, 1))

    public_card = UInt8(0)

    #todo: must post blinds!

    while true

        cp = gs.player

        if terminal!(gs) == true
            states = gs.players_states

            c1 = private_cards[1]
            c2 = private_cards[2]

            println("Board ", public_card)

            if RANKS[c1] == RANKS[public_card] || states[1] == true && states[2] == false || RANKS[c1] > RANKS[c2]
                println("You Won! ", Int(gs.pot), " Opponent Lost ", Int(gs.bets[2]))
            elseif c2 == public_card || states[1] == false && states[2] == true || c1 < c2
                println("You Lost! ", Int(gs.bets[1]), " Opponent Won ", Int(gs.pot))
            elseif c1 == c2
                println("Draw! ", gs.pot/2)
            end
            
            rotateplayers!(game)
    
            shuffle!(deck_idx)
            
            i = 1

            for ps in game.players
                private_cards[ps] = deck[deck_idx[i]]

                # if ps == mp
                #     game.pc_idx = deck_idx[i]
                # end
                
                i += 1
            end

            #each player places a bet    
            gs = placebets(leduc.reset(gs), SVector{2, UInt8}(1, 1))

        elseif chance!(gs) == true
            println("Next Round! ")
            gs = leduc.nextround!(gs, cp)
        
        else
            if cp == mp
                a = chooseaction!(gs, actions)
            else
                a = chooseaction!(gs, actions)
            end
    
            gs = perform(action(gs, a), gs, cp)

            println("Pot ", gs.pot)
            println("Player ", Int(cp), " Performed ", message(a, gs))

        end

        public_card = deck[deck_idx[4]]
        actions, n_actions = legalactions!(UInt8, gs)

    end
end