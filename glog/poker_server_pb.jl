# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

# service methods for PokerService
const _PokerService_methods = MethodDescriptor[
        MethodDescriptor("IsReady", 1, Empty, Empty),
        MethodDescriptor("GetPlayers", 2, Empty, Channel{PlayerData}),
        MethodDescriptor("GetDealer", 3, Channel{PlayerData}, PlayerData),
        MethodDescriptor("GetPlayerAction", 4, PlayerActionRequest, ActionData),
        MethodDescriptor("GetPlayerCards", 5, PlayerCardsRequest, CardsData),
        MethodDescriptor("GetBoardCards", 6, BoardCardsRequest, CardsData),
        MethodDescriptor("GetBlinds", 7, BlindsRequest, Blinds),
        MethodDescriptor("PerformAction", 8, ActionData, Empty)
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

IsReady(stub::PokerServiceStub, controller::ProtoRpcController, inp::Empty, done::Function) = call_method(stub.impl, _PokerService_methods[1], controller, inp, done)
IsReady(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::Empty) = call_method(stub.impl, _PokerService_methods[1], controller, inp)

GetPlayers(stub::PokerServiceStub, controller::ProtoRpcController, inp::Empty, done::Function) = call_method(stub.impl, _PokerService_methods[2], controller, inp, done)
GetPlayers(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::Empty) = call_method(stub.impl, _PokerService_methods[2], controller, inp)

GetDealer(stub::PokerServiceStub, controller::ProtoRpcController, inp::Channel{PlayerData}, done::Function) = call_method(stub.impl, _PokerService_methods[3], controller, inp, done)
GetDealer(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::Channel{PlayerData}) = call_method(stub.impl, _PokerService_methods[3], controller, inp)

GetPlayerAction(stub::PokerServiceStub, controller::ProtoRpcController, inp::PlayerActionRequest, done::Function) = call_method(stub.impl, _PokerService_methods[4], controller, inp, done)
GetPlayerAction(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::PlayerActionRequest) = call_method(stub.impl, _PokerService_methods[4], controller, inp)

GetPlayerCards(stub::PokerServiceStub, controller::ProtoRpcController, inp::PlayerCardsRequest, done::Function) = call_method(stub.impl, _PokerService_methods[5], controller, inp, done)
GetPlayerCards(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::PlayerCardsRequest) = call_method(stub.impl, _PokerService_methods[5], controller, inp)

GetBoardCards(stub::PokerServiceStub, controller::ProtoRpcController, inp::BoardCardsRequest, done::Function) = call_method(stub.impl, _PokerService_methods[6], controller, inp, done)
GetBoardCards(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::BoardCardsRequest) = call_method(stub.impl, _PokerService_methods[6], controller, inp)

GetBlinds(stub::PokerServiceStub, controller::ProtoRpcController, inp::BlindsRequest, done::Function) = call_method(stub.impl, _PokerService_methods[7], controller, inp, done)
GetBlinds(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::BlindsRequest) = call_method(stub.impl, _PokerService_methods[7], controller, inp)

PerformAction(stub::PokerServiceStub, controller::ProtoRpcController, inp::ActionData, done::Function) = call_method(stub.impl, _PokerService_methods[8], controller, inp, done)
PerformAction(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::ActionData) = call_method(stub.impl, _PokerService_methods[8], controller, inp)

export PokerService, PokerServiceStub, PokerServiceBlockingStub, IsReady, GetPlayers, GetDealer, GetPlayerAction, GetPlayerCards, GetBoardCards, GetBlinds, PerformAction
