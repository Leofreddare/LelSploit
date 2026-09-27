from __future__ import annotations

import copy
import ctypes
import hashlib
import json
import os
import queue
import re
import threading
import time
import urllib.parse
from pathlib import Path

from PyQt6.QtCore import Qt, QTimer, QSize, QObject, pyqtSignal, QMimeData, QPropertyAnimation, QVariantAnimation, QEasingCurve, QRectF, QEvent
from PyQt6.QtGui import QIcon, QColor, QBrush, QDrag, QPixmap, QPen, QPainter
from PyQt6.QtWidgets import (
    QAbstractItemView,
    QAbstractSpinBox,
    QStyledItemDelegate,
    QStyle,
    QStyleOptionViewItem,
    QButtonGroup,
    QComboBox,
    QCheckBox,
    QDialog,
    QFileDialog,
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QHeaderView,
    QLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMessageBox,
    QPushButton,
    QPlainTextEdit,
    QScrollArea,
    QSpinBox,
    QSplitter,
    QStackedWidget,
    QTreeWidget,
    QTreeWidgetItem,
    QVBoxLayout,
    QWidget,
)

import lelsploit_extensions as _market
from lelsploit_native_input import NativeInput, blocked_keys
import lelsploit_macro_actions as _macro_actions

_HOST = {}
_NATIVE_RUN_LOCK = threading.Lock()
RUNTIME_DIR = Path(__file__).resolve().parent
_APPDATA_ROOT = os.environ.get("APPDATA")
BASE_DIR = (
    (Path(_APPDATA_ROOT).expanduser().resolve() / "LelSploit")
    if _APPDATA_ROOT
    else (Path.home() / "AppData" / "Roaming" / "LelSploit").resolve()
)
MACROS_DIR = BASE_DIR / "lelsploit_macros"
MACRO_FORMAT_VERSION = 1
MACRO_FILE_LIMIT = 512 * 1024
MACRO_MAX_STEPS = 1000
MACRO_MAX_REPEAT = 100
MACRO_MAX_DEPTH = 6
MACRO_MAX_WAIT_MS = 60_000
MACRO_MAX_TOTAL_WAIT_MS = 10 * 60_000
MARKETPLACE_DEFAULT_API = "https://marketplace.lelsploit.workers.dev"
marketplace_request = _market.marketplace_request
MarketplaceAccountDialog = _market.MarketplaceAccountDialog


def configure_host(namespace):
    if not namespace:
        return
    clean = {str(k): v for k, v in namespace.items() if not str(k).startswith("__")}
    _HOST.clear()
    _HOST.update(clean)
    globals().update(clean)


def _file_icon(filename, fallback=""):
    path = ICON_DIR / filename
    if path.is_file():
        icon = QIcon(str(path))
        if not icon.isNull():
            return icon
    if fallback:
        try:
            icon = app_icon(fallback)
            if not icon.isNull():
                return icon
        except Exception:
            pass
    return QIcon()


def _macro_icon():
    return _file_icon("macros.png", "macro")


# Virtual-key whitelist intentionally excludes Win/Meta keys (0x5B/0x5C).
_KEY_CODES = {
    **{chr(code): code for code in range(ord("A"), ord("Z") + 1)},
    **{str(n): 0x30 + n for n in range(10)},
    **{f"F{n}": 0x6F + n for n in range(1, 13)},
    "BACKSPACE": 0x08,
    "TAB": 0x09,
    "ENTER": 0x0D,
    "SHIFT": 0x10,
    "CTRL": 0x11,
    "CONTROL": 0x11,
    "ALT": 0x12,
    "PAUSE": 0x13,
    "CAPSLOCK": 0x14,
    "ESC": 0x1B,
    "ESCAPE": 0x1B,
    "SPACE": 0x20,
    "PAGEUP": 0x21,
    "PAGEDOWN": 0x22,
    "END": 0x23,
    "HOME": 0x24,
    "LEFT": 0x25,
    "UP": 0x26,
    "RIGHT": 0x27,
    "DOWN": 0x28,
    "INSERT": 0x2D,
    "DELETE": 0x2E,
    "NUM0": 0x60,
    "NUM1": 0x61,
    "NUM2": 0x62,
    "NUM3": 0x63,
    "NUM4": 0x64,
    "NUM5": 0x65,
    "NUM6": 0x66,
    "NUM7": 0x67,
    "NUM8": 0x68,
    "NUM9": 0x69,
    "NUM*": 0x6A,
    "NUM+": 0x6B,
    "NUM-": 0x6D,
    "NUM.": 0x6E,
    "NUM/": 0x6F,
    ";": 0xBA,
    "=": 0xBB,
    ",": 0xBC,
    "-": 0xBD,
    ".": 0xBE,
    "/": 0xBF,
    "`": 0xC0,
    "[": 0xDB,
    "\\": 0xDC,
    "]": 0xDD,
    "'": 0xDE,
}
_FORBIDDEN_KEY_NAMES = {
    "WIN",
    "WINDOWS",
    "META",
    "SUPER",
    "LWIN",
    "RWIN",
    "CMD",
    "COMMAND",
}
_KEY_CHOICES = [
    "SPACE",
    "ENTER",
    "TAB",
    "ESC",
    "SHIFT",
    "CTRL",
    "ALT",
    "UP",
    "DOWN",
    "LEFT",
    "RIGHT",
    "HOME",
    "END",
    "PAGEUP",
    "PAGEDOWN",
    "INSERT",
    "DELETE",
    *[chr(c) for c in range(ord("A"), ord("Z") + 1)],
    *[str(n) for n in range(10)],
    *[f"F{n}" for n in range(1, 13)],
    *[f"NUM{n}" for n in range(10)],
    "NUM+",
    "NUM-",
    "NUM*",
    "NUM/",
    ";",
    "=",
    ",",
    "-",
    ".",
    "/",
    "`",
    "[",
    "]",
    "\\",
    "'",
]

_STOP_HOTKEY_CHOICES = ["F6", "F7", "F8", "F9", "F10", "F11", "F12", "PAUSE", "ESC"]
_CONTAINER_OPS = {"repeat", "forever"}


def _settings_value(owner, key, default=None):
    settings = getattr(owner, "settings", None)
    if settings is None:
        return default
    try:
        return settings.value(key, default)
    except Exception:
        return default


def _settings_set(owner, key, value):
    settings = getattr(owner, "settings", None)
    if settings is None:
        return
    try:
        settings.setValue(key, value)
        settings.sync()
    except Exception:
        pass


def _macro_hotkeys(owner):
    raw = _settings_value(owner, "macros/hotkeys", {})
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except ValueError:
            raw = {}
    return {str(k): str(v) for k, v in raw.items() if v} if isinstance(raw, dict) else {}


_MACRO_HOTKEY_CHOICES = ["None"] + [prefix + key for prefix in ("", "CTRL+", "ALT+", "SHIFT+") for key in [f"F{i}" for i in range(1, 13)]]


def hotkey_parts(value):
    value = str(value).upper()
    parts = []
    while any(value.startswith(prefix + "+") for prefix in ("CTRL", "ALT", "SHIFT")):
        modifier, value = value.split("+", 1)
        parts.append(modifier)
    if value not in _KEY_CODES or len(parts) != len(set(parts)):
        raise ValueError("Unsupported hotkey.")
    return parts + [value]


class IssueStatusLabel(QLabel):
    def __init__(self, text="", parent=None):
        super().__init__(parent)
        self.setText("" if text.startswith("Loading") else text)

    def setText(self, text):
        super().setText(text)
        self.setVisible(bool(text))


class KeyRecorderDialog(QDialog):
    def __init__(self, title, current, chords, allow_clear, parent=None):
        super().__init__(parent)
        self.value = current
        self.chords = chords
        self.setWindowTitle(title)
        self.setMinimumWidth(360)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        layout = QVBoxLayout(self)
        layout.addWidget(QLabel("Press your hotkey, then click Use." if chords else "Press a key, then click Use."))
        self.preview = QLabel(str(current or "Waiting for a key…"))
        layout.addWidget(self.preview)
        self.message = QLabel("")
        self.message.setWordWrap(True)
        layout.addWidget(self.message)
        row = QHBoxLayout()
        self.use = QPushButton("Use")
        self.use.setEnabled(False)
        self.use.clicked.connect(self.accept)
        cancel = QPushButton("Cancel")
        cancel.clicked.connect(self.reject)
        buttons = [self.use, cancel]
        if allow_clear:
            clear = QPushButton("Clear hotkey")
            clear.clicked.connect(self.clear_key)
            buttons.insert(0, clear)
        for button in buttons:
            button.setAutoDefault(False)
            button.setFocusPolicy(Qt.FocusPolicy.NoFocus)
            row.addWidget(button)
        layout.addLayout(row)

    def clear_key(self):
        self.value = "None"
        self.accept()

    def event(self, event):
        if event.type() == QEvent.Type.KeyPress:
            self.keyPressEvent(event)
            return True
        return super().event(event)

    def keyPressEvent(self, event):
        event.accept()
        if event.isAutoRepeat():
            return
        self.use.setEnabled(False)
        if event.modifiers() & Qt.KeyboardModifier.MetaModifier:
            self.message.setText("Windows/Meta keys are not allowed.")
            return
        vk = int(event.nativeVirtualKey())
        vk = {160:16,161:16,162:17,163:17,164:18,165:18}.get(vk,vk)
        name = next((name for name, code in _KEY_CODES.items() if code == vk), None)
        if name is None:
            key = int(event.key())
            if 65 <= key <= 90 or 48 <= key <= 57:
                name = chr(key)
            else:
                mapping = {Qt.Key.Key_Space:"SPACE",Qt.Key.Key_Return:"ENTER",Qt.Key.Key_Enter:"ENTER",
                    Qt.Key.Key_Escape:"ESC",Qt.Key.Key_Tab:"TAB",Qt.Key.Key_Backspace:"BACKSPACE",
                    Qt.Key.Key_Delete:"DELETE",Qt.Key.Key_Insert:"INSERT",Qt.Key.Key_Left:"LEFT",
                    Qt.Key.Key_Right:"RIGHT",Qt.Key.Key_Up:"UP",Qt.Key.Key_Down:"DOWN",
                    Qt.Key.Key_Home:"HOME",Qt.Key.Key_End:"END",Qt.Key.Key_PageUp:"PAGEUP",Qt.Key.Key_PageDown:"PAGEDOWN",
                    Qt.Key.Key_Control:"CTRL",Qt.Key.Key_Shift:"SHIFT",Qt.Key.Key_Alt:"ALT"}
                mapping.update({getattr(Qt.Key, f"Key_F{i}"):f"F{i}" for i in range(1,13)})
                name = mapping.get(key)
        if name is None:
            self.message.setText("That key is not on the allowed key list.")
            return
        modifiers = [name for flag,name in ((Qt.KeyboardModifier.ControlModifier,"CTRL"),(Qt.KeyboardModifier.AltModifier,"ALT"),(Qt.KeyboardModifier.ShiftModifier,"SHIFT")) if event.modifiers() & flag]
        if self.chords and name in ("CTRL","ALT","SHIFT"):
            self.message.setText("Keep the modifier held and press the main key.")
            return
        names = modifiers + [name] if self.chords else [name]
        if blocked_keys({_KEY_CODES[k] for k in names}):
            self.message.setText("That system shortcut is blocked.")
            return
        self.value = "+".join(names)
        self.preview.setText(self.value)
        self.message.setText("")
        self.use.setEnabled(True)


def record_key(parent, owner, title, current="", chords=False, allow_clear=False):
    owner._macro_recording = True
    window = getattr(owner, "macros_window", None)
    if window is not None:
        window.stop_running_macro()
    try:
        dialog = KeyRecorderDialog(title, current, chords, allow_clear, parent)
        ok = dialog.exec() == QDialog.DialogCode.Accepted
        return dialog.value, ok
    finally:
        owner._macro_recording = False


class MacroStopHotkeyService(QObject):
    """Host-only emergency stop key. It reads physical key state and never injects input."""
    activated = pyqtSignal()
    macroActivated = pyqtSignal(str)

    def __init__(self, owner, parent=None):
        super().__init__(parent)
        self.owner = owner
        self.key_name = "F8"
        self.vk = _KEY_CODES["F8"]
        self.was_down = False
        self.macro_down = {}
        self.timer = QTimer(self)
        self.timer.setInterval(25)
        self.timer.timeout.connect(self._poll)
        self.set_key(str(_settings_value(owner, "macros/stop_hotkey", "F8") or "F8"))
        if os.name == "nt":
            self.timer.start()

    def set_key(self, name):
        value = str(name or "F8").strip().upper()
        if value not in _KEY_CODES:
            value = "F8"
        self.key_name = value
        self.vk = _KEY_CODES[value]
        self.was_down = False
        _settings_set(self.owner, "macros/stop_hotkey", value)

    def _poll(self):
        if getattr(self.owner, "_macro_recording", False):
            return
        try:
            down = bool(ctypes.windll.user32.GetAsyncKeyState(int(self.vk)) & 0x8000)
        except Exception:
            return
        if down and not self.was_down:
            self.activated.emit()
        self.was_down = down
        bindings = _macro_hotkeys(self.owner)
        for macro_id, chord in bindings.items():
            try:
                names = hotkey_parts(chord)
            except ValueError:
                continue
            if self.key_name in names:
                self.macro_down[macro_id] = False
                continue
            try:
                pressed = all(bool(ctypes.windll.user32.GetAsyncKeyState(_KEY_CODES[name]) & 0x8000) for name in names)
                pressed = pressed and all(bool(ctypes.windll.user32.GetAsyncKeyState(_KEY_CODES[modifier]) & 0x8000) == (modifier in names) for modifier in ("CTRL", "ALT", "SHIFT"))
                pressed = pressed and not any(ctypes.windll.user32.GetAsyncKeyState(vk) & 0x8000 for vk in (0x5B, 0x5C))
            except (KeyError, AttributeError, OSError):
                pressed = False
            before = self.macro_down.get(macro_id, False)
            self.macro_down[macro_id] = pressed
            if pressed and not before and not down:
                self.macroActivated.emit(macro_id)
        self.macro_down = {key: value for key, value in self.macro_down.items() if key in bindings}


