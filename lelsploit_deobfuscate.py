# SPDX-License-Identifier: GPL-3.0-or-later
# LelSploit 3.1.0. Modified 2026-10-17 for Luau source recovery.
# Includes modified unprom at d37b9d97746160359fb68dbdbb5213317403e669.
# Original upstream MIT notice is retained below.
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

_LUAUVMP_LICENSE = 'MIT License\n\nCopyright (c) 2026 luau-vmp-deobf contributors\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the "Software"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\nAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\nLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\nOUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\nSOFTWARE.\n'
_UNPROM_LICENSE = 'MIT License\n\nCopyright (c) 2026 unprom contributors\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software and associated documentation files (the "Software"), to deal\nin the Software without restriction, including without limitation the rights\nto use, copy, modify, merge, publish, distribute, sublicense, and/or sell\ncopies of the Software, and to permit persons to whom the Software is\nfurnished to do so, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\nAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\nLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\nOUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\nSOFTWARE.\n'

__version__ = "3.1.0"

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


def _legacy_extract_embedded_payloads(source_or_path) -> list[dict[str,Any]]:
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


def _legacy_deobfuscate(source_or_path: str | bytes | os.PathLike, *, return_report: bool=False,
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




_AST_SOURCES = {'_lelsploit_ast': ('"""unprom - a best-effort deobfuscator for the Prometheus Lua/Luau obfuscator\nand its rebrands (e.g. wearedevs.net\'s obfuscator v1.0.0).\n\nQuick start::\n\n    from unprom import deobfuscate\n    clean_source = deobfuscate(obfuscated_source)\n\nFiner control::\n\n    from unprom import Pipeline\n    text, ctx = Pipeline(passes=["unwrap", "encrypt_strings", "constant_fold"],\n                         options={"rename": "all"}).run(src)\n    print(ctx.notes, ctx.stats)\n"""\n\nfrom .pipeline import deobfuscate, Pipeline, DEFAULT_PASSES, PassContext  # noqa: F401\n\n__version__ = "0.1.0"\n__all__ = ["deobfuscate", "Pipeline", "DEFAULT_PASSES", "PassContext", "__version__"]\n', True), '_lelsploit_ast.ast_nodes': ('"""AST node definitions plus generic visitor / transformer machinery.\n\nThe tree is intentionally small and uniform.  Every node is a dataclass that\ninherits from :class:`Node`; child links are either ``Node`` instances or lists\nof ``Node``.  ``iter_fields`` / ``NodeTransformer`` walk those links generically\nso passes never have to enumerate every node type.\n"""\n\nfrom __future__ import annotations\n\nfrom dataclasses import dataclass, field, fields\nfrom typing import Any, List, Optional, Tuple\n\n\nclass Node:\n    # Populated by dataclass subclasses; declared here for typing only.\n    line: int = 0\n\n    @property\n    def kind(self) -> str:\n        return type(self).__name__\n\n\ndef iter_fields(node: Node):\n    for f in fields(node):\n        if f.name in ("line", "col"):\n            continue\n        yield f.name, getattr(node, f.name)\n\n\ndef iter_child_nodes(node: Node):\n    for _name, value in iter_fields(node):\n        if isinstance(value, Node):\n            yield value\n        elif isinstance(value, list):\n            for item in value:\n                if isinstance(item, Node):\n                    yield item\n                elif isinstance(item, tuple):\n                    for sub in item:\n                        if isinstance(sub, Node):\n                            yield sub\n\n\ndef walk(node: Node):\n    stack = [node]\n    while stack:\n        cur = stack.pop()\n        yield cur\n        stack.extend(list(iter_child_nodes(cur)))\n\n\n# --------------------------------------------------------------------------\n# Statements\n# --------------------------------------------------------------------------\n@dataclass\nclass Chunk(Node):\n    body: "Block"\n    line: int = 0\n\n\n@dataclass\nclass Block(Node):\n    stmts: List[Node] = field(default_factory=list)\n    line: int = 0\n\n\n@dataclass\nclass LocalAssign(Node):\n    targets: List["Name"] = field(default_factory=list)\n    values: List[Node] = field(default_factory=list)\n    attribs: List[Optional[str]] = field(default_factory=list)\n    line: int = 0\n\n\n@dataclass\nclass Assign(Node):\n    targets: List[Node] = field(default_factory=list)\n    values: List[Node] = field(default_factory=list)\n    line: int = 0\n\n\n@dataclass\nclass CompoundAssign(Node):\n    op: str = "+"          # one of + - * / % ^ ..\n    target: Node = None\n    value: Node = None\n    line: int = 0\n\n\n@dataclass\nclass CallStat(Node):\n    call: Node = None\n    line: int = 0\n\n\n@dataclass\nclass Do(Node):\n    body: Block = None\n    line: int = 0\n\n\n@dataclass\nclass While(Node):\n    cond: Node = None\n    body: Block = None\n    line: int = 0\n\n\n@dataclass\nclass Repeat(Node):\n    body: Block = None\n    cond: Node = None\n    line: int = 0\n\n\n@dataclass\nclass If(Node):\n    # list of (condition, Block)\n    clauses: List[Tuple[Node, Block]] = field(default_factory=list)\n    orelse: Optional[Block] = None\n    line: int = 0\n\n\n@dataclass\nclass NumericFor(Node):\n    var: "Name" = None\n    start: Node = None\n    stop: Node = None\n    step: Optional[Node] = None\n    body: Block = None\n    line: int = 0\n\n\n@dataclass\nclass GenericFor(Node):\n    names: List["Name"] = field(default_factory=list)\n    exprs: List[Node] = field(default_factory=list)\n    body: Block = None\n    line: int = 0\n\n\n@dataclass\nclass FunctionDecl(Node):\n    # target is a Name / Index chain; is_method True => trailing \':name\'\n    target: Node = None\n    is_method: bool = False\n    func: "Function" = None\n    line: int = 0\n\n\n@dataclass\nclass LocalFunction(Node):\n    name: "Name" = None\n    func: "Function" = None\n    line: int = 0\n\n\n@dataclass\nclass Return(Node):\n    values: List[Node] = field(default_factory=list)\n    line: int = 0\n\n\n@dataclass\nclass Break(Node):\n    line: int = 0\n\n\n@dataclass\nclass Continue(Node):\n    line: int = 0\n\n\n@dataclass\nclass Goto(Node):\n    label: str = ""\n    line: int = 0\n\n\n@dataclass\nclass Label(Node):\n    name: str = ""\n    line: int = 0\n\n\n# --------------------------------------------------------------------------\n# Expressions\n# --------------------------------------------------------------------------\n@dataclass\nclass Nil(Node):\n    line: int = 0\n\n\n@dataclass\nclass TrueExpr(Node):\n    line: int = 0\n\n\n@dataclass\nclass FalseExpr(Node):\n    line: int = 0\n\n\n@dataclass\nclass Vararg(Node):\n    line: int = 0\n\n\n@dataclass\nclass Number(Node):\n    value: float = 0.0\n    raw: str = ""\n    line: int = 0\n\n\n@dataclass\nclass String(Node):\n    value: str = ""\n    raw: Optional[str] = None       # original spelling if known\n    line: int = 0\n\n\n@dataclass\nclass Name(Node):\n    name: str = ""\n    # filled in by the resolver: a stable id for the binding this refers to\n    binding: Optional[int] = None\n    line: int = 0\n\n\n@dataclass\nclass Index(Node):\n    obj: Node = None\n    key: Node = None\n    # ``dot`` is a formatting hint: True means it was written ``a.b``.\n    dot: bool = False\n    line: int = 0\n\n\n@dataclass\nclass Call(Node):\n    func: Node = None\n    args: List[Node] = field(default_factory=list)\n    line: int = 0\n\n\n@dataclass\nclass MethodCall(Node):\n    obj: Node = None\n    method: str = ""\n    args: List[Node] = field(default_factory=list)\n    line: int = 0\n\n\n@dataclass\nclass Function(Node):\n    params: List["Name"] = field(default_factory=list)\n    is_vararg: bool = False\n    body: Block = None\n    line: int = 0\n\n\n@dataclass\nclass Table(Node):\n    # each field: ("pos", None, value) | ("name", "key", value) | ("expr", keyNode, value)\n    fields: List[Tuple[str, Any, Node]] = field(default_factory=list)\n    line: int = 0\n\n\n@dataclass\nclass BinOp(Node):\n    op: str = ""\n    left: Node = None\n    right: Node = None\n    line: int = 0\n\n\n@dataclass\nclass UnOp(Node):\n    op: str = ""\n    operand: Node = None\n    line: int = 0\n\n\n@dataclass\nclass Paren(Node):\n    inner: Node = None\n    line: int = 0\n\n\n# --------------------------------------------------------------------------\n# Transformer\n# --------------------------------------------------------------------------\nclass NodeTransformer:\n    """Mutating visitor.  ``visit_<Kind>`` may return a replacement node,\n    ``None`` to drop a statement (only valid inside a statement list), or the\n    node itself.  Everything else is handled generically."""\n\n    def visit(self, node: Node) -> Any:\n        method = getattr(self, "visit_" + node.kind, None)\n        if method is not None:\n            return method(node)\n        return self.generic_visit(node)\n\n    def generic_visit(self, node: Node) -> Node:\n        for name, value in list(iter_fields(node)):\n            if isinstance(value, Node):\n                new = self.visit(value)\n                setattr(node, name, new)\n            elif isinstance(value, list):\n                setattr(node, name, self._visit_list(value))\n        return node\n\n    def _visit_list(self, lst: list) -> list:\n        out = []\n        for item in lst:\n            if isinstance(item, Node):\n                res = self.visit(item)\n                if res is None:\n                    continue\n                if isinstance(res, list):\n                    out.extend(res)\n                else:\n                    out.append(res)\n            elif isinstance(item, tuple):\n                out.append(tuple(self.visit(s) if isinstance(s, Node) else s\n                                 for s in item))\n            else:\n                out.append(item)\n        return out\n\n\nclass NodeVisitor:\n    """Read-only walk."""\n\n    def visit(self, node: Node) -> Any:\n        method = getattr(self, "visit_" + node.kind, None)\n        if method is not None:\n            return method(node)\n        return self.generic_visit(node)\n\n    def generic_visit(self, node: Node):\n        for child in iter_child_nodes(node):\n            self.visit(child)\n\n\ndef clone(node: Any) -> Any:\n    """Deep copy of a node tree (bindings preserved)."""\n    if isinstance(node, Node):\n        kwargs = {}\n        for name, value in iter_fields(node):\n            kwargs[name] = clone(value)\n        new = type(node)(**kwargs)\n        new.line = getattr(node, "line", 0)\n        return new\n    if isinstance(node, list):\n        return [clone(x) for x in node]\n    if isinstance(node, tuple):\n        return tuple(clone(x) for x in node)\n    return node\n', False), '_lelsploit_ast.astutil': ('"""Small shared helpers for pattern-matching over the AST."""\n\nfrom __future__ import annotations\n\nfrom typing import Optional\n\nfrom . import ast_nodes as A\nfrom .evaluator import const_value\n\n\ndef unparen(node: A.Node) -> A.Node:\n    while isinstance(node, A.Paren):\n        node = node.inner\n    return node\n\n\ndef as_number(node: A.Node) -> Optional[float]:\n    ok, v = const_value(node)\n    if ok and isinstance(v, float):\n        return v\n    return None\n\n\ndef as_int(node: A.Node) -> Optional[int]:\n    v = as_number(node)\n    if v is None:\n        return None\n    if v != v or v in (float("inf"), float("-inf")):\n        return None\n    if abs(v - round(v)) < 1e-9:\n        return int(round(v))\n    return None\n\n\ndef as_string(node: A.Node) -> Optional[str]:\n    ok, v = const_value(node)\n    if ok and isinstance(v, str):\n        return v\n    return None\n\n\ndef name_of(node: A.Node) -> Optional[str]:\n    node = unparen(node)\n    return node.name if isinstance(node, A.Name) else None\n\n\ndef binding_of(node: A.Node) -> Optional[int]:\n    node = unparen(node)\n    return node.binding if isinstance(node, A.Name) else None\n\n\ndef is_call_of(node: A.Node, binding: Optional[int] = None,\n               name: Optional[str] = None) -> bool:\n    node = unparen(node)\n    if not isinstance(node, A.Call):\n        return False\n    f = unparen(node.func)\n    if not isinstance(f, A.Name):\n        return False\n    if binding is not None and f.binding != binding:\n        return False\n    if name is not None and f.name != name:\n        return False\n    return True\n\n\ndef contains_number(node: A.Node, value: float) -> bool:\n    for n in A.walk(node):\n        if isinstance(n, A.Number) and n.value == value:\n            return True\n    return False\n\n\ndef contains_string(node: A.Node, needle: str) -> bool:\n    for n in A.walk(node):\n        if isinstance(n, A.String) and needle in n.value:\n            return True\n    return False\n\n\ndef count_binding_uses(chunk: A.Node, binding: int) -> int:\n    return sum(1 for n in A.walk(chunk)\n              if isinstance(n, A.Name) and n.binding == binding)\n', False), '_lelsploit_ast.control_flow': ('"""Recover finite, literal integer dispatch chains without guessing branches."""\nfrom . import ast_nodes as A\nfrom .scope import resolve\nfrom .evaluator import const_value, is_truthy\n\ndef run(chunk, ctx):\n    r=resolve(chunk)\n    def const(node):\n        ok,v=const_value(node)\n        return v if ok and type(v) is float else None\n    class Recover(A.NodeTransformer):\n        def visit_Block(self,node):\n            node=self.generic_visit(node); out=[]; i=0\n            while i<len(node.stmts):\n                decl=node.stmts[i]; loop=node.stmts[i+1] if i+1<len(node.stmts) else None\n                replacement=None\n                if isinstance(decl,A.LocalAssign) and len(decl.targets)==len(decl.values)==1 and isinstance(loop,A.While):\n                    bid=decl.targets[0].binding; state=const(decl.values[0]); ok,truth=const_value(loop.cond)\n                    if state is not None and ok and is_truthy(truth) and len(loop.body.stmts)==1 and isinstance(loop.body.stmts[0],A.If):\n                        branch=loop.body.stmts[0]; arms={}; valid=branch.orelse is None or all(isinstance(x,A.Break) for x in branch.orelse.stmts)\n                        for condition,body in branch.clauses:\n                            if not isinstance(condition,A.BinOp) or condition.op!=\'==\': valid=False; break\n                            left,right=condition.left,condition.right\n                            if isinstance(right,A.Name): left,right=right,left\n                            value=const(right)\n                            if not isinstance(left,A.Name) or left.binding!=bid or value is None or value in arms: valid=False; break\n                            arms[value]=body\n                        loop_names={id(n) for n in A.walk(loop) if isinstance(n,A.Name) and n.binding==bid}\n                        if any(id(use) not in loop_names for use in r.bindings[bid].uses): valid=False\n                        path=[]; seen=set()\n                        while valid and state in arms and state not in seen and len(seen)<4096:\n                            seen.add(state); body=arms[state]; stmts=body.stmts\n                            if not stmts: valid=False; break\n                            tail=stmts[-1]; core=stmts[:-1]; next_state=None\n                            if isinstance(tail,A.Assign) and len(tail.targets)==len(tail.values)==1 and isinstance(tail.targets[0],A.Name) and tail.targets[0].binding==bid:\n                                next_state=const(tail.values[0])\n                                if next_state is None: valid=False; break\n                            elif isinstance(tail,A.Break): pass\n                            elif isinstance(tail,A.Return): core=stmts\n                            else: valid=False; break\n                            # Moving a branch must not expose/read its state or\n                            # move a loop-control statement out of its loop.\n                            if any(isinstance(n,A.Name) and n.binding==bid or isinstance(n,(A.Break,A.Continue)) for s in core for n in A.walk(s)):\n                                valid=False; break\n                            path.append(A.Do(body=A.Block(core)))\n                            if next_state is None: replacement=path; break\n                            state=next_state\n                        if valid and state not in arms and branch.orelse is not None: replacement=path\n                        if not valid: replacement=None\n                if replacement is not None:\n                    out.extend(replacement); i+=2; ctx.bump(\'finite_dispatchers_recovered\')\n                else: out.append(decl); i+=1\n            node.stmts=out; return node\n    return Recover().visit(chunk)\n', False), '_lelsploit_ast.evaluator': ('"""Constant evaluation of pure Lua expressions.\n\n``const_value(node)`` returns ``(True, value)`` when ``node`` provably evaluates\nto a Lua constant with no side effects, else ``(False, None)``.  Lua values map\nto Python as: number->float, string->str, boolean->bool, nil->``LuaNil``.\n"""\n\nfrom __future__ import annotations\n\nimport math\nfrom typing import Any, Tuple\n\nfrom . import ast_nodes as A\n\n\nclass _Nil:\n    _inst = None\n\n    def __new__(cls):\n        if cls._inst is None:\n            cls._inst = super().__new__(cls)\n        return cls._inst\n\n    def __repr__(self):\n        return "nil"\n\n\nLuaNil = _Nil()\n\nNOCONST: Tuple[bool, Any] = (False, None)\n\n\ndef is_truthy(v: Any) -> bool:\n    return not (v is LuaNil or v is False)\n\n\ndef _lua_num_to_str(x: float) -> str:\n    if x == 0 and math.copysign(1.0,x)<0: return "-0"\n    if x != x:\n        return "nan"\n    if x == math.inf:\n        return "inf"\n    if x == -math.inf:\n        return "-inf"\n    if x == int(x) and abs(x) < 1e16:\n        return "%d" % int(x)\n    return repr(x)\n\n\ndef _tonum(v: Any):\n    if isinstance(v, bool):\n        return None\n    if isinstance(v, float):\n        return v\n    if isinstance(v, str):\n        s = v.strip()\n        try:\n            if s[:2].lower() == "0x":\n                return float(int(s, 16))\n            return float(s)\n        except ValueError:\n            return None\n    return None\n\n\ndef const_value(node: A.Node) -> Tuple[bool, Any]:\n    k = node.kind\n    if k == "Number":\n        return True, float(node.value)\n    if k == "String":\n        return True, node.value\n    if k == "TrueExpr":\n        return True, True\n    if k == "FalseExpr":\n        return True, False\n    if k == "Nil":\n        return True, LuaNil\n    if k == "Paren":\n        return const_value(node.inner)\n    if k == "UnOp":\n        ok, v = const_value(node.operand)\n        if not ok:\n            return NOCONST\n        if node.op == "-":\n            n = _tonum(v)\n            return (True, -n) if n is not None else NOCONST\n        if node.op == "not":\n            return True, not is_truthy(v)\n        if node.op == "#":\n            if isinstance(v, str):\n                return True, float(len(v))\n            return NOCONST\n        return NOCONST\n    if k == "BinOp":\n        op = node.op\n        if op == "and":\n            ok, l = const_value(node.left)\n            if not ok:\n                return NOCONST\n            if not is_truthy(l):\n                return True, l\n            return const_value(node.right)\n        if op == "or":\n            ok, l = const_value(node.left)\n            if not ok:\n                return NOCONST\n            if is_truthy(l):\n                return True, l\n            return const_value(node.right)\n        ok, l = const_value(node.left)\n        if not ok:\n            return NOCONST\n        ok, r = const_value(node.right)\n        if not ok:\n            return NOCONST\n        return _bin(op, l, r)\n    return NOCONST\n\n\ndef _bin(op: str, l: Any, r: Any) -> Tuple[bool, Any]:\n    if op == "..":\n        ls = l if isinstance(l, str) else (_lua_num_to_str(l) if isinstance(l, float) else None)\n        rs = r if isinstance(r, str) else (_lua_num_to_str(r) if isinstance(r, float) else None)\n        if ls is None or rs is None:\n            return NOCONST\n        return (True, ls + rs) if len(ls) + len(rs) <= 2_000_000 else NOCONST\n    if op == "==":\n        return True, _lua_eq(l, r)\n    if op == "~=":\n        return True, not _lua_eq(l, r)\n    if op in ("<", "<=", ">", ">="):\n        if isinstance(l, str) and isinstance(r, str):\n            a, b = l, r\n        else:\n            a, b = l, r\n            if type(a) is not float or type(b) is not float:\n                return NOCONST\n        return True, {"<": a < b, "<=": a <= b, ">": a > b, ">=": a >= b}[op]\n    a, b = _tonum(l), _tonum(r)\n    if a is None or b is None:\n        return NOCONST\n    try:\n        if op == "+":\n            return True, a + b\n        if op == "-":\n            return True, a - b\n        if op == "*":\n            return True, a * b\n        if op == "/":\n            return True, a / b if b != 0 else math.copysign(math.inf, a) * math.copysign(1.0, b) if a else math.nan\n        if op == "%":\n            if b == 0:\n                return True, math.nan\n            return True, a - math.floor(a / b) * b\n        if op == "^":\n            return True, float(a ** b)\n        if op == "//":\n            if b == 0:\n                return True, math.copysign(math.inf, a) * math.copysign(1.0, b) if a else math.nan\n            return True, float(math.floor(a / b))\n    except (OverflowError, ValueError):\n        return NOCONST\n    return NOCONST\n\n\ndef _lua_eq(l: Any, r: Any) -> bool:\n    if isinstance(l, bool) or isinstance(r, bool):\n        return l is r\n    if l is LuaNil or r is LuaNil:\n        return l is r\n    if isinstance(l, float) and isinstance(r, float):\n        return l == r\n    if isinstance(l, str) and isinstance(r, str):\n        return l == r\n    return False\n\n\ndef value_to_node(v: Any) -> A.Node:\n    if isinstance(v, bool):\n        return A.TrueExpr() if v else A.FalseExpr()\n    if v is LuaNil:\n        return A.Nil()\n    if isinstance(v, float):\n        return A.Number(value=v, raw=_lua_num_to_str(v))\n    if isinstance(v, str):\n        return A.String(value=v)\n    raise TypeError(f"cannot lift {v!r}")\n', False), '_lelsploit_ast.lexer': ('"""A tokenizer for Lua 5.1 / 5.2 source, with a few Luau tolerances.\n\nPrometheus emits Lua 5.1 by default (LuaVersion = "Lua51") and, with\nPrettyPrint disabled, produces a single very long line.  The lexer below is\ndeliberately permissive: it also accepts ``goto`` / ``::label::`` (5.2), the\nLuau compound-assignment operators (``+=`` ...), ``//`` integer division and\n``continue`` as a soft keyword so that partially-Luau output still tokenizes.\n"""\n\nfrom __future__ import annotations\n\nimport re\n\nfrom dataclasses import dataclass\nfrom typing import List, Optional\n\n\nKEYWORDS = {\n    "and", "break", "do", "else", "elseif", "end", "false", "for", "function",\n    "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return",\n    "then", "true", "until", "while",\n}\n\n# Multi-character operators, longest first so the scanner is greedy.\n_SYMBOLS = [\n    "...", "..=", "//=", "..", "::", "<<", ">>", "//",\n    "==", "~=", "<=", ">=",\n    "+=", "-=", "*=", "/=", "%=", "^=", "..=",\n    "+", "-", "*", "/", "%", "^", "#", "&", "~", "|", "<", ">", "=",\n    "(", ")", "{", "}", "[", "]", ";", ":", ",", ".",\n]\n\n\nclass LuaSyntaxError(SyntaxError):\n    pass\n\n\n@dataclass\nclass Token:\n    type: str          # NAME, NUMBER, STRING, KEYWORD, OP, EOF\n    value: str         # raw-ish value; for STRING this is the decoded text\n    line: int\n    col: int\n    # For strings we remember how they were written so the unparser can round\n    # trip long-bracket literals when it wants to.\n    raw: Optional[str] = None\n\n    def __repr__(self) -> str:  # pragma: no cover - debug aid\n        v = self.value if len(self.value) < 24 else self.value[:21] + "..."\n        return f"Token({self.type}, {v!r}, {self.line}:{self.col})"\n\n\nclass Lexer:\n    def __init__(self, src: str):\n        self.src = src\n        self.n = len(src)\n        self.i = 0\n        self.line = 1\n        self.col = 1\n\n    # -- low level helpers -------------------------------------------------\n    def _peek(self, k: int = 0) -> str:\n        j = self.i + k\n        return self.src[j] if j < self.n else ""\n\n    def _advance(self) -> str:\n        c = self.src[self.i]\n        self.i += 1\n        if c == "\\n":\n            self.line += 1\n            self.col = 1\n        else:\n            self.col += 1\n        return c\n\n    def _match(self, s: str) -> bool:\n        if self.src.startswith(s, self.i):\n            for _ in s:\n                self._advance()\n            return True\n        return False\n\n    def error(self, msg: str):\n        raise LuaSyntaxError(f"{msg} at line {self.line} col {self.col}")\n\n    # -- long brackets [[ ]] / [==[ ]==] --------------------------------\n    def _read_long_bracket(self) -> Optional[str]:\n        """If positioned on a long-bracket opener, consume and return contents.\n\n        Returns None when there is no opener here (so a bare ``[`` stays an op).\n        """\n        start = self.i\n        if self._peek() != "[":\n            return None\n        j = self.i + 1\n        level = 0\n        while j < self.n and self.src[j] == "=":\n            level += 1\n            j += 1\n        if j >= self.n or self.src[j] != "[":\n            return None\n        # commit\n        for _ in range(2 + level):\n            self._advance()\n        # A newline immediately after the opener is skipped by Lua.\n        if self._peek() == "\\r":\n            self._advance()\n        if self._peek() == "\\n":\n            self._advance()\n        close = "]" + "=" * level + "]"\n        idx = self.src.find(close, self.i)\n        if idx == -1:\n            self.i = start\n            self.error("unterminated long bracket")\n        text = self.src[self.i:idx]\n        while self.i < idx + len(close):\n            self._advance()\n        return text.replace("\\r\\n", "\\n").replace("\\r", "\\n").encode("utf-8").decode("latin1")\n\n    # -- string escapes -------------------------------------------------\n    def _read_quoted(self, q: str) -> str:\n        self._advance()  # opening quote\n        out: List[str] = []\n        while True:\n            if self.i >= self.n:\n                self.error("unterminated string")\n            c = self._advance()\n            if c == q:\n                break\n            if c == "\\n":\n                self.error("unterminated string")\n            if c != "\\\\":\n                out.append(c.encode("utf-8").decode("latin1"))\n                continue\n            e = self._advance()\n            simple = {\n                "a": "\\a", "b": "\\b", "f": "\\f", "n": "\\n", "r": "\\r",\n                "t": "\\t", "v": "\\v", "\\\\": "\\\\", \'"\': \'"\', "\'": "\'",\n                "\\n": "\\n", "\\r": "\\r",\n            }\n            if e in simple:\n                out.append(simple[e])\n            elif e == "x":\n                h = ""\n                for _ in range(2):\n                    if self._peek() and self._peek() in "0123456789abcdefABCDEF":\n                        h += self._advance()\n                if not h:\n                    self.error("malformed \\\\x escape")\n                out.append(chr(int(h, 16)))\n            elif e == "z":\n                while self._peek() and self._peek() in " \\t\\r\\n\\f\\v":\n                    self._advance()\n            elif e.isdigit():\n                d = e\n                for _ in range(2):\n                    if self._peek().isdigit():\n                        d += self._advance()\n                v = int(d)\n                if v > 255:\n                    self.error("decimal escape too large")\n                out.append(chr(v))\n            elif e == "u":\n                if self._peek() != "{":\n                    self.error("malformed \\\\u escape")\n                self._advance()\n                h = ""\n                while self._peek() and self._peek() != "}":\n                    h += self._advance()\n                self._advance()\n                out.append(chr(int(h, 16)).encode("utf-8").decode("latin1"))\n            else:\n                # Unknown escape: keep the char (permissive).\n                out.append(e)\n        return "".join(out)\n\n    # -- numbers ------------------------------------------------------------\n    def _read_number(self) -> str:\n        import re\n        m = re.compile(r"(?:0[xX][\\da-fA-F_]+(?:\\.[\\da-fA-F_]*)?(?:[pP][+-]?[\\d_]+)?|0[bB][01_]+|(?:\\d[\\d_]*(?:\\.(?!\\.)[\\d_]*)?|\\.\\d[\\d_]*)(?:[eE][+-]?[\\d_]+)?)").match(self.src, self.i)\n        if m is None: self.error("malformed number")\n        value = m.group(0)\n        for _ in value: self._advance()\n        return value\n\n    # -- main loop --------------------------------------------------------\n    def tokens(self) -> List[Token]:\n        toks: List[Token] = []\n        # Skip an initial shebang line, which Lua allows.\n        if self.src.startswith("#"):\n            while self.i < self.n and self._peek() != "\\n":\n                self._advance()\n        while True:\n            self._skip_trivia()\n            if self.i >= self.n:\n                toks.append(Token("EOF", "", self.line, self.col))\n                return toks\n            line, col = self.line, self.col\n            c = self._peek()\n\n            if c in "\'\\"":\n                raw_start = self.i\n                text = self._read_quoted(c)\n                toks.append(Token("STRING", text, line, col,\n                                  raw=self.src[raw_start:self.i]))\n                continue\n\n            if c == "[" and self._peek(1) in ("[", "="):\n                raw_start = self.i\n                lb = self._read_long_bracket()\n                if lb is not None:\n                    toks.append(Token("STRING", lb, line, col,\n                                      raw=self.src[raw_start:self.i]))\n                    continue\n\n            if c.isdigit() or (c == "." and self._peek(1).isdigit()):\n                toks.append(Token("NUMBER", self._read_number(), line, col))\n                continue\n\n            if c.isalpha() or c == "_":\n                start = self.i\n                while self._peek() and (self._peek().isalnum() or self._peek() == "_"):\n                    self._advance()\n                word = self.src[start:self.i]\n                ttype = "KEYWORD" if word in KEYWORDS else "NAME"\n                toks.append(Token(ttype, word, line, col))\n                continue\n\n            for sym in _SYMBOLS:\n                if self.src.startswith(sym, self.i):\n                    for _ in sym:\n                        self._advance()\n                    toks.append(Token("OP", sym, line, col))\n                    break\n            else:\n                self.error(f"unexpected character {c!r}")\n\n    def _skip_trivia(self):\n        while self.i < self.n:\n            c = self._peek()\n            if c in " \\t\\r\\n\\f\\v":\n                self._advance()\n                continue\n            if c == "-" and self._peek(1) == "-":\n                self._advance()\n                self._advance()\n                lb = self._read_long_bracket()\n                if lb is not None:\n                    continue\n                while self.i < self.n and self._peek() != "\\n":\n                    self._advance()\n                continue\n            return\n\n\ndef tokenize(src: str) -> List[Token]:\n    return Lexer(src).tokens()\n', False), '_lelsploit_ast.parser': ('"""Recursive-descent parser: token stream -> AST (see :mod:`unprom.ast_nodes`).\n\nTargets Lua 5.1 grammar (what Prometheus emits by default) plus:\n  * ``goto`` / ``::label::``           (Lua 5.2)\n  * bitwise ``& | ~ << >>`` and ``//``  (Lua 5.3 - accepted, low precedence)\n  * ``continue`` as a statement          (Luau)\n  * compound assignment ``+= -= ...``    (Luau)\n"""\n\nfrom __future__ import annotations\n\nfrom typing import List, Optional\n\nfrom .lexer import Token, tokenize, LuaSyntaxError\nfrom . import ast_nodes as A\n\n\n# name -> (left binding power, right binding power); right < left => right assoc\n_BINPRI = {\n    "or": (1, 2), "and": (3, 4),\n    "<": (5, 6), ">": (5, 6), "<=": (5, 6), ">=": (5, 6), "~=": (5, 6), "==": (5, 6),\n    "|": (7, 8), "~": (9, 10), "&": (11, 12),\n    "<<": (13, 14), ">>": (13, 14),\n    "..": (18, 17),                       # right assoc\n    "+": (19, 20), "-": (19, 20),\n    "*": (21, 22), "/": (21, 22), "//": (21, 22), "%": (21, 22),\n    "^": (28, 27),                        # right assoc, binds tighter than unary\n}\n_UNARY_PRI = 25\n_UNARY_OPS = {"not", "-", "#", "~"}\n\n\nclass Parser:\n    def __init__(self, tokens: List[Token]):\n        self.toks = tokens\n        self.p = 0\n\n    # -- token helpers --------------------------------------------------\n    @property\n    def cur(self) -> Token:\n        return self.toks[self.p]\n\n    def _next(self) -> Token:\n        t = self.toks[self.p]\n        if t.type != "EOF":\n            self.p += 1\n        return t\n\n    def _check(self, type_: str, value: Optional[str] = None) -> bool:\n        t = self.cur\n        if t.type != type_:\n            return False\n        if value is not None and t.value != value:\n            return False\n        return True\n\n    def _accept(self, type_: str, value: Optional[str] = None) -> Optional[Token]:\n        if self._check(type_, value):\n            return self._next()\n        return None\n\n    def _expect(self, type_: str, value: Optional[str] = None) -> Token:\n        if not self._check(type_, value):\n            want = value or type_\n            got = self.cur\n            raise LuaSyntaxError(\n                f"expected {want!r} but got {got.type}:{got.value!r} "\n                f"at line {got.line} col {got.col}")\n        return self._next()\n\n    def _is_kw(self, *words: str) -> bool:\n        return self.cur.type == "KEYWORD" and self.cur.value in words\n\n    def _is_op(self, *ops: str) -> bool:\n        return self.cur.type == "OP" and self.cur.value in ops\n\n    # -- entry --------------------------------------------------------\n    def parse_chunk(self) -> A.Chunk:\n        blk = self._block()\n        self._expect("EOF")\n        return A.Chunk(body=blk, line=1)\n\n    # -- blocks -----------------------------------------------------------\n    _BLOCK_END = {"end", "else", "elseif", "until"}\n\n    def _at_block_end(self) -> bool:\n        if self.cur.type == "EOF":\n            return True\n        if self.cur.type == "KEYWORD" and self.cur.value in self._BLOCK_END:\n            return True\n        return False\n\n    def _block(self) -> A.Block:\n        line = self.cur.line\n        stmts: List[A.Node] = []\n        while not self._at_block_end():\n            if self._is_kw("return"):\n                stmts.append(self._return_stat())\n                break\n            s = self._statement()\n            if s is not None:\n                stmts.append(s)\n        return A.Block(stmts=stmts, line=line)\n\n    def _return_stat(self) -> A.Return:\n        line = self._next().line  # \'return\'\n        values: List[A.Node] = []\n        if not self._at_block_end() and not self._is_op(";"):\n            values = self._exprlist()\n        self._accept("OP", ";")\n        return A.Return(values=values, line=line)\n\n    # -- statements -----------------------------------------------------\n    def _statement(self) -> Optional[A.Node]:\n        t = self.cur\n        line = t.line\n\n        if self._accept("OP", ";"):\n            return None\n\n        if self._accept("OP", "::"):\n            name = self._expect("NAME").value\n            self._expect("OP", "::")\n            return A.Label(name=name, line=line)\n\n        if t.type == "KEYWORD":\n            kw = t.value\n            if kw == "break":\n                self._next()\n                return A.Break(line=line)\n            if kw == "goto":\n                self._next()\n                return A.Goto(label=self._expect("NAME").value, line=line)\n            if kw == "do":\n                self._next()\n                body = self._block()\n                self._expect("KEYWORD", "end")\n                return A.Do(body=body, line=line)\n            if kw == "while":\n                self._next()\n                cond = self._expr()\n                self._expect("KEYWORD", "do")\n                body = self._block()\n                self._expect("KEYWORD", "end")\n                return A.While(cond=cond, body=body, line=line)\n            if kw == "repeat":\n                self._next()\n                body = self._block()\n                self._expect("KEYWORD", "until")\n                cond = self._expr()\n                return A.Repeat(body=body, cond=cond, line=line)\n            if kw == "if":\n                return self._if_stat()\n            if kw == "for":\n                return self._for_stat()\n            if kw == "function":\n                return self._function_stat()\n            if kw == "local":\n                return self._local_stat()\n\n        # Luau soft keyword\n        if t.type == "NAME" and t.value == "continue" and self._looks_like_continue():\n            self._next()\n            return A.Continue(line=line)\n\n        return self._expr_stat()\n\n    def _looks_like_continue(self) -> bool:\n        nxt = self.toks[self.p + 1]\n        if nxt.type == "EOF":\n            return True\n        if nxt.type == "KEYWORD" and nxt.value in self._BLOCK_END:\n            return True\n        if nxt.type == "OP" and nxt.value == ";":\n            return True\n        # \'continue\' followed by another statement-starting name/keyword on a\n        # fresh line is still ambiguous; treat as continue only in the safe set.\n        return nxt.type == "KEYWORD" and nxt.value in {\n            "if", "for", "while", "do", "local", "return", "repeat", "break"}\n\n    def _if_stat(self) -> A.If:\n        line = self._next().line  # \'if\'\n        clauses = []\n        cond = self._expr()\n        self._expect("KEYWORD", "then")\n        clauses.append((cond, self._block()))\n        while self._is_kw("elseif"):\n            self._next()\n            c = self._expr()\n            self._expect("KEYWORD", "then")\n            clauses.append((c, self._block()))\n        orelse = None\n        if self._accept("KEYWORD", "else"):\n            orelse = self._block()\n        self._expect("KEYWORD", "end")\n        return A.If(clauses=clauses, orelse=orelse, line=line)\n\n    def _for_stat(self) -> A.Node:\n        line = self._next().line  # \'for\'\n        first = self._expect("NAME").value\n        if self._accept("OP", "="):\n            start = self._expr()\n            self._expect("OP", ",")\n            stop = self._expr()\n            step = None\n            if self._accept("OP", ","):\n                step = self._expr()\n            self._expect("KEYWORD", "do")\n            body = self._block()\n            self._expect("KEYWORD", "end")\n            return A.NumericFor(var=A.Name(name=first, line=line), start=start,\n                                stop=stop, step=step, body=body, line=line)\n        names = [A.Name(name=first, line=line)]\n        while self._accept("OP", ","):\n            names.append(A.Name(name=self._expect("NAME").value, line=line))\n        self._expect("KEYWORD", "in")\n        exprs = self._exprlist()\n        self._expect("KEYWORD", "do")\n        body = self._block()\n        self._expect("KEYWORD", "end")\n        return A.GenericFor(names=names, exprs=exprs, body=body, line=line)\n\n    def _funcname(self):\n        line = self.cur.line\n        node: A.Node = A.Name(name=self._expect("NAME").value, line=line)\n        while self._accept("OP", "."):\n            key = self._expect("NAME").value\n            node = A.Index(obj=node, key=A.String(value=key), dot=True, line=line)\n        is_method = False\n        if self._accept("OP", ":"):\n            key = self._expect("NAME").value\n            node = A.Index(obj=node, key=A.String(value=key), dot=True, line=line)\n            is_method = True\n        return node, is_method\n\n    def _function_stat(self) -> A.FunctionDecl:\n        line = self._next().line  # \'function\'\n        target, is_method = self._funcname()\n        func = self._funcbody(line, implicit_self=is_method)\n        return A.FunctionDecl(target=target, is_method=is_method, func=func, line=line)\n\n    def _funcbody(self, line: int, implicit_self: bool = False) -> A.Function:\n        self._expect("OP", "(")\n        params: List[A.Name] = []\n        if implicit_self:\n            params.append(A.Name(name="self", line=line))\n        is_vararg = False\n        if not self._is_op(")"):\n            while True:\n                if self._accept("OP", "..."):\n                    is_vararg = True\n                    break\n                params.append(A.Name(name=self._expect("NAME").value, line=line))\n                if not self._accept("OP", ","):\n                    break\n        self._expect("OP", ")")\n        # Luau return-type annotation:  ): Type\n        if self._accept("OP", ":"):\n            self._skip_type()\n        body = self._block()\n        self._expect("KEYWORD", "end")\n        return A.Function(params=params, is_vararg=is_vararg, body=body, line=line)\n\n    def _local_stat(self) -> A.Node:\n        line = self._next().line  # \'local\'\n        if self._accept("KEYWORD", "function"):\n            name = A.Name(name=self._expect("NAME").value, line=line)\n            func = self._funcbody(line)\n            return A.LocalFunction(name=name, func=func, line=line)\n        targets: List[A.Name] = []\n        attribs: List[Optional[str]] = []\n        while True:\n            targets.append(A.Name(name=self._expect("NAME").value, line=line))\n            attr = None\n            if self._accept("OP", "<"):\n                attr = self._expect("NAME").value\n                self._expect("OP", ">")\n            elif self._accept("OP", ":"):\n                self._skip_type()\n            attribs.append(attr)\n            if not self._accept("OP", ","):\n                break\n        values: List[A.Node] = []\n        if self._accept("OP", "="):\n            values = self._exprlist()\n        return A.LocalAssign(targets=targets, values=values, attribs=attribs, line=line)\n\n    def _skip_type(self):\n        """Best-effort skip of a Luau type expression after \':\'."""\n        depth = 0\n        while True:\n            t = self.cur\n            if t.type == "EOF":\n                return\n            if t.type == "OP" and t.value in "([{":\n                depth += 1\n                self._next()\n                continue\n            if t.type == "OP" and t.value in ")]}":\n                if depth == 0:\n                    return\n                depth -= 1\n                self._next()\n                continue\n            if depth == 0:\n                if t.type == "OP" and t.value in {",", "="}:\n                    return\n                if t.type == "KEYWORD" and t.value in {\n                        "do", "then", "end", "return", "local", "if", "while",\n                        "for", "function", "repeat"}:\n                    return\n                if t.type == "OP" and t.value == ";":\n                    return\n            self._next()\n\n    def _expr_stat(self) -> A.Node:\n        line = self.cur.line\n        first = self._suffixed_expr()\n        if self._is_op("=", ",", "+=", "-=", "*=", "/=", "//=", "%=", "^=", "..="):\n            if self.cur.value in ("+=", "-=", "*=", "/=", "//=", "%=", "^=", "..="):\n                op = self._next().value[:-1]\n                val = self._expr()\n                return A.CompoundAssign(op=op, target=first, value=val, line=line)\n            targets = [first]\n            while self._accept("OP", ","):\n                targets.append(self._suffixed_expr())\n            self._expect("OP", "=")\n            values = self._exprlist()\n            return A.Assign(targets=targets, values=values, line=line)\n        if not isinstance(first, (A.Call, A.MethodCall)):\n            raise LuaSyntaxError(\n                f"syntax error near line {line}: expression statement is not a call")\n        return A.CallStat(call=first, line=line)\n\n    # -- expressions --------------------------------------------------\n    def _exprlist(self) -> List[A.Node]:\n        exprs = [self._expr()]\n        while self._accept("OP", ","):\n            exprs.append(self._expr())\n        return exprs\n\n    def _expr(self, min_bp: int = 0) -> A.Node:\n        line = self.cur.line\n        # prefix / unary\n        if self._is_op("-", "#", "~") or self._is_kw("not"):\n            op = self._next().value\n            operand = self._expr(_UNARY_PRI)\n            left: A.Node = A.UnOp(op=op, operand=operand, line=line)\n        else:\n            left = self._simple_expr()\n\n        while True:\n            t = self.cur\n            opname = None\n            if t.type == "OP" and t.value in _BINPRI:\n                opname = t.value\n            elif t.type == "KEYWORD" and t.value in ("and", "or"):\n                opname = t.value\n            if opname is None:\n                break\n            lbp, rbp = _BINPRI[opname]\n            if lbp < min_bp:\n                break\n            self._next()\n            right = self._expr(rbp)\n            left = A.BinOp(op=opname, left=left, right=right, line=line)\n        return left\n\n    def _simple_expr(self) -> A.Node:\n        t = self.cur\n        line = t.line\n        if t.type == "NUMBER":\n            self._next()\n            return A.Number(value=_num(t.value), raw=t.value, line=line)\n        if t.type == "STRING":\n            self._next()\n            return A.String(value=t.value, raw=t.raw, line=line)\n        if t.type == "KEYWORD":\n            if t.value == "nil":\n                self._next(); return A.Nil(line=line)\n            if t.value == "true":\n                self._next(); return A.TrueExpr(line=line)\n            if t.value == "false":\n                self._next(); return A.FalseExpr(line=line)\n            if t.value == "function":\n                self._next()\n                return self._funcbody(line)\n        if self._is_op("..."):\n            self._next()\n            return A.Vararg(line=line)\n        if self._is_op("{"):\n            return self._table()\n        return self._suffixed_expr()\n\n    def _primary_expr(self) -> A.Node:\n        t = self.cur\n        line = t.line\n        if self._accept("OP", "("):\n            inner = self._expr()\n            self._expect("OP", ")")\n            return A.Paren(inner=inner, line=line)\n        if t.type == "NAME":\n            self._next()\n            return A.Name(name=t.value, line=line)\n        raise LuaSyntaxError(\n            f"unexpected symbol {t.type}:{t.value!r} at line {t.line} col {t.col}")\n\n    def _suffixed_expr(self) -> A.Node:\n        node = self._primary_expr()\n        while True:\n            t = self.cur\n            line = t.line\n            if self._accept("OP", "."):\n                key = self._expect("NAME").value\n                node = A.Index(obj=node, key=A.String(value=key), dot=True, line=line)\n            elif self._accept("OP", "["):\n                key = self._expr()\n                self._expect("OP", "]")\n                node = A.Index(obj=node, key=key, dot=False, line=line)\n            elif self._accept("OP", ":"):\n                method = self._expect("NAME").value\n                args = self._call_args()\n                node = A.MethodCall(obj=node, method=method, args=args, line=line)\n            elif t.type == "OP" and t.value in ("(", "{"):\n                node = A.Call(func=node, args=self._call_args(), line=line)\n            elif t.type == "STRING":\n                self._next()\n                node = A.Call(func=node,\n                              args=[A.String(value=t.value, raw=t.raw, line=line)],\n                              line=line)\n            else:\n                break\n        return node\n\n    def _call_args(self) -> List[A.Node]:\n        t = self.cur\n        if t.type == "STRING":\n            self._next()\n            return [A.String(value=t.value, raw=t.raw, line=t.line)]\n        if self._is_op("{"):\n            return [self._table()]\n        self._expect("OP", "(")\n        args: List[A.Node] = []\n        if not self._is_op(")"):\n            args = self._exprlist()\n        self._expect("OP", ")")\n        return args\n\n    def _table(self) -> A.Table:\n        line = self._expect("OP", "{").line\n        flds = []\n        while not self._is_op("}"):\n            if self._is_op("["):\n                self._next()\n                key = self._expr()\n                self._expect("OP", "]")\n                self._expect("OP", "=")\n                val = self._expr()\n                flds.append(("expr", key, val))\n            elif self.cur.type == "NAME" and self.toks[self.p + 1].type == "OP" \\\n                    and self.toks[self.p + 1].value == "=":\n                key = self._next().value\n                self._next()  # \'=\'\n                val = self._expr()\n                flds.append(("name", key, val))\n            else:\n                flds.append(("pos", None, self._expr()))\n            if not (self._accept("OP", ",") or self._accept("OP", ";")):\n                break\n        self._expect("OP", "}")\n        return A.Table(fields=flds, line=line)\n\n\ndef _num(text: str) -> float:\n    s = text.strip().replace("_", "")\n    try:\n        if s[:2].lower() == "0b":\n            return float(int(s, 2))\n        if s[:2].lower() == "0x":\n            if any(c in s.lower() for c in ".p"):\n                return float.fromhex(s)\n            return float(int(s, 16))\n        return float(s)\n    except ValueError:\n        try:\n            return float.fromhex(s)\n        except ValueError:\n            return float("nan")\n\n\ndef parse(src: str) -> A.Chunk:\n    return Parser(tokenize(src)).parse_chunk()\n', False), '_lelsploit_ast.passes': ('', True), '_lelsploit_ast.passes.anti_tamper': ('"""Strip the ``AntiTamper`` prelude.\n\nAntiTamper injects a single ``do ... end`` block at the very top of the script.\nIt is pure runtime self-checking with no effect on program output, so we drop\nany top-level ``do`` block that carries its fingerprints ("Tamper Detected!",\nthe debug.sethook dance, ``repeat until valid``).\n"""\n\nfrom __future__ import annotations\n\nfrom .. import ast_nodes as A\n\n\n_MARKERS = ("Tamper Detected", "Tamper detected")\n\n\ndef _has_marker_string(node: A.Node) -> bool:\n    for n in A.walk(node):\n        if isinstance(n, A.String) and any(m in n.value for m in _MARKERS):\n            return True\n    return False\n\n\ndef _looks_like_anti_tamper(do: A.Do) -> bool:\n    if _has_marker_string(do):\n        return True\n    # Fallback fingerprint: `repeat until <name>` plus a `debug` reference plus\n    # the 2^45 modulus constant that shows up nowhere else.\n    names = {n.name for n in A.walk(do) if isinstance(n, A.Name)}\n    has_repeat_until = any(\n        isinstance(n, A.Repeat) and isinstance(n.cond, A.Name) for n in A.walk(do))\n    has_debug = "debug" in names or "sethook" in names or "getinfo" in names\n    return has_repeat_until and has_debug\n\n\ndef run(chunk: A.Chunk, ctx) -> A.Chunk:\n    kept = []\n    removed = 0\n    for st in chunk.body.stmts:\n        if isinstance(st, A.Do) and _looks_like_anti_tamper(st):\n            removed += 1\n            continue\n        kept.append(st)\n    if removed:\n        chunk.body.stmts = kept\n        ctx.bump("anti_tamper_blocks_removed", removed)\n        ctx.note(f"[anti_tamper] removed {removed} tamper-check block(s)")\n    return chunk\n', False), '_lelsploit_ast.passes.cleanup': ('"""Cosmetic tidying that is always safe.\n\n  * inline ``do ... end`` blocks that declare no locals of their own\n  * drop unused ``local x = <side-effect-free>`` declarations\n"""\n\nfrom __future__ import annotations\n\nfrom .. import ast_nodes as A\nfrom ..astutil import count_binding_uses\nfrom ..scope import resolve\n\n\n_PURE = (A.Number, A.String, A.Nil, A.TrueExpr, A.FalseExpr, A.Name,\n         A.Function, A.Vararg)\n\n\ndef _is_pure(expr: A.Node) -> bool:\n    if isinstance(expr, _PURE):\n        return True\n    if isinstance(expr, A.Paren):\n        return _is_pure(expr.inner)\n    if isinstance(expr, (A.BinOp,)):\n        return _is_pure(expr.left) and _is_pure(expr.right)\n    if isinstance(expr, A.UnOp):\n        return _is_pure(expr.operand)\n    if isinstance(expr, A.Table):\n        return all(_is_pure(v) and (k is None or not isinstance(k, A.Node) or _is_pure(k))\n                   for _kind, k, v in expr.fields)\n    return False\n\n\nclass _InlineDo(A.NodeTransformer):\n    def __init__(self, ctx):\n        self.ctx = ctx\n\n    def _declares_local(self, block: A.Block) -> bool:\n        for st in block.stmts:\n            if isinstance(st, (A.LocalAssign, A.LocalFunction, A.Label)):\n                return True\n        return False\n\n    def visit_Block(self, node: A.Block):\n        node = self.generic_visit(node)\n        out = []\n        for st in node.stmts:\n            if isinstance(st, A.Do) and not self._declares_local(st.body):\n                out.extend(st.body.stmts)\n                self.ctx.bump("do_blocks_inlined")\n            else:\n                out.append(st)\n        node.stmts = _merge_decl_assign(out, self.ctx)\n        return node\n\n\ndef _merge_decl_assign(stmts, ctx):\n    """`local x`  immediately followed by  `x = <expr>`  ->  `local x = <expr>`\n    (only for a single, un-initialised name and a plain-Name assignment)."""\n    out = []\n    i = 0\n    while i < len(stmts):\n        s = stmts[i]\n        nxt = stmts[i + 1] if i + 1 < len(stmts) else None\n        if isinstance(s, A.LocalAssign) and len(s.targets) == 1 and not s.values \\\n                and isinstance(nxt, A.Assign) and len(nxt.targets) == 1 \\\n                and len(nxt.values) == 1 \\\n                and isinstance(nxt.targets[0], A.Name) \\\n                and nxt.targets[0].name == s.targets[0].name \\\n                and not _mentions(nxt.values[0], s.targets[0].name):\n            out.append(A.LocalAssign(targets=s.targets, values=[nxt.values[0]],\n                                     attribs=s.attribs))\n            ctx.bump("decl_assign_merged")\n            i += 2\n            continue\n        out.append(s)\n        i += 1\n    return out\n\n\ndef _mentions(node: A.Node, name: str) -> bool:\n    return any(isinstance(n, A.Name) and n.name == name for n in A.walk(node))\n\n\ndef _drop_unused_locals(chunk: A.Chunk, ctx) -> bool:\n    resolve(chunk)\n    changed = False\n\n    class _Drop(A.NodeTransformer):\n        def visit_LocalAssign(self, node: A.LocalAssign):\n            node = self.generic_visit(node)\n            if not node.targets or len(node.targets) != len(node.values):\n                return node\n            keep_t, keep_v = [], []\n            for t, v in zip(node.targets, node.values):\n                uses = count_binding_uses(chunk, t.binding)\n                if uses <= 1 and _is_pure(v):\n                    nonlocal changed\n                    changed = True\n                    ctx.bump("unused_locals_removed")\n                    continue\n                keep_t.append(t)\n                keep_v.append(v)\n            if not keep_t:\n                return None\n            node.targets, node.values = keep_t, keep_v\n            return node\n\n    chunk2 = _Drop().visit(chunk)\n    chunk.body = chunk2.body\n    return changed\n\n\ndef run(chunk: A.Chunk, ctx) -> A.Chunk:\n    chunk = _InlineDo(ctx).visit(chunk)\n    for _ in range(5):\n        if not _drop_unused_locals(chunk, ctx):\n            break\n    return chunk\n', False), '_lelsploit_ast.passes.constant_array': ('"""Reverse ``ConstantArray``.\n\nHandles the common configuration (global wrapper function, optional array\nrotation, optional base64 string encoding).  Local wrapper tables\n(``LocalWrapperCount > 0``) are not yet undone -- a note is emitted if they are\ndetected.\n\nObfuscated shape::\n\n    local ARR = { <b64 or raw literals> }\n    for i, v in ipairs({{1, LEN}, {1, SHIFT}, {SHIFT + 1, LEN}}) do ... end   -- optional\n    local function W(a) return ARR[a - OFFSET] end\n    do <base64 decode loop over ARR> end                                     -- optional\n    ...  W(<index>)  ...   -- every extracted constant\n"""\n\nfrom __future__ import annotations\n\nfrom typing import List, Optional\n\nfrom .. import ast_nodes as A\nfrom ..astutil import as_int, as_string, binding_of, name_of, unparen\nfrom ..evaluator import const_value\nfrom ..scope import resolve\n\n\n# -- structural finders ---------------------------------------------------\ndef _find_const_array(chunk: A.Chunk):\n    for st in chunk.body.stmts:\n        if not (isinstance(st, A.LocalAssign) and len(st.targets) == 1\n                and len(st.values) == 1):\n            continue\n        tbl = unparen(st.values[0])\n        if not isinstance(tbl, A.Table) or not tbl.fields:\n            continue\n        vals = []\n        ok = True\n        for kind, _key, v in tbl.fields:\n            if kind != "pos":\n                ok = False\n                break\n            cok, cv = const_value(v)\n            if not cok:\n                ok = False\n                break\n            vals.append(cv)\n        if ok and len(vals) >= 2:\n            return st, st.targets[0].binding, vals\n    return None\n\n\ndef _find_wrapper(chunk: A.Chunk, arr_bind: int):\n    def match_fn(fn: A.Function):\n        if len(fn.params) < 1 or not fn.body.stmts:\n            return None\n        body = [s for s in fn.body.stmts]\n        if len(body) != 1 or not isinstance(body[0], A.Return) \\\n                or len(body[0].values) != 1:\n            return None\n        idx = unparen(body[0].values[0])\n        if not isinstance(idx, A.Index) or binding_of(idx.obj) != arr_bind:\n            return None\n        expr = unparen(idx.key)\n        if not isinstance(expr, A.BinOp) or expr.op not in ("+", "-"):\n            return None\n        p0 = fn.params[0].binding\n        off = as_int(expr.right)\n        if binding_of(expr.left) != p0 or off is None:\n            return None\n        return -off if expr.op == "-" else off\n\n    for st in chunk.body.stmts:\n        if isinstance(st, A.LocalFunction):\n            off = match_fn(st.func)\n            if off is not None:\n                return st, st.name.binding, off\n        if isinstance(st, A.LocalAssign) and len(st.targets) == 1 \\\n                and len(st.values) == 1 and isinstance(unparen(st.values[0]), A.Function):\n            off = match_fn(unparen(st.values[0]))\n            if off is not None:\n                return st, st.targets[0].binding, off\n    return None\n\n\ndef _find_rotate_loop(chunk: A.Chunk, arr_bind: int):\n    for st in chunk.body.stmts:\n        if not isinstance(st, A.GenericFor) or len(st.exprs) != 1:\n            continue\n        call = unparen(st.exprs[0])\n        if not (isinstance(call, A.Call) and name_of(call.func) == "ipairs"\n                and len(call.args) == 1):\n            continue\n        outer = unparen(call.args[0])\n        if not isinstance(outer, A.Table) or len(outer.fields) != 3:\n            continue\n        pairs = []\n        for kind, _k, v in outer.fields:\n            v = unparen(v)\n            if kind != "pos" or not isinstance(v, A.Table) or len(v.fields) != 2:\n                pairs = None\n                break\n            a = as_int(v.fields[0][2])\n            b = as_int(v.fields[1][2])\n            pairs.append((a, b))\n        if not pairs:\n            continue\n        # {{1, LEN}, {1, SHIFT}, {SHIFT+1, LEN}}\n        (a1, length), (a2, shift), (a3, length3) = pairs\n        if a1 == 1 and a2 == 1 and shift is not None and length is not None \\\n                and a3 == shift + 1 and length3 == length \\\n                and _mentions_binding(st.body, arr_bind):\n            return st, shift, length\n    return None\n\n\ndef _find_decode_block(chunk: A.Chunk, arr_bind: int):\n    for st in chunk.body.stmts:\n        if not isinstance(st, A.Do):\n            continue\n        if not _mentions_binding(st, arr_bind):\n            continue\n        # the base64 loop divides by 65536 / raises 64 ^ (3 - k); those magic\n        # numbers may still be obfuscated arithmetic, so evaluate.\n        nums = set()\n        for n in A.walk(st):\n            if isinstance(n, (A.Number, A.BinOp, A.UnOp)):\n                v = as_int(n)\n                if v is not None:\n                    nums.add(v)\n        if 65536 not in nums and 64 not in nums:\n            continue\n        alphabet = _extract_alphabet(st)\n        if alphabet:\n            return st, alphabet\n        return st, None          # decode block present but alphabet unreadable\n    return None\n\n\ndef _has_decode_block(chunk: A.Chunk, arr_bind: int) -> bool:\n    for st in chunk.body.stmts:\n        if isinstance(st, A.Do) and _mentions_binding(st, arr_bind):\n            for n in A.walk(st):\n                if isinstance(n, A.Name) and n.name in (\n                        "char", "byte", "sub", "gmatch") :\n                    return True\n            txt = {as_string(x) for x in A.walk(st) if isinstance(x, A.String)}\n            if any(t == "=" for t in txt):        # base64 padding check\n                return True\n    return False\n\n\ndef _extract_alphabet(node: A.Node) -> Optional[str]:\n    for n in A.walk(node):\n        if not isinstance(n, A.Table) or len(n.fields) < 32:\n            continue\n        pos = {}\n        ok = True\n        for kind, key, val in n.fields:\n            k = as_string(key) if isinstance(key, A.Node) else (\n                key if isinstance(key, str) else None)\n            iv = as_int(val)\n            if k is None or len(k) != 1 or iv is None:\n                ok = False\n                break\n            pos[iv] = k\n        if ok and len(pos) >= 64 and set(range(64)) <= set(pos):\n            return "".join(pos[i] for i in range(64))\n    return None\n\n\ndef _mentions_binding(node: A.Node, binding: int) -> bool:\n    return any(isinstance(n, A.Name) and n.binding == binding for n in A.walk(node))\n\n\n# -- data transforms ----------------------------------------------------\ndef _reverse(t: List, i: int, j: int):\n    while i < j:\n        t[i], t[j] = t[j], t[i]\n        i += 1\n        j -= 1\n\n\ndef _rotate(t: List, shift: int):\n    n = len(t)\n    if n == 0:\n        return\n    shift %= n\n    _reverse(t, 0, n - 1)\n    _reverse(t, 0, shift - 1)\n    _reverse(t, shift, n - 1)\n\n\ndef _b64decode(data: str, alphabet: str) -> str:\n    lookup = {c: i for i, c in enumerate(alphabet)}\n    out = bytearray()\n    value = 0\n    count = 0\n    i = 0\n    n = len(data)\n    while i < n:\n        ch = data[i]\n        code = lookup.get(ch)\n        if code is not None:\n            value += code * (64 ** (3 - count))\n            count += 1\n            if count == 4:\n                count = 0\n                out.append(value // 65536)\n                out.append(value % 65536 // 256)\n                out.append(value % 256)\n                value = 0\n        elif ch == "=":\n            out.append(value // 65536)\n            if i + 1 >= n or data[i + 1] != "=":\n                out.append(value % 65536 // 256)\n            break\n        i += 1\n    return out.decode("latin-1")\n\n\n# -- main ---------------------------------------------------------------\nclass _Rewrite(A.NodeTransformer):\n    def __init__(self, w_bind, off, values, ctx):\n        self.w_bind = w_bind\n        self.off = off\n        self.values = values\n        self.ctx = ctx\n\n    def visit_Call(self, node: A.Call):\n        node = self.generic_visit(node)\n        if binding_of(node.func) != self.w_bind or len(node.args) != 1:\n            return node\n        arg = as_int(node.args[0])\n        if arg is None:\n            return node\n        real = arg + self.off            # off is signed: ARR[a + off]\n        idx = real - 1\n        if 0 <= idx < len(self.values):\n            v = self.values[idx]\n            self.ctx.bump("constants_inlined")\n            if isinstance(v, str):\n                return A.String(value=v, line=node.line)\n            if isinstance(v, float):\n                return A.Number(value=v, line=node.line)\n            if isinstance(v, bool):\n                return A.TrueExpr() if v else A.FalseExpr()\n        return node\n\n\ndef run(chunk: A.Chunk, ctx) -> A.Chunk:\n    resolve(chunk)\n    found = _find_const_array(chunk)\n    if not found:\n        return chunk\n    arr_stmt, arr_bind, values = found\n    wrap = _find_wrapper(chunk, arr_bind)\n    if not wrap:\n        ctx.note("[constant_array] found array but no wrapper function; skipped")\n        return chunk\n    wrap_stmt, w_bind, off = wrap\n\n    rot = _find_rotate_loop(chunk, arr_bind)\n    dec = _find_decode_block(chunk, arr_bind)\n\n    # Local hardening: only the recognized setup and accessor may reference\n    # the array. A banner is not evidence that removing arbitrary uses is safe.\n    allowed = {id(n) for st in [arr_stmt, wrap_stmt] + ([rot[0]] if rot else []) + ([dec[0]] if dec else []) for n in A.walk(st)}\n    for n in A.walk(chunk):\n        if isinstance(n, A.Name) and n.binding == arr_bind and id(n) not in allowed:\n            ctx.note("[constant_array] unmatched array use; preserved")\n            return chunk\n    resolved = resolve(chunk)\n    if resolved.bindings[w_bind].writes:\n        return chunk\n    call_names = {id(n.func) for n in A.walk(chunk) if isinstance(n, A.Call)}\n    if any(id(use) not in call_names for use in resolved.bindings[w_bind].uses):\n        return chunk\n    if rot and any(isinstance(n, (A.Call, A.MethodCall, A.Function)) for n in A.walk(rot[0].body)):\n        ctx.note("[constant_array] rotation has additional calls; preserved")\n        return chunk\n\n    # If the array is base64-encoded but we can\'t read the alphabet, inlining\n    # would produce garbage strings - leave the whole thing intact instead.\n    if dec and dec[1] is None:\n        ctx.note("[constant_array] base64 alphabet unreadable; leaving array, "\n                 "decoder and wrapper in place")\n        return chunk\n    if not dec and _has_decode_block(chunk, arr_bind):\n        ctx.note("[constant_array] a decoder block was detected but not matched; "\n                 "leaving array, decoder and wrapper in place")\n        return chunk\n\n    if rot:\n        _rotate(values, rot[1])\n        ctx.note(f"[constant_array] replayed rotation shift={rot[1]}")\n    if dec:\n        values = [_b64decode(v, dec[1]) if isinstance(v, str) else v\n                  for v in values]\n        ctx.note("[constant_array] base64-decoded array entries")\n\n    chunk = _Rewrite(w_bind, off, values, ctx).visit(chunk)\n\n    remaining = sum(\n        1 for n in A.walk(chunk)\n        if isinstance(n, A.Call) and binding_of(n.func) == w_bind)\n    drop = {id(arr_stmt), id(wrap_stmt)}\n    if rot:\n        drop.add(id(rot[0]))\n    if dec:\n        drop.add(id(dec[0]))\n    if remaining > 0:\n        ctx.note(f"[constant_array] {remaining} wrapper call(s) unresolved; "\n                 "keeping array/wrapper")\n        drop = set()\n    chunk.body.stmts = [s for s in chunk.body.stmts if id(s) not in drop]\n    if drop:\n        ctx.note("[constant_array] removed array, wrapper and setup code")\n    return chunk\n', False), '_lelsploit_ast.passes.constant_fold': ('"""Constant folding / partial evaluation.\n\nReverses ``NumbersToExpressions`` (``5`` -> ``2 + 3`` -> ``5`` again) and the\n``strcat`` form of ``SplitStrings`` (``"a" .. "b" .. "c"`` -> ``"abc"``).  Also\nsimplifies constant conditions, ``not not x``, redundant parens and the\n``(cond and A or B)`` ternary when ``cond`` is constant.\n"""\n\nfrom __future__ import annotations\n\nfrom .. import ast_nodes as A\nfrom ..evaluator import const_value, value_to_node, is_truthy, LuaNil\n\n\nclass _Fold(A.NodeTransformer):\n    def __init__(self, ctx):\n        self.ctx = ctx\n        self.changed = False\n\n    # -- expressions ------------------------------------------------\n    def visit_BinOp(self, node: A.BinOp):\n        node.left = self.visit(node.left)\n        node.right = self.visit(node.right)\n\n        ok, val = const_value(node)\n        if ok and _liftable(val):\n            self.changed = True\n            self.ctx.bump("folded_exprs")\n            return _with_line(value_to_node(val), node)\n\n        # (K and A or B)  ->  A or B depending on K, even when A/B aren\'t const\n        if node.op == "or" and isinstance(node.left, A.BinOp) and node.left.op == "and":\n            okc, cond = const_value(node.left.left)\n            if okc:\n                self.changed = True\n                if is_truthy(cond):\n                    oka, _ = const_value(node.left.right)\n                    # A is only the result when A is truthy; keep semantics safe\n                    # by only collapsing when A is a constant-truthy value.\n                    if oka and is_truthy(_):\n                        return node.left.right\n                    return A.BinOp(op="or", left=node.left.right, right=node.right,\n                                   line=node.line)\n                return node.right\n        return node\n\n    def visit_UnOp(self, node: A.UnOp):\n        node.operand = self.visit(node.operand)\n        ok, val = const_value(node)\n        if ok and _liftable(val):\n            self.changed = True\n            self.ctx.bump("folded_exprs")\n            return _with_line(value_to_node(val), node)\n        if node.op == "not" and isinstance(node.operand, A.UnOp) \\\n                and node.operand.op == "not" \\\n                and isinstance(node.operand.operand, A.UnOp) \\\n                and node.operand.operand.op == "not":\n            self.changed = True\n            return node.operand.operand\n        return node\n\n    def visit_Paren(self, node: A.Paren):\n        node.inner = self.visit(node.inner)\n        inner = node.inner\n        # Parens are only semantically meaningful around multi-value exprs.\n        if isinstance(inner, (A.Number, A.String, A.Nil, A.TrueExpr, A.FalseExpr,\n                              A.Name, A.Index, A.Paren)):\n            self.changed = True\n            return inner\n        return node\n\n    # -- statements ------------------------------------------------\n    def visit_If(self, node: A.If):\n        node = self.generic_visit(node)\n        new_clauses = []\n        for cond, body in node.clauses:\n            ok, val = const_value(cond)\n            if ok:\n                if is_truthy(val):\n                    # This clause always fires: everything after is dead.\n                    if not new_clauses:\n                        self.changed = True\n                        return _inline_block(body)\n                    node.orelse = body\n                    node.clauses = new_clauses\n                    return node\n                else:\n                    self.changed = True\n                    continue  # drop this clause\n            new_clauses.append((cond, body))\n        if not new_clauses:\n            self.changed = True\n            return _inline_block(node.orelse) if node.orelse else A.Do(body=A.Block([]))\n        node.clauses = new_clauses\n        return node\n\n    def visit_While(self, node: A.While):\n        node = self.generic_visit(node)\n        ok, val = const_value(node.cond)\n        if ok and not is_truthy(val):\n            self.changed = True\n            return None\n        return node\n\n\ndef _inline_block(block: A.Block):\n    return A.Do(body=block)\n\n\ndef _liftable(v) -> bool:\n    return isinstance(v, (bool, float, str)) or v is LuaNil\n\n\ndef _with_line(new: A.Node, old: A.Node) -> A.Node:\n    new.line = getattr(old, "line", 0)\n    return new\n\n\ndef run(chunk: A.Chunk, ctx) -> A.Chunk:\n    for _ in range(12):\n        f = _Fold(ctx)\n        chunk = f.visit(chunk)\n        if not f.changed:\n            break\n    return chunk\n', False), '_lelsploit_ast.passes.dead_code': ('"""Remove obviously dead code.\n\n  * statements after an unconditional ``return`` / ``break`` in the same block\n  * empty ``do ... end`` blocks\n  * ``if false`` / ``while false`` are handled by :mod:`constant_fold`\n"""\n\nfrom __future__ import annotations\n\nfrom .. import ast_nodes as A\n\n\n_TERMINATORS = (A.Return, A.Break, A.Continue, A.Goto)\n\n\nclass _Dead(A.NodeTransformer):\n    def __init__(self, ctx):\n        self.ctx = ctx\n\n    def _prune_block(self, block: A.Block):\n        out = []\n        for st in block.stmts:\n            out.append(st)\n            if isinstance(st, _TERMINATORS):\n                break\n        if len(out) != len(block.stmts):\n            self.ctx.bump("dead_stmts_removed", len(block.stmts) - len(out))\n        block.stmts = out\n\n    def visit_Block(self, node: A.Block):\n        node = self.generic_visit(node)\n        self._prune_block(node)\n        return node\n\n    def visit_Do(self, node: A.Do):\n        node = self.generic_visit(node)\n        if not node.body.stmts:\n            self.ctx.bump("empty_do_removed")\n            return None\n        return node\n\n    def visit_If(self, node: A.If):\n        node = self.generic_visit(node)\n        # collapse `if c then X else X end` -> X (only when X has no control-flow\n        # effect that depends on the branch and c has no side effects)\n        if len(node.clauses) == 1 and node.orelse is not None \\\n                and _same(node.clauses[0][1].stmts, node.orelse.stmts) \\\n                and not _has_calls(node.clauses[0][0]):\n            self.ctx.bump("identical_if_branches_collapsed")\n            return list(A.clone(node.orelse).stmts)\n        # drop `if c then end` with no bodies (keep c if it may have effects)\n        bodies_empty = all(not b.stmts for _c, b in node.clauses) \\\n            and (node.orelse is None or not node.orelse.stmts)\n        if bodies_empty:\n            keep = [A.CallStat(call=c) for c, _b in node.clauses\n                    if isinstance(c, (A.Call, A.MethodCall))]\n            self.ctx.bump("empty_if_removed")\n            return keep or None\n        return node\n\n\ndef _has_calls(node: A.Node) -> bool:\n    return any(isinstance(n, (A.Call, A.MethodCall)) for n in A.walk(node))\n\n\ndef _same(a, b) -> bool:\n    if len(a) != len(b) or not a:\n        return False\n    try:\n        return _dump(a) == _dump(b)\n    except Exception:  # noqa: BLE001\n        return False\n\n\ndef _dump(stmts) -> str:\n    from ..unparser import Unparser\n    u = Unparser()\n    for s in stmts:\n        u._stat(s)\n    return "\\n".join(u.out)\n\n\ndef run(chunk: A.Chunk, ctx) -> A.Chunk:\n    for _ in range(4):\n        d = _Dead(ctx)\n        chunk = d.visit(chunk)\n    return chunk\n', False), '_lelsploit_ast.passes.devirtualize': ('"""Best-effort handling of the ``Vmify`` step.\n\nFull devirtualisation (lifting the custom bytecode back to the original Lua) is\na research-grade problem and version-specific.  What this pass does instead is\n**de-flatten the VM dispatcher**, which recovers most of the readability:\n\n  * Prometheus compiles every function into numbered *blocks* run by a single\n    ``while pos do ... end`` loop whose body is a balanced binary search tree of\n    ``if pos < K then ... else ... end`` over shuffled block ids.\n  * We reconstruct the block list in order, map the opaque ids to small indices\n    (0, 1, 2, ...), rewrite every ``pos = <id>`` transition accordingly, and\n    replace the search tree with a flat ``if pos == 0 then ... elseif ...``\n    chain.\n\nThe result is the same VM, but with linear, readable dispatch and real block\nnumbers - a much better starting point for manual analysis.  Register locals and\nthe upvalue / closure scaffolding are left intact.  Set the ``devirt`` option to\n``"off"`` to skip this entirely.\n"""\n\nfrom __future__ import annotations\n\nfrom typing import List, Optional, Tuple\n\nfrom .. import ast_nodes as A\nfrom ..astutil import as_int, unparen\n\n\n# --------------------------------------------------------------------------\n# Locating the container function\n# --------------------------------------------------------------------------\ndef _find_container(chunk: A.Chunk) -> Optional[Tuple[A.Function, A.While]]:\n    """A function whose body contains `while <pos> do <search-tree> end` where\n    the search tree is nested `if <pos> < K then ... else ... end`."""\n    best = None\n    for n in A.walk(chunk):\n        if not isinstance(n, A.Function) or n.body is None:\n            continue\n        for st in n.body.stmts:\n            if not isinstance(st, A.While) or not isinstance(st.cond, A.Name):\n                continue\n            pos = st.cond.name\n            leaves = _tree_leaves(st.body, pos)\n            if leaves is None or leaves < 3:\n                continue\n            if best is None or leaves > best[2]:\n                best = (n, st, leaves)\n    if best is None:\n        return None\n    return best[0], best[1]\n\n\ndef _split_if(block: A.Block, pos: str):\n    """Return (bound, left_block, right_block) if `block` is a lone\n    `if pos < K then L else R end`, else None."""\n    if len(block.stmts) != 1:\n        return None\n    st = block.stmts[0]\n    if not (isinstance(st, A.If) and len(st.clauses) == 1 and st.orelse is not None):\n        return None\n    cond = st.clauses[0][0]\n    if not (isinstance(cond, A.BinOp) and cond.op == "<"):\n        return None\n    left = unparen(cond.left)\n    if not (isinstance(left, A.Name) and left.name == pos):\n        return None\n    bound = as_int(cond.right)\n    if bound is None:\n        return None\n    return bound, st.clauses[0][1], st.orelse\n\n\ndef _tree_leaves(block: A.Block, pos: str):\n    sp = _split_if(block, pos)\n    if sp is None:\n        # a straight-line leaf block\n        return 1\n    _bound, l, r = sp\n    ln = _tree_leaves(l, pos)\n    rn = _tree_leaves(r, pos)\n    if ln is None or rn is None:\n        return None\n    return ln + rn\n\n\n# --------------------------------------------------------------------------\n# Flattening the search tree into ordered (bound, block) leaves\n# --------------------------------------------------------------------------\nclass _Leaf:\n    def __init__(self, stmts: List[A.Node]):\n        self.stmts = stmts\n        self.lo = None          # inclusive id lower bound\n        self.hi = None          # exclusive id upper bound\n        self.index = -1\n\n\ndef _collect(block: A.Block, pos: str, leaves: List[_Leaf], seps: List[int]):\n    sp = _split_if(block, pos)\n    if sp is None:\n        leaves.append(_Leaf(list(block.stmts)))\n        return\n    bound, l, r = sp\n    _collect(l, pos, leaves, seps)\n    seps.append(bound)\n    _collect(r, pos, leaves, seps)\n\n\ndef _flatten(wh: A.While):\n    leaves: List[_Leaf] = []\n    seps: List[int] = []\n    _collect(wh.body, wh.cond.name, leaves, seps)\n    # seps has len(leaves)-1 entries, sorted ascending, separating consecutive\n    # leaves: id(leaf i-1) < seps[i-1] <= id(leaf i)\n    bounds = [None] + seps + [None]\n    for i, leaf in enumerate(leaves):\n        leaf.lo = bounds[i]\n        leaf.hi = bounds[i + 1]\n        leaf.index = i\n    return leaves, seps\n\n\ndef _id_to_index(idv: int, seps: List[int]) -> int:\n    lo = 0\n    for i, s in enumerate(seps):\n        if idv < s:\n            return i\n        lo = i + 1\n    return lo\n\n\n# --------------------------------------------------------------------------\n# Rewriting pos transitions\n# --------------------------------------------------------------------------\nclass _Retarget(A.NodeTransformer):\n    def __init__(self, pos_name: str, seps: List[int], nleaves: int, ctx):\n        self.pos = pos_name\n        self.seps = seps\n        self.n = nleaves\n        self.ctx = ctx\n\n    def _map_num(self, node: A.Node) -> A.Node:\n        iv = as_int(node)\n        if iv is None:\n            return node\n        # Only remap plausible block ids (Prometheus uses 0 .. 2^24).\n        if 0 <= iv <= (1 << 24):\n            idx = _id_to_index(iv, self.seps)\n            self.ctx.bump("vm_transitions_remapped")\n            return A.Number(value=float(idx), line=getattr(node, "line", 0))\n        return node\n\n    def visit_Assign(self, node: A.Assign):\n        node = self.generic_visit(node)\n        if len(node.targets) == 1 and isinstance(unparen(node.targets[0]), A.Name) \\\n                and unparen(node.targets[0]).name == self.pos and len(node.values) == 1:\n            node.values[0] = self._map_value(node.values[0])\n        return node\n\n    def _map_value(self, v: A.Node) -> A.Node:\n        v = unparen(v)\n        if isinstance(v, A.Number):\n            return self._map_num(v)\n        if isinstance(v, A.BinOp) and v.op in ("and", "or"):\n            v.left = self._map_value(v.left)\n            v.right = self._map_value(v.right)\n            return v\n        return v\n\n\ndef run(chunk: A.Chunk, ctx) -> A.Chunk:\n    if str(ctx.options.get("devirt", "on")) in ("off", "false", "0"):\n        return chunk\n    found = _find_container(chunk)\n    if not found:\n        return chunk\n    fn, wh = found\n    pos_name = wh.cond.name\n    leaves, seps = _flatten(wh)\n    if len(leaves) < 2:\n        return chunk\n\n    ctx.note(f"[devirtualize] found Prometheus VM container: {len(leaves)} blocks, "\n             f"pos var {pos_name!r}")\n\n    # Remap every `pos = <id>` inside the blocks to a 0-based index.\n    retarget = _Retarget(pos_name, seps, len(leaves), ctx)\n    for leaf in leaves:\n        leaf.stmts = [retarget.visit(s) for s in leaf.stmts]\n\n    # Rebuild the loop body as a flat dispatch chain.\n    clauses = []\n    for leaf in leaves:\n        cond = A.BinOp(op="==", left=A.Name(name=pos_name),\n                       right=A.Number(value=float(leaf.index)))\n        clauses.append((cond, A.Block(stmts=leaf.stmts)))\n    wh.body = A.Block(stmts=[A.If(clauses=clauses, orelse=None)])\n\n    # Remap the VM entry point in the outer `createClosure(<startId>, ...)` call.\n    _remap_entry(chunk, seps, ctx)\n\n    ctx.bump("vm_containers_deflattened")\n    ctx.note("[devirtualize] de-flattened VM dispatch; this is the VM in "\n             "readable form, not lifted source")\n    return chunk\n\n\ndef _remap_entry(chunk: A.Chunk, seps: List[int], ctx):\n    """The top-level `return F(startBlockId, {upvals})(unpack(arg))` -\n    rewrite startBlockId to its 0-based index."""\n    for n in A.walk(chunk):\n        if not isinstance(n, A.Call):\n            continue\n        inner = unparen(n.func)\n        if not (isinstance(inner, A.Call) and len(inner.args) == 2):\n            continue\n        a0 = as_int(inner.args[0])\n        a1 = unparen(inner.args[1])\n        if a0 is not None and 0 <= a0 <= (1 << 24) and isinstance(a1, A.Table):\n            idx = _id_to_index(a0, seps)\n            inner.args[0] = A.Number(value=float(idx))\n            ctx.note(f"[devirtualize] VM entry block = {idx}")\n            return\n', False), '_lelsploit_ast.passes.encrypt_strings': ('"""Reverse ``EncryptStrings``.\n\nObfuscated shape (after Prometheus\' own renamer)::\n\n    local D, S                       -- two locals, declared empty, shuffled order\n    do\n        local function get_next_pseudo_random_byte() ... end   -- keystream lives here\n        S = setmetatable({}, { __index = realStrings, __metatable = nil })\n        function D(str, seed) ... end -- fills realStrings[seed], returns seed\n    end\n    ...  S[D("<cipher>", 123456)] ...  -- every original string literal\n\nThe keystream constants ``param_mul_45`` / ``param_add_45`` (from the\n``(x * K1 + K2) % 35184372088832`` update), ``param_mul_8`` (from\n``state_8 * K % 257``) and ``secret_key_8`` (the ``local prevVal = <n>`` init)\nare baked into the prelude, so every ``S[D(c, seed)]`` becomes a plain literal\nagain.  The ``do`` block and the now-unused ``local D, S`` decl are removed.\n"""\n\nfrom __future__ import annotations\n\nfrom .. import ast_nodes as A\nfrom ..astutil import as_int, binding_of, name_of, unparen\nfrom ..scope import resolve\nfrom ..prng import decrypt\n\n_MOD45 = 35184372088832.0\n\n\ndef _find_seed_modulus(node: A.Node):\n    """Locate ``(x * K1 + K2) % 35184372088832`` -> (K1, K2)."""\n    for n in A.walk(node):\n        if not (isinstance(n, A.BinOp) and n.op == "%"):\n            continue\n        if not (isinstance(unparen(n.right), A.Number)\n                and unparen(n.right).value == _MOD45):\n            continue\n        add = unparen(n.left)\n        if isinstance(add, A.BinOp) and add.op == "+":\n            mul = unparen(add.left)\n            k2 = as_int(add.right)\n            if isinstance(mul, A.BinOp) and mul.op == "*":\n                k1 = as_int(mul.right)\n                if k1 is None:\n                    k1 = as_int(mul.left)\n                if k1 is not None and k2 is not None:\n                    return k1, k2\n    return None\n\n\ndef _find_mul_8(node: A.Node):\n    """``state_8 = state_8 * K % 257`` -> K."""\n    for n in A.walk(node):\n        if isinstance(n, A.BinOp) and n.op == "%":\n            if isinstance(unparen(n.right), A.Number) and unparen(n.right).value == 257.0:\n                mul = unparen(n.left)\n                if isinstance(mul, A.BinOp) and mul.op == "*":\n                    return as_int(mul.right) if as_int(mul.right) is not None \\\n                        else as_int(mul.left)\n    return None\n\n\ndef _find_secret_key_8(node: A.Node):\n    for n in A.walk(node):\n        if isinstance(n, A.LocalAssign) and len(n.values) == 1:\n            v = as_int(n.values[0])\n            if v is not None and 0 <= v <= 255:\n                return v\n    return None\n\n\ndef _strings_binding(do: A.Do):\n    for n in A.walk(do):\n        if isinstance(n, A.Assign) and len(n.values) == 1:\n            v = unparen(n.values[0])\n            if isinstance(v, A.Call) and name_of(v.func) == "setmetatable":\n                return binding_of(n.targets[0])\n    return None\n\n\ndef _decrypt_binding(do: A.Do, outer: set, s_bind):\n    for n in A.walk(do):\n        fn = target = None\n        if isinstance(n, A.FunctionDecl) and not n.is_method:\n            fn, target = n.func, n.target\n        elif isinstance(n, A.Assign) and len(n.values) == 1 \\\n                and isinstance(unparen(n.values[0]), A.Function):\n            fn, target = unparen(n.values[0]), n.targets[0]\n        if fn is None or len(fn.params) < 2:\n            continue\n        b = binding_of(target)\n        if b is not None and b in outer and b != s_bind:\n            return b\n    return None\n\n\ndef _find_prelude(chunk: A.Chunk):\n    stmts = chunk.body.stmts\n    for i in range(len(stmts) - 1):\n        decl, do = stmts[i], stmts[i + 1]\n        if not (isinstance(decl, A.LocalAssign) and len(decl.targets) == 2\n                and not decl.values):\n            continue\n        if not isinstance(do, A.Do):\n            continue\n        seedmod = _find_seed_modulus(do)\n        if seedmod is None:\n            continue\n        outer = {t.binding for t in decl.targets}\n        s_bind = _strings_binding(do)\n        d_bind = _decrypt_binding(do, outer, s_bind)\n        mul8 = _find_mul_8(do)\n        key8 = _find_secret_key_8(do)\n        if None in (s_bind, d_bind, mul8, key8):\n            continue\n        consts = (seedmod[0], seedmod[1], mul8, key8)\n        return decl, do, d_bind, s_bind, consts\n    return None\n\n\nclass _Rewrite(A.NodeTransformer):\n    def __init__(self, s_bind, d_bind, consts, ctx):\n        self.s_bind, self.d_bind, self.consts, self.ctx = s_bind, d_bind, consts, ctx\n        self.failures = 0\n\n    def visit_Index(self, node: A.Index):\n        node = self.generic_visit(node)\n        if binding_of(node.obj) != self.s_bind:\n            return node\n        key = unparen(node.key)\n        if not (isinstance(key, A.Call) and binding_of(key.func) == self.d_bind\n                and len(key.args) == 2):\n            return node\n        cipher = unparen(key.args[0])\n        seed = as_int(key.args[1])\n        if not isinstance(cipher, A.String) or seed is None:\n            return node\n        try:\n            plain = decrypt(cipher.value, seed, *self.consts)\n        except Exception as exc:  # noqa: BLE001\n            self.ctx.note(f"[encrypt_strings] decrypt failed: {exc!r}")\n            self.failures += 1\n            return node\n        self.ctx.bump("strings_decrypted")\n        return A.String(value=plain, line=node.line)\n\n\ndef run(chunk: A.Chunk, ctx) -> A.Chunk:\n    resolve(chunk)\n    found = _find_prelude(chunk)\n    if not found:\n        return chunk\n    decl, do, d_bind, s_bind, consts = found\n    ctx.note(f"[encrypt_strings] keystream consts = {consts}")\n    rw = _Rewrite(s_bind, d_bind, consts, ctx)\n    chunk = rw.visit(chunk)\n\n    inlined = ctx.stats.get("strings_decrypted", 0)\n    # Keep the decoder if even one dynamic access or escaping reference remains.\n    setup_ids={id(n) for st in (decl,do) for n in A.walk(st)}\n    residual=any(isinstance(n,A.Name) and n.binding in (s_bind,d_bind) and id(n) not in setup_ids for n in A.walk(chunk))\n    if inlined and not rw.failures and not residual:\n        chunk.body.stmts = [s for s in chunk.body.stmts\n                            if s is not do and s is not decl]\n        ctx.note(f"[encrypt_strings] inlined {inlined} string(s), removed prelude")\n    else:\n        ctx.note(f"[encrypt_strings] inlined {inlined} string(s); "\n                 f"{rw.failures} failure(s); prelude kept")\n    return chunk\n', False), '_lelsploit_ast.passes.proxify_locals': ('"""Reverse ``ProxifyLocals`` (best effort).\n\nProxifyLocals is not part of any built-in preset, so this pass targets the\ndefault ``LiteralType = "string"`` configuration and the straightforward\ndeclaration / read / write shapes it produces::\n\n    local e = function() end\n    local x = setmetatable({ [VN] = <init> },\n                           { __opG = function(s) return s[VN] end,\n                             __opS = function(s, a) s[VN] = a end })\n    ...  x <opG> "<junk>"      -- a read of x\n    ...  e(x <opS> <value>)    -- a write  x = <value>\n    ...  x[VN] = <value>       -- also a write\n\nAnything that does not match is left untouched.\n"""\n\nfrom __future__ import annotations\n\nfrom typing import Dict, Optional\n\nfrom .. import ast_nodes as A\nfrom ..astutil import binding_of, name_of, unparen\nfrom ..scope import resolve\n\n_META_OP = {\n    "__add": "+", "__sub": "-", "__mul": "*", "__div": "/",\n    "__pow": "^", "__concat": "..",\n}\n\n\nclass _Proxy:\n    __slots__ = ("value_name", "get_op", "set_op", "get_index", "set_index")\n\n    def __init__(self):\n        self.value_name = None\n        self.get_op = None       # operator string, or None when get uses indexing\n        self.set_op = None\n        self.get_index = False\n        self.set_index = False\n\n\ndef _table_fields(t: A.Table):\n    out = {}\n    for kind, key, val in t.fields:\n        if kind == "name":\n            out[key] = val\n        elif kind == "expr":\n            k = key.value if isinstance(key, A.String) else None\n            if k is not None:\n                out[k] = val\n        elif kind == "pos":\n            out.setdefault("__pos__", []).append(val)\n    return out\n\n\ndef _analyse_decl(node: A.LocalAssign) -> Optional[tuple]:\n    if len(node.targets) != 1 or len(node.values) != 1:\n        return None\n    call = unparen(node.values[0])\n    if not (isinstance(call, A.Call) and name_of(call.func) == "setmetatable"\n            and len(call.args) == 2):\n        return None\n    obj, meta = unparen(call.args[0]), unparen(call.args[1])\n    if not (isinstance(obj, A.Table) and isinstance(meta, A.Table)):\n        return None\n    if len(obj.fields) != 1:\n        return None\n    okind, okey, oinit = obj.fields[0]\n    vn = okey if isinstance(okey, str) else (okey.value if isinstance(okey, A.String) else None)\n    if vn is None:\n        return None\n    mf = _table_fields(meta)\n    px = _Proxy()\n    px.value_name = vn\n    for mkey, fn in mf.items():\n        fn = unparen(fn)\n        if not isinstance(fn, A.Function):\n            continue\n        is_getter = _fn_returns_member(fn, vn)\n        is_setter = _fn_assigns_member(fn, vn)\n        if is_getter:\n            if mkey == "__index":\n                px.get_index = True\n            else:\n                px.get_op = _META_OP.get(mkey)\n        elif is_setter:\n            if mkey == "__index" or mkey == "__newindex":\n                px.set_index = True\n            else:\n                px.set_op = _META_OP.get(mkey)\n    if px.get_op is None and not px.get_index:\n        return None\n    return node.targets[0].binding, px, oinit\n\n\ndef _fn_returns_member(fn: A.Function, vn: str) -> bool:\n    for st in A.walk(fn.body):\n        if isinstance(st, A.Return) and len(st.values) == 1:\n            v = unparen(st.values[0])\n            if isinstance(v, A.Index) and _is_member(v, vn):\n                return True\n            if isinstance(v, A.Call) and name_of(v.func) == "rawget" \\\n                    and len(v.args) == 2 and _str_eq(v.args[1], vn):\n                return True\n    return False\n\n\ndef _fn_assigns_member(fn: A.Function, vn: str) -> bool:\n    for st in A.walk(fn.body):\n        if isinstance(st, A.Assign) and len(st.targets) == 1:\n            if isinstance(unparen(st.targets[0]), A.Index) \\\n                    and _is_member(unparen(st.targets[0]), vn):\n                return True\n    return False\n\n\ndef _is_member(idx: A.Index, vn: str) -> bool:\n    return _str_eq(idx.key, vn)\n\n\ndef _str_eq(node: A.Node, s: str) -> bool:\n    node = unparen(node)\n    return isinstance(node, A.String) and node.value == s\n\n\nclass _Rewrite(A.NodeTransformer):\n    def __init__(self, proxies: Dict[int, _Proxy], empty_binding, ctx):\n        self.px = proxies\n        self.empty = empty_binding\n        self.ctx = ctx\n\n    def visit_CallStat(self, node: A.CallStat):\n        node = self.generic_visit(node)\n        call = unparen(node.call)\n        if isinstance(call, A.Call) and binding_of(call.func) == self.empty \\\n                and len(call.args) == 1:\n            inner = unparen(call.args[0])\n            if isinstance(inner, A.BinOp):\n                b = binding_of(inner.left)\n                px = self.px.get(b)\n                if px and inner.op == px.set_op:\n                    self.ctx.bump("proxify_writes")\n                    return A.Assign(targets=[A.Name(name=name_of(inner.left),\n                                                    binding=b)],\n                                    values=[inner.right], line=node.line)\n        return node\n\n    def visit_Assign(self, node: A.Assign):\n        node = self.generic_visit(node)\n        if len(node.targets) == 1:\n            t = unparen(node.targets[0])\n            if isinstance(t, A.Index):\n                b = binding_of(t.obj)\n                px = self.px.get(b)\n                if px and _str_eq(t.key, px.value_name):\n                    self.ctx.bump("proxify_writes")\n                    node.targets = [t.obj]\n        return node\n\n    def visit_BinOp(self, node: A.BinOp):\n        node = self.generic_visit(node)\n        b = binding_of(node.left)\n        px = self.px.get(b)\n        if px and px.get_op and node.op == px.get_op:\n            self.ctx.bump("proxify_reads")\n            return node.left\n        return node\n\n    def visit_Index(self, node: A.Index):\n        node = self.generic_visit(node)\n        b = binding_of(node.obj)\n        px = self.px.get(b)\n        if px and px.get_index and not _str_eq(node.key, px.value_name):\n            # a read via  x[<junk>]\n            self.ctx.bump("proxify_reads")\n            return node.obj\n        return node\n\n\ndef _find_empty_fn(chunk: A.Chunk) -> Optional[int]:\n    for st in chunk.body.stmts:\n        if isinstance(st, A.LocalAssign) and len(st.targets) == 1 \\\n                and len(st.values) == 1:\n            v = unparen(st.values[0])\n            if isinstance(v, A.Function) and not v.body.stmts and not v.params:\n                return st.targets[0].binding\n    return None\n\n\ndef run(chunk: A.Chunk, ctx) -> A.Chunk:\n    resolve(chunk)\n    proxies: Dict[int, _Proxy] = {}\n    inits = {}\n    for n in A.walk(chunk):\n        if isinstance(n, A.LocalAssign):\n            res = _analyse_decl(n)\n            if res:\n                bid, px, init = res\n                proxies[bid] = px\n                inits[bid] = (n, init)\n    if not proxies:\n        return chunk\n    empty_binding = _find_empty_fn(chunk)\n    chunk = _Rewrite(proxies, empty_binding, ctx).visit(chunk)\n\n    # rewrite the declarations themselves:  local x = <init>\n    for bid, (decl, init) in inits.items():\n        decl.values = [init]\n    ctx.note(f"[proxify_locals] unwrapped {len(proxies)} proxied local(s)")\n    return chunk\n', False), '_lelsploit_ast.passes.rename': ('"""Give obfuscated local identifiers readable names.\n\nModes (``ctx.options[\'rename\']``):\n  * ``none`` - do nothing\n  * ``auto`` - rename only names that look machine-generated (default)\n  * ``all``  - rename every local to ``v1``, ``v2`` ...\n\nNew names are globally unique and are checked against every identifier already\npresent in the tree, so renaming can never introduce shadowing.\n"""\n\nfrom __future__ import annotations\n\nimport re\n\nfrom .. import ast_nodes as A\nfrom ..scope import resolve\n\n_OBFUSCATED = [\n    re.compile(r"^_\\d+$"),                 # \'number\' generator  (PREFIX .. id)\n    re.compile(r"^[Il1]{3,}$"),            # \'Il\' generator\n    re.compile(r"^[O0lI1]{4,}$"),\n    re.compile(r"^[A-Za-z_][A-Za-z0-9_]{13,}$"),   # very long mangled\n]\n\n\ndef _looks_obfuscated(name: str) -> bool:\n    if any(p.match(name) for p in _OBFUSCATED):\n        return True\n    if any(ord(c) > 127 for c in name):\n        return True\n    return False\n\n\ndef run(chunk: A.Chunk, ctx) -> A.Chunk:\n    mode = str(ctx.options.get("rename", "auto"))\n    if mode == "none":\n        return chunk\n\n    r = resolve(chunk)\n    used = {n.name for n in A.walk(chunk) if isinstance(n, A.Name)}\n    used.update({"self", "_ENV", "_G"})\n\n    counter = 0\n\n    def fresh() -> str:\n        nonlocal counter\n        while True:\n            counter += 1\n            cand = f"v{counter}"\n            if cand not in used:\n                used.add(cand)\n                return cand\n\n    mapping = {}\n    for bid, b in r.bindings.items():\n        if b.kind == "param" and b.name == "self":\n            continue\n        if mode == "all" or _looks_obfuscated(b.name):\n            mapping[bid] = fresh()\n\n    if not mapping:\n        return chunk\n\n    for n in A.walk(chunk):\n        if isinstance(n, A.Name) and n.binding in mapping:\n            n.name = mapping[n.binding]\n\n    ctx.bump("locals_renamed", len(mapping))\n    ctx.note(f"[rename] renamed {len(mapping)} local(s) (mode={mode})")\n    return chunk\n', False), '_lelsploit_ast.passes.vm_lift': ('"""Full lift of the Prometheus ``Vmify`` VM back to structured Lua.\n\nPipeline for the container function (and, recursively, every nested closure):\n\n1. flatten the ``if pos < K`` search tree into an ordered block list\n   (:mod:`unprom.vm`);\n2. **symbolically execute** each block over the register file, turning\n   ``rT="foo"; rX=ENV[rT]`` back into ``foo``, ``rX = a + b`` into an\n   expression, ``createClosureN(id,{..})`` into a nested ``function`` etc., and\n   dropping the scope-cleanup ``reg = nil`` noise;\n3. classify each block\'s terminator from the symbolic value of ``pos`` /\n   ``ret`` (goto / branch / return);\n4. **structure** the resulting CFG into ``if`` / ``elseif`` / ``else``,\n   ``while`` and numeric ``for`` using dominator / post-dominator info.\n\nIf a function cannot be structured cleanly it is left for the de-flattener\n(:mod:`unprom.passes.devirtualize`) and a note is emitted.  Enabled unless the\n``devirt`` option is ``"off"`` or ``"deflatten"``.\n"""\n\nfrom __future__ import annotations\n\nfrom typing import Dict, List, Optional, Set, Tuple\n\nfrom .. import ast_nodes as A\nfrom ..ast_nodes import clone\nfrom ..astutil import as_int, as_string, unparen\nfrom ..evaluator import const_value, value_to_node\nfrom ..vm import Container, find_container, flatten_blocks, id_to_index\n\n\n# ======================================================================\n# Terminators\n# ======================================================================\nclass Term:\n    def succs(self) -> List[int]:\n        return []\n\n\nclass TGoto(Term):\n    def __init__(self, target: int):\n        self.target = target\n\n    def succs(self):\n        return [self.target]\n\n    def __repr__(self):\n        return f"goto {self.target}"\n\n\nclass TBranch(Term):\n    def __init__(self, cond: A.Node, t: int, f: int):\n        self.cond, self.t, self.f = cond, t, f\n\n    def succs(self):\n        return [self.t, self.f]\n\n    def __repr__(self):\n        return f"branch ? {self.t} : {self.f}"\n\n\nclass TReturn(Term):\n    def __init__(self, values: List[A.Node]):\n        self.values = values\n\n    def __repr__(self):\n        return f"return ({len(self.values)})"\n\n\nclass TRaw(Term):\n    """Could not classify - keep the block\'s tail statements verbatim."""\n    def __init__(self, stmts: List[A.Node]):\n        self.stmts = stmts\n\n    def __repr__(self):\n        return "raw-tail"\n\n\nclass LiftedBlock:\n    def __init__(self, index: int):\n        self.index = index\n        self.body: List[A.Node] = []\n        self.term: Term = TRaw([])\n\n    def succs(self) -> List[int]:\n        t = self.term\n        if isinstance(t, TGoto):\n            return [t.target]\n        if isinstance(t, TBranch):\n            return [t.t, t.f]\n        return []\n\n\nclass Unsupported(Exception):\n    pass\n\n\n# ======================================================================\n# Function frame\n# ======================================================================\nclass Frame:\n    def __init__(self, parent: Optional["Frame"]):\n        self.parent = parent\n        self.params: List[str] = []\n        self.is_vararg = False\n        self.is_top = False\n        self.upvalues: Dict[int, str] = {}       # upvalue id -> name visible here\n        self.var_regs: Set[str] = set()\n        self.param_map: Dict[str, str] = {}\n        self.declared_vars: Set[str] = set()\n\n\n# ======================================================================\n# The lifter\n# ======================================================================\nclass Lifter:\n    def __init__(self, chunk: A.Chunk, c: Container, ctx):\n        self.chunk = chunk\n        self.c = c\n        self.ctx = ctx\n        self.blocks, self.seps = flatten_blocks(c.while_stmt)\n        self.nblocks = len(self.blocks)\n        self._local_pool_n = 0\n        self._closure_cache: Dict[tuple, A.Function] = {}\n        self._lifting: Set[tuple] = set()\n        self._free_upval_names = set(c.free_upval_names)\n        if c.free_upval_name:\n            self._free_upval_names.add(c.free_upval_name)\n\n    # -- name helpers ------------------------------------------------\n    def new_local(self) -> str:\n        self._local_pool_n += 1\n        return f"L{self._local_pool_n}"\n\n    def idx_of(self, block_id: int) -> int:\n        return id_to_index(block_id, self.seps)\n\n    # -- entry -----------------------------------------------------\n    def lift(self) -> A.Function:\n        root = Frame(None)\n        root.is_top = True\n        entry = self.idx_of(self.c.start_id) if self.c.start_id is not None else 0\n        body = self.lift_function_body(entry, root, is_top=True)\n        return A.Function(params=[], is_vararg=True, body=body)\n\n    # -- per-function --------------------------------------------\n    def lift_function_body(self, entry: int, frame: Frame, is_top=False) -> A.Block:\n        c = self.c\n        regset = set(c.reg_names)\n        reach = self._reachable(entry, frame)\n\n        # Which register(s) carry a real (cross-block / loop-carried) variable?\n        param_map: Dict[str, str] = {}\n        self._scan_params(entry, frame, param_map)\n        var_regs = self._classify_variables(reach, regset, param_map)\n        frame.var_regs = var_regs\n        frame.param_map = param_map\n        frame.declared_vars = set()\n\n        lifted: Dict[int, LiftedBlock] = {}\n        for bi in reach:\n            lifted[bi] = self._exec_block(bi, frame, entry)\n\n        struct = Structurer(lifted, entry, frame, self.ctx)\n        stmts = struct.run()\n\n        for _ in range(4):\n            if not _prune_dead_stores(stmts, set()):\n                break\n\n        decl = sorted(\n            {d for d in frame.declared_vars if _name_used(stmts, d)},\n            key=_reg_sort_key)\n        if decl:\n            stmts.insert(0, A.LocalAssign(\n                targets=[A.Name(name=d) for d in decl], values=[],\n                attribs=[None] * len(decl)))\n        return A.Block(stmts=stmts)\n\n    # -- register classification ---------------------------------\n    def _scan_params(self, entry: int, frame: Frame, param_map: Dict[str, str]):\n        """Read the entry block prologue: `pReg = args[i]` (or captured/vararg)."""\n        c = self.c\n        for s in self.blocks[entry]:\n            if not (isinstance(s, A.Assign) and len(s.targets) == 1\n                    and isinstance(unparen(s.targets[0]), A.Name)):\n                continue\n            nm = unparen(s.targets[0]).name\n            if not s.values:\n                continue\n            v = unparen(s.values[0])\n            if isinstance(v, A.Index) and _is_name(v.obj, c.args_name):\n                k = as_int(v.key)\n                if k is not None:\n                    param_map[nm] = _param_name(frame, k)\n            elif _is_vararg_pack(v, c) or _is_name(v, c.args_name):\n                frame.is_vararg = True\n\n    def _classify_variables(self, reach, regset, param_map) -> Set[str]:\n        """A register is a variable if some block reads it before writing it\n        (its definition lives in another block / a previous iteration)."""\n        variables: Set[str] = set()\n        c = self.c\n        for bi in reach:\n            written: Set[str] = set()\n            for s in self.blocks[bi]:\n                for nm in _reg_reads_of(s, regset):\n                    if nm in (c.pos_name, c.ret_name):\n                        continue\n                    if nm not in written and nm not in param_map:\n                        variables.add(nm)\n                if isinstance(s, A.Assign) and len(s.targets) == 1 \\\n                        and isinstance(unparen(s.targets[0]), A.Name):\n                    written.add(unparen(s.targets[0]).name)\n        return variables\n\n    def _reachable(self, entry: int, frame: Frame) -> List[int]:\n        """Symbolically resolve each block\'s `pos` terminator to discover the\n        successor set (a cheap dummy frame is enough - successor resolution\n        doesn\'t depend on variable classification)."""\n        dummy = Frame(None)\n        seen: Set[int] = set()\n        order: List[int] = []\n        stack = [entry]\n        while stack:\n            b = stack.pop()\n            if b in seen or b < 0 or b >= self.nblocks:\n                continue\n            seen.add(b)\n            order.append(b)\n            try:\n                term = self._exec_block(b, dummy, entry).term\n            except Unsupported:\n                continue\n            for s in term.succs():\n                if s not in seen:\n                    stack.append(s)\n        return order\n\n    # -- symbolic execution of one block --------------------------\n    def _exec_block(self, bi: int, frame: Frame, entry: int) -> LiftedBlock:\n        lb = LiftedBlock(bi)\n        c = self.c\n        # seed: parameter registers resolve to their parameter name everywhere\n        state: Dict[str, A.Node] = {\n            r: A.Name(name=p) for r, p in getattr(frame, "param_map", {}).items()}\n        raw = list(self.blocks[bi])\n        raw = _drop_trailing_reg_nils(raw, c.reg_names, c.pos_name)\n        if bi == entry:\n            raw = self._strip_prologue(raw, frame)\n\n        for i, s in enumerate(raw):\n            future = raw[i + 1:]\n            if isinstance(s, A.CallStat):\n                lb.body.append(A.CallStat(call=self._subst(s.call, state, frame)))\n                continue\n            if not isinstance(s, A.Assign):\n                raise Unsupported(f"block {bi}: {s.kind} statement")\n\n            if len(s.targets) != 1:\n                rhs = self._subst(s.values[0], state, frame) if s.values else A.Nil()\n                names = [self.new_local() for _ in s.targets]\n                lb.body.append(A.LocalAssign(\n                    targets=[A.Name(name=n) for n in names], values=[rhs],\n                    attribs=[None] * len(names)))\n                for tgt, nm in zip(s.targets, names):\n                    if isinstance(unparen(tgt), A.Name):\n                        state[unparen(tgt).name] = A.Name(name=nm)\n                continue\n\n            tgt = unparen(s.targets[0])\n            val = self._subst(s.values[0], state, frame) if s.values else A.Nil()\n\n            if isinstance(tgt, A.Name):\n                nm = tgt.name\n                # `w` (pos) and `h` (ret) are reused as scratch registers, so we\n                # just let them flow through `state` and read the final value\n                # off the end of the block.\n                if nm in (c.pos_name, c.ret_name):\n                    state[nm] = val\n                    continue\n                # recognise globals / varargs / params / upvalue cells /\n                # nested closures first - these must not be masked by the\n                # variable-register path.\n                if self._special_bind(nm, val, state, frame, lb):\n                    continue\n                if nm in getattr(frame, "var_regs", ()) and nm not in \\\n                        getattr(frame, "param_map", {}):\n                    frame.declared_vars.add(nm)\n                    lb.body.append(A.Assign(targets=[A.Name(name=nm)], values=[val]))\n                    # keep the full symbolic value too, so the block terminator\n                    # and later in-block reads resolve completely (register\n                    # reuse means the same name can be a plain temp here).  Only\n                    # withhold it when it holds a call, to avoid duplicating a\n                    # side effect.\n                    state[nm] = A.Name(name=nm) if _contains_call(val) else val\n                    continue\n                self._bind_register(nm, val, state, frame, lb, future)\n                continue\n\n            if isinstance(tgt, A.Index):\n                self._store_index(tgt, val, state, frame, lb)\n                continue\n\n            raise Unsupported(f"block {bi}: assignment to {tgt.kind}")\n\n        lb.term = self._classify_term(state.get(c.pos_name), state.get(c.ret_name),\n                                      bi)\n        # lift any factory calls that survived inside emitted statements / return\n        lb.body = [self._lift_nested(s, state, frame) for s in lb.body]\n        if isinstance(lb.term, TReturn):\n            lb.term.values = [self._lift_nested(v, state, frame)\n                              for v in lb.term.values]\n        return lb\n\n    def _lift_nested(self, node, state, frame):\n        """Replace `factory(id, {ups})` occurrences anywhere in ``node`` with the\n        lifted nested function."""\n        if not isinstance(node, A.Node):\n            return node\n        if self._is_factory_call(node):\n            fn = self._lift_factory(node, state, frame)\n            if fn is not None:\n                return fn\n        if isinstance(node, A.Call) and self._is_factory_call(node.func):\n            fn = self._lift_factory(unparen(node.func), state, frame)\n            if fn is not None:\n                return A.Call(func=A.Paren(inner=fn),\n                              args=[self._lift_nested(a, state, frame)\n                                    for a in node.args])\n        for fname, value in list(A.iter_fields(node)):\n            if isinstance(value, A.Node):\n                setattr(node, fname, self._lift_nested(value, state, frame))\n            elif isinstance(value, list):\n                setattr(node, fname, [\n                    self._lift_nested(x, state, frame) if isinstance(x, A.Node)\n                    else (tuple(self._lift_nested(y, state, frame)\n                                if isinstance(y, A.Node) else y for y in x)\n                          if isinstance(x, tuple) else x)\n                    for x in value])\n        return node\n\n    # -- register binding --------------------------------------\n    def _special_bind(self, nm, val, state, frame, lb) -> bool:\n        """Recognisers that apply regardless of variable-register status.\n        Returns True when it has fully handled the assignment."""\n        c = self.c\n        val = unparen(val)\n\n        # scope-cleanup: reg = freeUpvalue(reg) / freeUpvalueList(reg)  -> drop\n        if isinstance(val, A.Call) and isinstance(unparen(val.func), A.Name) \\\n                and unparen(val.func).name in self._free_upval_names:\n            return True\n\n        # global read:  ENV[<str>]\n        if isinstance(val, A.Index) and _is_name(val.obj, c.env_name):\n            key = as_string(val.key)\n            if key is not None:\n                state[nm] = A.Name(name=key)\n                return True\n\n        if _is_name(val, c.args_name) or _is_vararg_pack(val, c):\n            state[nm] = A.Vararg()\n            return True\n\n        # parameter:  args[i]\n        if isinstance(val, A.Index) and _is_name(val.obj, c.args_name):\n            k = as_int(val.key)\n            if k is not None:\n                state[nm] = A.Name(name=_param_name(frame, k))\n                return True\n\n        # alloc upvalue cell:  X = allocUpval()\n        if isinstance(val, A.Call) and _is_name(val.func, c.alloc_upval_name) \\\n                and not val.args:\n            state[nm] = _UpvalCell(self.new_local())\n            return True\n\n        # upvalue read:  UPV[idx]\n        if isinstance(val, A.Index) and _is_name(val.obj, c.upvals_table_name):\n            resolved = self._resolve_upval_id(val.key, state, frame)\n            if resolved is not None:\n                state[nm] = A.Name(name=resolved)\n                return True\n\n        # nested closure:  X = factory(id, {ups})  [ (args) ]\n        clo = self._as_closure(val, state, frame)\n        if clo is not None:\n            if nm in getattr(frame, "var_regs", ()):\n                frame.declared_vars.add(nm)\n                lb.body.append(A.Assign(targets=[A.Name(name=nm)], values=[clo]))\n                state[nm] = A.Name(name=nm)\n            else:\n                state[nm] = clo\n            return True\n        return False\n\n    def _bind_register(self, nm, val, state, frame, lb, future):\n        val = unparen(val)\n        if self._special_bind(nm, val, state, frame, lb):\n            return\n\n        # bare call:  rX = f(args)\n        if isinstance(val, (A.Call, A.MethodCall)):\n            reads = _count_name(future, nm)\n            if reads == 0:\n                lb.body.append(A.CallStat(call=val))     # result unused -> statement\n                return\n            if reads == 1:\n                state[nm] = val                          # single use -> inline\n                return\n            t = self.new_local()\n            lb.body.append(A.LocalAssign(targets=[A.Name(name=t)], values=[val],\n                                         attribs=[None]))\n            state[nm] = A.Name(name=t)\n            return\n\n        # expression that *contains* a call and is read more than once: pin it\n        if _contains_call(val) and _count_name(future, nm) > 1:\n            t = self.new_local()\n            lb.body.append(A.LocalAssign(targets=[A.Name(name=t)], values=[val],\n                                         attribs=[None]))\n            state[nm] = A.Name(name=t)\n            return\n\n        state[nm] = val\n\n    def _store_index(self, tgt: A.Index, val, state, frame, lb):\n        c = self.c\n        # global write\n        if _is_name(tgt.obj, c.env_name):\n            key = as_string(tgt.key)\n            if key is not None:\n                lb.body.append(A.Assign(targets=[A.Name(name=key)], values=[val]))\n                return\n        # upvalue write\n        if _is_name(tgt.obj, c.upvals_table_name):\n            resolved = self._resolve_upval_id(tgt.key, state, frame, creating=True)\n            if resolved is not None:\n                if resolved.startswith("\\0"):\n                    real = resolved[1:]\n                    lb.body.append(A.LocalAssign(targets=[A.Name(name=real)],\n                                                 values=[val], attribs=[None]))\n                else:\n                    lb.body.append(A.Assign(targets=[A.Name(name=resolved)],\n                                            values=[val]))\n                return\n        base = self._subst(tgt.obj, state, frame)\n        key = self._subst(tgt.key, state, frame)\n        lb.body.append(A.Assign(targets=[A.Index(obj=base, key=key, dot=tgt.dot)],\n                                values=[val]))\n\n    def _resolve_upval_id(self, key_expr, state, frame, creating=False):\n        k = self._subst(key_expr, state, frame)\n        k = unparen(k)\n        if isinstance(k, _UpvalCell):\n            if creating and not k.declared:\n                k.declared = True\n                return "\\0" + k.name\n            return k.name\n        if isinstance(k, A.Name) and isinstance(state.get(k.name), _UpvalCell):\n            cell = state[k.name]\n            if creating and not cell.declared:\n                cell.declared = True\n                return "\\0" + cell.name\n            return cell.name\n        # currentUpvalues[j]\n        if isinstance(k, A.Index) and _is_name(k.obj, self.c.upvals_name):\n            j = as_int(k.key)\n            if j is not None and j in frame.upvalues:\n                return frame.upvalues[j]\n        return None\n\n    # -- closure recognition -----------------------------------\n    def _is_factory_call(self, node) -> bool:\n        node = unparen(node)\n        if not isinstance(node, A.Call) or len(node.args) != 2:\n            return False\n        f = unparen(node.func)\n        if not isinstance(f, A.Name):\n            return False\n        if f.name not in self.c.factory_names:\n            # name not captured: fall back to the (id:int, {..}) shape\n            if as_int(node.args[0]) is None:\n                return False\n        return as_int(node.args[0]) is not None \\\n            and isinstance(unparen(node.args[1]), A.Table)\n\n    def _lift_factory(self, call, state, frame) -> Optional[A.Function]:\n        bid = as_int(call.args[0])\n        upt = unparen(call.args[1])\n        if bid is None or not isinstance(upt, A.Table):\n            return None\n        ups = tuple(self._name_for_upval_entry(ent, state, frame)\n                    for _k, _key, ent in upt.fields)\n        key = (bid, ups)\n        cached = self._closure_cache.get(key)\n        if cached is not None:\n            return clone(cached)\n        if key in self._lifting:            # guard against pathological recursion\n            return A.Function(params=[], is_vararg=True, body=A.Block(stmts=[]))\n        self._lifting.add(key)\n        child = Frame(frame)\n        for k, nm in enumerate(ups, start=1):\n            child.upvalues[k] = nm\n        body = self.lift_function_body(self.idx_of(bid), child)\n        fn = A.Function(params=[A.Name(name=p) for p in child.params],\n                        is_vararg=child.is_vararg, body=body)\n        self._lifting.discard(key)\n        self._closure_cache[key] = fn\n        return clone(fn)\n\n    def _as_closure(self, val, state, frame):\n        """`factory(id, {ups})`            -> function ... end\n           `factory(id, {ups})(a, b, ...)` -> (function ... end)(a, b, ...)"""\n        val = unparen(val)\n        if self._is_factory_call(val):\n            return self._lift_factory(val, state, frame)\n        if isinstance(val, A.Call) and self._is_factory_call(val.func):\n            fn = self._lift_factory(unparen(val.func), state, frame)\n            if fn is not None:\n                return A.Call(func=A.Paren(inner=fn),\n                              args=[self._subst(a, state, frame) for a in val.args])\n        return None\n\n    def _name_for_upval_entry(self, ent, state, frame) -> str:\n        ent = unparen(self._subst(ent, state, frame))\n        if isinstance(ent, _UpvalCell):\n            return ent.name\n        if isinstance(ent, A.Name):\n            return ent.name\n        if isinstance(ent, A.Index) and _is_name(ent.obj, self.c.upvals_name):\n            j = as_int(ent.key)\n            if j is not None and j in frame.upvalues:\n                return frame.upvalues[j]\n        if isinstance(ent, A.Call) and _is_name(ent.func, self.c.alloc_upval_name):\n            return self.new_local()\n        return self.new_local()\n\n    def _strip_prologue(self, raw: List[A.Node], frame: Frame) -> List[A.Node]:\n        """Drop the entry-block statements that only bind parameters."""\n        c = self.c\n        out = []\n        for s in raw:\n            if isinstance(s, A.Assign) and len(s.targets) == 1 \\\n                    and isinstance(unparen(s.targets[0]), A.Name) and s.values:\n                nm = unparen(s.targets[0]).name\n                v = unparen(s.values[0])\n                if nm in frame.param_map and isinstance(v, A.Index) \\\n                        and _is_name(v.obj, c.args_name):\n                    continue\n                if _is_vararg_pack(v, c) or _is_name(v, c.args_name):\n                    frame.is_vararg = True\n                    continue\n            out.append(s)\n        return out\n\n    # -- terminator classification ----------------------------\n    def _classify_term(self, pos_expr, ret_expr, bi=-1) -> Term:\n        if pos_expr is None:\n            return TRaw([])\n        pe = unparen(pos_expr)\n        if _is_exit(pe, self.c):\n            return TReturn(self._return_values(ret_expr) if ret_expr is not None\n                           else [])\n        n = as_int(pe)\n        if n is not None:\n            return TGoto(self.idx_of(n))\n        br = _as_branch(pe)\n        if br is not None:\n            cond, a, b = br\n            return TBranch(cond, self.idx_of(a), self.idx_of(b))\n        from ..unparser import Unparser\n        try:\n            txt = Unparser()._expr(pe)\n        except Exception:  # noqa: BLE001\n            txt = pe.kind\n        raise Unsupported(f"block {bi}: unclassifiable pos expression -> {txt}")\n\n    def _return_values(self, ret_expr) -> List[A.Node]:\n        r = unparen(ret_expr)\n        if isinstance(r, A.Table):\n            out = []\n            for _k, _key, v in r.fields:\n                v = unparen(v)\n                if isinstance(v, A.Call) and _is_name(v.func, self.c.unpack_name) \\\n                        and len(v.args) == 1:\n                    inner = unparen(v.args[0])\n                    if isinstance(inner, A.Table):\n                        # unpack({ a, b, ... })  ->  a, b, ...\n                        out.extend(unparen(f[2]) for f in inner.fields)\n                    else:\n                        out.append(v.args[0])   # return unpack(x) -> return x...\n                else:\n                    out.append(v)\n            return out\n        return [r]\n\n    # -- substitution -----------------------------------------\n    def _subst(self, expr: A.Node, state: Dict[str, A.Node], frame: Frame,\n               depth=0) -> A.Node:\n        if depth > 60 or expr is None:\n            return expr\n        if isinstance(expr, A.Name):\n            if expr.name in state:\n                v = state[expr.name]\n                if isinstance(v, _UpvalCell):\n                    return A.Name(name=v.name)\n                return clone(v)\n            return A.Name(name=expr.name, binding=expr.binding)\n        if isinstance(expr, _UpvalCell):\n            return A.Name(name=expr.name)\n        new = clone(expr)\n        self._subst_children(new, state, frame, depth)\n        return _simplify(new)\n\n    def _subst_children(self, node: A.Node, state, frame, depth):\n        for fname, value in list(A.iter_fields(node)):\n            if isinstance(value, A.Node):\n                setattr(node, fname, self._subst(value, state, frame, depth + 1))\n            elif isinstance(value, list):\n                out = []\n                for it in value:\n                    if isinstance(it, A.Node):\n                        out.append(self._subst(it, state, frame, depth + 1))\n                    elif isinstance(it, tuple):\n                        out.append(tuple(\n                            self._subst(x, state, frame, depth + 1)\n                            if isinstance(x, A.Node) else x for x in it))\n                    else:\n                        out.append(it)\n                setattr(node, fname, out)\n\n\nclass _UpvalCell:\n    __slots__ = ("name", "declared", "line")\n\n    def __init__(self, name: str):\n        self.name = name\n        self.declared = False\n        self.line = 0\n\n    @property\n    def kind(self):\n        return "Name"\n\n\n# ======================================================================\n# Helpers\n# ======================================================================\ndef _is_name(node, name) -> bool:\n    if name is None:\n        return False\n    node = unparen(node)\n    return isinstance(node, A.Name) and node.name == name\n\n\ndef _reg_reads_of(s: A.Node, regset: Set[str]) -> List[str]:\n    """Register names *read* by statement ``s`` (LHS bare-name targets excluded)."""\n    out: List[str] = []\n    if isinstance(s, A.Assign):\n        for t in s.targets:\n            t = unparen(t)\n            if isinstance(t, A.Index):\n                out += [n.name for n in A.walk(t)\n                        if isinstance(n, A.Name) and n.name in regset]\n        for v in s.values:\n            out += [n.name for n in A.walk(v)\n                    if isinstance(n, A.Name) and n.name in regset]\n    else:\n        out += [n.name for n in A.walk(s)\n                if isinstance(n, A.Name) and n.name in regset]\n    return out\n\n\ndef _reg_sort_key(name: str):\n    m = "".join(ch for ch in name if ch.isdigit())\n    return (0, int(m)) if m else (1, name)\n\n\ndef _numbers_in(expr) -> List[int]:\n    out = []\n    for n in A.walk(expr):\n        if isinstance(n, A.Number):\n            iv = as_int(n)\n            if iv is not None:\n                out.append(iv)\n    return out\n\n\ndef _drop_trailing_reg_nils(raw, reg_names, pos_name):\n    regset = set(reg_names)\n    end = len(raw)\n    # keep terminator (pos = ...) but drop a run of `regN = nil` just before it\n    term_i = end\n    for i in range(end - 1, -1, -1):\n        s = raw[i]\n        if isinstance(s, A.Assign) and len(s.targets) == 1 \\\n                and _is_name(s.targets[0], pos_name):\n            term_i = i\n            break\n    keep = []\n    for i, s in enumerate(raw):\n        if i < term_i and isinstance(s, A.Assign) and len(s.targets) == 1:\n            t = unparen(s.targets[0])\n            if isinstance(t, A.Name) and t.name in regset and len(s.values) == 1 \\\n                    and isinstance(unparen(s.values[0]), A.Nil):\n                continue\n        keep.append(s)\n    return keep\n\n\ndef _is_vararg_pack(val, c: Container) -> bool:\n    val = unparen(val)\n    if not isinstance(val, A.Table) or len(val.fields) != 1:\n        return False\n    v = unparen(val.fields[0][2])\n    if not isinstance(v, A.Call) or not _is_name(v.func, c.select_name):\n        return False\n    return True\n\n\ndef _param_name(frame: Frame, k: int) -> str:\n    while len(frame.params) < k:\n        frame.params.append(f"a{len(frame.params) + 1}")\n    return frame.params[k - 1]\n\n\ndef _is_exit(pos_expr, c: Container) -> bool:\n    if pos_expr is None:\n        return False\n    pe = unparen(pos_expr)\n    if isinstance(pe, A.Nil):\n        return True\n    if isinstance(pe, A.Index) and _is_name(pe.obj, c.env_name):\n        # pos = ENV["<random>"]  -> nil at runtime\n        return as_string(pe.key) is not None\n    return False\n\n\ndef _as_branch(pe: A.Node):\n    """`(C and A) or B` with A,B integer literals -> (C, A, B)."""\n    pe = unparen(pe)\n    if not (isinstance(pe, A.BinOp) and pe.op == "or"):\n        return None\n    b = as_int(pe.right)\n    land = unparen(pe.left)\n    if b is None or not (isinstance(land, A.BinOp) and land.op == "and"):\n        return None\n    a = as_int(land.right)\n    if a is None:\n        return None\n    return land.left, a, b\n\n\ndef _contains_call(node) -> bool:\n    for n in A.walk(node):\n        if isinstance(n, (A.Call, A.MethodCall)):\n            return True\n    return False\n\n\ndef _count_name(stmts, name) -> int:\n    total = 0\n    for s in stmts:\n        for n in A.walk(s):\n            if isinstance(n, A.Name) and n.name == name:\n                total += 1\n    return total\n\n\ndef _reads_more_than_once(stmts, name) -> bool:\n    return _count_name(stmts, name) > 1\n\n\ndef _simplify(node: A.Node) -> A.Node:\n    # ({ expr })[1]  ->  (expr)\n    if isinstance(node, A.Index):\n        base = unparen(node.obj)\n        k = as_int(node.key)\n        if isinstance(base, A.Table) and k == 1 and len(base.fields) == 1 \\\n                and base.fields[0][0] == "pos":\n            inner = base.fields[0][2]\n            return A.Paren(inner=inner) if isinstance(inner, (A.Call, A.MethodCall)) \\\n                else inner\n    if isinstance(node, (A.BinOp, A.UnOp)):\n        ok, v = const_value(node)\n        if ok and isinstance(v, (bool, float, str)):\n            try:\n                return value_to_node(v)\n            except TypeError:\n                pass\n    return node\n\n\n# ======================================================================\n# CFG structuring\n# ======================================================================\nclass Structurer:\n    def __init__(self, blocks: Dict[int, LiftedBlock], entry: int, frame: Frame,\n                 ctx):\n        self.blocks = blocks\n        self.entry = entry\n        self.frame = frame\n        self.ctx = ctx\n        self.nodes = sorted(blocks)\n        self.preds: Dict[int, List[int]] = {n: [] for n in self.nodes}\n        for n in self.nodes:\n            for s in blocks[n].succs():\n                if s in self.preds:\n                    self.preds[s].append(n)\n        self.idom = self._dominators()\n        self.loop_headers = self._find_loop_headers()\n\n    # -- dominators (Cooper-Harvey-Kennedy) -------------------\n    def _rpo(self) -> List[int]:\n        order, seen = [], set()\n\n        def dfs(n):\n            seen.add(n)\n            for s in self.blocks[n].succs():\n                if s in self.blocks and s not in seen:\n                    dfs(s)\n            order.append(n)\n\n        dfs(self.entry)\n        order.reverse()\n        return order\n\n    def _dominators(self) -> Dict[int, int]:\n        rpo = self._rpo()\n        pos = {n: i for i, n in enumerate(rpo)}\n        idom = {self.entry: self.entry}\n\n        def inter(a, b):\n            while a != b:\n                while pos[a] > pos[b]:\n                    a = idom[a]\n                while pos[b] > pos[a]:\n                    b = idom[b]\n            return a\n\n        changed = True\n        while changed:\n            changed = False\n            for n in rpo:\n                if n == self.entry:\n                    continue\n                ps = [p for p in self.preds[n] if p in idom]\n                if not ps:\n                    continue\n                new = ps[0]\n                for p in ps[1:]:\n                    new = inter(p, new)\n                if idom.get(n) != new:\n                    idom[n] = new\n                    changed = True\n        return idom\n\n    def _dominates(self, a: int, b: int) -> bool:\n        while b != self.entry:\n            if a == b:\n                return True\n            b = self.idom.get(b, self.entry)\n        return a == self.entry\n\n    def _find_loop_headers(self) -> Dict[int, Set[int]]:\n        headers: Dict[int, Set[int]] = {}\n        for n in self.nodes:\n            for s in self.blocks[n].succs():\n                if s in self.blocks and self._dominates(s, n):\n                    body = self._natural_loop(s, n)\n                    headers.setdefault(s, set()).update(body)\n        return headers\n\n    def _natural_loop(self, header: int, tail: int) -> Set[int]:\n        body = {header, tail}\n        stack = [tail]\n        while stack:\n            n = stack.pop()\n            for p in self.preds[n]:\n                if p not in body:\n                    body.add(p)\n                    stack.append(p)\n        return body\n\n    # -- structuring -----------------------------------------\n    def run(self) -> List[A.Node]:\n        self._open_loops: Set[int] = set()\n        return self._region(self.entry, set())\n\n    def _region(self, node: Optional[int], stop: Set[int],\n                force_first: bool = False) -> List[A.Node]:\n        out: List[A.Node] = []\n        cur = node\n        guard = 0\n        while cur is not None:\n            if cur in stop and not force_first:\n                break\n            force_first = False\n            guard += 1\n            if guard > len(self.blocks) * 4 + 10:\n                raise Unsupported("structuring did not converge")\n\n            if cur in self.loop_headers and cur not in self._open_loops:\n                loop_node, follow = self._emit_loop(cur, stop)\n                if loop_node is not None:\n                    out.append(loop_node)\n                cur = follow\n                continue\n\n            blk = self.blocks[cur]\n            out.extend(clone(s) for s in blk.body)\n            t = blk.term\n\n            if isinstance(t, TReturn):\n                out.append(A.Return(values=[clone(v) for v in t.values]))\n                cur = None\n            elif isinstance(t, TRaw):\n                out.extend(clone(s) for s in t.stmts)\n                cur = None\n            elif isinstance(t, TGoto):\n                nxt = t.target\n                if nxt in self._open_loops:\n                    out.append(A.Continue())\n                    cur = None\n                else:\n                    cur = nxt\n            elif isinstance(t, TBranch):\n                join = self._branch_join(cur, t, stop)\n                sset = stop | ({join} if join is not None else set())\n                then_b = self._region(t.t, sset)\n                else_b = self._region(t.f, sset)\n                out.append(self._make_if(clone(t.cond), then_b, else_b))\n                cur = join\n            else:\n                cur = None\n        return out\n\n    def _branch_join(self, node: int, t: TBranch, stop: Set[int]) -> Optional[int]:\n        """The merge point: earliest (in RPO) node reachable from *both*\n        successors without passing back through ``node``."""\n        ra = self._reach_from(t.t, block=node)\n        rb = self._reach_from(t.f, block=node)\n        common = (ra & rb) - {node} - stop\n        if not common:\n            return None\n        rpo = {n: i for i, n in enumerate(self._rpo())}\n        return min(common, key=lambda n: rpo.get(n, 1 << 30))\n\n    def _reach_from(self, start: int, block: int) -> Set[int]:\n        seen: Set[int] = set()\n        stack = [start]\n        while stack:\n            n = stack.pop()\n            if n in seen or n == block or n not in self.blocks:\n                continue\n            seen.add(n)\n            for s in self.blocks[n].succs():\n                stack.append(s)\n        return seen\n\n    def _emit_loop(self, header: int, stop: Set[int]) -> Tuple[A.Node, Optional[int]]:\n        body_nodes = self.loop_headers[header]\n        exits: Set[int] = set()\n        for n in body_nodes:\n            for s in self.blocks[n].succs():\n                if s not in body_nodes:\n                    exits.add(s)\n        follow = min(exits) if exits else None\n\n        self._open_loops.add(header)\n        hb = self.blocks[header]\n\n        sub_stop = stop | {header} | ({follow} if follow is not None else set())\n\n        # while <cond> do ... end   (header is a pure branch: one succ = follow)\n        if not hb.body and isinstance(hb.term, TBranch):\n            t = hb.term\n            if t.f == follow and t.t in body_nodes:\n                inner = _strip_trailing_continue(self._region(t.t, sub_stop))\n                self._open_loops.discard(header)\n                return A.While(cond=clone(t.cond), body=A.Block(stmts=inner)), follow\n            if t.t == follow and t.f in body_nodes:\n                inner = _strip_trailing_continue(self._region(t.f, sub_stop))\n                self._open_loops.discard(header)\n                return A.While(cond=A.UnOp(op="not", operand=A.Paren(inner=clone(t.cond))),\n                               body=A.Block(stmts=inner)), follow\n\n        # generic: while true do <body> [break] end\n        inner = _strip_trailing_continue(\n            self._region(header, sub_stop, force_first=True))\n        self._open_loops.discard(header)\n\n        # not actually a loop (spurious back-edge / degenerate body): drop it\n        real = [s for s in inner if not isinstance(s, (A.Break, A.Continue))]\n        if not real:\n            return None, follow\n\n        inner = _append_break_on_fallthrough(inner)\n        return A.While(cond=A.TrueExpr(), body=A.Block(stmts=inner)), follow\n\n    def _make_if(self, cond: A.Node, then_b: List[A.Node],\n                 else_b: List[A.Node]) -> A.Node:\n        if then_b and not else_b:\n            return A.If(clauses=[(cond, A.Block(stmts=then_b))], orelse=None)\n        if else_b and not then_b:\n            neg = A.UnOp(op="not", operand=_paren_if_needed(cond))\n            return A.If(clauses=[(neg, A.Block(stmts=else_b))], orelse=None)\n        return A.If(clauses=[(cond, A.Block(stmts=then_b))],\n                    orelse=A.Block(stmts=else_b) if else_b else None)\n\n\ndef _paren_if_needed(cond: A.Node) -> A.Node:\n    if isinstance(cond, (A.BinOp,)):\n        return A.Paren(inner=cond)\n    return cond\n\n\ndef _append_break_on_fallthrough(stmts: List[A.Node]) -> List[A.Node]:\n    if stmts and isinstance(stmts[-1], (A.Return, A.Break, A.Continue)):\n        return stmts\n    return stmts + [A.Break()]\n\n\ndef _strip_trailing_continue(stmts: List[A.Node]) -> List[A.Node]:\n    if stmts and isinstance(stmts[-1], A.Continue):\n        return stmts[:-1]\n    return stmts\n\n\ndef _name_used(stmts, name: str) -> bool:\n    for s in stmts:\n        for n in A.walk(s):\n            if isinstance(n, A.Name) and n.name == name:\n                return True\n    return False\n\n\ndef _reads_in(node: A.Node) -> Set[str]:\n    """All bare-Name reads in ``node`` (LHS bare targets of Assign excluded)."""\n    out: Set[str] = set()\n    if isinstance(node, A.Assign):\n        for t in node.targets:\n            t = unparen(t)\n            if isinstance(t, A.Index):\n                out |= {n.name for n in A.walk(t) if isinstance(n, A.Name)}\n        for v in node.values:\n            out |= {n.name for n in A.walk(v) if isinstance(n, A.Name)}\n        return out\n    if isinstance(node, A.LocalAssign):\n        for v in node.values:\n            out |= {n.name for n in A.walk(v) if isinstance(n, A.Name)}\n        return out\n    return {n.name for n in A.walk(node) if isinstance(n, A.Name)}\n\n\ndef _prune_dead_stores(stmts: List[A.Node], live_after: Set[str]) -> bool:\n    """Backward walk: drop `x = <pure>` when x is not read before its next\n    write.  Compound statements are treated opaquely (everything they mention\n    stays live), which keeps this conservative around control flow."""\n    changed = False\n    live = set(live_after)\n    # names referenced by any compound stmt anywhere in this list stay live\n    for s in stmts:\n        if not isinstance(s, (A.Assign, A.LocalAssign, A.CallStat)):\n            live |= {n.name for n in A.walk(s) if isinstance(n, A.Name)}\n\n    new_rev: List[A.Node] = []\n    for s in reversed(stmts):\n        if isinstance(s, A.Assign) and len(s.targets) == 1 \\\n                and isinstance(s.targets[0], A.Name):\n            x = s.targets[0].name\n            has_call = _contains_call(s.values[0]) if s.values else False\n            if x not in live and not has_call:\n                changed = True\n                continue                          # dead store -> drop\n            live.discard(x)\n            live |= _reads_in(s)\n            new_rev.append(s)\n            continue\n        if isinstance(s, (A.If, A.While, A.Repeat)):\n            for b in _sub_blocks(s):\n                changed |= _prune_dead_stores(b.stmts, set(live))\n        live |= _reads_in(s)\n        new_rev.append(s)\n\n    new_rev.reverse()\n    stmts[:] = new_rev\n    return changed\n\n\ndef _sub_blocks(s: A.Node) -> List[A.Block]:\n    out = []\n    if isinstance(s, A.If):\n        out += [b for _c, b in s.clauses]\n        if s.orelse is not None:\n            out.append(s.orelse)\n    elif isinstance(s, (A.While, A.Repeat, A.Do)):\n        out.append(s.body)\n    return out\n\n\n# ======================================================================\n# pass entry\n# ======================================================================\ndef run(chunk: A.Chunk, ctx) -> A.Chunk:\n    mode = str(ctx.options.get("devirt", "on"))\n    if mode in ("off", "false", "0", "deflatten"):\n        return chunk\n    c = find_container(chunk)\n    if c is None:\n        return chunk\n    try:\n        lifter = Lifter(chunk, c, ctx)\n        new_fn = lifter.lift()\n    except Unsupported as exc:\n        ctx.note(f"[vm_lift] could not fully lift ({exc}); leaving for de-flattener")\n        return chunk\n    except Exception as exc:  # noqa: BLE001\n        ctx.note(f"[vm_lift] internal error: {exc!r}; leaving for de-flattener")\n        return chunk\n\n    # Replace the whole program with the lifted top-level function body.\n    chunk.body = new_fn.body\n    ctx.bump("vm_lifted")\n    ctx.note(f"[vm_lift] lifted Prometheus VM ({lifter.nblocks} blocks) to "\n             "structured Lua")\n    return chunk\n', False), '_lelsploit_ast.passes.wrap_in_function': ('"""Reverse ``WrapInFunction``.\n\nPrometheus wraps the whole script as::\n\n    return (function(...) <body> end)(...)\n\npossibly several times.  We peel every such layer off the top of the chunk.\n"""\n\nfrom __future__ import annotations\n\nfrom .. import ast_nodes as A\n\n\ndef _unwrap_once(chunk: A.Chunk) -> bool:\n    stmts = chunk.body.stmts\n    if len(stmts) != 1 or not isinstance(stmts[0], A.Return):\n        return False\n    ret = stmts[0]\n    if len(ret.values) != 1:\n        return False\n    call = ret.values[0]\n    if isinstance(call, A.Paren):\n        call = call.inner\n    if not isinstance(call, A.Call):\n        return False\n    fn = call.func\n    if isinstance(fn, A.Paren):\n        fn = fn.inner\n    if not isinstance(fn, A.Function):\n        return False\n    # Args must be exactly ``...`` (or empty) so hoisting keeps semantics.\n    if not all(isinstance(a, A.Vararg) for a in call.args):\n        return False\n    if any(not isinstance(p, A.Name) for p in fn.params):\n        return False\n    # Any non-vararg params would need the call args; WrapInFunction never adds\n    # them, so bail if present.\n    if fn.params:\n        return False\n    chunk.body = fn.body\n    return True\n\n\ndef run(chunk: A.Chunk, ctx) -> A.Chunk:\n    n = 0\n    while _unwrap_once(chunk):\n        n += 1\n    if n:\n        ctx.bump("wrap_layers_removed", n)\n        ctx.note(f"[unwrap] removed {n} WrapInFunction layer(s)")\n    return chunk\n', False), '_lelsploit_ast.pipeline': ('"""Pass pipeline: parse -> run passes -> unparse."""\n\nfrom __future__ import annotations\n\nfrom dataclasses import dataclass, field\nfrom typing import Callable, Dict, List, Optional\n\nfrom . import ast_nodes as A\nfrom .parser import parse\nfrom .unparser import unparse\n\n\n@dataclass\nclass PassContext:\n    """Shared scratch space + reporting for a single deobfuscation run."""\n    notes: List[str] = field(default_factory=list)\n    stats: Dict[str, int] = field(default_factory=dict)\n    options: Dict[str, object] = field(default_factory=dict)\n\n    def note(self, msg: str):\n        self.notes.append(msg)\n\n    def bump(self, key: str, n: int = 1):\n        self.stats[key] = self.stats.get(key, 0) + n\n\n\n# A pass is a callable (Chunk, PassContext) -> Chunk\nPass = Callable[[A.Chunk, PassContext], A.Chunk]\n\n\ndef _load_passes() -> Dict[str, Pass]:\n    from .passes import anti_tamper, constant_array, constant_fold\n    from .passes import encrypt_strings, wrap_in_function, proxify_locals\n    from .passes import dead_code, devirtualize, vm_lift, rename, cleanup\n\n    return {\n        "unwrap": wrap_in_function.run,\n        "anti_tamper": anti_tamper.run,\n        "encrypt_strings": encrypt_strings.run,\n        "constant_array": constant_array.run,\n        "vm_lift": vm_lift.run,\n        "devirtualize": devirtualize.run,\n        "constant_fold": constant_fold.run,\n        "proxify_locals": proxify_locals.run,\n        "dead_code": dead_code.run,\n        "cleanup": cleanup.run,\n        "rename": rename.run,\n    }\n\n\n# Order matters. Structural unwrapping first, then string/const recovery, then\n# the VM lifter, then simplification, then cosmetic renaming last.\nDEFAULT_PASSES: List[str] = [\n    "unwrap",\n    "anti_tamper",\n    "constant_fold",   # fold obfuscated arithmetic first so detectors see literals\n    "encrypt_strings",\n    "constant_array",\n    "constant_fold",\n    "vm_lift",         # full VM -> structured Lua (falls back to devirtualize)\n    "devirtualize",    # de-flatten whatever vm_lift left behind\n    "constant_fold",\n    "proxify_locals",\n    "constant_fold",\n    "dead_code",\n    "cleanup",\n    "rename",\n]\n\n\nclass Pipeline:\n    def __init__(self, passes: Optional[List[str]] = None,\n                 options: Optional[Dict[str, object]] = None):\n        self.registry = _load_passes()\n        self.passes = list(passes if passes is not None else DEFAULT_PASSES)\n        self.options = options or {}\n\n    def available(self) -> List[str]:\n        return sorted(self.registry)\n\n    def run_ast(self, chunk: A.Chunk) -> tuple[A.Chunk, PassContext]:\n        ctx = PassContext(options=dict(self.options))\n        for name in self.passes:\n            fn = self.registry.get(name)\n            if fn is None:\n                ctx.note(f"[pipeline] unknown pass {name!r}, skipped")\n                continue\n            try:\n                chunk = fn(chunk, ctx) or chunk\n            except Exception as exc:  # keep going; a failed pass shouldn\'t kill the run\n                ctx.note(f"[{name}] failed: {exc!r}")\n        return chunk, ctx\n\n    def run(self, source: str) -> "tuple[str, PassContext]":\n        chunk = parse(source)\n        chunk, ctx = self.run_ast(chunk)\n        indent = str(self.options.get("indent", "  ")) or "  "\n        return unparse(chunk, indent=indent), ctx\n\n\ndef deobfuscate(source: str, passes: Optional[List[str]] = None,\n                options: Optional[Dict[str, object]] = None) -> str:\n    """Convenience wrapper: obfuscated source in, cleaned source out."""\n    text, _ctx = Pipeline(passes, options).run(source)\n    return text\n', False), '_lelsploit_ast.prng': ('"""Reimplementation of the Prometheus ``EncryptStrings`` keystream.\n\nPorted straight from ``src/prometheus/steps/EncryptStrings.lua``.  The obfuscated\nscript embeds four integers (``param_mul_45``, ``param_add_45``, ``param_mul_8``\nand ``secret_key_8``); together with the per-string ``seed`` they fully\ndetermine the keystream, so decryption is completely static.\n\nNote: the ``charmap`` table the runtime builds is a no-op shuffle -- for every\n``n`` in 1..256 it stores ``string.char(n-1)`` -- so ``chars[b + 1] ==\nstring.char(b)`` and we can ignore it entirely.\n"""\n\nfrom __future__ import annotations\n\nimport math\n\n_MOD45 = 35184372088832  # 2**45\n\n\nclass Keystream:\n    def __init__(self, param_mul_45: int, param_add_45: int,\n                 param_mul_8: int, secret_key_8: int):\n        self.param_mul_45 = param_mul_45\n        self.param_add_45 = param_add_45\n        self.param_mul_8 = param_mul_8\n        self.secret_key_8 = secret_key_8\n        self.state_45 = 0.0\n        self.state_8 = 2.0\n        self._queue = []\n\n    def set_seed(self, seed: int):\n        self.state_45 = float(seed % _MOD45)\n        self.state_8 = float(seed % 255 + 2)\n        self._queue = []\n\n    @staticmethod\n    def _mod(a: float, b: float) -> float:\n        # Lua\'s `%` is floored modulo: a - floor(a/b)*b\n        return a - math.floor(a / b) * b\n\n    def _random_32(self) -> int:\n        self.state_45 = self._mod(\n            self.state_45 * self.param_mul_45 + self.param_add_45, _MOD45)\n        while True:\n            self.state_8 = self._mod(self.state_8 * self.param_mul_8, 257.0)\n            if self.state_8 != 1.0:\n                break\n        r = self._mod(self.state_8, 32.0)\n        # Lua: floor(state_45 / 2^(13-(state_8-r)/32)) % 2^32 / 2^r\n        tmp = math.floor(self.state_45 / 2.0 ** (13 - (self.state_8 - r) / 32.0))\n        n = self._mod(tmp, 2.0 ** 32) / 2.0 ** r\n        return int(math.floor(self._mod(n, 1.0) * 2.0 ** 32) + math.floor(n))\n\n    def next_byte(self) -> int:\n        if not self._queue:\n            rnd = self._random_32()\n            low16 = rnd % 65536\n            high16 = (rnd - low16) // 65536\n            b1 = low16 % 256\n            b2 = (low16 - b1) // 256\n            b3 = high16 % 256\n            b4 = (high16 - b3) // 256\n            self._queue = [b1, b2, b3, b4]\n        return self._queue.pop()   # table.remove -> pops the tail\n\n\ndef encrypt(plain: str, seed: int, param_mul_45: int, param_add_45: int,\n            param_mul_8: int, secret_key_8: int) -> str:\n    """Inverse of :func:`decrypt` -- mirrors ``EncryptStrings.encrypt`` and is\n    used only by the test-suite to prove the keystream round-trips."""\n    ks = Keystream(param_mul_45, param_add_45, param_mul_8, secret_key_8)\n    ks.set_seed(seed)\n    prev = secret_key_8\n    out = bytearray()\n    for byte in plain.encode("latin-1", "replace"):\n        out.append((byte - (ks.next_byte() + prev)) % 256)\n        prev = byte\n    return out.decode("latin-1")\n\n\ndef decrypt(enc: str, seed: int, param_mul_45: int, param_add_45: int,\n            param_mul_8: int, secret_key_8: int) -> str:\n    ks = Keystream(param_mul_45, param_add_45, param_mul_8, secret_key_8)\n    ks.set_seed(seed)\n    prev = secret_key_8\n    out = bytearray()\n    data = enc.encode("latin-1", "replace")\n    for byte in data:\n        prev = (byte + ks.next_byte() + prev) % 256\n        out.append(prev)\n    return out.decode("latin-1")\n', False), '_lelsploit_ast.recovery': ('"""LelSploit additions: bounded static partial evaluation for Luau source.\n\nInput is parsed as data. Only the operations explicitly implemented here can be\ninterpreted; no Lua, Python eval, host calls, or external programs are used.\n"""\nfrom __future__ import annotations\nimport math\nimport re\nimport struct\nfrom dataclasses import dataclass\nfrom functools import reduce\nfrom . import ast_nodes as A\nfrom .scope import resolve\nfrom .evaluator import LuaNil, const_value, value_to_node, is_truthy, _bin\n\nMAX_VALUE = 2_000_000\nMAX_STEPS = 100_000\n\nclass Unknown(Exception):\n    pass\n\nclass LoopBreak(Exception): pass\nclass LoopContinue(Exception): pass\n\nclass Returned(Exception):\n    def __init__(self, values):\n        self.values = values\n\n@dataclass(frozen=True)\nclass Builtin:\n    path: str\n\n@dataclass\nclass FunctionValue:\n    node: A.Function\n    env: dict\n\n@dataclass\nclass IteratorValue:\n    rows: list\n\n@dataclass\nclass Multi:\n    values: tuple\n\nclass BufferValue:\n    def __init__(self, data): self.data=bytearray(data)\n\nclass TableValue:\n    def __init__(self):\n        self.data = {}\n    @staticmethod\n    def key(v):\n        if v is LuaNil or isinstance(v, (TableValue, FunctionValue, Multi, Builtin)):\n            raise Unknown(\'unsupported table key\')\n        if isinstance(v, float) and math.isnan(v):\n            raise Unknown(\'NaN key\')\n        return (type(v), v)\n    def get(self, k):\n        return self.data.get(self.key(k), LuaNil)\n    def set(self, k, v):\n        key = self.key(k)\n        if v is LuaNil:\n            self.data.pop(key, None)\n        else:\n            self.data[key] = v\n    def length(self):\n        n = 0\n        while self.get(float(n + 1)) is not LuaNil:\n            n += 1\n            if n > 100_000:\n                raise Unknown(\'table limit\')\n        if any(t is float and k > n and k == int(k) for t, k in self.data):\n            raise Unknown(\'table has holes\')\n        return n\n\ndef scalar(value):\n    if isinstance(value, Multi):\n        return value.values[0] if value.values else LuaNil\n    return value\n\ndef primitive(value):\n    return value is LuaNil or type(value) in (bool, float, str)\n\ndef number(v):\n    if type(v) is not float or not math.isfinite(v):\n        raise Unknown(\'expected finite number\')\n    return v\n\ndef integer(v):\n    n = number(v)\n    if n != int(n):\n        raise Unknown(\'expected integer\')\n    return int(n)\n\ndef text(v):\n    if not isinstance(v, str):\n        raise Unknown(\'expected byte string\')\n    if len(v) > MAX_VALUE:\n        raise Unknown(\'string limit\')\n    return v\n\ndef lua_text(v):\n    if isinstance(v, str): return v\n    if type(v) is float and v==0 and math.copysign(1.0,v)<0: return \'-0\'\n    if type(v) is float and math.isfinite(v) and v == int(v) and abs(v) < 1e14:\n        return str(int(v))\n    if v is LuaNil: return \'nil\'\n    if v is True: return \'true\'\n    if v is False: return \'false\'\n    raise Unknown(\'unsupported tostring value\')\n\ndef byte_index(i, length):\n    return i if i >= 0 else length + i + 1\n\ndef u32(v):\n    return math.trunc(number(v)) % 2**32\n\nROOTS = {\'string\', \'table\', \'math\', \'bit32\', \'utf8\', \'buffer\', \'tonumber\',\n         \'tostring\', \'type\', \'typeof\', \'select\', \'ipairs\', \'unpack\'}\n\nclass Evaluator:\n    def __init__(self, env=None, disabled=(), steps=MAX_STEPS):\n        self.env = dict(env or {})\n        self.disabled = set(disabled)\n        self.remaining = steps\n        self.owned_bindings = set()\n        self.owned_tables = set()\n        self.owned_buffers = set()\n        self.depth = 0\n        self.call_cache = {}\n\n    def tick(self):\n        self.remaining -= 1\n        if self.remaining < 0: raise Unknown(\'static evaluation step budget exhausted\')\n\n    def exprlist(self, nodes):\n        out = []\n        for i, node in enumerate(nodes):\n            v = self.expr(node)\n            if i == len(nodes) - 1 and isinstance(v, Multi): out.extend(v.values)\n            else: out.append(scalar(v))\n        return out\n\n    def expr(self, node):\n        self.tick()\n        k = node.kind\n        if k == \'Name\':\n            if node.binding is not None:\n                if node.binding not in self.env: raise Unknown(\'unknown local\')\n                return self.env[node.binding]\n            if node.name in ROOTS and node.name not in self.disabled:\n                return Builtin(node.name)\n            raise Unknown(\'unknown global\')\n        if k == \'Paren\': return scalar(self.expr(node.inner))\n        if k == \'Function\': return FunctionValue(node, self.env)\n        if k == \'Vararg\':\n            if \'...\' not in self.env: raise Unknown(\'unknown chunk varargs\')\n            return self.env[\'...\']\n        if k == \'Table\':\n            tab = TableValue(); self.owned_tables.add(id(tab)); pos = 1\n            for kind, key, val in node.fields:\n                if kind == \'pos\':\n                    result = self.expr(val)\n                    vals = result.values if isinstance(result, Multi) and val is node.fields[-1][2] else (scalar(result),)\n                    for value in vals: tab.set(float(pos), value); pos += 1\n                else:\n                    key = key if kind == \'name\' else scalar(self.expr(key))\n                    tab.set(key, scalar(self.expr(val)))\n            return tab\n        if k == \'Index\':\n            obj = scalar(self.expr(node.obj)); key = scalar(self.expr(node.key))\n            if isinstance(obj, Builtin) and isinstance(key, str):\n                path = obj.path + \'.\' + key\n                if path == \'math.pi\': return math.pi\n                if path == \'math.huge\': return math.inf\n                return Builtin(path)\n            if isinstance(obj, TableValue): return obj.get(key)\n            raise Unknown(\'index on unknown object\')\n        if k == \'UnOp\':\n            v = scalar(self.expr(node.operand))\n            if node.op == \'not\': return not is_truthy(v)\n            if node.op == \'-\': return -number(v)\n            if node.op == \'#\':\n                if isinstance(v, str): return float(len(v))\n                if isinstance(v, TableValue): return float(v.length())\n            raise Unknown(\'unknown unary expression\')\n        if k == \'BinOp\':\n            left = scalar(self.expr(node.left))\n            if node.op == \'and\': return scalar(self.expr(node.right)) if is_truthy(left) else left\n            if node.op == \'or\': return left if is_truthy(left) else scalar(self.expr(node.right))\n            right = scalar(self.expr(node.right))\n            if not primitive(left) or not primitive(right): raise Unknown(\'object operation\')\n            ok, v = _bin(node.op, left, right)\n            if not ok or isinstance(v, complex): raise Unknown(\'unknown binary expression\')\n            if isinstance(v, float) and not math.isfinite(v): raise Unknown(\'nonfinite value\')\n            return v\n        if k == \'Call\':\n            fn = scalar(self.expr(node.func)); args = self.exprlist(node.args)\n            return self.call(fn, args)\n        if k == \'MethodCall\':\n            obj = scalar(self.expr(node.obj))\n            if isinstance(obj, str): return self.builtin(\'string.\' + node.method, [obj] + self.exprlist(node.args))\n            raise Unknown(\'unknown method\')\n        ok, val = const_value(node)\n        if ok: return val\n        raise Unknown(\'unsupported expression \' + k)\n\n    def call(self, fn, args):\n        self.tick()\n        if isinstance(fn, Builtin):\n            key=None\n            if all(primitive(v) for v in args) and sum(len(v) for v in args if isinstance(v,str))<=4096:\n                key=(fn.path,tuple((type(v),v) for v in args))\n                if key in self.call_cache: return self.call_cache[key]\n            result=self.builtin(fn.path,args)\n            if key is not None and len(self.call_cache)<256 and (primitive(result) and (not isinstance(result,str) or len(result)<=4096)):\n                self.call_cache[key]=result\n            return result\n        if not isinstance(fn, FunctionValue) or self.depth >= 16: raise Unknown(\'unknown function or recursion limit\')\n        saved = self.env, self.owned_bindings\n        self.env = dict(fn.env)\n        self.owned_bindings = set()\n        self.depth += 1\n        try:\n            for i, param in enumerate(fn.node.params):\n                self.env[param.binding] = args[i] if i < len(args) else LuaNil\n                self.owned_bindings.add(param.binding)\n            if fn.node.is_vararg: self.env[\'...\'] = Multi(tuple(args[len(fn.node.params):]))\n            try: self.block(fn.node.body)\n            except Returned as result: return Multi(tuple(result.values))\n            return Multi(())\n        finally:\n            self.depth -= 1\n            self.env, self.owned_bindings = saved\n\n    def assign(self, target, value):\n        if isinstance(target, A.Name) and target.binding in self.owned_bindings:\n            self.env[target.binding] = value\n        elif isinstance(target, A.Index):\n            obj = scalar(self.expr(target.obj)); key = scalar(self.expr(target.key))\n            if not isinstance(obj, TableValue) or id(obj) not in self.owned_tables:\n                raise Unknown(\'write to captured or external table\')\n            obj.set(key, value)\n        else: raise Unknown(\'external assignment\')\n\n    def block(self, block):\n        for s in block.stmts:\n            self.tick(); k = s.kind\n            if k == \'Return\': raise Returned(self.exprlist(s.values))\n            if k == \'LocalAssign\':\n                values = self.exprlist(s.values)\n                for i, t in enumerate(s.targets):\n                    self.env[t.binding] = values[i] if i < len(values) else LuaNil\n                    self.owned_bindings.add(t.binding)\n            elif k == \'LocalFunction\':\n                self.owned_bindings.add(s.name.binding)\n                self.env[s.name.binding] = FunctionValue(s.func, self.env)\n            elif k == \'Assign\':\n                values = self.exprlist(s.values)\n                # Compute all lvalues before writing (Lua simultaneous assignment).\n                targets = []\n                for t in s.targets:\n                    if isinstance(t, A.Index):\n                        obj = scalar(self.expr(t.obj)); key = scalar(self.expr(t.key))\n                        if not isinstance(obj, TableValue) or id(obj) not in self.owned_tables: raise Unknown(\'external table mutation\')\n                        targets.append((obj, key))\n                    elif isinstance(t, A.Name) and t.binding in self.owned_bindings: targets.append(t.binding)\n                    else: raise Unknown(\'external assignment\')\n                for i, t in enumerate(targets):\n                    value = values[i] if i < len(values) else LuaNil\n                    if isinstance(t, tuple): t[0].set(t[1], value)\n                    else: self.env[t] = value\n            elif k == \'CompoundAssign\':\n                old = scalar(self.expr(s.target)); new = scalar(self.expr(s.value))\n                ok, v = _bin(s.op, old, new)\n                if not ok: raise Unknown(\'compound assignment\')\n                self.assign(s.target, v)\n            elif k == \'Break\': raise LoopBreak()\n            elif k == \'Continue\': raise LoopContinue()\n            elif k == \'Do\': self.block(s.body)\n            elif k == \'If\':\n                for cond, body in s.clauses:\n                    if is_truthy(scalar(self.expr(cond))): self.block(body); break\n                else:\n                    if s.orelse is not None: self.block(s.orelse)\n            elif k == \'NumericFor\':\n                a, b = number(scalar(self.expr(s.start))), number(scalar(self.expr(s.stop)))\n                step = number(scalar(self.expr(s.step))) if s.step else 1.0\n                if step == 0: raise Unknown(\'zero loop step\')\n                count = max(0, math.floor((b - a) / step) + 1)\n                if count > min(100_000, self.remaining): raise Unknown(\'loop budget exhausted\')\n                self.owned_bindings.add(s.var.binding)\n                v = a\n                for _ in range(count):\n                    self.env[s.var.binding] = v\n                    try: self.block(s.body)\n                    except LoopBreak: break\n                    except LoopContinue: pass\n                    v += step\n            elif k in (\'While\',\'Repeat\'):\n                while True:\n                    self.tick()\n                    if k==\'While\' and not is_truthy(scalar(self.expr(s.cond))): break\n                    try: self.block(s.body)\n                    except LoopBreak: break\n                    except LoopContinue: pass\n                    if k==\'Repeat\' and is_truthy(scalar(self.expr(s.cond))): break\n            elif k == \'GenericFor\':\n                values=self.exprlist(s.exprs)\n                if len(values)!=1: raise Unknown(\'unknown iterator tuple\')\n                iterator=values[0]\n                if isinstance(iterator,TableValue):\n                    # Restrict generalized iteration to fresh, dense arrays.\n                    n=iterator.length()\n                    if len(iterator.data)!=n: raise Unknown(\'non-array iteration order\')\n                    rows=[(float(i),iterator.get(float(i))) for i in range(1,n+1)]\n                elif isinstance(iterator,IteratorValue): rows=iterator.rows\n                else: raise Unknown(\'unknown iterator\')\n                for row in rows:\n                    self.tick()\n                    for i,target in enumerate(s.names):\n                        self.env[target.binding]=row[i] if i<len(row) else LuaNil\n                        self.owned_bindings.add(target.binding)\n                    try: self.block(s.body)\n                    except LoopBreak: break\n                    except LoopContinue: pass\n            elif k == \'CallStat\':\n                self.expr(s.call)\n            else: raise Unknown(\'unsupported statement \' + k)\n\n    def builtin(self, name, args):\n        self.tick()\n        a = args\n        def arity(lo, hi=None):\n            if not lo <= len(a) <= (lo if hi is None else hi): raise Unknown(\'arity\')\n        if name == \'string.char\':\n            if len(a) > MAX_VALUE: raise Unknown(\'size limit\')\n            ns = [integer(v) for v in a]\n            if any(v < 0 or v > 255 for v in ns): raise Unknown(\'byte range\')\n            return \'\'.join(map(chr, ns))\n        if name == \'utf8.char\':\n            ns = [integer(v) for v in a]\n            if any(v < 0 or v > 0x10ffff or 0xd800 <= v <= 0xdfff for v in ns): raise Unknown(\'code point\')\n            return \'\'.join(map(chr, ns)).encode(\'utf-8\').decode(\'latin1\')\n        if name in (\'string.reverse\', \'string.lower\', \'string.upper\', \'string.len\'):\n            arity(1); s = text(a[0])\n            if name.endswith(\'reverse\'): return s[::-1]\n            if name.endswith(\'len\'): return float(len(s))\n            # Luau\'s standard case conversion affects ASCII bytes only.\n            lo, hi, off = (65, 90, 32) if name.endswith(\'lower\') else (97, 122, -32)\n            return \'\'.join(chr(ord(c) + off) if lo <= ord(c) <= hi else c for c in s)\n        if name in (\'string.sub\', \'string.byte\'):\n            arity(1, 3); s = text(a[0]); n = len(s)\n            i = integer(a[1]) if len(a) > 1 else 1\n            j = integer(a[2]) if len(a) > 2 else (i if name.endswith(\'byte\') else -1)\n            i, j = max(1, byte_index(i, n)), min(n, byte_index(j, n))\n            s = s[i-1:j] if i <= j else \'\'\n            if name.endswith(\'byte\'): return Multi(tuple(float(ord(c)) for c in s))\n            return s\n        if name == \'string.rep\':\n            arity(2); s = text(a[0]); n = integer(a[1])\n            if max(0, n) * len(s) > MAX_VALUE: raise Unknown(\'size limit\')\n            return s * max(0, n)\n        if name == \'string.gmatch\':\n            arity(2); subject, pattern = text(a[0]), text(a[1])\n            # Fixed-width Lua patterns cover hex-pair and byte-wise decoders.\n            # Unsupported captures, repetition and frontier patterns are retained.\n            if pattern.startswith(\'(\') and pattern.endswith(\')\'):\n                pattern = pattern[1:-1]\n            classes = {\'%x\': \'[0-9a-fA-F]\', \'%d\': \'[0-9]\', \'%a\': \'[A-Za-z]\', \'%w\': \'[A-Za-z0-9]\'}\n            translated = []; pos = 0\n            while pos < len(pattern):\n                pair = pattern[pos:pos + 2]\n                if pair in classes:\n                    translated.append(classes[pair]); pos += 2\n                elif pattern[pos] == \'.\':\n                    translated.append(r\'[\\s\\S]\'); pos += 1\n                elif pattern[pos] in \'%()[]^$+*?-\':\n                    raise Unknown(\'unsupported gmatch pattern\')\n                else:\n                    translated.append(re.escape(pattern[pos])); pos += 1\n            if not translated: raise Unknown(\'empty gmatch pattern\')\n            rows = []\n            for match in re.finditer(\'\'.join(translated), subject):\n                self.tick()\n                if len(rows) >= 100_000: raise Unknown(\'iterator size limit\')\n                rows.append((match.group(0),))\n            return IteratorValue(rows)\n        if name == \'string.split\':\n            arity(2); subject, separator = text(a[0]), text(a[1])\n            parts = subject.split(separator) if separator else list(subject)\n            if len(parts) > 100_000: raise Unknown(\'split size limit\')\n            tab = TableValue(); self.owned_tables.add(id(tab))\n            for i, value in enumerate(parts, 1):\n                self.tick(); tab.set(float(i), value)\n            return tab\n        if name == \'string.format\':\n            # A deliberately exact subset of Lua formatting; decline ambiguous\n            # float formatting, flags, locale-dependent and quoted conversions.\n            if not a: raise Unknown(\'arity\')\n            template = text(a[0]); output = []; at = 0; argument = 1; size = 0\n            for match in re.finditer(r\'%(%|[scdiuoxX])\', template):\n                prefix = template[at:match.start()]\n                if \'%\' in prefix: raise Unknown(\'unsupported format\')\n                spec = match.group(1)\n                if spec == \'%\': value = \'%\'\n                else:\n                    if argument >= len(a): raise Unknown(\'arity\')\n                    item = a[argument]; argument += 1\n                    if spec == \'s\': value = lua_text(item)\n                    elif spec == \'c\':\n                        value_int = integer(item)\n                        if not 0 <= value_int <= 255: raise Unknown(\'byte range\')\n                        value = chr(value_int)\n                    else:\n                        value_int = integer(item)\n                        if not -(2**31) <= value_int < 2**31: raise Unknown(\'format integer range\')\n                        if spec in (\'u\',\'o\',\'x\',\'X\'): value_int &= 0xffffffff\n                        value = str(value_int) if spec in (\'d\',\'i\',\'u\') else format(value_int, spec)\n                size += len(prefix) + len(value)\n                if size > MAX_VALUE: raise Unknown(\'format size limit\')\n                output.extend((prefix, value)); at = match.end()\n            suffix = template[at:]\n            if \'%\' in suffix: raise Unknown(\'unsupported format\')\n            if size + len(suffix) > MAX_VALUE: raise Unknown(\'format size limit\')\n            return \'\'.join(output) + suffix\n        if name == \'ipairs\':\n            arity(1); tab=a[0]\n            if not isinstance(tab,TableValue): raise Unknown(\'expected table\')\n            rows=[]; i=1\n            while tab.get(float(i)) is not LuaNil:\n                self.tick();rows.append((float(i),tab.get(float(i))));i+=1\n            return IteratorValue(rows)\n        if name == \'table.create\':\n            arity(1,2); count=integer(a[0])\n            if not 0<=count<=100_000: raise Unknown(\'table size limit\')\n            tab=TableValue();self.owned_tables.add(id(tab))\n            if len(a)==2:\n                for i in range(1,count+1): self.tick();tab.set(float(i),a[1])\n            return tab\n        if name == \'table.remove\':\n            arity(1,2);tab=a[0]\n            if not isinstance(tab,TableValue) or id(tab) not in self.owned_tables: raise Unknown(\'external table mutation\')\n            n=tab.length();i=integer(a[1]) if len(a)>1 else n\n            if i==n and n==0: return LuaNil\n            if not 1<=i<=n: raise Unknown(\'table range\')\n            result=tab.get(float(i))\n            for k in range(i,n): self.tick();tab.set(float(k),tab.get(float(k+1)))\n            tab.set(float(n),LuaNil);return result\n        if name==\'string.gsub\':\n            arity(3,4); subject=text(a[0]);pattern=text(a[1]);replacement=a[2]\n            maximum=max(0,integer(a[3])) if len(a)>3 else 100_000\n            # An explicit Lua-pattern subset; never treat source as Python regex.\n            classes={\'%d\':\'[0-9]\',\'%x\':\'[0-9a-fA-F]\',\'%a\':\'[A-Za-z]\',\'%w\':\'[A-Za-z0-9]\',\'%s\':\'[ \\t\\r\\n\\f\\v]\',\'%z\':\'\\x00\'}\n            translated=[];pos=0\n            while pos<len(pattern):\n                item=pattern[pos:pos+2]\n                if item in classes: translated.append(classes[item]);pos+=2\n                elif pattern[pos]==\'.\': translated.append(r\'[\\s\\S]\');pos+=1\n                elif pattern[pos]==\'%\' and pos+1<len(pattern) and pattern[pos+1] in \'().%+-*?[]^$\': translated.append(re.escape(pattern[pos+1]));pos+=2\n                elif pattern[pos] in \'()[]^$+*?-\': raise Unknown(\'unsupported Lua pattern\')\n                else: translated.append(re.escape(pattern[pos]));pos+=1\n            if not translated: raise Unknown(\'empty pattern\')\n            rx=re.compile(\'\'.join(translated));parts=[];last=0;count=0;size=0\n            for match in rx.finditer(subject):\n                self.tick()\n                if count>=maximum: break\n                matched=match.group(0)\n                if isinstance(replacement,FunctionValue): value=scalar(self.call(replacement,[matched]))\n                elif isinstance(replacement,TableValue): value=replacement.get(matched)\n                elif isinstance(replacement,str):\n                    # Lua replacement templates: only %% and %0 are supported.\n                    value=\'\';q=0\n                    while q<len(replacement):\n                        if replacement[q]==\'%\':\n                            if q+1>=len(replacement) or replacement[q+1] not in \'%0\': raise Unknown(\'unsupported replacement template\')\n                            value+= \'%\' if replacement[q+1]==\'%\' else matched;q+=2\n                        else: value+=replacement[q];q+=1\n                else: raise Unknown(\'replacement\')\n                if value is LuaNil or value is False: value=matched\n                value=lua_text(value);prefix=subject[last:match.start()];size+=len(prefix)+len(value)\n                if size>MAX_VALUE: raise Unknown(\'string limit\')\n                parts.extend((prefix,value));last=match.end();count+=1\n            size+=len(subject)-last\n            if size>MAX_VALUE: raise Unknown(\'string limit\')\n            parts.append(subject[last:]);return Multi((\'\'.join(parts),float(count)))\n        if name==\'string.find\':\n            arity(2,4);subject=text(a[0]);needle=text(a[1])\n            start=integer(a[2]) if len(a)>2 else 1\n            if len(a)<4 or not is_truthy(a[3]):\n                if any(c in needle for c in \'^$()%.[]*+-?\'): raise Unknown(\'pattern find\')\n            start=max(1,byte_index(start,len(subject)))\n            found=subject.find(needle,start-1)\n            return LuaNil if found<0 else Multi((float(found+1),float(found+len(needle))))\n        if name == \'table.concat\':\n            arity(1, 4); tab = a[0]\n            if not isinstance(tab, TableValue): raise Unknown(\'expected table\')\n            sep = text(a[1]) if len(a) > 1 else \'\'\n            i = integer(a[2]) if len(a) > 2 else 1\n            j = integer(a[3]) if len(a) > 3 else tab.length()\n            if j-i > 100_000: raise Unknown(\'size limit\')\n            parts = [] ; size = 0\n            for k in range(i, j+1):\n                v = tab.get(float(k))\n                if type(v) not in (str, float): raise Unknown(\'concat element\')\n                v = lua_text(v); size += len(v) + len(sep)\n                if size > MAX_VALUE: raise Unknown(\'size limit\')\n                parts.append(v)\n            return sep.join(parts)\n        if name == \'table.insert\':\n            arity(2, 3); tab = a[0]\n            if not isinstance(tab, TableValue) or id(tab) not in self.owned_tables: raise Unknown(\'external table mutation\')\n            n = tab.length()\n            pos, value = (n+1, a[1]) if len(a) == 2 else (integer(a[1]), a[2])\n            if not 1 <= pos <= n+1 or n >= 100_000: raise Unknown(\'table limit\')\n            for k in range(n, pos-1, -1): tab.set(float(k+1), tab.get(float(k)))\n            tab.set(float(pos), value); return Multi(())\n        if name in (\'table.unpack\', \'unpack\'):\n            arity(1, 3); tab = a[0]\n            if not isinstance(tab, TableValue): raise Unknown(\'expected table\')\n            i = integer(a[1]) if len(a) > 1 else 1\n            j = integer(a[2]) if len(a) > 2 else tab.length()\n            if j-i > 100_000: raise Unknown(\'size limit\')\n            return Multi(tuple(tab.get(float(k)) for k in range(i, j+1)))\n        if name == \'tonumber\':\n            arity(1, 2)\n            if type(a[0]) is float and len(a) == 1: return a[0]\n            s = text(a[0]).strip(\' \\t\\n\\r\\v\\f\')\n            if \'_\' in s or any(ord(c)>127 for c in s): return LuaNil\n            try:\n                if len(a) == 2:\n                    base = integer(a[1])\n                    if not 2 <= base <= 36: raise Unknown(\'base range\')\n                    return float(int(s, base))\n                return float.fromhex(s) if \'0x\' in s.lower() else float(s)\n            except ValueError: return LuaNil\n        if name == \'tostring\': arity(1); return lua_text(a[0])\n        if name in (\'type\', \'typeof\'):\n            arity(1); v = a[0]\n            if v is LuaNil: return \'nil\'\n            if type(v) is bool: return \'boolean\'\n            if type(v) is float: return \'number\'\n            if type(v) is str: return \'string\'\n            if isinstance(v, TableValue): return \'table\'\n            if isinstance(v, (Builtin, FunctionValue)): return \'function\'\n            raise Unknown(\'type\')\n        if name == \'select\':\n            arity(1, 100_000)\n            if a[0] == \'#\': return float(len(a)-1)\n            i = integer(a[0]); n = len(a)-1\n            if i < 0: i = n+i+1\n            if i <= 0: raise Unknown(\'select index\')\n            return Multi(tuple(a[i:]))\n        if name.startswith(\'math.\'):\n            op = name[5:]\n            unary = {\'floor\': math.floor, \'ceil\': math.ceil, \'abs\': abs, \'sqrt\': math.sqrt}\n            if op in unary:\n                arity(1); value=number(a[0])\n                if value==0 and op in (\'floor\',\'ceil\',\'sqrt\'): return value\n                return float(unary[op](value))\n            if op in (\'min\', \'max\'):\n                arity(1, 100_000); return (min if op == \'min\' else max)(map(number, a))\n            if op == \'clamp\': arity(3); x, lo, hi = map(number, a); return max(lo, min(x, hi)) if lo <= hi else (_ for _ in ()).throw(Unknown(\'clamp bounds\'))\n            if op == \'modf\':\n                arity(1); frac,whole=math.modf(number(a[0]));return Multi((whole,frac))\n            if op == \'ldexp\': arity(2); return math.ldexp(number(a[0]), integer(a[1]))\n            if op == \'fmod\': arity(2); return math.fmod(*map(number, a))\n            raise Unknown(\'unsupported math operation\')\n        if name.startswith(\'bit32.\'):\n            op = name[6:]\n            if op in (\'bxor\', \'band\', \'bor\', \'btest\'):\n                ns = [u32(v) for v in a]\n                initial = 0xffffffff if op in (\'band\', \'btest\') else 0\n                fn = (lambda x,y:x^y) if op == \'bxor\' else (lambda x,y:x&y) if op in (\'band\',\'btest\') else (lambda x,y:x|y)\n                result = reduce(fn, ns, initial)\n                return bool(result) if op == \'btest\' else float(result)\n            if op == \'bnot\': arity(1); return float(u32(a[0]) ^ 0xffffffff)\n            if op in (\'lshift\', \'rshift\', \'arshift\', \'lrotate\', \'rrotate\'):\n                arity(2); x, n = u32(a[0]), integer(a[1])\n                if op in (\'lrotate\',\'rrotate\'):\n                    n %= 32\n                    if op == \'rrotate\': n = (-n) % 32\n                    return float(((x << n) | (x >> ((32-n) % 32))) & 0xffffffff)\n                if n < 0:\n                    op = \'lshift\' if op != \'lshift\' else \'rshift\'; n = -n\n                if op == \'arshift\':\n                    if x >= 2**31: x -= 2**32\n                    return float((x >> min(n, 32)) & 0xffffffff)\n                if n >= 32: return 0.0\n                return float((x << n) & 0xffffffff if op == \'lshift\' else x >> n)\n            if op in (\'extract\', \'replace\'):\n                arity(2, 3) if op == \'extract\' else arity(3, 4)\n                x = u32(a[0]); field = integer(a[1 if op == \'extract\' else 2])\n                width = integer(a[2 if op == \'extract\' else 3]) if len(a) == (3 if op == \'extract\' else 4) else 1\n                if field < 0 or width <= 0 or field+width > 32: raise Unknown(\'bit field\')\n                mask = (1 << width)-1\n                return float((x >> field) & mask) if op == \'extract\' else float((x & ~(mask << field)) | ((u32(a[1]) & mask) << field))\n            if op in (\'countlz\', \'countrz\'):\n                arity(1); x = u32(a[0]); return float(32 if x == 0 else 32-x.bit_length() if op == \'countlz\' else (x & -x).bit_length()-1)\n            if op == \'byteswap\': arity(1); return float(int.from_bytes(u32(a[0]).to_bytes(4,\'little\'),\'big\'))\n            raise Unknown(\'unsupported bit32 operation\')\n        if name in (\'buffer.create\', \'buffer.fromstring\'):\n            arity(1)\n            if name.endswith(\'create\'):\n                size=integer(a[0])\n                if not 0 <= size <= MAX_VALUE: raise Unknown(\'buffer size limit\')\n                buf=BufferValue(bytes(size))\n            else: buf=BufferValue(text(a[0]).encode(\'latin1\'))\n            self.owned_buffers.add(id(buf)); return buf\n        if name in (\'buffer.len\', \'buffer.tostring\'):\n            arity(1); buf=a[0]\n            if not isinstance(buf,BufferValue): raise Unknown(\'expected buffer\')\n            return float(len(buf.data)) if name.endswith(\'len\') else bytes(buf.data).decode(\'latin1\')\n        if name.startswith((\'buffer.read\',\'buffer.write\')):\n            write=name.startswith(\'buffer.write\'); op=name[12:] if write else name[11:]\n            formats={\'i8\':(\'b\',1),\'u8\':(\'B\',1),\'i16\':(\'h\',2),\'u16\':(\'H\',2),\n                     \'i32\':(\'i\',4),\'u32\':(\'I\',4),\'f32\':(\'f\',4),\'f64\':(\'d\',8)}\n            if op==\'string\':\n                arity(3,4) if write else arity(3)\n                buf=a[0]; off=integer(a[1]); value=text(a[2]) if write else None\n                size=integer(a[3]) if write and len(a)>3 else len(value) if write else integer(a[2])\n            elif op in formats:\n                arity(3) if write else arity(2)\n                buf=a[0]; off=integer(a[1]); fmt,size=formats[op]\n            else: raise Unknown(\'unsupported buffer operation\')\n            if not isinstance(buf,BufferValue) or off<0 or size<0 or off+size>len(buf.data): raise Unknown(\'buffer range\')\n            if write:\n                if id(buf) not in self.owned_buffers: raise Unknown(\'external buffer mutation\')\n                if op==\'string\':\n                    if size>len(value): raise Unknown(\'write string range\')\n                    buf.data[off:off+size]=value[:size].encode(\'latin1\')\n                else:\n                    value=number(a[2])\n                    if op[0] in \'iu\':\n                        value=math.trunc(value) % (1 << (size*8))\n                        if op[0]==\'i\' and value>=1 << (size*8-1): value-=1 << (size*8)\n                    struct.pack_into(\'<\'+fmt,buf.data,off,value)\n                return Multi(())\n            if op==\'string\': return bytes(buf.data[off:off+size]).decode(\'latin1\')\n            return float(struct.unpack_from(\'<\'+fmt,buf.data,off)[0])\n        raise Unknown(\'unsupported builtin \' + name)\n\n\ndef _analysis(chunk):\n    resolver = resolve(chunk)\n    parents = {}\n    disabled = set()\n    nodes = list(A.walk(chunk))\n    for node in nodes:\n        for child in A.iter_child_nodes(node): parents[id(child)] = node\n        if isinstance(node, (A.Assign, A.CompoundAssign)):\n            targets = node.targets if isinstance(node, A.Assign) else [node.target]\n            for t in targets:\n                while isinstance(t, A.Index): t = t.obj\n                if isinstance(t, A.Name) and t.binding is None: disabled.add(t.name)\n        if isinstance(node, A.Call) and isinstance(node.func, A.Name) and node.func.binding is None and node.func.name in (\'getfenv\', \'setfenv\'):\n            disabled.update(ROOTS)\n    return resolver, parents, disabled, nodes\n\n\ndef run(chunk, ctx):\n    """Propagate immutable locals and evaluate closed, pure decoder helpers."""\n    if ctx.options.get(\'simple\'):\n        resolver=None; parents={}; nodes=[]\n        disabled=ROOTS if ctx.options.get(\'dynamic_environment\') else set()\n    else:\n        resolver, parents, disabled, nodes = _analysis(chunk)\n    values = {}\n    evaluator = Evaluator(values, disabled)\n    # AST walk is reverse-order; collect declaration order from source lines by\n    # a proper visitor instead so a forward reference never becomes a constant.\n    declarations = []\n    class Collect(A.NodeVisitor):\n        def visit_LocalAssign(self, node):\n            declarations.append(node)\n            self.generic_visit(node)\n        def visit_LocalFunction(self, node):\n            declarations.append(node)\n            self.generic_visit(node)\n    Collect().visit(chunk)\n    for node in declarations:\n        targets = [node.name] if isinstance(node, A.LocalFunction) else node.targets\n        expressions = [node.func] if isinstance(node, A.LocalFunction) else node.values\n        if not expressions:\n            continue\n        try:\n            evaluator.env = dict(values)\n            evaluator.owned_tables = set(); evaluator.owned_buffers = set()\n            results = evaluator.exprlist(expressions)\n            pending = {}\n            for index, target in enumerate(targets):\n                if resolver.bindings[target.binding].writes:\n                    continue\n                result = results[index] if index < len(results) else LuaNil\n                if isinstance(result, TableValue):\n                    if any(not primitive(v) for v in result.data.values()): raise Unknown(\'nested mutable table\')\n                    # Every use must be a read-only index (never an escape, alias,\n                    # mutation, or argument passed to an arbitrary function).\n                    for use in resolver.bindings[target.binding].uses:\n                        p = parents.get(id(use)); gp = parents.get(id(p))\n                        if not isinstance(p, A.Index) or p.obj is not use:\n                            raise Unknown(\'table escapes\')\n                        if isinstance(gp, A.Assign) and p in gp.targets or isinstance(gp, A.CompoundAssign) and p is gp.target:\n                            raise Unknown(\'table is mutated\')\n                if not (primitive(result) or isinstance(result,(TableValue,FunctionValue,Builtin))): raise Unknown(\'mutable value\')\n                pending[target.binding] = result\n            values.update(pending)\n        except (Unknown, LoopBreak, LoopContinue, ArithmeticError, ValueError, TypeError, IndexError, RecursionError):\n            continue\n\n    values_by_binding=values\n    class Fold(A.NodeTransformer):\n        def __init__(self):\n            self.protected = 0\n        def try_value(self, node):\n            if self.protected: return node\n            try:\n                evaluator.env = dict(values)\n                evaluator.owned_tables = set()\n                evaluator.owned_buffers = set()\n                v = evaluator.expr(node)\n                if isinstance(v, Multi):\n                    if len(v.values) != 1: return node\n                    v = v.values[0]\n                if not primitive(v) or isinstance(v, float) and not math.isfinite(v): return node\n                if isinstance(v, str) and len(v) > MAX_VALUE: return node\n                ctx.bump(\'static_expressions_recovered\')\n                return value_to_node(v)\n            except (Unknown, LoopBreak, LoopContinue, ArithmeticError, ValueError, TypeError, IndexError, RecursionError):\n                return node\n        def folded_list(self, nodes):\n            values=[self.visit(v) for v in nodes]\n            if values and isinstance(values[-1],(A.Call,A.MethodCall,A.Vararg)):\n                try:\n                    evaluator.env=dict(values_by_binding)\n                    evaluator.owned_tables=set(); evaluator.owned_buffers=set()\n                    result=evaluator.expr(values[-1])\n                    if isinstance(result,Multi) and len(result.values)<=1024 and all(primitive(v) and not (isinstance(v,float) and not math.isfinite(v)) for v in result.values):\n                        values=values[:-1]+[value_to_node(v) for v in result.values]\n                        ctx.bump(\'multi_results_recovered\')\n                except (Unknown,ArithmeticError,ValueError,TypeError,IndexError,RecursionError): pass\n            return values\n        def visit_Return(self,node):\n            node.values=self.folded_list(node.values); return node\n        def visit_Name(self, node):\n            return self.try_value(node) if node.binding in values and primitive(values[node.binding]) else node\n        def visit_Call(self, node):\n            saved=self.protected\n            self.protected=1\n            node.func = self.visit(node.func)\n            self.protected=0\n            node.args = [self.visit(a) for a in node.args]\n            self.protected=saved\n            return self.try_value(node)\n        def visit_CallStat(self, node):\n            # Dropping or replacing a call-statement with a literal is invalid.\n            self.protected += 1\n            node.call = self.visit(node.call)\n            self.protected -= 1\n            # Arguments can still be folded without evaluating the statement.\n            node.call.args = [self.visit(a) for a in node.call.args]\n            return node\n        def visit_MethodCall(self, node): return self.try_value(self.generic_visit(node))\n        def visit_BinOp(self, node): return self.try_value(self.generic_visit(node))\n        def visit_UnOp(self, node): return self.try_value(self.generic_visit(node))\n        def visit_Paren(self, node): return self.try_value(self.generic_visit(node))\n        def visit_Index(self, node):\n            # Preserve callee/lvalue identities while folding key expressions.\n            self.protected += 1; node.obj = self.visit(node.obj); self.protected -= 1\n            node.key = self.visit(node.key)\n            return self.try_value(node)\n        def visit_LocalAssign(self, node):\n            node.values = self.folded_list(node.values); return node\n        def visit_LocalFunction(self, node): node.func = self.visit(node.func); return node\n        def visit_Function(self, node):\n            node.body = self.visit(node.body); return node\n        def visit_FunctionDecl(self, node): node.func = self.visit(node.func); return node\n        def visit_Assign(self, node):\n            self.protected += 1; node.targets = [self.visit(t) for t in node.targets]; self.protected -= 1\n            node.values = self.folded_list(node.values); return node\n        def visit_CompoundAssign(self, node):\n            self.protected += 1; node.target = self.visit(node.target); self.protected -= 1\n            node.value = self.visit(node.value); return node\n        def visit_NumericFor(self, node):\n            node.start = self.visit(node.start); node.stop = self.visit(node.stop)\n            if node.step: node.step = self.visit(node.step)\n            node.body = self.visit(node.body); return node\n        def visit_GenericFor(self, node):\n            node.exprs = [self.visit(e) for e in node.exprs]; node.body = self.visit(node.body); return node\n    return Fold().visit(chunk)\n', False), '_lelsploit_ast.scope': ('"""Lexical scope / binding resolution.\n\nAfter :func:`resolve`, every :class:`ast_nodes.Name` that refers to a local has\n``name.binding`` set to a small integer id, and ``binding`` is ``None`` for a\nfree (global) reference.  ``Resolver.bindings`` maps id -> :class:`Binding` with\nthe definition sites and use sites, which the rename / substitution passes rely\non.\n"""\n\nfrom __future__ import annotations\n\nfrom dataclasses import dataclass, field\nfrom typing import Dict, List, Optional\n\nfrom . import ast_nodes as A\n\n\n@dataclass\nclass Binding:\n    id: int\n    name: str\n    kind: str                      # \'local\' | \'param\' | \'loop\' | \'localfunc\'\n    defs: List[A.Name] = field(default_factory=list)\n    uses: List[A.Name] = field(default_factory=list)\n    # number of assignments (Assign targets) after definition\n    writes: int = 0\n\n\nclass _Scope:\n    def __init__(self, parent: Optional["_Scope"], func_boundary: bool = False):\n        self.parent = parent\n        self.func_boundary = func_boundary\n        self.names: Dict[str, int] = {}\n\n    def declare(self, name: str, bid: int):\n        self.names[name] = bid\n\n    def lookup(self, name: str) -> Optional[int]:\n        s = self\n        while s is not None:\n            if name in s.names:\n                return s.names[name]\n            s = s.parent\n        return None\n\n\nclass Resolver:\n    def __init__(self):\n        self.bindings: Dict[int, Binding] = {}\n        self._next = 1\n\n    def _new_binding(self, name: str, kind: str) -> int:\n        bid = self._next\n        self._next += 1\n        self.bindings[bid] = Binding(id=bid, name=name, kind=kind)\n        return bid\n\n    def resolve(self, chunk: A.Chunk):\n        top = _Scope(None, func_boundary=True)\n        self._block(chunk.body, top)\n        return self\n\n    # -- helpers -----------------------------------------------------\n    def _declare(self, scope: _Scope, name_node: A.Name, kind: str) -> int:\n        bid = self._new_binding(name_node.name, kind)\n        scope.declare(name_node.name, bid)\n        name_node.binding = bid\n        self.bindings[bid].defs.append(name_node)\n        return bid\n\n    def _use(self, scope: _Scope, name_node: A.Name):\n        bid = scope.lookup(name_node.name)\n        name_node.binding = bid\n        if bid is not None:\n            self.bindings[bid].uses.append(name_node)\n\n    # -- blocks / statements ---------------------------------------\n    def _block(self, block: A.Block, parent: _Scope):\n        scope = _Scope(parent)\n        for st in block.stmts:\n            self._stat(st, scope)\n\n    def _stat(self, s: A.Node, scope: _Scope):\n        k = s.kind\n        if k == "LocalAssign":\n            for v in s.values:\n                self._expr(v, scope)\n            for t in s.targets:\n                self._declare(scope, t, "local")\n        elif k == "LocalFunction":\n            self._declare(scope, s.name, "localfunc")\n            self._function(s.func, scope)\n        elif k == "Assign":\n            for v in s.values:\n                self._expr(v, scope)\n            for t in s.targets:\n                self._expr(t, scope)\n                if isinstance(t, A.Name) and t.binding is not None:\n                    self.bindings[t.binding].writes += 1\n        elif k == "CompoundAssign":\n            self._expr(s.value, scope)\n            self._expr(s.target, scope)\n            if isinstance(s.target, A.Name) and s.target.binding is not None:\n                self.bindings[s.target.binding].writes += 1\n        elif k == "CallStat":\n            self._expr(s.call, scope)\n        elif k == "Do":\n            self._block(s.body, scope)\n        elif k == "While":\n            self._expr(s.cond, scope)\n            self._block(s.body, scope)\n        elif k == "Repeat":\n            # \'until\' can see body locals -> share one scope\n            inner = _Scope(scope)\n            for st in s.body.stmts:\n                self._stat(st, inner)\n            self._expr(s.cond, inner)\n        elif k == "If":\n            for cond, body in s.clauses:\n                self._expr(cond, scope)\n                self._block(body, scope)\n            if s.orelse is not None:\n                self._block(s.orelse, scope)\n        elif k == "NumericFor":\n            self._expr(s.start, scope)\n            self._expr(s.stop, scope)\n            if s.step is not None:\n                self._expr(s.step, scope)\n            inner = _Scope(scope)\n            self._declare(inner, s.var, "loop")\n            for st in s.body.stmts:\n                self._stat(st, inner)\n        elif k == "GenericFor":\n            for e in s.exprs:\n                self._expr(e, scope)\n            inner = _Scope(scope)\n            for n in s.names:\n                self._declare(inner, n, "loop")\n            for st in s.body.stmts:\n                self._stat(st, inner)\n        elif k == "FunctionDecl":\n            self._expr(s.target, scope)\n            self._function(s.func, scope)\n        elif k == "Return":\n            for v in s.values:\n                self._expr(v, scope)\n        elif k in ("Break", "Continue", "Goto", "Label"):\n            pass\n        else:\n            # unknown statement: walk generically\n            for child in A.iter_child_nodes(s):\n                self._maybe(child, scope)\n\n    def _function(self, fn: A.Function, parent: _Scope):\n        scope = _Scope(parent, func_boundary=True)\n        for p in fn.params:\n            self._declare(scope, p, "param")\n        for st in fn.body.stmts:\n            self._stat(st, scope)\n\n    # -- expressions -----------------------------------------------\n    def _maybe(self, node, scope):\n        if isinstance(node, A.Node):\n            self._expr(node, scope)\n\n    def _expr(self, e: A.Node, scope: _Scope):\n        k = e.kind\n        if k == "Name":\n            self._use(scope, e)\n        elif k == "Function":\n            self._function(e, scope)\n        elif k == "Index":\n            self._expr(e.obj, scope)\n            self._expr(e.key, scope)\n        elif k == "Call":\n            self._expr(e.func, scope)\n            for a in e.args:\n                self._expr(a, scope)\n        elif k == "MethodCall":\n            self._expr(e.obj, scope)\n            for a in e.args:\n                self._expr(a, scope)\n        elif k == "BinOp":\n            self._expr(e.left, scope)\n            self._expr(e.right, scope)\n        elif k == "UnOp":\n            self._expr(e.operand, scope)\n        elif k == "Paren":\n            self._expr(e.inner, scope)\n        elif k == "Table":\n            for kind, key, val in e.fields:\n                if isinstance(key, A.Node):\n                    self._expr(key, scope)\n                self._expr(val, scope)\n        elif k in ("Number", "String", "Nil", "TrueExpr", "FalseExpr", "Vararg"):\n            pass\n        else:\n            for child in A.iter_child_nodes(e):\n                self._maybe(child, scope)\n\n\ndef resolve(chunk: A.Chunk) -> Resolver:\n    return Resolver().resolve(chunk)\n', False), '_lelsploit_ast.tidy': ('"""Conservative cleanup that preserves scopes and potentially effectful tests."""\nfrom . import ast_nodes as A\nfrom .scope import resolve\n\ndef run(chunk, ctx):\n    for _ in range(8):\n        resolver = resolve(chunk)\n        changed = False\n        def unused(name):\n            b = resolver.bindings.get(name.binding)\n            return b and not b.uses and not b.writes\n        def pure(node):\n            if isinstance(node, (A.Number, A.String, A.Nil, A.TrueExpr, A.FalseExpr, A.Function)): return True\n            if isinstance(node, A.Table):\n                return all(pure(v) and (kind != \'expr\' or pure(k)) for kind,k,v in node.fields)\n            return False\n        class Tidy(A.NodeTransformer):\n            def visit_LocalAssign(self, node):\n                nonlocal changed\n                node = self.generic_visit(node)\n                if len(node.targets) != len(node.values): return node\n                kept = [(t,v) for t,v in zip(node.targets,node.values) if not (unused(t) and pure(v))]\n                if len(kept) != len(node.targets):\n                    changed = True; ctx.bump(\'unused_pure_locals_removed\', len(node.targets)-len(kept))\n                    if not kept: return None\n                    node.targets, node.values = map(list, zip(*kept))\n                return node\n            def visit_LocalFunction(self, node):\n                nonlocal changed\n                if unused(node.name): changed=True; ctx.bump(\'unused_helpers_removed\'); return None\n                return self.generic_visit(node)\n            def visit_Do(self, node):\n                nonlocal changed\n                node = self.generic_visit(node)\n                if not node.body.stmts: changed=True; return None\n                # Keep lexical scope whenever a direct declaration remains.\n                if not any(isinstance(s,(A.LocalAssign,A.LocalFunction)) for s in node.body.stmts):\n                    changed=True; return node.body.stmts\n                return node\n        chunk = Tidy().visit(chunk)\n        if not changed: break\n    return chunk\n', False), '_lelsploit_ast.unparser': ('"""AST -> formatted Lua source.\n\nPrecedence-aware so the emitted text re-parses to an equivalent tree; keeps\nthings readable with 2-space indentation.\n"""\n\nfrom __future__ import annotations\n\nimport keyword as _pykw\nimport re\nfrom typing import List\n\nfrom . import ast_nodes as A\nfrom .lexer import KEYWORDS\n\n\n_BIN_PREC = {\n    "or": 1, "and": 2,\n    "<": 3, ">": 3, "<=": 3, ">=": 3, "~=": 3, "==": 3,\n    "|": 4, "~": 5, "&": 6, "<<": 7, ">>": 7,\n    "..": 9,\n    "+": 10, "-": 10,\n    "*": 11, "/": 11, "//": 11, "%": 11,\n    "^": 14,\n}\n_UNARY_PREC = 12\n_RIGHT_ASSOC = {"..", "^"}\n\n\ndef _is_ident(s: str) -> bool:\n    if not s or (not s[0].isalpha() and s[0] != "_"):\n        return False\n    return all(c.isalnum() or c == "_" for c in s) and s not in KEYWORDS\n\n\ndef _quote(s: str) -> str:\n    try:\n        decoded = s.encode("latin1").decode("utf-8")\n    except (UnicodeError, ValueError):\n        decoded = None\n    value = decoded if decoded is not None else s\n    out = [\'"\']\n    for c in value:\n        n = ord(c)\n        if c == \'"\': out.append(\'\\\\"\')\n        elif c == "\\\\": out.append("\\\\\\\\")\n        elif c == "\\n": out.append("\\\\n")\n        elif c == "\\r": out.append("\\\\r")\n        elif c == "\\t": out.append("\\\\t")\n        elif n < 32 or n == 127 or decoded is None and n >= 127: out.append("\\\\%03d" % n)\n        else: out.append(c)\n    out.append(\'"\')\n    return "".join(out)\n\n\ndef _fmt_number(n: A.Number) -> str:\n    v = n.value\n    if v == 0 and __import__("math").copysign(1.0,v)<0: return "-0.0"\n    if v != v:  # nan\n        return "(0/0)"\n    if v == float("inf"):\n        return "(1/0)"\n    if v == float("-inf"):\n        return "(-1/0)"\n    if v == int(v) and abs(v) < 1e15:\n        iv = int(v)\n        # Reuse hex spelling when the source used one and it is still tidy.\n        if n.raw and n.raw.strip().lower().startswith("0x") and "." not in n.raw:\n            return hex(iv) if iv >= 0 else "-" + hex(-iv)\n        return str(iv)\n    r = repr(v)\n    return r\n\n\nclass Unparser:\n    def __init__(self, indent: str = "  "):\n        self.indent = indent\n        self.out: List[str] = []\n        self.level = 0\n\n    # -- helpers ------------------------------------------------------\n    def _line(self, text: str):\n        self.out.append(self.indent * self.level + text)\n\n    def emit(self, chunk: A.Chunk) -> str:\n        self._block(chunk.body)\n        return "\\n".join(self.out) + "\\n"\n\n    def _block(self, block: A.Block):\n        for st in block.stmts:\n            self._stat(st)\n\n    # -- statements -------------------------------------------------\n    def _stat(self, s: A.Node):\n        m = getattr(self, "_st_" + s.kind, None)\n        if m is None:\n            raise NotImplementedError(f"unparse statement {s.kind}")\n        before = len(self.out)\n        m(s)\n        # A statement that begins with \'(\' can be glued onto the previous\n        # statement by Lua\'s grammar (`a = b` newline `(f)()` parses as\n        # `a = b(f)()`).  Guard it with a leading empty statement -- but only\n        # when there actually is a preceding line.\n        if before > 0 and len(self.out) > before:\n            if self.out[before].lstrip().startswith("("):\n                self.out[before] = self.out[before].replace("(", ";(", 1)\n\n    def _st_LocalAssign(self, s: A.LocalAssign):\n        names = []\n        for i, t in enumerate(s.targets):\n            nm = self._sanitize(t.name)\n            if i < len(s.attribs) and s.attribs[i]:\n                nm += " <%s>" % s.attribs[i]\n            names.append(nm)\n        text = "local " + ", ".join(names)\n        if s.values:\n            text += " = " + ", ".join(self._expr(v) for v in s.values)\n        self._line(text)\n\n    def _st_Assign(self, s: A.Assign):\n        lhs = ", ".join(self._expr(t) for t in s.targets)\n        rhs = ", ".join(self._expr(v) for v in s.values)\n        self._line(f"{lhs} = {rhs}")\n\n    def _st_CompoundAssign(self, s: A.CompoundAssign):\n        self._line(f"{self._expr(s.target)} {s.op}= {self._expr(s.value)}")\n\n    def _st_CallStat(self, s: A.CallStat):\n        self._line(self._expr(s.call))\n\n    def _st_Do(self, s: A.Do):\n        self._line("do")\n        self.level += 1\n        self._block(s.body)\n        self.level -= 1\n        self._line("end")\n\n    def _st_While(self, s: A.While):\n        self._line(f"while {self._expr(s.cond)} do")\n        self.level += 1\n        self._block(s.body)\n        self.level -= 1\n        self._line("end")\n\n    def _st_Repeat(self, s: A.Repeat):\n        self._line("repeat")\n        self.level += 1\n        self._block(s.body)\n        self.level -= 1\n        self._line(f"until {self._expr(s.cond)}")\n\n    def _st_If(self, s: A.If):\n        for i, (cond, body) in enumerate(s.clauses):\n            kw = "if" if i == 0 else "elseif"\n            self._line(f"{kw} {self._expr(cond)} then")\n            self.level += 1\n            self._block(body)\n            self.level -= 1\n        if s.orelse is not None:\n            self._line("else")\n            self.level += 1\n            self._block(s.orelse)\n            self.level -= 1\n        self._line("end")\n\n    def _st_NumericFor(self, s: A.NumericFor):\n        parts = [self._expr(s.start), self._expr(s.stop)]\n        if s.step is not None:\n            parts.append(self._expr(s.step))\n        self._line(f"for {self._sanitize(s.var.name)} = {\', \'.join(parts)} do")\n        self.level += 1\n        self._block(s.body)\n        self.level -= 1\n        self._line("end")\n\n    def _st_GenericFor(self, s: A.GenericFor):\n        names = ", ".join(self._sanitize(n.name) for n in s.names)\n        exprs = ", ".join(self._expr(e) for e in s.exprs)\n        self._line(f"for {names} in {exprs} do")\n        self.level += 1\n        self._block(s.body)\n        self.level -= 1\n        self._line("end")\n\n    def _st_FunctionDecl(self, s: A.FunctionDecl):\n        name = self._func_target(s.target, s.is_method)\n        params = self._params(s.func, skip_self=s.is_method)\n        self._line(f"function {name}({params})")\n        self.level += 1\n        self._block(s.func.body)\n        self.level -= 1\n        self._line("end")\n\n    def _st_LocalFunction(self, s: A.LocalFunction):\n        params = self._params(s.func)\n        self._line(f"local function {self._sanitize(s.name.name)}({params})")\n        self.level += 1\n        self._block(s.func.body)\n        self.level -= 1\n        self._line("end")\n\n    def _st_Return(self, s: A.Return):\n        if s.values:\n            self._line("return " + ", ".join(self._expr(v) for v in s.values))\n        else:\n            self._line("return")\n\n    def _st_Break(self, s: A.Break):\n        self._line("break")\n\n    def _st_Continue(self, s: A.Continue):\n        self._line("continue")\n\n    def _st_Goto(self, s: A.Goto):\n        self._line(f"goto {s.label}")\n\n    def _st_Label(self, s: A.Label):\n        self._line(f"::{s.name}::")\n\n    # -- function bits ------------------------------------------------\n    def _params(self, fn: A.Function, skip_self: bool = False) -> str:\n        names = [self._sanitize(p.name) for p in fn.params]\n        if skip_self and names and names[0] == "self":\n            names = names[1:]\n        if fn.is_vararg:\n            names.append("...")\n        return ", ".join(names)\n\n    def _func_target(self, target: A.Node, is_method: bool) -> str:\n        # target is Name / Index chain of dotted string keys\n        parts = []\n        node = target\n        chain = []\n        while isinstance(node, A.Index):\n            chain.append(node.key.value)\n            node = node.obj\n        chain.append(node.name)\n        chain.reverse()\n        if is_method:\n            head = ".".join(chain[:-1])\n            return f"{head}:{chain[-1]}"\n        return ".".join(chain)\n\n    # -- expressions ------------------------------------------------\n    def _sanitize(self, name: str) -> str:\n        return name\n\n    def _expr(self, e: A.Node, parent_prec: int = 0, right: bool = False) -> str:\n        m = getattr(self, "_ex_" + e.kind, None)\n        if m is None:\n            raise NotImplementedError(f"unparse expr {e.kind}")\n        return m(e, parent_prec, right)\n\n    def _ex_Nil(self, e, *_):\n        return "nil"\n\n    def _ex_TrueExpr(self, e, *_):\n        return "true"\n\n    def _ex_FalseExpr(self, e, *_):\n        return "false"\n\n    def _ex_Vararg(self, e, *_):\n        return "..."\n\n    def _ex_Number(self, e, *_):\n        return _fmt_number(e)\n\n    def _ex_String(self, e, *_):\n        # Retain unchanged long literals: quoting a large Base85 payload adds\n        # escapes and can enlarge the output by hundreds of kilobytes.\n        if e.raw and e.raw.startswith(\'[\'):\n            m=re.match(r\'\\[(=*)\\[\',e.raw)\n            if m:\n                closer=\']\'+m.group(1)+\']\'\n                if e.raw.endswith(closer):\n                    body=e.raw[m.end():-len(closer)]\n                    if body.startswith(\'\\r\\n\'):body=body[2:]\n                    elif body.startswith((\'\\r\',\'\\n\')):body=body[1:]\n                    body=body.replace(\'\\r\\n\',\'\\n\').replace(\'\\r\',\'\\n\').encode(\'utf-8\').decode(\'latin1\')\n                    if body==e.value:return e.raw\n        return _quote(e.value)\n\n    def _ex_Name(self, e, *_):\n        return self._sanitize(e.name)\n\n    def _ex_Index(self, e: A.Index, *_):\n        base = self._prefix(e.obj)\n        if e.dot and isinstance(e.key, A.String) and _is_ident(e.key.value):\n            return f"{base}.{e.key.value}"\n        return f"{base}[{self._expr(e.key)}]"\n\n    def _ex_Call(self, e: A.Call, *_):\n        return f"{self._prefix(e.func)}({\', \'.join(self._expr(a) for a in e.args)})"\n\n    def _ex_MethodCall(self, e: A.MethodCall, *_):\n        return (f"{self._prefix(e.obj)}:{e.method}"\n                f"({\', \'.join(self._expr(a) for a in e.args)})")\n\n    def _ex_Paren(self, e: A.Paren, *_):\n        return f"({self._expr(e.inner)})"\n\n    def _ex_Function(self, e: A.Function, *_):\n        params = self._params(e)\n        sub = Unparser(self.indent)\n        sub.level = self.level + 1\n        sub._block(e.body)\n        body = "\\n".join(sub.out)\n        pad = self.indent * self.level\n        if body:\n            return f"function({params})\\n{body}\\n{pad}end"\n        return f"function({params}) end"\n\n    def _ex_Table(self, e: A.Table, *_):\n        if not e.fields:\n            return "{}"\n        parts = []\n        self.level += 1\n        for kind, key, val in e.fields:\n            if kind == "pos":\n                parts.append(self._expr(val))\n            elif kind == "name":\n                parts.append(f"{key} = {self._expr(val)}")\n            else:\n                if isinstance(key, A.String) and _is_ident(key.value):\n                    parts.append(f"{key.value} = {self._expr(val)}")\n                else:\n                    parts.append(f"[{self._expr(key)}] = {self._expr(val)}")\n        self.level -= 1\n        inline = "{" + ", ".join(parts) + "}"\n        if len(inline) <= 78 and "\\n" not in inline:\n            return inline\n        pad = self.indent * (self.level + 1)\n        end = self.indent * self.level\n        return "{\\n" + ",\\n".join(pad + p for p in parts) + "\\n" + end + "}"\n\n    def _ex_UnOp(self, e: A.UnOp, parent_prec=0, right=False):\n        inner = self._expr(e.operand, _UNARY_PREC, right=True)\n        if e.op == "not":\n            op = "not "\n        elif e.op == "-" and inner[:1] == "-":\n            op = "- "          # avoid forming a `--` comment\n        else:\n            op = e.op\n        text = f"{op}{inner}"\n        if _UNARY_PREC < parent_prec:\n            return f"({text})"\n        return text\n\n    def _ex_BinOp(self, e: A.BinOp, parent_prec=0, right=False):\n        prec = _BIN_PREC[e.op]\n        la = prec + (1 if e.op in _RIGHT_ASSOC else 0)\n        ra = prec + (0 if e.op in _RIGHT_ASSOC else 1)\n        lhs = self._expr(e.left, la)\n        rhs = self._expr(e.right, ra)\n        text = f"{lhs} {e.op} {rhs}"\n        need = prec < parent_prec or (prec == parent_prec and right)\n        return f"({text})" if need else text\n\n    def _prefix(self, e: A.Node) -> str:\n        """Render something in prefix-expression position, adding parens when\n        the grammar requires them (literals, operators, function bodies)."""\n        if isinstance(e, (A.Name, A.Index, A.Call, A.MethodCall, A.Paren)):\n            return self._expr(e)\n        return f"({self._expr(e)})"\n\n\ndef unparse(chunk: A.Chunk, indent: str = "  ") -> str:\n    return Unparser(indent).emit(chunk)\n', False), '_lelsploit_ast.vm': ('"""Shared analysis of the Prometheus ``Vmify`` container.\n\nThis module locates the VM container function, flattens its balanced\n``if pos < K`` search tree into an ordered block list, and builds a basic-block\ncontrol-flow graph.  Both :mod:`unprom.passes.devirtualize` (de-flatten only)\nand :mod:`unprom.passes.vm_lift` (full lift) build on it.\n"""\n\nfrom __future__ import annotations\n\nfrom dataclasses import dataclass, field\nfrom typing import Dict, List, Optional, Tuple\n\nfrom . import ast_nodes as A\nfrom .astutil import as_int, unparen\n\n\n# ======================================================================\n# Container discovery\n# ======================================================================\n@dataclass\nclass Container:\n    outer_fn: Optional[A.Function]      # (env, unpack, newproxy, setmeta, getmeta, select, arg, ...)\n    container_fn: A.Function            # C(pos, args, upvals, gc)\n    while_stmt: A.While\n    pos_name: str\n    args_name: str\n    upvals_name: str\n    gc_name: str\n    ret_name: Optional[str]\n    env_name: Optional[str]\n    unpack_name: Optional[str]\n    select_name: Optional[str]\n    reg_names: List[str] = field(default_factory=list)\n    factory_names: set = field(default_factory=set)      # createClosure* var names\n    container_name: Optional[str] = None\n    alloc_upval_name: Optional[str] = None\n    upvals_table_name: Optional[str] = None\n    free_upval_name: Optional[str] = None\n    free_upval_names: set = field(default_factory=set)\n    start_id: Optional[int] = None\n\n\ndef find_container(chunk: A.Chunk) -> Optional[Container]:\n    cand = _find_container_fn(chunk)\n    if cand is None:\n        return None\n    fn, wh = cand\n    params = [p.name for p in fn.params]\n    pos_name = wh.cond.name\n    c = Container(\n        outer_fn=None, container_fn=fn, while_stmt=wh, pos_name=pos_name,\n        args_name=params[1] if len(params) > 1 else "args",\n        upvals_name=params[2] if len(params) > 2 else "upvals",\n        gc_name=params[3] if len(params) > 3 else "gc",\n        ret_name=None, env_name=None, unpack_name=None, select_name=None,\n    )\n    _fill_return(c)\n    _fill_registers(c)\n    _fill_outer(chunk, c)\n    return c\n\n\ndef _find_container_fn(chunk: A.Chunk) -> Optional[Tuple[A.Function, A.While]]:\n    best = None\n    for n in A.walk(chunk):\n        if not isinstance(n, A.Function) or n.body is None:\n            continue\n        for st in n.body.stmts:\n            if not isinstance(st, A.While) or not isinstance(st.cond, A.Name):\n                continue\n            leaves = _count_leaves(st.body, st.cond.name)\n            if leaves is None or leaves < 3:\n                continue\n            if best is None or leaves > best[2]:\n                best = (n, st, leaves)\n    return (best[0], best[1]) if best else None\n\n\ndef _fill_return(c: Container):\n    body = c.container_fn.body.stmts\n    for st in body:\n        if isinstance(st, A.Return) and len(st.values) == 1:\n            call = unparen(st.values[0])\n            if isinstance(call, A.Call) and len(call.args) == 1 \\\n                    and isinstance(unparen(call.args[0]), A.Name):\n                c.unpack_name = unparen(call.func).name if isinstance(\n                    unparen(call.func), A.Name) else None\n                c.ret_name = unparen(call.args[0]).name\n                return\n\n\ndef _fill_registers(c: Container):\n    for st in c.container_fn.body.stmts:\n        if isinstance(st, A.LocalAssign) and not st.values and len(st.targets) >= 1:\n            names = [t.name for t in st.targets]\n            if c.ret_name in names or len(names) > 3:\n                c.reg_names = names\n                return\n    # fallback: first empty local decl\n    for st in c.container_fn.body.stmts:\n        if isinstance(st, A.LocalAssign) and not st.values:\n            c.reg_names = [t.name for t in st.targets]\n            return\n\n\ndef _fill_outer(chunk: A.Chunk, c: Container):\n    """Top-level `return (function(env, unpack, newproxy, setmetatable,\n    getmetatable, select, arg, ...) ... end)(...)`."""\n    for st in chunk.body.stmts:\n        if not isinstance(st, A.Return) or len(st.values) != 1:\n            continue\n        call = unparen(st.values[0])\n        if not isinstance(call, A.Call):\n            continue\n        fn = unparen(call.func)\n        if not isinstance(fn, A.Function) or len(fn.params) < 6:\n            continue\n        c.outer_fn = fn\n        names = [p.name for p in fn.params]\n        c.env_name = names[0]\n        c.unpack_name = c.unpack_name or names[1]\n        c.select_name = names[5]\n        _fill_factories_and_helpers(fn, c)\n        _fill_start_id(fn, c)\n        return\n\n\ndef _fill_factories_and_helpers(outer: A.Function, c: Container):\n    """The outer body assigns a batch of locals; classify the interesting ones."""\n    pairs = []\n    for st in A.walk(outer):\n        if isinstance(st, A.Assign):\n            for tgt, val in zip(st.targets, st.values):\n                name = unparen(tgt).name if isinstance(unparen(tgt), A.Name) else None\n                if name is not None:\n                    pairs.append((name, unparen(val)))\n\n    for name, val in pairs:\n        if not isinstance(val, A.Function):\n            continue\n        if val is c.container_fn or _is_container_literal(val, c):\n            c.container_name = name\n        elif _is_factory(val):\n            c.factory_names.add(name)\n        elif _is_alloc_upval(val):\n            c.alloc_upval_name = name\n        elif _is_free_upval(val):\n            c.free_upval_name = name\n            c.free_upval_names.add(name)\n    _guess_upvals_table(outer, c)\n\n\ndef _is_factory(fn: A.Function) -> bool:\n    """`function(pos, ups) local g = p(ups); local E = function(...) return\n    C(pos, {...}, ups, g) end; return E end` and its variants."""\n    if len(fn.params) != 2:\n        return False\n    for st in A.walk(fn):\n        if isinstance(st, A.Return) and len(st.values) == 1:\n            v = unparen(st.values[0])\n            if isinstance(v, A.Call) and len(v.args) >= 2 \\\n                    and isinstance(unparen(v.args[1]), A.Table):\n                return True\n    return False\n\n\ndef _is_container_literal(fn: A.Function, c: Container) -> bool:\n    return [p.name for p in fn.params][:1] == [c.pos_name] and any(\n        isinstance(s, A.While) for s in fn.body.stmts)\n\n\ndef _is_alloc_upval(fn: A.Function) -> bool:\n    """`function() X = X + 1; V[X] = 1; return X end`."""\n    if fn.params:\n        return False\n    inc = ret = None\n    for st in A.walk(fn):\n        if isinstance(st, A.Assign) and len(st.targets) == 1 \\\n                and isinstance(unparen(st.targets[0]), A.Name):\n            x = unparen(st.targets[0]).name\n            v = unparen(st.values[0]) if st.values else None\n            if isinstance(v, A.BinOp) and v.op == "+" and (\n                    _is_named(v.left, x) or _is_named(v.right, x)):\n                inc = x\n        if isinstance(st, A.Return) and len(st.values) == 1 \\\n                and isinstance(unparen(st.values[0]), A.Name):\n            ret = unparen(st.values[0]).name\n    return inc is not None and inc == ret\n\n\ndef _is_free_upval(fn: A.Function) -> bool:\n    """`function(o) V[o] = V[o] - 1; if 0 == V[o] then V[o], t[o] = nil, nil end end`\n    (or the list variant)."""\n    if len(fn.params) != 1:\n        return False\n    has_dec = any(isinstance(n, A.BinOp) and n.op == "-" for n in A.walk(fn))\n    has_nilnil = any(\n        isinstance(n, A.Assign) and len(n.values) >= 2\n        and all(isinstance(unparen(v), A.Nil) for v in n.values)\n        for n in A.walk(fn))\n    return has_dec and has_nilnil\n\n\ndef _is_named(node, name) -> bool:\n    node = unparen(node)\n    return isinstance(node, A.Name) and node.name == name\n\n\ndef _stmt_names(node) -> List[str]:\n    return [n.name for n in A.walk(node) if isinstance(n, A.Name)]\n\n\ndef _guess_upvals_table(outer: A.Function, c: Container):\n    # look inside container blocks for  X[<expr>]  where X is a free outer local\n    counts: Dict[str, int] = {}\n    for n in A.walk(c.container_fn):\n        if isinstance(n, A.Index) and isinstance(unparen(n.obj), A.Name):\n            nm = unparen(n.obj).name\n            if nm not in c.reg_names and nm not in (\n                    c.pos_name, c.args_name, c.upvals_name, c.gc_name, c.ret_name,\n                    c.env_name):\n                counts[nm] = counts.get(nm, 0) + 1\n    if counts:\n        c.upvals_table_name = max(counts, key=counts.get)\n\n\ndef _fill_start_id(outer: A.Function, c: Container):\n    for n in A.walk(outer):\n        if isinstance(n, A.Call):\n            inner = unparen(n.func)\n            if isinstance(inner, A.Call) and len(inner.args) == 2:\n                a0 = as_int(inner.args[0])\n                if a0 is not None and isinstance(unparen(inner.args[1]), A.Table):\n                    c.start_id = a0\n                    return\n\n\n# ======================================================================\n# Block flattening\n# ======================================================================\ndef split_if(block: A.Block, pos: str):\n    if len(block.stmts) != 1:\n        return None\n    st = block.stmts[0]\n    if not (isinstance(st, A.If) and len(st.clauses) == 1 and st.orelse is not None):\n        return None\n    cond = st.clauses[0][0]\n    if not (isinstance(cond, A.BinOp) and cond.op == "<"):\n        return None\n    left = unparen(cond.left)\n    if not (isinstance(left, A.Name) and left.name == pos):\n        return None\n    bound = as_int(cond.right)\n    if bound is None:\n        return None\n    return bound, st.clauses[0][1], st.orelse\n\n\ndef _count_leaves(block: A.Block, pos: str):\n    sp = split_if(block, pos)\n    if sp is None:\n        return 1\n    _b, l, r = sp\n    ln = _count_leaves(l, pos)\n    rn = _count_leaves(r, pos)\n    if ln is None or rn is None:\n        return None\n    return ln + rn\n\n\ndef flatten_blocks(wh: A.While) -> Tuple[List[List[A.Node]], List[int]]:\n    leaves: List[List[A.Node]] = []\n    seps: List[int] = []\n\n    def rec(block: A.Block):\n        sp = split_if(block, wh.cond.name)\n        if sp is None:\n            leaves.append(list(block.stmts))\n            return\n        bound, l, r = sp\n        rec(l)\n        seps.append(bound)\n        rec(r)\n\n    rec(wh.body)\n    return leaves, seps\n\n\ndef id_to_index(idv: int, seps: List[int]) -> int:\n    lo = 0\n    for i, s in enumerate(seps):\n        if idv < s:\n            return i\n        lo = i + 1\n    return lo\n', False)}

# Bounded layer probing. The decoders below operate on bytes only.
from collections import deque as _deque

_LAYER_LIMIT = 8_000_000

def _literal_data(token):
    if token.kind!='string': return None
    m=_LONG_RX.match(token.value)
    if m:
        body=token.value[m.end():-(len(m.group(1))+2)]
        if body.startswith(('\r\n','\n\r')): body=body[2:]
        elif body.startswith(('\n','\r')): body=body[1:]
        return body.replace('\r\n','\n').replace('\r','\n').encode('utf-8')
    try:
        _,parser,_=_load_ast_modules()
        toks=parser.tokenize(token.value)
        return toks[0].value.encode('latin1') if toks[0].type=='STRING' else None
    except (ValueError,SyntaxError,UnicodeError): return None

def _lph85_decode(data,limit=_LAYER_LIMIT):
    """Inverse of the Lua 5-digit/4-byte little-endian LPH stream encoder.

    Mirrors the sample's own base-85 polynomial and uint32 buffer writes.
    A partial final group is ignored, as in the wrapper's numeric for loop.
    """
    if not data.startswith(b'LPH') or len(data)<9: raise ValueError('not an LPH stream')
    payload=data[4:]
    expanded=len(payload)+4*payload.count(b'z')
    if expanded//5*4>limit: raise DeobfuscationLimitError('LPH output limit exceeded')
    payload=payload.replace(b'z',b'!!!!!')
    if any(not 33<=c<=117 for c in payload): raise ValueError('invalid LPH alphabet')
    out=bytearray(expanded//5*4);position=0
    for off in range(0,len(payload)-4,5):
        a,b,c,d,e=payload[off:off+5]
        value=((((a-33)*85+b-33)*85+c-33)*85+d-33)*85+e-33
        struct.pack_into('<I',out,position,value&0xffffffff);position+=4
    return bytes(out)

def _bounded_decompress(data,kind,limit=_LAYER_LIMIT):
    if kind in ('zlib','gzip','deflate'):
        obj=zlib.decompressobj({'zlib':15,'gzip':31,'deflate':-15}[kind])
        out=obj.decompress(data,limit+1)
        if len(out)>limit or obj.unconsumed_tail: raise DeobfuscationLimitError('decompression output limit exceeded')
        if not obj.eof or len(obj.unused_data)>3: raise ValueError('incomplete or trailing compressed stream')
        return out
    if kind=='bz2': obj=bz2.BZ2Decompressor()
    elif kind=='lzma': obj=lzma.LZMADecompressor(memlimit=64*1024*1024)
    elif kind=='lzma-raw':
        obj=lzma.LZMADecompressor(format=lzma.FORMAT_RAW,filters=[{'id':lzma.FILTER_LZMA1,'dict_size':16*1024*1024,'lc':3,'lp':0,'pb':0}])
    else: raise ValueError('unknown decompressor')
    out=obj.decompress(data,max_length=limit+1)
    if len(out)>limit: raise DeobfuscationLimitError('decompression output limit exceeded')
    if not obj.eof or len(obj.unused_data)>3: raise ValueError('incomplete or trailing compressed stream')
    return out

def _source_candidate(raw):
    if not 5<=len(raw)<=2_000_000 or b'\x00' in raw: return None
    # Reject binary buffers before attempting a grammar parse.
    sample=raw[:8192]
    if sum(c<32 and c not in (9,10,13) for c in sample): return None
    try: source=raw.decode('utf-8')
    except UnicodeError:return None
    if not re.search(r'\b(?:return|local|function|if|for|while|repeat|print|game|workspace)\b',source): return None
    try:
        _,parser,_=_load_ast_modules();parser.parse(source)
    except (ValueError,SyntaxError,RecursionError): return None
    return source

def _moonveil_lzss(data,limit=_LAYER_LIMIT):
    """Control-byte LZSS (11-bit history, 5-bit length, minimum length 3).

    Adapted from binxgtl/luau-vmp-deobf (MIT); permission notice is embedded
    in this file's _LUAUVMP_LICENSE constant by the release assembler.
    """
    history=b'';out=bytearray();pos=0
    def sub(buf,i,j):
        n=len(buf)
        if i<0:i=max(n+i+1,1)
        elif i==0:i=1
        if j<0:j=n+j+1
        else:j=min(j,n)
        return b'' if i>j else buf[i-1:j]
    while pos<len(data):
        control=data[pos];pos+=1
        for _ in range(8):
            piece=None
            if control&1:
                if pos<len(data):piece=data[pos:pos+1];pos+=1
            elif pos+1<len(data):
                word=(data[pos]<<8)|data[pos+1];pos+=2
                start=len(history)-(word>>5);length=(word&31)+3
                piece=sub(history,start,start+length-1)
            control>>=1
            if piece is not None:
                if len(out)+len(piece)>limit:raise DeobfuscationLimitError('LZSS output limit exceeded')
                out.extend(piece);history=(history+piece)[-2048:]
    return bytes(out)

def _payload_operations(data,deep=False):
    """Yield plausible byte decoders; cheap shape checks precede every decode."""
    n=len(data)
    if n>_LAYER_LIMIT:return
    if data.startswith(b'LPH'):
        yield 'LPH/base85-le',lambda:_lph85_decode(data)
        return
    if n>=8 and n%2==0 and re.fullmatch(rb'[0-9a-fA-F]+',data):
        yield 'hex',lambda:bytes.fromhex(data.decode('ascii'))
    if n>=8 and re.fullmatch(rb'[A-Za-z0-9+/_=\-\r\n]+',data):
        packed=re.sub(rb'\s+',b'',data)
        if len(packed)%4!=1:
            yield 'base64',lambda:base64.b64decode(packed+b'='*((-len(packed))%4),altchars=b'-_',validate=True)
    if deep and 12<=n<=4096 and re.fullmatch(rb'[1-9A-HJ-NP-Za-km-z]+',data):
        yield 'base58',lambda:_decode_base58(data.decode('ascii'))
    if deep and 12<=n<=65536 and all(33<=c<=126 for c in data):
        yield 'base91',lambda:_decode_base91(data.decode('ascii'))
    if n>=8 and re.fullmatch(rb'[A-Z2-7=\r\n]+',data):
        yield 'base32',lambda:base64.b32decode(re.sub(rb'\s+',b'',data)+b'='*((-len(re.sub(rb'\s+',b'',data)))%8))
    if data.startswith(b'<~') and data.endswith(b'~>'):
        yield 'ascii85',lambda:base64.a85decode(data,adobe=True)
    if deep and 10<=n<=262144 and n%5==0 and all(33<=c<=117 or c==122 for c in data):
        yield 'ascii85',lambda:base64.a85decode(data)
        yield 'base85',lambda:base64.b85decode(data)
    if b'%' in data and re.search(rb'%[a-fA-F0-9]{2}',data):
        yield 'url-percent',lambda:unquote_to_bytes(data.decode('ascii'))
    if data.startswith(b'\x1f\x8b'):yield 'gzip',lambda:_bounded_decompress(data,'gzip')
    if n>2 and data[0]&15==8 and (data[0]*256+data[1])%31==0:yield 'zlib',lambda:_bounded_decompress(data,'zlib')
    if data.startswith(b'BZh'):yield 'bz2',lambda:_bounded_decompress(data,'bz2')
    if data.startswith((b'\xfd7zXZ',b'\x5d\x00')):yield 'lzma',lambda:_bounded_decompress(data,'lzma')
    if deep and 8<=n<=262144:
        yield 'raw-deflate',lambda:_bounded_decompress(data,'deflate')
        yield 'MoonVeil/LZSS-11-5',lambda:_moonveil_lzss(data)
        # Raw LZMA has no magic; only attempt it on range-coded-looking data.
        if data[0]==0:yield 'raw-lzma',lambda:_bounded_decompress(data,'lzma-raw')
        yield 'reverse',lambda:data[::-1]
        if all(c<128 for c in data):
            yield 'rot13',lambda:codecs.decode(data.decode('ascii'),'rot13').encode('ascii')


def recover_payload_layers(source_or_path, *, max_attempts=1024,max_depth=5,
                           time_budget=10.0,deep=False,scan_xor=False):
    """Return statically decoded layers and candidate source without executing it.

    `data` contains bytes. A `source` field is a syntactically checked candidate,
    not proof of a VM's application. The shared budget includes rejected probes.
    Large inputs never receive exhaustive XOR/shift sweeps.
    """
    if not isinstance(max_attempts,int) or not 1<=max_attempts<=16384: raise ValueError('max_attempts must be in 1..16384')
    if not 1<=max_depth<=12:raise ValueError('max_depth must be in 1..12')
    if not math.isfinite(time_budget) or time_budget<=0:raise ValueError('invalid time budget')
    source,_=_read_input(source_or_path)
    if len(source.encode('utf-8'))>8_000_000:raise DeobfuscationLimitError('input limit exceeded')
    tokens=_scan_source(source)
    literals=[]
    for token in tokens:
        if token.kind!='string' or len(token.value)<10:continue
        data=_literal_data(token)
        if data and len(data)>=8:literals.append((token,data))
    literals.sort(key=lambda pair:(not pair[1].startswith(b'LPH'),-len(pair[1])))
    queue=_deque((token.start,data,(),0) for token,data in literals[:64])
    seen=set();layers=[];attempts=0;total=0;deadline=_time.monotonic()+time_budget
    def accept(offset,out,chain,depth):
        nonlocal total
        if not out or len(out)>_LAYER_LIMIT:return
        digest=hashlib.sha256(out).hexdigest()
        key=(offset,digest)
        if key in seen:return
        seen.add(key);total+=len(out)
        if total>32_000_000:return
        candidate=_source_candidate(out)
        item={'literal_offset':offset,'chain':list(chain),'decoded_bytes':len(out),'sha256':digest,'data':out,'source':candidate}
        # Keep binary format layers, and checked source candidates. Arbitrary
        # XOR noise is not useful to return as an alleged recovered layer.
        if candidate or any(name not in ('reverse','rot13') and not name.startswith(('xor:','shift:')) for name in chain):layers.append(item)
        if candidate is None and depth<max_depth:queue.append((offset,out,chain,depth))
    while queue and attempts<max_attempts and _time.monotonic()<deadline:
        offset,data,chain,depth=queue.popleft()
        if depth>=max_depth:continue
        for name,decode in _payload_operations(data,deep):
            if attempts>=max_attempts or _time.monotonic()>=deadline:break
            attempts+=1
            try:out=decode()
            except (ValueError,ArithmeticError,UnicodeError,OSError,EOFError,lzma.LZMAError,zlib.error):continue
            if not isinstance(out,(bytes,bytearray)):continue
            if len(out)<=_LAYER_LIMIT:accept(offset,out,chain+(name,),depth+1)
        if scan_xor and depth<=1 and 8<=len(data)<=65536:
            # Check the first bytes before allocating a full transformed buffer.
            # This explores every byte key while rejecting non-source headers.
            for operation in ('xor','shift'):
                for key in range(1,256):
                    if attempts>=max_attempts or _time.monotonic()>=deadline:break
                    attempts+=1
                    head=bytes((b^key) if operation=='xor' else (b-key)&255 for b in data[:128])
                    if not re.search(rb'\b(?:local|return|function|print|game|if)\b',head):continue
                    out=bytes((b^key) if operation=='xor' else (b-key)&255 for b in data)
                    accept(offset,out,chain+(operation+':'+str(key),),depth+1)
    stats={'attempts':attempts,'budget':max_attempts,'depth':max_depth,'decoded_layers':len(layers),'source_candidates':sum(bool(x['source']) for x in layers),'budget_exhausted':bool(queue) and attempts>=max_attempts,'time_exhausted':_time.monotonic()>=deadline}
    return layers,stats


def _format_features(source,tokens=None):
    tokens=_scan_source(source) if tokens is None else tokens
    names=[t.value for t in tokens if t.kind=='name'];counts=Counter(names)
    code_tokens=[t for t in tokens if t.kind not in ('comment','string','interpolation')]
    compact=' '.join(t.value for t in code_tokens)
    literals=[]
    for t in tokens:
        if t.kind=='string':
            m=_LONG_RX.match(t.value)
            if m:
                body=t.value[m.end():-(len(m.group(1))+2)].lstrip('\r\n')
                if body.startswith('LPH'):literals.append(t)
    return {'tokens':tokens,'names':counts,'compact':compact,'lph':literals}


def _format_detections(source,features=None):
    f=_format_features(source) if features is None else features
    counts=f['names'];compact=f['compact'];low=source.lower();out=[]
    def add(family,score,reason):out.append(Detection(family,score,[reason]))
    if f['lph']:
        add('Luraph LPH inline VM' if len(f['lph'])==1 else 'Luraph LPH staged loader',95,'LPH long-string payload with source-level VM structure' if counts['while']+counts['repeat'] else 'LPH encoded long-string payload')
    if counts['_bsdata0'] and 'luarmor.net/' in low:
        add('Luarmor V4 bootstrap',100,'_bsdata0 plus Luarmor init/cache loader')
    elif 'luarmor.net/files/v4/loaders/' in low:add('Luarmor V4 public loader',98,'Luarmor public loader endpoint')
    if counts['_bsdata0'] and counts['readfile'] and counts['loadstring'] and counts['writefile']:
        add('Luarmor cache bootstrap',90,'bootstrap table with local cache read/load/write flow')
    if counts['LPH_ENCSTR'] or counts['LPH_JIT'] or counts['LPH_NO_VIRTUALIZE']:add('Luraph macro family',85,'LPH macro references')
    if '35184372088832' in source and '257' in source and counts['setmetatable']:
        add('Prometheus encrypted strings',92,'paired PRNG moduli and cache metatable')
    if counts['while'] and counts['function'] and counts['getfenv'] and counts['unpack'] and counts['newproxy']:
        add('Prometheus/VM dispatcher candidate',55,'environment/upvalue/dispatcher structure')
    if counts['bit32'] and counts['string'] and (counts['bxor'] or counts['xor']):add('XOR string/VM helpers',45,'string operations and bitwise XOR')
    if counts['buffer'] and counts['while'] and counts['function']:add('Luau buffer-backed VM',55,'buffer operations with function/loop interpreter scaffolding')
    if counts['tonumber'] and re.search(r', 36 \)',compact) and counts['char'] and counts['sub']:add('AztupBrew/base36 LZW candidate',65,'base36 decoding with string byte helpers')
    if counts['gsub'] and counts['rep'] and counts['tonumber'] and re.search(r', 16 \)',compact):add('IronBrew hex/RLE candidate',65,'hex conversion with run-length decoder primitives')
    if counts['loadstring']:add('Luau loadstring layer',35,'source-loading call present')
    banners={'MoonSec':('moonsec',),'Prometheus':('prometheus','wearedevs'),'IronBrew':('ironbrew',),'AztupBrew':('aztupbrew',),'Hercules':('hercules',),'Clyde':('clyde',),'MoonVeil':('moonveil',),'LuaObfuscator.com':('luaobfuscator.com',),'Synapse Xen':('synapse xen',)}
    for family,keys in banners.items():
        if any(key in low for key in keys):add(family,8,'family marker; structural confirmation required')
    out.sort(key=lambda d:(-d.score,d.family))
    return out or [Detection('generic/unknown',0,['generic static Luau recovery is available without a family banner'])]


def extract_embedded_payloads(source_or_path, *, max_attempts=1024, deep=False):
    """Return decoded byte/source layers; never replace source with an inventory."""
    layers,_=recover_payload_layers(source_or_path,max_attempts=max_attempts,deep=deep,scan_xor=deep)
    return [{'family':' / '.join(item['chain']),
             'kind':'decoded-source' if item['source'] else 'decoded-binary',
             'data':item['source'] if item['source'] else item['data']}
            for item in layers]

# Source recovery engine (LelSploit 3).
# Reviewed vendored modules are embedded below; input scripts are never exec'd.
import time as _time
import importlib.abc as _import_abc
import importlib.util as _import_util
import types as _types

class DeobfuscationLimitError(ValueError):
    """The supplied source exceeds a configured processing budget."""

class _ASTModules(_import_abc.MetaPathFinder, _import_abc.Loader):
    def __init__(self, sources):
        self.sources = sources
    def find_spec(self, fullname, path=None, target=None):
        if fullname not in self.sources: return None
        source, package = self.sources[fullname]
        return _import_util.spec_from_loader(fullname, self, is_package=package)
    def create_module(self, spec): return None
    def exec_module(self, module):
        source, package = self.sources[module.__name__]
        module.__file__ = '<lelsploit-vendored>/' + module.__name__.replace('.', '/') + '.py'
        # Only bundled, reviewed Python source reaches compile/exec. Luau input
        # is exclusively handled by tokenizers, AST passes and the evaluator.
        exec(compile(source, module.__file__, 'exec'), module.__dict__)

def _load_ast_modules():
    if '_lelsploit_ast' not in sys.modules:
        sys.meta_path.insert(0, _ASTModules(_AST_SOURCES))
    import _lelsploit_ast.ast_nodes as A
    import _lelsploit_ast.parser as parser
    import _lelsploit_ast.unparser as printer
    return A, parser, printer

@dataclass(frozen=True)
class _SourceToken:
    kind: str
    value: str
    start: int
    end: int

_NUMBER_RX = re.compile(r'(?:0[xX][\da-fA-F_]+(?:\.[\da-fA-F_]*)?(?:[pP][+-]?[\d_]+)?|0[bB][01_]+|(?:\d[\d_]*(?:\.(?!\.)[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?[\d_]+)?)')
_NAME_RX = re.compile(r'[A-Za-z_][A-Za-z_0-9]*')
_LONG_RX = re.compile(r'\[(=*)\[')
_OPS_RX = re.compile(r'\.\.\.|\.\.=|//=|\+=|-=|\*=|/=|%=|\^=|==|~=|<=|>=|::|->|\.\.|//|[\s\S]')

def _scan_source(source: str, max_tokens: int=1_000_000):
    """Lossless O(n) scanner; interpolation is deliberately one opaque token."""
    out = []; i = 0; n = len(source); nesting_depth=0
    def quoted(pos, quote):
        j = pos + 1
        while j < n:
            if source[j] == '\\': j += 2; continue
            if source[j] == quote: return j + 1
            j += 1
        raise ValueError('unterminated quoted string')
    def interpolation(pos, nesting=0):
        if nesting>64: raise DeobfuscationLimitError("interpolation nesting limit exceeded")
        # Nested interpolations may contain quoted strings, comments and braces.
        j = pos + 1; depth = 0
        while j < n:
            c = source[j]
            if c == '\\': j += 2; continue
            if c == '`':
                if depth == 0: return j + 1
                j = interpolation(j,nesting+1); continue
            if depth and c in '\"\'': j = quoted(j, c); continue
            if depth and (c == '[' or source.startswith('--', j)):
                offset = 2 if source.startswith('--', j) else 0
                m = _LONG_RX.match(source, j+offset)
                if m:
                    closer = ']' + m.group(1) + ']'; end = source.find(closer,m.end())
                    if end < 0: raise ValueError('unterminated long string')
                    j = end+len(closer); continue
                if offset:
                    end=source.find('\n',j+2); j=n if end<0 else end; continue
            if c == '{': depth += 1
            elif c == '}' and depth: depth -= 1
            j += 1
        raise ValueError('unterminated interpolated string')
    while i < n:
        c = source[i]
        if c.isspace(): i += 1; continue
        start = i
        if source.startswith('--', i):
            m = _LONG_RX.match(source, i+2)
            if m:
                close = ']' + m.group(1) + ']'; end = source.find(close, m.end())
                if end < 0: raise ValueError('unterminated long comment')
                i = end + len(close)
            else:
                end = source.find('\n',i+2); i = n if end < 0 else end
            kind='comment'
        elif c in '\"\'': i=quoted(i,c); kind='string'
        elif c == '`': i=interpolation(i); kind='interpolation'
        elif c == '[' and (m := _LONG_RX.match(source,i)):
            close=']'+m.group(1)+']'; end=source.find(close,m.end())
            if end<0: raise ValueError('unterminated long string')
            i=end+len(close); kind='string'
        elif (m := _NUMBER_RX.match(source,i)):
            i=m.end(); kind='number'
        elif (m := _NAME_RX.match(source,i)):
            i=m.end(); kind='name'
        else: i=_OPS_RX.match(source,i).end(); kind='op'
        if kind=='op':
            if c in '([{': nesting_depth+=1
            elif c in ')]}': nesting_depth=max(0,nesting_depth-1)
            if nesting_depth>256: raise DeobfuscationLimitError('delimiter nesting limit exceeded')
        out.append(_SourceToken(kind,source[start:i],start,i))
        if len(out)>max_tokens: raise DeobfuscationLimitError('token limit exceeded')
    return out

def _apply_edits(source, edits):
    out=[]; pos=0
    for a,b,value in sorted(edits):
        if a<pos: continue
        out.extend((source[pos:a],value)); pos=b
    out.append(source[pos:]); return ''.join(out)

def _strip_source_comments(source):
    return _apply_edits(source, [(t.start,t.end,'\n' * t.value.count('\n') if '\n' in t.value else ' ') for t in _scan_source(source) if t.kind=='comment'])

def _fallback_format(source, indent=4):
    # Change whitespace only. Preserve every token (including modern type and
    # interpolation syntax), so unsupported grammar cannot be silently erased.
    ts = [t for t in _scan_source(source) if t.kind!='comment']
    if not ts: return ''
    lines=[]; line=''; level=0; parens=0; brackets=0
    def flush():
        nonlocal line
        if line.strip(): lines.append(' '*(indent*max(0,level)) + line.strip())
        line=''
    previous=None
    for t in ts:
        v=t.value
        gap=source[previous.end:t.start] if previous else ''
        if '\n' in gap and not parens and not brackets: flush()
        if t.kind=='name' and v in ('end','else','elseif','until') and not parens and not brackets:
            flush(); level=max(0,level-1)
        # Retain original adjacency except where removing a comment would join
        # names or produce a different operator (e.g. '- --comment\n -').
        if line and gap: line += ' '
        line += v
        if v=='(': parens+=1
        elif v==')': parens=max(0,parens-1)
        elif v in ('[','{'): brackets+=1
        elif v in (']','}'): brackets=max(0,brackets-1)
        if not parens and not brackets:
            if v==';': flush()
            elif t.kind=='name' and v in ('then','do','repeat','else'):
                flush(); level+=1
            elif t.kind=='name' and v=='end': flush()
        previous=t
    flush()
    return '\n'.join(lines).rstrip()+'\n'

def _fallback_constants(source, report, max_passes, deadline=None):
    A, parser, printer = _load_ast_modules()
    from _lelsploit_ast.recovery import Evaluator, Multi, primitive
    from _lelsploit_ast.evaluator import value_to_node
    for _ in range(min(max_passes,16)):
        if deadline is not None and _time.monotonic() >= deadline:
            report.warnings.append('Time budget reached during token recovery.')
            break
        ts=[t for t in _scan_source(source) if t.kind!='comment']
        blocked={ts[i+1].value for i,t in enumerate(ts[:-1]) if t.value in ('local','function') and ts[i+1].kind=='name'}
        # Any assignment to a library disables folding that library, including
        # redefinitions anywhere in a typed function or nested scope.
        for i,t in enumerate(ts):
            if t.value in ('getfenv','setfenv'): blocked.update(('string','math','bit32','table','utf8','tonumber','tostring'))
            if t.value=='=':
                j=i-1
                while j>=0 and ts[j].value not in (';','then','do','end','local','return') and '\n' not in source[ts[j].end:ts[j+1].start]:
                    if ts[j].kind=='name': blocked.add(ts[j].value)
                    j-=1
        literal_edits = []
        at = 0
        while at + 2 < len(ts):
            if ts[at].kind != 'string' or ts[at+1].value != '..' or ts[at+2].kind != 'string':
                at += 1; continue
            end = at + 2
            while end + 2 < len(ts) and ts[end+1].value == '..' and ts[end+2].kind == 'string':
                end += 2
            fragment = source[ts[at].start:ts[end].end]
            if len(fragment) <= 100_000:
                try:
                    p = parser.Parser(parser.tokenize(fragment)); node = p._expr(); p._expect('EOF')
                    value = Evaluator(steps=10_000).expr(node)
                    if isinstance(value, str):
                        literal_edits.append((ts[at].start, ts[end].end, printer.Unparser()._expr(value_to_node(value))))
                except Exception:
                    pass
            at = end + 1
        if literal_edits:
            source = _apply_edits(source, literal_edits)
            if 'literal string chains recovered' not in report.passes: report.passes.append('literal string chains recovered')
            ts = [t for t in _scan_source(source) if t.kind != 'comment']
        stack=[]; pairs={}
        for i,t in enumerate(ts):
            if t.value=='(': stack.append(i)
            elif t.value==')' and stack: pairs[stack.pop()]=i
        edits=[]
        for i,j in sorted(pairs.items()):
            if deadline is not None and _time.monotonic() >= deadline: break
            start=ts[i].start; end=ts[j].end
            prefix=i
            if i>=3 and ts[i-2].value=='.' and ts[i-3].value in ('string','math','bit32','table','utf8') and ts[i-3].value not in blocked:
                prefix=i-3
            elif i and ts[i-1].value in ('tonumber','tostring') and ts[i-1].value not in blocked:
                prefix=i-1
            if j-prefix>256: continue
            fragment=source[ts[prefix].start:end]
            if j+1<len(ts) and ts[j+1].value in ('(', '[', '.', ':', '=', '+=', '-='): continue
            if prefix<i:
                before=ts[prefix-1].value if prefix else None
                if before is None or before in (';', 'then', 'do', 'else', 'end'): continue
                if prefix and '\n' in source[ts[prefix-1].end:ts[prefix].start] and before not in ('=', 'return', ',', '('): continue
            if prefix==i and (i and ts[i-1].kind in ('name','string','interpolation') or i and ts[i-1].value in (')',']')):
                continue
            try:
                p=parser.Parser(parser.tokenize(fragment)); node=p._expr(); p._expect('EOF')
                v=Evaluator(disabled=blocked,steps=10_000).expr(node)
                if isinstance(v,Multi):
                    if len(v.values)!=1: continue
                    v=v.values[0]
                if not primitive(v) or isinstance(v,float) and not math.isfinite(v): continue
                rendered=printer.Unparser()._expr(value_to_node(v))
                if isinstance(v,float) and (v<0 or math.copysign(1,v)<0): rendered='('+rendered+')'
                if rendered!=fragment: edits.append((ts[prefix].start,end,rendered))
            except Exception: continue
        if not edits: break
        source=_apply_edits(source,edits)
        if 'token-aware constant recovery' not in report.passes: report.passes.append('token-aware constant recovery')
    return source

def _ast_recover(source, report, max_passes, devirt, indent, deadline):
    A, parser, printer = _load_ast_modules()
    from _lelsploit_ast.pipeline import PassContext
    from _lelsploit_ast import recovery, tidy, control_flow
    from _lelsploit_ast.passes import constant_fold, constant_array, encrypt_strings, vm_lift, devirtualize
    ctx=PassContext(options={'rename':'none','devirt':devirt,'indent':' '*indent})
    chunk=parser.parse(source)
    structure=(A.LocalAssign,A.LocalFunction,A.Assign,A.CompoundAssign,A.Function,A.FunctionDecl,
               A.If,A.While,A.Repeat,A.NumericFor,A.GenericFor,A.Do)
    simple=not any(isinstance(n,structure) for n in A.walk(chunk))
    ctx.options['simple']=simple
    ctx.options['dynamic_environment']=any(isinstance(n,A.Call) and isinstance(n.func,A.Name) and n.func.name in ('getfenv','setfenv') for n in A.walk(chunk))
    # Wrapping a tail call in parentheses constrains it to one return value;
    # only peel the exact vararg-forwarding form used by WrapInFunction.
    layers=0
    while len(chunk.body.stmts)==1 and isinstance(chunk.body.stmts[0],A.Return):
        ret=chunk.body.stmts[0]
        call=ret.values[0] if len(ret.values)==1 else None
        if not isinstance(call,A.Call): break
        fn=call.func.inner if isinstance(call.func,A.Paren) else call.func
        if not isinstance(fn,A.Function) or fn.params: break
        forwarded=len(call.args)==1 and isinstance(call.args[0],A.Vararg) and fn.is_vararg
        empty=not call.args and not any(isinstance(n,A.Vararg) for n in A.walk(fn.body))
        if not (forwarded or empty): break
        chunk.body=fn.body; layers+=1
    if layers: ctx.bump('wrap_layers_removed',layers)
    if not simple:
        backup=A.clone(chunk)
        try: chunk=constant_fold.run(chunk,ctx)
        except Exception: chunk=backup
    # Specialized transformations run transactionally; a failed pass cannot
    # leave a partially mutated tree behind.
    specialized=[('Prometheus encrypted strings',encrypt_strings.run),('Prometheus constant arrays',constant_array.run)]
    for name, fn in specialized:
        if _time.monotonic()>deadline:
            report.warnings.append('Time budget reached; returning the best source recovered so far.')
            break
        if name.startswith('Prometheus encrypted') and '35184372088832' not in source: continue
        if name.endswith('arrays') and not ('{' in source and 'function' in source): continue
        backup=A.clone(chunk)
        try: chunk=fn(chunk,ctx)
        except Exception as exc:
            chunk=backup; report.warnings.append(name+': '+str(exc))
    # VM lifting is an explicit best-effort engine. It only activates when the
    # Prometheus container structure matches, never from a banner/name alone.
    if devirt!='off' and 'while' in source and 'function' in source and _time.monotonic()<deadline:
        for name,fn in [('Prometheus VM lifting',vm_lift.run),('Prometheus dispatcher recovery',devirtualize.run)]:
            backup=A.clone(chunk)
            try: chunk=fn(chunk,ctx)
            except Exception as exc: chunk=backup; report.warnings.append(name+': '+str(exc))
    previous=None
    for _ in range(1 if simple else max_passes):
        if _time.monotonic()>deadline:
            report.warnings.append('Time budget reached; returning the best source recovered so far.')
            break
        before=sum(ctx.stats.values())
        chunk=recovery.run(chunk,ctx)
        chunk=constant_fold.run(chunk,ctx)
        if not simple:
            chunk=control_flow.run(chunk,ctx)
            chunk=tidy.run(chunk,ctx)
        # Count changes, rather than repeatedly stringify/parse the whole AST.
        current=printer.unparse(chunk,indent=' '*indent)
        if current==previous: break
        previous=current
        if sum(ctx.stats.values())==before: break
    text=printer.unparse(chunk,indent=' '*indent)
    parser.parse(text)  # verify emitted grammar before accepting the result
    totals=report.details.setdefault('ast_stats',{})
    for key,value in ctx.stats.items(): totals[key]=totals.get(key,0)+value
    report.details.setdefault('ast_notes',[]).extend(ctx.notes)
    report.passes.extend(k for k,v in ctx.stats.items() if v and k not in report.passes)
    # Inline whole-file constant loadstring invocations as parsed source.
    if len(chunk.body.stmts)==1:
        statement=chunk.body.stmts[0]
        outer=statement.call if isinstance(statement,A.CallStat) else statement.values[0] if isinstance(statement,A.Return) and len(statement.values)==1 else None
        if isinstance(outer,A.Call) and not outer.args and isinstance(outer.func,A.Call):
            loader=outer.func
            if isinstance(loader.func,A.Name) and loader.func.binding is None and loader.func.name=='loadstring' and len(loader.args)==1 and isinstance(loader.args[0],A.String):
                try:
                    decoded=loader.args[0].value.encode('latin1').decode('utf-8')
                    payload=parser.parse(decoded)
                    # The loaded chunk is called with zero arguments. Resolve
                    # only its own varargs; nested functions retain theirs.
                    class EmptyChunkArgs(A.NodeTransformer):
                        def visit_Function(self,node): return node
                        def visit_Vararg(self,node): return A.Nil()
                        def visit_Call(self,node):
                            node.func=self.visit(node.func)
                            node.args=[self.visit(a) for i,a in enumerate(node.args) if not (i==len(node.args)-1 and isinstance(a,A.Vararg))]
                            return node
                        def visit_Return(self,node):
                            node.values=[self.visit(a) for i,a in enumerate(node.values) if not (i==len(node.values)-1 and isinstance(a,A.Vararg))]
                            return node
                        def visit_MethodCall(self,node):
                            node.obj=self.visit(node.obj)
                            node.args=[self.visit(a) for i,a in enumerate(node.args) if not (i==len(node.args)-1 and isinstance(a,A.Vararg))]
                            return node
                        def visit_Table(self,node):
                            node.fields=[(k,self.visit(key) if isinstance(key,A.Node) else key,self.visit(v)) for i,(k,key,v) in enumerate(node.fields) if not (i==len(node.fields)-1 and k=='pos' and isinstance(v,A.Vararg))]
                            return node
                    payload=EmptyChunkArgs().visit(payload)
                    decoded=printer.unparse(payload,indent=' '*indent)
                    if isinstance(statement,A.CallStat) and any(isinstance(n,A.Return) for n in A.walk(payload)):
                        # Preserve discarded return values via a normal closure.
                        wrapper=A.Function(body=payload.body)
                        text=printer.unparse(A.Chunk(A.Block([A.CallStat(A.Call(A.Paren(wrapper),[]))])),indent=' '*indent)
                    else: text=decoded
                    report.passes.append('unwrap literal Luau loader')
                except (UnicodeError,ValueError,SyntaxError): pass
    return text

def detect_obfuscator(source):
    text_value,_=_read_input(source)
    return _format_detections(text_value)

def check_supported_obfuscated_format(source, *, min_score=3):
    text_value,_=_read_input(source)
    try: features=_format_features(text_value)
    except (ValueError,RecursionError) as exc:
        return {'supported':False,'recognized':False,'family':'invalid source','score':0,
                'support_status':'invalid-input','reasons':[str(exc)],'detections':[]}
    detections=_format_detections(text_value,features);best=detections[0]
    is_loader=any('Luarmor' in d.family for d in detections)
    is_vm=bool(features['lph']) or any('dispatcher' in d.family for d in detections)
    level='loader-and-generic' if is_loader else 'vm-layers-and-generic' if is_vm else 'source-transforms'
    return {'supported':True,'processable':True,'recognized':best.score>=min_score,
            'family':best.family,'score':best.score,'reasons':best.reasons,
            'support_status':level,'full_recovery_guaranteed':False,
            'missing_dependencies':['Remote init/application bytes are not embedded in this bootstrap'] if is_loader else [],
            'detections':[d.__dict__ for d in detections]}

def analyze(source_or_path, *, deep=False):
    source,_=_read_input(source_or_path);f=_format_features(source)
    layers,stats=recover_payload_layers(source,max_attempts=4096 if deep else 256,deep=deep,scan_xor=deep)
    result=check_supported_obfuscated_format(source)
    result.update({'size':len(source.encode('utf-8')),'lines':source.count('\n')+1,
                   'token_count':len(f['tokens']),'lph_streams':len(f['lph']),
                   'layer_search':stats,'payload_layers':[{k:v for k,v in x.items() if k not in ('data','source')} for x in layers]})
    if f['names']['_bsdata0']:
        result['luarmor_v4_bootstrap']=extract_luarmor_v4_bootstrap(source)
    return result

def _normalize_literal_tokens(source):
    edits=[];_,parser,printer=_load_ast_modules()
    for token in _scan_source(source):
        if token.kind=='number' and ('_' in token.value or token.value.lower().startswith(('0x','0b'))):
            try:
                value=parser._num(token.value)
                if math.isfinite(value):
                    from _lelsploit_ast.ast_nodes import Number
                    rendered=printer._fmt_number(Number(value=value))
                    if rendered!=token.value:edits.append((token.start,token.end,rendered))
            except (ValueError,ArithmeticError):pass
        elif token.kind=='string' and len(token.value)<=65536 and not _LONG_RX.match(token.value):
            if re.search(r'\\(?:[0-9]|x|u\{|z)',token.value):
                data=_literal_data(token)
                if data is not None:
                    rendered=printer._quote(data.decode('latin1'))
                    if rendered!=token.value:edits.append((token.start,token.end,rendered))
    return _apply_edits(source,edits),len(edits)


def deobfuscate(source_or_path, *, return_report=False, max_passes=6,
                moonsec_mode='source', devirt='lift', pretty=True, indent=4,
                max_input_bytes=8_000_000, max_tokens=1_000_000,
                time_budget=30.0, strict=False, effort="balanced", max_attempts=None, explore=False):
    """Recover Roblox Luau as raw source, with diagnostics returned separately.

    No input code is executed or downloaded. Unknown/protected regions are
    preserved. VM lifting is best-effort; `devirt='off'` disables it. `strict`
    rejects inputs when the AST grammar is unsupported. Resource limits bound
    input/tokens, constant values and interpreter steps; `time_budget` is checked
    between passes (it is not a hard preemptive process timeout).
    """
    if not isinstance(max_passes,int) or not 1<=max_passes<=32: raise ValueError('max_passes must be in 1..32')
    if devirt not in ('lift','deflatten','off'): raise ValueError('invalid devirt mode')
    if moonsec_mode not in ('source','disassembly','bytecode'): raise ValueError('invalid moonsec mode')
    if not isinstance(indent,int) or not 1<=indent<=8: raise ValueError('indent must be in 1..8')
    if not math.isfinite(time_budget) or time_budget<=0: raise ValueError('time_budget must be positive and finite')
    if max_input_bytes<=0 or max_tokens<=0: raise ValueError('limits must be positive')
    if effort not in ('fast','balanced','deep'): raise ValueError('invalid effort')
    if max_attempts is None: max_attempts={'fast':128,'balanced':1024,'deep':4096}[effort]
    if not isinstance(max_attempts,int) or not 1<=max_attempts<=16384:raise ValueError('max_attempts must be in 1..16384')
    start=_time.monotonic(); deadline=start+time_budget
    if isinstance(source_or_path,os.PathLike):
        p=Path(source_or_path)
        if p.stat().st_size>max_input_bytes: raise DeobfuscationLimitError('input byte limit exceeded')
    if isinstance(source_or_path,bytes) and source_or_path.startswith(b'\x1b'): raise ValueError('expected Luau source, not bytecode')
    input_path=None
    if isinstance(source_or_path,os.PathLike):
        input_path=Path(source_or_path);code=input_path.read_text(encoding='utf-8')
    elif isinstance(source_or_path,bytes): code=source_or_path.decode('utf-8')
    elif isinstance(source_or_path,str):
        code=source_or_path
        try:
            candidate=Path(source_or_path)
            if '\n' not in source_or_path and '\r' not in source_or_path and candidate.is_file():
                if candidate.stat().st_size>max_input_bytes: raise DeobfuscationLimitError('input byte limit exceeded')
                input_path=candidate;code=candidate.read_text(encoding='utf-8')
        except (OSError,ValueError) as exc:
            if isinstance(exc,(DeobfuscationLimitError,UnicodeError)): raise
    else: raise TypeError('expected Luau source text, UTF-8 bytes, or a path')
    if len(code.encode('utf-8'))>max_input_bytes: raise DeobfuscationLimitError('input byte limit exceeded')
    if '\x00' in code: raise ValueError('expected Luau source text')
    tokens=_scan_source(code,max_tokens)
    # Detection is metadata only, never proof that an obfuscator is supported.
    features=_format_features(code,tokens)
    report=DeobfuscationReport(detections=_format_detections(code,features))
    if moonsec_mode!='source':
        result=_try_moonsec_specialized(code,report,mode=moonsec_mode)
        if result is None: raise ValueError('no complete MoonSec context recovered for requested output mode')
        report.changed=True
        return (result,report) if return_report else result
    original=code
    probe=bool(features['lph']) or effort=='deep' or explore or any(t.kind=='string' and len(t.value)>48 for t in tokens)
    if probe and effort!='fast':
        layers,stats=recover_payload_layers(code,max_attempts=max_attempts,deep=effort=='deep' or explore,
                                           scan_xor=effort=='deep' or explore,time_budget=min(10.0,time_budget/3))
        report.details['layer_search']=stats
        report.details['payload_layers']=[{k:v for k,v in item.items() if k not in ('data','source')} for item in layers]
        candidates={x['sha256']:x['source'] for x in layers if x['source']}
        if candidates:report.details['candidate_source_count']=len(candidates)
        if explore and len(candidates)==1 and features['names']['loadstring']:
            code=next(iter(candidates.values()))
            tokens=_scan_source(code,max_tokens);features=_format_features(code,tokens)
            report.details['heuristic_candidate_selected']=True
            report.warnings.append('Exploratory candidate selected from an encoded literal; application identity and equivalence are unverified.')
            report.passes.append('select exploratory source candidate')
    code,count=_normalize_literal_tokens(code)
    if count:report.passes.append('normalize numeric and byte-string literals')
    tokens=_scan_source(code,max_tokens)
    if extract_luarmor_v4_loader_refs(code):
        report.details['luarmor_v4_loader_refs']=extract_luarmor_v4_loader_refs(code)
        report.warnings.append('Remote loader preserved: the protected source is not embedded in this input.')
    # Never send Luau type syntax or interpolation through a Lua subset parser:
    # that parser accepts/skips some annotations and would silently erase them.
    modern=any(t.kind=='interpolation' or t.value in ('::','->','@') for t in tokens)
    modern=modern or any(t.value==':' and not (i+2<len(tokens) and tokens[i+1].kind=='name' and tokens[i+2].value=='(') for i,t in enumerate(tokens))
    modern=modern or any(t.value=='export' and i+1<len(tokens) and tokens[i+1].value=='type' or t.value=='type' and i+2<len(tokens) and tokens[i+1].kind=='name' and tokens[i+2].value in ('=','<') or t.value=='const' and i+2<len(tokens) and tokens[i+1].kind=='name' and tokens[i+2].value in ('=',':',',') for i,t in enumerate(tokens))
    # A colon after a local/parameter name can be a type annotation. Method-call
    # colons are accepted by the AST; unknown typed forms fall back losslessly.
    modern=modern or any(t.value==':' and i+1<len(tokens) and tokens[i+1].value=='typeof' for i,t in enumerate(tokens))
    seen=set()
    for layer in range(min(max_passes,16)):
        if _time.monotonic() >= deadline:
            report.warnings.append('Time budget reached; returning recovered source.')
            break
        digest=hashlib.sha256(code.encode()).digest()
        if digest in seen: break
        seen.add(digest)
        if modern:
            if strict: raise ValueError('this source uses Luau syntax outside the AST engine; disable strict for lossless token recovery')
            code=_fallback_constants(code,report,max_passes,deadline)
            report.details['engine']='luau-token-preserving'
            report.warnings.append('Advanced Luau syntax retained; only proven literal expressions were folded.')
            break
        try:
            new=_ast_recover(code,report,max_passes,devirt,indent,deadline)
            report.details['engine']='luau-ast'
        except DeobfuscationLimitError: raise
        except Exception as exc:
            if strict: raise ValueError('Luau AST recovery failed: '+str(exc)) from exc
            report.warnings.append('AST recovery declined this syntax: '+str(exc))
            new=_fallback_constants(code,report,max_passes,deadline)
            report.details['engine']='luau-token-preserving'
            code=new; break
        if new==code: break
        # Further parsing is only needed when a loader reveals a new source
        # layer; the AST itself already reached its simplification fixed point.
        code=new
        if not report.passes or report.passes[-1]!='unwrap literal Luau loader': break
    code=_strip_source_comments(code)
    if pretty and report.details.get('engine')=='luau-token-preserving': code=_fallback_format(code,indent)
    elif code and not code.endswith('\n'): code+='\n'
    report.output_kind='source'; report.changed=code!=original
    if any('Luarmor' in d.family for d in report.detections):
        report.details['recovery_status']='partial-loader'
        report.details['missing_dependencies']=['The matching downloaded init loader and encrypted application data are required for further recovery.']
    elif any('LPH' in d.family for d in report.detections):
        report.details['recovery_status']='partial-vm'
        report.warnings.append('LPH outer layers and source cleanup do not establish complete VM application recovery.')
    elif report.details.get('heuristic_candidate_selected'):report.details['recovery_status']='heuristic-source-candidate'
    else:report.details['recovery_status']='source-transforms-applied' if report.passes else 'formatted-source'

    report.details['elapsed_seconds']=round(_time.monotonic()-start,6)
    report.details['input_bytes']=len(original.encode('utf-8'))
    report.details['output_bytes']=len(code.encode('utf-8'))
    return (code,report) if return_report else code

def _mask_literals(code,tokens):
    return _apply_edits(code,[(t.start,t.end,' '*len(t.value)) for t in tokens if t.kind in ('comment','string','interpolation')])


def deobfuscate_file(input_path: str|os.PathLike, output_path: str|os.PathLike|None=None, **kwargs):
    result,report=deobfuscate(input_path,return_report=True,**kwargs)
    if output_path is None:
        p=Path(input_path)
        output_path=p.with_name(p.stem+'.deobfuscated'+('.luac' if isinstance(result,(bytes,bytearray)) else '.luau'))
    op=Path(output_path)
    if isinstance(result,(bytes,bytearray)): op.write_bytes(bytes(result))
    else: op.write_text(result,encoding='utf-8')
    return op,report


def _legacy_analyze(source_or_path):
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
    return {
        "version": __version__, "language": "Roblox Luau source",
        "execution": "static only; no input execution or remote fetching",
        "default_output": "raw formatted source without diagnostic comments",
        "format_detection": "structural signatures; processing support is separate from full VM recovery",
        "payload_search": "shared attempt/depth/output budgets; LPH/Base85-LE, hex, Base32/58/64/85/91, percent, compression and optional XOR/shift sweeps",
        "source_candidate_mode": "--explore is explicit and labels its unverified candidate",
        "new_in_3_1": ["support-check bug fixed", "Luarmor V4 bootstrap and inline LPH VM recognition", "restricted while/repeat/ipairs/generalized-array loops", "string.gsub subset and local closure fixes", "MoonVeil-style LZSS"],
        "engines": ["scope-aware AST partial evaluator", "lossless Luau token fallback",
                    "Prometheus string/constant-array reversal", "best-effort Prometheus VM lifting"],
        "generic_transforms": ["immutable primitive locals and read-only constant table lookups",
            "closed pure decoder helpers with numeric loops and bounded table mutation",
            "string/byte/UTF-8 operations, bit32 operations, numeric bases, math",
            "constant arithmetic, Lua truthiness, nested branches, string concatenation",
            "literal loadstring layers, exact vararg forwarding wrappers, unused pure helpers"],
        "legacy_analysis": "Historical family detectors and payload extractors remain available; detection is not verified support.",
        "limitations": ["No guarantee of recovering arbitrary custom VMs or encrypted remote payloads",
            "VM lifting is best effort and format-specific; disable with --devirt off",
            "Advanced Luau types/interpolation use token-preserving fallback",
            "Original variable/function names are not recoverable",
            "Time limits are cooperative; use a subprocess for a hard wall-clock deadline"],
        "upstream": {"unprom": "d37b9d97746160359fb68dbdbb5213317403e669 (MIT, embedded with local patches)"}
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
    def deobfuscate(self, source_or_path, *, return_report=False, moonsec_mode='source', **kwargs):
        return deobfuscate(source_or_path,return_report=return_report,max_passes=self.max_passes,moonsec_mode=moonsec_mode,**kwargs)
    def file(self, input_path, output_path=None, **kwargs):
        kwargs.setdefault('max_passes',self.max_passes)
        return deobfuscate_file(input_path,output_path,**kwargs)


def _cli(argv=None):
    ap=argparse.ArgumentParser(description='LelSploit Roblox Luau source deobfuscator (static/offline).')
    ap.add_argument('input',nargs='?',help='input .lua/.luau file')
    ap.add_argument('-o','--output',help='output path')
    ap.add_argument('--detect',action='store_true',help='only print detection report')
    ap.add_argument('--luarmor-info',action='store_true',help='print parsed Luarmor V4 _bsdata0/bootstrap metadata as JSON')
    ap.add_argument('--capabilities',action='store_true',help='print supported families/transforms as JSON')
    ap.add_argument('--extract-payloads',metavar='DIR',help='also save statically recovered embedded payloads')
    ap.add_argument('--report',action='store_true',help='print applied passes/warnings to stderr')
    ap.add_argument('--moonsec-bytecode',action='store_true',help='emit .luac when exact MoonSec context is recoverable')
    ap.add_argument('--max-passes',type=int,default=6)
    ap.add_argument('--devirt',choices=('lift','deflatten','off'),default='lift',help='Prometheus VM recovery mode (best effort)')
    ap.add_argument('--strict',action='store_true',help='fail when syntax exceeds the AST engine')
    ap.add_argument('--indent',type=int,default=4)
    ap.add_argument('--time-budget',type=float,default=30.0,help='cooperative time budget in seconds')
    ap.add_argument('--max-input-mb',type=float,default=8.0)
    ap.add_argument('--stdout',action='store_true',help='write only raw recovered source to stdout')
    ap.add_argument('--effort',choices=('fast','balanced','deep'),default='balanced')
    ap.add_argument('--max-attempts',type=int,default=None,help='shared payload-probe budget, at most 16384')
    ap.add_argument('--explore',action='store_true',help='allow a unique parsed embedded-source candidate; identity is unverified')
    ns=ap.parse_args(argv)
    if ns.capabilities:
        print(json.dumps(capabilities(),indent=2)); return 0
    if not ns.input:
        ap.error('input is required unless --capabilities is used')
    source=sys.stdin.read() if ns.input=='-' else Path(ns.input)
    if ns.detect:
        print(json.dumps(analyze(source,deep=ns.effort=='deep'),indent=2)); return 0
    if ns.luarmor_info:
        info=extract_luarmor_v4_bootstrap(source)
        print(json.dumps(info,indent=2) if info is not None else 'null')
        return 0
    if ns.extract_payloads:
        d=Path(ns.extract_payloads); d.mkdir(parents=True,exist_ok=True)
        for i,payload in enumerate(extract_embedded_payloads(source,max_attempts=ns.max_attempts or (4096 if ns.effort=='deep' else 1024),deep=ns.effort=='deep'),1):
            fam=re.sub(r'[^A-Za-z0-9_.-]+','_',payload['family']).strip('_') or 'payload'
            kind=re.sub(r'[^A-Za-z0-9_.-]+','_',payload['kind']).strip('_') or 'data'
            data=payload['data']
            ext='.luac' if payload['kind']=='lua-bytecode' else '.json' if payload['kind']=='bootstrap-metadata' else '.luau' if isinstance(data,str) else '.bin'
            fp=d/f'{i:02d}_{fam}_{kind}{ext}'
            if isinstance(data,str):fp.write_text(data,encoding='utf-8')
            else:fp.write_bytes(bytes(data))
    mode='bytecode' if ns.moonsec_bytecode else 'source'
    try:
        result,rep=deobfuscate(source,return_report=True,max_passes=ns.max_passes,moonsec_mode=mode,
                              devirt=ns.devirt,strict=ns.strict,indent=ns.indent,
                              time_budget=ns.time_budget,max_input_bytes=int(ns.max_input_mb*1_000_000),
                              effort=ns.effort,max_attempts=ns.max_attempts,explore=ns.explore)
    except (OSError,ValueError,TypeError) as exc:
        print('lelsploit: '+str(exc),file=sys.stderr)
        return 2
    out=None
    if ns.stdout or ns.input=='-' and not ns.output:
        if isinstance(result,bytes): sys.stdout.buffer.write(result)
        else: sys.stdout.write(result)
    else:
        out=Path(ns.output) if ns.output else Path(ns.input).with_name(Path(ns.input).stem+'.deobfuscated'+('.luac' if isinstance(result,bytes) else '.luau'))
        if isinstance(result,bytes): out.write_bytes(result)
        else: out.write_text(result,encoding='utf-8')
    if ns.report:
        print(json.dumps({'best_family':rep.best_family,'detections':[d.__dict__ for d in rep.detections], 'passes':rep.passes,'warnings':rep.warnings,'details':rep.details,'output_kind':rep.output_kind},indent=2),file=sys.stderr)
    if out is not None: print(out,file=sys.stderr if ns.report else sys.stdout)
    return 0


if __name__=='__main__':
    raise SystemExit(_cli())
