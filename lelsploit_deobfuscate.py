








from __future__ import annotations
import argparse
import ast
import base64
import binascii
import codecs
import bz2
import lzma
import io
import json
import hashlib
import math
import os
from pathlib import Path
import re
import struct
import sys
import textwrap
import zlib
from urllib.parse import unquote_to_bytes
from dataclasses import dataclass, field
from enum import IntEnum, Enum
from functools import reduce
from typing import Any, Callable, Iterable, Optional, Union, List, Dict, Tuple
from collections import Counter, defaultdict

__version__ = "2.1.0"

__product__ = "LelSploit"
__license__ = "GPL-3.0-or-later"
__attribution__ = "Contains GPL-3.0-derived MoonSec V3 bytecode logic based on tupsutumppu/MoonsecDeobfuscator and transforms adapted from 0x251/Prometheus-Deobfuscator."






from dataclasses import dataclass, field
from enum import IntEnum, Enum
from typing import Any


class OpCode(IntEnum):
    MOVE = 0
    LOADK = 1
    LOADBOOL = 2
    LOADNIL = 3
    GETUPVAL = 4
    GETGLOBAL = 5
    GETTABLE = 6
    SETGLOBAL = 7
    SETUPVAL = 8
    SETTABLE = 9
    NEWTABLE = 10
    SELF = 11
    ADD = 12
    SUB = 13
    MUL = 14
    DIV = 15
    MOD = 16
    POW = 17
    UNM = 18
    NOT = 19
    LEN = 20
    CONCAT = 21
    JMP = 22
    EQ = 23
    LT = 24
    LE = 25
    TEST = 26
    TESTSET = 27
    CALL = 28
    TAILCALL = 29
    RETURN = 30
    FORLOOP = 31
    FORPREP = 32
    TFORLOOP = 33
    SETLIST = 34
    CLOSE = 35
    CLOSURE = 36
    VARARG = 37
    UNKNOWN = 38


class OpType(Enum):
    AB = "AB"
    ABC = "ABC"
    ABX = "ABx"
    ASBX = "AsBx"
    SBX = "sBx"
    AC = "AC"
    A = "A"


OP_TYPES: dict[OpCode, OpType] = {
    **{op: OpType.AB for op in (
        OpCode.MOVE, OpCode.LOADNIL, OpCode.GETUPVAL, OpCode.SETUPVAL,
        OpCode.UNM, OpCode.NOT, OpCode.LEN, OpCode.RETURN, OpCode.VARARG,
    )},
    **{op: OpType.ABX for op in (
        OpCode.LOADK, OpCode.GETGLOBAL, OpCode.SETGLOBAL, OpCode.CLOSURE,
    )},
    **{op: OpType.ABC for op in (
        OpCode.LOADBOOL, OpCode.GETTABLE, OpCode.SETTABLE, OpCode.ADD,
        OpCode.SUB, OpCode.MUL, OpCode.DIV, OpCode.MOD, OpCode.POW,
        OpCode.CONCAT, OpCode.CALL, OpCode.TAILCALL, OpCode.SELF,
        OpCode.EQ, OpCode.LT, OpCode.LE, OpCode.TESTSET,
        OpCode.NEWTABLE, OpCode.SETLIST,
    )},
    OpCode.JMP: OpType.SBX,
    OpCode.TEST: OpType.AC,
    OpCode.TFORLOOP: OpType.AC,
    OpCode.FORPREP: OpType.ASBX,
    OpCode.FORLOOP: OpType.ASBX,
    OpCode.CLOSE: OpType.A,
}


def op_type(op: OpCode) -> OpType:
    if op not in OP_TYPES:
        raise ValueError(f"No Lua 5.1 encoding type for opcode {op.name}")
    return OP_TYPES[op]


@dataclass(eq=False)
class Constant:
    value: Any = None


@dataclass(eq=False)
class StringConstant(Constant):
    value: str = ""


@dataclass(eq=False)
class NumberConstant(Constant):
    value: float = 0.0


@dataclass(eq=False)
class BooleanConstant(Constant):
    value: bool = False


@dataclass(eq=False)
class NilConstant(Constant):
    value: None = None


@dataclass(eq=False)
class Instruction:
    a: int = 0
    b: int = 0
    c: int = 0
    op_num: int = 0
    pc: int = 0
    is_ka: bool = False
    is_kb: bool = False
    is_kc: bool = False
    is_dead: bool = False
    function: "Function | None" = None
    opcode: OpCode = OpCode.UNKNOWN

    def clone(self) -> "Instruction":
        return Instruction(
            a=self.a, b=self.b, c=self.c, op_num=self.op_num, pc=self.pc,
            is_ka=self.is_ka, is_kb=self.is_kb, is_kc=self.is_kc,
            is_dead=self.is_dead, function=self.function, opcode=self.opcode,
        )


@dataclass(eq=False)
class Function:
    instructions: list[Instruction] = field(default_factory=list)
    constants: list[Constant] = field(default_factory=list)
    functions: list["Function"] = field(default_factory=list)
    max_stack_size: int = 2
    num_params: int = 0
    num_upvalues: int = 0
    is_vararg_flag: int = 0
    name: str = ""

    def __post_init__(self) -> None:
        if not self.name:
            self.name = f"func_{id(self) & 0xFFFFFFFF:08x}"
        for ins in self.instructions:
            ins.function = self



"""MoonSec string/blob decoding helpers.

Semantics ported from the original GPL-3.0 C# implementation.
"""

import io
import struct


def decode_escape(data: str) -> bytes:
    """Decode MoonSec's decimal backslash byte representation (e.g. ``\\4\\8``)."""
    if not data:
        return b""
    parts = data.split("\\")[1:]
    return bytes(int(part, 10) & 0xFF for part in parts if part != "")


def decode(data: str, key: int) -> bytes:
    """Decode the custom 16-symbol nibble alphabet with a rolling additive key."""
    if len(data) < 16:
        raise ValueError("encoded MoonSec blob must contain a 16-character alphabet prefix")
    chars = {ch: i for i, ch in enumerate(data[:16])}
    out = bytearray()
    rolling = key
    for i in range(16, len(data), 2):
        c1 = data[i]
        c2 = data[i + 1] if i + 1 < len(data) else "\0"
        i1 = chars.get(c1, 0)
        i2 = chars.get(c2, 0)
        out.append((i1 * 16 + i2 + rolling) & 0xFF)
        rolling += key
    return bytes(out)


def decode_constant(key: int, data: bytes) -> str:
    if not (len(data) > 1 and data[0] > 0x7F):
        return data.decode("utf-8", errors="replace")
    transformed = bytes(((b + key) & 0xFF) for b in data[1:])
    return transformed.decode("utf-8", errors="replace")


def decode_constants(data: bytes) -> dict[str, list[str]]:
    """Decode the constant-replacement dictionary embedded in MoonSec's Lua source."""
    stream = io.BytesIO(data)
    constants: dict[str, list[str]] = {}

    def read_exact(n: int) -> bytes:
        value = stream.read(n)
        if len(value) != n:
            raise EOFError("truncated MoonSec constant table")
        return value

    while True:
        raw = stream.read(1)
        if not raw:
            raise EOFError("constant table ended before control byte 5")
        control = raw[0]
        if control == 5:
            break
        if control == 1:
            control += 1

        size = read_exact(1)[0]
        first = read_exact(size).decode("utf-8", errors="replace")
        if control == 0:
            second_size = read_exact(1)[0]
            second = read_exact(second_size).decode("utf-8", errors="replace")
            value = [first, second]
        elif control in (2, 4, 6):
            value = [first]
        else:
            value = []
        map_key = read_exact(8).decode("utf-8", errors="replace")
        constants[map_key] = value
    return constants




from dataclasses import dataclass, field
from enum import Enum
import json
from pathlib import Path


class ProtoStep(str, Enum):
    INSTRUCTIONS = "Instructions"
    CONSTANTS = "Constants"
    FUNCTIONS = "Functions"
    NUM_PARAMS = "NumParams"
    STRING_CONSTANT = "StringConstant"
    NUMBER_CONSTANT = "NumberConstant"
    BOOLEAN_CONSTANT = "BooleanConstant"


@dataclass
class Context:
    identified_names: dict[str, str] = field(default_factory=dict)
    proto_format: list[ProtoStep] = field(default_factory=list)
    constant_format: dict[int, ProtoStep] = field(default_factory=dict)
    bytecode_string: str = ""
    bytecode_key: int = 0
    constant_key: int = 0
    opcode_fingerprints: dict[int, list[str]] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, obj: dict) -> "Context":
        return cls(
            identified_names=dict(obj.get("identified_names", {})),
            proto_format=[ProtoStep(x) for x in obj.get("proto_format", [])],
            constant_format={int(k): ProtoStep(v) for k, v in obj.get("constant_format", {}).items()},
            bytecode_string=str(obj.get("bytecode_string", "")),
            bytecode_key=int(obj.get("bytecode_key", 0)),
            constant_key=int(obj.get("constant_key", 0)),
            opcode_fingerprints={int(k): list(v) for k, v in obj.get("opcode_fingerprints", {}).items()},
        )

    @classmethod
    def from_json(cls, path: str | Path) -> "Context":
        return cls.from_dict(json.loads(Path(path).read_text(encoding="utf-8")))

    def to_dict(self) -> dict:
        return {
            "identified_names": self.identified_names,
            "proto_format": [x.value for x in self.proto_format],
            "constant_format": {str(k): v.value for k, v in self.constant_format.items()},
            "bytecode_string": self.bytecode_string,
            "bytecode_key": self.bytecode_key,
            "constant_key": self.constant_key,
            "opcode_fingerprints": {str(k): v for k, v in self.opcode_fingerprints.items()},
        }



"""Fingerprint -> Lua 5.1 opcode mapping used by MoonSec V3 handlers.

Fingerprints are structural operation sequences.  The mapping and operand
normalization mirror the upstream GPL-3.0 implementation.
"""

from collections.abc import Callable


Transform = Callable[[Instruction], None]


def _nop(_: Instruction) -> None: pass

def _b_dec(i: Instruction) -> None: i.b -= 1

def _b_k(i: Instruction) -> None: i.b += 255

def _c_k(i: Instruction) -> None: i.c += 255

def _bc_k(i: Instruction) -> None: i.b += 255; i.c += 255

def _jump(i: Instruction) -> None: i.b -= i.pc + 1

def _forprep(i: Instruction) -> None: i.b -= i.pc + 2

def _call_b(i: Instruction) -> None: i.b -= i.a - 1

def _call_c(i: Instruction) -> None: i.c -= i.a - 2

def _call_bc(i: Instruction) -> None: i.b -= i.a - 1; i.c -= i.a - 2

def _ret_b(i: Instruction) -> None: i.b += 2

def _setlist_b(i: Instruction) -> None: i.b -= i.a

def _vararg_b(i: Instruction) -> None: i.b -= i.a - 1

def _tfor(i: Instruction) -> None: i.b = 0

def _loadbool_c1(i: Instruction) -> None: i.c = 1

def _test0(i: Instruction) -> None: i.b = 0; i.c = 0

def _test1(i: Instruction) -> None: i.b = 0; i.c = 1

def _testset0(i: Instruction) -> None: i.b = i.c; i.c = 0

def _testset1(i: Instruction) -> None: i.b = i.c; i.c = 1


def _cmp(a: int, b_const: bool = False, c_const: bool = False) -> Transform:
    def transform(i: Instruction) -> None:
        i.b = i.a + (255 if b_const else 0)
        i.a = a
        if c_const:
            i.c += 255
    return transform





STATIC_OPCODES: dict[str, tuple[OpCode, Transform]] = {

    "91909190": (OpCode.MOVE, _nop),
    "1419090": (OpCode.LOADK, _b_dec),
    "91902690": (OpCode.LOADBOOL, _nop),
    "91902690291529": (OpCode.LOADBOOL, _loadbool_c1),
    "13909091": (OpCode.LOADNIL, _nop),
    "91909290": (OpCode.GETUPVAL, _nop),
    "91909390": (OpCode.GETGLOBAL, _b_dec),
    "9190991909190": (OpCode.GETTABLE, _nop),
    "91909919090": (OpCode.GETTABLE, _c_k),
    "93909190": (OpCode.SETGLOBAL, _b_dec),
    "92909190": (OpCode.SETUPVAL, _nop),
    "9919091909190": (OpCode.SETTABLE, _nop),
    "99190919090": (OpCode.SETTABLE, _c_k),
    "99190909190": (OpCode.SETTABLE, _b_k),
    "991909090": (OpCode.SETTABLE, _bc_k),
    "919033": (OpCode.NEWTABLE, _nop),
    "909190911591990": (OpCode.SELF, _c_k),
    "90919091159199190": (OpCode.SELF, _nop),


    "91901591909190": (OpCode.ADD, _nop),
    "919015919090": (OpCode.ADD, _c_k),
    "919015909190": (OpCode.ADD, _b_k),
    "9190159090": (OpCode.ADD, _bc_k),
    "91901691909190": (OpCode.SUB, _nop),
    "919016919090": (OpCode.SUB, _c_k),
    "919016909190": (OpCode.SUB, _b_k),
    "9190169090": (OpCode.SUB, _bc_k),
    "91901791909190": (OpCode.MUL, _nop),
    "919017919090": (OpCode.MUL, _c_k),
    "919017909190": (OpCode.MUL, _b_k),
    "9190179090": (OpCode.MUL, _bc_k),
    "91901891909190": (OpCode.DIV, _nop),
    "919018919090": (OpCode.DIV, _c_k),
    "919018909190": (OpCode.DIV, _b_k),
    "9190189090": (OpCode.DIV, _bc_k),
    "91901991909190": (OpCode.MOD, _nop),
    "919019919090": (OpCode.MOD, _c_k),
    "919019909190": (OpCode.MOD, _b_k),
    "9190199090": (OpCode.MOD, _bc_k),
    "91902091909190": (OpCode.POW, _nop),
    "919020919090": (OpCode.POW, _c_k),
    "919020909190": (OpCode.POW, _b_k),
    "9190209090": (OpCode.POW, _bc_k),
    "9190319190": (OpCode.UNM, _nop),
    "9190349190": (OpCode.NOT, _nop),
    "9190289190": (OpCode.LEN, _nop),
    "909113159032919190": (OpCode.CONCAT, _nop),


    "2990": (OpCode.JMP, _jump),
    "101225919091902915292990": (OpCode.EQ, _cmp(0, False, False)),
    "1012259190902915292990": (OpCode.EQ, _cmp(0, False, True)),
    "1012259091902915292990": (OpCode.EQ, _cmp(0, True, False)),
    "10122590902915292990": (OpCode.EQ, _cmp(0, True, True)),
    "101226919091902915292990": (OpCode.EQ, _cmp(1, False, False)),
    "1012269190902915292990": (OpCode.EQ, _cmp(1, False, True)),
    "1012269091902915292990": (OpCode.EQ, _cmp(1, True, False)),
    "10122690902915292990": (OpCode.EQ, _cmp(1, True, True)),
    "2936352591909190901529": (OpCode.EQ, _cmp(1, False, False)),

    "101221919091902915292990": (OpCode.LT, _cmp(0, False, False)),
    "1012219091902915292990": (OpCode.LT, _cmp(0, True, False)),
    "1012219190902915292990": (OpCode.LT, _cmp(0, False, True)),
    "10122190902915292990": (OpCode.LT, _cmp(0, True, True)),
    "101221919091902990291529": (OpCode.LT, _cmp(1, False, False)),
    "1012219091902990291529": (OpCode.LT, _cmp(1, True, False)),
    "1012219190902990291529": (OpCode.LT, _cmp(1, False, True)),
    "10122190902990291529": (OpCode.LT, _cmp(1, True, True)),

    "101223919091902915292990": (OpCode.LE, _cmp(0, False, False)),
    "1012239091902915292990": (OpCode.LE, _cmp(0, True, False)),
    "1012239190902915292990": (OpCode.LE, _cmp(0, False, True)),
    "10122390902915292990": (OpCode.LE, _cmp(0, True, True)),
    "101223919091902990291529": (OpCode.LE, _cmp(1, False, False)),
    "1012239190902990291529": (OpCode.LE, _cmp(1, False, True)),
    "1012239091902990291529": (OpCode.LE, _cmp(1, True, False)),
    "10122390902990291529": (OpCode.LE, _cmp(1, True, True)),

    "101291902915292990": (OpCode.TEST, _test0),
    "10123491902915292990": (OpCode.TEST, _test1),
    "9190101229152991902990": (OpCode.TESTSET, _testset0),
    "919010123429152991902990": (OpCode.TESTSET, _testset1),


    "149190": (OpCode.CALL, _nop),
    "909114919115": (OpCode.CALL, _nop),
    "9091149114511590": (OpCode.CALL, _call_b),
    "9014919115": (OpCode.CALL, _nop),
    "90149114511590": (OpCode.CALL, _call_b),
    "9091149114511530": (OpCode.CALL, _nop),
    "903314919115139015919": (OpCode.CALL, _call_c),
    "90911491": (OpCode.CALL, _nop),
    "90141491301615133015919": (OpCode.CALL, _nop),
    "901414919115301615133015919": (OpCode.CALL, _call_b),
    "9014149114511590301615133015919": (OpCode.CALL, _call_b),
    "90149114511530": (OpCode.CALL, _nop),
    "9033149114511590139015919": (OpCode.CALL, _call_bc),
    "9033149114511530139015919": (OpCode.CALL, _call_c),
    "90331491901315919": (OpCode.CALL, _call_c),
    "9014149114511530301615133015919": (OpCode.CALL, _nop),
    "9027149114511590": (OpCode.TAILCALL, _call_b),
    "9027149114511530": (OpCode.TAILCALL, _nop),
    "27149190": (OpCode.TAILCALL, _nop),
    "27": (OpCode.RETURN, _nop),
    "279190": (OpCode.RETURN, _nop),
    "9027145130": (OpCode.RETURN, _nop),
    "902714511590": (OpCode.RETURN, _ret_b),
    "9027919115": (OpCode.RETURN, _nop),


    "909115159191101122102391152990911524911529909115": (OpCode.FORLOOP, _jump),
    "909191151011122210122291152990911521911529909115": (OpCode.FORPREP, _forprep),
    "909015331491911591139115991012912990291529": (OpCode.TFORLOOP, _tfor),
    "909113153014691": (OpCode.SETLIST, _nop),
    "909113159014691": (OpCode.SETLIST, _setlist_b),
    "3313289132899910352512490999": (OpCode.CLOSE, _nop),
    "990331473333927999999913902915299291012259916331991633299152891901483": (OpCode.CLOSURE, _nop),
    "91901489903": (OpCode.CLOSURE, _nop),
    "903016151330941691": (OpCode.VARARG, _nop),
    "909013919416": (OpCode.VARARG, _vararg_b),
}


def apply_fingerprint(instruction: Instruction, fingerprint: str) -> bool:
    item = STATIC_OPCODES.get(fingerprint)
    if item is None:
        return False
    opcode, transform = item
    instruction.opcode = opcode
    transform(instruction)
    return True




import io
import struct



class Deserializer:
    """Reader for MoonSec's custom serialized prototype format."""

    def __init__(self, data: bytes, ctx: Context):
        self.stream = io.BytesIO(data)
        self.ctx = ctx

    def _read(self, fmt: str):
        size = struct.calcsize(fmt)
        data = self.stream.read(size)
        if len(data) != size:
            raise EOFError(f"truncated input while reading {fmt}")
        return struct.unpack(fmt, data)[0]

    def read_u8(self) -> int:
        return self._read("<B")

    def read_i16(self) -> int:
        return self._read("<h")

    def read_i32(self) -> int:
        return self._read("<i")

    def read_f64(self) -> float:
        return self._read("<d")

    def read_bytes(self, count: int) -> bytes:
        data = self.stream.read(count)
        if len(data) != count:
            raise EOFError("truncated input while reading bytes")
        return data

    @staticmethod
    def get_bits(source: int, start: int, end: int) -> int:
        return (source >> (start - 1)) & ((1 << (end - start + 1)) - 1)

    def read_instructions(self, function: Function) -> list[Instruction]:
        size = self.read_i32()
        if size < 0:
            raise ValueError("negative instruction count")
        result: list[Instruction] = []
        for pc in range(size):
            descriptor = self.read_u8()
            if self.get_bits(descriptor, 1, 1) != 0:
                continue
            instruction_type = self.get_bits(descriptor, 2, 3)
            mask = self.get_bits(descriptor, 4, 6)
            ins = Instruction(
                op_num=self.read_i16(),
                a=self.read_i16(),
                pc=pc,
                function=function,
            )
            if instruction_type == 0:
                ins.b = self.read_i16()
                ins.c = self.read_i16()
            elif instruction_type == 1:
                ins.b = self.read_i32()
            elif instruction_type == 2:
                ins.b = self.read_i32() - (1 << 16)
            elif instruction_type == 3:
                ins.b = self.read_i32() - (1 << 16)
                ins.c = self.read_i16()
            else:
                raise ValueError(f"invalid instruction type {instruction_type}")
            ins.is_ka = self.get_bits(mask, 1, 1) == 1
            ins.is_kb = self.get_bits(mask, 2, 2) == 1
            ins.is_kc = self.get_bits(mask, 3, 3) == 1
            result.append(ins)
        return result

    def read_prototypes(self) -> list[Function]:
        count = self.read_i32()
        if count < 0:
            raise ValueError("negative prototype count")
        return [self.read_function() for _ in range(count)]

    def read_constants(self) -> list:
        count = self.read_i32()
        if count < 0:
            raise ValueError("negative constant count")
        constants = []
        for _ in range(count):
            type_flag = self.read_u8()
            const_type = self.ctx.constant_format.get(type_flag)
            if const_type is None:
                constants.append(NilConstant())
            elif const_type == ProtoStep.BOOLEAN_CONSTANT:
                constants.append(BooleanConstant(bool(self.read_u8())))
            elif const_type == ProtoStep.NUMBER_CONSTANT:
                constants.append(NumberConstant(self.read_f64()))
            elif const_type == ProtoStep.STRING_CONSTANT:
                length = self.read_i32()
                if length < 0:
                    raise ValueError("negative string constant length")
                constants.append(StringConstant(decode_constant(self.ctx.constant_key, self.read_bytes(length))))
            else:
                raise ValueError(f"unexpected constant proto step {const_type}")
        return constants

    def read_function(self) -> Function:
        function = Function()
        for step in self.ctx.proto_format:
            if step == ProtoStep.CONSTANTS:
                function.constants = self.read_constants()
            elif step == ProtoStep.INSTRUCTIONS:
                function.instructions = self.read_instructions(function)
            elif step == ProtoStep.NUM_PARAMS:
                function.num_params = self.read_u8()
            elif step == ProtoStep.FUNCTIONS:
                function.functions = self.read_prototypes()
        for ins in function.instructions:
            ins.function = function
        return function






class UnknownHandlerError(ValueError):
    pass


