module cards

export PRIMES,
    prime_product_from_hand,
    prime_product_from_rankbits,
    get_deck,
    new_card,
    pretty_print_cards

const PRIMES = Vector{UInt64}([2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41])
const str_ranks = Vector{String}(["2","3","4","5","6","7","8","9","T","J","Q","K","A"])

const char_rank_to_int_rank =
    Dict{String,UInt64}(zip(str_ranks, [i for i in 0:12]))

const suits = Vector{String}(["s", "h", "d", "c"])

const char_suit_to_int_suit = Dict{String,UInt64}(zip(suits, [1, 2, 4, 8]))

function prime_product_from_rankbits(rankbits::UInt64)
    product::UInt64 = 1
    for i in 0:12
        if rankbits & (1 << i) != 0
            product *= PRIMES[i + 1]
        end
    end
    return product
end


function prime_product_from_hand(card_ints::Vector{UInt64})
    product::UInt64 = 1
    for c in card_ints
        product *= (c & 0xFF)
    end
    return product
end

function prime_product_from_hand(card::UInt64)
    return 1 * (card & 0xFF)
end

function new_card(chars::String)
    chars = split(chars, "")

    rank_int = char_rank_to_int_rank[chars[1]]
    suit_int = char_suit_to_int_suit[chars[2]]

    rank_prime = PRIMES[rank_int + 1]

    bitrank = 1 << rank_int << 16
    suit = suit_int << 12
    rank = rank_int << 8

    return bitrank | suit | rank | rank_prime
end

function get_deck()
    return Vector{UInt64}([
        new_card(string(rank, suit)) for rank in str_ranks for suit in suits
    ])
end

function pretty_print_cards(cards::Vector{UInt64})
    pretty_suits = Dict{UInt64,String}(1 => "♠", 2 => "♡", 4 => "♢", 8 => "♣")

    function int_to_pretty_str(card::UInt64)

        suit_int = get_suit_int(card)
        rank_int = get_rank_int(card)

        return string(str_ranks[rank_int + 1], pretty_suits[suit_int])
    end

    function get_suit_int(card::UInt64)
        return (card >> 12) & 0xF
    end

    function get_rank_int(card::UInt64)
        return (card >> 8) & 0xF
    end

    lc = length(cards)
    output = ""

    for i = 1:lc
        if i != lc
            output = string(output, int_to_pretty_str(cards[i]), " ")
        else
            output = string(output, int_to_pretty_str(cards[i]))
        end
    end

    return output

end
end
