# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: poker_messages.proto
"""Generated protocol buffer code."""
from google.protobuf.internal import enum_type_wrapper
from google.protobuf import descriptor as _descriptor
from google.protobuf import message as _message
from google.protobuf import reflection as _reflection
from google.protobuf import symbol_database as _symbol_database
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()




DESCRIPTOR = _descriptor.FileDescriptor(
  name='poker_messages.proto',
  package='poker',
  syntax='proto3',
  serialized_options=b'\200\001\001',
  create_key=_descriptor._internal_create_key,
  serialized_pb=b'\n\x14poker_messages.proto\x12\x05poker\"\x85\x01\n\x0bInitialData\x12-\n\rplayers_state\x18\x01 \x03(\x0b\x32\x16.poker.PlayerStateData\x12!\n\x06\x64\x65\x61ler\x18\x02 \x01(\x0b\x32\x11.poker.PlayerData\x12\x11\n\tsb_amount\x18\x03 \x01(\x02\x12\x11\n\tbb_amount\x18\x04 \x01(\x02\"p\n\nPlayerData\x12\x10\n\x08position\x18\x01 \x01(\r\x12*\n\x04type\x18\x02 \x01(\x0e\x32\x1c.poker.PlayerData.PlayerType\"$\n\nPlayerType\x12\x08\n\x04MAIN\x10\x00\x12\x0c\n\x08OPPONENT\x10\x01\"\x07\n\x05\x45mpty\"0\n\x11\x42oardCardsRequest\x12\x1b\n\x05round\x18\x01 \x01(\x0e\x32\x0c.poker.Round\"C\n\x0fPlayerStateData\x12\r\n\x05\x63hips\x18\x01 \x01(\x02\x12!\n\x06player\x18\x02 \x01(\x0b\x32\x11.poker.PlayerData\"+\n\tCardsData\x12\x1e\n\x05\x63\x61rds\x18\x01 \x03(\x0b\x32\x0f.poker.CardData\"&\n\x08\x43\x61rdData\x12\x0c\n\x04suit\x18\x01 \x01(\r\x12\x0c\n\x04rank\x18\x02 \x01(\r\"\xaf\x01\n\nActionData\x12\x11\n\taction_id\x18\x01 \x01(\r\x12\x31\n\x0b\x61\x63tion_type\x18\x02 \x01(\x0e\x32\x1c.poker.ActionData.ActionType\x12\x0e\n\x06\x61mount\x18\x03 \x01(\x02\"K\n\nActionType\x12\x07\n\x03\x42\x45T\x10\x00\x12\x08\n\x04\x43\x41LL\x10\x01\x12\t\n\x05RAISE\x10\x02\x12\x08\n\x04\x46OLD\x10\x03\x12\n\n\x06\x41LL_IN\x10\x04\x12\t\n\x05\x43HECK\x10\x05\"\x17\n\x06\x41mount\x12\r\n\x05value\x18\x01 \x01(\x02*&\n\x05Round\x12\x08\n\x04\x46LOP\x10\x00\x12\x08\n\x04TURN\x10\x01\x12\t\n\x05RIVER\x10\x02\x42\x03\x80\x01\x01\x62\x06proto3'
)

_ROUND = _descriptor.EnumDescriptor(
  name='Round',
  full_name='poker.Round',
  filename=None,
  file=DESCRIPTOR,
  create_key=_descriptor._internal_create_key,
  values=[
    _descriptor.EnumValueDescriptor(
      name='FLOP', index=0, number=0,
      serialized_options=None,
      type=None,
      create_key=_descriptor._internal_create_key),
    _descriptor.EnumValueDescriptor(
      name='TURN', index=1, number=1,
      serialized_options=None,
      type=None,
      create_key=_descriptor._internal_create_key),
    _descriptor.EnumValueDescriptor(
      name='RIVER', index=2, number=2,
      serialized_options=None,
      type=None,
      create_key=_descriptor._internal_create_key),
  ],
  containing_type=None,
  serialized_options=None,
  serialized_start=697,
  serialized_end=735,
)
_sym_db.RegisterEnumDescriptor(_ROUND)

Round = enum_type_wrapper.EnumTypeWrapper(_ROUND)
FLOP = 0
TURN = 1
RIVER = 2


_PLAYERDATA_PLAYERTYPE = _descriptor.EnumDescriptor(
  name='PlayerType',
  full_name='poker.PlayerData.PlayerType',
  filename=None,
  file=DESCRIPTOR,
  create_key=_descriptor._internal_create_key,
  values=[
    _descriptor.EnumValueDescriptor(
      name='MAIN', index=0, number=0,
      serialized_options=None,
      type=None,
      create_key=_descriptor._internal_create_key),
    _descriptor.EnumValueDescriptor(
      name='OPPONENT', index=1, number=1,
      serialized_options=None,
      type=None,
      create_key=_descriptor._internal_create_key),
  ],
  containing_type=None,
  serialized_options=None,
  serialized_start=243,
  serialized_end=279,
)
_sym_db.RegisterEnumDescriptor(_PLAYERDATA_PLAYERTYPE)

