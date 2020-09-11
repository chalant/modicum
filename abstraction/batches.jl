module batches

export Batch

struct Batch
    array::Vector{Int64}
    length::Int64
    chunk::Int64
end

function Base.iterate(batch::Batch)
    return batch, (1, 0, Int64(ceil(batch.length/batch.chunk)))
end

function Base.iterate(batch::Batch, state::Tuple{Int64,Int64,Int64})
    j, i, itr = state
    i += 1
    res::Vector{Int64} = []
    try
        t = j + batch.chunk - 1
        res = batch.array[j:t]
        j = t + 1
    catch x
        res = batch.array[j:batch.length]
    end
    if i > itr
        return nothing
    end
    state = (j, i, itr)
    return res, state
end
end
