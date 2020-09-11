module cards
export PRIMES,
    prime_product_from_hand,
    prime_product_from_rankbits,
    get_deck

export pretty_print_cards

const PRIMES = Vector{UInt64}(
    [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41])

function prime_product_from_rankbits(rankbits::UInt64)
    product::UInt64 = 1
    for i = 1:13
        if rankbits & (1 << (i - 1)) != 0
            product *= PRIMES[i]
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

function new_card(
    chars::Vector{SubString{String}},
    rank_char_to_int::Dict{String,UInt64},
    suit_char_to_int::Dict{String,UInt64})
    rank_char = chars[1]
    suit_char = chars[2]
    rank_int = rank_char_to_int[rank_char]
    suit_int = suit_char_to_int[suit_char]
    rank_prime = PRIMES[rank_int + 1]

    bitrank = 1 << rank_int << 16
    suit = suit_int << 12
    rank = rank_int << 8

    return bitrank | suit | rank | rank_prime
end

function get_deck()
    str_ranks::Vector{String} = [
        "2","3","4",
        "5","6","7",
        "8","9","T",
        "J","Q","K",
        "A"]

    char_rank_to_int_rank::Dict{String,UInt64} = Dict(
        zip(str_ranks,[i for i = 0:12]))

    suits::Vector{String} = ["s", "h", "d", "c"]

    char_suit_to_int_suit::Dict{String,UInt64} = Dict(zip(suits,[1,2,4,8]))
    arr::Vector{UInt64} = [new_card(
        split(string(rank,suit),""),
        char_rank_to_int_rank,
        char_suit_to_int_suit)
        for rank in str_ranks
            for suit in suits]
    return arr
end

function pretty_print_cards(cards::Vector{UInt64})
    pretty_suits = Dict{UInt64,String}(
        1 => "♠",
        2 => "♡",
        4 => "♢",
        8 => "♣"
    )

    str_ranks::Vector{String} = [
        "2","3","4",
        "5","6","7",
        "8","9","T",
        "J","Q","K",
        "A"]


    function int_to_pretty_str(card::UInt64)
        suit_int = get_suit_int(card)
        rank_int = get_rank_int(card) + 1

        r = str_ranks[rank_int]
        s = pretty_suits[suit_int]

        return string(r, s)
    end

    function get_suit_int(card::UInt64)
        return (card >> 12) & 0xF
    end

    function get_rank_int(card::UInt64)
        return (card >> 8) & 0xF
    end

    lc = length(cards)
    output = ""

    for i in 1:lc
        if i != lc
            output = string(output, int_to_pretty_str(cards[i]), " ")
        else
            output = string(output, int_to_pretty_str(cards[i]))
        end
    end

    return output

end
end
