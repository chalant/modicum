module actions

using StaticArrays

using actions

export Action
export ActionSet
export ChanceAction

export viewactions
export id

abstract type Action end
abstract type ChanceAction end

mutable struct ActionSet{N, T<:Action}
    actions::SVector{N, T}
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

@inline function Base.in(action::T, actions::ActionSet{N, T}) where {N, T<:Action}
    return in(action, keys(actions.mapping))
end

@inline function Base.getindex(actions::ActionSet{N, T}, index::I) where {N, I<:Integer, T<:Action}
    return actions.actions[index]
end

@inline function Base.length(actions::ActionSet)
    return length(actions.actions)
end

@inline function sortandconvert(arr::V) where {N, T<:Action, V<:SizedVector{N, T}}
    return SVector{N, T}(sort!(arr))
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