def key_code(value):
    name = str(value or "").strip().upper().replace(" ", "")
    if name in _FORBIDDEN_KEY_NAMES:
        raise ValueError("Windows/Meta keys are not allowed in LelSploit macros.")
    if name not in _KEY_CODES:
        raise ValueError(f"Unsupported macro key: {value!r}")
    return _KEY_CODES[name]


def _validate_steps(steps, depth=0, counter=None, waits=None):
    if counter is None:
        counter = [0]
    if waits is None:
        waits = [0]
    if depth > MACRO_MAX_DEPTH:
        raise ValueError("Macro nesting is too deep.")
    if not isinstance(steps, list):
        raise ValueError("steps must be a JSON array.")
    clean = []
    for raw in steps:
        counter[0] += 1
        if counter[0] > MACRO_MAX_STEPS:
            raise ValueError(f"Macros are limited to {MACRO_MAX_STEPS} steps.")
        if not isinstance(raw, dict):
            raise ValueError("Every macro step must be an object.")
        op = str(raw.get("op") or "").strip().lower()
        if op in {"key_down", "key_up", "tap"}:
            key = str(raw.get("key") or "").strip()
            key_code(key)
            item = {"op": op, "key": key.upper()}
            if op == "tap":
                duration = int(raw.get("duration_ms", 35) or 35)
                if not 0 <= duration <= 5000:
                    raise ValueError("tap.duration_ms must be between 0 and 5000.")
                item["duration_ms"] = duration
            clean.append(item)
        elif op == "wait":
            ms = int(raw.get("ms", 0) or 0)
            if not 0 <= ms <= MACRO_MAX_WAIT_MS:
                raise ValueError(f"wait.ms must be between 0 and {MACRO_MAX_WAIT_MS}.")
            waits[0] += ms
            if waits[0] > MACRO_MAX_TOTAL_WAIT_MS:
                raise ValueError("Macro contains too much total wait time.")
            clean.append({"op": "wait", "ms": ms})
        elif op in {
            "mouse1_click",
            "mouse1_down",
            "mouse1_up",
            "mouse2_click",
            "mouse2_down",
            "mouse2_up",
        }:
            clean.append({"op": op})
        elif op == "mouse_move":
            x = int(raw.get("x", 0) or 0)
            y = int(raw.get("y", 0) or 0)
            if abs(x) > 10000 or abs(y) > 10000:
                raise ValueError("mouse_move x/y are limited to +/-10000.")
            clean.append({"op": op, "x": x, "y": y})
        elif op == "mouse_scroll":
            amount = int(raw.get("amount", 0) or 0)
            if abs(amount) > 10000:
                raise ValueError("mouse_scroll amount is limited to +/-10000.")
            clean.append({"op": op, "amount": amount})
        elif op == "repeat":
            times = int(raw.get("times", 1) or 1)
            if not 1 <= times <= MACRO_MAX_REPEAT:
                raise ValueError(f"repeat.times must be between 1 and {MACRO_MAX_REPEAT}.")
            nested = _validate_steps(raw.get("steps", []), depth + 1, counter, waits)
            clean.append({"op": "repeat", "times": times, "steps": nested})
        elif op == "forever":
            nested = _validate_steps(raw.get("steps", []), depth + 1, counter, waits)
            if not nested:
                raise ValueError("forever must contain at least one nested block.")
            clean.append({"op": "forever", "steps": nested})
        elif op in _macro_actions.SCHEMA:
            clean.append(_macro_actions.validate_action(raw))
        else:
            raise ValueError(f"Unsupported macro operation: {op or '<missing>'}.")
    return clean


def validate_macro(payload):
    if not isinstance(payload, dict):
        raise ValueError("Macro file must contain one JSON object.")
    if int(payload.get("format", 0) or 0) != MACRO_FORMAT_VERSION:
        raise ValueError(f"Unsupported macro format. Expected format {MACRO_FORMAT_VERSION}.")
    macro_id = str(payload.get("id") or "").strip()
    if not re.fullmatch(r"[a-z0-9][a-z0-9._-]{1,63}", macro_id):
        raise ValueError("id must be 2-64 lowercase letters, numbers, '.', '_' or '-'.")
    name = str(payload.get("name") or "").strip()
    if not name or len(name) > 80:
        raise ValueError("name is required and limited to 80 characters.")
    version = str(payload.get("version") or "1.0").strip()[:32]
    description = str(payload.get("description") or "").strip()[:1000]
    steps = _validate_steps(payload.get("steps", []))
    return {
        "format": 1,
        "id": macro_id,
        "name": name,
        "version": version,
        "description": description,
        "steps": steps,
    }


def read_macro(path):
    path = Path(path)
    if path.stat().st_size > MACRO_FILE_LIMIT:
        raise ValueError("Macro files are limited to 512 KiB.")
    return validate_macro(json.loads(path.read_text("utf-8-sig")))


def write_macro(path, payload):
    clean = validate_macro(payload)
    Path(path).write_text(json.dumps(clean, indent=2, ensure_ascii=False) + "\n", "utf-8")
    return clean


def installed_macros():
    MACROS_DIR.mkdir(parents=True, exist_ok=True)
    rows = []
    for path in sorted(MACROS_DIR.glob("*.lmacro"), key=lambda p: p.name.casefold()):
        try:
            item = read_macro(path)
            item["_path"] = str(path)
            rows.append(item)
        except Exception:
            continue
    return rows


class MacroRunner(QObject):
    finished = pyqtSignal(object)
    hostRequested = pyqtSignal(object)

    def __init__(self, owner):
        super().__init__(owner)
        self.owner = owner
        self.stop_event = threading.Event()
        self.thread = None
        self._done = None
        self.finished.connect(self._finish)
        self.host_actions = _macro_actions.HostActions(owner, _HOST)
        self.hostRequested.connect(self._run_host_request)

    def _run_host_request(self, request):
        try:
            if request['cancel'].is_set() and request['step']['op'] not in {'_script_cancel', '_resources_changed'}:
                raise RuntimeError('Macro stopped.')
            request['result'] = self.host_actions.run(request['step'])
            if request['cancel'].is_set() and request['step']['op'] == 'script_execute':
                self.host_actions.run({'op': '_script_cancel'})
        except Exception as exc:
            request['error'] = exc
        finally:
            request['done'].set()

    def _call_host(self, step, cleanup=False):
        request = {'step': step, 'done': threading.Event(), 'cancel': self.stop_event}
        self.hostRequested.emit(request)
        while not request['done'].wait(0.05):
            if self.stop_event.is_set() and not cleanup:
                raise RuntimeError('Macro stopped.')
        if 'error' in request:
            raise request['error']
        return request.get('result')

    def _finish(self, error):
        callback, self._done = self._done, None
        if callback is not None:
            callback(error)

    @property
    def running(self):
        return bool(self.thread and self.thread.is_alive())

    def stop(self):
        self.stop_event.set()

    def start(self, macro, on_done):
        if self.running:
            raise RuntimeError("A macro is already running.")
        clean = validate_macro(macro)
        def has_input(steps):
            return any(step['op'] in {'tap', 'key_down', 'key_up'} or step['op'].startswith('mouse')
                       or has_input(step.get('steps', [])) for step in steps)
        needs_input = has_input(clean['steps'])
        if needs_input and os.name != 'nt':
            raise RuntimeError('Native macro input requires Windows.')
        stop_key = str(_settings_value(self.owner, 'macros/stop_hotkey', 'F8') or 'F8')
        if not _NATIVE_RUN_LOCK.acquire(blocking=False):
            raise RuntimeError("Another macro is already running.")
        self.stop_event.clear()
        self._done = on_done

        def worker():
            error = None
            api = None
            try:
                if needs_input:
                    self._sleep(2000)
                    api = NativeInput(self.stop_event, reserved_keys=[key_code(stop_key)])
                self._run_steps(api, clean["steps"])
            except Exception as exc:
                error = str(exc)
            finally:
                if api is not None:
                    try:
                        api.release_all()
                    except Exception as exc:
                        error = str(exc)
                try:
                    self._call_host({'op': '_script_cancel'}, cleanup=True)
                except Exception:
                    pass
                _NATIVE_RUN_LOCK.release()
                self.finished.emit(error)

        self.thread = threading.Thread(target=worker, daemon=True, name="LelSploitMacro")
        try:
            self.thread.start()
        except Exception:
            _NATIVE_RUN_LOCK.release()
            raise

    def _sleep(self, ms):
        self.stop_event.wait(max(0, int(ms)) / 1000.0)
        if self.stop_event.is_set():
            raise RuntimeError("Macro stopped.")

    def _run_steps(self, api, steps):
        for step in steps:
            self._sleep(5)
            if self.stop_event.is_set():
                raise RuntimeError("Macro stopped.")
            op = step["op"]
            if op == "key_down":
                api.KeyPress(key_code(step["key"]))
            elif op == "key_up":
                api.KeyRelease(key_code(step["key"]))
            elif op == "tap":
                code = key_code(step["key"])
                api.KeyPress(code)
                self._sleep(step.get("duration_ms", 35))
                api.KeyRelease(code)
            elif op == "wait":
                self._sleep(step["ms"])
            elif op == "mouse1_click":
                api.MouseButton1Click()
            elif op == "mouse1_down":
                api.MouseButton1Press()
            elif op == "mouse1_up":
                api.MouseButton1Release()
            elif op == "mouse2_click":
                api.MouseButton2Click()
            elif op == "mouse2_down":
                api.MouseButton2Press()
            elif op == "mouse2_up":
                api.MouseButton2Release()
            elif op == "mouse_move":
                api.MouseMoveRel(step["x"], step["y"])
            elif op == "mouse_scroll":
                api.MouseScroll(step["amount"])
            elif op in _macro_actions.SCHEMA:
                if op.startswith(('asset_', 'custom_', 'skybox_')) and op != 'custom_flag_enabled':
                    try:
                        _macro_actions.apply_resource_action(step, _HOST)
                    finally:
                        self._call_host({'op': '_resources_changed'}, cleanup=True)
                else:
                    self._call_host(step)
                    if op == 'script_execute':
                        deadline = time.monotonic() + 180
                        while not self._call_host({'op': '_script_status'}):
                            if time.monotonic() > deadline:
                                raise RuntimeError('Timed out waiting for the script runner.')
                            self._sleep(50)
            elif op == "repeat":
                for _ in range(step["times"]):
                    self._run_steps(api, step["steps"])
            elif op == "forever":
                while not self.stop_event.is_set():
                    self._run_steps(api, step["steps"])


# ---------------------------------------------------------------------------
# Scratch-like no-code builder
# ---------------------------------------------------------------------------


def _builder_icon(category):
    name = str(category or "").strip().lower()
    path = ICON_DIR / "builder" / f"{name}.png"
    if path.is_file():
        icon = QIcon(str(path))
        if not icon.isNull():
            return icon
    return QIcon()


def _slug_from_name(value):
    slug = re.sub(r"[^a-z0-9._-]+", "-", str(value or "").strip().lower()).strip("-._")
    if len(slug) < 2:
        slug = (slug + "-macro").strip("-") if slug else "my-macro"
    return slug[:64]


MACRO_TEMPLATES = (
    {
        "id": "autoclicker",
        "name": "Auto Clicker",
        "version": "1.0",
        "description": "Clicks repeatedly with a short delay.",
        "steps": [{"op": "forever", "steps": [{"op": "mouse1_click"}, {"op": "wait", "ms": 100}]}],
    },
    {
        "id": "space-spammer",
        "name": "Space Spammer",
        "version": "1.0",
        "description": "Taps Space repeatedly.",
        "steps": [{"op": "repeat", "times": 40, "steps": [{"op": "tap", "key": "SPACE", "duration_ms": 35}, {"op": "wait", "ms": 110}]}],
    },
    {
        "id": "forward-burst",
        "name": "Forward Burst",
        "version": "1.0",
        "description": "Holds W briefly, then releases it.",
        "steps": [{"op": "key_down", "key": "W"}, {"op": "wait", "ms": 850}, {"op": "key_up", "key": "W"}],
    },
    {
        "id": "scroll-pulse",
        "name": "Scroll Pulse",
        "version": "1.0",
        "description": "Scrolls repeatedly in short pulses.",
        "steps": [{"op": "repeat", "times": 8, "steps": [{"op": "mouse_scroll", "amount": 120}, {"op": "wait", "ms": 120}]}],
    },
)

BLOCK_MIME = "application/x-lelsploit-macro-block"

