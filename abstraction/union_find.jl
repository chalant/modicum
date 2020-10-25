module union_find

export find_hand
export hand_union

function find_hand(hand::UInt32, forest::Vector{UInt32})

    hd = hand
    # path::Vector{UInt64} = []
    # append!(path, hd)
    while hd != forest[hd]
        hd = forest[hd]
        # append!(path, hd)
    end
    # for h in path
    #     forest[h] = hd
    # end
    return hd
end

function hand_union(
    u::UInt32,
    v::UInt32,
    idx_array::Vector{UInt32},
    sizes::Vector{UInt32},
)

    l = find_hand(u, idx_array)
    r = find_hand(v, idx_array)

    if l != r
        if sizes[l] < sizes[r]
            idx_array[l] = r
            sizes[r] += sizes[l]
        else
            idx_array[r] = l
            sizes[l] += sizes[r]
        end
        return -1
    end
    return 0
end

end
