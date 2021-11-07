#=
typetest:
- Julia version: 
- Author: yves
- Date: 2021-11-05
=#

using BenchmarkTools

abstract type ParametricType end
abstract type CompositeType end

struct ParametricTypeA <: ParametricType
    a::Float32
end

struct ParametricTypeB <: ParametricType
    a::Float32
end

struct ParametricCompositeType{T<:ParametricType} <: CompositeType
    a::T
end

struct SingleCompositeType <: CompositeType
    a::Float32
end

struct SomeCompositeType{T<:CompositeType}
    a::T
end

struct SimpleStruct
    a::Float32
end

@inline function loop1(arr::Vector{SomeCompositeType{T}}) where T <: CompositeType
    tot = 0

    for i in arr
        tot += callcompositetype(i.a)
    end

    return tot
end

@inline function loop2(arr::Vector{SimpleStruct})
    tot = 0

    for i in arr
        tot += callcompositetype(i.a)
    end

    return tot
end

@inline function create4(l::Int64)
    arr = Vector{SomeCompositeType{ParametricCompositeType{ParametricTypeA}}}()

    for i in 1:l
        push!(
            arr,
            SomeCompositeType{ParametricCompositeType{ParametricTypeA}}(
                ParametricCompositeType(
                    ParametricTypeA(Float32(10.1)))))
    end

    return arr
end

@inline function create1(l::Int64)
    arr = Vector{SomeCompositeType{SingleCompositeType}}()

    for i in 1:l
        push!(
            arr,
            SomeCompositeType{SingleCompositeType}(SingleCompositeType(Float32(10.1))))
    end

    return arr
end

function test1(l::Int64) where T<: CompositeType
    loop1(create1(l))
end

@inline function create2(l::Int64)
    arr = Vector{SimpleStruct}()

    for i in 1:l
        push!(
            arr,
            SimpleStruct(Float32(10.1))
        )
    end

    return arr

end

function test2(l::Int64)
    loop2(create2(l))
end

function create3(l::Int64)
    arr = Vector{Float32}()

    for i in 1:l
        push!(arr, Float32(10.1))
    end

    return arr

end

function loop3(arr::Vector{T}) where T <: AbstractFloat
    tot = 0

    for i in arr
        tot += i
    end

    return tot

end


@inline function callcompositetype(c::CompositeType)
    return c.a
end

@inline function callcompositetype(c::Float32)
        return c
end

@inline function callcompositetype(c::SingleCompositeType)
        return c.a
end

@inline function callcompositetype(c::ParametricCompositeType{T}) where T <: ParametricType
        return callparametrictype(c.a)
end

@inline function callparametrictype(c::ParametricTypeA)
        return c.a
end

@inline function callparametrictype(c::ParametricTypeB)
        return c.a
end

const arr1 = create1(100000)
const arr2 = create2(100000)
const arr3 = create3(100000)
const arr4 = create4(100000)

function starttests()
    println("Starting tests...")

    @btime loop1(arr1)
    @btime loop2(arr2)
    @btime loop3(arr3)
    @btime loop1(arr4)
end