BLOCK_DEFS = {
    "tap": {
        "label": "Tap key",
        "category": "Keyboard",
        "description": "Press and release one whitelisted key.",
        "template": {"op": "tap", "key": "SPACE", "duration_ms": 35},
    },
    "key_down": {
        "label": "Key down",
        "category": "Keyboard",
        "description": "Hold one whitelisted key down.",
        "template": {"op": "key_down", "key": "W"},
    },
    "key_up": {
        "label": "Key up",
        "category": "Keyboard",
        "description": "Release one whitelisted key.",
        "template": {"op": "key_up", "key": "W"},
    },
    "wait": {
        "label": "Wait",
        "category": "Timing",
        "description": "Pause the macro for a bounded amount of time.",
        "template": {"op": "wait", "ms": 250},
    },
    "mouse1_click": {
        "label": "Left click",
        "category": "Mouse",
        "description": "Click the left mouse button.",
        "template": {"op": "mouse1_click"},
    },
    "mouse1_down": {
        "label": "Left button down",
        "category": "Mouse",
        "description": "Hold the left mouse button.",
        "template": {"op": "mouse1_down"},
    },
    "mouse1_up": {
        "label": "Left button up",
        "category": "Mouse",
        "description": "Release the left mouse button.",
        "template": {"op": "mouse1_up"},
    },
    "mouse2_click": {
        "label": "Right click",
        "category": "Mouse",
        "description": "Click the right mouse button.",
        "template": {"op": "mouse2_click"},
    },
    "mouse2_down": {
        "label": "Right button down",
        "category": "Mouse",
        "description": "Hold the right mouse button.",
        "template": {"op": "mouse2_down"},
    },
    "mouse2_up": {
        "label": "Right button up",
        "category": "Mouse",
        "description": "Release the right mouse button.",
        "template": {"op": "mouse2_up"},
    },
    "mouse_move": {
        "label": "Move mouse",
        "category": "Mouse",
        "description": "Move the mouse by a relative x/y amount.",
        "template": {"op": "mouse_move", "x": 0, "y": 0},
    },
    "mouse_scroll": {
        "label": "Scroll",
        "category": "Mouse",
        "description": "Move the mouse wheel.",
        "template": {"op": "mouse_scroll", "amount": 120},
    },
    "repeat": {
        "label": "Repeat",
        "category": "Control",
        "description": "Repeat nested actions.",
        "template": {"op": "repeat", "times": 3, "steps": []},
    },
    "forever": {
        "label": "Forever",
        "category": "Control",
        "description": "Keep running nested actions until the macro is stopped.",
        "template": {"op": "forever", "steps": []},
    },
}

BLOCK_DEFS.update(_macro_actions.block_definitions())

CATEGORY_COLORS = {
    "Keyboard": QColor("#3569b9"),
    "Timing": QColor("#7651aa"),
    "Mouse": QColor("#218c78"),
    "Control": QColor("#a86a1b"),
    "Scripts": QColor("#487fa1"),
    "FastFlags": QColor("#8b673d"),
    "Username": QColor("#825191"),
    "Assets": QColor("#3c8575"),
    "Customs": QColor("#7077a2"),
}


def _block_definition(op):
    return BLOCK_DEFS.get(str(op or ""), BLOCK_DEFS["wait"])


def _block_summary(data):
    op = str(data.get("op") or "")
    if op == "tap":
        return f"Tap {data.get('key', 'SPACE')}  ·  {int(data.get('duration_ms', 35))} ms"
    if op == "key_down":
        return f"Key down  {data.get('key', 'W')}"
    if op == "key_up":
        return f"Key up  {data.get('key', 'W')}"
    if op == "wait":
        return f"Wait  {int(data.get('ms', 0))} ms"
    if op == "mouse1_click":
        return "Left click"
    if op == "mouse1_down":
        return "Left button down"
    if op == "mouse1_up":
        return "Left button up"
    if op == "mouse2_click":
        return "Right click"
    if op == "mouse2_down":
        return "Right button down"
    if op == "mouse2_up":
        return "Right button up"
    if op == "mouse_move":
        return f"Move mouse  x {int(data.get('x', 0))}  y {int(data.get('y', 0))}"
    if op == "mouse_scroll":
        return f"Scroll  {int(data.get('amount', 0))}"
    if op == "repeat":
        return f"Repeat  {int(data.get('times', 1))} times"
    if op == "forever":
        return "Forever"
    if op in _macro_actions.SCHEMA:
        label = _macro_actions.SCHEMA[op]['label']
        if op == 'fastflags_config':
            detail = _macro_actions.CONFIG.get(data.get('setting'), ('Setting',))[0] + ': ' + str(data.get('value', ''))
        elif op == 'script_execute':
            detail = next(iter(str(data.get('source', '')).splitlines()), '')[:60]
        else:
            detail = str(data.get('name') or data.get('target') or data.get('source') or data.get('enabled', ''))[:70]
        return label + (' · ' + detail if detail else '')
    return op or "Block"


class PaletteActionButton(QPushButton):
    """An action button with drag support and no internal scrolling viewport."""
    def __init__(self, op, icon, label, parent=None):
        super().__init__(icon, label, parent)
        self.op = op
        self._drag_origin = None
        self.setCheckable(True)
        self.setMinimumHeight(36)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self._drag_origin = event.position().toPoint()
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if (self._drag_origin is not None and event.buttons() & Qt.MouseButton.LeftButton
                and (event.position().toPoint() - self._drag_origin).manhattanLength() >= 10):
            self._drag_origin = None
            self.setDown(False)
            self.setChecked(True)
            mime = QMimeData()
            mime.setData(BLOCK_MIME, self.op.encode("utf-8"))
            drag = QDrag(self)
            drag.setMimeData(mime)
            drag.exec(Qt.DropAction.CopyAction)
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        self._drag_origin = None
        super().mouseReleaseEvent(event)


class BlockPalette(QWidget):
    blockActivated = pyqtSignal(str)

    def __init__(self, category, parent=None):
        super().__init__(parent)
        self.category = category
        self.setObjectName("macroActionPalette")
        self.actions_layout = QVBoxLayout(self)
        self.actions_layout.setContentsMargins(5, 5, 5, 5)
        self.actions_layout.setSpacing(4)
        self.actions_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.buttons = QButtonGroup(self)
        self.buttons.setExclusive(True)
        category_icon = _builder_icon(category)
        for op, definition in BLOCK_DEFS.items():
            if definition["category"] != category:
                continue
            button = PaletteActionButton(op, category_icon, definition["label"], self)
            button.setToolTip(definition["description"])
            button.setObjectName("macroPaletteAction")
            button.setStyleSheet("""
                QPushButton { text-align:left; background:#19222d; color:#edf1f5;
                    border:1px solid #35404d; border-radius:6px; padding:7px 9px; }
                QPushButton:hover { background:#25313f; }
                QPushButton:checked { background:#344252; border-color:#617386; }
            """)
            self.buttons.addButton(button)
            button.clicked.connect(lambda checked=False, action=op: self.blockActivated.emit(action))
            self.actions_layout.addWidget(button)

    def preferred_height(self):
        self.ensurePolished()
        self.actions_layout.invalidate()
        # Layout hints include the styled buttons' actual minimum heights.
        return self.actions_layout.sizeHint().height()


class MacroCategorySection(QWidget):
    def __init__(self, category, parent=None):
        super().__init__(parent)
        self.category = category
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)
        self.button = QPushButton("▸  " + category)
        self.button.setObjectName("macroCategoryButton")
        self.button.setIcon(_builder_icon(category))
        self.button.setCheckable(True)
        root.addWidget(self.button)
        self.palette = BlockPalette(category)
        self.palette.setFixedHeight(0)
        root.addWidget(self.palette)
        self.animation = QVariantAnimation(self)
        self.animation.valueChanged.connect(lambda height: self.palette.setFixedHeight(int(height)))
        self.animation.setDuration(200)
        self.animation.setEasingCurve(QEasingCurve.Type.InOutCubic)
        self.button.toggled.connect(self.set_expanded)

    def set_expanded(self, expanded):
        self.animation.stop()
        self.button.setText(("▾  " if expanded else "▸  ") + self.category)
        self.animation.setStartValue(self.palette.height())
        self.animation.setEndValue(self.palette.preferred_height() if expanded else 0)
        self.animation.start()


class MacroBlockDelegate(QStyledItemDelegate):
    """Paint a single block surface without native focus/branch decorations."""
    def paint(self, painter, option, index):
        data = index.data(Qt.ItemDataRole.UserRole) or {}
        container = str(data.get("op") or "") in _CONTAINER_OPS
        selected = bool(option.state & QStyle.StateFlag.State_Selected)
        hovered = bool(option.state & QStyle.StateFlag.State_MouseOver)
        rect = option.rect.adjusted(3, 3, -3, -3)
        painter.save()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setBrush(QColor("#344252" if selected else "#1c242d" if hovered else "#131a22"))
        painter.setPen(QPen(QColor("#617386" if selected else "#35404d"), 1))
        painter.drawRoundedRect(QRectF(rect), 5, 5)
        content = rect.adjusted(10, 0, -32 if container else -10, 0)
        icon = index.data(Qt.ItemDataRole.DecorationRole)
        if isinstance(icon, QIcon) and not icon.isNull():
            icon.paint(painter, content.left(), rect.center().y() - 8, 16, 16)
            content.adjust(24, 0, 0, 0)
        painter.setPen(QColor("#edf1f5"))
        painter.setFont(option.font)
        label = option.fontMetrics.elidedText(str(index.data() or ""), Qt.TextElideMode.ElideRight, max(0, content.width()))
        painter.drawText(content, Qt.AlignmentFlag.AlignVCenter | Qt.AlignmentFlag.AlignLeft, label)
        if container:
            tree = self.parent()
            expanded = tree.isExpanded(index)
            arrow = rect.adjusted(rect.width() - 25, 0, -3, 0)
            painter.setPen(QColor("#bdc8d4"))
            painter.drawText(arrow, Qt.AlignmentFlag.AlignCenter, "▾" if expanded else "▸")
        painter.restore()

    def sizeHint(self, option, index):
        return QSize(180, 39)


