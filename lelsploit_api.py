from __future__ import annotations
import ctypes
import hashlib
import json
import os
import re
import shlex
import shutil
import struct
import threading
import time
import uuid
import zipfile
from pathlib import Path
from typing import Any
import math
import weakref

def _appdata_root() -> Path:
    roaming = os.environ.get('APPDATA')
    if roaming:
        return Path(roaming).expanduser().resolve() / 'LelSploit'
    return (Path.home() / 'AppData' / 'Roaming' / 'LelSploit').resolve()
RUNTIME_DIR = Path(__file__).resolve().parent
APPDATA_DIR = _appdata_root()
DLL_DIR = APPDATA_DIR
DEPENDENCIES = ('libcrypto-3-x64.dll', 'libssl-3-x64.dll', 'xxhash.dll', 'zstd.dll', 'd3d9.dll', 'D3DX9_43.dll')
REQUIRED_FILES = (*DEPENDENCIES, 'libls.dll')
_DLL_SYNC_LOCK = threading.RLock()
_NATIVE_CALL_LOCK = threading.RLock()

class LuaExpr:

    def __init__(self, source: str):
        if not isinstance(source, str) or not source.strip():
            raise TypeError('source must be a non-empty Lua expression')
        self.source = source.strip()

    def __str__(self) -> str:
        return self.source

    def __repr__(self) -> str:
        return f'LuaExpr({self.source!r})'

class LuaReference(LuaExpr):

    def __init__(self, api: 'LelSploit', key: str):
        self._api = api
        self.key = key
        self._released = False
        super().__init__(f'getgenv().__PY_API_REFS[{_lua_string(key)}]')

    def release(self) -> None:
        if self._released:
            return
        self._api.execute(f'local g=getgenv() if g.__PY_API_REFS then g.__PY_API_REFS[{_lua_string(self.key)}]=nil end')
        self._released = True

def _lua_string(value: str) -> str:
    if not isinstance(value, str):
        raise TypeError('Lua string value must be a string')
    encoded = value.encode('utf-8')
    parts = ['"']
    for byte in encoded:
        if byte == 34:
            parts.append('\\"')
        elif byte == 92:
            parts.append('\\\\')
        elif 32 <= byte <= 126:
            parts.append(chr(byte))
        else:
            parts.append(f'\\{byte:03d}')
    parts.append('"')
    return ''.join(parts)

def _lua_value(value: Any) -> str:
    active: set[int] = set()

    def encode(item: Any, depth: int=0) -> str:
        if depth > 64:
            raise ValueError('Lua value nesting exceeds 64 levels')
        if isinstance(item, LuaExpr):
            if isinstance(item, LuaReference) and getattr(item, '_released', False):
                raise RuntimeError('Lua reference has been released')
            return item.source
        if item is None:
            return 'nil'
        if isinstance(item, bool):
            return 'true' if item else 'false'
        if isinstance(item, int):
            if abs(item) > 2 ** 53:
                raise ValueError("Integer exceeds Luau's exact integer range")
            return str(item)
        if isinstance(item, float):
            if not math.isfinite(item):
                raise ValueError('Lua numbers must be finite')
            return repr(item)
        if isinstance(item, str):
            return _lua_string(item)
        if isinstance(item, (dict, list, tuple)):
            identity = id(item)
            if identity in active:
                raise ValueError('Cyclic containers cannot be encoded as Lua literals')
            active.add(identity)
            try:
                pairs = item.items() if isinstance(item, dict) else enumerate(item, 1)
                fields = []
                for key, child in pairs:
                    if key is None:
                        raise TypeError('Lua table keys cannot be None')
                    fields.append(f'[{encode(key, depth + 1)}]={encode(child, depth + 1)}')
                return '{' + ','.join(fields) + '}'
            finally:
                active.remove(identity)
        raise TypeError(f'Unsupported Lua value type: {type(item).__name__}')
    return encode(value)

