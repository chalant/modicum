module combinations

export nextcombo!
export reset!
export subsets

struct Binomial{K, T<:Unsigned}
    cache::SizedVector{K, T}
    idx::SizedVector{K, Int64}
    Binomial{K, T}(cache, idx) where {K, T} = new(cache, idx)
end

@inline function subsets(::Val{K}, ::Type{T}, ::Type{SizedArray{K, T}}) where {K, T <: Unsigned}
    return Binomial{K, T}(Vector{T}(undef, k), collect(Int64, 1:K))
end

@inline function Base.length(bn::Binomial{K, T}, n::Int) where T <: Unsigned
    return binomial(n, K)
end

@inline function nextcombo!(arr::SizedVector{A, T}, it::Binomial{K, T}) where {A, K, T <: Any}
    idx = it.idx
    l = 1
    dest = it.cache
    
    for k in idx
        dest[l] = arr[k]
        l += 1
    end

    i = K
    
    while i > 0
        if idx[i] < A - K + i
            idx[i] += 1

            for j in 1:K-i
                idx[i+j] = idx[i] + j
            end

            break
        else
            i -= 1
        end
    end

    return dest
end

@inline function nextcombo!(
    arr::SizedVector{A, T}, 
    mask::SizedVector{A, T}, 
    it::Binomial{K, T}) where {A, K, T <: Any}
    
    idx = it.idx
    l = 1
    dest = it.cache
    
    for k in idx
        dest[l] = arr[k]
        l += 1
    end

    i = K
    
    s = sum(mask)

    while i > 0
        if idx[i] < s - K + i

            m = idx[i]

            #skip "inactive" elements
            while mask[m] == 0
                m += 1
            end

            idx[i] = m 

            j = 1

            for j in 1:K-i
                m = idx[i] + j

                #skip "inactive" elements
                while mask[m] == 0
                    m += 1
                end

                idx[i+j] = m
            end

            break
        else
            i -= 1
        end
    end

    return dest
end

@inline function reset!(bn::Binomial{K, T}) where {K, T <: Unsigned}
    #reset index array
    for i in 1:K
        bn.idx[i] = i
    end
end

end