class MacroProgramTree(QTreeWidget):
    changed = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("macroProgramTree")
        self.setColumnCount(1)
        self.setHeaderHidden(True)
        self.setRootIsDecorated(False)
        self.setIndentation(23)
        self.header().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.setItemDelegate(MacroBlockDelegate(self))
        self.setMouseTracking(True)
        self.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.setAnimated(True)
        self.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.setDragEnabled(True)
        self.setAcceptDrops(True)
        self.setDropIndicatorShown(True)
        self.setDragDropMode(QAbstractItemView.DragDropMode.InternalMove)
        self.setDefaultDropAction(Qt.DropAction.MoveAction)
        self.setExpandsOnDoubleClick(True)
        self.itemChanged.connect(lambda *_: self.changed.emit())

    @staticmethod
    def _flags_for(data):
        flags = Qt.ItemFlag.ItemIsEnabled | Qt.ItemFlag.ItemIsSelectable | Qt.ItemFlag.ItemIsDragEnabled
        if str(data.get("op")) in _CONTAINER_OPS:
            flags |= Qt.ItemFlag.ItemIsDropEnabled
        return flags

    def drawBranches(self, painter, rect, index):
        # The loop arrow is drawn inside the only column, not in a styled branch.
        pass

    def drawRow(self, painter, option, index):
        painter.fillRect(option.rect, QColor("#090a0d"))
        block_option = QStyleOptionViewItem(option)
        block_option.rect = self.visualRect(index)
        # drawRow runs before Qt's normal delegate option preparation. Read the
        # selection model explicitly, including when focus is in Properties.
        if self.selectionModel().isSelected(index):
            block_option.state |= QStyle.StateFlag.State_Selected
        else:
            block_option.state &= ~QStyle.StateFlag.State_Selected
        self.itemDelegate().paint(painter, block_option, index)

    def mousePressEvent(self, event):
        item = self.itemAt(event.position().toPoint())
        if item is not None and event.button() == Qt.MouseButton.LeftButton:
            data = item.data(0, Qt.ItemDataRole.UserRole) or {}
            rect = self.visualItemRect(item)
            if str(data.get("op") or "") in _CONTAINER_OPS and event.position().x() >= rect.right() - 30:
                self.setCurrentItem(item)
                self._toggle_repeat(item)
                event.accept()
                return
        super().mousePressEvent(event)

    def _install_repeat_toggle(self, item):
        self.viewport().update()

    def _toggle_repeat(self, item, button=None):
        item.setExpanded(not item.isExpanded())
        self.viewport().update()

    def _make_item(self, data):
        clean = copy.deepcopy(data)
        clean.pop("steps", None)
        item = QTreeWidgetItem()
        item.setData(0, Qt.ItemDataRole.UserRole, clean)
        item.setFlags(self._flags_for(clean))
        self.refresh_item(item)
        return item

    def refresh_item(self, item):
        data = item.data(0, Qt.ItemDataRole.UserRole) or {}
        definition = _block_definition(data.get("op"))
        item.setText(0, _block_summary(data))
        item.setToolTip(0, _block_summary(data) + "\n" + definition["description"])
        item.setBackground(0, QBrush(CATEGORY_COLORS[definition["category"]]))
        item.setForeground(0, QBrush(QColor("#ffffff")))
        icon = _builder_icon(definition["category"])
        if not icon.isNull():
            item.setIcon(0, icon)
        item.setSizeHint(0, QSize(180, 39))

    def _append_steps(self, parent_item, steps):
        for step in steps:
            data = copy.deepcopy(step)
            children = data.pop("steps", []) if data.get("op") in _CONTAINER_OPS else []
            item = self._make_item(data)
            if parent_item is None:
                self.addTopLevelItem(item)
            else:
                parent_item.addChild(item)
            if data.get("op") in _CONTAINER_OPS:
                if children:
                    self._append_steps(item, children)
                item.setExpanded(True)
                self._install_repeat_toggle(item)

    def load_steps(self, steps):
        self.blockSignals(True)
        self.clear()
        self._append_steps(None, copy.deepcopy(steps or []))
        self.blockSignals(False)
        self.changed.emit()

    def _item_to_step(self, item):
        data = copy.deepcopy(item.data(0, Qt.ItemDataRole.UserRole) or {})
        if data.get("op") in _CONTAINER_OPS:
            data["steps"] = [self._item_to_step(item.child(i)) for i in range(item.childCount())]
        return data

    def to_steps(self, validated=False):
        steps = [self._item_to_step(self.topLevelItem(i)) for i in range(self.topLevelItemCount())]
        return _validate_steps(steps) if validated else steps

    def _insert_external_block(self, op, event):
        if op not in BLOCK_DEFS:
            return False
        data = copy.deepcopy(BLOCK_DEFS[op]["template"])
        data.pop("steps", None)
        new_item = self._make_item(data)
        target = self.itemAt(event.position().toPoint())
        indicator = self.dropIndicatorPosition()

        if target is None:
            self.addTopLevelItem(new_item)
        elif indicator == QAbstractItemView.DropIndicatorPosition.OnItem and str((target.data(0, Qt.ItemDataRole.UserRole) or {}).get("op")) in _CONTAINER_OPS:
            target.addChild(new_item)
            target.setExpanded(True)
            self._install_repeat_toggle(target)
        else:
            parent = target.parent()
            if parent is None:
                row = self.indexOfTopLevelItem(target)
                if indicator == QAbstractItemView.DropIndicatorPosition.BelowItem:
                    row += 1
                self.insertTopLevelItem(max(0, row), new_item)
            else:
                row = parent.indexOfChild(target)
                if indicator == QAbstractItemView.DropIndicatorPosition.BelowItem:
                    row += 1
                parent.insertChild(max(0, row), new_item)
                parent.setExpanded(True)
                self._install_repeat_toggle(parent)

        if data.get("op") in _CONTAINER_OPS:
            new_item.setExpanded(True)
            self._install_repeat_toggle(new_item)
        self.setCurrentItem(new_item)
        self.scrollToItem(new_item)
        self.changed.emit()
        return True

    def dragEnterEvent(self, event):
        if event.mimeData().hasFormat(BLOCK_MIME):
            event.setDropAction(Qt.DropAction.CopyAction)
            event.accept()
            return
        super().dragEnterEvent(event)

    def dragMoveEvent(self, event):
        if event.mimeData().hasFormat(BLOCK_MIME):
            event.setDropAction(Qt.DropAction.CopyAction)
            event.accept()
            return
        super().dragMoveEvent(event)

    def dropEvent(self, event):
        snapshot = self.to_steps(False)
        try:
            if event.mimeData().hasFormat(BLOCK_MIME):
                op = bytes(event.mimeData().data(BLOCK_MIME)).decode("utf-8", errors="ignore")
                if not self._insert_external_block(op, event):
                    event.ignore()
                    return
                event.setDropAction(Qt.DropAction.CopyAction)
                event.accept()
            else:
                super().dropEvent(event)
            _validate_steps(self.to_steps(False))
            self.changed.emit()
        except Exception as exc:
            self.load_steps(snapshot)
            QMessageBox.warning(self, "Invalid block layout", str(exc))

    def add_block(self, op, parent_item=None):
        if op not in BLOCK_DEFS:
            return
        data = copy.deepcopy(BLOCK_DEFS[op]["template"])
        data.pop("steps", None)
        item = self._make_item(data)
        if parent_item is not None and str((parent_item.data(0, Qt.ItemDataRole.UserRole) or {}).get("op")) in _CONTAINER_OPS:
            parent_item.addChild(item)
            parent_item.setExpanded(True)
            self._install_repeat_toggle(parent_item)
        else:
            self.addTopLevelItem(item)
        if data.get("op") in _CONTAINER_OPS:
            item.setExpanded(True)
            self._install_repeat_toggle(item)
        self.setCurrentItem(item)
        self.scrollToItem(item)
        self.changed.emit()

    def remove_selected(self):
        item = self.currentItem()
        if item is None:
            return
        parent = item.parent()
        if parent is None:
            self.takeTopLevelItem(self.indexOfTopLevelItem(item))
        else:
            parent.takeChild(parent.indexOfChild(item))
        self.changed.emit()

    def duplicate_selected(self):
        item = self.currentItem()
        if item is None:
            return
        clone_step = self._item_to_step(item)
        parent = item.parent()
        clone = self._make_item({k: v for k, v in clone_step.items() if k != "steps"})
        if parent is None:
            row = self.indexOfTopLevelItem(item)
            self.insertTopLevelItem(row + 1, clone)
        else:
            row = parent.indexOfChild(item)
            parent.insertChild(row + 1, clone)
            parent.setExpanded(True)
            self._install_repeat_toggle(parent)
        if clone_step.get("op") in _CONTAINER_OPS:
            self._append_steps(clone, clone_step.get("steps", []))
            clone.setExpanded(True)
            self._install_repeat_toggle(clone)
        self.setCurrentItem(clone)
        self.changed.emit()