class BytecodeDeobfuscator:
    """Translate handler fingerprints and perform the original cleanup passes.

    The C# project derives fingerprints from its custom Lua AST frontend.  This
    Python module consumes an equivalent ``opcode_fingerprints`` mapping, making
    the devirtualization/bytecode half independent of a particular Lua parser.
    """

    def __init__(self, root: Function, opcode_fingerprints: dict[int, list[str]]):
        self.root = root
        self.opcode_fingerprints = opcode_fingerprints

    def deobfuscate(self) -> Function:
        self._deobfuscate_opcodes(self.root)
        self._deobfuscate_control_flow(self.root)
        self._fix_program_entry()
        self._rebuild_constant_pool(self.root)
        self._set_flags(self.root)
        self.root.is_vararg_flag = 2
        return self.root

    def _deobfuscate_opcodes(self, function: Function) -> None:
        instructions = function.instructions
        jump_targets: set[int] = set()
        i = 0
        while i < len(instructions):
            ins = instructions[i]
            fingerprints = self.opcode_fingerprints.get(ins.op_num)
            if not fingerprints:
                raise UnknownHandlerError(f"no handler fingerprints for MoonSec opcode {ins.op_num}")
            current = ins
            for idx, fingerprint in enumerate(fingerprints):
                if not apply_fingerprint(current, fingerprint):
                    raise UnknownHandlerError(f"unknown handler fingerprint: {fingerprint}")
                if current.opcode == OpCode.JMP:
                    jump_targets.add(i + current.b + 1)
                if current.opcode in (OpCode.RETURN, OpCode.TAILCALL):
                    j = i + 1
                    while j < len(instructions) and j not in jump_targets:
                        instructions[j].is_dead = True
                        j += 1
                    if j < len(instructions):
                        i = j - 1
                    break
                if idx != len(fingerprints) - 1 and i + 1 < len(instructions):
                    i += 1
                    current = instructions[i]
            i += 1
        for child in function.functions:
            self._deobfuscate_opcodes(child)

    @classmethod
    def _deobfuscate_control_flow(cls, function: Function) -> None:
        refs = cls._compute_jump_references(function)
        function.instructions[:] = [i for i in function.instructions if not i.is_dead]
        cls._remove_test_flip(function)
        cls._fix_tail_call(function)
        cls._fix_jump_offsets(function, refs)
        for child in function.functions:
            cls._deobfuscate_control_flow(child)

    @staticmethod
    def _compute_jump_references(function: Function) -> dict[Instruction, Instruction]:
        refs: dict[Instruction, Instruction] = {}
        instructions = function.instructions
        for idx, ins in enumerate(instructions):
            if ins.opcode in (OpCode.JMP, OpCode.FORLOOP, OpCode.FORPREP):
                target_idx = idx + ins.b + 1
                if 0 <= target_idx < len(instructions):
                    refs[ins] = instructions[target_idx]
        return refs

    @staticmethod
    def _remove_test_flip(function: Function) -> None:
        ins = function.instructions
        i = 0
        while i + 2 < len(ins):
            cur = ins[i]
            if cur.opcode in (OpCode.EQ, OpCode.LT, OpCode.LE, OpCode.TEST) \
                    and ins[i + 1].opcode == OpCode.JMP and ins[i + 2].opcode == OpCode.JMP:
                if cur.opcode in (OpCode.EQ, OpCode.LT, OpCode.LE):
                    cur.a = 0 if cur.a == 1 else 1
                else:
                    cur.c = 0 if cur.c == 1 else 1
                del ins[i + 1]
            i += 1

    @staticmethod
    def _fix_tail_call(function: Function) -> None:
        i = 0
        while i < len(function.instructions):
            cur = function.instructions[i]
            if cur.opcode == OpCode.TAILCALL:
                if i + 1 >= len(function.instructions) or function.instructions[i + 1].opcode != OpCode.RETURN:
                    function.instructions.insert(i + 1, Instruction(opcode=OpCode.RETURN, a=cur.a, function=function))
                    i += 1
            i += 1

    @staticmethod
    def _fix_jump_offsets(function: Function, refs: dict[Instruction, Instruction]) -> None:
        pos = {id(ins): i for i, ins in enumerate(function.instructions)}
        for i, ins in enumerate(function.instructions):
            target = refs.get(ins)
            if target is not None and id(target) in pos:
                ins.b = pos[id(target)] - (i + 1)

    def _fix_program_entry(self) -> None:
        check_idx = None
        for idx, ins in enumerate(self.root.instructions):
            if ins.opcode == OpCode.EQ and ins.c > 255 and ins.function is not None:
                ci = ins.c - 256
                if 0 <= ci < len(ins.function.constants):
                    c = ins.function.constants[ci]
                    if isinstance(c, StringConstant) and c.value.startswith("This file was protected with MoonSec V3"):
                        check_idx = idx
                        break
        if check_idx is None:
            return
        for i in range(check_idx, len(self.root.instructions)):
            if self.root.instructions[i].opcode == OpCode.RETURN:
                del self.root.instructions[: i + 1]
                break
        self._remove_unused_functions()

    def _remove_unused_functions(self) -> None:
        refs: list[tuple[Instruction, Function]] = []
        for ins in self.root.instructions:
            if ins.opcode == OpCode.CLOSURE and 0 <= ins.b < len(self.root.functions):
                refs.append((ins, self.root.functions[ins.b]))
        used = {id(fn) for _, fn in refs}
        self.root.functions[:] = [fn for fn in self.root.functions if id(fn) in used]
        positions = {id(fn): i for i, fn in enumerate(self.root.functions)}
        for ins, fn in refs:
            if id(fn) in positions:
                ins.b = positions[id(fn)]

    @classmethod
    def _rebuild_constant_pool(cls, function: Function) -> None:
        remap: dict[int, int] = {}
        new_order = []

        def remap_const(old_idx: int) -> int:
            if old_idx not in remap:
                if not 0 <= old_idx < len(function.constants):
                    return old_idx
                remap[old_idx] = len(new_order)
                new_order.append(function.constants[old_idx])
            return remap[old_idx]

        def remap_rk(operand: int) -> int:
            return remap_const(operand - 256) + 256 if operand >= 256 else operand

        for ins in function.instructions:
            if ins.opcode in (OpCode.LOADK, OpCode.GETGLOBAL, OpCode.SETGLOBAL):
                ins.b = remap_const(ins.b)
            elif ins.opcode in (OpCode.SETTABLE, OpCode.EQ, OpCode.LT, OpCode.LE,
                                 OpCode.ADD, OpCode.SUB, OpCode.MUL, OpCode.DIV,
                                 OpCode.MOD, OpCode.POW):
                ins.b = remap_rk(ins.b)
                ins.c = remap_rk(ins.c)
            elif ins.opcode in (OpCode.GETTABLE, OpCode.SELF):
                ins.c = remap_rk(ins.c)
        function.constants = new_order
        for child in function.functions:
            cls._rebuild_constant_pool(child)

    @classmethod
    def _set_flags(cls, function: Function) -> None:
        function.is_vararg_flag = 0
        max_a = 0
        for ins in function.instructions:
            max_a = max(max_a, ins.a)
            if ins.opcode == OpCode.CLOSURE and 0 <= ins.b < len(function.functions):
                function.functions[ins.b].num_upvalues = ins.c & 0xFF
            elif ins.opcode == OpCode.VARARG:
                function.is_vararg_flag = 2
        function.max_stack_size = max(2, max_a + 1)
        for child in function.functions:
            cls._set_flags(child)




import io
import struct
from pathlib import Path
from typing import BinaryIO



class Lua51Serializer:
    """Serialize the recovered model as a standard little-endian Lua 5.1 chunk."""

    HEADER = b"\x1bLua\x51\x00\x01\x04\x08\x04\x08\x00"

    def __init__(self, stream: BinaryIO | None = None):
        self.stream = stream or io.BytesIO()

    def _write(self, fmt: str, value) -> None:
        self.stream.write(struct.pack(fmt, value))

    def write_string(self, value: str) -> None:
        encoded = value.encode("utf-8")
        self._write("<Q", len(encoded) + 1)
        self.stream.write(encoded)
        self.stream.write(b"\0")

    @staticmethod
    def encode_instruction(ins) -> int:
        op = int(ins.opcode) & 0x3F
        typ = op_type(ins.opcode)
        data = op
        if typ == OpType.A:
            data |= (ins.a & 0xFF) << 6
        elif typ == OpType.AB:
            data |= (ins.a & 0xFF) << 6
            data |= (ins.b & 0x1FF) << 23
        elif typ == OpType.ABC:
            data |= (ins.a & 0xFF) << 6
            data |= (ins.b & 0x1FF) << 23
            data |= (ins.c & 0x1FF) << 14
        elif typ == OpType.ABX:
            data |= (ins.a & 0xFF) << 6
            data |= (ins.b & 0x3FFFF) << 14
        elif typ == OpType.ASBX:
            data |= (ins.a & 0xFF) << 6
            data |= ((ins.b + 131071) & 0x3FFFF) << 14
        elif typ == OpType.SBX:
            data |= ((ins.b + 131071) & 0x3FFFF) << 14
        elif typ == OpType.AC:
            data |= (ins.a & 0xFF) << 6
            data |= (ins.c & 0x1FF) << 14
        return data & 0xFFFFFFFF

    def write_instructions(self, function: Function) -> None:
        self._write("<i", len(function.instructions))
        for ins in function.instructions:
            self._write("<I", self.encode_instruction(ins))

    def write_constants(self, function: Function) -> None:
        self._write("<i", len(function.constants))
        for const in function.constants:
            if isinstance(const, StringConstant):
                self._write("<B", 4)
                self.write_string(const.value)
            elif isinstance(const, NumberConstant):
                self._write("<B", 3)
                self._write("<d", const.value)
            elif isinstance(const, BooleanConstant):
                self._write("<B", 1)
                self._write("<B", 1 if const.value else 0)
            elif isinstance(const, NilConstant):
                self._write("<B", 0)
            else:
                raise TypeError(f"unsupported constant {type(const).__name__}")

    def write_function(self, function: Function) -> None:
        self.write_string("")
        self._write("<i", 0)
        self._write("<i", 0)
        self._write("<B", function.num_upvalues & 0xFF)
        self._write("<B", function.num_params & 0xFF)
        self._write("<B", function.is_vararg_flag & 0xFF)
        self._write("<B", max(2, function.max_stack_size) & 0xFF)
        self.write_instructions(function)
        self.write_constants(function)
        self._write("<i", len(function.functions))
        for child in function.functions:
            self.write_function(child)
        self._write("<i", 0)
        self._write("<i", 0)
        self._write("<i", 0)

    def serialize(self, function: Function) -> bytes:
        self.stream.write(self.HEADER)
        self.write_function(function)
        if isinstance(self.stream, io.BytesIO):
            return self.stream.getvalue()
        return b""

    @classmethod
    def to_file(cls, function: Function, path: str | Path) -> None:
        with open(path, "wb") as fh:
            cls(fh).serialize(function)





class Lua51ChunkReader:
    """Parse a standard Lua 5.1 binary chunk into the same Function model used above.

    The parser obeys the chunk header's endianness and scalar sizes and never executes the
    chunk.  Debug records are consumed but intentionally not required for disassembly.
    """
    def __init__(self, data: bytes):
        self.data=bytes(data); self.pos=0; self.endian='little'; self.int_size=4
        self.size_t_size=8; self.instruction_size=4; self.number_size=8; self.integral=False

    def _read(self,n:int)->bytes:
        if n<0 or self.pos+n>len(self.data):raise EOFError('truncated Lua 5.1 chunk')
        b=self.data[self.pos:self.pos+n]; self.pos+=n; return b
    def _u8(self)->int:return self._read(1)[0]
    def _intn(self,n:int,signed:bool=True)->int:return int.from_bytes(self._read(n),self.endian,signed=signed)
    def _int(self)->int:return self._intn(self.int_size,True)
    def _size_t(self)->int:return self._intn(self.size_t_size,False)
    def _count(self,what:str)->int:
        n=self._int()
        if n<0 or n>2_000_000:raise ValueError(f'unreasonable {what} count: {n}')
        return n
    def _string(self)->str:
        n=self._size_t()
        if n==0:return ''
        if n>len(self.data)-self.pos or n>100_000_000:raise ValueError('invalid Lua string length')
        raw=self._read(n)
        if raw.endswith(b'\0'):raw=raw[:-1]
        return raw.decode('utf-8',errors='replace')
    def _number(self)->float:
        b=self._read(self.number_size)
        pref='<' if self.endian=='little' else '>'
        if self.integral:
            return float(int.from_bytes(b,self.endian,signed=True))
        if self.number_size==8:return float(struct.unpack(pref+'d',b)[0])
        if self.number_size==4:return float(struct.unpack(pref+'f',b)[0])
        raise ValueError(f'unsupported lua_Number size {self.number_size}')

    @staticmethod
    def _decode_instruction(word:int,pc:int,fn:Function)->Instruction:
        opnum=word & 0x3f
        op=OpCode(opnum) if 0<=opnum<=37 else OpCode.UNKNOWN
        a=(word>>6)&0xff; c=(word>>14)&0x1ff; b=(word>>23)&0x1ff; bx=(word>>14)&0x3ffff
        ins=Instruction(a=a,b=b,c=c,op_num=opnum,pc=pc,function=fn,opcode=op)
        if op != OpCode.UNKNOWN:
            typ=op_type(op)
            if typ==OpType.ABX:ins.b=bx
            elif typ==OpType.ASBX:ins.b=bx-131071
            elif typ==OpType.SBX:ins.a=0;ins.b=bx-131071;ins.c=0
            elif typ==OpType.AC:ins.b=0
            elif typ==OpType.A:ins.b=ins.c=0
        return ins

    def _function(self,parent_source:str='')->Function:
        source=self._string() or parent_source
        _line_defined=self._int(); _last_line_defined=self._int()
        nups=self._u8(); nparams=self._u8(); is_vararg=self._u8(); maxstack=self._u8()
        fn=Function(max_stack_size=maxstack,num_params=nparams,num_upvalues=nups,is_vararg_flag=is_vararg,
                    name=source or f'chunk_{self.pos:08x}')
        ncode=self._count('instruction')
        if self.instruction_size != 4:raise ValueError(f'unsupported Lua instruction size {self.instruction_size}')
        fn.instructions=[]
        for pc in range(ncode):
            word=self._intn(4,False); fn.instructions.append(self._decode_instruction(word,pc,fn))
        nk=self._count('constant'); consts=[]
        for _ in range(nk):
            tag=self._u8()
            if tag==0:consts.append(NilConstant())
            elif tag==1:consts.append(BooleanConstant(bool(self._u8())))
            elif tag==3:consts.append(NumberConstant(self._number()))
            elif tag==4:consts.append(StringConstant(self._string()))
            else:raise ValueError(f'unsupported Lua 5.1 constant tag {tag}')
        fn.constants=consts
        np=self._count('prototype'); fn.functions=[self._function(source) for _ in range(np)]
        nline=self._count('lineinfo')
        self._read(nline*self.int_size)
        nlocals=self._count('local')
        for _ in range(nlocals):
            self._string(); self._read(self.int_size*2)
        nupnames=self._count('upvalue-name')
        for _ in range(nupnames):self._string()
        return fn

    def parse(self)->Function:
        if self._read(4)!=b'\x1bLua':raise ValueError('not a Lua binary chunk')
        version=self._u8(); fmt=self._u8()
        if version!=0x51:raise ValueError(f'Lua bytecode version 0x{version:02x} is not Lua 5.1')
        if fmt!=0:raise ValueError(f'unsupported Lua 5.1 chunk format {fmt}')
        endian=self._u8(); self.endian='little' if endian==1 else 'big' if endian==0 else (_ for _ in ()).throw(ValueError('invalid endianness byte'))
        self.int_size=self._u8();self.size_t_size=self._u8();self.instruction_size=self._u8();self.number_size=self._u8();self.integral=bool(self._u8())
        if self.int_size not in (2,4,8) or self.size_t_size not in (2,4,8):raise ValueError('unsupported Lua scalar sizes')
        fn=self._function('')
        return fn


def parse_lua51_bytecode(data: bytes) -> Function:
    return Lua51ChunkReader(data).parse()


def disassemble_lua51_bytecode(data: bytes) -> str:
    return Disassembler(parse_lua51_bytecode(data)).disassemble()






def _constant_repr(value) -> str:
    if isinstance(value, StringConstant):
        return repr(value.value)
    if isinstance(value, NumberConstant):
        return repr(value.value)
    if isinstance(value, BooleanConstant):
        return "true" if value.value else "false"
    if isinstance(value, NilConstant):
        return "nil"
    return repr(getattr(value, "value", None))


class Disassembler:
    def __init__(self, function: Function):
        self.function = function

    def disassemble(self) -> str:
        chunks: list[str] = []
        self._function(self.function, chunks, 0)
        return "\n".join(chunks).rstrip() + "\n"

    def _function(self, fn: Function, out: list[str], depth: int) -> None:
        indent = "  " * depth
        out.append(f"{indent}; function {fn.name} params={fn.num_params} upvalues={fn.num_upvalues} stack={fn.max_stack_size} vararg={fn.is_vararg_flag}")
        if fn.constants:
            out.append(f"{indent}; constants:")
            for i, c in enumerate(fn.constants):
                out.append(f"{indent};   K{i:<4} = {_constant_repr(c)}")
        out.append(f"{indent}; code:")
        for pc, ins in enumerate(fn.instructions):
            out.append(f"{indent}{pc:04d}  {self._instruction(fn, pc, ins)}")
        for child in fn.functions:
            out.append("")
            self._function(child, out, depth + 1)

    @staticmethod
    def _rk(fn: Function, operand: int) -> str:
        if operand >= 256:
            idx = operand - 256
            if 0 <= idx < len(fn.constants):
                return f"K{idx}({_constant_repr(fn.constants[idx])})"
            return f"K{idx}"
        return f"R{operand}"

    def _instruction(self, fn: Function, pc: int, i: Instruction) -> str:
        op = i.opcode
        name = op.name
        if op == OpCode.LOADK:
            suffix = f" ; {_constant_repr(fn.constants[i.b])}" if 0 <= i.b < len(fn.constants) else ""
            return f"{name:<9} R{i.a} K{i.b}{suffix}"
        if op in (OpCode.GETGLOBAL, OpCode.SETGLOBAL):
            suffix = f" ; {_constant_repr(fn.constants[i.b])}" if 0 <= i.b < len(fn.constants) else ""
            return f"{name:<9} R{i.a} K{i.b}{suffix}"
        if op in (OpCode.GETTABLE, OpCode.SELF):
            return f"{name:<9} R{i.a} R{i.b} {self._rk(fn, i.c)}"
        if op == OpCode.SETTABLE:
            return f"{name:<9} R{i.a} {self._rk(fn, i.b)} {self._rk(fn, i.c)}"
        if op in (OpCode.ADD, OpCode.SUB, OpCode.MUL, OpCode.DIV, OpCode.MOD, OpCode.POW,
                  OpCode.EQ, OpCode.LT, OpCode.LE):
            return f"{name:<9} {i.a} {self._rk(fn, i.b)} {self._rk(fn, i.c)}"
        if op in (OpCode.JMP, OpCode.FORLOOP, OpCode.FORPREP):
            target = pc + i.b + 1
            if op == OpCode.JMP:
                return f"{name:<9} {i.b:+d} ; -> {target}"
            return f"{name:<9} R{i.a} {i.b:+d} ; -> {target}"
        try:
            typ = op_type(op)
        except ValueError:
            return f"{name:<9} A={i.a} B={i.b} C={i.c}"
        if typ == OpType.A:
            args = f"R{i.a}"
        elif typ == OpType.AB:
            args = f"R{i.a} {i.b}"
        elif typ == OpType.ABC:
            args = f"R{i.a} {i.b} {i.c}"
        elif typ == OpType.ABX:
            args = f"R{i.a} {i.b}"
        elif typ == OpType.ASBX:
            args = f"R{i.a} {i.b:+d}"
        elif typ == OpType.SBX:
            args = f"{i.b:+d}"
        elif typ == OpType.AC:
            args = f"R{i.a} {i.c}"
        else:
            args = f"A={i.a} B={i.b} C={i.c}"
        return f"{name:<9} {args}"



"""Lightweight source helpers for the Python port.

The upstream project has a sizeable custom ANTLR AST, constant folder,
control-flow solver and symbol-aware handler rewriter.  This module deliberately
does not execute untrusted Lua.  It only performs conservative textual recovery
that is useful when building a Context JSON file.
"""

import ast as py_ast
import re
from dataclasses import dataclass



_LUA_STRING = r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''


def _lua_unquote(token: str) -> str:


    try:
        return decode_lua_quoted_string(token)
    except Exception:
        return token[1:-1]


def collect_constant_maps(source: str) -> dict[str, list[str]]:
    """Recover constant replacement maps from common MoonSec source patterns."""
    decoded_maps: list[dict[str, list[str]]] = []
    call_re = re.compile(rf"\(\s*(\d+)\s*,\s*({_LUA_STRING})\s*\)")
    for match in call_re.finditer(source):
        key = int(match.group(1))
        text = _lua_unquote(match.group(2))
        try:
            decoded_maps.append(decode_constants(decode(text, key)))
        except Exception:
            pass


    for match in re.finditer(_LUA_STRING, source):
        text = _lua_unquote(match.group(0))
        if text.startswith("\\4\\8"):
            try:
                decoded_maps.append(decode_constants(decode_escape(text)))
            except Exception:
                pass

    merged: dict[str, list[str]] = {}
    for mapping in decoded_maps:
        merged.update(mapping)
    return merged


def find_encoded_blob_candidates(source: str) -> list[str]:
    """Find strings that look like MoonSec's 16-symbol-alphabet encoded blobs."""
    result: list[str] = []
    for match in re.finditer(_LUA_STRING, source):
        value = _lua_unquote(match.group(0))
        if not isinstance(value, str) or len(value) < 32:
            continue
        alphabet = value[:16]
        if len(set(alphabet)) >= 12 and all(ch in set(alphabet) for ch in value[16:]):
            result.append(value)
    result.sort(key=len, reverse=True)
    return result


def context_template_from_source(source: str) -> Context:
    """Create a best-effort Context template without executing the Lua source."""
    ctx = Context()
    candidates = find_encoded_blob_candidates(source)
    if candidates:
        ctx.bytecode_string = candidates[0]
    return ctx






def devirtualize_context(ctx: Context) -> Function:
    """Run the Python port from an already-recovered MoonSec Context."""
    if not ctx.bytecode_string:
        raise ValueError("Context.bytecode_string is empty")
    if not ctx.proto_format:
        raise ValueError("Context.proto_format is empty")
    if not ctx.opcode_fingerprints:
        raise ValueError("Context.opcode_fingerprints is empty")
    bytecode = decode(ctx.bytecode_string, ctx.bytecode_key)
    root = Deserializer(bytecode, ctx).read_function()
    return BytecodeDeobfuscator(root, ctx.opcode_fingerprints).deobfuscate()





def reverse_pipeline(code):
    code = re.sub(
        r'local Pipeline = require\("prometheus\.pipeline"\)[^}]+end\)',
        "",
        code,
        flags=re.DOTALL,
    )


    code = re.sub(r"pipeline:addStep\([^)]+\)", "", code)


    code = re.sub(r"pipeline:setNameGenerator\([^)]+\)", "", code)
    return code





def clean_name_generators(code):
    code = re.sub(
        r'util\.shuffle\([^)]+\);',
        '',
        code
    )


    code = re.sub(
        r'local namegenerators = .*?\}\}',
        '',
        code,
        flags=re.DOTALL
    )

    return code


def unwrap_functions(code):

    code = [re.sub(
        r'(?:local\s+(\w+)\s*=\s*)?function\(' + re.escape(', '.join([chr(97+i) for i in range(arity)])) + r'\)\s*'
        r'return\s+' + re.escape(', '.join([chr(97+i) for i in range(arity)])) + r'\s+end\s*[,;]?\s*'
        r'return\s+\1(?:\s*end)?',
        lambda m: f'local {m.group(1)} = function({", ".join([chr(97+i) for i in range(arity)])}) return {", ".join([chr(97+i) for i in range(arity)])} end' if m.group(1) else '',
        code
    ) for arity in range(0, 6)][-1]

    code = re.sub(
        r'local\s+(\w+)\s*=\s*Z\((\w+)\)\s*'
        r'local\s+(\w+)\s*=\s*function\(([^)]*)\)\s*'
        r'return\s+\3\(\3\)\s*end\s*'
        r'return\s+\3\s*end',
        lambda m: f'local {m.group(1)} = Z({m.group(2)})\nlocal {m.group(3)} = identity_fn',
        code
    )

    return code





def reconstruct_tokenized(code):
    substitution_patterns = [
        (r"\b(_[\dA-F]+)\b", lambda m: f"var_{int(m.group(1)[1:], 16)}"),
        (r"\\u\{([0-9a-fA-F]+)\}", lambda m: f"\\{int(m.group(1), 16)}"),
        (
            r"\b(local_var_\d+)\b",
            lambda m: f"var_{int(m.group(1)[10:]) % 1000}"
            if m.group(1).startswith("local_var_")
            else m.group(0),
        ),
        (r"\b(-?\d{7,})\b", lambda m: str(ast.literal_eval(m.group(0)))),
        (r"-\[METATABLE\]-", "--[[Removed metatable]]"),
        (r"\bvar_(\d+)\b", lambda m: f"var_{int(m.group(1)) % 1000}"),
    ]

    for pattern, replacement in substitution_patterns:
        code = re.sub(pattern, replacement, code)

    return code


def restore_control_flow(code):
    patterns = [
        (r"else\s+if", "elseif"),
        (r"(\bif\b.*?)\s*\n\s*(\bthen\b)", r"\1 \2", re.DOTALL),
        (r"return\s+(\w+)\(\)", r"return \1()"),
    ]

    for pattern in patterns:
        code = re.sub(
            *pattern[:2], flags=pattern[2] if len(pattern) > 2 else 0, string=code
        )

    return code


def reconstruct_functions(code):
    substitutions = [
        (r"function\(\.\.\.\)(.*)end\(\.\.\.\)", lambda m: m.group(1), re.DOTALL),
        (r",\s*\.\.\.|\.\.\.\s*,", ""),
        (r"\(\s*\.\.\.\s*\.\.\.\s*\)", "(...)"),
        (
            r"function\(([^)]*)\)",
            lambda m: "function("
            + (m.group(1).strip() or "_")
            + ("" if "..." in m.group(1) else ", ...")
            + ")",
        ),
        (r"function\(\s*_\s*,([^)]*)\)", lambda m: "function(" + m.group(1) + ")"),
        (
            r"return\s+([^{\n]+{.*?})(\s*end)",
            lambda m: "return " + m.group(1).strip() + m.group(2),
            re.DOTALL,
        ),
        (r",\s*function\b", "\nfunction"),
        (r"\b(Ellipsis|_VAR_)\b", "..."),
        (
            r"return (\w+)\(([^)]+)\)",
            lambda m: "return " + m.group(1) + "(" + m.group(2).rstrip(", ") + ")",
        ),
        (r"function\(\s*(\.\.\.)\s*\)", r"function(\1)"),
        (r",\s*\.\.\.\)", ")"),
        (r"end return", "end\nreturn"),
        (r"(\w+)\)local", r"\1\nlocal"),
        (r"(\w+)\)(\w+)", r"\1\n\2"),
        (
            r"=\s*(\w+)\(([^)]+)$",
            lambda m: "= " + m.group(1) + "(" + m.group(2) + ")",
            re.MULTILINE,
        ),
        (
            r"function\(([^)]+)\)",
            lambda m: "function("
            + ", ".join(p.strip() for p in m.group(1).split(","))
            + ")",
        ),
        (
            r"return\s+([^;]+)\s*\n\s*end",
            lambda m: "return " + m.group(1).strip() + "\nend",
            re.DOTALL,
        ),
        (r"local (\w+) = (\w+)\n(function)", r"local \1 = \2\n\3"),
        (r"(\w+)=(\w+)(\([^)]+\))\s*(\w+)\[", r"\1 = \2\3\n\4["),
        (
            r"return\(function\(([^)]+)\)\s*([^=]+)=function\(([^)]+)\)",
            lambda m: "return function("
            + m.group(1)
            + ")\n"
            + m.group(2)
            + " = function("
            + m.group(3)
            + ")",
        ),
        (r"([A-Z_]+,\s*){5,}[A-Z_]+=function\b", ""),
        (
            r"return (\w+) (\w+)=function\(([^)]+)\)\s+return \1\(\1, ([^)]+)\)",
            lambda m: "local "
            + m.group(2)
            + " = function("
            + m.group(3)
            + ")\nreturn "
            + m.group(1)
            + "("
            + m.group(4)
            + ")",
        ),
    ]

    for sub in substitutions:
        code = re.sub(sub[0], sub[1], code, flags=sub[2] if len(sub) > 2 else 0)

    return code


