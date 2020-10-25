module hands_filter

export filter_hand
export get_filter_data
export get_indexer

include("../abstraction/hands_indexer.jl")

using JSON
using Mmap
using Serialization

using .hands_indexer

struct FilterData
    compression_index::Vector{UInt32}
    compressed_hands::Dict{UInt32,Vector{UInt64}}
    indexer::Indexer
    index_io::IOStream
    hands_io::IOStream
end

struct FilterState

end

function filter_hand(filter_data::FilterData, private_hand::Vector{UInt64})
    return filter_data.compressed_hands[filter_data.compression_index[
        get_hand_index(
            filter_data.indexer,
            private_hand,
    )]]
end

function filter_hand(
    filter_data::FilterData,
    private_hand::Vector{UInt64},
    public_hand::Vector{UInt64},
)
    return filter_data.compressed_hands[filter_data.compression_index[
        get_hand_index(
            filter_data.indexer,
            private_hand,
            public_hand,
    )]]
end

function get_filter_data(indexer::Indexer, directory::String)
    f = open(joinpath(directory, "metadata.json"))
    metadata = JSON.parse(f)
    close(f)

    idx_io = open(joinpath(directory, "compression_index"))
    hd_io = open(joinpath(directory, "hands.bin"))

    return FilterData(
        Mmap.mmap(idx_io, Vector{UInt32}, metadata["total_hands"]),
        deserialize(hd_io),
        indexer,
        idx_io,
        hd_io
    )
end

function get_filter_data(
    cards::Vector{UInt64},
    private_cards_length::Int64,
    public_cards_length::Int64,
    directory::String)

    f = open(joinpath(directory, "metadata.json"))
    metadata = JSON.parse(f)
    close(f)

    idx_io = open(joinpath(directory, "compression_index"))
    hd_io = open(joinpath(directory, "hands.bin"))

    return FilterData(
        Mmap.mmap(idx_io, Vector{UInt32}, metadata["total_hands"]),
        deserialize(hd_io),
        get_indexer(cards, private_cards_length, public_cards_length),
        idx_io,
        hd_io
    )
end

function Base.close(filter_data::FilterData)
    close(filter_data.index_io)
    close(filter_data.hands_io)
end

end
