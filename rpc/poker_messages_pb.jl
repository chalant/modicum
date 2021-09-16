# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

const PlayerData_PlayerType = (;[
    Symbol("MAIN") => Int32(0),
    Symbol("OPPONENT") => Int32(1),
]...)

mutable struct PlayerData <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function PlayerData(; kwargs...)
        obj = new(meta(PlayerData), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            if fldval !== nothing
                values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
            end
        end
        obj
    end
end # mutable struct PlayerData
const __meta_PlayerData = Ref{ProtoMeta}()
function meta(::Type{PlayerData})
    ProtoBuf.metalock() do
        if !isassigned(__meta_PlayerData)
            __meta_PlayerData[] = target = ProtoMeta(PlayerData)
            allflds = Pair{Symbol,Union{Type,String}}[:position => UInt32, :_type => Int32]
            meta(target, PlayerData, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_PlayerData[]
    end
end
function Base.getproperty(obj::PlayerData, name::Symbol)
    if name === :position
        return (obj.__protobuf_jl_internal_values[name])::UInt32
    elseif name === :_type
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
    end
end

mutable struct Empty <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function Empty(; kwargs...)
        obj = new(meta(Empty), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            if fldval !== nothing
                values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
            end
        end
        obj
    end
end # mutable struct Empty
const __meta_Empty = Ref{ProtoMeta}()
function meta(::Type{Empty})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Empty)
            __meta_Empty[] = target = ProtoMeta(Empty)
            allflds = Pair{Symbol,Union{Type,String}}[]
            meta(target, Empty, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Empty[]
    end
end

mutable struct PlayerStateData <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function PlayerStateData(; kwargs...)
        obj = new(meta(PlayerStateData), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            if fldval !== nothing
                values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
            end
        end
        obj
    end
end # mutable struct PlayerStateData
const __meta_PlayerStateData = Ref{ProtoMeta}()
function meta(::Type{PlayerStateData})
    ProtoBuf.metalock() do
        if !isassigned(__meta_PlayerStateData)
            __meta_PlayerStateData[] = target = ProtoMeta(PlayerStateData)
            allflds = Pair{Symbol,Union{Type,String}}[:chips => Float32, :player => PlayerData]
            meta(target, PlayerStateData, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_PlayerStateData[]
    end
end
function Base.getproperty(obj::PlayerStateData, name::Symbol)
    if name === :chips
        return (obj.__protobuf_jl_internal_values[name])::Float32
    elseif name === :player
        return (obj.__protobuf_jl_internal_values[name])::PlayerData
    else
        getfield(obj, name)
    end
end

mutable struct InitialData <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function InitialData(; kwargs...)
        obj = new(meta(InitialData), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            if fldval !== nothing
                values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
            end
        end
        obj
    end
end # mutable struct InitialData
const __meta_InitialData = Ref{ProtoMeta}()
function meta(::Type{InitialData})
    ProtoBuf.metalock() do
        if !isassigned(__meta_InitialData)
            __meta_InitialData[] = target = ProtoMeta(InitialData)
            allflds = Pair{Symbol,Union{Type,String}}[:players_state => Base.Vector{PlayerStateData}, :dealer => PlayerData, :small_blind => PlayerData, :big_blind => PlayerData, :sb_amount => Float32, :bb_amount => Float32, :server_url => AbstractString]
            meta(target, InitialData, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_InitialData[]
    end
end
function Base.getproperty(obj::InitialData, name::Symbol)
    if name === :players_state
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{PlayerStateData}
    elseif name === :dealer
        return (obj.__protobuf_jl_internal_values[name])::PlayerData
    elseif name === :small_blind
        return (obj.__protobuf_jl_internal_values[name])::PlayerData
    elseif name === :big_blind
        return (obj.__protobuf_jl_internal_values[name])::PlayerData
    elseif name === :sb_amount
        return (obj.__protobuf_jl_internal_values[name])::Float32
    elseif name === :bb_amount
        return (obj.__protobuf_jl_internal_values[name])::Float32
    elseif name === :server_url
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    else
        getfield(obj, name)
    end
end

mutable struct CardData <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function CardData(; kwargs...)
        obj = new(meta(CardData), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            if fldval !== nothing
                values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
            end
        end
        obj
    end
end # mutable struct CardData
const __meta_CardData = Ref{ProtoMeta}()
function meta(::Type{CardData})
    ProtoBuf.metalock() do
        if !isassigned(__meta_CardData)
            __meta_CardData[] = target = ProtoMeta(CardData)
            allflds = Pair{Symbol,Union{Type,String}}[:suit => UInt32, :rank => UInt32]
            meta(target, CardData, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_CardData[]
    end
end
function Base.getproperty(obj::CardData, name::Symbol)
    if name === :suit
        return (obj.__protobuf_jl_internal_values[name])::UInt32
    elseif name === :rank
        return (obj.__protobuf_jl_internal_values[name])::UInt32
    else
        getfield(obj, name)
    end
end

mutable struct CardsData <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function CardsData(; kwargs...)
        obj = new(meta(CardsData), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            if fldval !== nothing
                values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
            end
        end
        obj
    end
end # mutable struct CardsData
const __meta_CardsData = Ref{ProtoMeta}()
function meta(::Type{CardsData})
    ProtoBuf.metalock() do
        if !isassigned(__meta_CardsData)
            __meta_CardsData[] = target = ProtoMeta(CardsData)
            allflds = Pair{Symbol,Union{Type,String}}[:cards => Base.Vector{CardData}]
            meta(target, CardsData, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_CardsData[]
    end
end
function Base.getproperty(obj::CardsData, name::Symbol)
    if name === :cards
        return (obj.__protobuf_jl_internal_values[name])::Base.Vector{CardData}
    else
        getfield(obj, name)
    end
end

const ActionData_ActionType = (;[
    Symbol("BET") => Int32(0),
    Symbol("CALL") => Int32(1),
    Symbol("RAISE") => Int32(2),
    Symbol("FOLD") => Int32(3),
    Symbol("ALL_IN") => Int32(4),
    Symbol("CHECK") => Int32(5),
]...)

mutable struct ActionData <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function ActionData(; kwargs...)
        obj = new(meta(ActionData), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            if fldval !== nothing
                values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
            end
        end
        obj
    end
end # mutable struct ActionData
const __meta_ActionData = Ref{ProtoMeta}()
function meta(::Type{ActionData})
    ProtoBuf.metalock() do
        if !isassigned(__meta_ActionData)
            __meta_ActionData[] = target = ProtoMeta(ActionData)
            allflds = Pair{Symbol,Union{Type,String}}[:action_id => UInt32, :action_type => Int32, :amount => Float32]
            meta(target, ActionData, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_ActionData[]
    end
end
function Base.getproperty(obj::ActionData, name::Symbol)
    if name === :action_id
        return (obj.__protobuf_jl_internal_values[name])::UInt32
    elseif name === :action_type
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :amount
        return (obj.__protobuf_jl_internal_values[name])::Float32
    else
        getfield(obj, name)
    end
end

mutable struct BlindsData <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function BlindsData(; kwargs...)
        obj = new(meta(BlindsData), Dict{Symbol,Any}(), Set{Symbol}())
        values = obj.__protobuf_jl_internal_values
        symdict = obj.__protobuf_jl_internal_meta.symdict
        for nv in kwargs
            fldname, fldval = nv
            fldtype = symdict[fldname].jtyp
            (fldname in keys(symdict)) || error(string(typeof(obj), " has no field with name ", fldname))
            if fldval !== nothing
                values[fldname] = isa(fldval, fldtype) ? fldval : convert(fldtype, fldval)
            end
        end
        obj
    end
end # mutable struct BlindsData
const __meta_BlindsData = Ref{ProtoMeta}()
function meta(::Type{BlindsData})
    ProtoBuf.metalock() do
        if !isassigned(__meta_BlindsData)
            __meta_BlindsData[] = target = ProtoMeta(BlindsData)
            allflds = Pair{Symbol,Union{Type,String}}[:small_blind => Float32, :big_blind => Float32]
            meta(target, BlindsData, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_BlindsData[]
    end
end
function Base.getproperty(obj::BlindsData, name::Symbol)
    if name === :small_blind
        return (obj.__protobuf_jl_internal_values[name])::Float32
    elseif name === :big_blind
        return (obj.__protobuf_jl_internal_values[name])::Float32
    else
        getfield(obj, name)
    end
end

export InitialData, PlayerData_PlayerType, PlayerData, Empty, PlayerStateData, CardsData, CardData, ActionData_ActionType, ActionData, BlindsData