class _DrawingObject:
    _internal_names = {'_api', '_key', '_class_name', '_removed'}

    def __init__(self, api: 'LelSploit', key: str, class_name: str):
        object.__setattr__(self, '_api', api)
        object.__setattr__(self, '_key', key)
        object.__setattr__(self, '_class_name', class_name)
        object.__setattr__(self, '_removed', False)

    @property
    def class_name(self) -> str:
        return self._class_name

    def Remove(self) -> None:
        if self._removed:
            return
        key = _lua_string(self._key)
        self._api.execute(f'local g=getgenv()\ng.__PY_DRAWINGS=g.__PY_DRAWINGS or {{}}\nlocal o=g.__PY_DRAWINGS[{key}]\nif o then\n    o:Remove()\n    g.__PY_DRAWINGS[{key}]=nil\nend')
        object.__setattr__(self, '_removed', True)
    remove = Remove

    def __setattr__(self, name: str, value: Any) -> None:
        if name in self._internal_names:
            object.__setattr__(self, name, value)
        else:
            self.update(**{name: value})

    def __getattr__(self, name: str) -> Any:
        raise AttributeError(f'Reading Drawing.{name} is unavailable because libls Execute() does not return Lua values to Python.')

    def update(self, **properties: Any) -> None:
        if self._removed:
            raise RuntimeError('This Drawing object has already been removed')
        if not properties:
            return
        assignments = []
        for name, value in properties.items():
            if not re.fullmatch('[A-Za-z_][A-Za-z0-9_]*', name):
                raise AttributeError(f'Invalid Drawing property: {name!r}')
            if name in {'TextBounds', '__OBJECT_EXISTS'}:
                raise AttributeError(f'{name} is read-only')
            assignments.append(f'o[{_lua_string(name)}]={_lua_value(value)}')
        self._api.execute('local g=getgenv() local o=g.__PY_DRAWINGS and g.__PY_DRAWINGS[' + _lua_string(self._key) + "] if not o then error('Drawing object no longer exists') end\n" + '\n'.join(assignments))
    Destroy = Remove
    destroy = Remove

class _DrawingAPI:
    VALID_CLASSES = {'Line', 'Text', 'Square', 'Circle', 'Triangle', 'Quad', 'Image'}

    def __init__(self, api: 'LelSploit'):
        self._api = api
        self._counter = 0
        self._lock = threading.RLock()
        self._objects = weakref.WeakSet()

    def new(self, class_name: str) -> _DrawingObject:
        if not isinstance(class_name, str):
            raise TypeError('class_name must be a string')
        canonical = next((name for name in self.VALID_CLASSES if name.casefold() == class_name.casefold()), None)
        if canonical is None:
            raise ValueError(f'Unsupported Drawing class: {class_name!r}')
        with self._lock:
            self._counter += 1
            key = f'draw_{self._counter}_{uuid.uuid4().hex}'
            self._api.execute(f'local g=getgenv() g.__PY_DRAWINGS=g.__PY_DRAWINGS or {{}} g.__PY_DRAWINGS[{_lua_string(key)}]=Drawing.new({_lua_string(canonical)})')
            item = _DrawingObject(self._api, key, canonical)
            self._objects.add(item)
            return item

    def clear(self) -> None:
        with self._lock:
            self._api.execute('cleardrawcache() local g=getgenv() g.__PY_DRAWINGS={}')
            for item in self._objects:
                object.__setattr__(item, '_removed', True)
            self._objects.clear()

def _files_match(source: Path, target: Path) -> bool:
    try:
        if not target.is_file() or source.stat().st_size != target.stat().st_size:
            return False
        if source.samefile(target):
            return True
        with source.open('rb') as src, target.open('rb') as dst:
            while True:
                chunk = src.read(1024 * 1024)
                other = dst.read(1024 * 1024)
                if chunk != other:
                    return False
                if not chunk:
                    return True
    except OSError:
        return False

