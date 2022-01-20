module combinations

using StaticArrays

export nextcombo!
export reset!
export subsets

abstract type AbstractBinomial{K, T} end 

struct Binomial{K, T} <: AbstractBinomial{K, T}
    cache::Vector{T}
    idx::StaticVector{K, Int64}
end

struct StaticBinomial{K, T} <: AbstractBinomial{K, T}
    cache::StaticVector{K, T}
    idx::StaticVector{K, Int64}
end

@inline function subsets(::Type{Binomial{K, T}}) where {K, T <: Real}
    v = @MVector zeros(T, K)

    return Binomial{K, T}(v, StaticArrays.sacollect(MVector{K, Int64}, 1:K))
end

@inline function subsets(::Type{StaticBinomial{K, T}}) where {K, T <: Real}
    v = @MVector zeros(T, K)

    return Binomial{K, T}(v, StaticArrays.sacollect(MVector{K, Int64}, 1:K))
end

@inline function Base.length(bn::Binomial{K, T}, n::U) where {K, T <: Real, U <: Integer}
    return binomial(n , K) 
end

@inline function nextcombo!(
    ::Val{A},
    arr::AbstractVector{T}, 
    dest::StaticArray{K, T}, 
    idx::StaticArray{K, U}) where {T <: Real, U <: Integer, A}

    l = 1
    
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
    len::U,
    arr::AbstractVector{T}, 
    dest::StaticArray{K, T}, 
    idx::StaticArray{K, U}) where {T <: Real, U <: Integer, A}

    l = 1
    
    for k in idx
        dest[l] = arr[k]
        l += 1
    end

    i = K
    
    while i > 0
        if idx[i] < len - K + i
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
    arr::Vector{T}, 
    it::Binomial{K, T}) where {K, T <: Real}
    
    idx = it.idx
    l = 1
    dest = it.cache
    
    for k in idx
        dest[l] = arr[k]
        l += 1
    end

    i = K
    s = length(arr)
    
    while i > 0
        if idx[i] < s - K + i
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
    arr::StaticVector{A, T}, 
    it::Binomial{K, T}) where {A, K, T <: Real}
    
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

@inline function reset!(bn::Binomial{K, T}) where {K, T <: Real}
    #reset index array
    for i in 1:K
        bn.idx[i] = i
    end
end

end
