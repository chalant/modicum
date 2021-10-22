# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

# service methods for PokerService
const _PokerService_methods = MethodDescriptor[
        MethodDescriptor("GetPlayers", 1, Empty, Channel{PlayerData}),
        MethodDescriptor("GetDealer", 2, Channel{PlayerData}, PlayerData),
        MethodDescriptor("GetPlayerAction", 3, PlayerData, ActionData),
        MethodDescriptor("GetPlayerCards", 4, PlayerData, CardsData),
        MethodDescriptor("GetBoardCards", 5, BoardCardsRequest, CardsData),
        MethodDescriptor("GetBlinds", 6, PlayerData, Amount)
    ] # const _PokerService_methods
const _PokerService_desc = ServiceDescriptor("poker.PokerService", 1, _PokerService_methods)

PokerService(impl::Module) = ProtoService(_PokerService_desc, impl)

mutable struct PokerServiceStub <: AbstractProtoServiceStub{false}
    impl::ProtoServiceStub
    PokerServiceStub(channel::ProtoRpcChannel) = new(ProtoServiceStub(_PokerService_desc, channel))
end # mutable struct PokerServiceStub

mutable struct PokerServiceBlockingStub <: AbstractProtoServiceStub{true}
    impl::ProtoServiceBlockingStub
    PokerServiceBlockingStub(channel::ProtoRpcChannel) = new(ProtoServiceBlockingStub(_PokerService_desc, channel))
end # mutable struct PokerServiceBlockingStub

GetPlayers(stub::PokerServiceStub, controller::ProtoRpcController, inp::Empty, done::Function) = call_method(stub.impl, _PokerService_methods[1], controller, inp, done)
GetPlayers(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::Empty) = call_method(stub.impl, _PokerService_methods[1], controller, inp)

GetDealer(stub::PokerServiceStub, controller::ProtoRpcController, inp::Channel{PlayerData}, done::Function) = call_method(stub.impl, _PokerService_methods[2], controller, inp, done)
GetDealer(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::Channel{PlayerData}) = call_method(stub.impl, _PokerService_methods[2], controller, inp)

GetPlayerAction(stub::PokerServiceStub, controller::ProtoRpcController, inp::PlayerData, done::Function) = call_method(stub.impl, _PokerService_methods[3], controller, inp, done)
GetPlayerAction(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::PlayerData) = call_method(stub.impl, _PokerService_methods[3], controller, inp)

GetPlayerCards(stub::PokerServiceStub, controller::ProtoRpcController, inp::PlayerData, done::Function) = call_method(stub.impl, _PokerService_methods[4], controller, inp, done)
GetPlayerCards(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::PlayerData) = call_method(stub.impl, _PokerService_methods[4], controller, inp)

GetBoardCards(stub::PokerServiceStub, controller::ProtoRpcController, inp::BoardCardsRequest, done::Function) = call_method(stub.impl, _PokerService_methods[5], controller, inp, done)
GetBoardCards(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::BoardCardsRequest) = call_method(stub.impl, _PokerService_methods[5], controller, inp)

GetBlinds(stub::PokerServiceStub, controller::ProtoRpcController, inp::PlayerData, done::Function) = call_method(stub.impl, _PokerService_methods[6], controller, inp, done)
GetBlinds(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::PlayerData) = call_method(stub.impl, _PokerService_methods[6], controller, inp)

export PokerService, PokerServiceStub, PokerServiceBlockingStub, GetPlayers, GetDealer, GetPlayerAction, GetPlayerCards, GetBoardCards, GetBlinds