_ACTIONDATA_ACTIONTYPE = _descriptor.EnumDescriptor(
  name='ActionType',
  full_name='poker.ActionData.ActionType',
  filename=None,
  file=DESCRIPTOR,
  create_key=_descriptor._internal_create_key,
  values=[
    _descriptor.EnumValueDescriptor(
      name='BET', index=0, number=0,
      serialized_options=None,
      type=None,
      create_key=_descriptor._internal_create_key),
    _descriptor.EnumValueDescriptor(
      name='CALL', index=1, number=1,
      serialized_options=None,
      type=None,
      create_key=_descriptor._internal_create_key),
    _descriptor.EnumValueDescriptor(
      name='RAISE', index=2, number=2,
      serialized_options=None,
      type=None,
      create_key=_descriptor._internal_create_key),
    _descriptor.EnumValueDescriptor(
      name='FOLD', index=3, number=3,
      serialized_options=None,
      type=None,
      create_key=_descriptor._internal_create_key),
    _descriptor.EnumValueDescriptor(
      name='ALL_IN', index=4, number=4,
      serialized_options=None,
      type=None,
      create_key=_descriptor._internal_create_key),
    _descriptor.EnumValueDescriptor(
      name='CHECK', index=5, number=5,
      serialized_options=None,
      type=None,
      create_key=_descriptor._internal_create_key),
  ],
  containing_type=None,
  serialized_options=None,
  serialized_start=595,
  serialized_end=670,
)
_sym_db.RegisterEnumDescriptor(_ACTIONDATA_ACTIONTYPE)


