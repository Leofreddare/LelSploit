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
import uuid
import zipfile
from pathlib import Path
from typing import Any


def _appdata_root() -> Path:
    roaming = os.environ.get("APPDATA")
    if roaming:
        return Path(roaming).expanduser().resolve() / "LelSploit"
    # Development fallback for non-Windows environments.
    return (Path.home() / "AppData" / "Roaming" / "LelSploit").resolve()


RUNTIME_DIR = Path(__file__).resolve().parent
APPDATA_DIR = _appdata_root()
DLL_DIR = APPDATA_DIR


DEPENDENCIES = (
    "libcrypto-3-x64.dll",
    "libssl-3-x64.dll",
    "xxhash.dll",
    "zstd.dll",
    "d3d9.dll",
    "D3DX9_43.dll",
)

REQUIRED_FILES = (*DEPENDENCIES, "libls.dll")


class LuaExpr:
    def __init__(self, source: str):
        if not isinstance(source, str) or not source.strip():
            raise TypeError("source must be a non-empty Lua expression")
        self.source = source.strip()

    def __str__(self) -> str:
        return self.source

    def __repr__(self) -> str:
        return f"LuaExpr({self.source!r})"


class LuaReference(LuaExpr):
    def __init__(self, api: "LelSploit", key: str):
        self._api = api
        self.key = key
        super().__init__(f'getgenv().__PY_API_REFS[{json.dumps(key)}]')

    def release(self) -> None:
        self._api.execute(
            f'''local g=getgenv()
g.__PY_API_REFS=g.__PY_API_REFS or {{}}
g.__PY_API_REFS[{_lua_string(self.key)}]=nil'''
        )


def _lua_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def _lua_value(value: Any) -> str:
    if isinstance(value, LuaExpr):
        return value.source
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return _lua_string(value)
    raise TypeError(
        "Unsupported Lua value. Use numbers, strings, booleans, None, "
        "LuaExpr/LuaReference, api.Vector2(...), or api.Color3(...)."
    )


class _DrawingObject:
    _internal_names = {"_api", "_key", "_class_name", "_removed"}

    def __init__(self, api: "LelSploit", key: str, class_name: str):
        object.__setattr__(self, "_api", api)
        object.__setattr__(self, "_key", key)
        object.__setattr__(self, "_class_name", class_name)
        object.__setattr__(self, "_removed", False)

    @property
    def class_name(self) -> str:
        return self._class_name

    def Remove(self) -> None:
        if self._removed:
            return

        key = _lua_string(self._key)

        self._api.execute(
            f'''local g=getgenv()
g.__PY_DRAWINGS=g.__PY_DRAWINGS or {{}}
local o=g.__PY_DRAWINGS[{key}]
if o then
    o:Remove()
    g.__PY_DRAWINGS[{key}]=nil
end'''
        )

        object.__setattr__(self, "_removed", True)

    remove = Remove

    def __setattr__(self, name: str, value: Any) -> None:
        if name in self._internal_names:
            object.__setattr__(self, name, value)
            return

        if self._removed:
            raise RuntimeError("This Drawing object has already been removed")

        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
            raise AttributeError(f"Invalid Drawing property name: {name!r}")

        if name == "TextBounds":
            raise AttributeError("TextBounds is read-only")

        key = _lua_string(self._key)
        lua_value = _lua_value(value)

        self._api.execute(
            f'''local g=getgenv()
g.__PY_DRAWINGS=g.__PY_DRAWINGS or {{}}
local o=g.__PY_DRAWINGS[{key}]
if not o then error("Drawing object no longer exists") end
o.{name}={lua_value}'''
        )

    def __getattr__(self, name: str) -> Any:
        raise AttributeError(
            f"Reading Drawing.{name} is unavailable because libls Execute() "
            "does not return Lua values to Python."
        )


