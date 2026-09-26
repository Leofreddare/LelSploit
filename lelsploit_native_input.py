"""Restricted Windows SendInput backend for declarative LelSploit macros.
No scripts, commands, paths, processes, or arbitrary virtual-key fields are accepted.
This is input automation, not a security sandbox for the foreground application.
"""
import ctypes
import os

VK_ALLOWED = frozenset(
    list(range(0x41, 0x5B)) + list(range(0x30, 0x3A)) + list(range(0x70, 0x7C))
    + list(range(0x60, 0x70))
    + [8, 9, 13, 16, 17, 18, 19, 20, 27, 32, 33, 34, 35, 36, 37, 38, 39, 40, 45, 46,
       0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, 0xDB, 0xDC, 0xDD, 0xDE]
)
EXTENDED = frozenset([33, 34, 35, 36, 37, 38, 39, 40, 45, 46, 0x6F])

class _Keyboard(ctypes.Structure):
    _fields_ = [('vk',ctypes.c_uint16),('scan',ctypes.c_uint16),('flags',ctypes.c_uint32),('time',ctypes.c_uint32),('extra',ctypes.c_size_t)]
class _Mouse(ctypes.Structure):
    _fields_ = [('dx',ctypes.c_int32),('dy',ctypes.c_int32),('data',ctypes.c_uint32),('flags',ctypes.c_uint32),('time',ctypes.c_uint32),('extra',ctypes.c_size_t)]
class _Hardware(ctypes.Structure):
    _fields_ = [('message',ctypes.c_uint32),('low',ctypes.c_uint16),('high',ctypes.c_uint16)]
class _Payload(ctypes.Union):
    _fields_ = [('keyboard',_Keyboard),('mouse',_Mouse),('hardware',_Hardware)]
class _Input(ctypes.Structure):
    _anonymous_ = ('payload',)
    _fields_ = [('type',ctypes.c_uint32),('payload',_Payload)]

def blocked_keys(keys):
    keys = set(keys)
    return bool(keys & {0x5B,0x5C}) or (
        18 in keys and bool(keys & {9,27,32,0x73})
    ) or (17 in keys and 27 in keys) or (17 in keys and 18 in keys and 46 in keys)

class NativeInput:
    def __init__(self, stop_event, reserved_keys=()):
        if os.name != 'nt':
            raise RuntimeError('Native macro input requires Windows.')
        self.user32 = ctypes.WinDLL('user32', use_last_error=True)
        self.user32.SendInput.argtypes = [ctypes.c_uint32,ctypes.POINTER(_Input),ctypes.c_int]
        self.user32.SendInput.restype = ctypes.c_uint32
        self.user32.GetAsyncKeyState.argtypes = [ctypes.c_int]
        self.user32.GetAsyncKeyState.restype = ctypes.c_int16
        self.user32.MapVirtualKeyW.argtypes = [ctypes.c_uint32, ctypes.c_uint32]
        self.user32.MapVirtualKeyW.restype = ctypes.c_uint32
        self.user32.GetForegroundWindow.restype = ctypes.c_void_p
        self.target = self.user32.GetForegroundWindow()
        if not self.target:
            raise RuntimeError('No foreground window is available for macro input.')
        self.stop_event = stop_event
        self.reserved_keys = set(reserved_keys)
        self.held = set()
        self.mouse_held = set()

    def _guard(self):
        if self.stop_event.is_set():
            raise RuntimeError('Macro stopped.')
        if self.user32.GetForegroundWindow() != self.target:
            raise RuntimeError('Macro stopped.')
        if any(self.user32.GetAsyncKeyState(vk) & 0x8000 for vk in (0x5B,0x5C)):
            raise RuntimeError('Macro stopped.')

    def _send(self, entry):
        if self.user32.SendInput(1,ctypes.byref(entry),ctypes.sizeof(_Input)) != 1:
            raise RuntimeError('Windows rejected macro input. The target may block simulated input or run with higher privileges.')

    def _key(self, code, up=False):
        event = _Input(type=1)
        mapped = self.user32.MapVirtualKeyW(code, 4)
        scan = mapped & 0xff
        extended = (mapped >> 8) == 0xe0 or code in EXTENDED
        # Pause has an E1 sequence; use the virtual-key path for that special key.
        if scan and (mapped >> 8) != 0xe1 and code != 19:
            flags = 8 | (2 if up else 0) | (1 if extended else 0)
            event.keyboard = _Keyboard(0, scan, flags, 0, 0)
        else:
            event.keyboard = _Keyboard(code, 0, (2 if up else 0) | (1 if extended else 0), 0, 0)
        self._send(event)

    def KeyPress(self, code):
        if type(code) is not int or code not in VK_ALLOWED:
            raise ValueError('Key is not on the native-input whitelist.')
        self._guard()
        if code in self.reserved_keys:
            raise ValueError('A macro cannot emit a key reserved for its emergency stop hotkey.')
        effective = self.held | {code} | {vk for vk in (16,17,18,9,27,32,46,0x73) if self.user32.GetAsyncKeyState(vk) & 0x8000}
        if blocked_keys(effective):
            raise ValueError('System shortcut is blocked for macro input.')
        if code in self.held:
            return
        if self.user32.GetAsyncKeyState(code) & 0x8000:
            return  # The user already holds it; do not claim or release their input.
        self._key(code)
        self.held.add(code)

    def KeyRelease(self, code):
        # Release only input this runner owns; never release somebody's held key.
        if code in self.held:
            self._key(code,True)
            self.held.discard(code)

    def _mouse(self, flag, dx=0, dy=0, data=0, release=False):
        if not release:
            self._guard()
        event = _Input(type=0)
        event.mouse = _Mouse(dx,dy,data & 0xffffffff,flag,0,0)
        self._send(event)

    def _button(self, button, down):
        press, release, vk = (2,4,1) if button == 1 else (8,16,2)
        if down:
            if button in self.mouse_held:
                return
            if self.user32.GetAsyncKeyState(vk) & 0x8000:
                return  # A physical click should not abort a running macro.
            self._mouse(press)
            self.mouse_held.add(button)
        elif button in self.mouse_held:
            self._mouse(release,release=True)
            self.mouse_held.discard(button)

    def MouseButton1Press(self): self._button(1,True)
    def MouseButton1Release(self): self._button(1,False)
    def MouseButton2Press(self): self._button(2,True)
    def MouseButton2Release(self): self._button(2,False)
    def MouseButton1Click(self):
        self.MouseButton1Press()
        try:
            self.stop_event.wait(0.02)
        finally:
            self.MouseButton1Release()
    def MouseButton2Click(self):
        self.MouseButton2Press()
        try:
            self.stop_event.wait(0.02)
        finally:
            self.MouseButton2Release()
    def MouseMoveRel(self,x,y):
        if not all(type(v) is int and -10000 <= v <= 10000 for v in (x,y)):
            raise ValueError('Mouse movement exceeds its permitted range.')
        self._mouse(1,x,y)
    def MouseScroll(self,amount):
        if type(amount) is not int or not -10000 <= amount <= 10000:
            raise ValueError('Scroll exceeds its permitted range.')
        self._mouse(0x800,data=amount)
    def release_all(self):
        errors=[]
        for code in list(self.held):
            try: self.KeyRelease(code)
            except Exception as exc: errors.append(str(exc))
        for button in list(self.mouse_held):
            try: self._button(button,False)
            except Exception as exc: errors.append(str(exc))
        if errors:
            raise RuntimeError('Windows could not release all simulated inputs: ' + errors[0])
