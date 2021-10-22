#=
dynamic_dispatch_test:
- Julia version: 
- Author: yves
- Date: 2021-10-22
=#

using BenchmarkTools

function do_something2(t::Int32)
    return t
end

function do_something2(t::Int64)
    return t
end

function test1(v::Vector{Int64})
    total = 0

    for i in v
        total += do_something2(i)
    end
end

function test2(v::Vector{Int32})
    total = 0

    for i in v
        total += do_something2(i)
    end
end

function test3(v::Vector)
    total = 0

    for i in v
        total += do_something2(i)
    end
end

const vec1 = rand(Int32, 1000000)

function test()

    println("Dynamic")
    @btime test3(vec1)

    println("Concrete")
    @btime test2(vec1)
end