class _DrawingAPI:
    VALID_CLASSES = {
        "Line",
        "Text",
        "Square",
        "Circle",
        "Triangle",
        "Quad",
        "Image",
    }

    def __init__(self, api: "LelSploit"):
        self._api = api
        self._counter = 0
        self._lock = threading.Lock()

    def new(self, class_name: str) -> _DrawingObject:
        if not isinstance(class_name, str) or not class_name:
            raise TypeError("class_name must be a non-empty string")

        canonical = class_name[:1].upper() + class_name[1:]

        if canonical not in self.VALID_CLASSES:
            raise ValueError(
                f"Unsupported Drawing class {class_name!r}. "
                f"Expected one of: {', '.join(sorted(self.VALID_CLASSES))}"
            )

        with self._lock:
            self._counter += 1
            key = f"draw_{self._counter}_{uuid.uuid4().hex}"

        lua_key = _lua_string(key)
        lua_class = _lua_string(canonical)

        self._api.execute(
            f'''local g=getgenv()
g.__PY_DRAWINGS=g.__PY_DRAWINGS or {{}}
g.__PY_DRAWINGS[{lua_key}]=Drawing.new({lua_class})'''
        )

        return _DrawingObject(self._api, key, canonical)

    def clear(self) -> None:
        self._api.execute(
            '''Drawing.clear()
local g=getgenv()
g.__PY_DRAWINGS={}'''
        )


def _files_match(source: Path, target: Path) -> bool:
    """Return True when two files contain the same bytes."""
    try:
        if not target.is_file() or source.stat().st_size != target.stat().st_size:
            return False
        source_hash = hashlib.sha256()
        target_hash = hashlib.sha256()
        with source.open("rb") as src, target.open("rb") as dst:
            while True:
                src_chunk = src.read(1024 * 1024)
                dst_chunk = dst.read(1024 * 1024)
                if not src_chunk and not dst_chunk:
                    break
                source_hash.update(src_chunk)
                target_hash.update(dst_chunk)
        return source_hash.digest() == target_hash.digest()
    except OSError:
        return False


def ensure_appdata_dlls() -> Path:
    r"""Materialize all native DLLs into %APPDATA%\LelSploit.

    Packaged builds carry the DLLs inside ``lelsploit_dll_payload.zip`` as
    ordinary data. They are never loaded from the EXE directory or Nuitka's
    onefile extraction directory. On startup, the payload is copied/extracted
    into AppData first; the API only loads the AppData copies.
    """
    DLL_DIR.mkdir(parents=True, exist_ok=True)

    payload_path = RUNTIME_DIR / "lelsploit_dll_payload.zip"
    installed: set[str] = set()

    if payload_path.is_file():
        try:
            with zipfile.ZipFile(payload_path, "r") as archive:
                members = {Path(name).name: name for name in archive.namelist()}

                for name in REQUIRED_FILES:
                    member = members.get(name)
                    if member is None:
                        continue

                    data = archive.read(member)
                    target = DLL_DIR / name

                    replace = True
                    if target.is_file():
                        try:
                            replace = hashlib.sha256(target.read_bytes()).digest() != hashlib.sha256(data).digest()
                        except OSError:
                            replace = True

                    if replace:
                        temp_target = target.with_suffix(target.suffix + ".new")
                        temp_target.write_bytes(data)
                        os.replace(temp_target, target)

                    installed.add(name)
        except (OSError, zipfile.BadZipFile):
            pass

    # Source-development fallback: loose DLLs may sit beside the source files,
    # but they are still COPIED to AppData before use and are never loaded there.
    for name in REQUIRED_FILES:
        target = DLL_DIR / name
        if name in installed or target.is_file():
            continue

        candidates = (
            RUNTIME_DIR / name,
            RUNTIME_DIR / "dlls" / name,
            RUNTIME_DIR / "bin" / name,
        )
        source = next((candidate for candidate in candidates if candidate.is_file()), None)
        if source is None:
            continue

        temp_target = target.with_suffix(target.suffix + ".new")
        shutil.copy2(source, temp_target)
        os.replace(temp_target, target)

    return DLL_DIR