_INITIALDATA = _descriptor.Descriptor(
  name='InitialData',
  full_name='poker.InitialData',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  create_key=_descriptor._internal_create_key,
  fields=[
    _descriptor.FieldDescriptor(
      name='players_state', full_name='poker.InitialData.players_state', index=0,
      number=1, type=11, cpp_type=10, label=3,
      has_default_value=False, default_value=[],
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
    _descriptor.FieldDescriptor(
      name='dealer', full_name='poker.InitialData.dealer', index=1,
      number=2, type=11, cpp_type=10, label=1,
      has_default_value=False, default_value=None,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
    _descriptor.FieldDescriptor(
      name='sb_amount', full_name='poker.InitialData.sb_amount', index=2,
      number=3, type=2, cpp_type=6, label=1,
      has_default_value=False, default_value=float(0),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
    _descriptor.FieldDescriptor(
      name='bb_amount', full_name='poker.InitialData.bb_amount', index=3,
      number=4, type=2, cpp_type=6, label=1,
      has_default_value=False, default_value=float(0),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  serialized_options=None,
  is_extendable=False,
  syntax='proto3',
  extension_ranges=[],
  oneofs=[
  ],
  serialized_start=32,
  serialized_end=165,
)


_PLAYERDATA = _descriptor.Descriptor(
  name='PlayerData',
  full_name='poker.PlayerData',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  create_key=_descriptor._internal_create_key,
  fields=[
    _descriptor.FieldDescriptor(
      name='position', full_name='poker.PlayerData.position', index=0,
      number=1, type=13, cpp_type=3, label=1,
      has_default_value=False, default_value=0,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
    _descriptor.FieldDescriptor(
      name='type', full_name='poker.PlayerData.type', index=1,
      number=2, type=14, cpp_type=8, label=1,
      has_default_value=False, default_value=0,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
    _PLAYERDATA_PLAYERTYPE,
  ],
  serialized_options=None,
  is_extendable=False,
  syntax='proto3',
  extension_ranges=[],
  oneofs=[
  ],
  serialized_start=167,
  serialized_end=279,
)


_EMPTY = _descriptor.Descriptor(
  name='Empty',
  full_name='poker.Empty',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  create_key=_descriptor._internal_create_key,
  fields=[
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  serialized_options=None,
  is_extendable=False,
  syntax='proto3',
  extension_ranges=[],
  oneofs=[
  ],
  serialized_start=281,
  serialized_end=288,
)


_BOARDCARDSREQUEST = _descriptor.Descriptor(
  name='BoardCardsRequest',
  full_name='poker.BoardCardsRequest',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  create_key=_descriptor._internal_create_key,
  fields=[
    _descriptor.FieldDescriptor(
      name='round', full_name='poker.BoardCardsRequest.round', index=0,
      number=1, type=14, cpp_type=8, label=1,
      has_default_value=False, default_value=0,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  serialized_options=None,
  is_extendable=False,
  syntax='proto3',
  extension_ranges=[],
  oneofs=[
  ],
  serialized_start=290,
  serialized_end=338,
)


_PLAYERSTATEDATA = _descriptor.Descriptor(
  name='PlayerStateData',
  full_name='poker.PlayerStateData',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  create_key=_descriptor._internal_create_key,
  fields=[
    _descriptor.FieldDescriptor(
      name='chips', full_name='poker.PlayerStateData.chips', index=0,
      number=1, type=2, cpp_type=6, label=1,
      has_default_value=False, default_value=float(0),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
    _descriptor.FieldDescriptor(
      name='player', full_name='poker.PlayerStateData.player', index=1,
      number=2, type=11, cpp_type=10, label=1,
      has_default_value=False, default_value=None,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  serialized_options=None,
  is_extendable=False,
  syntax='proto3',
  extension_ranges=[],
  oneofs=[
  ],
  serialized_start=340,
  serialized_end=407,
)


_CARDSDATA = _descriptor.Descriptor(
  name='CardsData',
  full_name='poker.CardsData',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  create_key=_descriptor._internal_create_key,
  fields=[
    _descriptor.FieldDescriptor(
      name='cards', full_name='poker.CardsData.cards', index=0,
      number=1, type=11, cpp_type=10, label=3,
      has_default_value=False, default_value=[],
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  serialized_options=None,
  is_extendable=False,
  syntax='proto3',
  extension_ranges=[],
  oneofs=[
  ],
  serialized_start=409,
  serialized_end=452,
)


_CARDDATA = _descriptor.Descriptor(
  name='CardData',
  full_name='poker.CardData',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  create_key=_descriptor._internal_create_key,
  fields=[
    _descriptor.FieldDescriptor(
      name='suit', full_name='poker.CardData.suit', index=0,
      number=1, type=13, cpp_type=3, label=1,
      has_default_value=False, default_value=0,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
    _descriptor.FieldDescriptor(
      name='rank', full_name='poker.CardData.rank', index=1,
      number=2, type=13, cpp_type=3, label=1,
      has_default_value=False, default_value=0,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  serialized_options=None,
  is_extendable=False,
  syntax='proto3',
  extension_ranges=[],
  oneofs=[
  ],
  serialized_start=454,
  serialized_end=492,
)


_ACTIONDATA = _descriptor.Descriptor(
  name='ActionData',
  full_name='poker.ActionData',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  create_key=_descriptor._internal_create_key,
  fields=[
    _descriptor.FieldDescriptor(
      name='action_id', full_name='poker.ActionData.action_id', index=0,
      number=1, type=13, cpp_type=3, label=1,
      has_default_value=False, default_value=0,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
    _descriptor.FieldDescriptor(
      name='action_type', full_name='poker.ActionData.action_type', index=1,
      number=2, type=14, cpp_type=8, label=1,
      has_default_value=False, default_value=0,
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
    _descriptor.FieldDescriptor(
      name='amount', full_name='poker.ActionData.amount', index=2,
      number=3, type=2, cpp_type=6, label=1,
      has_default_value=False, default_value=float(0),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
    _ACTIONDATA_ACTIONTYPE,
  ],
  serialized_options=None,
  is_extendable=False,
  syntax='proto3',
  extension_ranges=[],
  oneofs=[
  ],
  serialized_start=495,
  serialized_end=670,
)


_AMOUNT = _descriptor.Descriptor(
  name='Amount',
  full_name='poker.Amount',
  filename=None,
  file=DESCRIPTOR,
  containing_type=None,
  create_key=_descriptor._internal_create_key,
  fields=[
    _descriptor.FieldDescriptor(
      name='value', full_name='poker.Amount.value', index=0,
      number=1, type=2, cpp_type=6, label=1,
      has_default_value=False, default_value=float(0),
      message_type=None, enum_type=None, containing_type=None,
      is_extension=False, extension_scope=None,
      serialized_options=None, file=DESCRIPTOR,  create_key=_descriptor._internal_create_key),
  ],
  extensions=[
  ],
  nested_types=[],
  enum_types=[
  ],
  serialized_options=None,
  is_extendable=False,
  syntax='proto3',
  extension_ranges=[],
  oneofs=[
  ],
  serialized_start=672,
  serialized_end=695,
)

_INITIALDATA.fields_by_name['players_state'].message_type = _PLAYERSTATEDATA
_INITIALDATA.fields_by_name['dealer'].message_type = _PLAYERDATA
_PLAYERDATA.fields_by_name['type'].enum_type = _PLAYERDATA_PLAYERTYPE
_PLAYERDATA_PLAYERTYPE.containing_type = _PLAYERDATA
_BOARDCARDSREQUEST.fields_by_name['round'].enum_type = _ROUND
_PLAYERSTATEDATA.fields_by_name['player'].message_type = _PLAYERDATA
_CARDSDATA.fields_by_name['cards'].message_type = _CARDDATA
_ACTIONDATA.fields_by_name['action_type'].enum_type = _ACTIONDATA_ACTIONTYPE
_ACTIONDATA_ACTIONTYPE.containing_type = _ACTIONDATA
DESCRIPTOR.message_types_by_name['InitialData'] = _INITIALDATA
DESCRIPTOR.message_types_by_name['PlayerData'] = _PLAYERDATA
DESCRIPTOR.message_types_by_name['Empty'] = _EMPTY
DESCRIPTOR.message_types_by_name['BoardCardsRequest'] = _BOARDCARDSREQUEST
DESCRIPTOR.message_types_by_name['PlayerStateData'] = _PLAYERSTATEDATA
DESCRIPTOR.message_types_by_name['CardsData'] = _CARDSDATA
DESCRIPTOR.message_types_by_name['CardData'] = _CARDDATA
DESCRIPTOR.message_types_by_name['ActionData'] = _ACTIONDATA
DESCRIPTOR.message_types_by_name['Amount'] = _AMOUNT
DESCRIPTOR.enum_types_by_name['Round'] = _ROUND
_sym_db.RegisterFileDescriptor(DESCRIPTOR)

InitialData = _reflection.GeneratedProtocolMessageType('InitialData', (_message.Message,), {
  'DESCRIPTOR' : _INITIALDATA,
  '__module__' : 'poker_messages_pb2'
  # @@protoc_insertion_point(class_scope:poker.InitialData)
  })
_sym_db.RegisterMessage(InitialData)

PlayerData = _reflection.GeneratedProtocolMessageType('PlayerData', (_message.Message,), {
  'DESCRIPTOR' : _PLAYERDATA,
  '__module__' : 'poker_messages_pb2'
  # @@protoc_insertion_point(class_scope:poker.PlayerData)
  })
_sym_db.RegisterMessage(PlayerData)

Empty = _reflection.GeneratedProtocolMessageType('Empty', (_message.Message,), {
  'DESCRIPTOR' : _EMPTY,
  '__module__' : 'poker_messages_pb2'
  # @@protoc_insertion_point(class_scope:poker.Empty)
  })
_sym_db.RegisterMessage(Empty)

BoardCardsRequest = _reflection.GeneratedProtocolMessageType('BoardCardsRequest', (_message.Message,), {
  'DESCRIPTOR' : _BOARDCARDSREQUEST,
  '__module__' : 'poker_messages_pb2'
  # @@protoc_insertion_point(class_scope:poker.BoardCardsRequest)
  })
_sym_db.RegisterMessage(BoardCardsRequest)

PlayerStateData = _reflection.GeneratedProtocolMessageType('PlayerStateData', (_message.Message,), {
  'DESCRIPTOR' : _PLAYERSTATEDATA,
  '__module__' : 'poker_messages_pb2'
  # @@protoc_insertion_point(class_scope:poker.PlayerStateData)
  })
_sym_db.RegisterMessage(PlayerStateData)

CardsData = _reflection.GeneratedProtocolMessageType('CardsData', (_message.Message,), {
  'DESCRIPTOR' : _CARDSDATA,
  '__module__' : 'poker_messages_pb2'
  # @@protoc_insertion_point(class_scope:poker.CardsData)
  })
_sym_db.RegisterMessage(CardsData)

CardData = _reflection.GeneratedProtocolMessageType('CardData', (_message.Message,), {
  'DESCRIPTOR' : _CARDDATA,
  '__module__' : 'poker_messages_pb2'
  # @@protoc_insertion_point(class_scope:poker.CardData)
  })
_sym_db.RegisterMessage(CardData)

ActionData = _reflection.GeneratedProtocolMessageType('ActionData', (_message.Message,), {
  'DESCRIPTOR' : _ACTIONDATA,
  '__module__' : 'poker_messages_pb2'
  # @@protoc_insertion_point(class_scope:poker.ActionData)
  })
_sym_db.RegisterMessage(ActionData)

Amount = _reflection.GeneratedProtocolMessageType('Amount', (_message.Message,), {
  'DESCRIPTOR' : _AMOUNT,
  '__module__' : 'poker_messages_pb2'
  # @@protoc_insertion_point(class_scope:poker.Amount)
  })
_sym_db.RegisterMessage(Amount)


DESCRIPTOR._options = None
# @@protoc_insertion_point(module_scope)