def reconstruct_locals(code):
    patterns = [
        (
            r"(if\s+[^\s]+)(==|~=|<|>)([^\s]+)(then)(\s*\w+.*?local\s+)",
            lambda m: f"{m.group(1)} {m.group(2)} {m.group(3)} {m.group(4)}\n{m.group(5)}",
            re.DOTALL,
        ),
        (
            r"\b(local\s+[^;\n]+?)(\s*)(local\b)",
            lambda m: f"{m.group(1).rstrip()}\n{m.group(3)} ",
        ),
        (r"(-?\w+)([%^*/+-])(=?)", r"\1 \2\3 "),
        (r"local\s+(\w+),\s*\1", r"local \1"),
        (r"([%\*/\+\-])(=?)", lambda m: f" {m.group(1)}{m.group(2)} "),
        (
            r"(\w+)=([^=]+)(\s*)(local\s+\w+=)",
            lambda m: f"{m.group(1)} = {m.group(2).strip()}\n{m.group(4)}",
        ),
        (r"\s+-\s*(\w+)", r" -\1"),
        (
            r"for\s+(\w+)\s*=\s*(-?\w+)(\s+)(#?\w+)(\s+)(-?\w+)",
            r"for \1 = \2, \4, \6 do",
        ),
        (
            r"(\w+)\.(\w+)\s*=\s*(\w+)\(([^)]+)\)",
            lambda m: f"{m.group(1)}.{m.group(2)} = {m.group(3)}({m.group(4)})",
        ),
        (
            r"\.([A-Za-z])([^\.\w]|$)",
            lambda m: f".{ {'J': 'value', 'Z': 'length', 'X': 'key', 'Q': 'quality', 'D': 'data', 'S': 'size', 'T': 'type', 'B': 'buffer'}.get(m.group(1), m.group(1)) }{m.group(2)}",
        ),
        (r"(\b\w+)\(([^)]+)$", lambda m: f"{m.group(1)}({m.group(2)})", re.MULTILINE),
        (r"(\S)(local\s+)", lambda m: f"{m.group(1)}\n{m.group(2)}"),
    ]

    for p in patterns:
        code = re.sub(p[0], p[1], code, flags=p[2] if len(p) > 2 else 0)

    return code


def reconstruct_conditions(code):
    patterns = [
        (r"\b(elseif|else)\s+", lambda m: f"{m.group(1).rstrip()} "),
        (r"([<>]=?)\s*(-?\d+)", lambda m: f"{m.group(1)} {m.group(2)}"),
        (r"(\})(elseif|else)", r"\1\n\2"),
        (r"\[(-?\w+)\](\s*[<>=])", lambda m: f"[{m.group(1)}] {m.group(2).strip()}"),
        (r"(then)(\S)", r"\1\n\2"),
        (
            r"(\w+)=(\w+)([<>=!]=)(\w+)",
            lambda m: f"{m.group(1)} = {m.group(2)} {m.group(3)} {m.group(4)}",
        ),
        (
            r"(then|else)(\s*)([^\n=]+)=([^;]+);([^\n]+)",
            lambda m: f"{m.group(1)}\n{m.group(3)} = {m.group(4)}\n{m.group(5)}",
        ),
        (r"(\w+\.\w+)=(\w+)", r"\1 = \2"),
        (
            r"\b(if|elseif)\b(.*?)\bthen\b",
            lambda m: f"{m.group(1)} {m.group(2).strip()}\n    then",
            re.DOTALL,
        ),
        (r"(end)(\s*)(else)", r"\1\n\3"),
    ]

    for p in patterns:
        code = re.sub(p[0], p[1], code, flags=p[2] if len(p) > 2 else 0)

    return code


def remove_junkcode(code):
    patterns = [
        (r"local function \w+\(.*?\)\s*return \"[^\"]+\"\s*end", "", re.DOTALL),
        (r"if \w+ == -\d+ then \w+ = -\d+ end", ""),
        (
            r"TABLE_INSERT_OPERATION\(\[-\w+\],PRECISION_VALUE\(-\d+,-?\d+,-?\d+\)\);",
            "",
        ),
        (r"\b\w+ = \w+ [%+-\/*] (?:-?\d+|\(-?\d+ [%+-\/*] -?\d+\))", ""),
        (r"\w+\.\w+ = (?:nil|-\d+|\"\")", ""),
        (r"for \w+ = -\d+,#\w+,-?\d+ do end", ""),
        (r"local \w+ = (?:-?\d+|nil)(?=\s*[^\n])", ""),
        (r"\w+\.\w+,\w+\.\w+ = nil,nil", ""),
        (r"local function (\w+)\(.*?\)\s+return \1\(.*?\)\s+end", "", re.DOTALL),
        (r"\b(\w+) = -\d+\s*([^-+/*]|$)", ""),
        (r"function\(\.\.\.\)\s*return \{\}\s*end", ""),
        (r"-\s*\[\[.*?\]\]", ""),
        (r"\b(\w+) = \1 [+-] \d+\b", ""),
        (r"TABLE_INSERT_OPERATION\(\w+,\w+\([-,\w\s]+\),?\);", ""),
        (r"\b\w+ = \w+ [+-] \(\d+\)\s*$", ""),
    ]

    for p in patterns:
        code = re.sub(p[0], p[1], code, flags=p[2] if len(p) > 2 else 0)

    return code


