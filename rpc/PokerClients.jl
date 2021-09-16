module PokerClients
using gRPCClient

include("poker.jl")
using .poker

import Base: show

# begin service: poker.PokerService

export PokerServiceBlockingClient, PokerServiceClient

struct PokerServiceBlockingClient
    controller::gRPCController
    channel::gRPCChannel
    stub::PokerServiceBlockingStub

    function PokerServiceBlockingClient(api_base_url::String; kwargs...)
        controller = gRPCController(; kwargs...)
        channel = gRPCChannel(api_base_url)
        stub = PokerServiceBlockingStub(channel)
        new(controller, channel, stub)
    end
end

struct PokerServiceClient
    controller::gRPCController
    channel::gRPCChannel
    stub::PokerServiceStub

    function PokerServiceClient(api_base_url::String; kwargs...)
        controller = gRPCController(; kwargs...)
        channel = gRPCChannel(api_base_url)
        stub = PokerServiceStub(channel)
        new(controller, channel, stub)
    end
end

show(io::IO, client::PokerServiceBlockingClient) = print(io, "PokerServiceBlockingClient(", client.channel.baseurl, ")")
show(io::IO, client::PokerServiceClient) = print(io, "PokerServiceClient(", client.channel.baseurl, ")")

import .poker: GetPlayerAction
"""
    GetPlayerAction

- input: poker.PlayerData
- output: poker.ActionData
"""
GetPlayerAction(client::PokerServiceBlockingClient, inp::poker.PlayerData) = GetPlayerAction(client.stub, client.controller, inp)
GetPlayerAction(client::PokerServiceClient, inp::poker.PlayerData, done::Function) = GetPlayerAction(client.stub, client.controller, inp, done)

import .poker: GetPlayerCards
"""
    GetPlayerCards

- input: poker.PlayerData
- output: poker.CardsData
"""
GetPlayerCards(client::PokerServiceBlockingClient, inp::poker.PlayerData) = GetPlayerCards(client.stub, client.controller, inp)
GetPlayerCards(client::PokerServiceClient, inp::poker.PlayerData, done::Function) = GetPlayerCards(client.stub, client.controller, inp, done)

import .poker: GetBoardCards
"""
    GetBoardCards

- input: poker.Empty
- output: poker.CardsData
"""
GetBoardCards(client::PokerServiceBlockingClient, inp::poker.Empty) = GetBoardCards(client.stub, client.controller, inp)
GetBoardCards(client::PokerServiceClient, inp::poker.Empty, done::Function) = GetBoardCards(client.stub, client.controller, inp, done)

import .poker: GetBlinds
"""
    GetBlinds

- input: poker.Empty
- output: poker.BlindsData
"""
GetBlinds(client::PokerServiceBlockingClient, inp::poker.Empty) = GetBlinds(client.stub, client.controller, inp)
GetBlinds(client::PokerServiceClient, inp::poker.Empty, done::Function) = GetBlinds(client.stub, client.controller, inp, done)

# end service: poker.PokerService

end # module PokerClients