class LelSploit:
    def __init__(self, dll_dir: str | Path | None = None):
        # Native code is intentionally restricted to the persistent AppData
        # directory. A caller cannot redirect DLL loading back to the EXE or
        # Nuitka onefile extraction directory.
        if dll_dir is not None and Path(dll_dir).expanduser().resolve() != DLL_DIR:
            raise ValueError(f"LelSploit DLLs must be loaded from {DLL_DIR}")
        self.dll_dir = ensure_appdata_dlls()

        # Keep cwd at the DLL directory. Some native runtimes create files using
        # relative paths after Attach/Execute returns or from background threads.
        # Restoring the original cwd would make those files appear beside the EXE.
        os.chdir(self.dll_dir)

        self._libraries: list[ctypes.CDLL] = []
        self._engine = None
        self._lock = threading.RLock()
        self.Drawing = _DrawingAPI(self)

    def initialize(self) -> None:
        with self._lock:
            if self._engine is not None:
                return

            if os.name != "nt" or struct.calcsize("P") != 8:
                raise RuntimeError("LelSploit requires 64-bit Python on Windows")

            missing = [
                name
                for name in REQUIRED_FILES
                if not (self.dll_dir / name).is_file()
            ]

            if missing:
                raise FileNotFoundError(
                    "Missing DLL file(s) in "
                    f"{self.dll_dir}: {', '.join(missing)}"
                )

            search_flags = 0x00000100 | 0x00000800
            try:
                os.chdir(self.dll_dir)

                for name in REQUIRED_FILES:
                    dll = ctypes.CDLL(
                        str(self.dll_dir / name),
                        winmode=search_flags,
                    )
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
                raise RuntimeError(f"Failed to initialize LelSploit: {exc}") from exc


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
            raise TypeError("lua_script must be a string")

        if "\0" in lua_script:
            raise ValueError("lua_script cannot contain a NUL character")

        engine = self._engine_or_initialize()

        if not self.is_attached():
            raise RuntimeError("LelSploit is not attached")

        buffer = ctypes.create_string_buffer(lua_script.encode("utf-8"))

        with self._lock:
            engine.Execute(buffer)

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
        key = f"ref_{uuid.uuid4().hex}"
        self.execute(
            f'''local g=getgenv()
g.__PY_API_REFS=g.__PY_API_REFS or {{}}
g.__PY_API_REFS[{_lua_string(key)}]=({expression})'''
        )
        return LuaReference(self, key)

    def set_fps_cap(self, cap: int | float) -> None:
        self.execute(f"setfpscap({_lua_value(cap)})")

    setfpscap = set_fps_cap

    def hookfunction(
        self,
        old_function: LuaExpr,
        hook_function: LuaExpr,
    ) -> LuaReference:
        if not isinstance(old_function, LuaExpr):
            raise TypeError("old_function must be api.lua(...) or a LuaReference")
        if not isinstance(hook_function, LuaExpr):
            raise TypeError("hook_function must be api.lua(...) or a LuaReference")

        return self._store_expression(
            f"hookfunction(({old_function.source}), ({hook_function.source}))"
        )

    def MouseMoveRel(self, x: int, y: int) -> None:
        self.execute(f"mousemoverel({int(x)}, {int(y)})")

    mousemoverel = MouseMoveRel
    MouseMoveRelative = MouseMoveRel
    mousemoverelative = MouseMoveRel

    def MouseScroll(self, y: int) -> None:
        self.execute(f"mousescroll({int(y)})")

    mousescroll = MouseScroll

    def MouseButton1Click(self) -> None:
        self.execute("mouse1click()")

    def MouseButton1Press(self) -> None:
        self.execute("mouse1press()")

    def MouseButton1Release(self) -> None:
        self.execute("mouse1release()")

    def MouseButton2Click(self) -> None:
        self.execute("mouse2click()")

    def MouseButton2Press(self) -> None:
        self.execute("mouse2press()")

    def MouseButton2Release(self) -> None:
        self.execute("mouse2release()")

    def KeyPress(self, key: int) -> None:
        self.execute(f"keypress({int(key)})")

    keypress = KeyPress

    def KeyRelease(self, key: int) -> None:
        self.execute(f"keyrelease({int(key)})")

    keyrelease = KeyRelease

    def MouseMoveAbs(self, x: int, y: int) -> None:
        self.execute(f"mousemoveabs({int(x)}, {int(y)})")

    mousemoveabs = MouseMoveAbs

    def rconsoleprint(self, text: Any) -> None:
        self.execute(f"rconsoleprint({_lua_value(str(text))})")

    def rconsolewarn(self, text: Any) -> None:
        self.execute(f"rconsolewarn({_lua_value(str(text))})")

    def rconsoleerr(self, text: Any) -> None:
        self.execute(f"rconsoleerror({_lua_value(str(text))})")

    rconsoleerror = rconsoleerr

    def rconsolename(self, text: str) -> None:
        self.execute(f"rconsolename({_lua_string(str(text))})")

    def rconsoleclear(self) -> None:
        self.execute("rconsoleclear()")

    def rconsolecreate(self) -> None:
        self.execute("rconsolecreate()")

    def rconsoledestroy(self) -> None:
        self.execute("rconsoledestroy()")

    def HttpGet(self, url: str) -> LuaReference:
        if not isinstance(url, str):
            raise TypeError("url must be a string")

        return self._store_expression(
            f"game:HttpGet({_lua_string(url)})"
        )

    httpget = HttpGet

    @staticmethod
    def Vector2(x: float, y: float) -> LuaExpr:
        return LuaExpr(f"Vector2.new({float(x)!r}, {float(y)!r})")

    @staticmethod
    def Color3(r: float, g: float, b: float) -> LuaExpr:
        return LuaExpr(
            f"Color3.new({float(r)!r}, {float(g)!r}, {float(b)!r})"
        )

    def SendLuaCScript(self, lua_c_script: str) -> None:
        if not isinstance(lua_c_script, str):
            raise TypeError("lua_c_script must be a string")

        operations = self._parse_lua_c(lua_c_script)
        generated = self._build_lua_c_runtime(operations)
        self.execute(generated)

    send_lua_c_script = SendLuaCScript

    @staticmethod
    def _parse_lua_c(source: str) -> list[tuple[str, list[str]]]:
        operations: list[tuple[str, list[str]]] = []

        for line_number, raw_line in enumerate(source.splitlines(), 1):
            line = raw_line.strip()

            if not line:
                continue

            op, _, rest = line.partition(" ")
            op = op.lower()
            rest = rest.strip()

            if op == "pushstring":
                operations.append((op, [rest]))
                continue

            try:
                args = shlex.split(rest, posix=True) if rest else []
            except ValueError as exc:
                raise ValueError(
                    f"Invalid Lua-C parser syntax on line {line_number}: {exc}"
                ) from exc

            operations.append((op, args))

        return operations

    @staticmethod
    def _build_lua_c_runtime(
        operations: list[tuple[str, list[str]]],
    ) -> str:
        lines = [
            "local __NIL={}",
            "local __S={n=0}",
            "local function __box(v) if v==nil then return __NIL end return v end",
            "local function __unbox(v) if v==__NIL then return nil end return v end",
            "local function __push(v) __S.n=__S.n+1 __S[__S.n]=__box(v) end",
            "local function __pop() if __S.n<=0 then return nil end local v=__S[__S.n] __S[__S.n]=nil __S.n=__S.n-1 return __unbox(v) end",
            "local function __idx(i) if i<0 then return __S.n+i+1 end return i end",
            "local function __get(i) return __unbox(__S[__idx(i)]) end",
            "local function __settop(i)",
            "  local t=i",
            "  if i<0 then t=__S.n+i+1 end",
            "  if t<0 then t=0 end",
            "  while __S.n>t do __S[__S.n]=nil __S.n=__S.n-1 end",
            "  while __S.n<t do __push(nil) end",
            "end",
            "local function __call(nargs,nresults,protected)",
            "  local fnindex=__S.n-nargs",
            "  local fn=__get(fnindex)",
            "  local args={}",
            "  for i=1,nargs do args[i]=__get(fnindex+i) end",
            "  __settop(fnindex-1)",
            "  local results",
            "  if protected then",
            "    results=table.pack(pcall(fn,table.unpack(args,1,nargs)))",
            "    local ok=results[1]",
            "    if not ok then __push(results[2]) return end",
            "    local count=results.n-1",
            "    if nresults<0 then nresults=count end",
            "    for i=1,nresults do __push(results[i+1]) end",
            "  else",
            "    results=table.pack(fn(table.unpack(args,1,nargs)))",
            "    local count=results.n",
            "    if nresults<0 then nresults=count end",
            "    for i=1,nresults do __push(results[i]) end",
            "  end",
            "end",
            "local function __global(name)",
            "  local g=getgenv and getgenv() or _G",
            "  local v=g and g[name]",
            "  if v==nil and getrenv then local r=getrenv() v=r and r[name] end",
            "  return v",
            "end",
        ]

        def need(op: str, args: list[str], count: int) -> None:
            if len(args) != count:
                raise ValueError(
                    f"{op} expects {count} argument(s), got {len(args)}"
                )

        for op, args in operations:
            if op == "getglobal":
                need(op, args, 1)
                lines.append(f"__push(__global({_lua_string(args[0])}))")

            elif op == "getfield":
                need(op, args, 2)
                index = int(args[0])
                lines.append(
                    f"do local t=__get({index}) __push(t[{_lua_string(args[1])}]) end"
                )

            elif op == "setfield":
                need(op, args, 2)
                index = int(args[0])
                lines.append(
                    f"do local v=__pop() local t=__get({index}) t[{_lua_string(args[1])}]=v end"
                )

            elif op == "pushvalue":
                need(op, args, 1)
                lines.append(f"__push(__get({int(args[0])}))")

            elif op == "pushstring":
                need(op, args, 1)
                lines.append(f"__push({_lua_string(args[0])})")

            elif op == "pushnumber":
                need(op, args, 1)
                number = float(args[0])
                lines.append(f"__push({number!r})")

            elif op == "pushboolean":
                need(op, args, 1)
                value = args[0].lower()
                if value not in {"true", "false", "1", "0"}:
                    raise ValueError("pushboolean expects true/false or 1/0")
                lua_bool = "true" if value in {"true", "1"} else "false"
                lines.append(f"__push({lua_bool})")

            elif op == "pushnil":
                need(op, args, 0)
                lines.append("__push(nil)")

            elif op == "pcall":
                need(op, args, 3)
                nargs = int(args[0])
                nresults = int(args[1])
                int(args[2])
                lines.append(f"__call({nargs},{nresults},true)")

            elif op == "call":
                need(op, args, 2)
                lines.append(
                    f"__call({int(args[0])},{int(args[1])},false)"
                )

            elif op == "emptystack":
                need(op, args, 0)
                lines.append("__settop(0)")

            elif op == "settop":
                need(op, args, 1)
                lines.append(f"__settop({int(args[0])})")

            elif op == "gettop":
                need(op, args, 0)
                lines.append("print(__S.n)")

            elif op == "pop":
                need(op, args, 1)
                lines.append(
                    f"for _=1,{max(0, int(args[0]))} do __pop() end"
                )

            elif op == "insert":
                need(op, args, 1)
                index = int(args[0])
                lines.extend([
                    "do",
                    "  local top=__pop()",
                    f"  local target=__idx({index})",
                    "  if target<1 then target=1 end",
                    "  __S.n=__S.n+1",
                    "  for i=__S.n,target+1,-1 do __S[i]=__S[i-1] end",
                    "  __S[target]=__box(top)",
                    "end",
                ])

            elif op == "createtable":
                need(op, args, 2)
                int(args[0])
                int(args[1])
                lines.append("__push({})")

            elif op == "settable":
                need(op, args, 1)
                index = int(args[0])
                lines.append(
                    f"do local v=__pop() local k=__pop() local t=__get({index}) t[k]=v end"
                )

            elif op == "next":
                need(op, args, 1)
                index = int(args[0])
                lines.extend([
                    "do",
                    "  local key=__pop()",
                    f"  local t=__get({index})",
                    "  local nk,nv=next(t,key)",
                    "  if nk~=nil then __push(nk) __push(nv) end",
                    "end",
                ])

            elif op == "tonumber":
                need(op, args, 1)
                lines.append(f"print(tonumber(__get({int(args[0])})))")

            elif op == "tostring":
                need(op, args, 1)
                lines.append(f"print(tostring(__get({int(args[0])})))")

            elif op == "touserdata":
                need(op, args, 1)
                lines.append(f"print(tostring(__get({int(args[0])})))")

            else:
                raise ValueError(f"Unsupported Lua-C parser command: {op}")

        return "\n".join(lines)


API = LelSploit
ExploitAPI = LelSploit