def clean_tokenized_syntax(code):
    code = re.sub(r"--\[\[.*?\]\]", "", code, flags=re.DOTALL)
    code = re.sub(r"--.*", "", code)
    code = re.sub(r"\\\n", " ", code)
    code = re.sub(r"(\w)\s*=\s*(\w)", r"\1 = \2", code)

    code = re.sub(
        r'("|\')(.*?)(?<!\\)\1',
        lambda m: f"{m.group(1)}{m.group(2)}{m.group(1)}",
        code,
        flags=re.DOTALL,
    )

    indent_level = 0
    indent_stack = []
    output = []

    processed_lines = [
        (
            line.strip(),
            any(
                line.strip().startswith(kw)
                for kw in ["function", "if", "for", "while", "repeat"]
            ),
            line.strip() == "do" or line.strip().startswith("do "),
        )
        for line in code.split("\n")
        if line.strip()
    ]

    for stripped, is_control, is_do in processed_lines:
        if stripped.startswith(("end", "until", "else", "elseif")):
            indent_level = max(0, indent_level - 1)
            if indent_stack and indent_stack[-1] == "function":
                indent_level = max(0, indent_level - 1)
                indent_stack.pop()

        current_indent = "    " * indent_level
        output.append(f"{current_indent}{stripped}")

        if is_control:
            if "function" in stripped:
                indent_stack.append("function")
            indent_level += 1
        elif is_do:
            indent_level += 1

    code = "\n".join(output)

    def format_table(match):
        table_body = match.group(1)
        indent = "    " * (code[: match.start()].count("\n") // 4 + 1)
        entries = [e.strip() for e in re.split(r",(?![^{]*})", table_body) if e.strip()]
        formatted = [f"\n{indent}{e}," for e in entries]
        return (
            "{\n"
            + "\n".join(formatted).rstrip(",")
            + "\n"
            + "    " * (indent.count("    ") - 1)
            + "}"
        )

    code = re.sub(
        r"=\s*{([^}]*?)}", lambda m: f"= {format_table(m)}", code, flags=re.DOTALL
    )

    code = re.sub(r"(function|if|for|while)\s*(\()", r"\1 \2", code)

    cleanup_patterns = [
        (r"\s+(\=|\+|\-|\*|\/|\,)", r"\1"),
        (r"(\=|\+|\-|\*|\/|\,)\s+", r"\1 "),
        (r"(\S)\s*(\{)", r"\1 \2"),
        (r"\}\s*(\S)", r"} \1"),
        (
            r"local\s+((?:\w+\s*,\s*)+\w+)\s*=\s*((?:[^,\n]+,?)+)",
            lambda m: format_multi_declaration(m),
        ),
        (
            r"(\S)([=+-\/*%^<>~\(\)\{\}\[\]])|([=+-\/*%^<>~\(\)\{\}\[\]])[^\s\w]",
            lambda m: f"{m.group(1)} {m.group(2)}" if m.group(1) else f"{m.group(3)} ",
        ),
        (
            r"\{\s*([^{}]+?)\s*\}",
            lambda m: "{" + re.sub(r"\s+", " ", m.group(1)).strip() + "}",
        ),
        (r"\n{3,}", "\n\n"),
        (r"\s+:", ":"),
        (r"\s*,\s*", ", "),
        (r"(\b\w+\s*=\s*[^;\n]+)(;\s*\1)+", lambda m: m.group(1)),
        (r"\[\s*([^]]+?)\s*\]", lambda m: f"[{m.group(1).strip()}]"),
    ]

    for pattern, replacement in cleanup_patterns:
        code = re.sub(pattern, replacement, code)

    return code


def format_multi_declaration(match):
    variables = [v.strip() for v in match.group(1).split(",")]
    values = [v.strip() for v in match.group(2).split(",")]
    max_len = max(len(variables), len(values))
    pad = "    "
    formatted = [
        f"{variables[i] if i < len(variables) else 'nil'} = {values[i] if i < len(values) else 'nil'}"
        for i in range(max_len)
    ]
    return "local " + (",\n" + pad).join(formatted)





def add_debugging(code):
    code = re.sub(
        r"local function V\(V\)return H\[V-(-?\d+)\]end",
        lambda m: f"-- Original offset: {m.group(1)}\n"
        + "local function V(idx) return H[idx - offset] end",
        code,
    )
    return code


def handle_antitamper(code):
    code = re.sub(
        r"local valid=true;.*?if valid then else.*?end",
        "local valid=true;",
        code,
        flags=re.DOTALL,
    )

    code = re.sub(r'debug\.sethook\(.*?end,? "l", 5\);', "", code, flags=re.DOTALL)
    return code




@dataclass
class Detection:
    family: str
    score: int
    reasons: list[str] = field(default_factory=list)

@dataclass
class DeobfuscationReport:
    detections: list[Detection] = field(default_factory=list)
    passes: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    details: dict[str, Any] = field(default_factory=dict)
    changed: bool = False
    output_kind: str = "source"

    @property
    def best_family(self) -> str:
        return self.detections[0].family if self.detections else "generic/unknown"


def _read_input(value: str | bytes | os.PathLike) -> tuple[str, Optional[Path]]:
    if isinstance(value, bytes):
        return value.decode('utf-8', errors='replace'), None
    if isinstance(value, os.PathLike):
        p=Path(value)
        return p.read_text(encoding='utf-8', errors='replace'), p
    if isinstance(value, str):
        try:
            p=Path(value)
            if '\n' not in value and '\r' not in value and p.exists() and p.is_file():
                return p.read_text(encoding='utf-8', errors='replace'), p
        except (OSError, ValueError):
            pass
        return value, None
    raise TypeError('input must be Lua source text, bytes, or a path')




def _lua_protected_spans(code: str) -> list[tuple[int,int]]:
    """Return spans occupied by quoted strings, long strings, and comments."""
    spans=[]; i=0; n=len(code)
    while i<n:
        if code.startswith('--',i):

            m=re.match(r'--\[(=*)\[',code[i:])
            if m:
                eq=m.group(1); endmark=']'+eq+']'; j=code.find(endmark,i+m.end())
                j=n if j<0 else j+len(endmark); spans.append((i,j)); i=j; continue
            j=code.find('\n',i+2); j=n if j<0 else j; spans.append((i,j)); i=j; continue
        if code[i] in "\"'":
            q=code[i]; j=i+1
            while j<n:
                if code[j]=='\\': j+=2; continue
                if code[j]==q: j+=1; break
                j+=1
            spans.append((i,min(j,n))); i=max(j,i+1); continue
        if code[i]=='[':
            m=re.match(r'\[(=*)\[',code[i:])
            if m:
                eq=m.group(1); endmark=']'+eq+']'; j=code.find(endmark,i+m.end())
                j=n if j<0 else j+len(endmark); spans.append((i,j)); i=j; continue
        i+=1
    return spans


def _code_level_start(code: str, pos: int, spans: Optional[list[tuple[int,int]]]=None) -> bool:
    spans=_lua_protected_spans(code) if spans is None else spans
    for a,b in spans:
        if pos<a: return True
        if a<=pos<b: return pos==a and code[a:a+2] != '--'
    return True


def _sub_code(pattern, repl, code: str, *, flags=0):
    rx=re.compile(pattern,flags) if isinstance(pattern,str) else pattern
    spans=_lua_protected_spans(code)
    def rr(m):
        return repl(m) if _code_level_start(code,m.start(),spans) else m.group(0)
    return rx.sub(rr,code)


def _replace_identifier_code(code: str, old: str, new: str) -> str:
    return _sub_code(r'\b'+re.escape(old)+r'\b',lambda m:new,code)


def detect_obfuscator(source: str | bytes | os.PathLike) -> list[Detection]:
    text,_=_read_input(source)
    low=text.lower()
    scores: dict[str, tuple[int,list[str]]] = {}
    def add(fam: str, pts: int, reason: str):
        s,rs=scores.get(fam,(0,[])); scores[fam]=(s+pts,rs+[reason])


    if 'moonsec' in low: add('MoonSec', 8, 'MoonSec marker/comment')
    if 'prometheus' in low: add('Prometheus', 8, 'Prometheus marker/module name')
    if 'ironbrew' in low: add('IronBrew', 8, 'IronBrew marker/comment')
    if 'aztupbrew' in low: add('AztupBrew', 9, 'AztupBrew marker/comment')
    if 'luraph' in low: add('Luraph', 8, 'Luraph marker/comment')
    if 'luarmor' in low: add('Luarmor/Luraph', 8, 'Luarmor marker')
    if re.search(r'\b_bsdata0\s*=\s*\{', text) and re.search(r'https://(?:cdn|api)\.luarmor\.net/(?:v4|files/v4)', text, re.I):
        add('Luarmor V4 bootstrap', 20, '_bsdata0 plus official Luarmor V4 loader URL')
    elif re.search(r'\b_bsdata0\s*=\s*\{', text) and re.search(r'static_content_\d+', text):
        add('Luarmor V4 bootstrap', 12, '_bsdata0 plus Luarmor static-content cache layout')
    if re.search(r'https://api\.luarmor\.net/files/v4/loaders/[0-9a-f]{16,64}\.lua', text, re.I):
        add('Luarmor V4 public loader', 18, 'official Luarmor /files/v4/loaders/<id>.lua URL')
    if 'hercules' in low or 'protected by hercules' in low: add('Hercules', 10, 'Hercules marker/watermark')
    if 'moonveil' in low: add('MoonVeil/Luraph', 8, 'MoonVeil marker')
    if 'azure vm' in low or 'azureobf' in low: add('AzureVM/Prometheus', 8, 'AzureVM marker')



    marker_rules = [
        ('LuaObfuscator.com', 10, ('luaobfuscator.com', 'lua obfuscator.com')),
        ('Synapse Xen', 10, ('synapse xen', 'synapsexen_')),
        ('Boronide', 10, ('boronide', '[[boronide obfuscation]]')),
        ('77fuscator', 10, ('77fuscator', '77fuscator.lua')),
        ('LPS', 9, ('lps obfuscator', 'protected by lps')),
        ('PSU', 9, ('psu obfuscator', 'protected by psu')),
        ('wYnFuscate', 10, ('wynfuscate', 'is_caller_wynfuscate', 'wynf_')),
        ('WeAreDevs', 9, ('wearedevs', 'we are devs obfuscator')),
        ('Goofyscator', 10, ('goofyscator', 'goofyscator.lua.cz')),
        ('Dexfuscator', 9, ('dexfuscator',)),
        ('RealVuxObfuscate', 9, ('realvuxobfuscate', 'realvux obfuscate')),
        ('Asteria', 8, ('asteria obfuscator', 'protected by asteria')),
        ('Catph', 8, ('catph obfuscator', 'protected by catph')),
        ('Devlyx', 8, ('devlyx',)),
        ('DarkSec', 9, ('darksec',)),
        ('LuauProtect', 10, ('luauprotect', 'luauprotect.up.railway.app')),
        ('Secrovia', 10, ('secrovia', '__secrovia__')),
        ('ObscuraLua', 9, ('obscuralua', 'obscura lua')),
        ('25ms', 9, ('discord.gg/25ms', '25ms obfuscator')),
        ('XFuscator', 9, ('xfuscator',)),
        ('EssaFuscator', 9, ('essafuscator',)),
        ('Zenfus', 9, ('zenfus',)),
        ('Obelisk', 8, ('obelisk obfuscator', 'protected by obelisk')),
        ('LuaGuard', 8, ('luaguard obfuscator', 'protected by luaguard')),
        ('SLua', 7, ('slua obfuscator', 'protected by slua')),
        ('Veil Lua', 7, ('veil obfuscator', 'protected by veil')),
        ('05Fusec', 7, ('05fusec',)),
        ('2521', 7, ('2521 obfuscator',)),
        ('Aero', 7, ('aero obfuscator',)),
        ('Comet', 7, ('comet obfuscator',)),
        ('KRNOBf', 7, ('krnobf',)),
        ('MD21C', 7, ('md21c',)),
        ('Protosmasher', 7, ('protosmasher obfuscator',)),
        ('ComboSec', 9, ('combosec', 'protected by combosec')),
        ('MathOBF', 8, ('mathobf', 'vm_obfuscator.lua')),
        ('JokerObfuscator', 9, ('jokerobfuscator', 'joker obfuscator')),
        ('LuaU-obfuscator', 8, ('luau-obfuscator', 'luau obfuscator')),
        ('Punchfuscator', 8, ('punchfuscator',)),
        ('Ghost Obfuscator', 8, ('ghost obfuscator', 'ghostfuscator')),
        ('Luau-Protect', 8, ('luau-protect', 'luau protect')),
        ('LuaVirtualBox/Firefly', 9, ('luavirtualbox', 'fireflyprotector', 'generated by luavirtualbox')),
        ('Lunaris', 8, ('lunaris obfuscator', 'protected by lunaris')),
        ('Xemon', 7, ('xemon obfuscator',)),
        ('APRIL', 7, ('april obfuscator',)),
        ('Mote', 7, ('mote obfuscator', 'protected by mote')),
    ]
    for fam, pts, markers in marker_rules:
        for marker in markers:
            if marker in low:
                add(fam, pts, f'explicit {fam} marker')
                break



    if re.search(r'ironbrew\s*(?:v?1|1\.\d)', low): add('IronBrew 1', 5, 'IronBrew v1 marker')
    if re.search(r'ironbrew\s*(?:v?2|2\.\d)|\bib2\b', low): add('IronBrew 2', 6, 'IronBrew v2/IB2 marker')
    if re.search(r'ironbrew\s*(?:v?3|3\.\d)', low): add('IronBrew 3', 6, 'IronBrew v3 marker')
    if re.search(r'moonsec\s*(?:v?1|1\.\d)', low): add('MoonSec V1', 5, 'MoonSec V1 marker')
    if re.search(r'moonsec\s*(?:v?2|2\.\d)', low): add('MoonSec V2', 5, 'MoonSec V2 marker')
    if re.search(r'moonsec\s*(?:v?3|3\.\d)', low): add('MoonSec V3', 6, 'MoonSec V3 marker')




    if (re.search(r'\bbxor\b', text) and re.search(r'%\s*#\s*[A-Za-z_]\w*', text) and
            re.search(r'string\.(?:byte|char|sub)', text)):
        add('LuaObfuscator.com/repeating-XOR family', 5, 'repeating-key XOR string decoder shape')
    if re.search(r'Synapse\s+Xen\s*-\s*Failed\s+to\s+verify\s+bytecode', text, re.I):
        add('Synapse Xen', 12, 'Synapse Xen verification error string')
    if (re.search(r'\bbuffer\.create\s*\(', text) and
            (re.search(r'\bbuffer\.(?:read|write)[A-Za-z0-9_]*\s*\(', text) or text.count('bit32.') >= 3)):
        add('Luau buffer/VM obfuscator', 5, 'Luau buffer-backed VM structure')
    if (not re.search(r'\b_bsdata0\b', text) and 'luarmor.net' not in low and
            re.search(r'\bstatic_content_[A-Za-z0-9_]+\b', text) and re.search(r'\binit-[a-f0-9]{5,}\b', text, re.I)):
        add('LuauProtect', 7, 'LuauProtect static-content/init naming pattern')
    if 'clyde' in low and ('obfuscat' in low or 'virtual machine' in low): add('Clyde', 5, 'Clyde marker')
    if re.search(r'\b_clydeDec_[A-Za-z0-9_]+\b', text): add('Clyde', 10, 'Clyde string-decoder identifier')
    if '52200625' in text and '614125' in text and '7225' in text and 'Clyde Protection v2' in text:
        add('Clyde', 12, 'Clyde maximum-protection Base85/S-box bootstrap')
    if re.search(r'\bLPH_(?:NO_VIRTUALIZE|JIT|JIT_MAX|ENCSTR|ENCFUNC|ATTRIBUTES)\b', text):
        add('Luraph', 9, 'LPH macro signature')
    if re.match(r'\s*xpcall\s*\(\s*function\s*\(\s*\)', text, re.S) and re.search(r'[A-Za-z0-9+/]{24,}={0,2}', text):
        add('Luraph/Base64 VM loader', 6, 'xpcall shell plus large Base64 payload')


    if 'prometheus.pipeline' in low or 'pipeline:addstep' in low:
        add('Prometheus', 10, 'Prometheus pipeline API')
    if re.search(r'PHASE_BOUNDARY:[A-Z0-9_]+', text):
        add('Prometheus', 6, 'phase-boundary markers')
    if '35184372088832' in text and re.search(r'%\s*257\b', text):
        add('Prometheus', 8, 'Prometheus encrypted-string PRNG constants')
    if re.search(r'hercules\s*,\s*v1\s*,\s*alpha', text, re.I) or 'WrapState(BcToState' in text:
        add('Hercules', 10, 'Hercules VM bootstrap signature')
    if re.search(r'local\s+\w+\s*,\s*\w+\s*,\s*\w+\s*=\s*[\"\'][0-9A-Fa-f]{100,}[\"\']\s*,\s*\d+\s*,\s*\{\}', text):
        add('Hercules', 7, 'Hercules shifted-hex bytecode wrapper')
    if re.search(r'\(\(.*-\s*48\s*-.*%\s*10\).*\+\s*48', text, re.S) and re.search(r'-\s*65\s*-.*%\s*26', text, re.S):
        add('Hercules', 5, 'Hercules Caesar decoder shape')
    if re.search(r'\blocal\s+thing\s*=\s*\d+.*?\blocal\s+thing2\s*=\s*\d+.*?\blocal\s+counter\s*=\s*0.*?while\s+thing\s*==\s*thing2\s+and\s+counter\s*<\s*1', text, re.S):
        add('Hercules', 8, 'Hercules control-flow scaffold')
    if re.search(r'local\s+\w+\s*=\s*\{(?:[^{}]|\{[^{}]*\}){100,}\}', text, re.S):
        add('Prometheus', 1, 'large constant table')


    try:
        blobs=find_encoded_blob_candidates(text)
        if blobs: add('MoonSec', 5, 'custom 16-symbol encoded blob candidate')
    except Exception:
        pass
    if re.search(r'string\.(?:byte|char|sub|gsub)', text) and re.search(r'bit32\.|\bbit\.', text):
        add('MoonSec', 1, 'string/bit VM helpers')


    if re.search(r'getfenv\s+or\s+function\s*\(\)\s*return\s+_ENV', text, re.I|re.S):
        add('IronBrew/AztupBrew', 4, 'getfenv/_ENV compatibility bootstrap')
    if all(x in low for x in ('string.char','string.sub','table.concat','math.ldexp')):
        add('IronBrew/AztupBrew', 3, 'classic Lua 5.1 VM helper set')
    if re.search(r'tonumber\s*\(\s*[^,]+,\s*36\s*\)', text):
        add('AztupBrew', 5, 'base-36 LZW-style decoder')
    if re.search(r'gBits(?:8|16|32)|VMCall\s*\(', text):
        add('IronBrew', 5, 'IronBrew-style byte reader/VMCall names')
    if re.search(r'Subg\s*\(\s*Sub\s*\([^,]+,\s*5\s*\)\s*,\s*["\']\.\.["\']', text):
        add('IronBrew', 4, 'hex/RLE byte-string decoder shape')


    if re.search(r'\bLPH_[A-Z_]+\b', text):
        add('Luraph', 5, 'LPH identifier family')
    if text.count('bit32.') > 8 and len(re.findall(r'\bwhile\b', text)) > 3 and len(text) > 15000:
        add('VM-based Lua/Luau', 2, 'dense bitwise/state-machine VM structure')


    if re.search(r'(?:load|string\.char)\s*\(.*base64', low, re.S) or 'base64decode' in low:
        add('Base64 wrapper', 4, 'Base64 loader pattern')
    if len(re.findall(r'\\\d{1,3}', text)) > 20:
        add('Escape-encoded Lua', 3, 'many decimal byte escapes')
    if len(re.findall(r'\\x[0-9a-fA-F]{2}', text)) > 20:
        add('Hex-escape Lua', 3, 'many hex byte escapes')
    if re.search(r'(?:\\27Lua|\\x1[bB]Lua|\\027Lua)', text):
        add('Lua bytecode loader', 6, 'embedded Lua binary signature escapes')
    if re.search(r'string\.char\s*\(\s*\d+(?:\s*,\s*\d+){8,}\s*\)', text):
        add('Charcode wrapper', 4, 'large string.char constant sequence')
    try:
        if _extract_lua_bytecode_literals(text):
            add('Lua bytecode loader', 9, 'decoded quoted literal begins with Lua binary signature')
    except Exception:
        pass
    if len(re.findall(r'\b_0x[0-9A-Fa-f]{3,}\b', text)) >= 4:
        add('Hex-name/custom Lua obfuscator', 3, 'many _0x... mangled identifiers')
    compact=re.sub(r'\s+','',text)
    if '%255)+1' in compact and 'string.char' in text and re.search(r'\b_0x[0-9A-Fa-f]{3,}\b',text):
        add("Bill's Lua Obfuscator", 8, 'rotating-key XOR plus _0x mangling')
    if re.search(r'\[[A-Za-z_]\w*\[[A-Za-z_]\w*\]\+1\]',compact) and 'string.char' in text:
        add("Bill's Lua Obfuscator", 4, 'code-sequence/dictionary string decoder')
    if re.search(r'while\s+(?:true|1\s*==\s*1)\s+do\s*if\s+\w+\s*==\s*-?\d+\s+then', text, re.S):
        add('Flattened control flow', 4, 'integer state-machine dispatch loop')

    out=[Detection(k,v[0],v[1]) for k,v in scores.items() if v[0] > 0]
    out.sort(key=lambda d:(-d.score,d.family))
    return out or [Detection('generic/unknown',0,['no high-confidence family signature'])]


def check_supported_obfuscated_format(source_or_path: str | bytes | os.PathLike, *, min_score: int = 3) -> dict[str, Any]:
    detections = detect_obfuscator(source_or_path)
    usable = [d for d in detections if d.family != "generic/unknown" and d.score >= int(min_score)]
    best = usable[0] if usable else (detections[0] if detections else Detection("generic/unknown", 0, ["no detection"]))
    return {
        "supported": bool(usable),
        "family": best.family,
        "score": int(best.score),
        "reasons": list(best.reasons),
        "detections": [
            {"family": d.family, "score": int(d.score), "reasons": list(d.reasons)}
            for d in detections
        ],
    }


def is_supported_obfuscated_format(source_or_path: str | bytes | os.PathLike, *, min_score: int = 3) -> bool:
    return bool(check_supported_obfuscated_format(source_or_path, min_score=min_score)["supported"])


def is_supported_obfuscation(source_or_path: str | bytes | os.PathLike, *, min_score: int = 3) -> bool:
    return is_supported_obfuscated_format(source_or_path, min_score=min_score)


def _safe_arith_eval(expr: str):
    """Evaluate a tiny numeric/boolean expression subset, never names/calls/attrs."""
    expr=expr.strip()
    expr=expr.replace('~=','!=').replace('^','**')
    expr=re.sub(r'\btrue\b','True',expr,flags=re.I)
    expr=re.sub(r'\bfalse\b','False',expr,flags=re.I)
    expr=re.sub(r'\bnil\b','None',expr,flags=re.I)
    tree=ast.parse(expr, mode='eval')
    allowed=(ast.Expression,ast.Constant,ast.UnaryOp,ast.BinOp,ast.BoolOp,ast.Compare,
             ast.Add,ast.Sub,ast.Mult,ast.Div,ast.FloorDiv,ast.Mod,ast.Pow,
             ast.UAdd,ast.USub,ast.Not,ast.And,ast.Or,ast.Eq,ast.NotEq,ast.Lt,ast.LtE,ast.Gt,ast.GtE)
    for n in ast.walk(tree):
        if not isinstance(n,allowed):
            raise ValueError('unsafe expression')
    return eval(compile(tree,'<safe>','eval'),{'__builtins__':{}},{})


def decode_lua_quoted_string(token: str) -> str:
    if len(token)<2 or token[0] not in "\"'" or token[-1]!=token[0]:
        return token
    body=token[1:-1]

    def dec(m):
        try:return chr(int(m.group(1),10)&0xff)
        except:return m.group(0)
    body=re.sub(r'\\(\d{1,3})', dec, body)
    def hx(m):
        try:return chr(int(m.group(1),16))
        except:return m.group(0)
    body=re.sub(r'\\x([0-9A-Fa-f]{2})', hx, body)
    body=re.sub(r'\\u\{([0-9A-Fa-f]+)\}', lambda m: chr(int(m.group(1),16)), body)

    body=body.replace('\\n','\n').replace('\\r','\r').replace('\\t','\t').replace('\\\\','\\')
    if token[0]=='"': body=body.replace('\\"','"')
    else: body=body.replace("\\'", "'")
    return body





class _LuaConstantParser:
    """Tiny parser for constant-only Lua table literals.

    It intentionally supports only the syntax needed by protected loader metadata:
    array-style tables, nested tables, quoted strings, numbers, booleans and nil.
    No Lua code is evaluated.
    """
    def __init__(self, source: str):
        self.s = source
        self.i = 0
        self.n = len(source)

    def _skip(self) -> None:
        while self.i < self.n:
            if self.s[self.i].isspace():
                self.i += 1
                continue
            if self.s.startswith('--', self.i):
                j = self.s.find('\n', self.i + 2)
                self.i = self.n if j < 0 else j + 1
                continue
            break

    def _string(self) -> str:
        q = self.s[self.i]
        start = self.i
        self.i += 1
        while self.i < self.n:
            ch = self.s[self.i]
            if ch == '\\':
                self.i += 2
                continue
            self.i += 1
            if ch == q:
                break
        return decode_lua_quoted_string(self.s[start:self.i])

    def _number(self):
        m = re.match(r'[+-]?(?:0[xX][0-9A-Fa-f]+|(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)', self.s[self.i:])
        if not m:
            raise ValueError(f'expected number at offset {self.i}')
        tok = m.group(0)
        self.i += len(tok)
        if re.match(r'[+-]?0[xX]', tok):
            sign = -1 if tok.startswith('-') else 1
            raw = tok[1:] if tok[:1] in '+-' else tok
            return sign * int(raw, 16)
        v = float(tok)
        return int(v) if v.is_integer() else v

    def value(self):
        self._skip()
        if self.i >= self.n:
            raise ValueError('unexpected end of constant expression')
        ch = self.s[self.i]
        if ch == '{':
            return self.table()
        if ch in "\"'":
            return self._string()
        if ch.isdigit() or ch in '+-.':
            return self._number()
        for word, value in (('true', True), ('false', False), ('nil', None)):
            if self.s.startswith(word, self.i) and (self.i + len(word) == self.n or not (self.s[self.i+len(word)].isalnum() or self.s[self.i+len(word)] == '_')):
                self.i += len(word)
                return value
        raise ValueError(f'unsupported constant token at offset {self.i}: {self.s[self.i:self.i+20]!r}')

    def table(self):
        self._skip()
        if self.i >= self.n or self.s[self.i] != '{':
            raise ValueError('expected table literal')
        self.i += 1
        out = []
        while True:
            self._skip()
            if self.i >= self.n:
                raise ValueError('unterminated table literal')
            if self.s[self.i] == '}':
                self.i += 1
                return out
            out.append(self.value())
            self._skip()
            if self.i < self.n and self.s[self.i] in ',;':
                self.i += 1
                continue
            if self.i < self.n and self.s[self.i] == '}':
                continue
            raise ValueError(f'expected comma or closing brace at offset {self.i}')


def _find_lua_table_assignment(code: str, name: str) -> Optional[tuple[str, int, int]]:
    """Return (table_literal, start, end) for NAME = {...}, respecting strings."""
    m = re.search(r'\b' + re.escape(name) + r'\s*=\s*\{', code)
    if not m:
        return None
    start = code.find('{', m.start())
    i = start
    depth = 0
    n = len(code)
    while i < n:
        ch = code[i]
        if ch in "\"'":
            q = ch
            i += 1
            while i < n:
                if code[i] == '\\':
                    i += 2
                    continue
                if code[i] == q:
                    i += 1
                    break
                i += 1
            continue
        if code.startswith('--', i):
            lm = re.match(r'--\[(=*)\[', code[i:])
            if lm:
                endmark = ']' + lm.group(1) + ']'
                j = code.find(endmark, i + lm.end())
                i = n if j < 0 else j + len(endmark)
                continue
            j = code.find('\n', i + 2)
            i = n if j < 0 else j + 1
            continue
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                return code[start:i+1], start, i+1
        i += 1
    return None


def _luarmor_entry_summary(value: Any, index: Optional[int] = None) -> dict[str, Any]:
    out: dict[str, Any] = {}
    if index is not None:
        out['index'] = index
    if isinstance(value, list):
        out['type'] = 'table'
        out['length'] = len(value)
        out['items'] = [_luarmor_entry_summary(v, i + 1) for i, v in enumerate(value)]
        return out
    if isinstance(value, bool):
        out.update(type='boolean', value=value)
        return out
    if value is None:
        out.update(type='nil', value=None)
        return out
    if isinstance(value, (int, float)):
        out.update(type='number', value=value)
        return out
    if isinstance(value, str):
        raw = bytes((ord(c) & 0xFF) for c in value)
        printable = sum(32 <= b < 127 or b in (9, 10, 13) for b in raw) / max(1, len(raw))
        out['type'] = 'string'
        out['length'] = len(raw)
        out['sha256'] = hashlib.sha256(raw).hexdigest()
        out['printable_ratio'] = round(printable, 4)
        uniq = sorted(set(value))
        if len(value) >= 32 and len(value) % 2 == 0 and re.fullmatch(r'[0-9A-Fa-f]+', value):
            out['encoding_hint'] = 'hex ciphertext/blob'
            out['decoded_length'] = len(value) // 2
            out['text'] = value
        elif len(value) >= 24 and len(uniq) == 16 and all(32 <= ord(c) < 127 for c in uniq):
            out['encoding_hint'] = '16-symbol/nibble-alphabet ciphertext'
            out['alphabet'] = ''.join(uniq)
            out['text'] = value
        elif printable >= .85:
            out['text'] = value
        else:
            out['encoding_hint'] = 'binary string'
            out['hex'] = raw.hex()
        return out
    out.update(type=type(value).__name__, value=repr(value))
    return out



def extract_luarmor_v4_loader_refs(source_or_path) -> list[dict[str, str]]:
    """Return official Luarmor V4 loader references found in source."""
    code, _ = _read_input(source_or_path)
    out=[]
    seen=set()
    for m in re.finditer(r'https://api\.luarmor\.net/files/v4/loaders/([0-9a-f]{16,64})\.lua', code, re.I):
        url=m.group(0)
        key=url.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append({'loader_id':m.group(1), 'url':url, 'stage':'public-v4-loader'})
    for m in re.finditer(r'https://cdn\.luarmor\.net/(v4_init_[A-Za-z0-9_-]+\.lua)', code, re.I):
        url=m.group(0)
        key=url.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append({'loader_id':m.group(1)[:-4], 'url':url, 'stage':'v4-init'})
    return out

def extract_luarmor_v4_bootstrap(source_or_path) -> Optional[dict[str, Any]]:
    """Extract Luarmor V4 `_bsdata0` bootstrap metadata without running Lua.

    New Luarmor loaders keep the protected payload in `_bsdata0` and execute a
    separately downloaded, access-controlled init script.  This routine parses
    the local metadata exactly and reports the remote/cache loader relationship.
    """
    code, _ = _read_input(source_or_path)
    found = _find_lua_table_assignment(code, '_bsdata0')
    if not found:
        return None
    table_text, start, end = found
    init_urls = re.findall(r'https://(?:cdn|api)\.luarmor\.net/[^"\']+', code, re.I)
    v4_signal = any('/v4' in u.lower() or 'v4_init_' in u.lower() for u in init_urls)
    if not v4_signal and 'static_content_130525' not in code:
        return None
    try:
        values = _LuaConstantParser(table_text).table()
    except Exception as exc:
        values = None
        parse_error = str(exc)
    else:
        parse_error = None

    cache_dir = None
    m = re.search(r'["\'](static_content_\d+)["\']', code, re.I)
    if m:
        cache_dir = m.group(1)
    cache_tag = None
    m = re.search(r'local\s+[A-Za-z_]\w*\s*,\s*[A-Za-z_]\w*\s*,\s*[A-Za-z_]\w*\s*=\s*["\']static_content_\d+["\']\s*,\s*["\']([^"\']+)["\']', code)
    if m:
        cache_tag = m.group(1)
    if cache_tag is None:
        m = re.search(r'init-([A-Za-z0-9_-]+?)(?:\.lua|["\'])', code)
        if m:
            cache_tag = m.group(1)

    loader_url = init_urls[0] if init_urls else None
    variant = 'Luarmor V4 bootstrap'
    if loader_url:
        mm = re.search(r'v4_init_([A-Za-z0-9_-]+)\.lua', loader_url, re.I)
        if mm:
            variant += f' ({mm.group(1)})'
    info: dict[str, Any] = {
        'family': 'Luarmor V4',
        'variant': variant,
        'loader_url': loader_url,
        'all_luarmor_urls': init_urls,
        'loader_refs': extract_luarmor_v4_loader_refs(code),
        'cache_directory': cache_dir,
        'cache_tag': cache_tag,
        'bsdata_literal_start': start,
        'bsdata_literal_end': end,
        'bsdata_entry_count': len(values) if isinstance(values, list) else None,
        'bsdata': [_luarmor_entry_summary(v, i + 1) for i, v in enumerate(values)] if isinstance(values, list) else None,
        'parse_error': parse_error,
        'requires_external_init': True,
        'static_plaintext_available': False,
    }
    return info



def find_luarmor_v4_cache_files(input_path: str | os.PathLike, info: Optional[dict[str, Any]] = None) -> list[str]:
    """Find Luarmor V4 cache/init files near an input file without executing them."""
    p = Path(input_path)
    if not p.exists():
        return []
    if info is None:
        try:
            info = extract_luarmor_v4_bootstrap(p)
        except Exception:
            info = None
    cache_dir = (info or {}).get('cache_directory') or 'static_content_130525'
    roots = []
    for r in (p.parent, p.parent.parent, Path.cwd()):
        try:
            rr = (r / cache_dir).resolve()
        except Exception:
            continue
        if rr not in roots:
            roots.append(rr)
    found: list[Path] = []
    for root in roots:
        if not root.exists() or not root.is_dir():
            continue
        for f in root.iterdir():
            if not f.is_file():
                continue
            try:
                size = f.stat().st_size
            except OSError:
                continue
            if size < 256:
                continue
            if f.suffix.lower() not in ('.lua', '.luau', '.txt', '.json', '.js', ''):
                continue
            found.append(f.resolve())

    tag = (info or {}).get('cache_tag') or ''
    def rank(f: Path):
        name = f.name.lower()
        init_score = 0 if name.startswith('init') else 1
        exact = 0 if tag and tag.lower() in name else 1
        try: size = -f.stat().st_size
        except OSError: size = 0
        return (init_score, exact, size, name)
    found = sorted(set(found), key=rank)
    return [str(x) for x in found]

def _render_luarmor_v4_static_report(info: dict[str, Any]) -> str:
    lines = [
        '-- LelSploit recognized Luarmor V4 bootstrap',
        '-- The bootstrap contains encrypted per-script metadata in _bsdata0.',
        '-- Plaintext source is not present in this file; the access-controlled V4 init loader performs the next stage.',
    ]
    if info.get('loader_url'):
        lines.append('-- loader_url: ' + str(info['loader_url']))
    if info.get('cache_directory'):
        lines.append('-- cache_directory: ' + str(info['cache_directory']))
    if info.get('cache_tag'):
        lines.append('-- cache_tag: ' + str(info['cache_tag']))
    lines.append('-- bsdata entries: ' + str(info.get('bsdata_entry_count')))
    for ent in info.get('bsdata') or []:
        desc = f"--   [{ent.get('index')}] {ent.get('type')}"
        if ent.get('type') == 'number':
            desc += f" = {ent.get('value')}"
        elif ent.get('type') == 'string':
            desc += f" len={ent.get('length')}"
            if ent.get('encoding_hint'):
                desc += f" ({ent.get('encoding_hint')})"
            desc += f" sha256={ent.get('sha256')}"
        elif ent.get('type') == 'table':
            desc += f" len={ent.get('length')}"
        lines.append(desc)
    return '\n'.join(lines) + '\n'

def _lua_quote(s: str) -> str:
    out=['"']
    for ch in s:
        o=ord(ch)
        if ch=='\\':out.append('\\\\')
        elif ch=='"':out.append('\\"')
        elif ch=='\n':out.append('\\n')
        elif ch=='\r':out.append('\\r')
        elif ch=='\t':out.append('\\t')
        elif o < 32 or (127 <= o <= 255):out.append('\\%03d' % o)
        else:out.append(ch)
    out.append('"')
    return ''.join(out)


def pass_numeric_escapes(code: str) -> str:
    q=re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
    def repl(m):
        tok=m.group(0)
        if not re.search(r'\\(?:\d{1,3}|x[0-9A-Fa-f]{2}|u\{[0-9A-Fa-f]+\})',tok):
            return tok
        try:return _lua_quote(decode_lua_quoted_string(tok))
        except:return tok
    return q.sub(repl,code)


def pass_string_char(code: str) -> str:
    pat=re.compile(r'string\.char\s*\(\s*((?:0x[0-9A-Fa-f]+|\d+)(?:\s*,\s*(?:0x[0-9A-Fa-f]+|\d+)){1,})\s*\)')
    def repl(m):
        try:
            nums=[int(x.strip(),0)&255 for x in m.group(1).split(',')]
            s=bytes(nums).decode('utf-8')
            return _lua_quote(s)
        except Exception:
            try:return _lua_quote(''.join(chr(int(x.strip(),0)&255) for x in m.group(1).split(',')))
            except:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_literal_concat(code: str) -> str:
    pat=re.compile(r'((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')\s*\.\.\s*)+("(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')')
    def repl(m):
        toks=re.findall(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',m.group(0))
        try:return _lua_quote(''.join(decode_lua_quoted_string(t) for t in toks))
        except:return m.group(0)
    for _ in range(4):
        new=_sub_code(pat,repl,code)
        if new==code: break
        code=new
    return code


def pass_arithmetic_constants(code: str) -> str:

    pat=re.compile(r'\(([-+*/%^<>=~\s\d\.xXa-fA-F]+)\)')
    def repl(m):
        expr=m.group(1)
        if not re.search(r'[+*/%^<>~=]|\s-\s',expr): return m.group(0)
        try:
            v=_safe_arith_eval(expr)
            if isinstance(v,bool): return 'true' if v else 'false'
            if v is None:return 'nil'
            if isinstance(v,float) and v.is_integer(): return str(int(v))
            return repr(v)
        except:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_base64_literals(code: str) -> str:

    pat=re.compile(r'(?i)\b(?:base64(?:decode|_decode)|b64decode|decode64)\s*\(\s*(["\'])([A-Za-z0-9+/=_-]{8,})\1\s*\)')
    def repl(m):
        raw=m.group(2)
        try:
            padded=raw + '='*((4-len(raw)%4)%4)
            b=base64.urlsafe_b64decode(padded.encode())
            s=b.decode('utf-8')
            if sum(ch.isprintable() or ch in '\r\n\t' for ch in s)/max(1,len(s))<0.85:return m.group(0)
            return _lua_quote(s)
        except:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_hex_literals(code: str) -> str:
    pat=re.compile(r'(?i)\b(?:hexdecode|fromhex|unhex)\s*\(\s*(["\'])([0-9a-f]{8,})\1\s*\)')
    def repl(m):
        try:
            b=bytes.fromhex(m.group(2)); s=b.decode('utf-8')
            if sum(ch.isprintable() or ch in '\r\n\t' for ch in s)/max(1,len(s))<0.85:return m.group(0)
            return _lua_quote(s)
        except:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_table_concat_constants(code: str) -> str:

    strpat=re.compile(r'table\.concat\s*\(\s*\{\s*((?:["\'](?:\\.|[^"\'\\])*["\']\s*,?\s*){2,})\}\s*(?:,\s*(["\'])(.*?)\2\s*)?\)',re.S)
    def sr(m):
        toks=re.findall(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',m.group(1))
        try:return _lua_quote((m.group(3) or '').join(decode_lua_quoted_string(t) for t in toks))
        except:return m.group(0)
    code=_sub_code(strpat,sr,code)
    numpat=re.compile(r'(?:table\.concat|string\.char)\s*\(\s*\{?\s*((?:\d+\s*,\s*){3,}\d+)\s*\}?\s*\)')
    def nr(m):
        try:return _lua_quote(''.join(chr(int(x)&255) for x in m.group(1).split(',')))
        except:return m.group(0)
    return _sub_code(numpat,nr,code)


def pass_constant_tables(code: str) -> str:

    pat=re.compile(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*\{\s*((?:["\'](?:\\.|[^"\'\\])*["\']\s*,?\s*){2,})\}',re.S)
    tables=[]
    for m in pat.finditer(code):
        name=m.group(1)

        if re.search(r'\b'+re.escape(name)+r'\s*\[[^\]]+\]\s*=', code[m.end():]):
            continue
        toks=re.findall(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',m.group(2))
        vals=[_lua_quote(decode_lua_quoted_string(t)) for t in toks]
        tables.append((name,vals))
    for name,vals in tables:
        def rr(m):
            idx=int(m.group(1)); return vals[idx-1] if 1<=idx<=len(vals) else m.group(0)
        code=_sub_code(r'\b'+re.escape(name)+r'\s*\[\s*(\d+)\s*\]',rr,code)
    return code


def pass_simple_dead_branches(code: str) -> str:

    code=re.sub(r'\bif\s+false\s+then\s*(.*?)\s*end\b','',code,flags=re.S)
    code=re.sub(r'\bif\s+true\s+then\s*(.*?)\s*end\b',lambda m:m.group(1),code,flags=re.S)
    return code


def pass_alias_globals(code: str) -> str:

    names=['string.byte','string.char','string.sub','string.gsub','string.rep','table.concat','table.insert','math.ldexp','math.floor','tonumber','select','setmetatable','pcall']
    for target in names:
        m=re.search(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*'+re.escape(target)+r'\s*;?',code)
        if not m: continue
        alias=m.group(1)
        code=code[:m.start()]+code[m.end():]
        code=_replace_identifier_code(code,alias,target)
    return code


def pass_prometheus_conservative(code: str) -> str:

    funcs=[reverse_pipeline,clean_name_generators,unwrap_functions,reconstruct_tokenized,
           restore_control_flow,reconstruct_functions,reconstruct_locals,reconstruct_conditions,
           remove_junkcode,clean_tokenized_syntax,handle_antitamper]
    for fn in funcs:
        try:
            new=fn(code)
            if isinstance(new,str): code=new
        except Exception:
            pass
    return code


def _looks_like_aztup_lzw(code: str) -> bool:
    return bool(re.search(r'tonumber\s*\(\s*[^,]+,\s*36\s*\)',code) and 'table.concat' in code and 'string.sub' in code)


def _decode_aztup_lzw_payload(payload: str) -> Optional[str]:
    """Reverse the base-36 variable-width LZW decoder used by common AztupBrew builds."""
    try:
        pos=0
        def readnum():
            nonlocal pos
            if pos>=len(payload): raise ValueError
            width=int(payload[pos],36); pos+=1
            n=int(payload[pos:pos+width],36); pos+=width
            return n
        dictionary={i:chr(i) for i in range(256)}
        nextcode=256
        first=chr(readnum()); out=[first]; prev=first
        while pos<len(payload):
            n=readnum()
            cur=dictionary.get(n, prev+prev[0] if n==nextcode else None)
            if cur is None: raise ValueError
            out.append(cur); dictionary[nextcode]=prev+cur[0]; nextcode+=1; prev=cur
        return ''.join(out)
    except Exception:
        return None


def pass_aztupbrew_payload(code: str) -> str:
    if not _looks_like_aztup_lzw(code): return code

    q=re.compile(r'(["\'])([0-9A-Za-z]{80,})\1')
    best=None
    for m in q.finditer(code):
        dec=_decode_aztup_lzw_payload(m.group(2))
        if not dec: continue
        printable=sum(ch.isprintable() or ch in '\r\n\t' for ch in dec)/max(1,len(dec))
        luaish=sum(x in dec for x in ('local ','function','return ','string.','\x1bLua'))
        if printable>0.7 or luaish:
            if best is None or len(dec)>len(best[2]): best=(m.start(),m.end(),dec)
    if not best:return code
    s,e,dec=best

    return code[:s]+_lua_quote(dec)+code[e:]




def pass_tonumber_literals(code: str) -> str:
    pat=re.compile(r'\btonumber\s*\(\s*(["\'])([0-9A-Za-z_+-]+)\1\s*,\s*(\d+)\s*\)')
    def repl(m):
        try:
            base=int(m.group(3));
            if not (2 <= base <= 36): return m.group(0)
            return str(int(m.group(2).replace('_',''),base))
        except:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_reverse_literals(code: str) -> str:
    pat=re.compile(r'\bstring\.reverse\s*\(\s*(["\'])(.*?)\1\s*\)',re.S)
    def repl(m):
        try:return _lua_quote(decode_lua_quoted_string(m.group(1)+m.group(2)+m.group(1))[::-1])
        except:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_bitwise_constants(code: str) -> str:
    ops={'bxor':lambda a,b:a^b,'band':lambda a,b:a&b,'bor':lambda a,b:a|b,
         'lshift':lambda a,b:(a<<b)&0xffffffff,'rshift':lambda a,b:(a&0xffffffff)>>b}
    pat=re.compile(r'\b(?:bit32|bit)\.(bxor|band|bor|lshift|rshift)\s*\(\s*(-?(?:0x[0-9A-Fa-f]+|\d+))\s*,\s*(-?(?:0x[0-9A-Fa-f]+|\d+))\s*\)')
    def repl(m):
        try:return str(ops[m.group(1)](int(m.group(2),0),int(m.group(3),0)))
        except:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_mixed_radix_numbers(code: str) -> str:

    def b(m):
        try:return str(int(m.group(0).replace('_',''),2))
        except:return m.group(0)
    def h(m):
        try:return str(int(m.group(0).replace('_',''),16))
        except:return m.group(0)
    code=_sub_code(r'\b0[bB][01_]+\b',b,code)
    code=_sub_code(r'\b0[xX][0-9A-Fa-f_]+\b',h,code)
    return code


def pass_unwrap_literal_loader(code: str) -> str:

    m=re.fullmatch(r'\s*(?:(?:--[^\n]*\n)\s*)*(?:return\s+)?(?:loadstring|load)\s*\(\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*\)\s*\(\s*\)\s*;?\s*',code,re.S)
    if not m:return code
    try:
        inner=decode_lua_quoted_string(m.group(1))
        if inner and sum(c.isprintable() or c in '\r\n\t' for c in inner)/len(inner)>0.9:
            return inner
    except:pass
    return code


def _decode_ironbrew_hexrle_payload(payload: str) -> Optional[str]:
    """Decode the common IronBrew `Sub(ByteString,5)` pair/RLE packing stage."""
    if len(payload)<8:return None
    data=payload[4:]
    out=[]; repeat=None
    i=0
    try:
        while i+1 < len(data):
            pair=data[i:i+2]; i+=2
            if pair[1] in 'Oo':
                repeat=int(pair[0],16 if pair[0].lower() in 'abcdef' else 10)
                continue
            ch=chr(int(pair,16))
            if repeat is not None:
                out.append(ch*repeat); repeat=None
            else:out.append(ch)
        return ''.join(out)
    except:return None


def pass_ironbrew_hexrle(code: str) -> str:
    if not (re.search(r'gBits(?:8|16|32)|VMCall\s*\(',code) or re.search(r'Subg\s*\(\s*Sub\s*\([^,]+,\s*5\s*\)',code)):
        return code
    q=re.compile(r'(["\'])([0-9A-Fa-fOo]{80,})\1')
    best=None
    for m in q.finditer(code):
        dec=_decode_ironbrew_hexrle_payload(m.group(2))
        if not dec:continue
        printable=sum(c.isprintable() or c in '\r\n\t' for c in dec)/max(1,len(dec))
        if printable>0.5 or dec.startswith('\x1bLua'):
            if best is None or len(dec)>len(best[2]):best=(m.start(),m.end(),dec)
    if not best:return code
    a,b,dec=best
    return code[:a]+_lua_quote(dec)+code[b:]





def _printable_ratio(s: str) -> float:
    if not s:
        return 1.0
    return sum(ch.isprintable() or ch in '\r\n\t' for ch in s) / len(s)


def _bytes_from_lua_string(token: str) -> bytes:
    """Best-effort Lua string literal -> raw bytes without executing Lua."""
    val = decode_lua_quoted_string(token)
    return bytes((ord(ch) & 0xFF) for ch in val)


def _hercules_caesar_decode(value: str, offset: int) -> str:
    out=[]
    for ch in value:
        o=ord(ch)
        if 48 <= o <= 57:
            out.append(chr(((o-48-offset) % 10)+48))
        elif 65 <= o <= 90:
            out.append(chr(((o-65-offset) % 26)+65))
        elif 97 <= o <= 122:
            out.append(chr(((o-97-offset) % 26)+97))
        else:
            out.append(ch)
    return ''.join(out)


def _discover_hercules_caesar_names(code: str) -> set[str]:
    names=set()
    for m in re.finditer(r'\blocal\s+function\s+([A-Za-z_]\w*)\s*\(\s*([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*\)', code):
        name,data,key=m.group(1),m.group(2),m.group(3)
        window=code[m.end():m.end()+7000]

        if (re.search(r'-\s*48\s*-\s*'+re.escape(key)+r'.*?%\s*10',window,re.S) and
            re.search(r'-\s*65\s*-\s*'+re.escape(key)+r'.*?%\s*26',window,re.S) and
            re.search(r'-\s*97\s*-\s*'+re.escape(key)+r'.*?%\s*26',window,re.S) and
            'string.char' in window[:5000]):
            names.add(name)
    return names


def pass_hercules_caesar_strings(code: str) -> str:
    names=_discover_hercules_caesar_names(code)
    if not names:
        return code
    for name in sorted(names, key=len, reverse=True):
        pat=re.compile(r'\b'+re.escape(name)+r'\s*\(\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*,\s*(\d{1,3})\s*\)')
        def repl(m):
            try:
                off=int(m.group(2))
                if not (0 <= off <= 255): return m.group(0)
                return _lua_quote(_hercules_caesar_decode(decode_lua_quoted_string(m.group(1)),off))
            except Exception:
                return m.group(0)
        code=_sub_code(pat,repl,code)
    return code


def _find_ascii_lookup_tables(code: str) -> list[tuple[str, dict[int,str], tuple[int,int]]]:
    """Find tables shaped like {[65]='A',[66]='B',...}, even after variable renaming."""
    out=[]
    rx=re.compile(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*\{([^{}]{1,12000})\}',re.S)
    ent=re.compile(r'\[\s*(\d{1,3})\s*\]\s*=\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))')
    for m in rx.finditer(code):
        mp={}
        for e in ent.finditer(m.group(2)):
            try:
                k=int(e.group(1)); v=decode_lua_quoted_string(e.group(2))
                if len(v)==1: mp[k]=v
            except Exception: pass
        matches=sum(1 for k,v in mp.items() if 0 <= k <= 255 and ord(v)==k)
        if len(mp)>=1 and matches == len(mp):
            out.append((m.group(1),mp,(m.start(),m.end())))
    return out


def pass_hercules_string_expressions(code: str) -> str:
    tables=_find_ascii_lookup_tables(code)
    for name,mp,span in tables:
        pat=re.compile(r'\b'+re.escape(name)+r'\s*\[\s*([^\[\]\n]{1,180})\s*\]')
        def repl(m):
            expr=m.group(1).strip()
            try:
                v=_safe_arith_eval(expr)
                if isinstance(v,bool) or not isinstance(v,(int,float)) or int(v)!=v: return m.group(0)
                v=int(v)
                if v in mp: return _lua_quote(mp[v])
            except Exception: pass
            return m.group(0)
        code=_sub_code(pat,repl,code)

    return code


def pass_hercules_wrapper(code: str) -> str:

    m=re.fullmatch(r'\s*\(\s*function\s*\(\s*\.\.\.\s*\)\s*(.*)\s*end\s*\)\s*\(\s*\)\s*;?\s*',code,re.S)
    if not m:
        return code
    body=m.group(1)

    if '...' in body:
        return code
    return body.strip()+"\n"


def _extract_hercules_shifted_bytecode(code: str) -> Optional[bytes]:

    m=re.search(r'\blocal\s+([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*=\s*(["\'])([0-9A-Fa-f]{40,})\4\s*,\s*(\d{1,3})\s*,\s*\{\s*\}',code,re.S)
    if not m:
        return None
    try:
        enc=bytes.fromhex(m.group(5)); off=int(m.group(6))
        return bytes((b-off)&255 for b in enc)
    except Exception:
        return None


def _prometheus_prng_params(code: str) -> Optional[tuple[int,int,int,int]]:
    m45=re.search(r'\b([A-Za-z_]\w*)\s*=\s*\(\s*\1\s*\*\s*(\d+)\s*\+\s*(\d+)\s*\)\s*%\s*35184372088832',code)
    m8=re.search(r'\b([A-Za-z_]\w*)\s*=\s*\1\s*\*\s*(\d+)\s*%\s*257',code)
    if not (m45 and m8):
        return None

    secrets=[]
    for m in re.finditer(r'\blocal\s+[A-Za-z_]\w*\s*=\s*(\d{1,3})\s*;?\s*\blocal\s+[A-Za-z_]\w*\s*=\s*["\']["\']\s*;?\s*\bfor\b',code,re.S):
        v=int(m.group(1))
        if 0 <= v <= 255: secrets.append(v)
    if not secrets:

        for m in re.finditer(r'\blocal\s+[A-Za-z_]\w*\s*=\s*(\d{1,3})\s*;?',code):
            w=code[m.end():m.end()+1200]
            if 'string.byte' in w and '% 256' in w and ('prev_values' in code or '35184372088832' in code):
                v=int(m.group(1))
                if 0 <= v <= 255: secrets.append(v); break
    if not secrets:
        return None
    return int(m45.group(2)),int(m45.group(3)),int(m8.group(2)),secrets[0]


def _prometheus_decrypt_bytes(cipher: bytes, seed: int, mul45: int, add45: int, mul8: int, secret8: int) -> bytes:
    state45=seed % 35184372088832
    state8=seed % 255 + 2
    prev_stack=[]
    def next_byte():
        nonlocal state45,state8,prev_stack
        if not prev_stack:
            state45=(state45*mul45+add45) % 35184372088832
            while True:
                state8=(state8*mul8) % 257
                if state8 != 1: break
            r=state8 % 32
            shift=13 - ((state8-r)//32)

            n=(float(state45)/(2.0**shift)) % (2.0**32)
            n=n/(2.0**r)
            rnd=math.floor((n % 1.0)*(2.0**32))+math.floor(n)
            low=rnd % 65536; high=(rnd-low)//65536
            b1=low % 256; b2=(low-b1)//256; b3=high % 256; b4=(high-b3)//256
            prev_stack=[b1,b2,b3,b4]
        return int(prev_stack.pop())
    out=bytearray(); prev=secret8
    for b in cipher:
        prev=(b+next_byte()+prev) % 256
        out.append(prev)
    return bytes(out)


def pass_prometheus_encrypted_strings(code: str) -> str:
    params=_prometheus_prng_params(code)
    if not params:
        return code
    mul45,add45,mul8,secret8=params

    pat=re.compile(r'\b([A-Za-z_]\w*)\s*\[\s*([A-Za-z_]\w*)\s*\(\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*,\s*(\d{1,14})\s*\)\s*\]')
    def repl(m):
        try:
            cipher=_bytes_from_lua_string(m.group(3)); seed=int(m.group(4))
            plain=_prometheus_decrypt_bytes(cipher,seed,mul45,add45,mul8,secret8)
            text=plain.decode('utf-8',errors='strict')
            if _printable_ratio(text)<0.70: return m.group(0)
            return _lua_quote(text)
        except Exception:
            return m.group(0)
    return _sub_code(pat,repl,code)


def _parse_custom_lookup_tables(code: str, size: int) -> list[tuple[str,dict[str,int]]]:
    out=[]
    rx=re.compile(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*\{([^{}]{80,20000})\}',re.S)
    ent=re.compile(r'\[\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*\]\s*=\s*(\d+)')
    for m in rx.finditer(code):
        mp={}
        for e in ent.finditer(m.group(2)):
            try:
                k=decode_lua_quoted_string(e.group(1)); v=int(e.group(2))
                if len(k)==1: mp[k]=v
            except Exception: pass
        if len(mp)==size and set(mp.values())==set(range(size)):
            out.append((m.group(1),mp))
    return out


def _decode_custom_base64(s: str, lookup: dict[str,int]) -> Optional[bytes]:
    try:
        value=0; count=0; out=bytearray(); i=0
        while i<len(s):
            ch=s[i]
            if ch in lookup:
                value += lookup[ch] * (64 ** (3-count)); count += 1
                if count==4:
                    out.extend(((value//65536)&255,(value%65536//256)&255,value&255)); value=0; count=0
            elif ch=='=':
                out.append((value//65536)&255)
                if i>=len(s)-1 or s[i+1] != '=': out.append((value%65536//256)&255)
                break
            else: return None
            i+=1
        return bytes(out)
    except Exception:return None


def _decode_custom_base85(s: str, lookup: dict[str,int]) -> Optional[bytes]:
    try:
        out=bytearray(); idx=0
        while idx<len(s):
            remain=len(s)-idx; count=min(5,remain)
            if count<=1:return None
            value=0
            for j in range(5):
                code=lookup.get(s[idx+j]) if j<count else 84
                if code is None:return None
                value=value*85+code
            bs=[(value//16777216)%256,(value//65536)%256,(value//256)%256,value%256]
            out.extend(bs[:count-1]); idx+=count
        return bytes(out)
    except Exception:return None


def pass_prometheus_custom_constant_encodings(code: str) -> str:
    """Decode Prometheus shuffled-base64/base85 constant-array literals when lookup tables are embedded."""
    if not any(sig in code for sig in ('64 ^ (3 -', 'value * 85', '16777216')):
        return code
    l64=_parse_custom_lookup_tables(code,64)
    l85=_parse_custom_lookup_tables(code,85)
    if not l64 and not l85:return code

    prefixes=re.findall(r'\bif\s+[A-Za-z_]\w*\s*==\s*(["\'])(.)\1\s*then|\belseif\s+[A-Za-z_]\w*\s*==\s*(["\'])(.)\3\s*then',code)
    pchars=[]
    for a,b,c,d in prefixes:pchars.append(b or d)
    q=re.compile(r'("(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')')
    def repl(m):
        try:s=decode_lua_quoted_string(m.group(1))
        except Exception:return m.group(0)
        candidates=[]
        if len(pchars)>=2 and len(s)>=3:
            if s[0]==pchars[0] and l64:candidates=[_decode_custom_base64(s[1:],l64[0][1])]
            elif s[0]==pchars[1] and l85:candidates=[_decode_custom_base85(s[1:],l85[0][1])]
        else:
            if l64 and len(s)>=8 and len(s)%4==0 and all(ch in l64[0][1] or ch=='=' for ch in s):
                candidates.append(_decode_custom_base64(s,l64[0][1]))
            if l85 and len(s)>=10 and all(ch in l85[0][1] for ch in s):
                candidates.append(_decode_custom_base85(s,l85[0][1]))
        for b in candidates:
            if not b:continue
            try:t=b.decode('utf-8')
            except Exception:continue
            if _printable_ratio(t)>=0.82:return _lua_quote(t)
        return m.group(0)
    return q.sub(repl,code)


def pass_constant_predicates(code: str) -> str:
    """Evaluate side-effect-free literal conditions, leaving block structure to later passes."""
    pat=re.compile(r'\b(if|elseif|while)\s+([^\n]{1,240}?)\s+(then|do)\b')
    def repl(m):
        expr=m.group(2).strip()

        scrub=re.sub(r'\b(?:true|false|nil|not|and|or)\b','',expr,flags=re.I)
        if re.search(r'[A-Za-z_]',scrub):return m.group(0)
        try:
            v=_safe_arith_eval(expr)
            if isinstance(v,(bool,int,float)) or v is None:
                truth=bool(v)
                return f'{m.group(1)} {"true" if truth else "false"} {m.group(3)}'
        except Exception:pass
        return m.group(0)
    return _sub_code(pat,repl,code)


def pass_string_stdlib_constants(code: str) -> str:

    pbyte=re.compile(r'\bstring\.byte\s*\(\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*(?:,\s*(-?\d+)\s*)?\)')
    def rb(m):
        try:
            s=decode_lua_quoted_string(m.group(1)); idx=int(m.group(2) or 1); idx=idx if idx>0 else len(s)+idx+1
            if 1<=idx<=len(s):return str(ord(s[idx-1])&255)
        except Exception:pass
        return m.group(0)
    code=_sub_code(pbyte,rb,code)
    psub=re.compile(r'\bstring\.sub\s*\(\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*,\s*(-?\d+)\s*(?:,\s*(-?\d+)\s*)?\)')
    def rs(m):
        try:
            s=decode_lua_quoted_string(m.group(1)); a=int(m.group(2)); b=int(m.group(3)) if m.group(3) else len(s)
            a=a if a>0 else len(s)+a+1; b=b if b>0 else len(s)+b+1
            a=max(a,1); b=min(b,len(s)); return _lua_quote(s[a-1:b] if b>=a else '')
        except Exception:return m.group(0)
    code=_sub_code(psub,rs,code)
    plen=re.compile(r'\bstring\.len\s*\(\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*\)')
    code=_sub_code(plen,lambda m:str(len(decode_lua_quoted_string(m.group(1)))),code)
    phash=re.compile(r'#\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))')
    code=_sub_code(phash,lambda m:str(len(decode_lua_quoted_string(m.group(1)))),code)
    return code


def pass_string_char_expressions(code: str) -> str:
    pat=re.compile(r'\b(?:string|utf8)\.char\s*\(\s*([^()\n]{1,600})\s*\)')
    def repl(m):
        parts=[x.strip() for x in m.group(1).split(',')]
        if not parts or len(parts)>256:return m.group(0)
        vals=[]
        for x in parts:
            try:
                v=_safe_arith_eval(x)
                if isinstance(v,bool) or not isinstance(v,(int,float)) or int(v)!=v:return m.group(0)
                vals.append(int(v))
            except Exception:return m.group(0)
        try:
            if m.group(0).lstrip().startswith('utf8.char'):
                return _lua_quote(''.join(chr(v) for v in vals))
            return _lua_quote(''.join(chr(v&255) for v in vals))
        except Exception:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_indexed_globals(code: str) -> str:

    pat=re.compile(r'\b(_G|_ENV|string|table|math|bit32|bit|utf8|coroutine|buffer)\s*\[\s*(["\'])([A-Za-z_]\w*)\2\s*\]')
    def repl(m):
        base,key=m.group(1),m.group(3)
        return key if base in ('_G','_ENV') else base+'.'+key
    return _sub_code(pat,repl,code)


def pass_single_byte_xor_helpers(code: str) -> str:
    """Recognize simple literal XOR decoder helpers and evaluate their literal calls."""
    helpers=[]
    for m in re.finditer(r'\blocal\s+function\s+([A-Za-z_]\w*)\s*\(\s*([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*\)',code):
        name,data,key=m.group(1),m.group(2),m.group(3); w=code[m.end():m.end()+3500]
        if re.search(r'(?:bit32|bit)\.bxor\s*\(\s*(?:string\.byte\s*\(\s*'+re.escape(data)+r'|[^,]+)\s*.*?,\s*'+re.escape(key)+r'\s*\)',w,re.S) and 'string.char' in w:
            helpers.append(name)
    for name in helpers:
        pat=re.compile(r'\b'+re.escape(name)+r'\s*\(\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*,\s*(0x[0-9A-Fa-f]+|\d+)\s*\)')
        def repl(m):
            try:
                key=int(m.group(2),0)&255; raw=_bytes_from_lua_string(m.group(1)); dec=bytes(b^key for b in raw)
                t=dec.decode('utf-8')
                return _lua_quote(t) if _printable_ratio(t)>=0.75 else m.group(0)
            except Exception:return m.group(0)
        code=_sub_code(pat,repl,code)
    return code


def _lua_keyword_tokens(code: str):
    spans=_lua_protected_spans(code); si=0
    for m in re.finditer(r'\b(?:do|end|function|if|for|while|repeat|until)\b',code):
        pos=m.start()
        while si<len(spans) and spans[si][1] <= pos:si+=1
        if si<len(spans) and spans[si][0] <= pos < spans[si][1]:continue
        yield m.group(0),m.start(),m.end()


def _matching_lua_block_end(code: str, opener_pos: int) -> Optional[int]:
    toks=list(_lua_keyword_tokens(code)); start=None
    for i,(_,a,_) in enumerate(toks):
        if a>=opener_pos:start=i;break
    if start is None:return None
    stack=[]; pending_loop=False
    for kw,a,b in toks[start:]:
        if not stack:
            if a!=toks[start][1]:continue
        if kw in ('for','while'):
            stack.append(kw); pending_loop=True
        elif kw=='if' or kw=='function' or kw=='repeat':
            stack.append(kw); pending_loop=False
        elif kw=='do':
            if pending_loop: pending_loop=False
            else: stack.append('do')
        elif kw=='until':
            if stack and stack[-1]=='repeat':stack.pop()
        elif kw=='end':
            if stack and stack[-1] != 'repeat':stack.pop()
        if not stack and a>opener_pos:return b
    return None


def pass_hercules_antitamper(code: str) -> str:

    m=re.match(r'\s*do\b',code)
    if not m:return code
    end=_matching_lua_block_end(code,m.start()+len(m.group(0))-2)
    if not end:return code
    block=code[m.start():end]
    if 'Tamper Detected! Reason:' in block and ('Critical function' in block or 'Debug library incomplete' in block):
        return code[:m.start()]+code[end:].lstrip()
    return code




def pass_hercules_control_flow(code: str) -> str:
    """Undo the current Hercules one-shot control-flow wrapper when its exact scaffold is present.

    Hercules' public control-flow module emits literal identifiers `thing`, `thing2`, and
    `counter` *after* its rename pass.  We only unwrap when all invariants match, so this
    does not attempt to guess arbitrary user loops.
    """
    head=re.search(
        r'\blocal\s+thing\s*=\s*(-?\d+)\s*;?\s*'
        r'\blocal\s+thing2\s*=\s*(-?\d+)\s*;?\s*'
        r'\blocal\s+counter\s*=\s*0\s*;?\s*'
        r'\bwhile\s+thing\s*==\s*thing2\s+and\s+counter\s*<\s*1\s+do\b',
        code,re.S)
    if not head or head.group(1) != head.group(2):
        return code
    while_pos=code.rfind('while', head.start(), head.end())
    while_end=_matching_lua_block_end(code,while_pos)
    if not while_end:
        return code
    block=code[head.end():while_end-3]

    arm=re.search(r'\bif\s+thing\s*==\s*thing2\s+then\b.*?\belse\s+do\b',block,re.S)
    if not arm:
        return code
    do_rel=block.rfind('do',0,arm.end())
    do_abs=head.end()+do_rel
    do_end=_matching_lua_block_end(code,do_abs)
    if not do_end or do_end > while_end:
        return code
    payload=code[do_abs+2:do_end-3].strip()
    if not payload:
        return code

    prefix=code[:head.start()]
    suffix=code[while_end:]
    suffix=re.sub(r'^\s*;?\s*(?:local\s+\w+\s*=\s*\d+\s*;?\s*)?','',suffix,count=1)
    return prefix+payload+'\n'+suffix


def pass_luraph_xpcall_wrapper(code: str) -> str:
    """Strip the common outer `xpcall(function() ... end, function(e) ... end)` shell.

    Uses block matching instead of a dot-star regex, so nested functions/ifs in the payload
    do not cause the wrong `end` to be selected.
    """
    m=re.match(r'\s*xpcall\s*\(\s*(?P<fn>function)\s*\(\s*\)\s*',code,re.S)
    if not m:
        return code
    fn_pos=m.start('fn')
    first_end=_matching_lua_block_end(code,fn_pos)
    if not first_end:
        return code
    rest=code[first_end:]
    h=re.match(r'\s*,\s*(?P<fn>function)\s*\([^)]*\)\s*',rest,re.S)
    if not h:
        return code
    second_pos=first_end+h.start('fn')
    second_end=_matching_lua_block_end(code,second_pos)
    if not second_end:
        return code
    if not re.fullmatch(r'\s*\)\s*;?\s*',code[second_end:]):
        return code
    body=code[m.end():first_end-3].strip()
    return body+'\n' if body else code


def _decode_b64_zlib_text(token: str) -> Optional[str]:
    try:
        raw=base64.b64decode(token + '='*((-len(token))%4),validate=False)
    except Exception:
        return None
    variants=[raw]
    for wb in (zlib.MAX_WBITS, -zlib.MAX_WBITS, 16+zlib.MAX_WBITS):
        try:
            d=zlib.decompress(raw,wb)
            if d not in variants: variants.insert(0,d)
        except Exception:
            pass
    for fn in (bz2.decompress,lzma.decompress):
        try:
            d=fn(raw)
            if d not in variants:variants.insert(0,d)
        except Exception:
            pass
    for data in variants:
        try:t=data.decode('utf-8')
        except Exception:continue
        if len(t)>=8 and _printable_ratio(t)>=0.88 and re.search(r'\b(?:local|function|return|if|for|while|load|string|table)\b',t):
            return t
    return None


def pass_luraph_base64_zlib_literals(code: str) -> str:
    """Decode textual Base64(+zlib/gzip/raw-deflate) blobs while preserving string semantics."""
    pat=re.compile(r'(["\'])([A-Za-z0-9+/]{24,}={0,2})\1')
    def repl(m):
        t=_decode_b64_zlib_text(m.group(2))
        return _lua_quote(t) if t is not None else m.group(0)

    return pat.sub(repl,code)



def _discover_clyde_decoders(code: str) -> set[str]:
    names=set(re.findall(r'\b(_clydeDec_[A-Za-z0-9_]+)\b',code))

    pats=[
        re.compile(r'\blocal\s+function\s+([A-Za-z_]\w*)\s*\(\s*([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*\)'),
        re.compile(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*function\s*\(\s*([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*\)'),
    ]
    for pat in pats:
        for m in pat.finditer(code):
            name,t,k=m.group(1),m.group(2),m.group(3)
            fpos=code.find('function',m.start(),m.end())
            end=_matching_lua_block_end(code,fpos)
            if not end:continue
            body=code[m.end():end-3]
            bx=re.search(r'(?:bit32|bit)\.bxor\s*\(\s*'+re.escape(t)+r'\s*\[\s*[A-Za-z_]\w*\s*\]\s*,\s*'+re.escape(k)+r'\s*\)',body)
            if bx and 'string.char' in body and 'table.concat' in body:names.add(name)
    return names


def pass_clyde_xor_tables(code: str) -> str:
    """Reverse Clyde's public StringEncoder: decoder({xor_bytes...}, key) -> literal."""
    names=_discover_clyde_decoders(code)
    if not names:return code
    for name in sorted(names,key=len,reverse=True):
        pat=re.compile(r'\b'+re.escape(name)+r'\s*\(\s*\{\s*((?:0x[0-9A-Fa-f]+|\d+)\s*(?:,\s*(?:0x[0-9A-Fa-f]+|\d+)\s*)*)\}\s*,\s*(0x[0-9A-Fa-f]+|\d+)\s*\)')
        def repl(m):
            try:
                vals=[int(x,0) for x in re.findall(r'0x[0-9A-Fa-f]+|\d+',m.group(1))]
                key=int(m.group(2),0)&255
                if not vals or not all(0<=x<=255 for x in vals):return m.group(0)
                raw=bytes(x^key for x in vals); text=raw.decode('utf-8')
                return _lua_quote(text) if _printable_ratio(text)>=0.70 else m.group(0)
            except Exception:return m.group(0)
        code=_sub_code(pat,repl,code)
    return code




def pass_bill_rotating_xor(code: str) -> str:
    """Reverse BillChirico/LUA-Obfuscator's current rotating-key XOR IIFE."""
    pat=re.compile(
        r'\(\s*function\s*\(\s*([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*\)'
        r'(.*?)\bend\s*\)\s*\(\s*\{\s*((?:0x[0-9A-Fa-f]+|\d+)\s*(?:,\s*(?:0x[0-9A-Fa-f]+|\d+)\s*)*)\}\s*,\s*(0x[0-9A-Fa-f]+|\d+)\s*\)',re.S)
    def repl(m):
        body=m.group(3); t,k=m.group(1),m.group(2)

        if 'string.char' not in body or '%255' not in re.sub(r'\s+','',body):return m.group(0)
        compact=re.sub(r'\s+','',body)
        if not (re.search(re.escape(t)+r'\[[A-Za-z_]\w*\]~\(\(\('+re.escape(k),compact) or
                ('bit32.bxor' in compact and re.escape(k))):

            if '~(((' not in compact:return m.group(0)
        try:
            vals=[int(x,0) for x in re.findall(r'0x[0-9A-Fa-f]+|\d+',m.group(4))]
            key=int(m.group(5),0)
            if not vals or not 1<=key<=255 or not all(0<=v<=255 for v in vals):return m.group(0)
            raw=bytes(v ^ (((key+i)%255)+1) for i,v in enumerate(vals))
            text=raw.decode('utf-8')
            return _lua_quote(text) if _printable_ratio(text)>=0.70 else m.group(0)
        except Exception:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_bill_huffman(code: str) -> str:
    """Reverse the public code-sequence/dictionary string form used as Bill's Huffman option."""
    pat=re.compile(
        r'\(\s*function\s*\(\s*([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*\)'
        r'(.*?)\bend\s*\)\s*\(\s*\{\s*((?:\d+\s*,\s*)*\d+)\s*\}\s*,\s*'
        r'\{\s*((?:\d+\s*,\s*)*\d+)\s*\}\s*\)',re.S)
    def repl(m):
        body=re.sub(r'\s+','',m.group(3)); c,d=m.group(1),m.group(2)
        if 'string.char' not in body:return m.group(0)

        if not re.search(re.escape(d)+r'\['+re.escape(c)+r'\[[A-Za-z_]\w*\]\+1\]',body):return m.group(0)
        try:
            codes=[int(x) for x in re.findall(r'\d+',m.group(4))]
            dictionary=[int(x) for x in re.findall(r'\d+',m.group(5))]
            if not codes or not dictionary or not all(0<=x<len(dictionary) for x in codes):return m.group(0)
            if not all(0<=x<=255 for x in dictionary):return m.group(0)
            raw=bytes(dictionary[x] for x in codes); text=raw.decode('utf-8')
            return _lua_quote(text) if _printable_ratio(text)>=0.70 else m.group(0)
        except Exception:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_bill_inline_base64(code: str) -> str:
    """Collapse Bill's inline standard-alphabet Base64 decoder when called with a literal."""
    pat=re.compile(
        r'\(\s*function\s*\(\s*([A-Za-z_]\w*)\s*\)(.*?)\bend\s*\)\s*\(\s*'
        r'((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*\)',re.S)
    alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    def repl(m):
        body=m.group(2)
        if alphabet not in body or 'string.char' not in body:return m.group(0)
        compact=re.sub(r'\s+','',body)
        if '#'+m.group(1) not in compact and ('#s' not in compact):return m.group(0)
        try:
            token=decode_lua_quoted_string(m.group(3))
            raw=base64.b64decode(token,validate=True); text=raw.decode('utf-8')
            return _lua_quote(text) if _printable_ratio(text)>=0.70 else m.group(0)
        except Exception:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_more_stdlib_constants(code: str) -> str:
    """Fold additional side-effect-free stdlib calls on literal values."""
    q=r'((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))'
    unary={
        'lower':str.lower,'upper':str.upper,
    }
    pat=re.compile(r'\bstring\.(lower|upper)\s*\(\s*'+q+r'\s*\)')
    def rs(m):
        try:return _lua_quote(unary[m.group(1)](decode_lua_quoted_string(m.group(2))))
        except Exception:return m.group(0)
    code=_sub_code(pat,rs,code)


    pg=re.compile(r'\bstring\.gsub\s*\(\s*'+q+r'\s*,\s*'+q+r'\s*,\s*'+q+r'\s*\)')
    def rg(m):
        try:
            src=decode_lua_quoted_string(m.group(1)); old=decode_lua_quoted_string(m.group(2)); new=decode_lua_quoted_string(m.group(3))
            if not old or re.search(r'[\^\$\(\)%.\[\]\*\+\-\?]',old) or '%' in new:return m.group(0)
            return _lua_quote(src.replace(old,new))
        except Exception:return m.group(0)
    code=_sub_code(pg,rg,code)


    pm=re.compile(r'\bmath\.(abs|floor|ceil|sqrt)\s*\(\s*(-?(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?))\s*\)')
    def rm(m):
        try:
            x=float(int(m.group(2),0)) if re.match(r'-?0x',m.group(2),re.I) else float(m.group(2))
            f={'abs':abs,'floor':math.floor,'ceil':math.ceil,'sqrt':math.sqrt}[m.group(1)]; v=f(x)
            return str(int(v)) if isinstance(v,(int,float)) and float(v).is_integer() else repr(v)
        except Exception:return m.group(0)
    code=_sub_code(pm,rm,code)
    pmm=re.compile(r'\bmath\.(min|max)\s*\(\s*((?:-?(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\s*,\s*)+-?(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?))\s*\)')
    def rmm(m):
        try:
            vals=[]
            for x in re.findall(r'-?(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)',m.group(2)):
                vals.append(float(int(x,0)) if re.match(r'-?0x',x,re.I) else float(x))
            v=(min if m.group(1)=='min' else max)(vals)
            return str(int(v)) if v.is_integer() else repr(v)
        except Exception:return m.group(0)
    return _sub_code(pmm,rmm,code)


def _decode_lua_long_string_token(token: str) -> Optional[str]:
    m=re.fullmatch(r'\[(=*)\[(.*)\]\1\]',token,re.S)
    if not m:return None
    body=m.group(2)

    if body.startswith('\r\n'):body=body[2:]
    elif body.startswith('\n') or body.startswith('\r'):body=body[1:]
    return body


def pass_unwrap_long_literal_loader(code: str) -> str:
    """Unwrap complete load/loadstring calls over Lua long-string literals."""
    m=re.fullmatch(r'\s*(?:return\s+)?(?:loadstring|load)\s*\(\s*(\[(=*)\[.*?\]\2\])\s*\)\s*\(\s*\)\s*;?\s*',code,re.S)
    if not m:return code
    inner=_decode_lua_long_string_token(m.group(1))
    return inner if inner is not None and _printable_ratio(inner)>=0.85 else code


def _clyde_base85_decode(blob: str, orig_len: Optional[int]=None) -> bytes:
    """Decode Clyde's current ASCII85 variant ("z" is a 4-byte zero block)."""
    s=re.sub(r'\s+','',blob).replace('z','!!!!!')
    if not s:return b''
    out=bytearray(); i=0
    while i<len(s):
        rem=min(5,len(s)-i); chunk=s[i:i+rem]
        if any(ord(c)<33 or ord(c)>117 for c in chunk):
            raise ValueError('invalid Clyde base85 character')
        v=0
        for c in chunk:v=v*85+(ord(c)-33)
        if rem<5:
            for _ in range(rem,5):v=v*85+84
        block=bytes(((v>>24)&255,(v>>16)&255,(v>>8)&255,v&255))
        out.extend(block if rem==5 else block[:max(0,rem-1)])
        i+=rem
    data=bytes(out)
    return data[:orig_len] if orig_len is not None else data


def _parse_const_num_expr(expr: str) -> Optional[int]:
    try:
        value=_safe_arith_eval(expr.strip())
        if isinstance(value,bool) or not isinstance(value,(int,float)):
            return None
        if isinstance(value,float) and not value.is_integer():
            return None
        return int(value)
    except Exception:
        return None


def _clyde_numeric_arrays(code: str) -> dict[str,list[int]]:
    """Recover local numeric arrays emitted by Clyde's splitArray helper."""
    arrays: dict[str,list[int]]={}
    for m in re.finditer(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*\{([^{}]*)\}',code,re.S):
        body=m.group(2).strip()
        if not body:continue
        parts=[x.strip() for x in body.split(',') if x.strip()]
        if not parts or len(parts)>1024:continue
        vals=[]
        for part in parts:

            if not re.fullmatch(r'[\s()0-9A-Fa-fxX+*/%.-]+',part):
                vals=[];break
            v=_parse_const_num_expr(part)
            if v is None or not 0<=v<=255:
                vals=[];break
            vals.append(v)
        if vals:arrays[m.group(1)]=vals



    appends: dict[tuple[str,str],list[tuple[int,str]]]=defaultdict(list)
    loop_re=re.compile(
        r'for\s+([A-Za-z_]\w*)\s*=\s*1\s*,\s*#([A-Za-z_]\w*)\s+do\s+'
        r'([A-Za-z_]\w*)\s*=\s*\3\s*\+\s*1\s+'
        r'([A-Za-z_]\w*)\s*\[\s*\3\s*\]\s*=\s*\2\s*\[\s*\1\s*\]\s+end',re.S)
    for m in loop_re.finditer(code):
        frag,counter,base=m.group(2),m.group(3),m.group(4)
        appends[(base,counter)].append((m.start(),frag))
    for (base,counter),items in appends.items():

        if not re.search(r'\blocal\s+'+re.escape(base)+r'\s*=\s*\{\s*\}',code):continue
        if not re.search(r'\blocal\s+'+re.escape(counter)+r'\s*=\s*0\b',code):continue
        vals=[];ok=True
        for _,frag in sorted(items):
            if frag not in arrays:ok=False;break
            vals.extend(arrays[frag])
        if ok and vals:arrays[base]=vals
    return arrays


def _extract_clyde_max_payload(code: str) -> Optional[str]:
    """Recover plaintext from Clyde's current maximum-protection Base85/S-box bootstrap.

    This targets the public `generateBootstrap` layout: split masked key/S-box arrays,
    ASCII85 blob, XOR masks, inverse S-box and Adler-32 verification. No Lua is run.
    """

    if '52200625' not in code or '614125' not in code or '7225' not in code:
        return None
    if not re.search(r'"Clyde Protection v2"|\'Clyde Protection v2\'',code):
        return None
    arrays=_clyde_numeric_arrays(code)
    if not arrays:return None

    atom=r'(\([^()\n]*\)|0x[0-9A-Fa-f]+|\d+)'

    sm=re.search(
        r'\blocal\s+([A-Za-z_]\w*)\s*=\s*\{\s*\}\s*'
        r'for\s+([A-Za-z_]\w*)\s*=\s*1\s*,\s*256\s+do\s*'
        r'\1\s*\[\s*\2\s*\]\s*=\s*([A-Za-z_]\w*)\s*\(\s*([A-Za-z_]\w*)\s*\[\s*\2\s*\]\s*,\s*'+atom+r'\s*\)\s*end',
        code,re.S)
    if not sm:return None
    sbox_raw_name=sm.group(4); sbox_mask=_parse_const_num_expr(sm.group(5))
    if sbox_raw_name not in arrays or sbox_mask is None:return None
    inv_sbox=[v^(sbox_mask&255) for v in arrays[sbox_raw_name]]
    if len(inv_sbox)!=256 or sorted(inv_sbox)!=list(range(256)):return None


    km=re.search(
        r'\blocal\s+([A-Za-z_]\w*)\s*=\s*#\s*([A-Za-z_]\w*)\s*'
        r'\blocal\s+([A-Za-z_]\w*)\s*=\s*\{\s*\}\s*'
        r'for\s+([A-Za-z_]\w*)\s*=\s*1\s*,\s*\1\s+do\s*'
        r'\3\s*\[\s*\4\s*\]\s*=\s*([A-Za-z_]\w*)\s*\(\s*\2\s*\[\s*\4\s*\]\s*,\s*'+atom+r'\s*\)\s*end',
        code,re.S)
    if not km:return None
    key_raw_name=km.group(2); key_mask=_parse_const_num_expr(km.group(6))
    if key_raw_name not in arrays or key_mask is None:return None
    key=[v^(key_mask&255) for v in arrays[key_raw_name]]
    if not 8<=len(key)<=128:return None


    dm=re.search(r'52200625.*?614125.*?7225.*?\breturn\b[^\n]*?,\s*1\s*,\s*(\d+)\s*\)',code,re.S)
    if not dm:return None
    orig_len=int(dm.group(1))
    if orig_len<=0 or orig_len>100_000_000:return None



    candidates=[]
    for lm in re.finditer(r'\[(=*)\[(.*?)\]\1\]',code,re.S):
        blob=lm.group(2)
        compact=re.sub(r'\s+','',blob)
        if len(compact)<20 or not re.fullmatch(r'[!-uz]+',compact):continue
        try:enc=_clyde_base85_decode(compact,orig_len)
        except Exception:continue
        if len(enc)>=orig_len:candidates.append((len(compact),enc))
    if not candidates:return None
    enc=max(candidates,key=lambda x:x[0])[1][:orig_len]

    out=bytearray();prev=0;klen=len(key)
    for i,e in enumerate(enc):
        sub=e ^ key[i%klen] ^ prev
        out.append(inv_sbox[sub])
        prev=e
    raw=bytes(out)



    cm=re.search(r'\bif\s+[A-Za-z_]\w*\s*\(\s*[A-Za-z_]\w*\s*\)\s*~=\s*(\d+)\s+then',code)
    if cm:
        expected=int(cm.group(1)) & 0xffffffff
        if (zlib.adler32(raw)&0xffffffff)!=expected:return None
    try:text=raw.decode('utf-8')
    except UnicodeDecodeError:return None
    if _printable_ratio(text)<0.75:return None
    return text


def pass_clyde_max_bootstrap(code: str) -> str:
    payload=_extract_clyde_max_payload(code)
    return payload if payload is not None else code


def pass_opaque_boolean_terms(code: str) -> str:
    """Simplify constant arithmetic predicates used as `CONST and/or real_condition`."""
    num=r'-?(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)'
    expr=r'(?P<expr>'+num+r'\s*[+\-*/%^]\s*'+num+r'\s*(?:==|~=|<=|>=|<|>)\s*'+num+r')'
    pat=re.compile(r'(?P<open>\(\s*)?'+expr+r'(?P<close>\s*\))?\s+(?P<op>and|or)\s+')
    def repl(m):

        if bool(m.group('open')) != bool(m.group('close')):return m.group(0)
        try:truth=bool(_safe_arith_eval(m.group('expr')))
        except Exception:return m.group(0)
        op=m.group('op')
        if (op=='and' and truth) or (op=='or' and not truth):return ''
        return ('true '+op+' ') if truth else ('false '+op+' ')
    return _sub_code(pat,repl,code)


def pass_fixed_xor_helpers(code: str) -> str:
    """Evaluate one-argument XOR string decoders with an embedded constant byte key."""
    helpers=[]

    for m in re.finditer(r'\blocal\s+function\s+([A-Za-z_]\w*)\s*\(\s*([A-Za-z_]\w*)\s*\)',code):
        name,data=m.group(1),m.group(2)
        end=_matching_lua_block_end(code,m.start()+m.group(0).find('function'))
        if not end:continue
        body=code[m.end():end-3]
        km=re.search(r'(?:bit32|bit)\.bxor\s*\(\s*string\.byte\s*\(\s*'+re.escape(data)+r'\s*(?:,\s*[^)]*)?\)\s*,\s*(0x[0-9A-Fa-f]+|\d+)\s*\)',body,re.S)
        if not km:

            km=re.search(r'string\.byte\s*\(\s*'+re.escape(data)+r'\s*(?:,\s*[^)]*)?\)\s*~\s*(0x[0-9A-Fa-f]+|\d+)',body,re.S)
        if km and ('string.char' in body or 'utf8.char' in body):
            try:helpers.append((name,int(km.group(1),0)&255))
            except Exception:pass
    for name,key in helpers:
        pat=re.compile(r'\b'+re.escape(name)+r'\s*\(\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*\)')
        def repl(m,key=key):
            try:
                raw=_bytes_from_lua_string(m.group(1)); dec=bytes(b^key for b in raw); t=dec.decode('utf-8')
                return _lua_quote(t) if _printable_ratio(t)>=0.75 else m.group(0)
            except Exception:return m.group(0)
        code=_sub_code(pat,repl,code)
    return code



def pass_byte_shift_helpers(code: str) -> str:
    """Evaluate simple one-argument byte Caesar/add/sub decoder helpers on literal calls."""
    helpers=[]
    for m in re.finditer(r'\blocal\s+function\s+([A-Za-z_]\w*)\s*\(\s*([A-Za-z_]\w*)\s*\)',code):
        name,data=m.group(1),m.group(2)
        end=_matching_lua_block_end(code,m.start()+m.group(0).find('function'))
        if not end:continue
        body=code[m.end():end-3]

        km=re.search(r'(?:string|utf8)\.char\s*\(\s*\(?\s*string\.byte\s*\(\s*'+re.escape(data)+r'\s*(?:,\s*[^)]*)?\)\s*([+-])\s*(0x[0-9A-Fa-f]+|\d+)\s*\)?\s*(?:%\s*256)?\s*\)',body,re.S)
        if km:
            try:
                delta=int(km.group(2),0); delta=delta if km.group(1)=='+' else -delta
                helpers.append((name,delta))
            except Exception:pass
    for name,delta in helpers:
        pat=re.compile(r'\b'+re.escape(name)+r'\s*\(\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*\)')
        def repl(m,delta=delta):
            try:
                raw=_bytes_from_lua_string(m.group(1)); dec=bytes((b+delta)&255 for b in raw); t=dec.decode('utf-8')
                return _lua_quote(t) if _printable_ratio(t)>=0.75 else m.group(0)
            except Exception:return m.group(0)
        code=_sub_code(pat,repl,code)
    return code


def pass_library_aliases(code: str) -> str:
    """Resolve immutable local aliases of stable Lua stdlib functions."""
    rx=re.compile(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*((?:string|table|math|bit32|bit|utf8|buffer)\.[A-Za-z_]\w*)\b(?!\s*\()\s*;?')

    for _ in range(64):
        found=None
        for m in rx.finditer(code):
            name,target=m.group(1),m.group(2)
            tail=code[m.end():]

            if re.search(re.escape(target)+r'\s*=',code):continue
            if not re.search(r'\b'+re.escape(name)+r'\s*=',tail):
                found=(m,name,target);break
        if not found:break
        m,name,target=found

        code=code[:m.start()]+code[m.end():]
        code=_replace_identifier_code(code,name,target)
    return code


def pass_string_byte_constants(code: str) -> str:
    """Fold string.byte/utf8.codepoint calls on literal strings for static indices."""
    q=r'((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))'
    pat=re.compile(r'\b(?:string\.byte|utf8\.codepoint)\s*\(\s*'+q+r'(?:\s*,\s*([^,()]+))?(?:\s*,\s*([^,()]+))?\s*\)')
    def repl(m):
        try:
            raw=_bytes_from_lua_string(m.group(1))
            i=1 if m.group(2) is None else int(_safe_arith_eval(m.group(2)))
            j=i if m.group(3) is None else int(_safe_arith_eval(m.group(3)))
            if i<0:i=len(raw)+i+1
            if j<0:j=len(raw)+j+1
            if not (1<=i<=len(raw) and 1<=j<=len(raw) and i<=j):return m.group(0)
            vals=list(raw[i-1:j])

            return str(vals[0]) if len(vals)==1 else m.group(0)
        except Exception:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_string_rep_constants(code: str) -> str:
    q=r'((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))'
    pat=re.compile(r'\bstring\.rep\s*\(\s*'+q+r'\s*,\s*([^,()]+)(?:\s*,\s*'+q+r')?\s*\)')
    def repl(m):
        try:
            text=decode_lua_quoted_string(m.group(1)); n=int(_safe_arith_eval(m.group(2)))
            if n<0 or n>100000:return m.group(0)
            sep=decode_lua_quoted_string(m.group(3)) if m.group(3) else ''
            out=sep.join([text]*n)
            return _lua_quote(out) if len(out)<=200000 else m.group(0)
        except Exception:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_byte_array_strings(code: str) -> str:
    """Recover strings from constant byte arrays used with string.char(unpack/table.unpack)."""
    arrays={}
    rx=re.compile(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*\{\s*((?:0x[0-9A-Fa-f]+|\d+)\s*(?:,\s*(?:0x[0-9A-Fa-f]+|\d+)\s*){2,})\}')
    for m in rx.finditer(code):
        try:
            vals=[int(x,0) for x in re.findall(r'0x[0-9A-Fa-f]+|\d+',m.group(2))]
            if vals and all(0<=v<=255 for v in vals):arrays[m.group(1)]=bytes(vals)
        except Exception:pass
    for name,data in arrays.items():
        try:t=data.decode('utf-8')
        except Exception:continue
        if _printable_ratio(t)<0.70:continue
        pats=[
            re.compile(r'\b(?:string|utf8)\.char\s*\(\s*(?:table\.)?unpack\s*\(\s*'+re.escape(name)+r'\s*\)\s*\)'),
            re.compile(r'\b(?:string|utf8)\.char\s*\(\s*unpack\s*\(\s*'+re.escape(name)+r'\s*\)\s*\)'),
        ]
        for pat in pats:code=_sub_code(pat,lambda m,t=t:_lua_quote(t),code)
    return code


def pass_utf8_char_constants(code: str) -> str:
    pat=re.compile(r'\butf8\.char\s*\(\s*([^()]{1,1000})\s*\)')
    def repl(m):
        parts=[x.strip() for x in m.group(1).split(',')]
        if not parts:return m.group(0)
        vals=[]
        try:
            for x in parts:
                v=_safe_arith_eval(x)
                if isinstance(v,bool) or not isinstance(v,(int,float)) or int(v)!=v:return m.group(0)
                v=int(v)
                if not (0<=v<=0x10ffff) or 0xD800<=v<=0xDFFF:return m.group(0)
                vals.append(v)
            return _lua_quote(''.join(chr(v) for v in vals))
        except Exception:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_load_local_literal(code: str) -> str:
    """Unwrap `local x='source'; load/loadstring(x)()` when x is immutable and used only there."""
    rx=re.compile(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*;?')
    for m in list(rx.finditer(code)):
        name=m.group(1)

        tail=code[m.end():]
        if re.search(r'\b'+re.escape(name)+r'\s*=',tail):continue
        calls=list(re.finditer(r'\b(?:loadstring|load)\s*\(\s*'+re.escape(name)+r'\s*\)\s*\(\s*\)',tail))
        occurrences=len(re.findall(r'\b'+re.escape(name)+r'\b',tail))
        if len(calls)!=1 or occurrences!=1:continue
        try:payload=decode_lua_quoted_string(m.group(2))
        except Exception:continue
        if not re.search(r'\b(?:local|function|return|if|for|while|print|require)\b',payload):continue
        call=calls[0]; a=m.start(); b=m.end()+call.end()

        between=tail[:call.start()]
        if re.fullmatch(r'[\s;]*',between):
            code=code[:a]+payload+'\n'+code[b:]
            break
    return code


def _top_level_branch_slices(body: str, state: str) -> Optional[dict[int,str]]:
    """Parse a simple top-level if/elseif chain used by flattened state machines."""

    spans=_lua_protected_spans(body)
    def protected(pos):

        return any(a<=pos<b for a,b in spans)
    starts=[]
    pat=re.compile(r'\b(if|elseif)\s+'+re.escape(state)+r'\s*==\s*(-?\d+)\s+then\b')
    for m in pat.finditer(body):
        if protected(m.start()):continue

        prefix=body[:m.start()]
        depth=0
        for kw,_,_ in _lua_keyword_tokens(prefix):
            if kw in ('if','function','for','while','do','repeat'):depth+=1
            elif kw in ('end','until'):depth=max(0,depth-1)
        if (m.group(1)=='if' and not starts) or (m.group(1)=='elseif' and starts):
            starts.append((m,int(m.group(2))))
    if not starts:return None

    first=starts[0][0]
    if body[:first.start()].strip():return None
    outer_end=_matching_lua_block_end(body,first.start())
    if not outer_end:return None
    tail=body[outer_end:]
    if tail.strip():return None
    branches={}
    for idx,(m,val) in enumerate(starts):
        a=m.end(); b=(starts[idx+1][0].start() if idx+1<len(starts) else outer_end-3)
        chunk=body[a:b]

        if re.search(r'\belse\b',chunk):return None
        branches[val]=chunk.strip()
    return branches


def pass_simple_state_machine(code: str) -> str:
    """Linearize a conservative `local state=N; while true do if state==...` flattening chain."""
    head=re.search(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*(-?\d+)\s*;?\s*\bwhile\s+(?:true|1\s*==\s*1)\s+do\b',code,re.I)
    if not head:return code
    state=head.group(1); start=int(head.group(2))
    while_pos=code.rfind('while',head.start(),head.end())
    while_end=_matching_lua_block_end(code,while_pos)
    if not while_end:return code
    inner=code[head.end():while_end-3].strip()
    branches=_top_level_branch_slices(inner,state)
    if not branches or start not in branches:return code
    order=[]; seen=set(); cur=start
    terminal=False
    while cur in branches and cur not in seen and len(order)<=len(branches):
        seen.add(cur); chunk=branches[cur]

        assigns=list(re.finditer(r'\b'+re.escape(state)+r'\s*=\s*(-?\d+)\s*;?',chunk))
        state_refs=[m for m in re.finditer(r'\b'+re.escape(state)+r'\b',chunk)]

        if len(assigns)>1:return code
        cleaned=chunk
        if assigns:
            a=assigns[-1]
            if any(r.start()!=a.start() for r in state_refs):return code

            after=chunk[a.end():]
            if not re.fullmatch(r'[\s;]*(?:break\s*;?)?[\s;]*',after):return code
            nxt=int(a.group(1)); cleaned=(chunk[:a.start()]+' '+re.sub(r'\bbreak\b\s*;?','',after)).strip(); cur=nxt
        else:
            if state_refs:return code
            cleaned=re.sub(r'\bbreak\b\s*;?\s*$','',cleaned).strip()
            if re.search(r'\b(?:break|return)\b',chunk):terminal=True
            else:terminal=True
            cur=10**18
        order.append(cleaned)
    if not terminal and cur in branches:return code
    if len(order)<2:return code

    if cur in seen:return code
    replacement='\n'.join(x for x in order if x).strip()+'\n'
    return code[:head.start()]+replacement+code[while_end:]






def _lua_quote_bytes(data: bytes) -> str:
    """Encode arbitrary bytes as a Lua short string without losing binary data."""
    out=['"']
    for b in data:
        if b == 0x22:
            out.append('\\"')
        elif b == 0x5C:
            out.append('\\\\')
        elif b == 10:
            out.append('\\n')
        elif b == 13:
            out.append('\\r')
        elif b == 9:
            out.append('\\t')
        elif 32 <= b <= 126:
            out.append(chr(b))
        else:


            out.append('\\%03d' % b)
    out.append('"')
    return ''.join(out)


def _decoded_bytes_score(data: bytes) -> float:
    if not data:
        return 0.0
    printable=sum((32 <= b <= 126) or b in (9,10,13) for b in data) / len(data)
    low=data.lower()
    bonus=0.0
    for tok in (b'local ', b'function', b'return ', b'print(', b'http', b'game', b'require', b'getgenv'):
        if tok in low: bonus += 0.08
    return printable + min(bonus,0.32)


def _simple_lua_args(text: str) -> Optional[list[str]]:
    """Split a simple Lua argument list while respecting strings/brackets."""
    args=[]; start=0; stack=[]; q=None; esc=False
    pairs={')':'(',']':'[','}':'{'}
    for i,ch in enumerate(text):
        if q:
            if esc: esc=False
            elif ch=='\\': esc=True
            elif ch==q: q=None
            continue
        if ch in "\"'": q=ch; continue
        if ch in '([{': stack.append(ch); continue
        if ch in ')]}':
            if not stack or stack[-1] != pairs[ch]: return None
            stack.pop(); continue
        if ch==',' and not stack:
            args.append(text[start:i].strip()); start=i+1
    if q or stack:return None
    args.append(text[start:].strip())
    return args if not (len(args)==1 and not args[0]) else []


def _decode_base91(data: str) -> Optional[bytes]:
    alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&()*+,./:;<=>?@[]^_`{|}~"'
    table={c:i for i,c in enumerate(alphabet)}
    b=0; n=0; v=-1; out=bytearray()
    try:
        for ch in data:
            if ch not in table: continue
            c=table[ch]
            if v < 0: v=c
            else:
                v += c*91
                b |= v << n
                n += 13 if (v & 8191) > 88 else 14
                while n >= 8:
                    out.append(b & 255); b >>= 8; n -= 8
                v=-1
        if v >= 0:
            b |= v << n; n += 7
            while n >= 8:
                out.append(b & 255); b >>= 8; n -= 8
        return bytes(out)
    except Exception:
        return None


def _decode_base58(data: str) -> Optional[bytes]:
    alphabet='123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
    try:
        n=0
        for ch in data:
            n=n*58+alphabet.index(ch)
        raw=(n.to_bytes((n.bit_length()+7)//8,'big') if n else b'')
        return b'\0'*(len(data)-len(data.lstrip('1'))) + raw
    except Exception:
        return None


def _literal_wrapper_decoder(code: str, names: str, decoder: Callable[[str], Optional[bytes]], *, min_score: float=.68) -> str:
    q=r'((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))'
    pat=re.compile(r'\b(?:'+names+r')\s*\(\s*'+q+r'\s*\)',re.I)
    def repl(m):
        try:
            src=decode_lua_quoted_string(m.group(1))
            raw=decoder(src)
            if raw is None or _decoded_bytes_score(raw) < min_score:return m.group(0)
            return _lua_quote_bytes(raw)
        except Exception:return m.group(0)
    return _sub_code(pat,repl,code)


def pass_base32_literals(code: str) -> str:
    def dec(s):
        try:return base64.b32decode(re.sub(r'\s+','',s).upper() + '='*((-len(re.sub(r'\s+','',s)))%8),casefold=True)
        except Exception:return None
    return _literal_wrapper_decoder(code,r'(?:base32decode|b32decode|decode_base32|decode32)',dec)


def pass_base85_literals(code: str) -> str:
    def dec(s):
        b=s.encode('ascii','strict')
        for fn in (base64.b85decode,base64.a85decode):
            try:return fn(b)
            except Exception:pass
        return None
    return _literal_wrapper_decoder(code,r'(?:base85decode|b85decode|ascii85decode|a85decode|decode_base85)',dec)


def pass_base58_literals(code: str) -> str:
    return _literal_wrapper_decoder(code,r'(?:base58decode|b58decode|decode_base58)',_decode_base58)


def pass_base91_literals(code: str) -> str:
    return _literal_wrapper_decoder(code,r'(?:base91decode|b91decode|decode_base91)',_decode_base91)


def pass_url_percent_literals(code: str) -> str:
    def dec(s):
        try:return unquote_to_bytes(s)
        except Exception:return None
    return _literal_wrapper_decoder(code,r'(?:urldecode|url_decode|percentdecode|percent_decode|decode_uri_component)',dec,min_score=.55)


def pass_rot_literals(code: str) -> str:
    q=r'((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))'
    p13=re.compile(r'\b(?:rot13|decode_rot13)\s*\(\s*'+q+r'\s*\)',re.I)
    p47=re.compile(r'\b(?:rot47|decode_rot47)\s*\(\s*'+q+r'\s*\)',re.I)
    def r13(m):
        try:return _lua_quote(codecs.decode(decode_lua_quoted_string(m.group(1)),'rot_13'))
        except Exception:return m.group(0)
    def r47(m):
        try:
            src=decode_lua_quoted_string(m.group(1)); out=''.join(chr(33+((ord(c)-33+47)%94)) if 33<=ord(c)<=126 else c for c in src)
            return _lua_quote(out)
        except Exception:return m.group(0)
    return _sub_code(p47,r47,_sub_code(p13,r13,code))


def _discover_repeating_xor_helpers(code: str) -> list[tuple[str,int]]:
    found=[]
    heads=[]



    xor_aliases=set(re.findall(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*(?:[A-Za-z_]\w*\.)?bxor\b',code))
    char_aliases=set(re.findall(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*string\.char\b',code))
    byte_aliases=set(re.findall(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*string\.byte\b',code))
    sub_aliases=set(re.findall(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*string\.sub\b',code))
    for rx in (
        re.compile(r'\blocal\s+function\s+([A-Za-z_]\w*)\s*\(\s*([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*\)'),
        re.compile(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*function\s*\(\s*([A-Za-z_]\w*)\s*,\s*([A-Za-z_]\w*)\s*\)'),
    ):
        heads.extend(rx.finditer(code))
    for m in heads:
        name,data,key=m.group(1),m.group(2),m.group(3)
        fpos=code.find('function',m.start(),m.end())
        end=_matching_lua_block_end(code,fpos)
        if not end:continue
        body=code[m.end():end]
        has_xor=bool(re.search(r'\bbxor\b',body) or any(re.search(r'\b'+re.escape(a)+r'\s*\(',body) for a in xor_aliases))
        has_char=bool('string.char' in body or any(re.search(r'\b'+re.escape(a)+r'\s*\(',body) for a in char_aliases))
        has_byte=bool(('string.byte' in body or 'string.sub' in body) or any(re.search(r'\b'+re.escape(a)+r'\s*\(',body) for a in (byte_aliases|sub_aliases)))
        if not (has_xor and has_char and has_byte):continue
        if not re.search(r'%\s*#\s*'+re.escape(key)+r'\b',body):continue

        shift=1 if re.search(r'1\s*\+\s*\(\s*[A-Za-z_]\w*\s*%\s*#\s*'+re.escape(key),body) else 0
        found.append((name,shift))

    return list(dict.fromkeys(found))


def pass_repeating_xor_helpers(code: str) -> str:
    q=r'((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))'
    for name,preferred_shift in _discover_repeating_xor_helpers(code):
        pat=re.compile(r'\b'+re.escape(name)+r'\s*\(\s*'+q+r'\s*,\s*'+q+r'\s*\)')
        def repl(m,preferred_shift=preferred_shift):
            try:
                data=_bytes_from_lua_string(m.group(1)); key=_bytes_from_lua_string(m.group(2))
                if not key:return m.group(0)
                candidates=[]
                for shift in (preferred_shift,1-preferred_shift):
                    raw=bytes(b ^ key[(i+shift)%len(key)] for i,b in enumerate(data))
                    candidates.append((_decoded_bytes_score(raw),raw))
                score,raw=max(candidates,key=lambda x:x[0])
                return _lua_quote_bytes(raw) if score>=.70 else m.group(0)
            except Exception:return m.group(0)
        code=_sub_code(pat,repl,code)
    return code


def _custom_b64_decode(data: str, alphabet: str) -> Optional[bytes]:
    if len(alphabet)!=64 or len(set(alphabet))!=64:return None
    std='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    trans=str.maketrans(alphabet,std)
    try:
        x=''.join(ch for ch in data if ch in alphabet or ch=='=').translate(trans)
        x += '='*((-len(x))%4)
        return base64.b64decode(x,validate=False)
    except Exception:return None


def pass_custom_base64_helpers(code: str) -> str:
    """Evaluate local custom-alphabet Base64 helpers on literal inputs."""
    helpers=[]
    head=re.compile(r'\blocal\s+function\s+([A-Za-z_]\w*)\s*\(\s*([A-Za-z_]\w*)\s*\)')
    qrx=re.compile(r'(["\'])(.{64})\1',re.S)
    for m in head.finditer(code):
        end=_matching_lua_block_end(code,m.start())
        if not end:continue
        body=code[m.end():end]
        if not ('string.char' in body or 'char(' in body):continue
        if 'gsub' not in body:continue
        if not (':find' in body or 'string.find' in body):continue
        if not (re.search(r'2\s*\^',body) or re.search(r'%\s*[48]\b',body) or re.search(r'\b6\b',body)):continue
        for qm in qrx.finditer(body):
            alphabet=qm.group(2)
            if len(set(alphabet))==64 and '\n' not in alphabet and '\r' not in alphabet:
                helpers.append((m.group(1),alphabet));break
    q=r'((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))'
    for name,alphabet in helpers:
        pat=re.compile(r'\b'+re.escape(name)+r'\s*\(\s*'+q+r'\s*\)')
        def repl(mm,alphabet=alphabet):
            try:
                raw=_custom_b64_decode(decode_lua_quoted_string(mm.group(1)),alphabet)
                return _lua_quote_bytes(raw) if raw is not None and _decoded_bytes_score(raw)>=.68 else mm.group(0)
            except Exception:return mm.group(0)
        code=_sub_code(pat,repl,code)
    return code


def _synapse_xen_unpack(raw: bytes) -> Optional[bytes]:
    """Decode the public Synapse Xen u/c payload framing (raw or 16-bit LZW)."""
    if not raw:return None
    mode=raw[:1]; payload=raw[1:]
    if mode==b'u':return payload
    if mode!=b'c' or len(payload)<2:return None
    if len(payload)%2:payload=payload[:-1]
    codes=[payload[i] | (payload[i+1]<<8) for i in range(0,len(payload),2)]
    if not codes:return b''
    table={i:bytes((i,)) for i in range(256)}; next_code=256
    if codes[0] not in table:return None
    prev=table[codes[0]]; out=bytearray(prev)
    try:
        for k in codes[1:]:
            if k in table:entry=table[k]
            elif k==next_code:entry=prev+prev[:1]
            else:return None
            out.extend(entry)
            if next_code < 65536:
                table[next_code]=prev+entry[:1]; next_code+=1
            prev=entry
        return bytes(out)
    except Exception:return None


def _synapse_xen_decode_b64(s: str) -> Optional[bytes]:
    try:
        raw=base64.b64decode(re.sub(r'\s+','',s)+'='*((-len(re.sub(r'\s+','',s)))%4),validate=False)
    except Exception:return None
    return _synapse_xen_unpack(raw)


def pass_synapse_xen_payloads(code: str) -> str:
    if not (re.search(r'synapse\s*xen|synapsexen_',code,re.I)):
        return code
    q=re.compile(r'(["\'])([A-Za-z0-9+/]{12,}={0,2})\1')
    best=None
    for m in q.finditer(code):
        raw=_synapse_xen_decode_b64(m.group(2))
        if raw is None:continue
        score=_decoded_bytes_score(raw)
        if score>=.72 and (best is None or len(raw)>len(best[2])):best=(m.start(),m.end(),raw)
    if not best:return code
    a,b,raw=best


    return code[:a]+_lua_quote_bytes(raw)+code[b:]


def _pack_lua_constants(fmt: str, args: list[str]) -> Optional[bytes]:
    endian='='; i=0; ai=0; out=bytearray()
    def get_num():
        nonlocal ai
        if ai>=len(args):raise ValueError
        v=_safe_arith_eval(args[ai]); ai+=1
        if isinstance(v,bool) or not isinstance(v,(int,float)):raise ValueError
        return v
    def get_bytes():
        nonlocal ai
        if ai>=len(args):raise ValueError
        t=args[ai].strip(); ai+=1
        if len(t)<2 or t[0] not in "\"'" or t[-1]!=t[0]:raise ValueError
        return _bytes_from_lua_string(t)
    while i<len(fmt):
        c=fmt[i]
        if c.isspace():i+=1;continue
        if c in '<>=':endian=c;i+=1;continue
        if c=='!':
            i+=1
            while i<len(fmt) and fmt[i].isdigit():i+=1
            continue
        if c=='x':out.append(0);i+=1;continue
        if c in 'bB':
            v=int(get_num());out += int(v).to_bytes(1,'little',signed=(c=='b'));i+=1;continue
        if c in 'hH':
            v=int(get_num());out += int(v).to_bytes(2,'little' if endian!='>' else 'big',signed=(c=='h'));i+=1;continue
        if c in 'iI':
            signed=(c=='i');i+=1;j=i
            while j<len(fmt) and fmt[j].isdigit():j+=1
            n=int(fmt[i:j] or '4');i=j
            if n<1 or n>16:raise ValueError
            v=int(get_num());out += v.to_bytes(n,'little' if endian!='>' else 'big',signed=signed);continue
        if c in 'fdn':
            v=float(get_num()); spec={'f':'f','d':'d','n':'d'}[c]
            out += struct.pack(('>' if endian=='>' else '<')+spec,v);i+=1;continue
        if c in 'cs':
            kind=c;i+=1;j=i
            while j<len(fmt) and fmt[j].isdigit():j+=1
            if j==i:raise ValueError
            n=int(fmt[i:j]);i=j; raw=get_bytes()
            if kind=='c':out += raw[:n].ljust(n,b'\0')
            else:out += len(raw).to_bytes(n,'little' if endian!='>' else 'big')+raw
            continue
        if c=='z':out += get_bytes()+b'\0';i+=1;continue

        raise ValueError
    if ai != len(args):raise ValueError
    return bytes(out)


def pass_string_pack_constants(code: str) -> str:
    pat=re.compile(r'\bstring\.pack\s*\(\s*((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))\s*(?:,\s*([^()]*?))?\)')
    def repl(m):
        try:
            fmt=decode_lua_quoted_string(m.group(1)); args=_simple_lua_args(m.group(2) or '')
            if args is None:return m.group(0)
            raw=_pack_lua_constants(fmt,args)
            return _lua_quote_bytes(raw) if raw is not None else m.group(0)
        except Exception:return m.group(0)
    return _sub_code(pat,repl,code)


def _apply_buffer_write(buf: bytearray, opname: str, args: list[str]) -> bool:
    try:
        if len(args)<3:return False
        off=int(_safe_arith_eval(args[1])); val=args[2].strip()
        if off<0:return False
        formats={'writei8':'b','writeu8':'B','writei16':'h','writeu16':'H','writei32':'i','writeu32':'I','writef32':'f','writef64':'d'}
        if opname in formats:
            v=_safe_arith_eval(val); raw=struct.pack('<'+formats[opname],v)
            if off+len(raw)>len(buf):return False
            buf[off:off+len(raw)]=raw;return True
        if opname=='writestring':
            if len(val)<2 or val[0] not in "\"'" or val[-1]!=val[0]:return False
            raw=_bytes_from_lua_string(val)
            count=int(_safe_arith_eval(args[3])) if len(args)>=4 and args[3].strip() else len(raw)
            raw=raw[:count]
            if off+len(raw)>len(buf):return False
            buf[off:off+len(raw)]=raw;return True
        if opname=='fill':
            v=int(_safe_arith_eval(val))&255
            count=int(_safe_arith_eval(args[3])) if len(args)>=4 and args[3].strip() else len(buf)-off
            if count<0 or off+count>len(buf):return False
            buf[off:off+count]=bytes((v,))*count;return True
    except Exception:return False
    return False


def pass_luau_buffer_constants(code: str) -> str:
    """Fold straight-line Luau buffer.create/write*/tostring sequences."""
    creates=list(re.finditer(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*buffer\.create\s*\(\s*([^()]+)\s*\)',code))
    for cm in reversed(creates):
        name=cm.group(1)
        try:size=int(_safe_arith_eval(cm.group(2)))
        except Exception:continue
        if size<0 or size>4*1024*1024:continue
        tostring=list(re.finditer(r'\bbuffer\.tostring\s*\(\s*'+re.escape(name)+r'\s*\)',code[cm.end():]))
        if not tostring:continue


        tm=tostring[0]; ta=cm.end()+tm.start(); tb=cm.end()+tm.end()
        region=code[cm.end():ta]
        if re.search(r'\b(?:if|for|while|repeat|function)\b',region):continue
        buf=bytearray(size); ok=True
        wrx=re.compile(r'\bbuffer\.(writei8|writeu8|writei16|writeu16|writei32|writeu32|writef32|writef64|writestring|fill)\s*\(([^()]*)\)')
        supported_spans=[]
        for wm in wrx.finditer(region):
            args=_simple_lua_args(wm.group(2))
            if args is None or not args or args[0].strip()!=name or not _apply_buffer_write(buf,wm.group(1),args):ok=False;break
            supported_spans.append(wm.span())

        if re.search(r'\bbuffer\.write[A-Za-z0-9_]*\s*\(\s*'+re.escape(name)+r'\s*,',region) and not supported_spans:
            ok=False
        if ok:
            code=code[:ta]+_lua_quote_bytes(bytes(buf))+code[tb:]
    return code


def pass_gsub_literal_maps(code: str) -> str:
    """Fold literal:gsub('.', {['a']='x', ...}) substitution tables."""
    q=r'((?:"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'))'
    pat=re.compile(q+r'\s*:\s*gsub\s*\(\s*(["\'])\.\2\s*,\s*\{([^{}]{1,12000})\}\s*\)')
    pair=re.compile(r'\[?\s*'+q+r'\s*\]?\s*=\s*'+q)
    def repl(m):
        try:
            mapping={}
            for pm in pair.finditer(m.group(3)):
                k=decode_lua_quoted_string(pm.group(1));v=decode_lua_quoted_string(pm.group(2))
                if len(k)==1:mapping[k]=v
            if not mapping:return m.group(0)
            src=decode_lua_quoted_string(m.group(1));out=''.join(mapping.get(c,c) for c in src)
            return _lua_quote(out)
        except Exception:return m.group(0)
    return _sub_code(pat,repl,code)


def _try_static_decompressions(raw: bytes) -> list[bytes]:
    variants=[raw]
    for wb in (zlib.MAX_WBITS,-zlib.MAX_WBITS,16+zlib.MAX_WBITS):
        try:
            d=zlib.decompress(raw,wb)
            if d not in variants:variants.insert(0,d)
        except Exception:pass
    for fn in (bz2.decompress,lzma.decompress):
        try:
            d=fn(raw)
            if d not in variants:variants.insert(0,d)
        except Exception:pass
    return variants


def _lua_source_from_bytes(raw: bytes) -> Optional[str]:
    for data in _try_static_decompressions(raw):
        try:t=data.decode('utf-8')
        except Exception:continue
        if len(t)>=6 and _printable_ratio(t)>=.88 and re.search(r'\b(?:local|function|return|if|for|while|repeat|print|require|game|loadstring)\b',t):
            return t
    return None


def pass_long_hex_compressed_payloads(code: str) -> str:
    """Decode long hex literals only when they yield convincing Lua source."""
    pat=re.compile(r'(["\'])([0-9A-Fa-f]{32,})\1')
    def repl(m):
        try:
            if len(m.group(2))%2:return m.group(0)
            t=_lua_source_from_bytes(bytes.fromhex(m.group(2)))
            return _lua_quote(t) if t is not None else m.group(0)
        except Exception:return m.group(0)
    return pat.sub(repl,code)


def _canonical_simple_lua_value(token: str) -> Optional[str]:
    token=token.strip()
    if len(token)>=2 and token[0] in "\"'" and token[-1]==token[0]:
        try:return _lua_quote(decode_lua_quoted_string(token))
        except Exception:return None
    if re.fullmatch(r'(?:true|false|nil)',token,re.I):return token.lower()
    if re.fullmatch(r'[\s()0-9A-Fa-fxXbB_+*/%^.-]+',token):
        try:

            norm=re.sub(r'\b0[bB][01_]+\b',lambda m:str(int(m.group(0).replace('_',''),2)),token)
            v=_safe_arith_eval(norm)
            if isinstance(v,bool):return 'true' if v else 'false'
            if isinstance(v,(int,float)):
                return str(int(v)) if float(v).is_integer() else repr(float(v))
        except Exception:pass
    return None


def pass_mixed_constant_tables(code: str) -> str:
    """Inline immutable sequential tables containing only literal/static values."""
    tables={}
    rx=re.compile(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*\{([^{}]{1,50000})\}',re.S)
    for m in rx.finditer(code):
        name=m.group(1); parts=_simple_lua_args(m.group(2))
        if not parts or len(parts)<2 or len(parts)>4096:continue
        if any(re.search(r'(?<![<>=~])=(?!=)',x) for x in parts):continue
        vals=[]
        for part in parts:
            v=_canonical_simple_lua_value(part)
            if v is None:vals=[];break
            vals.append(v)
        if not vals:continue
        tail=code[m.end():]
        if re.search(r'\b'+re.escape(name)+r'\s*\[[^\]]+\]\s*=',tail):continue
        tables[name]=vals
    for name,vals in tables.items():
        pat=re.compile(r'\b'+re.escape(name)+r'\s*\[\s*([^\[\]]{1,100})\s*\]')
        def repl(m,vals=vals):
            try:
                idx=_safe_arith_eval(m.group(1))
                if isinstance(idx,bool) or int(idx)!=idx:return m.group(0)
                idx=int(idx)
                return vals[idx-1] if 1<=idx<=len(vals) else m.group(0)
            except Exception:return m.group(0)
        code=_sub_code(pat,repl,code)
    return code


def pass_constant_table_accessors(code: str) -> str:
    """Replace tiny `return T[index + constant]` accessor calls over immutable tables."""


    table_defs={}
    rx=re.compile(r'\blocal\s+([A-Za-z_]\w*)\s*=\s*\{([^{}]{1,50000})\}',re.S)
    for m in rx.finditer(code):
        name=m.group(1); parts=_simple_lua_args(m.group(2))
        if not parts or len(parts)<2:continue
        vals=[]
        for part in parts:
            v=_canonical_simple_lua_value(part)
            if v is None:vals=[];break
            vals.append(v)
        if not vals:continue
        if re.search(r'\b'+re.escape(name)+r'\s*\[[^\]]+\]\s*=',code[m.end():]):continue
        table_defs[name]=vals
    hrx=re.compile(r'\blocal\s+function\s+([A-Za-z_]\w*)\s*\(\s*([A-Za-z_]\w*)\s*\)\s*return\s+([A-Za-z_]\w*)\s*\[\s*([^\]]+)\s*\]\s*end')
    for hm in hrx.finditer(code):
        fn,arg,tname,expr=hm.group(1),hm.group(2),hm.group(3),hm.group(4)
        vals=table_defs.get(tname)
        if not vals:continue

        mm=re.fullmatch(r'\s*'+re.escape(arg)+r'\s*([+-])\s*(.+?)\s*',expr)
        if mm:
            try:delta=_safe_arith_eval(mm.group(2)); delta=delta if mm.group(1)=='+' else -delta
            except Exception:continue
        elif re.fullmatch(r'\s*'+re.escape(arg)+r'\s*',expr):delta=0
        else:continue
        call=re.compile(r'\b'+re.escape(fn)+r'\s*\(\s*([^()]{1,100})\s*\)')
        def repl(cm,vals=vals,delta=delta):
            try:
                n=_safe_arith_eval(cm.group(1)); idx=int(n+delta)
                if idx!=(n+delta):return cm.group(0)
                return vals[idx-1] if 1<=idx<=len(vals) else cm.group(0)
            except Exception:return cm.group(0)
        code=_sub_code(call,repl,code)
    return code

def _extract_lua_bytecode_literals(code: str) -> list[bytes]:
    """Find quoted literals whose decoded bytes begin with a Lua binary signature."""
    out=[]
    q=re.compile(r'("(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')')
    for m in q.finditer(code):
        try:b=_bytes_from_lua_string(m.group(1))
        except Exception:continue
        if b.startswith(b'\x1bLua') and b not in out:out.append(b)
        if len(out)>=8:break
    return out


def extract_embedded_payloads(source_or_path) -> list[dict[str,Any]]:
    """Recover statically packed payloads without executing the input.

    Each result contains `family`, `kind`, and `data` (bytes or str).
    """
    code,_=_read_input(source_or_path); out=[]
    luarmor=extract_luarmor_v4_bootstrap(code)
    if luarmor is not None:
        out.append({'family':'Luarmor V4','kind':'bootstrap-metadata','data':json.dumps(luarmor,indent=2)})
        found=_find_lua_table_assignment(code,'_bsdata0')
        if found:
            try:
                vals=_LuaConstantParser(found[0]).table()
            except Exception:
                vals=[]
            def walk(seq, path=''):
                for i,v in enumerate(seq,1):
                    pth=f'{path}.{i}' if path else str(i)
                    if isinstance(v,list):
                        yield from walk(v,pth)
                    elif isinstance(v,str):
                        raw=bytes((ord(c)&255) for c in v)
                        if len(v)>=32 and len(v)%2==0 and re.fullmatch(r'[0-9A-Fa-f]+',v):
                            try:
                                yield {'family':'Luarmor V4','kind':f'bsdata-{pth}-hex','data':bytes.fromhex(v)}
                            except Exception:
                                pass
                        elif len(raw)>=8 and any(b<32 or b>=127 for b in raw):
                            yield {'family':'Luarmor V4','kind':f'bsdata-{pth}-binary','data':raw}
                        elif len(v)>=24 and len(set(v))==16:
                            yield {'family':'Luarmor V4','kind':f'bsdata-{pth}-16symbol','data':v}
            out.extend(walk(vals))
    b=_extract_hercules_shifted_bytecode(code)
    if b is not None:out.append({'family':'Hercules','kind':'lua-bytecode','data':b})
    clyde=_extract_clyde_max_payload(code)
    if clyde is not None:out.append({'family':'Clyde','kind':'decoded-source','data':clyde})
    if _looks_like_aztup_lzw(code):
        for m in re.finditer(r'(["\'])([0-9A-Za-z]{80,})\1',code):
            d=_decode_aztup_lzw_payload(m.group(2))
            if d:out.append({'family':'AztupBrew','kind':'decoded-payload','data':d});break
    if re.search(r'gBits(?:8|16|32)|VMCall\s*\(',code):
        for m in re.finditer(r'(["\'])([0-9A-Fa-fOo]{80,})\1',code):
            d=_decode_ironbrew_hexrle_payload(m.group(2))
            if d:out.append({'family':'IronBrew','kind':'decoded-payload','data':d});break


    if re.search(r'synapse\s*xen|synapsexen_',code,re.I):
        for m in re.finditer(r'(["\'])([A-Za-z0-9+/]{12,}={0,2})\1',code):
            d=_synapse_xen_decode_b64(m.group(2))
            if d is not None:
                kind='decoded-source' if _decoded_bytes_score(d)>=.72 else 'decoded-payload'
                out.append({'family':'Synapse Xen','kind':kind,'data':d.decode('utf-8','replace') if kind=='decoded-source' else d})
                break

    for m in re.finditer(r'(["\'])([A-Za-z0-9+/]{24,}={0,2})\1',code):
        t=_decode_b64_zlib_text(m.group(2))
        if t is not None:
            out.append({'family':'Luraph/Base64 loader','kind':'decoded-source','data':t})
            if len(out)>=8:break
    for b in _extract_lua_bytecode_literals(code):
        out.append({'family':'Lua','kind':'lua-bytecode','data':b})
        if len(out)>=12:break
    return out

def _generic_pipeline(code: str, report: DeobfuscationReport, max_passes: int=6) -> str:
    pipeline=[
        ('unwrap literal load/loadstring wrapper',pass_unwrap_literal_loader),
        ('unwrap long-string load/loadstring wrapper',pass_unwrap_long_literal_loader),
        ('unwrap Hercules function wrapper',pass_hercules_wrapper),
        ('unwrap Hercules control-flow wrapper',pass_hercules_control_flow),
        ('strip Hercules anti-tamper prelude',pass_hercules_antitamper),
        ('unwrap local literal loader',pass_load_local_literal),
        ('decode numeric/hex/unicode escapes',pass_numeric_escapes),
        ('normalize indexed globals/libraries',pass_indexed_globals),
        ('resolve stdlib aliases',pass_library_aliases),
        ('fold constant string.pack',pass_string_pack_constants),
        ('fold straight-line Luau buffers',pass_luau_buffer_constants),
        ('decode repeating-key XOR helpers',pass_repeating_xor_helpers),
        ('decode custom-alphabet Base64 helpers',pass_custom_base64_helpers),
        ('decode Synapse Xen framed payloads',pass_synapse_xen_payloads),
        ('fold literal gsub substitution maps',pass_gsub_literal_maps),
        ('normalize mixed-radix numbers',pass_mixed_radix_numbers),
        ('fold tonumber literals',pass_tonumber_literals),
        ('fold string stdlib constants',pass_string_stdlib_constants),
        ('fold string.byte constants',pass_string_byte_constants),
        ('fold string.rep constants',pass_string_rep_constants),
        ('fold additional stdlib constants',pass_more_stdlib_constants),
        ("decode Bill's rotating XOR strings",pass_bill_rotating_xor),
        ("decode Bill's dictionary strings",pass_bill_huffman),
        ("decode Bill's inline Base64 strings",pass_bill_inline_base64),
        ('fold constant bitwise calls',pass_bitwise_constants),
        ('recover Clyde maximum-protection bootstrap',pass_clyde_max_bootstrap),
        ('decode Clyde XOR byte tables',pass_clyde_xor_tables),
        ('decode simple XOR helper calls',pass_single_byte_xor_helpers),
        ('decode fixed-key XOR helper calls',pass_fixed_xor_helpers),
        ('decode byte-shift helper calls',pass_byte_shift_helpers),
        ('decode Hercules Caesar strings',pass_hercules_caesar_strings),
        ('decode Hercules string expressions',pass_hercules_string_expressions),
        ('decode Prometheus encrypted strings',pass_prometheus_encrypted_strings),
        ('decode Prometheus custom constant encodings',pass_prometheus_custom_constant_encodings),
        ('reverse literal strings',pass_reverse_literals),
        ('fold string.char expressions',pass_string_char_expressions),
        ('fold string.char constants',pass_string_char),
        ('fold utf8.char constants',pass_utf8_char_constants),
        ('recover byte-array strings',pass_byte_array_strings),
        ('decode literal Base64 wrappers',pass_base64_literals),
        ('decode embedded Base64/compressed Lua payloads',pass_luraph_base64_zlib_literals),
        ('decode literal Base32 wrappers',pass_base32_literals),
        ('decode literal Base58 wrappers',pass_base58_literals),
        ('decode literal Base85/Ascii85 wrappers',pass_base85_literals),
        ('decode literal Base91 wrappers',pass_base91_literals),
        ('decode URL-percent wrappers',pass_url_percent_literals),
        ('decode ROT13/ROT47 wrappers',pass_rot_literals),
        ('decode literal hex wrappers',pass_hex_literals),
        ('decode long hex/compressed Lua payloads',pass_long_hex_compressed_payloads),
        ('fold table.concat constants',pass_table_concat_constants),
        ('inline mixed constant tables',pass_mixed_constant_tables),
        ('fold constant table accessors',pass_constant_table_accessors),
        ('inline simple constant tables',pass_constant_tables),
        ('fold literal string concatenation',pass_literal_concat),
        ('fold literal arithmetic',pass_arithmetic_constants),
        ('simplify opaque boolean terms',pass_opaque_boolean_terms),
        ('evaluate constant predicates',pass_constant_predicates),
        ('normalize common global aliases',pass_alias_globals),
        ('remove trivial constant branches',pass_simple_dead_branches),
        ('linearize simple state machine',pass_simple_state_machine),
    ]
    for _round in range(max_passes):
        before=code
        for name,fn in pipeline:
            try:
                new=fn(code)
            except Exception as exc:
                report.warnings.append(f'{name}: {exc}')
                continue
            if new!=code:
                if name not in report.passes: report.passes.append(name)
                code=new
        if code==before: break
    return code


def _try_moonsec_specialized(code: str, report: DeobfuscationReport, mode: str='source') -> Optional[str|bytes]:
    """Use exact MoonSec bytecode core if the source itself yields enough context.

    Full MoonSec handler recovery requires upstream AST analysis. This single-file tool
    attempts textual context recovery and otherwise leaves source to generic passes.
    """
    try:
        ctx=context_template_from_source(code)
        if not ctx.bytecode_string:
            return None

        for keyname,attr in [('bytecode_key','bytecode_key'),('constant_key','constant_key')]:
            m=re.search(r'\b'+keyname+r'\b\s*[=:]\s*(\d+)',code,re.I)
            if m:setattr(ctx,attr,int(m.group(1)))

        m=re.search(r'--\s*MOONSEC_CONTEXT\s*:\s*(\{.*\})\s*$',code,re.M)
        if m:
            try: ctx=Context.from_dict(json.loads(m.group(1)))
            except Exception: pass
        if not (ctx.proto_format and ctx.opcode_fingerprints):
            report.warnings.append('MoonSec detected, but static source did not expose proto format/opcode fingerprints; applied generic cleanup only.')
            return None
        root=devirtualize_context(ctx)
        report.passes.append('MoonSec V3 bytecode devirtualization')
        if mode=='bytecode':
            report.output_kind='lua51-bytecode'
            return Lua51Serializer().serialize(root)
        report.output_kind='disassembly'
        return Disassembler(root).disassemble()
    except Exception as exc:
        report.warnings.append(f'MoonSec specialized pass failed: {exc}')
        return None


def deobfuscate(source_or_path: str | bytes | os.PathLike, *, return_report: bool=False,
                max_passes: int=6, moonsec_mode: str='source'):
    """Auto-detect and statically deobfuscate Lua/Luau.

    Parameters
    ----------
    source_or_path: source text, bytes, or filesystem path
    return_report: if True returns (output, DeobfuscationReport)
    max_passes: generic fixed-point cleanup rounds
    moonsec_mode: 'source' (default), 'disassembly', or 'bytecode'. If an exact
                  MoonSec context can be recovered, source/disassembly returns a
                  disassembly because VM bytecode is the recovered representation.

    This function never executes the supplied Lua.
    """
    code,input_path=_read_input(source_or_path)
    report=DeobfuscationReport(detections=detect_obfuscator(code))
    original=code


    families={d.family for d in report.detections if d.score>=4}


    if any('Luarmor V4 public loader' in f for f in families) and not any('Luarmor V4 bootstrap' in f for f in families):
        refs=extract_luarmor_v4_loader_refs(code)
        report.details['luarmor_v4_loader_refs']=refs
        report.passes.append('Luarmor V4 public-loader extraction')
        report.warnings.append('Luarmor V4 public loader recognized. This file is only a remote loader reference; the protected program is served by Luarmor and is not embedded as plaintext here.')
        header='-- LelSploit recognized Luarmor V4 public loader\n'
        for ref in refs:
            header += '-- loader_id: ' + ref.get('loader_id','') + '\n-- loader_url: ' + ref.get('url','') + '\n'
        report.changed=True
        report.output_kind='luarmor-v4-public-loader'
        rendered=header+'\n'+code
        return (rendered,report) if return_report else rendered
    if any('Luarmor V4 bootstrap' in f for f in families):
        info=extract_luarmor_v4_bootstrap(code)
        if info is not None:
            report.passes.append('Luarmor V4 _bsdata0/bootstrap extraction')
            report.details['luarmor_v4'] = info
            if input_path is not None:
                cached=find_luarmor_v4_cache_files(input_path, info)
                if cached:
                    report.details['luarmor_cache_candidates'] = cached
                    report.warnings.append('Found nearby Luarmor cache/init file(s): ' + ', '.join(cached[:4]))
            report.warnings.append(
                'Luarmor V4 bootstrap parsed successfully. The plaintext program is not embedded in this wrapper: '
                'the protected _bsdata0 values are consumed by the separately downloaded Luarmor/Luraph V4 init loader. '
                'Static analysis therefore preserves the encrypted bootstrap instead of executing the remote loader.'
            )
            rendered=_render_luarmor_v4_static_report(info) + '\n' + code
            report.changed=True
            report.output_kind='luarmor-v4-bootstrap'
            return (rendered,report) if return_report else rendered
    if any('LuaObfuscator.com' in f or 'repeating-XOR' in f for f in families):
        new=pass_repeating_xor_helpers(code)
        if new!=code: report.passes.append('LuaObfuscator.com/repeating-key XOR recovery'); code=new
    if any('Synapse Xen' in f for f in families):
        new=pass_synapse_xen_payloads(code)
        if new!=code: report.passes.append('Synapse Xen Base64/LZW payload recovery'); code=new
    if any('Prometheus' in f or 'WeAreDevs' in f for f in families):
        new=pass_prometheus_encrypted_strings(code)
        if new!=code: report.passes.append('Prometheus encrypted-string recovery'); code=new
        new=pass_prometheus_custom_constant_encodings(code)
        if new!=code: report.passes.append('Prometheus custom constant decoding'); code=new
        new=pass_prometheus_conservative(code)
        if new!=code: report.passes.append('Prometheus conservative reversal'); code=new
    if any('Hercules' in f for f in families):
        for _name,_fn in [('Hercules Caesar strings',pass_hercules_caesar_strings),('Hercules string expressions',pass_hercules_string_expressions),('Hercules control-flow recovery',pass_hercules_control_flow),('Hercules anti-tamper removal',pass_hercules_antitamper),('Hercules wrapper removal',pass_hercules_wrapper)]:
            new=_fn(code)
            if new!=code: report.passes.append(_name); code=new
        hb=_extract_hercules_shifted_bytecode(code)
        if hb is not None:
            if hb.startswith(b'\x1bLua\x51'):
                try:
                    dis=disassemble_lua51_bytecode(hb)
                    report.passes.append('Hercules Lua 5.1 bytecode disassembly')
                    report.output_kind='disassembly'; report.changed=True
                    return (dis,report) if return_report else dis
                except Exception as exc:
                    report.warnings.append(f'Hercules Lua 5.1 chunk recovered but parsing failed: {exc}')
            report.warnings.append(f'Hercules embedded Lua bytecode recovered ({len(hb)} bytes); call extract_embedded_payloads() to retrieve it.')
    if any("Bill's Lua Obfuscator" in f for f in families):
        for _name,_fn in [("Bill rotating-key XOR strings",pass_bill_rotating_xor),("Bill dictionary strings",pass_bill_huffman),("Bill inline Base64 strings",pass_bill_inline_base64)]:
            new=_fn(code)
            if new!=code: report.passes.append(_name); code=new
    if any('Clyde' in f for f in families):
        new=pass_clyde_max_bootstrap(code)
        if new!=code:
            report.passes.append('Clyde maximum-protection bootstrap recovery'); code=new

            families.update(d.family for d in detect_obfuscator(code)[:4])
        new=pass_clyde_xor_tables(code)
        if new!=code: report.passes.append('Clyde XOR string-table recovery'); code=new
        new=pass_opaque_boolean_terms(code)
        if new!=code: report.passes.append('Clyde opaque-predicate simplification'); code=new
    if any('Luraph' in f or 'MoonVeil' in f for f in families):
        for _name,_fn in [('Luraph xpcall wrapper',pass_luraph_xpcall_wrapper),('Luraph Base64/zlib payloads',pass_luraph_base64_zlib_literals),('fixed-key XOR strings',pass_fixed_xor_helpers)]:
            new=_fn(code)
            if new!=code: report.passes.append(_name); code=new
    if any('AztupBrew' in f or 'IronBrew' in f for f in families):
        new=pass_ironbrew_hexrle(code)
        if new!=code: report.passes.append('IronBrew hex/RLE payload decode'); code=new
        new=pass_aztupbrew_payload(code)
        if new!=code: report.passes.append('AztupBrew base36/LZW payload decode'); code=new
    if any('Lua bytecode loader' in f for f in families):
        chunks=_extract_lua_bytecode_literals(code)
        for chunk in chunks:
            if chunk.startswith(b'\x1bLua\x51'):
                try:
                    dis=disassemble_lua51_bytecode(chunk)
                    report.passes.append('embedded Lua 5.1 bytecode disassembly')
                    report.output_kind='disassembly'; report.changed=True
                    return (dis,report) if return_report else dis
                except Exception as exc:
                    report.warnings.append(f'embedded Lua 5.1 parse failed: {exc}')
    if any('MoonSec' in f for f in families):
        mode='bytecode' if moonsec_mode=='bytecode' else 'disassembly'
        spec=_try_moonsec_specialized(code,report,mode=mode)
        if spec is not None:
            report.changed=True
            return (spec,report) if return_report else spec

    code=_generic_pipeline(code,report,max_passes=max_passes)
    report.changed=(code!=original)
    return (code,report) if return_report else code


def deobfuscate_file(input_path: str|os.PathLike, output_path: str|os.PathLike|None=None, **kwargs):
    result,report=deobfuscate(input_path,return_report=True,**kwargs)
    if output_path is None:
        p=Path(input_path)
        output_path=p.with_name(p.stem+'.deobfuscated'+('.luac' if isinstance(result,(bytes,bytearray)) else '.lua'))
    op=Path(output_path)
    if isinstance(result,(bytes,bytearray)): op.write_bytes(bytes(result))
    else: op.write_text(result,encoding='utf-8')
    return op,report


def analyze(source_or_path):
    text,input_path=_read_input(source_or_path)
    luarmor_info=extract_luarmor_v4_bootstrap(text)
    return {
        'detections':[{'family':d.family,'score':d.score,'reasons':d.reasons} for d in detect_obfuscator(text)],
        'size':len(text),
        'lines':text.count('\n')+1,
        'encoded_blob_candidates':len(find_encoded_blob_candidates(text)) if text else 0,
        'decimal_escapes':len(re.findall(r'\\\d{1,3}',text)),
        'hex_escapes':len(re.findall(r'\\x[0-9A-Fa-f]{2}',text)),
        'bit32_calls':text.count('bit32.'),
        'luau_buffer_calls':len(re.findall(r'\bbuffer\.[A-Za-z_]\w*\s*\(',text)),
        'repeating_xor_helpers':len(_discover_repeating_xor_helpers(text)),
        'embedded_payloads':[(p['family'],p['kind'],len(p['data'])) for p in extract_embedded_payloads(text)],
        'prometheus_prng_detected':_prometheus_prng_params(text) is not None,
        'hercules_caesar_helpers':len(_discover_hercules_caesar_names(text)),
        'base64_zlib_payloads':sum(1 for p in extract_embedded_payloads(text) if p['kind']=='decoded-source'),
        'lua_bytecode_payloads':sum(1 for p in extract_embedded_payloads(text) if p['kind']=='lua-bytecode'),
        'luarmor_v4_bootstrap':luarmor_info,
        'luarmor_v4_loader_refs':extract_luarmor_v4_loader_refs(text),
        'luarmor_cache_candidates':find_luarmor_v4_cache_files(input_path,luarmor_info) if input_path is not None and luarmor_info is not None else [],
    }



SUPPORTED_FAMILIES = (

    "MoonSec V3", "Prometheus", "Hercules", "IronBrew 1/2/3", "AztupBrew",
    "LuaObfuscator.com", "Synapse Xen", "Clyde", "Bill Lua Obfuscator",
    "Luraph/MoonVeil loader layers", "Luarmor V4 public loader", "Luarmor V4 bootstrap", "Luarmor/Luraph signatures", "AzureVM/Prometheus",

    "Boronide", "77fuscator", "LPS", "PSU", "wYnFuscate", "WeAreDevs",
    "Goofyscator", "Dexfuscator", "RealVuxObfuscate", "Asteria", "Catph", "Devlyx",
    "DarkSec", "LuauProtect", "Secrovia", "ObscuraLua", "25ms", "XFuscator",
    "EssaFuscator", "Zenfus", "Obelisk", "LuaGuard", "SLua", "Veil Lua",
    "05Fusec", "2521", "Aero", "Comet", "KRNOBf", "MD21C", "Protosmasher",
    "ComboSec", "MathOBF", "JokerObfuscator", "LuaU-obfuscator", "Punchfuscator",
    "Ghost Obfuscator", "Luau-Protect", "LuaVirtualBox/Firefly", "Lunaris", "Xemon", "APRIL", "Mote",
    "Luau buffer/custom-VM families", "Lua 5.1 bytecode loaders",
    "Base32/Base58/Base64/Base85/Base91/hex/URL/ROT packers",
    "generic Lua/Luau source obfuscation",
)

SUPPORT_TIERS = {
    "specialized": [
        "MoonSec V3 (when VM context can be recovered)", "Prometheus", "Hercules",
        "IronBrew/AztupBrew packing layers", "LuaObfuscator.com repeating-XOR strings",
        "Synapse Xen u/c Base64+LZW framing", "Clyde", "Bill Lua Obfuscator",
    ],
    "loader_and_shared_transforms": [
        "Luraph", "MoonVeil", "Luarmor V4 public loader", "Luarmor V4 bootstrap", "Luarmor", "AzureVM", "Boronide", "77fuscator",
        "LPS", "PSU", "wYnFuscate", "WeAreDevs", "Goofyscator", "Dexfuscator",
        "RealVuxObfuscate", "Asteria", "Catph", "Devlyx", "DarkSec", "LuauProtect",
        "Secrovia", "ObscuraLua", "25ms", "XFuscator", "EssaFuscator", "Zenfus",
        "Obelisk", "LuaGuard", "SLua", "Veil Lua", "05Fusec", "2521", "Aero",
        "Comet", "KRNOBf", "MD21C", "Protosmasher", "ComboSec", "MathOBF",
        "JokerObfuscator", "LuaU-obfuscator", "Punchfuscator", "Ghost Obfuscator", "Luau-Protect",
        "LuaVirtualBox/Firefly", "Lunaris", "Xemon", "APRIL", "Mote",
    ],
}


def capabilities() -> dict[str, Any]:
    """Return a machine-readable summary for integrations/UI wrappers."""
    return {
        "version": __version__,
        "execution": "static-only; input Lua is never executed",
        "families": list(SUPPORTED_FAMILIES),
        "support_tiers": SUPPORT_TIERS,
        "major_transforms": [
            "MoonSec V3 bytecode devirtualization when context is recoverable",
            "Prometheus encrypted strings and custom base64/base85 constant arrays",
            "Hercules Caesar strings, StringToExpressions, anti-tamper, wrapper/control-flow removal, shifted bytecode",
            "IronBrew hex/RLE and AztupBrew base36/LZW payload recovery",
            "Luarmor V4 _bsdata0 bootstrap parsing, cache/loader extraction, binary/hex/nibble-ciphertext inventory",
            "Luraph-style xpcall shell and Base64+zlib/gzip/raw-deflate payload recovery",
            "standard Lua 5.1 bytecode parsing/disassembly",
            "Clyde XOR byte tables, opaque predicates, and maximum-protection Base85/S-box bootstrap recovery",
            "Bill rotating-key XOR, inline Base64, dictionary-code strings, and chunked char reconstruction",
            "LuaObfuscator.com-style repeating-key XOR helpers even through renamed stdlib aliases",
            "Synapse Xen raw/LZW framed payload extraction",
            "custom-alphabet Base64 helper evaluation and Base32/Base58/Base85/Base91 wrappers",
            "URL-percent, ROT13/ROT47, fixed-key XOR, repeating-key XOR, and byte-shift decoding",
            "constant string.pack evaluation and straight-line Luau buffer.create/write/tostring folding",
            "literal gsub substitution maps and extra constant string/math folding",
            "numeric/hex/unicode escapes, string.char/utf8.char, byte arrays, stdlib aliases",
            "constant arithmetic/bitwise/string operations, constant tables, dead branches",
            "simple integer state-machine control-flow linearization",
        ],
    }


class Deobfuscator:
    """Small import-friendly facade.

    Example:
        from LelSploit_Deobfuscate import Deobfuscator
        d = Deobfuscator()
        clean = d.deobfuscate(source)
    """
    def __init__(self, max_passes: int=6):
        self.max_passes=max_passes
    def detect(self, source_or_path):
        return detect_obfuscator(source_or_path)
    def is_supported(self, source_or_path, *, min_score=3):
        return is_supported_obfuscated_format(source_or_path, min_score=min_score)
    def check_supported(self, source_or_path, *, min_score=3):
        return check_supported_obfuscated_format(source_or_path, min_score=min_score)
    def analyze(self, source_or_path):
        return analyze(source_or_path)
    def capabilities(self):
        return capabilities()
    def payloads(self, source_or_path):
        return extract_embedded_payloads(source_or_path)
    def luarmor_info(self, source_or_path):
        return extract_luarmor_v4_bootstrap(source_or_path)
    def luarmor_loader_refs(self, source_or_path):
        return extract_luarmor_v4_loader_refs(source_or_path)
    def luarmor_cache_files(self, input_path):
        return find_luarmor_v4_cache_files(input_path)
    def deobfuscate(self, source_or_path, *, return_report=False, moonsec_mode='source'):
        return deobfuscate(source_or_path,return_report=return_report,max_passes=self.max_passes,moonsec_mode=moonsec_mode)
    def file(self, input_path, output_path=None, **kwargs):
        kwargs.setdefault('max_passes',self.max_passes)
        return deobfuscate_file(input_path,output_path,**kwargs)


def _cli(argv=None):
    ap=argparse.ArgumentParser(description='LelSploit auto-detecting Lua/Luau deobfuscator (static/offline).')
    ap.add_argument('input',nargs='?',help='input .lua/.luau file')
    ap.add_argument('-o','--output',help='output path')
    ap.add_argument('--detect',action='store_true',help='only print detection report')
    ap.add_argument('--luarmor-info',action='store_true',help='print parsed Luarmor V4 _bsdata0/bootstrap metadata as JSON')
    ap.add_argument('--capabilities',action='store_true',help='print supported families/transforms as JSON')
    ap.add_argument('--extract-payloads',metavar='DIR',help='also save statically recovered embedded payloads')
    ap.add_argument('--report',action='store_true',help='print applied passes/warnings to stderr')
    ap.add_argument('--moonsec-bytecode',action='store_true',help='emit .luac when exact MoonSec context is recoverable')
    ap.add_argument('--max-passes',type=int,default=6)
    ns=ap.parse_args(argv)
    if ns.capabilities:
        print(json.dumps(capabilities(),indent=2)); return 0
    if not ns.input:
        ap.error('input is required unless --capabilities is used')
    if ns.detect:
        print(json.dumps(analyze(ns.input),indent=2)); return 0
    if ns.luarmor_info:
        info=extract_luarmor_v4_bootstrap(ns.input)
        print(json.dumps(info,indent=2) if info is not None else 'null')
        return 0
    if ns.extract_payloads:
        d=Path(ns.extract_payloads); d.mkdir(parents=True,exist_ok=True)
        for i,payload in enumerate(extract_embedded_payloads(ns.input),1):
            fam=re.sub(r'[^A-Za-z0-9_.-]+','_',payload['family']).strip('_') or 'payload'
            kind=re.sub(r'[^A-Za-z0-9_.-]+','_',payload['kind']).strip('_') or 'data'
            data=payload['data']
            ext='.luac' if payload['kind']=='lua-bytecode' else '.json' if payload['kind']=='bootstrap-metadata' else '.lua' if isinstance(data,str) else '.bin'
            fp=d/f'{i:02d}_{fam}_{kind}{ext}'
            if isinstance(data,str):fp.write_text(data,encoding='utf-8')
            else:fp.write_bytes(bytes(data))
    mode='bytecode' if ns.moonsec_bytecode else 'source'
    result,rep=deobfuscate(ns.input,return_report=True,max_passes=ns.max_passes,moonsec_mode=mode)
    out=Path(ns.output) if ns.output else Path(ns.input).with_name(Path(ns.input).stem+'.deobfuscated'+('.luac' if isinstance(result,(bytes,bytearray)) else '.lua'))
    if isinstance(result,(bytes,bytearray)): out.write_bytes(bytes(result))
    else: out.write_text(result,encoding='utf-8')
    if ns.report:
        print(json.dumps({'best_family':rep.best_family,'detections':[d.__dict__ for d in rep.detections], 'passes':rep.passes,'warnings':rep.warnings,'details':rep.details,'output_kind':rep.output_kind},indent=2),file=sys.stderr)
    print(out)
    return 0


if __name__=='__main__':
    raise SystemExit(_cli())