class MacroPropertiesPanel(QWidget):
    def __init__(self, tree, parent=None):
        super().__init__(parent)
        self.tree = tree
        self.current = None
        self.root = QVBoxLayout(self)
        self.root.setContentsMargins(12, 12, 12, 12)
        self.root.setSpacing(8)
        title = QLabel("Properties")
        title.setObjectName("macroPanelTitle")
        self.root.addWidget(title)
        self.form_holder = QWidget()
        self.form = QFormLayout(self.form_holder)
        self.form.setContentsMargins(0, 0, 0, 0)
        self.form.setSpacing(8)
        self.form.setRowWrapPolicy(QFormLayout.RowWrapPolicy.WrapAllRows)
        self.form.setFieldGrowthPolicy(QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        self.root.addWidget(self.form_holder)
        self.root.addStretch(1)
        self.tree.currentItemChanged.connect(self.set_item)

    def _clear_form(self):
        while self.form.rowCount():
            self.form.removeRow(0)

    def _update_data(self, key, value):
        if self.current is None:
            return
        data = copy.deepcopy(self.current.data(0, Qt.ItemDataRole.UserRole) or {})
        data[key] = value
        self.current.setData(0, Qt.ItemDataRole.UserRole, data)
        self.tree.refresh_item(self.current)
        self.tree.changed.emit()

    def _key_combo(self, current):
        button = QPushButton(str(current or "Record key…"))
        button.setToolTip("Click, then press the key to use")
        def capture():
            builder = self.tree.window()
            value, ok = record_key(self, builder.owner, "Record block key", str(current or ""))
            if ok:
                button.setText(value)
                self._update_data("key", value)
        button.clicked.connect(capture)
        return button

    def _spin(self, minimum, maximum, value, suffix=""):
        spin = QSpinBox()
        spin.setButtonSymbols(QAbstractSpinBox.ButtonSymbols.NoButtons)
        spin.setRange(minimum, maximum)
        spin.setValue(int(value))
        if suffix:
            spin.setSuffix(suffix)
        return spin

    def _action_field(self, key, spec, value, data):
        kind = spec['type']
        if kind == 'bool':
            widget = QCheckBox()
            widget.setChecked(bool(value))
            widget.toggled.connect(lambda checked, k=key: self._update_data(k, checked))
        elif kind in {'enum', 'asset'}:
            widget = QComboBox()
            choices = _macro_actions.asset_choices(_HOST) if kind == 'asset' else [
                (_macro_actions.CONFIG[v][0] if key == 'setting' else v.title() if v in {'normal', 'custom', 'your', 'others'} else v, v)
                for v in spec['choices']]
            for label, item_value in choices:
                widget.addItem(label, item_value)
            selected = widget.findData(value)
            if selected < 0:
                widget.addItem(str(value), value)
                selected = widget.count() - 1
            widget.setCurrentIndex(selected)
            def changed(_index):
                self._update_data(key, widget.currentData())
                if key == 'setting':
                    config = _macro_actions.CONFIG[widget.currentData()]
                    default = False if config[2] == 'bool' else config[3][0]
                    self._update_data('value', default)
                    QTimer.singleShot(0, lambda: self.set_item(self.current))
            widget.currentIndexChanged.connect(changed)
        elif kind == 'config':
            _, _, setting_kind, options = _macro_actions.CONFIG[data['setting']]
            if setting_kind == 'int':
                widget = self._spin(options[0], options[1], value)
                widget.valueChanged.connect(lambda v: self._update_data('value', v))
            else:
                widget = self._action_field(key, dict(type=setting_kind, choices=options), value, data)
        elif kind == 'script':
            widget = QPlainTextEdit(str(value))
            widget.setPlaceholderText('Paste Luau script here…')
            widget.setMinimumHeight(200)
            widget.textChanged.connect(lambda: self._update_data(key, widget.toPlainText()))
        else:
            widget = QLineEdit(str(value))
            widget.setMaxLength(spec.get('limit', 1024))
            if kind == 'source':
                widget.setPlaceholderText('File path, https:// URL, asset ID, or none')
            widget.textChanged.connect(lambda text, k=key: self._update_data(k, text))
        return widget

    def set_item(self, item, _old=None):
        self.current = item
        self._clear_form()
        if item is None:
            return
        data = item.data(0, Qt.ItemDataRole.UserRole) or {}
        op = str(data.get("op") or "")
        if op in _macro_actions.SCHEMA:
            for key, spec in _macro_actions.SCHEMA[op]['fields'].items():
                widget = self._action_field(key, spec, data.get(key, spec['default']), data)
                self.form.addRow(spec['label'], widget)
                if spec['type'] in {'source', 'script'}:
                    browse = QPushButton('Choose file…' if spec['type'] == 'source' else 'Load script…')
                    def choose(_checked=False, edit=widget, k=key, script=spec['type'] == 'script'):
                        path, _ = QFileDialog.getOpenFileName(self, 'Choose source', '', 'Scripts (*.lua *.luau *.txt);;All files (*)' if script else 'All files (*)')
                        if path:
                            try:
                                if script:
                                    source = Path(path).read_bytes()
                                    if len(source) > 200000:
                                        raise ValueError('Script exceeds 200 KB.')
                                    edit.setPlainText(source.decode('utf-8-sig'))
                                else:
                                    edit.setText(path)
                            except Exception as exc:
                                QMessageBox.warning(self, 'Macro source', str(exc))
                    browse.clicked.connect(choose)
                    self.form.addRow('', browse)
            hint = QLabel(_macro_actions.SCHEMA[op]['description'])
            hint.setWordWrap(True)
            self.form.addRow(hint)
            return
        if op in {"tap", "key_down", "key_up"}:
            self.form.addRow("Key", self._key_combo(data.get("key")))
        if op == "tap":
            spin = self._spin(0, 5000, data.get("duration_ms", 35), " ms")
            spin.valueChanged.connect(lambda value: self._update_data("duration_ms", int(value)))
            self.form.addRow("Press time", spin)
        elif op == "wait":
            spin = self._spin(0, MACRO_MAX_WAIT_MS, data.get("ms", 250), " ms")
            spin.valueChanged.connect(lambda value: self._update_data("ms", int(value)))
            self.form.addRow("Delay", spin)
        elif op == "mouse_move":
            x = self._spin(-10000, 10000, data.get("x", 0))
            y = self._spin(-10000, 10000, data.get("y", 0))
            x.valueChanged.connect(lambda value: self._update_data("x", int(value)))
            y.valueChanged.connect(lambda value: self._update_data("y", int(value)))
            self.form.addRow("X", x)
            self.form.addRow("Y", y)
        elif op == "mouse_scroll":
            spin = self._spin(-10000, 10000, data.get("amount", 120))
            spin.valueChanged.connect(lambda value: self._update_data("amount", int(value)))
            self.form.addRow("Amount", spin)
        elif op == "repeat":
            spin = self._spin(1, MACRO_MAX_REPEAT, data.get("times", 3))
            spin.valueChanged.connect(lambda value: self._update_data("times", int(value)))
            self.form.addRow("Times", spin)


class MacroBuilderDialog(QDialog):
    def __init__(self, owner, macro=None, path=None, parent=None):
        super().__init__(parent or owner)
        self.owner = owner
        source_path = Path(path) if path else None
        self.installed_path = source_path if source_path and source_path.resolve().parent == MACROS_DIR.resolve() else None
        self.path = source_path if self.installed_path is None else None
        self._installed_id = str(macro.get("id")) if self.installed_path and macro else None
        self.runner = MacroRunner(owner)
        self._dirty = False
        self._loading = True
        self.setWindowTitle("Macro Builder")
        self.resize(1080, 730)
        self.setMinimumSize(850, 600)
        apply_window_icon(self)

        initial = copy.deepcopy(macro) if macro else {
            "format": 1,
            "id": "",
            "name": "My Macro",
            "version": "1.0",
            "description": "",
            "steps": [],
        }

        layout = blur_content_layout(self, self, "Macro Builder", (16, 12, 16, 14), 9)

        meta = QFrame()
        meta.setObjectName("macroMetaFrame")
        meta_layout = QFormLayout(meta)
        meta_layout.setContentsMargins(12, 10, 12, 10)
        meta_layout.setHorizontalSpacing(12)
        meta_layout.setVerticalSpacing(7)
        self.name_edit = QLineEdit(str(initial.get("name") or "My Macro"))
        self.id_edit = QLineEdit(str(initial.get("id") or ""))
        if self._installed_id:
            self.id_edit.setReadOnly(True)
            self.id_edit.setToolTip("The ID stays fixed when applying changes to an installed macro.")
        self.version_edit = QLineEdit(str(initial.get("version") or "1.0"))
        self.description_edit = QLineEdit(str(initial.get("description") or ""))
        self.name_edit.setPlaceholderText("Macro name")
        self.version_edit.setPlaceholderText("1.0")
        self.description_edit.setPlaceholderText("What does this macro do?")
        self._sync_id_placeholder()
        meta_layout.addRow("Name", self.name_edit)
        meta_layout.addRow("ID", self.id_edit)
        meta_layout.addRow("Version", self.version_edit)
        meta_layout.addRow("Description", self.description_edit)
        layout.addWidget(meta)

        body = QSplitter(Qt.Orientation.Horizontal)
        body.setChildrenCollapsible(False)
        layout.addWidget(body, 1)

        palette_frame = QFrame()
        palette_frame.setObjectName("macroSidePanel")
        palette_layout = QVBoxLayout(palette_frame)
        palette_layout.setContentsMargins(10, 10, 10, 10)
        palette_layout.setSpacing(5)
        self.category_sections = []
        category_scroll = QScrollArea()
        category_scroll.setWidgetResizable(True)
        category_scroll.setFrameShape(QFrame.Shape.NoFrame)
        category_content = QWidget()
        category_layout = QVBoxLayout(category_content)
        category_layout.setSizeConstraint(QLayout.SizeConstraint.SetMinAndMaxSize)
        category_layout.setContentsMargins(0, 0, 4, 0)
        category_layout.setSpacing(6)
        self.category_sections = []
        for category in CATEGORY_COLORS:
            section = MacroCategorySection(category)
            section.palette.blockActivated.connect(self.add_block)
            self.category_sections.append(section)
            category_layout.addWidget(section)
        category_layout.addStretch(1)
        category_scroll.setWidget(category_content)
        palette_layout.addWidget(category_scroll, 1)
        body.addWidget(palette_frame)

        center = QFrame()
        center.setObjectName("macroProgramPanel")
        center_layout = QVBoxLayout(center)
        center_layout.setContentsMargins(10, 10, 10, 10)
        center_layout.setSpacing(7)
        title_row = QHBoxLayout()
        title_row.addStretch(1)
        self.duplicate_button = QPushButton()
        self.duplicate_button.setObjectName("macroBuilderIconButton")
        self.duplicate_button.setFixedSize(34, 34)
        self.duplicate_button.setToolTip("Duplicate selected block")
        copy_icon = _file_icon("copy.png", "copy")
        if not copy_icon.isNull():
            self.duplicate_button.setIcon(copy_icon)
            self.duplicate_button.setIconSize(QSize(18, 18))
        self.delete_button = QPushButton()
        self.delete_button.setObjectName("macroBuilderIconButton")
        self.delete_button.setFixedSize(34, 34)
        self.delete_button.setToolTip("Remove selected block")
        remove_icon = _file_icon("remove.png", "remove")
        if not remove_icon.isNull():
            self.delete_button.setIcon(remove_icon)
            self.delete_button.setIconSize(QSize(18, 18))
        self.duplicate_button.clicked.connect(lambda: self.tree.duplicate_selected())
        self.delete_button.clicked.connect(lambda: self.tree.remove_selected())
        title_row.addWidget(self.duplicate_button)
        title_row.addWidget(self.delete_button)
        center_layout.addLayout(title_row)
        self.tree = MacroProgramTree()
        self.tree.load_steps(initial.get("steps", []))
        center_layout.addWidget(self.tree, 1)
        body.addWidget(center)

        props_frame = QFrame()
        props_frame.setObjectName("macroSidePanel")
        props_layout = QVBoxLayout(props_frame)
        props_layout.setContentsMargins(0, 0, 0, 0)
        self.properties = MacroPropertiesPanel(self.tree)
        props_layout.addWidget(self.properties)
        body.addWidget(props_frame)
        body.setSizes([225, 585, 240])

        bottom = QHBoxLayout()
        bottom.addStretch(1)
        self.status = IssueStatusLabel("")
        self.status.hide()
        self.run_button = QPushButton("Run")
        self.stop_button = QPushButton("Stop")
        self.install_button = QPushButton("Apply" if self.installed_path else "Install")
        self.save_button = QPushButton("Save")
        self.save_as_button = QPushButton("Save As")
        for button, filename, fallback in (
            (self.run_button, "run.png", "run"),
            (self.stop_button, "stop.png", "stop"),
            (self.install_button, "Apply.png" if self.installed_path else "install.png", "install"),
            (self.save_button, "save.png", "save"),
            (self.save_as_button, "save.png", "save"),
        ):
            icon = _file_icon(filename, fallback)
            if not icon.isNull():
                button.setIcon(icon)
                button.setIconSize(QSize(17, 17))
        self.stop_button.hide()
        self.run_button.clicked.connect(self.run_current)
        self.stop_button.clicked.connect(self.stop_current)
        self.install_button.clicked.connect(self._install_clicked)
        self.save_button.clicked.connect(self.save)
        self.save_as_button.clicked.connect(self.save_as)
        for button in (self.run_button, self.stop_button, self.install_button, self.save_button, self.save_as_button):
            bottom.addWidget(button)
        layout.addLayout(bottom)

        self.name_edit.textChanged.connect(self._name_changed)
        for edit in (self.name_edit, self.id_edit, self.version_edit, self.description_edit):
            edit.textChanged.connect(self.mark_dirty)
        self.tree.changed.connect(self.mark_dirty)
        self._loading = False
        self._dirty = False
        self._sync_title()

        self.setStyleSheet(r"""
            QDialog { background:#08090a; color:#e8e9ea; }
            QFrame#macroMetaFrame, QFrame#macroSidePanel, QFrame#macroProgramPanel {
                background:#0b0c0f; border:1px solid #23262c; border-radius:8px;
            }
            QLabel#macroPanelTitle { color:#f1f2f4; font-size:13px; font-weight:600; }
            QLineEdit, QComboBox, QSpinBox, QPlainTextEdit {
                background:#0e1014; border:1px solid #2c3038; border-radius:6px; padding:6px; color:#eceef2;
            }
            QPushButton { background:#111318; border:1px solid #2b2f37; border-radius:6px; padding:6px 10px; color:#e8e9ea; }
            QPushButton:hover { background:#191c22; border-color:#3b414c; }
            QPushButton:checked { background:#1e222a; border-color:#485362; color:#ffffff; }
            QPushButton#macroCategoryButton { text-align:left; min-height:30px; }
            QPushButton#macroBuilderIconButton { padding:0; }
            QPushButton#macroCollapseButton {
                padding:0; background:#111318; border:1px solid #303640;
                color:#cfd3da; border-radius:5px; font-size:13px; font-weight:600;
            }
            QPushButton#macroCollapseButton:hover { background:#1a1e25; border-color:#454d5a; color:#ffffff; }
            QListWidget#macroBlockPalette, QTreeWidget#macroProgramTree {
                background:#090a0d; border:1px solid #20242b; border-radius:7px; outline:none; padding:5px;
            }
            QListWidget#macroBlockPalette::item, QTreeWidget#macroProgramTree::item {
                border-radius:6px; margin:2px; padding:7px 9px;
            }
            QListWidget#macroBlockPalette::item:selected { background:#344252; color:#ffffff; border:1px solid #617386; }
            QTreeWidget#macroProgramTree::item, QTreeWidget#macroProgramTree::item:selected,
            QTreeWidget#macroProgramTree::item:hover { border:none; background:transparent; padding:0; margin:0; }
            QTreeWidget#macroProgramTree::branch { background:transparent; border:none; image:none; }
            QScrollBar:vertical { width:9px; background:transparent; }
            QScrollBar::handle:vertical { background:#353a43; border-radius:4px; min-height:28px; }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height:0; }
        """)
        apply_blur_style(self)

    def _sync_id_placeholder(self):
        self.id_edit.setPlaceholderText(_slug_from_name(self.name_edit.text()))

    def _name_changed(self, *_):
        self._sync_id_placeholder()

    def _sync_title(self):
        marker = " *" if self._dirty else ""
        self.setWindowTitle(f"Macro Builder — {self.name_edit.text().strip() or 'Untitled'}{marker}")

    def mark_dirty(self, *_):
        if self._loading:
            return
        self._dirty = True
        self._sync_title()

    def add_block(self, op):
        selected = self.tree.currentItem()
        parent = selected if selected is not None and str((selected.data(0, Qt.ItemDataRole.UserRole) or {}).get("op")) in _CONTAINER_OPS else None
        self.tree.add_block(op, parent)

    def macro_payload(self):
        macro_id = self._installed_id or self.id_edit.text().strip() or self.id_edit.placeholderText().strip()
        payload = {
            "format": 1,
            "id": macro_id,
            "name": self.name_edit.text().strip(),
            "version": self.version_edit.text().strip() or "1.0",
            "description": self.description_edit.text().strip(),
            "steps": self.tree.to_steps(False),
        }
        return validate_macro(payload)

    def _mark_saved(self):
        self._dirty = False
        self._sync_title()

    def _install_clicked(self):
        applying = self.installed_path is not None
        if self.install_macro() and applying:
            self.close()

    def install_macro(self):
        try:
            payload = self.macro_payload()
            MACROS_DIR.mkdir(parents=True, exist_ok=True)
            target = self.installed_path or MACROS_DIR / f"{payload['id']}.lmacro"
            if self.installed_path is None and target.exists():
                answer = QMessageBox.question(self, "Replace installed macro?",
                    "A macro with this ID is already installed. Replace it?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                    QMessageBox.StandardButton.No)
                if answer != QMessageBox.StandardButton.Yes:
                    return False
            write_macro(target, payload)
            self.installed_path = target
            self._installed_id = payload["id"]
            self.id_edit.setText(payload["id"])
            self.id_edit.setReadOnly(True)
            self.install_button.setText("Apply")
            self.install_button.setIcon(_file_icon("Apply.png", "install"))
            self._mark_saved()
            if hasattr(self.parent(), "refresh_installed"):
                self.parent().refresh_installed()
            return True
        except Exception as exc:
            QMessageBox.warning(self, "Install Macro", str(exc))
            return False

    def _save_to(self, target):
        try:
            payload = self.macro_payload()
            target = Path(target)
            target.parent.mkdir(parents=True, exist_ok=True)
            write_macro(target, payload)
            self.path = target
            self._mark_saved()
            if hasattr(self.parent(), "refresh_installed"):
                self.parent().refresh_installed()
            return True
        except Exception as exc:
            QMessageBox.warning(self, "Save Macro", str(exc))
            return False

    def save(self):
        return self._save_to(self.path) if self.path is not None else self.save_as()

    def save_as(self):
        try:
            payload = self.macro_payload()
        except Exception as exc:
            QMessageBox.warning(self, "Save Macro", str(exc))
            return False
        suggested = self.path or Path.home() / "Documents" / f"{payload['id']}.lmacro"
        path, _ = QFileDialog.getSaveFileName(self, "Save Macro As", str(suggested), "LelSploit macros (*.lmacro)")
        if not path:
            return False
        if not path.lower().endswith(".lmacro"):
            path += ".lmacro"
        return self._save_to(Path(path))

    def run_current(self):
        try:
            payload = self.macro_payload()
            self.run_button.hide()
            self.stop_button.show()
            self.stop_button.setEnabled(True)
            self.runner.start(payload, self._run_done)
        except Exception as exc:
            self.run_button.show()
            self.stop_button.hide()
            QMessageBox.warning(self, "Run Macro", str(exc))

    def stop_current(self):
        self.runner.stop()

    def _run_done(self, error):
        self.run_button.show()
        self.run_button.setEnabled(True)
        self.stop_button.hide()
        if error and error != "Macro stopped.":
            QMessageBox.warning(self, "Macro", error)

    def closeEvent(self, event):
        if self.runner.running:
            self.runner.stop()
        if self._dirty:
            box = QMessageBox(self)
            box.setWindowTitle("Unsaved macro")
            box.setText("Keep your changes before closing the Macro Builder?")
            box.setIcon(QMessageBox.Icon.Question)
            install_button = box.addButton("Apply" if self.installed_path else "Install", QMessageBox.ButtonRole.AcceptRole)
            save_button = box.addButton("Save", QMessageBox.ButtonRole.ActionRole)
            discard_button = box.addButton("Discard", QMessageBox.ButtonRole.DestructiveRole)
            cancel_button = box.addButton("Cancel", QMessageBox.ButtonRole.RejectRole)
            for button, filename, fallback in (
                (install_button, "Apply.png" if self.installed_path else "install.png", "install"),
                (save_button, "save.png", "save"),
                (discard_button, "clear.png", "clear"),
                (cancel_button, "close.png", "close"),
            ):
                icon = _file_icon(filename, fallback)
                if not icon.isNull():
                    button.setIcon(icon)
                    button.setIconSize(QSize(17, 17))
            box.setDefaultButton(install_button)
            box.exec()
            clicked = box.clickedButton()
            if clicked is cancel_button or clicked is None:
                event.ignore()
                return
            if clicked is install_button and not self.install_macro():
                event.ignore()
                return
            if clicked is save_button and not self.save():
                event.ignore()
                return
        event.accept()


# ---------------------------------------------------------------------------
# Marketplace — deliberately mirrors the Extensions marketplace UX.
# ---------------------------------------------------------------------------

class MacroMarketplacePane(QWidget):
    SORTS = (
        ("Popular", "popular"),
        ("Most favorited", "favorites"),
        ("Newest", "newest"),
        ("Recently updated", "updated"),
    )

    def __init__(self, owner, parent=None):
        super().__init__(parent)
        self.owner = owner
        self.events = queue.Queue()
        self.request_id = 0
        self.loaded_items = []
        self.my_only = False
        self.favorite_only = False
        self.api_base = MARKETPLACE_DEFAULT_API.rstrip("/")
        self.token = _market._marketplace_api_token(owner.settings)
        self._active = False

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(9)

        self.account_button = QPushButton()
        self.account_button.setFixedHeight(34)
        self.account_button.setMinimumWidth(92)
        user_icon = app_icon("user")
        if not user_icon.isNull():
            self.account_button.setIcon(user_icon)
            self.account_button.setIconSize(QSize(17, 17))
        self.account_button.clicked.connect(self.account_action)

        search_row = QHBoxLayout()
        search_row.setContentsMargins(0, 0, 0, 0)
        search_row.setSpacing(8)
        self.search = SearchLineEdit()
        self.search.setPlaceholderText("Search macros, authors, or descriptions...")
        self.search.setClearButtonEnabled(True)
        self.search.setFixedHeight(46)
        self.search.setMinimumWidth(420)
        self.search.returnPressed.connect(self.refresh)
        search_row.addWidget(self.search, 1)

        self.upload_button = QPushButton("Upload")
        self.upload_button.setFixedHeight(46)
        self.upload_button.setMinimumWidth(108)
        up_icon = app_icon("upload")
        if not up_icon.isNull():
            self.upload_button.setIcon(up_icon)
            self.upload_button.setIconSize(QSize(17, 17))
        self.upload_button.clicked.connect(self.upload_macro)
        search_row.addWidget(self.upload_button, 0, Qt.AlignmentFlag.AlignRight)
        layout.addLayout(search_row)

        filters = QHBoxLayout()
        self.sort = LelComboBox()
        sort_icon = app_icon("sort")
        for label, value in self.SORTS:
            self.sort.addItem(sort_icon, label, value)
        self.sort.currentIndexChanged.connect(self.refresh)
        filters.addWidget(self.sort)

        self.favorites_button = QPushButton("Favorites")
        self.favorites_button.setCheckable(True)
        star_icon = _file_icon("stared.png", "stared")
        if star_icon.isNull():
            star_icon = app_icon("star")
        if not star_icon.isNull():
            self.favorites_button.setIcon(star_icon)
            self.favorites_button.setIconSize(QSize(17, 17))
        self.favorites_button.toggled.connect(self.set_favorites_only)
        filters.addWidget(self.favorites_button)

        self.my_button = QPushButton("My Macros")
        self.my_button.setCheckable(True)
        macros_icon = _file_icon("macros.png", "macro")
        if not macros_icon.isNull():
            self.my_button.setIcon(macros_icon)
            self.my_button.setIconSize(QSize(17, 17))
        self.my_button.toggled.connect(self.set_my_only)
        filters.addWidget(self.my_button)
        filters.addStretch(1)
        layout.addLayout(filters)

        self.status = IssueStatusLabel("")
        self.status.setWordWrap(True)
        layout.addWidget(self.status)

        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QFrame.Shape.NoFrame)
        layout.addWidget(self.scroll, 1)

        self.search_timer = QTimer(self)
        self.search_timer.setSingleShot(True)
        self.search_timer.setInterval(450)
        self.search_timer.timeout.connect(self.refresh)
        self.search.textChanged.connect(self._queue_search)

        self.poll_timer = QTimer(self)
        self.poll_timer.setInterval(50)
        self.poll_timer.timeout.connect(self.poll_events)
        self.poll_timer.start()

        self.setStyleSheet(r"""
            QWidget { background:transparent; color:#e8e9ea; }
            QLabel { color:#aeb1b5; }
            QLineEdit { background:#0d0d0f; border:1px solid #292a2f; border-radius:7px; padding:8px; }
            QPushButton { background:#111216; border:1px solid #2b2d34; border-radius:6px; padding:6px 10px; }
            QPushButton:hover { background:#1a1c21; border-color:#3b3e47; }
            QPushButton:checked { background:#22251d; color:#e7dc8e; border-color:#55583a; }
            QPushButton#marketStar { padding:0; }
            QPushButton#marketDanger:hover { background:#251416; border-color:#5a2e33; }
            QFrame#marketCard { background:#0a0a0d; border:1px solid #202127; border-radius:8px; }
            QFrame#marketCard:hover { background:#0d0e12; border-color:#31333b; }
            QLabel#marketTitle { color:#f3f3f5; font-size:13px; font-weight:600; }
            QLabel#marketMeta { color:#7f838a; font-size:10px; }
            QLabel#marketDesc { color:#b0b1b5; }
            QScrollArea { border:none; background:transparent; }
        """)
        self.refresh_account_state()

    def _queue_search(self):
        if self._active:
            self.search_timer.start()

    @staticmethod
    def _set_button_icon(button, name, size=17):
        icon = app_icon(name)
        if not icon.isNull():
            button.setIcon(icon)
            button.setIconSize(QSize(size, size))

    def activate(self):
        self._active = True
        self.api_base = MARKETPLACE_DEFAULT_API.rstrip("/")
        self.token = _market._marketplace_api_token(self.owner.settings)
        self.refresh_account_state()
        self.refresh()

    def deactivate(self):
        self._active = False
        self.search_timer.stop()

    def favorite_ids(self):
        value = self.owner.settings.value("macro_marketplace/favorites", [])
        return {str(x) for x in value} if isinstance(value, list) else set()

    def save_favorite_ids(self, ids):
        self.owner.settings.setValue("macro_marketplace/favorites", sorted(set(ids)))
        self.owner.settings.sync()

    def refresh_account_state(self):
        self.token = _market._marketplace_api_token(self.owner.settings)
        username = str(self.owner.settings.value("extension_marketplace/username", "") or "")
        logged = bool(self.token)
        self.account_button.setText((username or "Account") if logged else "Login")
        self.account_button.setToolTip("Log out" if logged else "Log in or create a LelSploit account")
        self.upload_button.setToolTip("Upload a macro" if logged else "Log in / register to upload a macro")
        self.my_button.setVisible(logged)
        if not logged and self.my_only:
            self.my_only = False
            self.my_button.blockSignals(True)
            self.my_button.setChecked(False)
            self.my_button.blockSignals(False)

    def account_action(self):
        if self.token:
            answer = QMessageBox.question(
                self,
                "Log out?",
                "Log out of the LelSploit marketplace on this device?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.No,
            )
            if answer != QMessageBox.StandardButton.Yes:
                return
            token = self.token
            self.owner.settings.setValue("extension_marketplace/token", "")
            self.owner.settings.setValue("extension_marketplace/username", "")
            self.owner.settings.sync()
            self.refresh_account_state()
            threading.Thread(target=lambda: self._quiet_logout(token), daemon=True).start()
            self.refresh()
            return
        MarketplaceAccountDialog(self).exec()
        self.refresh_account_state()
        if self.token:
            self.refresh()

    @staticmethod
    def _quiet_logout(token):
        try:
            marketplace_request(MARKETPLACE_DEFAULT_API, "/api/auth/logout", "POST", token=token)
        except Exception:
            pass

    def ensure_login(self):
        if self.token:
            return True
        result = MarketplaceAccountDialog(self).exec()
        self.refresh_account_state()
        return result == QDialog.DialogCode.Accepted and bool(self.token)

    def set_my_only(self, enabled):
        enabled = bool(enabled)
        if enabled and not self.token:
            self.my_button.blockSignals(True)
            self.my_button.setChecked(False)
            self.my_button.blockSignals(False)
            self.my_only = False
            return
        self.my_only = enabled
        if enabled and self.favorite_only:
            self.favorites_button.blockSignals(True)
            self.favorites_button.setChecked(False)
            self.favorites_button.blockSignals(False)
            self.favorite_only = False
        self.refresh()

    def set_favorites_only(self, enabled):
        self.favorite_only = bool(enabled)
        if enabled and self.my_only:
            self.my_button.blockSignals(True)
            self.my_button.setChecked(False)
            self.my_button.blockSignals(False)
            self.my_only = False
        self.refresh()

    def clear_results(self):
        old = self.scroll.takeWidget()
        if old is not None:
            old.deleteLater()

    def refresh(self, *_):
        if not self._active:
            return
        self.search_timer.stop()
        self.request_id += 1
        rid = self.request_id
        self.status.setText("")
        query = self.search.text().strip()
        sort = str(self.sort.currentData() or "popular")
        token = self.token
        params = {"q": query, "sort": sort, "limit": 100}
        if self.my_only:
            params["mine"] = "1"
        base = self.api_base

        def worker():
            try:
                payload = marketplace_request(base, "/api/macros?" + urllib.parse.urlencode(params), token=token)
                self.events.put(("catalog", rid, payload))
            except Exception as exc:
                self.events.put(("error", rid, str(exc)))

        threading.Thread(target=worker, daemon=True).start()

    def poll_events(self):
        for _ in range(25):
            try:
                kind, rid, payload = self.events.get_nowait()
            except queue.Empty:
                break
            if rid != self.request_id and kind in {"catalog", "error"}:
                continue
            if kind == "catalog":
                items = payload.get("items", []) if isinstance(payload, dict) else []
                self.loaded_items = [x for x in items if isinstance(x, dict)]
                self.render_items()
            elif kind == "error":
                self.status.setText(str(payload))
                self.clear_results()
            elif kind == "action_ok":
                self.status.setText("")
                self.refresh()
            elif kind == "action_error":
                self.status.setText(str(payload))
                QMessageBox.warning(self, "Macro Marketplace", str(payload))
            elif kind == "installed":
                self.status.setText("")
                window = self.window()
                if hasattr(window, "refresh_installed"):
                    window.refresh_installed()

    def render_items(self):
        favorites = self.favorite_ids()
        items = self.loaded_items
        if self.favorite_only:
            items = [x for x in items if str(x.get("id")) in favorites or bool(x.get("favorited"))]
        self.clear_results()
        content = QWidget()
        cards = QVBoxLayout(content)
        cards.setContentsMargins(0, 1, 4, 2)
        cards.setSpacing(8)
        if not items:
            empty = QLabel("No macros found." if not self.favorite_only else "No favorite macros yet.")
            empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
            empty.setStyleSheet("padding:28px;color:#777a80;")
            cards.addWidget(empty)
        else:
            for item in items:
                cards.addWidget(self.build_card(item, str(item.get("id")) in favorites or bool(item.get("favorited")), self.my_only))
        cards.addStretch(1)
        self.scroll.setWidget(content)
        self.status.setText(
            ""        )

    def build_card(self, item, favorite, manage):
        card = QFrame()
        card.setObjectName("marketCard")
        root = QHBoxLayout(card)
        root.setContentsMargins(12, 11, 11, 11)
        root.setSpacing(11)

        icon_label = QLabel()
        icon_label.setFixedSize(44, 44)
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon = _file_icon("macros.png", "macro")
        if not icon.isNull():
            icon_label.setPixmap(icon.pixmap(38, 38))
        root.addWidget(icon_label, 0, Qt.AlignmentFlag.AlignTop)

        info = QVBoxLayout()
        info.setSpacing(3)
        title = QLabel(str(item.get("name") or "Untitled macro"))
        title.setObjectName("marketTitle")
        info.addWidget(title)
        author = str(item.get("author") or "unknown")
        version = str(item.get("version") or "1.0")
        downloads = int(item.get("downloads") or 0)
        favs = int(item.get("favorites") or 0)
        status = "Published" if bool(item.get("published", True)) else "Unpublished"
        meta = QLabel(
            f"by {author}  ·  v{version}  ·  {downloads:,} installs  ·  {favs:,} favorites"
            + (f"  ·  {status}" if manage else "")
        )
        meta.setObjectName("marketMeta")
        meta.setWordWrap(True)
        info.addWidget(meta)
        desc = QLabel(str(item.get("description") or "No description provided."))
        desc.setObjectName("marketDesc")
        desc.setWordWrap(True)
        desc.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        info.addWidget(desc)
        root.addLayout(info, 1)

        actions = QHBoxLayout()
        actions.setSpacing(6)
        if manage:
            edit = self._icon_button("edit", "Edit title, description and version")
            edit.clicked.connect(lambda checked=False, x=item: self.edit_macro(x))
            actions.addWidget(edit)
            update = self._icon_button("upload", "Upload an updated .lmacro file")
            update.clicked.connect(lambda checked=False, x=item: self.update_package(x))
            actions.addWidget(update)
            published = bool(item.get("published", True))
            pub = self._icon_button("disable" if published else "run", "Unpublish" if published else "Republish")
            pub.clicked.connect(lambda checked=False, x=item: self.set_published(x, not published))
            actions.addWidget(pub)
            remove = self._icon_button("remove", "Permanently remove macro", "marketDanger")
            remove.clicked.connect(lambda checked=False, x=item: self.delete_macro(x))
            actions.addWidget(remove)
        else:
            install = QPushButton("Install")
            self._set_button_icon(install, "install")
            button_height = max(34, install.sizeHint().height())
            install.setFixedHeight(button_height)
            install.clicked.connect(lambda checked=False, x=item: self.install_macro(x))
            actions.addWidget(install)
            star_name = "stared" if favorite and not app_icon("stared").isNull() else "star"
            star = self._icon_button(star_name, "Remove favorite" if favorite else "Favorite", "marketStar", button_height)
            star.clicked.connect(lambda checked=False, x=item: self.toggle_favorite(x))
            actions.addWidget(star)
        root.addLayout(actions)
        return card

    def _icon_button(self, name, tooltip, object_name="marketIcon", size=34):
        button = QPushButton()
        button.setObjectName(object_name)
        side = max(28, int(size))
        button.setFixedSize(side, side)
        button.setToolTip(tooltip)
        self._set_button_icon(button, name)
        return button

    def toggle_favorite(self, item):
        key = str(item.get("id") or "")
        if not key:
            return
        ids = self.favorite_ids()
        was = key in ids or bool(item.get("favorited"))
        if was:
            ids.discard(key)
        else:
            ids.add(key)
        self.save_favorite_ids(ids)
        item["favorited"] = not was
        if self.token:
            try:
                count = int(item.get("favorites") or 0)
                item["favorites"] = max(0, count + (-1 if was else 1))
            except Exception:
                pass
        self.render_items()
        if self.token:
            threading.Thread(target=lambda: self._favorite_request(key, was), daemon=True).start()

    def _favorite_request(self, key, was):
        try:
            marketplace_request(
                self.api_base,
                f"/api/macros/{urllib.parse.quote(key)}/favorite",
                "DELETE" if was else "POST",
                token=self.token,
            )
        except Exception:
            pass

    def choose_installed_macro(self, title, manifest_id=None):
        choices = [m for m in installed_macros() if not m.get("_error") and m.get("id")]
        if manifest_id:
            choices = [m for m in choices if m["id"] == manifest_id]
        if not choices:
            QMessageBox.information(self, title,
                "Install a macro with this marketplace ID first." if manifest_id else "There are no installed macros to upload. Install or import one first.")
            return None
        labels = [f"{m['name']} · v{m['version']} · {m['id']}" for m in choices]
        label, ok = QInputDialog.getItem(self, title, "Installed macro:", labels, 0, False)
        if not ok:
            return None
        return choices[labels.index(label)]["_path"]

    def upload_macro(self):
        if not self.ensure_login():
            return
        path = self.choose_installed_macro("Upload Installed Macro")
        if not path:
            return
        try:
            macro = read_macro(path)
            raw = Path(path).read_bytes()
        except Exception as exc:
            QMessageBox.warning(self, "Upload Macro", str(exc))
            return
        self.action_request(
            "POST",
            "/api/macros",
            fields={
                "name": macro["name"],
                "version": macro["version"],
                "description": macro["description"],
                "manifestId": macro["id"],
            },
            file_tuple=("package", Path(path).name, raw),
            success="Macro uploaded.",
        )

    def edit_macro(self, item):
        name, ok = QInputDialog.getText(self, "Edit macro", "Name:", text=str(item.get("name") or ""))
        if not ok or not name.strip():
            return
        version, ok = QInputDialog.getText(self, "Edit macro", "Version:", text=str(item.get("version") or "1.0"))
        if not ok:
            return
        desc, ok = QInputDialog.getMultiLineText(self, "Edit macro", "Description:", str(item.get("description") or ""))
        if not ok:
            return
        self.action_request(
            "PATCH",
            f"/api/macros/{urllib.parse.quote(str(item.get('id')))}",
            json_body={"name": name.strip(), "version": version.strip(), "description": desc.strip()},
            success="Macro updated.",
        )

    def update_package(self, item):
        if not self.ensure_login():
            return
        manifest_id = str(item.get("manifestId") or "")
        if not manifest_id:
            QMessageBox.warning(self, "Update Macro", "The marketplace listing is missing its macro ID. Refresh the marketplace first.")
            return
        path = self.choose_installed_macro("Upload New Version", manifest_id)
        if not path:
            return
        try:
            macro = read_macro(path)
            raw = Path(path).read_bytes()
        except Exception as exc:
            QMessageBox.warning(self, "Update Macro", str(exc))
            return
        self.action_request(
            "PUT",
            f"/api/macros/{urllib.parse.quote(str(item.get('id')))}/package",
            fields={"version": macro["version"], "manifestId": macro["id"]},
            file_tuple=("package", Path(path).name, raw),
            success="Macro file updated.",
        )

    def set_published(self, item, published):
        self.action_request(
            "PATCH",
            f"/api/macros/{urllib.parse.quote(str(item.get('id')))}",
            json_body={"published": bool(published)},
            success="Macro republished." if published else "Macro unpublished.",
        )

    def delete_macro(self, item):
        answer = QMessageBox.question(
            self,
            "Remove macro?",
            f"Permanently remove {item.get('name') or 'this macro'} from the marketplace?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        if answer == QMessageBox.StandardButton.Yes:
            self.action_request(
                "DELETE",
                f"/api/macros/{urllib.parse.quote(str(item.get('id')))}",
                success="Macro removed.",
            )

    def action_request(self, method, path, json_body=None, fields=None, file_tuple=None, success="Done."):
        if not self.ensure_login():
            return
        rid = self.request_id
        token = self.token

        def worker():
            try:
                marketplace_request(
                    self.api_base,
                    path,
                    method,
                    token=token,
                    json_body=json_body,
                    multipart_fields=fields,
                    multipart_file=file_tuple,
                    timeout=30,
                )
                self.events.put(("action_ok", rid, success))
            except Exception as exc:
                self.events.put(("action_error", rid, str(exc)))

        threading.Thread(target=worker, daemon=True).start()
        self.status.setText("")

    def install_macro(self, item):
        macro_id = urllib.parse.quote(str(item.get("id") or ""))
        rid = self.request_id
        self.status.setText("")

        def worker():
            try:
                raw = marketplace_request(
                    self.api_base,
                    f"/api/macros/{macro_id}/download",
                    raw=True,
                    response_limit=MACRO_FILE_LIMIT,
                    timeout=30,
                )
                if not raw or len(raw) > MACRO_FILE_LIMIT:
                    raise ValueError("Downloaded macro exceeds the 512 KiB limit.")
                data = validate_macro(json.loads(raw.decode("utf-8-sig")))
                MACROS_DIR.mkdir(parents=True, exist_ok=True)
                target = MACROS_DIR / (data["id"] + ".lmacro")
                target.write_bytes(raw)
                self.events.put(("installed", rid, f"Installed {data['name']}."))
            except Exception as exc:
                self.events.put(("action_error", rid, str(exc)))

        threading.Thread(target=worker, daemon=True).start()


class MacrosWindow(QDialog):
    def __init__(self, parent):
        super().__init__(parent)
        self.owner = parent
        self.runner = MacroRunner(parent)
        self.stop_hotkey_service = getattr(parent, "macro_hotkey_service", None)
        if self.stop_hotkey_service is None:
            self.stop_hotkey_service = MacroStopHotkeyService(parent, self)
            self.stop_hotkey_service.activated.connect(self.stop_running_macro)
            self.stop_hotkey_service.macroActivated.connect(self.run_installed_hotkey)
        self.builder_windows = []
        self._active_run_button = None
        self.view_mode = "installed"
        self.setWindowTitle("Macros")
        self.resize(820, 660)
        self.setMinimumSize(650, 470)
        apply_window_icon(self)

        layout = blur_content_layout(self, self, "Macros", (18, 12, 18, 16), 9)
        top = QHBoxLayout()
        top.setContentsMargins(0, 0, 0, 0)

        self.group = QButtonGroup(self)
        self.group.setExclusive(True)

        self.installed_button = QPushButton("Installed")
        self.installed_button.setObjectName("macroNavButton")
        self.installed_button.setCheckable(True)
        self.installed_button.setChecked(True)
        installed_icon = _file_icon("macros.png", "macro")
        if not installed_icon.isNull():
            self.installed_button.setIcon(installed_icon)
            self.installed_button.setIconSize(QSize(17, 17))
        self.installed_button.clicked.connect(lambda: self.set_view("installed"))
        self.group.addButton(self.installed_button)
        top.addWidget(self.installed_button)

        self.templates_button = QPushButton("Templates")
        self.templates_button.setObjectName("macroNavButton")
        self.templates_button.setCheckable(True)
        template_icon = _file_icon("templates.png", "template")
        if not template_icon.isNull():
            self.templates_button.setIcon(template_icon)
            self.templates_button.setIconSize(QSize(17, 17))
        self.templates_button.clicked.connect(lambda: self.set_view("templates"))
        self.group.addButton(self.templates_button)
        top.addWidget(self.templates_button)

        self.market_button = QPushButton("Marketplace")
        self.market_button.setObjectName("macroNavButton")
        self.market_button.setCheckable(True)
        market_icon = _file_icon("marketplace.png", "marketplace")
        if not market_icon.isNull():
            self.market_button.setIcon(market_icon)
            self.market_button.setIconSize(QSize(17, 17))
        self.market_button.clicked.connect(lambda: self.set_view("marketplace"))
        self.group.addButton(self.market_button)
        top.addWidget(self.market_button)

        top.addStretch(1)
        self.new_button = QPushButton("New Macro")
        new_icon = _file_icon("new.png", "new")
        if not new_icon.isNull():
            self.new_button.setIcon(new_icon)
            self.new_button.setIconSize(QSize(17, 17))
        self.new_button.clicked.connect(self.create_macro)
        top.addWidget(self.new_button)

        self.import_button = QPushButton("Import Macro")
        self.import_button.setIcon(_file_icon("macro.png", "macro"))
        self.import_button.setIconSize(QSize(17, 17))
        self.import_button.clicked.connect(self.import_macro)
        top.addWidget(self.import_button)

        self.marketplace = MacroMarketplacePane(parent, self)
        top.addWidget(self.marketplace.account_button, 0, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        layout.addLayout(top)

        self.stack = QStackedWidget()
        layout.addWidget(self.stack, 1)

        self.installed_page = QWidget()
        installed_layout = QVBoxLayout(self.installed_page)
        installed_layout.setContentsMargins(0, 0, 0, 0)
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.scroll.setObjectName("macroScroll")
        installed_layout.addWidget(self.scroll)
        self.stack.addWidget(self.installed_page)

        self.templates_page = QWidget()
        templates_layout = QVBoxLayout(self.templates_page)
        templates_layout.setContentsMargins(0, 0, 0, 0)
        self.templates_scroll = QScrollArea()
        self.templates_scroll.setWidgetResizable(True)
        self.templates_scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.templates_scroll.setObjectName("macroScroll")
        templates_layout.addWidget(self.templates_scroll)
        self.stack.addWidget(self.templates_page)

        self.stack.addWidget(self.marketplace)

        self.setStyleSheet(r"""
            QDialog { background:#08090a; color:#e8e9ea; }
            QWidget { background:transparent; color:#e8e9ea; }
            QLabel { background:transparent; color:#b0b1b5; }
            QScrollArea#macroScroll { background:transparent; border:none; }
            QFrame#macroCard, QFrame#macroTemplateCard { background:#0a0a0d; border:1px solid #202127; border-radius:8px; }
            QFrame#macroCard:hover, QFrame#macroTemplateCard:hover { background:#0d0e12; border-color:#31333b; }
            QLabel#macroTitle { color:#f3f3f5; font-size:13px; font-weight:600; }
            QLabel#macroMeta { color:#7f838a; font-size:10px; }
            QLabel#macroDesc { color:#b0b1b5; }
            QPushButton { background:#111216; border:1px solid #2b2d34; border-radius:6px; padding:6px 10px; }
            QPushButton:hover { background:#1a1c21; border-color:#3b3e47; }
            QPushButton#macroNavButton:checked { background:#1c2025; border-color:#3d4855; color:#ffffff; }
            QPushButton#macroDanger:hover { background:#251416; border-color:#5a2e33; }
            QScrollBar:vertical { width:9px; background:transparent; }
            QScrollBar::handle:vertical { background:#35353b; border-radius:4px; min-height:28px; }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height:0; }
        """)
        apply_blur_style(self)
        self.refresh_installed()
        self.refresh_templates()
        self.set_view("installed")

    def showEvent(self, event):
        super().showEvent(event)
        if self.view_mode == "marketplace":
            self.marketplace.activate()
        elif self.view_mode == "templates":
            self.refresh_templates()
        else:
            self.refresh_installed()

    def hideEvent(self, event):
        self.marketplace.deactivate()
        super().hideEvent(event)

    def set_view(self, mode):
        mode = str(mode or "installed")
        if mode not in {"installed", "templates", "marketplace"}:
            mode = "installed"
        self.view_mode = mode
        mapping = {
            "installed": self.installed_button,
            "templates": self.templates_button,
            "marketplace": self.market_button,
        }
        for key, button in mapping.items():
            button.blockSignals(True)
            button.setChecked(key == mode)
            button.blockSignals(False)
        self.new_button.setVisible(mode == "installed")
        self.import_button.setVisible(mode == "installed")
        if mode == "installed":
            self.marketplace.deactivate()
            self.stack.setCurrentWidget(self.installed_page)
            self.refresh_installed()
        elif mode == "templates":
            self.marketplace.deactivate()
            self.stack.setCurrentWidget(self.templates_page)
            self.refresh_templates()
        else:
            self.stack.setCurrentWidget(self.marketplace)
            self.marketplace.activate()

    @staticmethod
    def _clear_scroll(scroll):
        old = scroll.takeWidget()
        if old is not None:
            old.deleteLater()

    def refresh_installed(self):
        self._clear_scroll(self.scroll)
        macros = installed_macros()
        content = QWidget()
        box = QVBoxLayout(content)
        box.setContentsMargins(0, 2, 4, 2)
        box.setSpacing(8)
        if not macros:
            label = QLabel("No macros installed. Create one with New Macro, use a template, or install one from Marketplace.")
            label.setWordWrap(True)
            label.setAlignment(Qt.AlignmentFlag.AlignCenter)
            label.setStyleSheet("padding:28px;color:#777a80;")
            box.addWidget(label)
        else:
            for macro in macros:
                box.addWidget(self._installed_card(macro))
        box.addStretch(1)
        self.scroll.setWidget(content)

    def refresh_templates(self):
        self._clear_scroll(self.templates_scroll)
        installed_ids = {str(m.get("id") or "") for m in installed_macros()}
        content = QWidget()
        box = QVBoxLayout(content)
        box.setContentsMargins(0, 2, 4, 2)
        box.setSpacing(8)
        available = [t for t in MACRO_TEMPLATES if t["id"] not in installed_ids]
        if not available:
            label = QLabel("All built-in macro templates are installed.")
            label.setAlignment(Qt.AlignmentFlag.AlignCenter)
            label.setStyleSheet("padding:28px;color:#777a80;")
            box.addWidget(label)
        else:
            for template in available:
                box.addWidget(self._template_card(template))
        box.addStretch(1)
        self.templates_scroll.setWidget(content)

    def _template_card(self, template):
        card = QFrame()
        card.setObjectName("macroTemplateCard")
        row = QHBoxLayout(card)
        row.setContentsMargins(12, 11, 11, 11)
        row.setSpacing(11)
        icon_label = QLabel()
        icon_label.setFixedSize(44, 44)
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon = _file_icon("templates.png", "template")
        if not icon.isNull():
            icon_label.setPixmap(icon.pixmap(38, 38))
        row.addWidget(icon_label, 0, Qt.AlignmentFlag.AlignTop)
        info = QVBoxLayout()
        info.setSpacing(3)
        title = QLabel(str(template.get("name") or "Macro template"))
        title.setObjectName("macroTitle")
        info.addWidget(title)
        meta = QLabel(f"Template  ·  v{template.get('version') or '1.0'}  ·  {len(template.get('steps') or [])} top-level blocks")
        meta.setObjectName("macroMeta")
        info.addWidget(meta)
        desc = QLabel(str(template.get("description") or ""))
        desc.setObjectName("macroDesc")
        desc.setWordWrap(True)
        info.addWidget(desc)
        row.addLayout(info, 1)
        install = QPushButton("Install")
        icon = app_icon("install")
        if not icon.isNull():
            install.setIcon(icon)
            install.setIconSize(QSize(17, 17))
        install.clicked.connect(lambda checked=False, t=template: self.install_template(t))
        row.addWidget(install)
        return card

    def install_template(self, template):
        try:
            payload = validate_macro({"format": 1, **copy.deepcopy(template)})
            MACROS_DIR.mkdir(parents=True, exist_ok=True)
            target = MACROS_DIR / f"{payload['id']}.lmacro"
            if target.exists():
                QMessageBox.information(self, "Macro template", "That macro template is already installed.")
                return
            write_macro(target, payload)
            self.refresh_templates()
            self.refresh_installed()
        except Exception as exc:
            QMessageBox.warning(self, "Install Macro Template", str(exc))

    def _installed_card(self, macro):
        card = QFrame()
        card.setObjectName("macroCard")
        row = QHBoxLayout(card)
        row.setContentsMargins(12, 11, 11, 11)
        row.setSpacing(11)
        icon_label = QLabel()
        icon_label.setFixedSize(44, 44)
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon = _file_icon("macros.png", "macro")
        if not icon.isNull():
            icon_label.setPixmap(icon.pixmap(38, 38))
        row.addWidget(icon_label, 0, Qt.AlignmentFlag.AlignTop)
        text = QVBoxLayout()
        text.setSpacing(3)
        title = QLabel(str(macro.get("name") or "Untitled macro"))
        title.setObjectName("macroTitle")
        text.addWidget(title)
        meta = QLabel(f"v{macro.get('version') or '1.0'}  ·  {macro.get('id') or ''}  ·  {len(macro.get('steps') or [])} top-level blocks")
        meta.setObjectName("macroMeta")
        text.addWidget(meta)
        desc = QLabel(macro.get("description") or "No description.")
        desc.setObjectName("macroDesc")
        desc.setWordWrap(True)
        text.addWidget(desc)
        row.addLayout(text, 1)

        run = QPushButton("Run")
        run_icon = _file_icon("run.png", "run")
        if not run_icon.isNull():
            run.setIcon(run_icon)
            run.setIconSize(QSize(17, 17))
        run.clicked.connect(lambda checked=False, b=run, x=macro: self._run_button_clicked(b, x))
        row.addWidget(run)
        hotkey = QPushButton(_macro_hotkeys(self.owner).get(macro["id"], "Set hotkey"))
        hotkey.setToolTip("Choose a hotkey to run this installed macro")
        hotkey.clicked.connect(lambda checked=False, x=macro: self.choose_macro_hotkey(x))
        row.addWidget(hotkey)
        edit = QPushButton("Edit")
        edit_icon = app_icon("edit")
        if not edit_icon.isNull():
            edit.setIcon(edit_icon)
        edit.clicked.connect(lambda checked=False, x=macro: self.edit_macro(x))
        row.addWidget(edit)
        remove = QPushButton()
        remove.setObjectName("macroDanger")
        remove.setFixedSize(34, 34)
        remove.setToolTip("Remove macro")
        remove_icon = _file_icon("remove.png", "remove")
        if not remove_icon.isNull():
            remove.setIcon(remove_icon)
            remove.setIconSize(QSize(17, 17))
        remove.clicked.connect(lambda checked=False, x=macro: self.remove_macro(x))
        row.addWidget(remove)
        return card

    def create_macro(self):
        builder = MacroBuilderDialog(self.owner, parent=self)
        self.builder_windows.append(builder)
        builder.finished.connect(lambda _=0, b=builder: self._builder_closed(b))
        builder.show()

    def edit_macro(self, macro):
        path = macro.get("_path")
        builder = MacroBuilderDialog(self.owner, macro=macro, path=path, parent=self)
        self.builder_windows.append(builder)
        builder.finished.connect(lambda _=0, b=builder: self._builder_closed(b))
        builder.show()

    def _builder_closed(self, builder):
        try:
            self.builder_windows.remove(builder)
        except ValueError:
            pass
        self.refresh_installed()
        self.refresh_templates()

    def import_macro(self):
        path, _ = QFileDialog.getOpenFileName(self, "Import Macro", "", "LelSploit macros (*.lmacro)")
        if not path:
            return
        try:
            payload = read_macro(path)
            MACROS_DIR.mkdir(parents=True, exist_ok=True)
            target = MACROS_DIR / f"{payload['id']}.lmacro"
            if target.exists() and target.resolve() != Path(path).resolve():
                answer = QMessageBox.question(self, "Replace installed macro?",
                    "A macro with this ID is already installed. Replace it?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                    QMessageBox.StandardButton.No)
                if answer != QMessageBox.StandardButton.Yes:
                    return
            write_macro(target, payload)
            self.refresh_installed()
        except Exception as exc:
            QMessageBox.warning(self, "Import Macro", str(exc))

    def choose_macro_hotkey(self, macro):
        bindings = _macro_hotkeys(self.owner)
        current = bindings.get(macro["id"], "None")
        choice, ok = record_key(self, self.owner, "Record macro hotkey", current, chords=True, allow_clear=True)
        if not ok:
            return
        if choice != "None":
            if self.stop_hotkey_service.key_name in hotkey_parts(choice):
                QMessageBox.warning(self, "Macro hotkey", "That key is reserved for stopping macros. Change the Macro stop key in Settings or choose another key.")
                return
            if any(key != macro["id"] and value == choice for key, value in bindings.items()):
                QMessageBox.warning(self, "Macro hotkey", "Another installed macro already uses that hotkey.")
                return
            bindings[macro["id"]] = choice
        else:
            bindings.pop(macro["id"], None)
        _settings_set(self.owner, "macros/hotkeys", bindings)
        self.refresh_installed()

    def run_installed_hotkey(self, macro_id):
        if self.runner.running or any(b.runner.running for b in self.builder_windows):
            return
        for macro in installed_macros():
            if macro.get("id") == macro_id:
                self.run_macro(macro)
                return

    def stop_running_macro(self):
        if self.runner.running:
            self.runner.stop()
        for builder in list(self.builder_windows):
            try:
                if builder.runner.running:
                    builder.runner.stop()
            except Exception:
                pass

    @staticmethod
    def _set_card_run_state(button, running):
        button.setProperty("macroRunning", bool(running))
        button.setText("Stop" if running else "Run")
        icon = _file_icon("stop.png" if running else "run.png", "stop" if running else "run")
        if not icon.isNull():
            button.setIcon(icon)
            button.setIconSize(QSize(17, 17))

    def _run_button_clicked(self, button, macro):
        if bool(button.property("macroRunning")):
            self.stop_running_macro()
            return
        self.run_macro(macro, button)

    def run_macro(self, macro, button=None):
        try:
            if self.runner.running:
                raise RuntimeError(f"A macro is already running. Press {self.stop_hotkey_service.key_name} or Stop first.")
            if button is not None:
                self._active_run_button = button
                self._set_card_run_state(button, True)
            self.runner.start(macro, lambda error: self._run_done(error))
        except Exception as exc:
            if button is not None:
                self._set_card_run_state(button, False)
                if self._active_run_button is button:
                    self._active_run_button = None
            QMessageBox.warning(self, "Macro", str(exc))

    def _run_done(self, error):
        if self._active_run_button is not None:
            try:
                self._set_card_run_state(self._active_run_button, False)
            except Exception:
                pass
            self._active_run_button = None
        if error and error != "Macro stopped.":
            QMessageBox.warning(self, "Macro", error)

    def remove_macro(self, macro):
        answer = QMessageBox.question(
            self,
            "Remove macro?",
            f"Remove {macro.get('name') or 'this macro'} from this device?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        if answer != QMessageBox.StandardButton.Yes:
            return
        try:
            Path(str(macro.get("_path") or "")).unlink(missing_ok=True)
            bindings = _macro_hotkeys(self.owner)
            bindings.pop(macro.get("id"), None)
            _settings_set(self.owner, "macros/hotkeys", bindings)
            self.refresh_installed()
            self.refresh_templates()
        except Exception as exc:
            QMessageBox.warning(self, "Remove Macro", str(exc))


MACRO_DOCUMENTATION_HTML = r"""
<h1>Macros</h1>
<p>Macros are built with the <b>no-code Macro Builder</b>. Open a category in the folding sidebar, then click or drag blocks into the builder. Select a block to edit its values in <b>Properties</b>. Drag blocks onto a <b>Repeat</b> or <b>Forever</b> block to nest them, and drag program blocks to reorder them.</p>

<h2>Creating a macro</h2>
<ol>
<li>Open <b>Macros</b> from the main LelSploit toolbar.</li>
<li>Stay on <b>Installed</b> and click <b>New Macro</b>, or open <b>Templates</b> for starter macros such as Auto Clicker.</li>
<li>Choose a category on the left: Keyboard, Timing, Mouse, or Control.</li>
<li>Click a block to add it, or drag it into the builder. Category sections fold open underneath their buttons.</li>
<li>Select a block and change its values in <b>Properties</b>.</li>
<li>Use <b>Run</b> to test the current block program, then <b>Install</b> (or <b>Apply</b> for an installed macro). <b>Save</b> writes to your chosen file; <b>Save As</b> chooses a new file. While a macro runs, Run changes to Stop.</li>
<li>In Settings, choose the <b>Macro stop key</b> (F8 by default) so you can stop the active macro even while Roblox has focus.</li>
</ol>

<h2>Block categories</h2>
<h3>Keyboard</h3>
<ul>
<li><b>Tap key</b> — press and release a whitelisted key for a chosen number of milliseconds.</li>
<li><b>Key down</b> — hold a whitelisted key.</li>
<li><b>Key up</b> — release a whitelisted key.</li>
</ul>
<h3>Timing</h3>
<ul><li><b>Wait</b> — pause the macro without blocking the LelSploit UI.</li></ul>
<h3>Mouse</h3>
<ul>
<li>Left/right click, button down, and button up.</li>
<li><b>Move mouse</b> — relative mouse movement.</li>
<li><b>Scroll</b> — mouse wheel movement.</li>
</ul>
<h3>Control</h3>
<ul>
<li><b>Repeat</b> — run nested blocks a chosen number of times.</li>
<li><b>Forever</b> — keep running nested blocks until you press Stop or the configured macro stop key.</li>
</ul>

<h2>Safety model</h2>
<p>Macros support native input, script execution, normal and custom FastFlags, username settings, assets, fonts, skyboxes, and custom resource replacements. Input blocks use Windows keyboard/mouse input with a two-second focus delay. Execute script blocks use the existing app script runner and wait for its response; this does not wait for spawned Luau tasks. Settings and asset changes may require restarting Roblox. Script blocks execute code, and asset blocks can download resources: inspect shared macros before running them. A key whitelist is not a script sandbox.</p>
<p><b>Windows, Meta, Super, Command, LWin and RWin are always rejected.</b> This remains true even if somebody manually edits a downloaded macro file.</p>

<h2>File format</h2>
<p>The builder saves UTF-8 JSON with the <code>.lmacro</code> extension. You normally do not need to edit this yourself, but the format is documented for transparency and marketplace tooling.</p>
<pre>{
  "format": 1,
  "id": "example.jump",
  "name": "Jump three times",
  "version": "1.0",
  "description": "Simple example",
  "steps": [
    {"op": "tap", "key": "SPACE", "duration_ms": 35},
    {"op": "wait", "ms": 150},
    {"op": "repeat", "times": 2, "steps": [
      {"op": "tap", "key": "SPACE", "duration_ms": 35}
    ]}
  ]
}</pre>

<h2>Limits</h2>
<ul>
<li>512 KiB maximum file size.</li>
<li>1000 parsed steps.</li>
<li>Repeat count up to 100.</li>
<li>Forever loops can only be ended with Stop or the configured stop key.</li>
<li>Nesting depth up to 6.</li>
<li>One wait up to 60 seconds.</li>
<li>At most 10 minutes of declared wait time.</li>
</ul>
<p>Marketplace downloads are validated again locally before they are installed, so a malformed or unsupported macro is rejected rather than executed.</p>
"""


__all__ = [
    "configure_host",
    "MacrosWindow",
    "MacroMarketplacePane",
    "MACRO_TEMPLATES",
    "MacroBuilderDialog",
    "validate_macro",
    "read_macro",
    "write_macro",
    "MACRO_DOCUMENTATION_HTML",
]
