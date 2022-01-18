module concat

export concatenate!

@inline function concatenate!(
    dest::StaticVector{N, T},
    l::StaticVector{L, T},
    r::StaticVector{R, T}) where T <: Any
    
    i = 1
    for c in l
        dest[i] = c
        i += 1
    end

    for c in r
        dest[i] = c
        i += 1
    end

    return dest
end

function concatenate!(
    dest::Vector{UInt64},
    l::Vector{UInt64},
    r::Vector{UInt64},
    m::Vector{UInt64},
)
    i = 1
    for c in l
        dest[i] = c
        i += 1
    end

    for c in r
        dest[i] = c
        i += 1
    end

    for c in m
        dest[i] = c
        i += 1
    end

    return dest
end
end
