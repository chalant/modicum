module hands_filter

export filter_hand
export get_filter_data
export get_indexer

include("indexing.jl")

using JSON
using Mmap
using Serialization
using Reexport

@reexport using .indexing

abstract type AbstractData end
abstract type AbstractHandsData <: AbstractData end
abstract type AbstractIndexData <: AbstractData end

struct IndexData <: AbstractIndexData
    compression_index::Vector{UInt32}
end

struct HandsData <: AbstractHandsData
    compression_index::Vector{UInt32}
    compressed_hands::Dict{UInt32, Vector{UInt64}}
end

struct MmapIndexData <: AbstractIndexData
    compression_index::Vector{UInt32}
    index_io::IOStream
end

struct MmapHandsData <: AbstractHandsData
    compression_index::Vector{UInt32}
    compressed_hands::Dict{UInt32, Vector{UInt64}}
    index_io::IOStream
    hands_io::IOStream
end

struct Filter{T<:AbstractData}
    data::T
    indexer::Indexer
end

struct

function filterhand(flt::Filter{AbstractHandsData}, private_hand::Vector{UInt64})
    filter_data = flt.data
    return filter_data.compressed_hands[filter_data.compression_index[
        handindex(filter_data.indexer, private_hand)]]
end

function filterhand(
    flt::Filter{AbstractHandsData},
    private_hand::Vector{UInt64},
    public_hand::Vector{UInt64},
)
    filter_data = flt.data
    return filter_data.compressed_hands[filter_data.compression_index[
        get_hand_index(
            filter_data.indexer,
            private_hand,
            public_hand,
    )]]
end

function handsdata(::Type{MmapHandsData}, dir::String)
    f = open(joinpath(directory, "metadata.json"))
    metadata = JSON.parse(f)
    close(f)

    idx_io = open(joinpath(directory, "compression_index"))
    hd_io = open(joinpath(directory, "hands.bin"))

    MmapHandsData(
        Mmap.mmap(idx_io, Vector{UInt32}, metadata["total_hands"]),
        deserialize(hd_io),
        idx_io,
        hd_io)
end

function indexdata(::Type{IndexData}, dir::String)
    f = open(joinpath(dir, "metadata.json"))
    metadata = JSON.parse(f)
    tot = metadata["total_hands"]
    close(f)

    v = Vector{UInt32}(undef, tot)
    idx_io = open(joinpath(directory, "compression_index"))
    #copy mmapped file to idx
    copy!(v, Mmap.mmap(idx_io, Vector{UInt32}, tot))
    close(idx_io)
    return IndexData(v)
end

function filterindex(flt::Filter{AbstractIndexData}, hand::Vector{UInt64})
    data = flt.data
    return data.compression_index[handindex(data.indexer, hand)]
end

function Base.close(data::MmapHandsData)
    close(data.index_io)
    close(data.hands_io)
end

function Base.close(data::MmapIndexData)
    close(data.index_io)
end

function Base.close(flt::Union{Filter{MmapIndexData}, Filter{MmapHandsData}})
    close(flt.filter_data)
end

end
