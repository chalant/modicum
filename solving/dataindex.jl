module dataindex

export LeafIndex
export Index

export index!
export indice!

struct LeafIndex{T<:AbstractVector}
    indices::Vector{T}
end

struct Index{T<:AbstractVector}
    indices::Vector{T}
    children::Vector{Union{Index{T}, LeafIndex{T}}}
end

LeafIndex(::Type{T}) where {T<:AbstractVector} = LeafIndex{T}(Vector{T}())
Index(::Type{T}) where {T<:AbstractVector}  = Index{T}(Vector{T}(), Vector{Index{T}}())

@inline function index!(ind::Index{T}, i::I) where {T<:AbstractVector, I<:Integer}
    return ind.children[i]
end

@inline function index!(ind::LeafIndex{T}, i::I) where {T<:AbstractVector, I<:Integer}
    return nothing
end

@inline function indice!(ind::Union{Index{T}, LeafIndex{T}}, i::I) where {T<:AbstractVector, I<:Integer}
    return ind.indices[i]
end

end