def _validate_x64_dll(path: Path) -> None:
    with path.open('rb') as stream:
        dos = stream.read(64)
        if len(dos) != 64 or dos[:2] != b'MZ':
            raise RuntimeError(f'{path.name}: invalid DOS header; expected a Windows x64 DLL')
        offset = struct.unpack_from('<I', dos, 60)[0]
        length = path.stat().st_size
        if offset < 64 or offset > length - 26:
            raise RuntimeError(f'{path.name}: invalid PE header offset')
        stream.seek(offset)
        header = stream.read(26)
        if header[:4] != b'PE\x00\x00':
            raise RuntimeError(f'{path.name}: invalid PE signature')
        machine = struct.unpack_from('<H', header, 4)[0]
        optional_size = struct.unpack_from('<H', header, 20)[0]
        flags = struct.unpack_from('<H', header, 22)[0]
        magic = struct.unpack_from('<H', header, 24)[0]
        if machine != 34404 or magic != 523:
            raise RuntimeError(f'{path.name}: expected AMD64/PE32+; machine=0x{machine:04x}, format=0x{magic:04x}')
        if optional_size < 2 or offset + 24 + optional_size > length or (not flags & 8192):
            raise RuntimeError(f'{path.name}: malformed DLL header')

def _atomic_replace_dll(temp_target: Path, target: Path) -> None:
    try:
        _validate_x64_dll(temp_target)
        os.replace(temp_target, target)
    except PermissionError as exc:
        raise RuntimeError(f'Cannot replace {target.name}; close all instances using the DLL and restart') from exc
    finally:
        temp_target.unlink(missing_ok=True)

def _payload_members(archive):
    expected = {name.casefold(): name for name in REQUIRED_FILES}
    members = {}
    for item in archive.infolist():
        if item.is_dir():
            continue
        base = item.filename.replace('\\', '/').rsplit('/', 1)[-1]
        name = expected.get(base.casefold())
        if name is None:
            continue
        if name in members:
            raise RuntimeError(f'Duplicate native DLL in payload: {name}')
        members[name] = item.filename
    return members

def _read_payload_member(archive, member):
    maximum = 128 * 1024 * 1024
    info = archive.getinfo(member)
    if not 0 < info.file_size <= maximum:
        raise RuntimeError(f'Invalid DLL payload size: {member}')
    with archive.open(info) as stream:
        data = stream.read(maximum + 1)
    if len(data) != info.file_size or len(data) > maximum:
        raise RuntimeError(f'Invalid DLL payload length: {member}')
    return data

def ensure_appdata_dlls() -> Path:
    with _DLL_SYNC_LOCK:
        return _ensure_appdata_dlls_locked()

def _ensure_appdata_dlls_locked() -> Path:
    DLL_DIR.mkdir(parents=True, exist_ok=True)
    payload_path = RUNTIME_DIR / 'lelsploit_dll_payload.zip'
    local_libls = next((path for path in (RUNTIME_DIR / 'libls.dll', RUNTIME_DIR / 'dlls' / 'libls.dll', RUNTIME_DIR / 'bin' / 'libls.dll') if path.is_file()), None)
    installed: set[str] = set()
    if payload_path.is_file():
        try:
            with zipfile.ZipFile(payload_path, 'r') as archive:
                members = _payload_members(archive)
                for name in REQUIRED_FILES:
                    if name == 'libls.dll' and local_libls is not None:
                        continue
                    member = members.get(name)
                    if member is None:
                        continue
                    data = _read_payload_member(archive, member)
                    target = DLL_DIR / name
                    replace = True
                    if target.is_file():
                        try:
                            replace = hashlib.sha256(target.read_bytes()).digest() != hashlib.sha256(data).digest()
                        except OSError:
                            replace = True
                    if replace:
                        temp_target = target.with_name(f'.{target.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp')
                        temp_target.write_bytes(data)
                        _atomic_replace_dll(temp_target, target)
                    installed.add(name)
        except (OSError, zipfile.BadZipFile):
            pass
    for name in REQUIRED_FILES:
        target = DLL_DIR / name
        if name in installed and name != 'libls.dll':
            continue
        if name != 'libls.dll' and target.is_file():
            continue
        candidates = (RUNTIME_DIR / name, RUNTIME_DIR / 'dlls' / name, RUNTIME_DIR / 'bin' / name)
        source = local_libls if name == 'libls.dll' else next((candidate for candidate in candidates if candidate.is_file()), None)
        if source is None:
            continue
        if name == 'libls.dll' and _files_match(source, target):
            continue
        temp_target = target.with_name(f'.{target.name}.{os.getpid()}.{uuid.uuid4().hex}.tmp')
        shutil.copy2(source, temp_target)
        _atomic_replace_dll(temp_target, target)
    return DLL_DIR

