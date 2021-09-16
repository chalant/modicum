# syntax: proto3
using ProtoBuf
import ProtoBuf.meta

# service methods for PokerService
const _PokerService_methods = MethodDescriptor[
        MethodDescriptor("GetPlayerAction", 1, PlayerData, ActionData),
        MethodDescriptor("GetPlayerCards", 2, PlayerData, CardsData),
        MethodDescriptor("GetBoardCards", 3, Empty, CardsData),
        MethodDescriptor("GetBlinds", 4, Empty, BlindsData)
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

GetPlayerAction(stub::PokerServiceStub, controller::ProtoRpcController, inp::PlayerData, done::Function) = call_method(stub.impl, _PokerService_methods[1], controller, inp, done)
GetPlayerAction(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::PlayerData) = call_method(stub.impl, _PokerService_methods[1], controller, inp)

GetPlayerCards(stub::PokerServiceStub, controller::ProtoRpcController, inp::PlayerData, done::Function) = call_method(stub.impl, _PokerService_methods[2], controller, inp, done)
GetPlayerCards(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::PlayerData) = call_method(stub.impl, _PokerService_methods[2], controller, inp)

GetBoardCards(stub::PokerServiceStub, controller::ProtoRpcController, inp::Empty, done::Function) = call_method(stub.impl, _PokerService_methods[3], controller, inp, done)
GetBoardCards(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::Empty) = call_method(stub.impl, _PokerService_methods[3], controller, inp)

GetBlinds(stub::PokerServiceStub, controller::ProtoRpcController, inp::Empty, done::Function) = call_method(stub.impl, _PokerService_methods[4], controller, inp, done)
GetBlinds(stub::PokerServiceBlockingStub, controller::ProtoRpcController, inp::Empty) = call_method(stub.impl, _PokerService_methods[4], controller, inp)

export PokerService, PokerServiceStub, PokerServiceBlockingStub, GetPlayerAction, GetPlayerCards, GetBoardCards, GetBlinds
