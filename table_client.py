import grpc
import click

from glog.poker_server_pb2_grpc import PokerServiceStub
from glog.poker_messages_pb2 import Empty, PlayerData

@click.group()
def cli():
    pass

# @cli.command()
# def ready():
#     stub.IsReady(Empty())

@cli.command()
def connect():
    channel = grpc.insecure_channel('localhost:50051')
    stub = PokerServiceStub(channel)

    while True:
        try:
            result = stub.GetPlayerAction(PlayerData(
                position=1,
                type=PlayerData.PlayerType.MAIN,
                is_active=True
            ))

            print("Action", result.action_type,
                  "Amount", result.amount,
                  "Multiplier", result.multiplier)
        except KeyboardInterrupt:
            break

    # _input(input(), stub)

def _input(ipt, stub):
    if ipt == "pa":
        result = stub.GetPlayerAction(PlayerData(
            position=1,
            type=PlayerData.PlayerType.MAIN,
            is_active=True
        ))

        print("Action", result.action_type,
              "Amount", result.amount,
              "Multiplier", result.multiplier)
        return _input(input(), stub)
    else:
        print("Input not supported", ipt)
        return _input(input(), stub)


if __name__ == '__main__':
    cli()