class LelSploit:

    def __init__(self, dll_dir: str | Path | None=None):
        if dll_dir is not None and Path(dll_dir).expanduser().resolve() != DLL_DIR:
            raise ValueError(f'LelSploit DLLs must be loaded from {DLL_DIR}')
        self.dll_dir = ensure_appdata_dlls()
        os.chdir(self.dll_dir)
        self._libraries: list[ctypes.CDLL] = []
        self._engine = None
        self._lock = _NATIVE_CALL_LOCK
        self.Drawing = _DrawingAPI(self)

    def initialize(self) -> None:
        with self._lock:
            if self._engine is not None:
                return
            if os.name != 'nt' or struct.calcsize('P') != 8:
                raise RuntimeError('LelSploit requires 64-bit Python on Windows')
            missing = [name for name in REQUIRED_FILES if not (self.dll_dir / name).is_file()]
            if missing:
                raise FileNotFoundError(f"Missing DLL file(s) in {self.dll_dir}: {', '.join(missing)}")
            search_flags = 256 | 2048
            try:
                os.chdir(self.dll_dir)
                for name in REQUIRED_FILES:
                    _validate_x64_dll(self.dll_dir / name)
                    dll = ctypes.CDLL(str(self.dll_dir / name), winmode=search_flags)
                    self._libraries.append(dll)
                engine = self._libraries[-1]
                engine.SetSettings.argtypes = [ctypes.c_int, ctypes.c_int]
                engine.SetSettings.restype = None
                engine.Attach.argtypes = []
                engine.Attach.restype = None
                engine.IsAttached.argtypes = []
                engine.IsAttached.restype = ctypes.c_bool
                engine.Execute.argtypes = [ctypes.POINTER(ctypes.c_char)]
                engine.Execute.restype = None
                self._engine = engine
            except (OSError, AttributeError) as exc:
                self._libraries.clear()
                self._engine = None
                raise RuntimeError(f'Failed to initialize LelSploit: {exc}') from exc

    def _engine_or_initialize(self):
        if self._engine is None:
            self.initialize()
        return self._engine

    def attach(self) -> None:
        engine = self._engine_or_initialize()
        with self._lock:
            engine.SetSettings(0, 0)
            engine.Attach()

    def is_attached(self) -> bool:
        engine = self._engine_or_initialize()
        with self._lock:
            return bool(engine.IsAttached())

    def execute(self, lua_script: str) -> None:
        if not isinstance(lua_script, str):
            raise TypeError('lua_script must be a string')
        if '\x00' in lua_script:
            raise ValueError('lua_script cannot contain a NUL character')
        payload = ctypes.create_string_buffer(lua_script.encode('utf-8'))
        with self._lock:
            engine = self._engine_or_initialize()
            if not engine.IsAttached():
                raise RuntimeError('LelSploit is not attached')
            engine.Execute(payload)

    def LaunchExploit(self) -> None:
        self.attach()

    def SendLuaScript(self, lua_script: str) -> None:
        self.execute(lua_script)

    def isAPIAttached(self) -> bool:
        return self.is_attached()

    @staticmethod
    def lua(expression: str) -> LuaExpr:
        return LuaExpr(expression)

    def _store_expression(self, expression: str) -> LuaReference:
        key = f'ref_{uuid.uuid4().hex}'
        self.execute(f'local g=getgenv()\ng.__PY_API_REFS=g.__PY_API_REFS or {{}}\ng.__PY_API_REFS[{_lua_string(key)}]=({expression})')
        return LuaReference(self, key)

    def set_fps_cap(self, cap: int | float) -> None:
        self.execute(f'setfpscap({_lua_value(cap)})')
    setfpscap = set_fps_cap

    def hookfunction(self, old_function: LuaExpr, hook_function: LuaExpr) -> LuaReference:
        if not isinstance(old_function, LuaExpr):
            raise TypeError('old_function must be api.lua(...) or a LuaReference')
        if not isinstance(hook_function, LuaExpr):
            raise TypeError('hook_function must be api.lua(...) or a LuaReference')
        return self._store_expression(f'hookfunction(({old_function.source}), ({hook_function.source}))')

    def MouseMoveRel(self, x: int, y: int) -> None:
        self.execute(f'mousemoverel({int(x)}, {int(y)})')
    mousemoverel = MouseMoveRel
    MouseMoveRelative = MouseMoveRel
    mousemoverelative = MouseMoveRel

    def MouseScroll(self, y: int) -> None:
        self.execute(f'mousescroll({int(y)})')
    mousescroll = MouseScroll

    def MouseButton1Click(self) -> None:
        self.execute('mouse1click()')

    def MouseButton1Press(self) -> None:
        self.execute('mouse1press()')

    def MouseButton1Release(self) -> None:
        self.execute('mouse1release()')

    def MouseButton2Click(self) -> None:
        self.execute('mouse2click()')

    def MouseButton2Press(self) -> None:
        self.execute('mouse2press()')

    def MouseButton2Release(self) -> None:
        self.execute('mouse2release()')

    def KeyPress(self, key: int) -> None:
        self.execute(f'keypress({int(key)})')
    keypress = KeyPress

    def KeyRelease(self, key: int) -> None:
        self.execute(f'keyrelease({int(key)})')
    keyrelease = KeyRelease

    def MouseMoveAbs(self, x: int, y: int) -> None:
        self.execute(f'mousemoveabs({int(x)}, {int(y)})')
    mousemoveabs = MouseMoveAbs

    def rconsoleprint(self, text: Any) -> None:
        self.execute(f'rconsoleprint({_lua_value(str(text))})')

    def rconsolewarn(self, text: Any) -> None:
        self.execute(f'rconsolewarn({_lua_value(str(text))})')

    def rconsoleerr(self, text: Any) -> None:
        self.execute(f'rconsoleerror({_lua_value(str(text))})')
    rconsoleerror = rconsoleerr

    def rconsolename(self, text: str) -> None:
        self.execute(f'rconsolename({_lua_string(str(text))})')

    def rconsoleclear(self) -> None:
        self.execute('rconsoleclear()')

    def rconsolecreate(self) -> None:
        self.execute('rconsolecreate()')

    def rconsoledestroy(self) -> None:
        self.execute('rconsoledestroy()')

    def HttpGet(self, url: str) -> LuaReference:
        if not isinstance(url, str):
            raise TypeError('url must be a string')
        return self._store_expression(f'game:HttpGet({_lua_string(url)})')
    httpget = HttpGet

    @staticmethod
    def Vector2(x: float, y: float) -> LuaExpr:
        if isinstance(x, bool) or isinstance(y, bool):
            raise TypeError('coordinates must be numbers')
        return LuaExpr(f'Vector2.new({_lua_value(float(x))},{_lua_value(float(y))})')

    @staticmethod
    def Color3(r: float, g: float, b: float) -> LuaExpr:
        if any((isinstance(value, bool) for value in (r, g, b))):
            raise TypeError('color channels must be numbers')
        return LuaExpr('Color3.new(' + ','.join((_lua_value(float(value)) for value in (r, g, b))) + ')')

    def SendLuaCScript(self, lua_c_script: str) -> None:
        if not isinstance(lua_c_script, str):
            raise TypeError('lua_c_script must be a string')
        operations = self._parse_lua_c(lua_c_script)
        generated = self._build_lua_c_runtime(operations)
        self.execute(generated)
    send_lua_c_script = SendLuaCScript

    @staticmethod
    def _parse_lua_c(source: str) -> list[tuple[str, list[str]]]:
        operations = []
        for line_number, raw_line in enumerate(source.splitlines(), 1):
            split = raw_line.strip().split(None, 1)
            if not split:
                continue
            op = split[0].lower()
            rest = split[1] if len(split) == 2 else ''
            if op == 'pushstring':
                operations.append((op, [rest]))
                continue
            try:
                args = shlex.split(rest, posix=True) if rest else []
            except ValueError as exc:
                raise ValueError(f'Invalid Lua-C syntax on line {line_number}: {exc}') from exc
            operations.append((op, args))
        return operations

    @staticmethod
    def _build_lua_c_runtime(operations: list[tuple[str, list[str]]]) -> str:
        lines = ['local __NIL={}', 'local __S={n=0}', 'local function __box(v) if v==nil then return __NIL end return v end', 'local function __unbox(v) if v==__NIL then return nil end return v end', 'local function __push(v) __S.n=__S.n+1 __S[__S.n]=__box(v) end', 'local function __pop() if __S.n<=0 then return nil end local v=__S[__S.n] __S[__S.n]=nil __S.n=__S.n-1 return __unbox(v) end', 'local function __idx(i) if i<0 then return __S.n+i+1 end return i end', 'local function __get(i) return __unbox(__S[__idx(i)]) end', 'local function __settop(i)', '  local t=i', '  if i<0 then t=__S.n+i+1 end', '  if t<0 then t=0 end', '  while __S.n>t do __S[__S.n]=nil __S.n=__S.n-1 end', '  while __S.n<t do __push(nil) end', 'end', 'local function __call(nargs,nresults,protected)\n  assert(nargs>=0 and nargs%1==0 and nresults>=-1 and nresults%1==0,"invalid call arity")\n  assert(__S.n>=nargs+1,"stack underflow")', '  local fnindex=__S.n-nargs', '  local fn=__get(fnindex)', '  local args={}', '  for i=1,nargs do args[i]=__get(fnindex+i) end', '  __settop(fnindex-1)', '  local results', '  if protected then', '    results=table.pack(pcall(fn,table.unpack(args,1,nargs)))', '    local ok=results[1]', '    if not ok then __push(results[2]) return end', '    local count=results.n-1', '    if nresults<0 then nresults=count end', '    for i=1,nresults do __push(results[i+1]) end', '  else', '    results=table.pack(fn(table.unpack(args,1,nargs)))', '    local count=results.n', '    if nresults<0 then nresults=count end', '    for i=1,nresults do __push(results[i]) end', '  end', 'end', 'local function __global(name)', '  local g=getgenv and getgenv() or _G', '  local v=g and g[name]', '  if v==nil and getrenv then local r=getrenv() v=r and r[name] end', '  return v', 'end']

        def need(op: str, args: list[str], count: int) -> None:
            if len(args) != count:
                raise ValueError(f'{op} expects {count} argument(s), got {len(args)}')
        for op, args in operations:
            if op == 'getglobal':
                need(op, args, 1)
                lines.append(f'__push(__global({_lua_string(args[0])}))')
            elif op == 'getfield':
                need(op, args, 2)
                index = int(args[0])
                lines.append(f'do local t=__get({index}) __push(t[{_lua_string(args[1])}]) end')
            elif op == 'setfield':
                need(op, args, 2)
                index = int(args[0])
                lines.append(f'do local t=__get({index}) local v=__pop() t[{_lua_string(args[1])}]=v end')
            elif op == 'pushvalue':
                need(op, args, 1)
                lines.append(f'__push(__get({int(args[0])}))')
            elif op == 'pushstring':
                need(op, args, 1)
                lines.append(f'__push({_lua_string(args[0])})')
            elif op == 'pushnumber':
                need(op, args, 1)
                number = float(args[0])
                lines.append(f'__push({_lua_value(number)})')
            elif op == 'pushboolean':
                need(op, args, 1)
                value = args[0].lower()
                if value not in {'true', 'false', '1', '0'}:
                    raise ValueError('pushboolean expects true/false or 1/0')
                lua_bool = 'true' if value in {'true', '1'} else 'false'
                lines.append(f'__push({lua_bool})')
            elif op == 'pushnil':
                need(op, args, 0)
                lines.append('__push(nil)')
            elif op == 'pcall':
                need(op, args, 3)
                nargs = int(args[0])
                nresults = int(args[1])
                if int(args[2]) != 0:
                    raise NotImplementedError('Lua-C pcall error-function indices require native support')
                lines.append(f'__call({nargs},{nresults},true)')
            elif op == 'call':
                need(op, args, 2)
                lines.append(f'__call({int(args[0])},{int(args[1])},false)')
            elif op == 'emptystack':
                need(op, args, 0)
                lines.append('__settop(0)')
            elif op == 'settop':
                need(op, args, 1)
                lines.append(f'__settop({int(args[0])})')
            elif op == 'gettop':
                need(op, args, 0)
                lines.append('print(__S.n)')
            elif op == 'pop':
                need(op, args, 1)
                lines.append(f'for _=1,{max(0, int(args[0]))} do __pop() end')
            elif op == 'insert':
                need(op, args, 1)
                index = int(args[0])
                lines.extend(['do', f'  local target=__idx({index})', '  local top=__pop()', '  assert(target>=1 and target<=__S.n+1,"invalid insert stack index")', '  __S.n=__S.n+1', '  for i=__S.n,target+1,-1 do __S[i]=__S[i-1] end', '  __S[target]=__box(top)', 'end'])
            elif op == 'createtable':
                need(op, args, 2)
                int(args[0])
                int(args[1])
                lines.append('__push({})')
            elif op == 'settable':
                need(op, args, 1)
                index = int(args[0])
                lines.append(f'do local t=__get({index}) local v=__pop() local k=__pop() t[k]=v end')
            elif op == 'next':
                need(op, args, 1)
                index = int(args[0])
                lines.extend(['do', f'  local t=__get({index})', '  local key=__pop()', '  local nk,nv=next(t,key)', '  if nk~=nil then __push(nk) __push(nv) end', 'end'])
            elif op == 'tonumber':
                need(op, args, 1)
                lines.append(f'print(tonumber(__get({int(args[0])})))')
            elif op == 'tostring':
                need(op, args, 1)
                lines.append(f'print(tostring(__get({int(args[0])})))')
            elif op == 'touserdata':
                need(op, args, 1)
                lines.append(f'print(tostring(__get({int(args[0])})))')
            else:
                raise ValueError(f'Unsupported Lua-C parser command: {op}')
        return '\n'.join(lines)

    def execute_many(self, scripts) -> None:
        if isinstance(scripts, (str, bytes)):
            raise TypeError('scripts must be an iterable of Lua source strings')
        chunks = []
        for source in scripts:
            if not isinstance(source, str):
                raise TypeError('Each script must be a string')
            if '\x00' in source:
                raise ValueError('Scripts cannot contain a NUL character')
            chunks.append('do local function __lelsploit_batch_step(...)\n' + source + '\nend __lelsploit_batch_step() end')
        if chunks:
            self.execute('\n'.join(chunks))

    def call(self, function_name: str, *args: Any) -> None:
        if not isinstance(function_name, str) or not re.fullmatch('[A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)*', function_name):
            raise ValueError('function_name must be a dotted Lua identifier')
        self.execute(function_name + '(' + ','.join((_lua_value(value) for value in args)) + ')')

    def call_ref(self, function_name: str, *args: Any) -> LuaReference:
        if not isinstance(function_name, str) or not re.fullmatch('[A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)*', function_name):
            raise ValueError('function_name must be a dotted Lua identifier')
        return self._store_expression(function_name + '(' + ','.join((_lua_value(value) for value in args)) + ')')

    def setclipboard(self, text: str) -> None:
        if not isinstance(text, str):
            raise TypeError('text must be a string')
        self.call('setclipboard', text)

    def queue_on_teleport(self, source: str) -> None:
        if not isinstance(source, str):
            raise TypeError('source must be a string')
        self.call('queue_on_teleport', source)

    def dofile(self, path: str) -> LuaReference:
        if not isinstance(path, str):
            raise TypeError('path must be a string')
        return self.call_ref('dofile', path)

    def rconsoleinput(self) -> LuaReference:
        return self.call_ref('rconsoleinput')

    def messagebox(self, text: str, caption: str, flags: int=0) -> LuaReference:
        if not isinstance(text, str) or not isinstance(caption, str):
            raise TypeError('text and caption must be strings')
        if isinstance(flags, bool) or not isinstance(flags, int) or (not 0 <= flags <= 4294967295):
            raise ValueError('flags must be a uint32')
        return self.call_ref('messagebox', text, caption, flags)

    def getcallingscript(self) -> LuaReference:
        return self.call_ref('getcallingscript')
    setrbxclipboard = setclipboard
    toclipboard = setclipboard
    queueonteleport = queue_on_teleport
    rconsolesettitle = rconsolename
    consolesettitle = rconsolename
    mouse1click = MouseButton1Click
    mouse1press = MouseButton1Press
    mouse1release = MouseButton1Release
    mouse2click = MouseButton2Click
    mouse2press = MouseButton2Press
    mouse2release = MouseButton2Release
    mousecroll = MouseScroll
