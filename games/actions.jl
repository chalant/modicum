module actions

using StaticArrays

using actions

export Action
export ActionSet

export viewactions
export id
export legalactions!

abstract type Action end

mutable struct ActionSet{N, T<:Action}
    actions::MVector{N, T}
    mapping::Dict{T, T}
    ActionSet{N, T}(actions) where {N, T<:Action} = new(sort!(actions), _createmapping(actions))

end

@inline function _createmapping(action_list::MVector{A, T}) where {A, T<:Action}
    mapping = Dict{T, T}()
    
    for action in action_list
        mapping[action] = action
    end

    return mapping
end

# ActionSet(acts::Vector{Action}) = ActionSet(acts::Vector{Action}, false)

@inline function id(a::Action)
    return a.id
end

@inline function Base.in(action::T, actions::ActionSet{N, T}) where {N, T<:Action}
    return in(action, keys(actions.mapping))
end

@inline function Base.getindex(actions::ActionSet{N, T}, index::Int) where {N, T<:Action}
    return actions.actions[index]
end

@inline function Base.length(actions::ActionSet)
    return length(actions.actions)
end

@inline function legalactions!(mask::MVector{A, Bool}, n_actions::T) where {A, T<:Integer}
    # sorts actions such that the active ones are at the top 

    idx = StaticArrays.sacollect(MVector{A, T}, 1:A)
    
    #todo we might not need to copy the mask, since it gets overwritten anyway
    
    i = 1

    while i < n_actions + 1
        
        if mask[i] == 0
            j = i + 1
            
            while j < A + 1
                
                if mask[j] == 1
                    #permute index
                    k = idx[i]
                    idx[i] = idx[j]
                    idx[j] = k
                    mask[i] = 1
                    mask[j] = 0
                    
                    break
                
                end

                j += 1

            end
        end

        i += 1
    end

    return idx

end

@inline function Base.sort!(s::ActionSet{N, T}) where {N, T<:Action}
    if s.sorted != true
        sort!(s.actions)
        s.sorted = false
    end
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
