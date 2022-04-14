module unionfind

export UnionFind
export union
export find

mutable struct UnionFind{T<:Integer, I<:Integer}
    id::Vector{T}
    sz::Vector{T}
    count::I
end

UnionFind(::Type{T}, size::I) where {T<:Integer, I<:Integer} = UnionFind(collect(T, i for i in 1:size), ones(T, size), size)

function find(uf::UnionFind{I}, p::T) where {I<:Integer, T<:Integer}
    
    while (p!=uf.id[p])
        p = uf.id[p]
    end

    return p
end

function Base.union(uf::UnionFind{I}, i::T, j::T) where {I<:Integer ,T<:Integer}

    p = find(uf, i)
    q = find(uf, j)

    if p == q
        return
    end

    if uf.sz[p] < uf.sz[q]
        uf.id[p] = q
        uf.sz[q] += uf.sz[p]
    else
        uf.id[q] = p
        uf.sz[p] += uf.sz[q]
    end

    uf.count -= 1

end

end