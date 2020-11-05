module combinations

export nextcombo!
export reset!
export subsets

mutable struct Binomial{T}
    cache::Vector{T}
    idx::Vector{Int64}
    k::Int64
    Binomial{T}() = new()
end

function subsets(::Type{T}, k::Int) where {T} <: Any
    return Binomial{T}(Vector{T}(undef, k), collect(Int64, 1:k))
end

function Base.length(bn::Binomial, n::Int)
    return binomial(n, bn.k)
end

function nextcombo!(arr::Vector{T}, it::Binomial) where T <: Any
    idx = it.idx
    l = 1
    dest = it.cache
    n = length(arr)
    for k in idx
        dest[l] = arr[k]
        l += 1
    end

    i = it.k
    while i > 0
        if idx[i] < n - it.k + i
            idx[i] += 1

            for j in 1:it.k-i
                idx[i+j] = idx[i] + j
            end

            break
        else
            i -= 1
        end
    end

    return dest
end

function reset!(bn::Binomial)
    #reset index array
    for i in 1:bn.k
        bn.idx[i] = i
    end
end

end
