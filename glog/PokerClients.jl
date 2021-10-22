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

import .poker: GetPlayers
"""
    GetPlayers

- input: poker.Empty
- output: Channel{poker.PlayerData}
"""
GetPlayers(client::PokerServiceBlockingClient, inp::poker.Empty) = GetPlayers(client.stub, client.controller, inp)
GetPlayers(client::PokerServiceClient, inp::poker.Empty, done::Function) = GetPlayers(client.stub, client.controller, inp, done)

import .poker: GetDealer
"""
    GetDealer

- input: Channel{poker.PlayerData}
- output: poker.PlayerData
"""
GetDealer(client::PokerServiceBlockingClient, inp::Channel{poker.PlayerData}) = GetDealer(client.stub, client.controller, inp)
GetDealer(client::PokerServiceClient, inp::Channel{poker.PlayerData}, done::Function) = GetDealer(client.stub, client.controller, inp, done)

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

- input: poker.BoardCardsRequest
- output: poker.CardsData
"""
GetBoardCards(client::PokerServiceBlockingClient, inp::poker.BoardCardsRequest) = GetBoardCards(client.stub, client.controller, inp)
GetBoardCards(client::PokerServiceClient, inp::poker.BoardCardsRequest, done::Function) = GetBoardCards(client.stub, client.controller, inp, done)

import .poker: GetBlinds
"""
    GetBlinds

- input: poker.PlayerData
- output: poker.Amount
"""
GetBlinds(client::PokerServiceBlockingClient, inp::poker.PlayerData) = GetBlinds(client.stub, client.controller, inp)
GetBlinds(client::PokerServiceClient, inp::poker.PlayerData, done::Function) = GetBlinds(client.stub, client.controller, inp, done)

# end service: poker.PokerService

end # module PokerClients
