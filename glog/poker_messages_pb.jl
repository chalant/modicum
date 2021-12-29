# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

const Round = (;[
    Symbol("FLOP") => Int32(0),
    Symbol("TURN") => Int32(1),
    Symbol("RIVER") => Int32(2),
]...)

mutable struct Blinds <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function Blinds(; kwargs...)
        obj = new(meta(Blinds), Dict{Symbol,Any}(), Set{Symbol}())
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
end # mutable struct Blinds
const __meta_Blinds = Ref{ProtoMeta}()
function meta(::Type{Blinds})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Blinds)
            __meta_Blinds[] = target = ProtoMeta(Blinds)
            allflds = Pair{Symbol,Union{Type,String}}[:small_blind => Float32, :big_blind => Float32]
            meta(target, Blinds, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Blinds[]
    end
end
function Base.getproperty(obj::Blinds, name::Symbol)
    if name === :small_blind
        return (obj.__protobuf_jl_internal_values[name])::Float32
    elseif name === :big_blind
        return (obj.__protobuf_jl_internal_values[name])::Float32
    else
        getfield(obj, name)
    end
end

mutable struct BlindsRequest <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function BlindsRequest(; kwargs...)
        obj = new(meta(BlindsRequest), Dict{Symbol,Any}(), Set{Symbol}())
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
end # mutable struct BlindsRequest
const __meta_BlindsRequest = Ref{ProtoMeta}()
function meta(::Type{BlindsRequest})
    ProtoBuf.metalock() do
        if !isassigned(__meta_BlindsRequest)
            __meta_BlindsRequest[] = target = ProtoMeta(BlindsRequest)
            allflds = Pair{Symbol,Union{Type,String}}[:num_hands => UInt32]
            meta(target, BlindsRequest, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_BlindsRequest[]
    end
end
function Base.getproperty(obj::BlindsRequest, name::Symbol)
    if name === :num_hands
        return (obj.__protobuf_jl_internal_values[name])::UInt32
    else
        getfield(obj, name)
    end
end

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
            allflds = Pair{Symbol,Union{Type,String}}[:position => UInt32, :player_type => Int32, :is_active => Bool]
            meta(target, PlayerData, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_PlayerData[]
    end
end
function Base.getproperty(obj::PlayerData, name::Symbol)
    if name === :position
        return (obj.__protobuf_jl_internal_values[name])::UInt32
    elseif name === :player_type
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :is_active
        return (obj.__protobuf_jl_internal_values[name])::Bool
    else
        getfield(obj, name)
    end
end

mutable struct PlayerCardsRequest <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function PlayerCardsRequest(; kwargs...)
        obj = new(meta(PlayerCardsRequest), Dict{Symbol,Any}(), Set{Symbol}())
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
end # mutable struct PlayerCardsRequest
const __meta_PlayerCardsRequest = Ref{ProtoMeta}()
function meta(::Type{PlayerCardsRequest})
    ProtoBuf.metalock() do
        if !isassigned(__meta_PlayerCardsRequest)
            __meta_PlayerCardsRequest[] = target = ProtoMeta(PlayerCardsRequest)
            allflds = Pair{Symbol,Union{Type,String}}[:new_hand => Bool, :showdown => Bool, :player => PlayerData]
            meta(target, PlayerCardsRequest, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_PlayerCardsRequest[]
    end
end
function Base.getproperty(obj::PlayerCardsRequest, name::Symbol)
    if name === :new_hand
        return (obj.__protobuf_jl_internal_values[name])::Bool
    elseif name === :showdown
        return (obj.__protobuf_jl_internal_values[name])::Bool
    elseif name === :player
        return (obj.__protobuf_jl_internal_values[name])::PlayerData
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

mutable struct PlayerActionRequest <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function PlayerActionRequest(; kwargs...)
        obj = new(meta(PlayerActionRequest), Dict{Symbol,Any}(), Set{Symbol}())
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
end # mutable struct PlayerActionRequest
const __meta_PlayerActionRequest = Ref{ProtoMeta}()
function meta(::Type{PlayerActionRequest})
    ProtoBuf.metalock() do
        if !isassigned(__meta_PlayerActionRequest)
            __meta_PlayerActionRequest[] = target = ProtoMeta(PlayerActionRequest)
            allflds = Pair{Symbol,Union{Type,String}}[:round => UInt32, :player_data => PlayerData, :new_hand => Bool]
            meta(target, PlayerActionRequest, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_PlayerActionRequest[]
    end
end
function Base.getproperty(obj::PlayerActionRequest, name::Symbol)
    if name === :round
        return (obj.__protobuf_jl_internal_values[name])::UInt32
    elseif name === :player_data
        return (obj.__protobuf_jl_internal_values[name])::PlayerData
    elseif name === :new_hand
        return (obj.__protobuf_jl_internal_values[name])::Bool
    else
        getfield(obj, name)
    end
end

mutable struct BoardCardsRequest <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function BoardCardsRequest(; kwargs...)
        obj = new(meta(BoardCardsRequest), Dict{Symbol,Any}(), Set{Symbol}())
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
end # mutable struct BoardCardsRequest
const __meta_BoardCardsRequest = Ref{ProtoMeta}()
function meta(::Type{BoardCardsRequest})
    ProtoBuf.metalock() do
        if !isassigned(__meta_BoardCardsRequest)
            __meta_BoardCardsRequest[] = target = ProtoMeta(BoardCardsRequest)
            allflds = Pair{Symbol,Union{Type,String}}[:round => Int32]
            meta(target, BoardCardsRequest, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_BoardCardsRequest[]
    end
end
function Base.getproperty(obj::BoardCardsRequest, name::Symbol)
    if name === :round
        return (obj.__protobuf_jl_internal_values[name])::Int32
    else
        getfield(obj, name)
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
            allflds = Pair{Symbol,Union{Type,String}}[:players_state => Base.Vector{PlayerStateData}, :dealer => PlayerData, :sb_amount => Float32, :bb_amount => Float32]
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
    elseif name === :sb_amount
        return (obj.__protobuf_jl_internal_values[name])::Float32
    elseif name === :bb_amount
        return (obj.__protobuf_jl_internal_values[name])::Float32
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
            allflds = Pair{Symbol,Union{Type,String}}[:rank => AbstractString, :suit => AbstractString]
            meta(target, CardData, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_CardData[]
    end
end
function Base.getproperty(obj::CardData, name::Symbol)
    if name === :rank
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
    elseif name === :suit
        return (obj.__protobuf_jl_internal_values[name])::AbstractString
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
            allflds = Pair{Symbol,Union{Type,String}}[:action_type => Int32, :multiplier => Float32, :amount => Float32]
            meta(target, ActionData, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_ActionData[]
    end
end
function Base.getproperty(obj::ActionData, name::Symbol)
    if name === :action_type
        return (obj.__protobuf_jl_internal_values[name])::Int32
    elseif name === :multiplier
        return (obj.__protobuf_jl_internal_values[name])::Float32
    elseif name === :amount
        return (obj.__protobuf_jl_internal_values[name])::Float32
    else
        getfield(obj, name)
    end
end

mutable struct Amount <: ProtoType
    __protobuf_jl_internal_meta::ProtoMeta
    __protobuf_jl_internal_values::Dict{Symbol,Any}
    __protobuf_jl_internal_defaultset::Set{Symbol}

    function Amount(; kwargs...)
        obj = new(meta(Amount), Dict{Symbol,Any}(), Set{Symbol}())
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
end # mutable struct Amount
const __meta_Amount = Ref{ProtoMeta}()
function meta(::Type{Amount})
    ProtoBuf.metalock() do
        if !isassigned(__meta_Amount)
            __meta_Amount[] = target = ProtoMeta(Amount)
            allflds = Pair{Symbol,Union{Type,String}}[:value => Float32]
            meta(target, Amount, allflds, ProtoBuf.DEF_REQ, ProtoBuf.DEF_FNUM, ProtoBuf.DEF_VAL, ProtoBuf.DEF_PACK, ProtoBuf.DEF_WTYPES, ProtoBuf.DEF_ONEOFS, ProtoBuf.DEF_ONEOF_NAMES)
        end
        __meta_Amount[]
    end
end
function Base.getproperty(obj::Amount, name::Symbol)
    if name === :value
        return (obj.__protobuf_jl_internal_values[name])::Float32
    else
        getfield(obj, name)
    end
end

export Round, InitialData, Blinds, BlindsRequest, PlayerData_PlayerType, PlayerData, PlayerCardsRequest, Empty, PlayerActionRequest, BoardCardsRequest, PlayerStateData, CardsData, CardData, ActionData_ActionType, ActionData, Amount