API = LelSploit
ExploitAPI = LelSploit

class CombinedStop:

    def __init__(self, *events):
        self.events = tuple((event for event in events if event is not None))

    def is_set(self):
        return any((event.is_set() for event in self.events))

    def wait(self, timeout=None):
        if self.is_set():
            return True
        if timeout is None:
            while not self.is_set():
                time.sleep(0.05)
            return True
        deadline = time.monotonic() + max(0.0, float(timeout))
        while not self.is_set():
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return False
            time.sleep(min(0.05, remaining))
        return True

def attach_api(log, stop, api=None, force=False):
    if api is None:
        api = LelSploit()
        api.initialize()
        force = True
    if force or not api.is_attached():
        api.attach()
    deadline = time.monotonic() + 20
    while not api.is_attached():
        if stop.is_set():
            return None
        if time.monotonic() >= deadline:
            raise TimeoutError('LelSploit API did not report an attached client.')
        stop.wait(0.25)
    if stop.is_set():
        return None
    log('LelSploit API reports attached.')
    return api

def run_script(source, log, stop, api=None):
    api = attach_api(log, stop, api)
    if api is None:
        return None
    api.execute(source)
    log("Script sent. Check the client's output.")
    return api

def reattach_api(log, stop, api=None, initial=False):
    api = attach_api(log, stop, api, force=True)
    if api is not None:
        log('Attached successfully.' if initial else 'Reattached successfully.')
    return api

def detach_api(api, log=None):
    if api is None:
        return None
    detached = False
    for name in ('detach', 'disconnect', 'deattach', 'close', 'dispose', 'shutdown'):
        method = getattr(api, name, None)
        if not callable(method):
            continue
        try:
            method()
            detached = True
            break
        except TypeError:
            continue
        except Exception:
            break
    if log is not None:
        log('Detached from Roblox.' if detached else 'Attachment state cleared.')
    return None
