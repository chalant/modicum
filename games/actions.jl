module actions

using StaticArrays

using actions

export Action
export ActionSet

export viewactions
export id

abstract type Action end

mutable struct ActionSet{N, T<:Action}
    actions::SizedVector{N, T}
    mapping::Set{T}
end

ActionSet(actions::V) where {N, T<:Action, V<:SizedVector{N, T}} = ActionSet{N, T}(sortandconvert(actions), Set{T}(actions))  

@inline function _createmapping(action_list::V) where {T<:Action, V<:AbstractVector{T}}
    return Set{T}(action_list)
end

# ActionSet(acts::Vector{Action}) = ActionSet(acts::Vector{Action}, false)

@inline function id(a::Action)
    return a.id
end

function Base.in(action::T, actions::ActionSet{N, T}) where {N, T<:Action}
    return in(action, keys(actions.mapping))
end

function Base.getindex(action_set::ActionSet{N, T}, index::I) where {N, I<:Integer, T<:Action}
    return action_set.actions[index]
end

@inline function Base.length(actions::ActionSet)
    return length(actions.actions)
end

@inline function sortandconvert(arr::V) where {N, T<:Action, V<:SizedVector{N, T}}
    return sort!(arr)
end

@inline function Base.sort!(s::ActionSet{N, T}) where {N, T<:Action}
    sort!(s.actions)
end

@inline function Base.iterate(a::ActionSet{N, T}, i::Tuple) where {N, T<:Action}
    return iterate(a.actions, i)
end

# @inline function Base.iterate(a::ActionSet{N, T}, i::Int) where {N, T<:Action}
#     return iterate(a.actions, (i, nothing))
# end

@inline function Base.iterate(a::ActionSet{N, T}) where {N, T<:Action}
    return iterate(a.actions, (SOneTo(N), 0))
end

@inline function viewactions(a::ActionSet{N, T}) where {N, T<:Action}
    return a.actions
end

end
