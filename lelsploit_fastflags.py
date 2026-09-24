




import ctypes
import json
import os
import queue
import re
import sys
import threading
import time
import urllib.request
from pathlib import Path

from PyQt6.QtCore import Qt, QTimer, QSize, QEvent, QRectF, QPoint, QObject, pyqtSignal, QPropertyAnimation, QEasingCurve
from PyQt6.QtGui import (
    QAction, QColor, QFont, QIcon, QPixmap, QKeySequence, QShortcut, QTextCharFormat, QTextCursor, QTextDocument, QPainter, QPainterPath, QRegion, QSyntaxHighlighter,
)
from PyQt6.QtWidgets import (
    QApplication, QCheckBox, QColorDialog, QComboBox, QDialog, QFileDialog, QFrame, QInputDialog,
    QGridLayout, QHBoxLayout, QLabel, QLineEdit, QMainWindow, QMenu, QMessageBox, QPlainTextEdit,
    QPushButton, QScrollArea, QStackedWidget, QTabWidget, QTabBar, QTextBrowser, QVBoxLayout, QWidget, QGraphicsOpacityEffect, QButtonGroup,
    QListWidget, QListWidgetItem, QAbstractItemView, QAbstractScrollArea, QSystemTrayIcon, QSpinBox, QSlider, QHeaderView, QTableWidget, QTableWidgetItem,
)

_HOST = {}

def configure_host(namespace):

    if not namespace:
        return
    clean = {str(key): value for key, value in namespace.items() if not str(key).startswith("__")}
    _HOST.clear()
    _HOST.update(clean)
    globals().update(clean)

def _modifier_bit_for_vk(vk):
    if vk in (0x11, 0xA2, 0xA3):
        return MOD_CTRL
    if vk in (0x12, 0xA4, 0xA5):
        return MOD_ALT
    if vk in (0x10, 0xA0, 0xA1):
        return MOD_SHIFT
    if vk in (0x5B, 0x5C):
        return MOD_WIN
    return 0


def _qt_modifier_mask(modifiers):
    mask = 0
    if modifiers & Qt.KeyboardModifier.ControlModifier:
        mask |= MOD_CTRL
    if modifiers & Qt.KeyboardModifier.AltModifier:
        mask |= MOD_ALT
    if modifiers & Qt.KeyboardModifier.ShiftModifier:
        mask |= MOD_SHIFT
    if modifiers & Qt.KeyboardModifier.MetaModifier:
        mask |= MOD_WIN
    return mask


def _vk_is_down(vk):
    if sys.platform != "win32":
        return False
    try:
        return bool(ctypes.windll.user32.GetAsyncKeyState(int(vk)) & 0x8000)
    except Exception:
        return False


def _current_modifier_mask():
    mask = 0
    if _vk_is_down(0x11) or _vk_is_down(0xA2) or _vk_is_down(0xA3):
        mask |= MOD_CTRL
    if _vk_is_down(0x12) or _vk_is_down(0xA4) or _vk_is_down(0xA5):
        mask |= MOD_ALT
    if _vk_is_down(0x10) or _vk_is_down(0xA0) or _vk_is_down(0xA1):
        mask |= MOD_SHIFT
    if _vk_is_down(0x5B) or _vk_is_down(0x5C):
        mask |= MOD_WIN
    return mask


def hotkey_text(spec):
    if not isinstance(spec, dict):
        return "Set hotkey"
    try:
        vk = int(spec.get("virtual_key", 0) or 0)
        modifiers = int(spec.get("modifiers", 0) or 0)
    except (TypeError, ValueError):
        return "Set hotkey"
    labels = []
    for bit, label in ((MOD_CTRL, "Ctrl"), (MOD_ALT, "Alt"), (MOD_SHIFT, "Shift"), (MOD_WIN, "Win")):
        if modifiers & bit:
            labels.append(label)
    names = {
        0x08: "Backspace", 0x09: "Tab", 0x0D: "Enter", 0x10: "Shift", 0x11: "Ctrl",
        0x12: "Alt", 0x13: "Pause", 0x14: "Caps Lock", 0x1B: "Esc", 0x20: "Space",
        0x21: "Page Up", 0x22: "Page Down", 0x23: "End", 0x24: "Home",
        0x25: "Left", 0x26: "Up", 0x27: "Right", 0x28: "Down", 0x2C: "Print Screen",
        0x2D: "Insert", 0x2E: "Delete", 0x5B: "Left Win", 0x5C: "Right Win",
        0x60: "Num 0", 0x61: "Num 1", 0x62: "Num 2", 0x63: "Num 3", 0x64: "Num 4",
        0x65: "Num 5", 0x66: "Num 6", 0x67: "Num 7", 0x68: "Num 8", 0x69: "Num 9",
        0x6A: "Num *", 0x6B: "Num +", 0x6D: "Num -", 0x6E: "Num .", 0x6F: "Num /",
        0x90: "Num Lock", 0x91: "Scroll Lock",
        0xA0: "Left Shift", 0xA1: "Right Shift", 0xA2: "Left Ctrl", 0xA3: "Right Ctrl",
        0xA4: "Left Alt", 0xA5: "Right Alt",
        0xBA: ";", 0xBB: "=", 0xBC: ",", 0xBD: "-", 0xBE: ".", 0xBF: "/",
        0xC0: "`", 0xDB: "[", 0xDC: "\\", 0xDD: "]", 0xDE: "'",
    }
    if 0x41 <= vk <= 0x5A or 0x30 <= vk <= 0x39:
        key_name = chr(vk)
    elif 0x70 <= vk <= 0x87:
        key_name = f"F{vk - 0x6F}"
    else:
        key_name = names.get(vk, f"VK {vk:02X}")
    own_modifier = _modifier_bit_for_vk(vk)
    if own_modifier and modifiers & own_modifier:
        labels = [label for bit, label in ((MOD_CTRL, "Ctrl"), (MOD_ALT, "Alt"), (MOD_SHIFT, "Shift"), (MOD_WIN, "Win")) if modifiers & bit and bit != own_modifier]
    labels.append(key_name)
    return "+".join(labels)


class FastFlagHotkeyService(QObject):
    activated = pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._bindings = {}
        self._down = {}
        self._timer = QTimer(self)
        self._timer.setInterval(15)
        self._timer.timeout.connect(self._poll)
        if sys.platform == "win32":
            self._timer.start()

    def set_bindings(self, bindings):
        clean = {}
        if isinstance(bindings, dict):
            for name, spec in bindings.items():
                if not isinstance(name, str) or not isinstance(spec, dict):
                    continue
                try:
                    vk = int(spec.get("virtual_key", 0) or 0)
                    modifiers = int(spec.get("modifiers", 0) or 0) & 0x0F
                except (TypeError, ValueError):
                    continue
                if 0 < vk <= 0xFF:
                    clean[name] = {**spec, "virtual_key": vk, "modifiers": modifiers}
        self._bindings = clean
        current_modifiers = _current_modifier_mask()
        down = {}
        for name, spec in clean.items():
            vk = int(spec.get("virtual_key", 0) or 0)
            required = int(spec.get("modifiers", 0) or 0) & 0x0F
            own_modifier = _modifier_bit_for_vk(vk)
            comparison = current_modifiers & ~own_modifier
            required_comparison = required & ~own_modifier
            down[name] = bool(_vk_is_down(vk) and comparison == required_comparison)
        self._down = down

    def _poll(self):
        if not self._bindings or sys.platform != "win32":
            return
        current_modifiers = _current_modifier_mask()
        for name, spec in tuple(self._bindings.items()):
            vk = int(spec.get("virtual_key", 0) or 0)
            required = int(spec.get("modifiers", 0) or 0) & 0x0F
            own_modifier = _modifier_bit_for_vk(vk)
            comparison = current_modifiers & ~own_modifier
            required_comparison = required & ~own_modifier
            active = _vk_is_down(vk) and comparison == required_comparison
            was_down = self._down.get(name, False)
            if active and not was_down:
                self.activated.emit(name)
            self._down[name] = active


class FastFlagHotkeyCaptureDialog(QDialog):
    _MODIFIER_QT_KEYS = {
        int(Qt.Key.Key_Control), int(Qt.Key.Key_Alt), int(Qt.Key.Key_Shift), int(Qt.Key.Key_Meta),
    }

    def __init__(self, flag_name, parent=None):
        super().__init__(parent)
        self.binding = None
        self.clear_requested = False
        self._pending_binding = None
        self._pending_key = None
        self.setWindowTitle("Set FastFlag Hotkey")
        self.setMinimumSize(430, 170)
        apply_window_icon(self)
        root = blur_content_layout(self, self, "Set FastFlag Hotkey", (16, 12, 16, 16), 10)
        label = QLabel(f'Press a global hotkey for <b>{flag_name}</b>.<br><span style="color:#888">Esc, Backspace, or Delete clears it.</span>')
        label.setTextFormat(Qt.TextFormat.RichText)
        label.setWordWrap(True)
        root.addWidget(label)
        self.preview = QLabel("Waiting for a key combination…")
        self.preview.setStyleSheet("color:#a9a9a9;background:transparent;padding:10px 0;font-size:12px;")
        root.addWidget(self.preview)
        row = QHBoxLayout()
        clear = QPushButton("Clear hotkey")
        cancel = QPushButton("Cancel")
        clear.clicked.connect(self._clear)
        cancel.clicked.connect(self.reject)
        row.addWidget(clear)
        row.addStretch(1)
        row.addWidget(cancel)
        root.addLayout(row)
        apply_blur_style(self)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        QTimer.singleShot(0, self.setFocus)

    def _clear(self):
        self.clear_requested = True
        self.accept()

    def _event_binding(self, event):
        if sys.platform != "win32":
            return None
        try:
            vk = int(event.nativeVirtualKey())
            scan = int(event.nativeScanCode())
        except Exception:
            return None
        if not 0 < vk <= 0xFF:
            return None
        modifiers = _qt_modifier_mask(event.modifiers())
        modifiers &= ~_modifier_bit_for_vk(vk)
        return {
            "virtual_key": vk,
            "scan_code": max(0, scan),
            "extended": vk in {0xA3, 0xA5, 0x2D, 0x2E, 0x24, 0x23, 0x21, 0x22, 0x25, 0x26, 0x27, 0x28, 0x5B, 0x5C},
            "modifiers": modifiers,
        }

    def keyPressEvent(self, event):
        if event.isAutoRepeat():
            event.accept()
            return
        if event.key() in (Qt.Key.Key_Escape, Qt.Key.Key_Backspace, Qt.Key.Key_Delete):
            self.clear_requested = True
            self.binding = None
            self.accept()
            return
        binding = self._event_binding(event)
        if binding is None:
            self.preview.setText("That key could not be captured.")
            event.accept()
            return
        self._pending_binding = binding
        self._pending_key = int(event.key())
        if self._pending_key in self._MODIFIER_QT_KEYS:
            preview = dict(binding)
            preview["modifiers"] = _qt_modifier_mask(event.modifiers()) | _modifier_bit_for_vk(binding["virtual_key"])
            self.preview.setText(hotkey_text(preview))
        else:
            self.preview.setText(hotkey_text(binding))
        event.accept()

    def keyReleaseEvent(self, event):
        if event.isAutoRepeat():
            event.accept()
            return
        if self._pending_binding is not None and int(event.key()) == self._pending_key:
            self.binding = dict(self._pending_binding)
            self._pending_binding = None
            self._pending_key = None
            self.accept()
            return
        event.accept()


class FastFlagListDialog(QDialog):
    MAX_ROWS = 1000

    def __init__(self, fastflags_window):
        super().__init__(fastflags_window)
        self.fastflags_window = fastflags_window
        self.setObjectName("fastFlagListDialog")
        self.catalog = useful_fastflag_catalog()
        self.setWindowTitle("FastFlags List")
        self.resize(860, 600)
        self.setMinimumSize(700, 460)
        apply_window_icon(self)
        root = blur_content_layout(self, self, "FastFlags List", (14, 12, 14, 14), 9)

        self.search = QLineEdit()
        self.search.setPlaceholderText("Search for useful FastFlags")
        root.addWidget(self.search)

        self.table = QTableWidget(0, 3)
        self.table.setObjectName("catalogTable")
        self.table.setAutoFillBackground(False)
        self.table.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.table.viewport().setAutoFillBackground(False)
        self.table.viewport().setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.table.viewport().setStyleSheet("background:transparent;border:0;")
        self.table.setHorizontalHeaderLabels(("Name", "Value", "Does"))
        self.table.verticalHeader().setVisible(False)
        self.table.setShowGrid(False)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.table.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.table.setAlternatingRowColors(False)
        self.table.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        header = self.table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Interactive)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        self.table.setColumnWidth(1, 145)
        self.table.verticalHeader().setDefaultSectionSize(31)
        root.addWidget(self.table, 1)

        actions = QHBoxLayout()
        self.add_selected = QPushButton("Add selected")
        self.add_selected.setEnabled(False)
        actions.addStretch(1)
        actions.addWidget(self.add_selected)
        root.addLayout(actions)

        self.search.textChanged.connect(self._populate)
        self.table.itemSelectionChanged.connect(
            lambda: self.add_selected.setEnabled(bool(self.table.selectionModel().selectedRows()))
        )
        self.table.itemDoubleClicked.connect(lambda _item: self._add_selection())
        self.add_selected.clicked.connect(self._add_selection)

        self.setStyleSheet(r'''
            QDialog#fastFlagListDialog { background:#0b0c0d; color:#dedede; }
            QWidget { color:#dedede; }
            QLabel { background:transparent; }
            QLineEdit { background:#0d0d0e; color:#ededed; border:1px solid #2a2a2d; border-radius:6px; min-height:32px; padding:0 9px; }
            QLineEdit:focus { background:#101012; border-color:#45454a; }
            QPushButton { background:#111113; color:#e9e9e9; border:1px solid #2a2a2d; border-radius:6px; padding:6px 11px; }
            QPushButton:hover { background:#19191c; border-color:#414146; }
            QTableWidget#catalogTable { background:transparent; alternate-background-color:transparent; border:1px solid #252528; border-radius:7px; selection-background-color:#1a1b1d; selection-color:#fff; gridline-color:transparent; }
            QTableWidget#catalogTable::item { padding:5px 7px; border-bottom:1px solid #151517; }
            QHeaderView::section { background:#0d0d0f; color:#bcbcbc; border:0; border-bottom:1px solid #252528; padding:7px; font-weight:600; }
        ''')
        apply_blur_style(self)
        self._populate()

    def _matching_entries(self):
        query = self.search.text().strip().casefold()
        rows = []
        for name, meta in self.catalog.items():
            
            haystack = " ".join((
                name,
                str(meta.get("category", "")),
                " ".join(meta.get("presets", ())),
            )).casefold()
            if query and query not in haystack:
                continue
            rows.append((name, meta))
        rows.sort(key=lambda item: item[0].casefold())
        return rows

    def _populate(self, *_):
        rows = self._matching_entries()
        visible = rows[:self.MAX_ROWS]
        self.table.setUpdatesEnabled(False)
        self.table.setRowCount(len(visible))
        try:
            for row, (name, meta) in enumerate(visible):
                presets = ", ".join(meta.get("presets", ()))
                values = (
                    name,
                    str(meta.get("value", "")),
                    presets,
                )
                for column, value in enumerate(values):
                    item = QTableWidgetItem(value)
                    item.setData(Qt.ItemDataRole.UserRole, name)
                    if presets:
                        item.setToolTip(presets)
                    self.table.setItem(row, column, item)
        finally:
            self.table.setUpdatesEnabled(True)
        self.add_selected.setEnabled(bool(self.table.selectionModel().selectedRows()))

    def _add_selection(self):
        selected = []
        for index in self.table.selectionModel().selectedRows():
            item = self.table.item(index.row(), 0)
            if not item:
                continue
            name = str(item.data(Qt.ItemDataRole.UserRole) or item.text()).strip()
            if name:
                selected.append(name)
        if not selected:
            return
        additions = {}
        for name in selected:
            meta = self.catalog.get(name, {})
            additions[name] = str(meta.get("value", ""))
        self.fastflags_window.add_catalog_fastflags(additions)
        self.accept()


class FastFlagCheckButton(QPushButton):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("fastFlagCheck")
        self.setCheckable(True)
        self.setFixedSize(22, 22)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setAccessibleName("Toggle")
        self.toggled.connect(self._sync_mark)
        self._sync_mark(False)

    def _sync_mark(self, checked):
        self.setText("✓" if checked else "")


class FastFlagsWindow(QDialog):
    MSAA_ITEMS = (("Default", None), ("1x", "1"), ("2x", "2"), ("4x", "4"))
    TEXTURE_ITEMS = (("Default", None), ("Level 0", "0"), ("Level 1", "1"), ("Level 2", "2"), ("Level 3", "3"))
    RENDER_ITEMS = (("Default", None), ("D3D11", "D3D11"), ("Vulkan", "Vulkan"), ("OpenGL", "OpenGL"))

    def __init__(self, parent):
        super().__init__(parent)
        self.owner = parent
        self.current_flags = {}
        self._baseline_flags = {}
        self._baseline_enabled = False
        self._baseline_fps = 0
        self._baseline_custom_flags = {}
        self._baseline_username_settings = {}
        self._reloading = False
        self.asset_rows = []
        self.auto_save_timer = QTimer(self)
        self.auto_save_timer.setSingleShot(True)
        self.auto_save_timer.setInterval(260)
        self.auto_save_timer.timeout.connect(lambda: self.save_changes(quiet=True))
        self.username_save_timer = QTimer(self)
        self.username_save_timer.setSingleShot(True)
        self.username_save_timer.setInterval(220)
        self.username_save_timer.timeout.connect(self.persist_username_spoofer)
        self.setObjectName("fastFlagsWindow")
        self.setWindowTitle("FastFlags")
        self.resize(980, 700)
        self.setMinimumSize(780, 540)
        apply_window_icon(self)
        outer = blur_content_layout(self, self, "FastFlags", (14, 12, 14, 14), 9)

        self.attached_banner = QFrame()
        self.attached_banner.setObjectName("attachedWarning")
        attached_row = QHBoxLayout(self.attached_banner)
        attached_row.setContentsMargins(11, 8, 11, 8)
        attached_row.setSpacing(8)
        self.attached_label = QLabel("")
        self.attached_label.setTextFormat(Qt.TextFormat.RichText)
        self.attached_label.setTextInteractionFlags(Qt.TextInteractionFlag.TextBrowserInteraction)
        self.attached_label.setOpenExternalLinks(False)
        self.attached_label.linkActivated.connect(self.owner.handle_fastflags_mode_link)
        attached_row.addWidget(self.attached_label, 1)
        outer.addWidget(self.attached_banner)

        nav = QHBoxLayout()
        nav.setSpacing(5)
        self.nav_group = QButtonGroup(self)
        self.nav_group.setExclusive(True)
        self.nav_buttons = []
        for index, label in enumerate(("FastFlags", "Custom Flags", "Assets", "Username", "Custom")):
            button = QPushButton(label)
            button.setObjectName("clientNav")
            button.setCheckable(True)
            button.setFixedHeight(31)
            button.clicked.connect(lambda checked=False, i=index: self.stack.setCurrentIndex(i))
            self.nav_group.addButton(button)
            self.nav_buttons.append(button)
            nav.addWidget(button)
        nav.addStretch(1)
        outer.addLayout(nav)

        self.stack = QStackedWidget()
        self.stack.setObjectName("clientStack")
        self.stack.setAutoFillBackground(False)
        self.stack.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)
        self.stack.addWidget(self.build_fastflag_page())
        self.stack.addWidget(self.build_custom_fastflags_page())
        self.stack.addWidget(self.build_assets_page())
        self.stack.addWidget(self.build_username_page())
        self.stack.addWidget(self.build_custom_page())
        outer.addWidget(self.stack, 1)
        self.nav_buttons[0].setChecked(True)

        self.restart_bar = QFrame()
        self.restart_bar.setObjectName("restartBar")
        restart_layout = QHBoxLayout(self.restart_bar)
        restart_layout.setContentsMargins(11, 7, 11, 7)
        self.restart_label = QLabel('Restart Roblox to apply changes. <a href="restart" style="color:#9ec5ff;text-decoration:none;"><b>Restart now</b></a>')
        self.restart_label.setTextFormat(Qt.TextFormat.RichText)
        self.restart_label.setTextInteractionFlags(Qt.TextInteractionFlag.TextBrowserInteraction)
        self.restart_label.setOpenExternalLinks(False)
        self.restart_label.linkActivated.connect(self.restart_now)
        restart_layout.addWidget(self.restart_label)
        restart_layout.addStretch(1)
        outer.addWidget(self.restart_bar)

        self.setStyleSheet(r'''
            QDialog#fastFlagsWindow { background:#0b0c0d; color:#dedede; }
            QWidget { color:#dedede; }
            QLabel { background:transparent; }
            QCheckBox { background:transparent; color:#f1f1f1; spacing:7px; }
            QCheckBox::indicator { width:16px; height:16px; border:1px solid #696969; border-radius:3px; background:#090909; }
            QCheckBox::indicator:hover { border-color:#a0a0a0; background:#121212; }
            QCheckBox::indicator:checked { border-color:#8be3a5; background:#3c995d; }
            QPushButton { background:#111111; color:#e7e7e7; border:1px solid #292929; border-radius:5px; padding:6px 10px; }
            QPushButton:hover { background:#191919; border-color:#3a3a3a; }
            QPushButton#clientNav { background:transparent; border:0; color:#999; padding:5px 12px; }
            QPushButton#clientNav:hover { color:#eee; background:#101010; }
            QPushButton#clientNav:checked { color:#fff; background:#171717; }
            QStackedWidget#clientStack { border:0; background:transparent; }
            QStackedWidget#clientStack > QWidget { border:0; background:transparent; }
            QWidget#fastFlagsPage, QWidget#customFastFlagsPage, QWidget#assetsPage, QWidget#usernamePage, QWidget#customModsPage { background:transparent; border:0; }
            QFrame#fastFlagCard, QFrame#modRow { background:#0b0b0b; border:1px solid #242424; border-radius:7px; }
            QFrame#fastFlagManagerCard { background:#0d0d0d; border:1px solid #2b2b2b; border-radius:7px; }
            QLabel#sectionTitle { color:#8e8e8e; font-size:11px; font-weight:600; padding:7px 2px 2px; }
            QLabel#modStatus { color:#888; font-style:italic; }
            QLabel#modStatus[applied="true"] { color:#7fce91; font-style:normal; }
            QLineEdit, QSpinBox { background:#0d0d0e; color:#ececec; border:1px solid #2a2a2c; border-radius:6px; min-height:32px; padding:0 9px; }
            QLineEdit:focus, QSpinBox:focus { border-color:#454548; background:#101012; }
            QSlider { background:transparent; border:none; }
            QSlider::groove:horizontal { height:4px; background:#2c2c2f; border:none; border-radius:2px; }
            QSlider::sub-page:horizontal { background:#56565b; border-radius:2px; }
            QSlider::add-page:horizontal { background:#242426; border-radius:2px; }
            QSlider::handle:horizontal { width:12px; margin:-4px 0; background:#8a8a8f; border:1px solid #a0a0a4; border-radius:6px; }
            QSlider::handle:horizontal:hover { background:#a8a8ad; border-color:#c0c0c4; }
            QFrame#restartBar { background:#0c0c0d; border:1px solid #2a2a2c; border-radius:7px; }
            QFrame#attachedWarning { background:#18130a; border:1px solid #55401b; border-radius:7px; }
            QFrame#attachedWarning QLabel { color:#e8d7ad; background:transparent; }
            QPlainTextEdit#customFlagEditor { background:#09090a; color:#e8e8e8; border:1px solid #28282b; border-radius:7px; padding:8px; selection-background-color:#303033; }
            QPlainTextEdit#customFlagEditor[invalid="true"] { border-color:#8b3a3a; }
            QLabel#customFlagStatus { color:#888; background:transparent; }
            QTableWidget#customFlagTable { background:transparent; alternate-background-color:transparent; border:1px solid #252528; border-radius:7px; gridline-color:transparent; selection-background-color:#18191b; selection-color:#f0f0f0; }
            QTableWidget#customFlagTable::item { padding:6px 7px; border-bottom:1px solid #151517; }
            QHeaderView::section { background:#0d0d0f; color:#bcbcbc; border:0; border-bottom:1px solid #252528; padding:7px; font-weight:600; }
            QPushButton#hotkeyButton { background:#101012; border:1px solid #2d2d31; border-radius:5px; padding:0 9px; color:#d6d6d6; }
            QPushButton#hotkeyButton:hover { background:#171719; border-color:#45454a; color:#ffffff; }
            QPushButton#hotkeyResetButton { background:transparent; border:1px solid transparent; border-radius:5px; padding:0; }
            QPushButton#hotkeyResetButton:hover { background:#171719; border-color:#303034; }
            QPushButton#hotkeyResetButton:disabled { background:transparent; border-color:transparent; }
            QPushButton#fastFlagCheck { background:#080808; color:#fff; border:1px solid #444; border-radius:4px; padding:0; font-weight:700; }
            QPushButton#fastFlagCheck:checked { background:#356846; border-color:#6da17d; }
            QPushButton#flatButton, QPushButton#resetLink { background:transparent; border:0; color:#999; }
            QPushButton#flatButton:hover, QPushButton#resetLink:hover { color:#eee; background:transparent; }
            QScrollArea, QScrollArea > QWidget > QWidget { border:0; background:transparent; }
            QScrollBar:vertical { width:9px; background:#070707; }
            QScrollBar::handle:vertical { background:#333; border-radius:4px; min-height:25px; }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height:0; }
        ''')
        apply_blur_style(self)
        self.reload()

    @staticmethod
    def row_card(label, control, prominent=False):
        card = QFrame()
        card.setObjectName("fastFlagManagerCard" if prominent else "fastFlagCard")
        card.setMinimumHeight(48)
        row = QHBoxLayout(card)
        row.setContentsMargins(12, 8, 12, 8)
        row.setSpacing(10)
        text = QLabel(label)
        if prominent:
            text.setStyleSheet("color:#eee;font-weight:600;background:transparent;")
        row.addWidget(text, 1)
        row.addWidget(control, 0, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        return card

    def build_fastflag_page(self):
        page = QWidget()
        page.setObjectName("fastFlagsPage")
        page.setAutoFillBackground(False)
        page_layout = QVBoxLayout(page)
        page_layout.setContentsMargins(0, 0, 0, 0)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(1, 1, 1, 1)
        layout.setSpacing(8)
        self.manager_check = FastFlagCheckButton()
        layout.addWidget(self.row_card("Allow LelSploit to manage FastFlags", self.manager_check, True))
        self.managed_panel = QWidget()
        managed = QVBoxLayout(self.managed_panel)
        managed.setContentsMargins(0, 0, 0, 0)
        managed.setSpacing(7)
        title = QLabel("Rendering")
        title.setObjectName("sectionTitle")
        managed.addWidget(title)
        self.render_combo = LelComboBox(); self.render_combo.setFixedWidth(190)
        for label, value in self.RENDER_ITEMS: self.render_combo.addItem(label, value)
        managed.addWidget(self.row_card("Rendering Mode", self.render_combo))
        self.msaa_combo = LelComboBox(); self.msaa_combo.setFixedWidth(190)
        for label, value in self.MSAA_ITEMS: self.msaa_combo.addItem(label, value)
        managed.addWidget(self.row_card("MSAA Level", self.msaa_combo))
        self.scaling_check = FastFlagCheckButton(); managed.addWidget(self.row_card("Fix Display Scaling", self.scaling_check))
        self.fullscreen_check = FastFlagCheckButton(); managed.addWidget(self.row_card("Alt+Enter Fullscreen", self.fullscreen_check))
        self.texture_combo = LelComboBox(); self.texture_combo.setFixedWidth(190)
        for label, value in self.TEXTURE_ITEMS: self.texture_combo.addItem(label, value)
        managed.addWidget(self.row_card("Texture Quality", self.texture_combo))

        title = QLabel("Quality overrides"); title.setObjectName("sectionTitle"); managed.addWidget(title)
        self.mesh_check = FastFlagCheckButton()
        self.mesh_slider = JumpSlider(Qt.Orientation.Horizontal); self.mesh_slider.setRange(0, 4); self.mesh_slider.setFixedWidth(170)
        self.mesh_value = QLabel("Default"); self.mesh_value.setFixedWidth(55)
        mesh_ctl = QWidget(); mesh_ctl.setStyleSheet("background:transparent;border:none;"); mesh_row = QHBoxLayout(mesh_ctl); mesh_row.setContentsMargins(0,0,0,0); mesh_row.setSpacing(8)
        mesh_row.addWidget(self.mesh_check); mesh_row.addWidget(self.mesh_slider); mesh_row.addWidget(self.mesh_value)
        managed.addWidget(self.row_card("Mesh LOD Override", mesh_ctl))
        self.frm_check = FastFlagCheckButton()
        self.frm_slider = JumpSlider(Qt.Orientation.Horizontal); self.frm_slider.setRange(0, 21); self.frm_slider.setFixedWidth(170)
        self.frm_value = QLabel("Default"); self.frm_value.setFixedWidth(62)
        frm_ctl = QWidget(); frm_ctl.setStyleSheet("background:transparent;border:none;"); frm_row = QHBoxLayout(frm_ctl); frm_row.setContentsMargins(0,0,0,0); frm_row.setSpacing(8)
        frm_row.addWidget(self.frm_check); frm_row.addWidget(self.frm_slider); frm_row.addWidget(self.frm_value)
        managed.addWidget(self.row_card("FRM Quality Override", frm_ctl))
        self.grey_sky_check = FastFlagCheckButton(); managed.addWidget(self.row_card("Grey Sky (Debug)", self.grey_sky_check))
        self.pause_voxelizer_check = FastFlagCheckButton(); managed.addWidget(self.row_card("Pause Voxelizer", self.pause_voxelizer_check))

        title = QLabel("Environment"); title.setObjectName("sectionTitle"); managed.addWidget(title)
        self.grass_max = self._default_spin(0, 10000); managed.addWidget(self.row_card("Grass Distance Max", self.grass_max))
        self.grass_min = self._default_spin(0, 10000); managed.addWidget(self.row_card("Grass Distance Min", self.grass_min))
        self.grass_motion = self._default_spin(0, 10000); managed.addWidget(self.row_card("Grass Motion Factor", self.grass_motion))
        self.fps_cap = QSpinBox(); self.fps_cap.setRange(0, 1000); self.fps_cap.setSpecialValueText("Default"); self.fps_cap.setFixedWidth(190)
        managed.addWidget(self.row_card("Framerate Cap (FPS)", self.fps_cap))
        self.reset_button = QPushButton("Reset configuration"); self.reset_button.setObjectName("resetLink"); self.reset_button.clicked.connect(self.reset_configuration)
        managed.addWidget(self.reset_button, 0, Qt.AlignmentFlag.AlignLeft)
        layout.addWidget(self.managed_panel)
        layout.addStretch(1)
        scroll.setWidget(content)
        page_layout.addWidget(scroll, 1)
        self.manager_check.toggled.connect(self.on_manager_toggled)
        controls = [self.render_combo, self.msaa_combo, self.scaling_check, self.fullscreen_check, self.texture_combo,
                    self.mesh_check, self.mesh_slider, self.frm_check, self.frm_slider, self.grey_sky_check,
                    self.pause_voxelizer_check, self.grass_max, self.grass_min, self.grass_motion, self.fps_cap]
        for control in controls:
            signal = getattr(control, "toggled", None) or getattr(control, "valueChanged", None) or getattr(control, "currentIndexChanged", None)
            if signal is not None:
                signal.connect(self.update_change_state)
        self.mesh_slider.valueChanged.connect(self._update_slider_labels)
        self.frm_slider.valueChanged.connect(self._update_slider_labels)
        return page

    def build_custom_fastflags_page(self):
        page = QWidget()
        page.setObjectName("customFastFlagsPage")
        page.setAutoFillBackground(False)
        root = QVBoxLayout(page)
        root.setContentsMargins(4, 4, 4, 4)
        root.setSpacing(10)

        header = QHBoxLayout()
        title = QLabel("Custom FastFlags")
        title.setStyleSheet("font-size:14px;font-weight:600;color:#f0f0f0;background:transparent;")
        header.addWidget(title)
        header.addStretch(1)
        root.addLayout(header)

        self.custom_flag_status = QLabel("")
        self.custom_flag_status.setObjectName("customFlagStatus")
        self.custom_flag_status.setStyleSheet("color:#e06c75;background:transparent;")
        self.custom_flag_status.hide()
        root.addWidget(self.custom_flag_status)

        toolbar_top = QHBoxLayout()
        toolbar_top.setSpacing(7)
        self.custom_flag_search = QLineEdit()
        self.custom_flag_search.setPlaceholderText("Search custom FastFlags…")
        self.custom_flag_search.textChanged.connect(self._filter_custom_flag_rows)
        self.fastflag_list_button = QPushButton("FastFlags List")
        list_icon = app_icon("fflaglist")
        if not list_icon.isNull():
            self.fastflag_list_button.setIcon(list_icon)
            self.fastflag_list_button.setIconSize(QSize(16, 16))
        self.fastflag_list_button.clicked.connect(self.open_fastflag_list)
        toolbar_top.addWidget(self.custom_flag_search, 1)
        toolbar_top.addWidget(self.fastflag_list_button)
        root.addLayout(toolbar_top)

        toolbar_actions = QHBoxLayout()
        toolbar_actions.setSpacing(7)
        add_button = QPushButton("Add flag")
        import_button = QPushButton("Import JSON")
        export_button = QPushButton("Export JSON")

        fastflags_icon = app_icon("fastflags")
        if not fastflags_icon.isNull():
            add_button.setIcon(fastflags_icon)
            add_button.setIconSize(QSize(16, 16))

        json_icon = app_icon("json")
        if not json_icon.isNull():
            import_button.setIcon(json_icon)
            import_button.setIconSize(QSize(16, 16))
            export_button.setIcon(json_icon)
            export_button.setIconSize(QSize(16, 16))

        add_button.clicked.connect(self.add_custom_fastflag)
        import_button.clicked.connect(self.import_custom_fastflags)
        export_button.clicked.connect(self.export_custom_fastflags)
        toolbar_actions.addWidget(add_button)
        toolbar_actions.addStretch(1)
        toolbar_actions.addWidget(import_button)
        toolbar_actions.addWidget(export_button)
        root.addLayout(toolbar_actions)

        self.custom_flag_table = QTableWidget(0, 4)
        self.custom_flag_table.setObjectName("customFlagTable")
        self.custom_flag_table.setAutoFillBackground(False)
        self.custom_flag_table.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.custom_flag_table.viewport().setAutoFillBackground(False)
        self.custom_flag_table.viewport().setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.custom_flag_table.viewport().setStyleSheet("background:transparent;border:0;")
        self.custom_flag_table.setHorizontalHeaderLabels(("Name", "Value", "Status", "Hotkey"))
        self.custom_flag_table.verticalHeader().setVisible(False)
        self.custom_flag_table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.custom_flag_table.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.custom_flag_table.setAlternatingRowColors(False)
        self.custom_flag_table.setShowGrid(False)
        self.custom_flag_table.setEditTriggers(
            QAbstractItemView.EditTrigger.DoubleClicked
            | QAbstractItemView.EditTrigger.SelectedClicked
            | QAbstractItemView.EditTrigger.EditKeyPressed
        )
        self.custom_flag_table.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.custom_flag_table.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.custom_flag_table.customContextMenuRequested.connect(self._remove_custom_flag_at_position)
        header_view = self.custom_flag_table.horizontalHeader()
        header_view.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        header_view.setSectionResizeMode(1, QHeaderView.ResizeMode.Fixed)
        header_view.setSectionResizeMode(2, QHeaderView.ResizeMode.Fixed)
        header_view.setSectionResizeMode(3, QHeaderView.ResizeMode.Fixed)
        self.custom_flag_table.setColumnWidth(1, 170)
        self.custom_flag_table.setColumnWidth(2, 76)
        self.custom_flag_table.setColumnWidth(3, 310)
        self.custom_flag_table.cellChanged.connect(self._custom_flag_table_changed)
        self.custom_flag_table.cellClicked.connect(self._begin_custom_flag_edit)
        self.custom_flag_table.verticalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Fixed)
        self.custom_flag_table.verticalHeader().setMinimumSectionSize(54)
        self.custom_flag_table.verticalHeader().setDefaultSectionSize(54)
        root.addWidget(self.custom_flag_table, 1)

        return page

    def _parse_custom_fastflag_editor(self):
        return normalize_fastflags(self.owner.load_custom_fastflags())

    def _set_custom_flag_status(self, text="", invalid=False):
        self.custom_flag_status.setText(text if invalid else "")
        self.custom_flag_status.setVisible(bool(invalid and text))

    def _custom_flags_from_table(self):
        flags = {}
        for row in range(self.custom_flag_table.rowCount()):
            name_item = self.custom_flag_table.item(row, 0)
            value_item = self.custom_flag_table.item(row, 1)
            name = name_item.text().strip() if name_item else ""
            if name:
                flags[name] = value_item.text() if value_item else ""
        return normalize_fastflags(flags)

    def _sync_custom_json_from_saved(self, flags=None):
        return

    def _load_custom_flag_table(self):
        if not hasattr(self, "custom_flag_table"):
            return
        flags = normalize_fastflags(self.owner.load_custom_fastflags())
        state = self.owner.load_custom_fastflag_state()
        disabled = set(state.get("disabled", []))
        bindings = state.get("keybinds", {}) if isinstance(state.get("keybinds"), dict) else {}
        self.custom_flag_table.blockSignals(True)
        try:
            self.custom_flag_table.clearContents()
            self.custom_flag_table.setRowCount(len(flags))
            self._custom_status_buttons = {}
            self._custom_hotkey_buttons = {}
            self._custom_hotkey_reset_buttons = {}
            for row, (name, value) in enumerate(sorted(flags.items(), key=lambda item: item[0].casefold())):
                name_item = QTableWidgetItem(name)
                name_item.setData(Qt.ItemDataRole.UserRole, name)
                name_item.setToolTip("Click to rename this FastFlag")
                value_item = QTableWidgetItem(str(value))
                value_item.setToolTip("Click to edit this value")
                self.custom_flag_table.setItem(row, 0, name_item)
                self.custom_flag_table.setItem(row, 1, value_item)

                status_host = QWidget()
                status_host.setStyleSheet("background:transparent;")
                status_layout = QHBoxLayout(status_host)
                status_layout.setContentsMargins(0, 0, 0, 0)
                status_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
                status_button = FastFlagCheckButton()
                status_button.setChecked(name not in disabled)
                status_button.setToolTip("Enabled" if name not in disabled else "Disabled")
                status_button.toggled.connect(lambda checked, n=name: self._set_custom_flag_enabled(n, checked))
                status_layout.addWidget(status_button)
                self.custom_flag_table.setCellWidget(row, 2, status_host)
                self._custom_status_buttons[name] = status_button

                self.custom_flag_table.setRowHeight(row, 54)
                hotkey_host = QWidget()
                hotkey_host.setStyleSheet("background:transparent;")
                hotkey_layout = QHBoxLayout(hotkey_host)
                hotkey_layout.setContentsMargins(6, 8, 6, 8)
                hotkey_layout.setSpacing(6)
                hotkey_layout.setAlignment(Qt.AlignmentFlag.AlignVCenter)
                hotkey_button = QPushButton(hotkey_text(bindings.get(name)))
                hotkey_button.setMinimumWidth(225)
                hotkey_button.setFixedHeight(30)
                hotkey_button.setObjectName("hotkeyButton")
                hotkey_button.setToolTip("Click to set a global hotkey")
                hotkey_button.clicked.connect(lambda checked=False, n=name: self.edit_custom_fastflag_hotkey(n))
                hotkey_layout.addWidget(hotkey_button, 1)
                hotkey_reset = QPushButton()
                hotkey_reset.setObjectName("hotkeyResetButton")
                hotkey_reset.setToolTip("Clear hotkey")
                hotkey_reset.setFixedSize(30, 30)
                hotkey_reset.setFocusPolicy(Qt.FocusPolicy.NoFocus)
                reset_icon = app_icon("reattach")
                if not reset_icon.isNull():
                    hotkey_reset.setIcon(reset_icon)
                    hotkey_reset.setIconSize(QSize(13, 13))
                hotkey_reset.setEnabled(name in bindings)
                hotkey_reset.clicked.connect(lambda checked=False, n=name: self.clear_custom_fastflag_hotkey(n))
                hotkey_layout.addWidget(hotkey_reset)
                self.custom_flag_table.setCellWidget(row, 3, hotkey_host)
                self._custom_hotkey_buttons[name] = hotkey_button
                self._custom_hotkey_reset_buttons[name] = hotkey_reset
        finally:
            self.custom_flag_table.blockSignals(False)
        self.custom_flag_table.horizontalScrollBar().setValue(0)
        self._filter_custom_flag_rows(self.custom_flag_search.text() if hasattr(self, "custom_flag_search") else "")

    def _filter_custom_flag_rows(self, text=""):
        if not hasattr(self, "custom_flag_table"):
            return
        query = str(text or "").strip().casefold()
        for row in range(self.custom_flag_table.rowCount()):
            name_item = self.custom_flag_table.item(row, 0)
            value_item = self.custom_flag_table.item(row, 1)
            haystack = ((name_item.text() if name_item else "") + " " + (value_item.text() if value_item else "")).casefold()
            self.custom_flag_table.setRowHidden(row, bool(query and query not in haystack))

    def _persist_custom_flag_mapping(self, flags):
        flags = normalize_fastflags(flags)
        previous = normalize_fastflags(self.owner.load_custom_fastflags())
        if flags == previous:
            return False
        proxy_was_needed = self.owner.proxy_features_needed()
        self.owner.save_custom_fastflags(flags)
        state = self.owner.save_custom_fastflag_state(self.owner.load_custom_fastflag_state())
        self.owner.refresh_custom_fastflag_hotkeys()
        self._baseline_custom_flags = dict(flags)
        effective = self.owner.load_effective_fastflags()
        prime_windows_fastflag_cache(effective)
        self.owner.mark_custom_fastflags_changed()
        if not self.owner.proxy_suspended_for_api():
            self.owner.refresh_proxy_for_active_session()
        proxy_is_needed = self.owner.proxy_features_needed()
        if self.owner.roblox_running is True and (not self.owner.roblox_proxy_active or proxy_was_needed != proxy_is_needed):
            self.owner.set_fastflags_restart_required(True)
        self._sync_custom_json_from_saved(flags)
        return True

    def _begin_custom_flag_edit(self, row, column):
        if column not in (0, 1) or self._reloading:
            return
        item = self.custom_flag_table.item(row, column)
        if item is not None:
            QTimer.singleShot(0, lambda i=item: self.custom_flag_table.editItem(i))

    def _rename_custom_fastflag(self, old_name, new_name, value):
        old_name = str(old_name or "").strip()
        new_name = str(new_name or "").strip()
        if not old_name or not new_name or old_name == new_name:
            return False
        flags = self.owner.load_custom_fastflags()
        if new_name in flags and new_name != old_name:
            return False
        state = self.owner.load_custom_fastflag_state()
        flags.pop(old_name, None)
        flags[new_name] = value
        disabled = set(state.get("disabled", []))
        if old_name in disabled:
            disabled.discard(old_name)
            disabled.add(new_name)
        bindings = dict(state.get("keybinds", {}))
        binding = bindings.pop(old_name, None)
        if binding is not None:
            bindings[new_name] = binding
        self.owner.save_custom_fastflags(flags)
        self.owner.save_custom_fastflag_state({"disabled": sorted(disabled), "keybinds": bindings})
        self.owner.refresh_custom_fastflag_hotkeys()
        self._baseline_custom_flags = normalize_fastflags(flags)
        prime_windows_fastflag_cache(self.owner.load_effective_fastflags())
        self.owner.mark_custom_fastflags_changed()
        if not self.owner.proxy_suspended_for_api():
            self.owner.refresh_proxy_for_active_session()
        if self.owner.roblox_running is True and not self.owner.roblox_proxy_active:
            self.owner.set_fastflags_restart_required(True)
        self._sync_custom_json_from_saved(flags)
        return True

    def _custom_flag_table_changed(self, row, column):
        if self._reloading or column not in (0, 1):
            return
        name_item = self.custom_flag_table.item(row, 0)
        value_item = self.custom_flag_table.item(row, 1)
        if name_item is None:
            return
        current_name = name_item.text().strip()
        original_name = str(name_item.data(Qt.ItemDataRole.UserRole) or current_name).strip()
        value = value_item.text() if value_item is not None else ""
        if column == 0:
            if not current_name:
                self.custom_flag_table.blockSignals(True)
                try:
                    name_item.setText(original_name)
                finally:
                    self.custom_flag_table.blockSignals(False)
                return
            if current_name != original_name:
                if current_name in self.owner.load_custom_fastflags():
                    self.custom_flag_table.blockSignals(True)
                    try:
                        name_item.setText(original_name)
                    finally:
                        self.custom_flag_table.blockSignals(False)
                    self._set_custom_flag_status("A FastFlag with that name already exists.", True)
                    return
                if self._rename_custom_fastflag(original_name, current_name, value):
                    self._set_custom_flag_status()
                    self._load_custom_flag_table()
                return
        flags = self.owner.load_custom_fastflags()
        if current_name:
            flags[current_name] = value
            self._persist_custom_flag_mapping(flags)


    def _set_custom_flag_enabled(self, name, enabled):
        if self._reloading:
            return
        state = self.owner.load_custom_fastflag_state()
        disabled = set(state.get("disabled", []))
        if enabled:
            disabled.discard(name)
        else:
            disabled.add(name)
        state["disabled"] = sorted(disabled)
        self.owner.save_custom_fastflag_state(state)
        self.owner.refresh_custom_fastflag_hotkeys()
        self.owner.mark_custom_fastflags_changed()
        if not self.owner.proxy_suspended_for_api():
            self.owner.refresh_proxy_for_active_session()
        if self.owner.roblox_running is True and not self.owner.roblox_proxy_active:
            self.owner.set_fastflags_restart_required(True)
        button = getattr(self, "_custom_status_buttons", {}).get(name)
        if button is not None:
            button.setToolTip("Enabled" if enabled else "Disabled")

    def clear_custom_fastflag_hotkey(self, name):
        state = self.owner.load_custom_fastflag_state()
        bindings = dict(state.get("keybinds", {}))
        if name not in bindings:
            return
        bindings.pop(name, None)
        state["keybinds"] = bindings
        state = self.owner.save_custom_fastflag_state(state)
        self.owner.refresh_custom_fastflag_hotkeys()
        button = getattr(self, "_custom_hotkey_buttons", {}).get(name)
        reset = getattr(self, "_custom_hotkey_reset_buttons", {}).get(name)
        if button is not None:
            button.setText(hotkey_text(None))
        if reset is not None:
            reset.setEnabled(False)

    def add_catalog_fastflags(self, additions):
        additions = normalize_fastflags(additions)
        if not additions:
            return
        flags = self.owner.load_custom_fastflags()
        flags.update(additions)
        self._persist_custom_flag_mapping(flags)
        self._load_custom_flag_table()

    def open_fastflag_list(self):
        dialog = FastFlagListDialog(self)
        dialog.exec()

    def edit_custom_fastflag_hotkey(self, name):
        if sys.platform != "win32":
            QMessageBox.information(self, "FastFlag Hotkey", "Global FastFlag hotkeys are currently available on Windows.")
            return
        dialog = FastFlagHotkeyCaptureDialog(name, self)
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return
        state = self.owner.load_custom_fastflag_state()
        bindings = dict(state.get("keybinds", {}))
        if dialog.clear_requested:
            bindings.pop(name, None)
        elif dialog.binding is not None:
            bindings[name] = dialog.binding
        state["keybinds"] = bindings
        state = self.owner.save_custom_fastflag_state(state)
        self.owner.refresh_custom_fastflag_hotkeys()
        button = getattr(self, "_custom_hotkey_buttons", {}).get(name)
        reset = getattr(self, "_custom_hotkey_reset_buttons", {}).get(name)
        current_binding = state.get("keybinds", {}).get(name)
        if button is not None:
            button.setText(hotkey_text(current_binding))
        if reset is not None:
            reset.setEnabled(current_binding is not None)

    def add_custom_fastflag(self):
        tracker_url = "https://raw.githubusercontent.com/MaximumADHD/Roblox-FFlag-Tracker/main/PCDesktopClient.json"
        tracker_flags = {}
        try:
            request = urllib.request.Request(
                tracker_url,
                headers={"User-Agent": "LelSploit-FastFlags/1.0"},
            )
            with urllib.request.urlopen(request, timeout=8) as response:
                remote_data = json.loads(response.read().decode("utf-8"))
            if isinstance(remote_data, dict):
                tracker_flags = {str(flag_name): flag_value for flag_name, flag_value in remote_data.items()}
        except Exception as exc:
            self.owner.log(f"Could not load Roblox FFlag Tracker suggestions: {exc}", "warning")

        dialog = QDialog(self)
        dialog.setObjectName("addCustomFastFlagDialog")
        dialog.setWindowTitle("Add Custom FastFlag")
        dialog.resize(570, 390)
        dialog.setMinimumSize(500, 330)
        apply_window_icon(dialog)
        root = blur_content_layout(dialog, dialog, "Add Custom FastFlag", (16, 12, 16, 16), 9)

        name = QLineEdit()
        name.setPlaceholderText("FastFlag name — type anything or choose a suggestion")
        root.addWidget(name)
        suggestions = QListWidget()
        suggestions.setObjectName("fastFlagSuggestions")
        suggestions.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        root.addWidget(suggestions, 1)
        value = QLineEdit()
        value.setPlaceholderText("Value")
        root.addWidget(value)

        actions = QHBoxLayout()
        add = QPushButton("Add")
        cancel = QPushButton("Cancel")
        actions.addStretch(1)
        actions.addWidget(cancel)
        actions.addWidget(add)
        root.addLayout(actions)

        def value_text(raw_value):
            if isinstance(raw_value, bool):
                return "true" if raw_value else "false"
            if raw_value is None:
                return ""
            return str(raw_value)

        def update_suggestions(text_value=""):
            query = str(text_value or "").strip().casefold()
            suggestions.clear()
            matches = []
            for flag_name, flag_value in tracker_flags.items():
                if query and query not in flag_name.casefold():
                    continue
                matches.append((flag_name, flag_value))
            matches.sort(key=lambda item: (0 if item[0].casefold().startswith(query) else 1, item[0].casefold()))
            for flag_name, flag_value in matches[:80]:
                item = QListWidgetItem(flag_name)
                item.setData(Qt.ItemDataRole.UserRole, flag_name)
                item.setToolTip(f"Current tracker value: {value_text(flag_value)}")
                suggestions.addItem(item)

        def choose_item(item):
            if item is None:
                return
            flag_name = str(item.data(Qt.ItemDataRole.UserRole) or item.text()).strip()
            name.setText(flag_name)
            if not value.text().strip():
                value.setText(value_text(tracker_flags.get(flag_name, "")))
            value.setFocus()
            value.selectAll()

        name.textChanged.connect(update_suggestions)
        suggestions.itemClicked.connect(choose_item)
        suggestions.itemDoubleClicked.connect(lambda item: (choose_item(item), dialog.accept()))
        add.clicked.connect(dialog.accept)
        cancel.clicked.connect(dialog.reject)
        name.returnPressed.connect(lambda: value.setFocus())
        value.returnPressed.connect(dialog.accept)

        dialog.setStyleSheet(r'''
            QDialog#addCustomFastFlagDialog { background:#0b0c0d; color:#dedede; }
            QWidget { color:#dedede; }
            QLabel { background:transparent; }
            QLineEdit { background:#0d0d0e; color:#ededed; border:1px solid #2a2a2d; border-radius:6px; min-height:33px; padding:0 9px; }
            QLineEdit:focus { background:#101012; border-color:#45454a; }
            QListWidget#fastFlagSuggestions { background:#080809; border:1px solid #252528; border-radius:7px; padding:3px; outline:0; }
            QListWidget#fastFlagSuggestions::item { min-height:27px; padding:3px 8px; border-radius:5px; }
            QListWidget#fastFlagSuggestions::item:hover { background:#121214; }
            QListWidget#fastFlagSuggestions::item:selected { background:#1d1e21; color:#fff; }
            QPushButton { background:#111113; color:#e9e9e9; border:1px solid #2a2a2d; border-radius:6px; padding:6px 11px; }
            QPushButton:hover { background:#19191c; border-color:#414146; }
        ''')
        apply_blur_style(dialog)
        update_suggestions()
        name.setFocus()
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return
        key = name.text().strip()
        if not key:
            QMessageBox.warning(self, "Custom FastFlags", "FastFlag name cannot be empty.")
            return
        flags = self.owner.load_custom_fastflags()
        flags[key] = value.text()
        self._persist_custom_flag_mapping(flags)
        self._load_custom_flag_table()

    def _remove_custom_flag_at_position(self, position):
        row = self.custom_flag_table.rowAt(position.y())
        if row < 0:
            return
        self.custom_flag_table.clearSelection()
        self.custom_flag_table.selectRow(row)
        self.remove_selected_custom_fastflags()

    def remove_selected_custom_fastflags(self):
        rows = sorted({index.row() for index in self.custom_flag_table.selectionModel().selectedRows()}, reverse=True)
        if not rows:
            return
        names = []
        for row in rows:
            item = self.custom_flag_table.item(row, 0)
            if item:
                names.append(item.text())
        flags = self.owner.load_custom_fastflags()
        for name in names:
            flags.pop(name, None)
        if self._persist_custom_flag_mapping(flags):
            self._load_custom_flag_table()

    def schedule_custom_fastflag_save(self, *_):
        if self._reloading:
            return
        try:
            self._parse_custom_fastflag_editor()
        except Exception as exc:
            self._set_custom_flag_status(str(exc), True)
            return
        self._set_custom_flag_status()

    def persist_custom_fastflags(self, *_):
        if self._reloading:
            return
        try:
            flags = self._parse_custom_fastflag_editor()
        except Exception as exc:
            self._set_custom_flag_status(str(exc), True)
            return
        self._set_custom_flag_status()
        if self._persist_custom_flag_mapping(flags):
            self._load_custom_flag_table()
        self.update_change_state()

    def import_custom_fastflags(self):
        path, _ = QFileDialog.getOpenFileName(self, "Import FastFlags", "", "JSON (*.json);;All files (*)")
        if not path:
            return
        try:
            payload = read_json_object(path, {})
            if not isinstance(payload, dict):
                raise ValueError("The JSON root must be an object of FastFlag name/value pairs.")
            flags = normalize_fastflags(payload)
            self._persist_custom_flag_mapping(flags)
            self._load_custom_flag_table()
            self._sync_custom_json_from_saved(flags)
        except Exception as exc:
            QMessageBox.warning(self, "Custom FastFlags", str(exc))

    def export_custom_fastflags(self):
        flags = self.owner.load_custom_fastflags()
        path, _ = QFileDialog.getSaveFileName(self, "Export FastFlags", "custom_fastflags.json", "JSON (*.json)")
        if path:
            write_json_object(path, flags)

    def update_attached_state(self):
        if self.owner.api_attached:
            self.attached_label.setText(
                'LelSploit is currently attached to Roblox. Live FastFlags and proxy features are unavailable in this session. '
                '<a href="detach" style="color:#79b8ff;text-decoration:none;"><b>Detach & restart</b></a>'
            )
            self.attached_banner.setVisible(True)
            return
        if (
            self.owner.roblox_running is True
            and self.owner.proxy_features_needed()
            and self.owner.roblox_session_mode == "attach"
            and not getattr(self.owner, "_fastflags_detach_restart_in_progress", False)
        ):
            self.attached_label.setText(
                'Roblox is running in Attach mode. Roblox must restart before live FastFlags can use the client proxy. '
                '<a href="proxy_restart" style="color:#79b8ff;text-decoration:none;"><b>Restart now</b></a>'
            )
            self.attached_banner.setVisible(True)
            return
        self.attached_banner.hide()

    @staticmethod
    def _default_spin(minimum, maximum):
        spin = QSpinBox()
        spin.setRange(minimum - 1, maximum)
        spin.setSpecialValueText("Default")
        spin.setValue(minimum - 1)
        spin.setFixedWidth(190)
        return spin

    def build_assets_page(self):
        page = QWidget(); page.setObjectName("assetsPage"); page.setAutoFillBackground(False); root = QVBoxLayout(page); root.setContentsMargins(0,0,0,0)
        scroll = QScrollArea(); scroll.setWidgetResizable(True)
        content = QWidget(); layout = QVBoxLayout(content); layout.setContentsMargins(1,1,1,1); layout.setSpacing(7)
        font_title = QLabel("Custom Font"); font_title.setObjectName("sectionTitle"); layout.addWidget(font_title)
        font_row = ModificationSourceRow(self, "Custom Font", "__font__", "font")
        self.asset_rows.append(font_row); layout.addWidget(font_row)
        for category, items in ASSET_TARGETS.items():
            title = QLabel(category); title.setObjectName("sectionTitle"); layout.addWidget(title)
            if category == "Skyboxes":
                apply_all = QPushButton("Apply to all Sky faces")
                apply_all.setObjectName("flatButton")
                apply_all.clicked.connect(self.apply_all_sky_faces)
                layout.addWidget(apply_all, 0, Qt.AlignmentFlag.AlignLeft)
            for label, target in items.items():
                row = ModificationSourceRow(self, label, target, "asset")
                self.asset_rows.append(row); layout.addWidget(row)
        layout.addStretch(1); scroll.setWidget(content); root.addWidget(scroll,1)
        return page

    def apply_all_sky_faces(self):
        path, _ = QFileDialog.getOpenFileName(self, "Choose skybox source", "", "All files (*)")
        if not path:
            return
        targets = [(label, target) for label, target in ASSET_TARGETS["Skyboxes"].items() if label.startswith("Sky —")]
        errors = []
        for label, target in targets:
            try: set_modification(label, target, path, "asset")
            except Exception as exc: errors.append(str(exc))
        for row in self.asset_rows: row.refresh()
        self.owner.set_fastflags_restart_required(self.owner.roblox_running is True)
        if errors: QMessageBox.warning(self, "Skybox", errors[0])
        else: self.owner.log("Applied source to all default sky faces.", "success")

    def build_username_page(self):
        page = QWidget()
        page.setObjectName("usernamePage")
        page.setAutoFillBackground(False)
        layout = QVBoxLayout(page)
        layout.setContentsMargins(14, 12, 14, 14)
        layout.setSpacing(14)

        heading = QHBoxLayout()
        title = QLabel("Username Spoofer")
        title.setStyleSheet("font-size:14px;font-weight:600;color:#f1f1f1;background:transparent;")
        heading.addWidget(title)
        heading.addStretch(1)
        layout.addLayout(heading)

        card = QFrame()
        card.setObjectName("usernameSpoofCard")
        card.setStyleSheet(
            "QFrame#usernameSpoofCard { background:#0c0c0c; border:1px solid #242424; border-radius:8px; }"
        )
        card_layout = QVBoxLayout(card)
        card_layout.setContentsMargins(12, 12, 12, 12)
        card_layout.setSpacing(10)

        grid = QGridLayout()
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setHorizontalSpacing(14)
        grid.setVerticalSpacing(10)
        grid.setColumnMinimumWidth(0, 92)
        grid.setColumnStretch(1, 1)
        grid.setColumnMinimumWidth(2, 112)
        grid.setColumnMinimumWidth(3, 82)

        everyone_label = QLabel("Everyone Else")
        everyone_label.setStyleSheet("background:transparent;color:#d8d8d8;")
        grid.addWidget(everyone_label, 0, 0, Qt.AlignmentFlag.AlignVCenter)
        self.spoof_others = QLineEdit()
        self.spoof_others.setPlaceholderText("Spoofed username")
        self.spoof_others.setMinimumHeight(34)
        grid.addWidget(self.spoof_others, 0, 1)
        self.spoof_others_apply = BrightCheckBox("Apply Ingame")
        grid.addWidget(self.spoof_others_apply, 0, 2, Qt.AlignmentFlag.AlignVCenter)
        self.spoof_others_verified = BrightCheckBox("Verified")
        grid.addWidget(self.spoof_others_verified, 0, 3, Qt.AlignmentFlag.AlignVCenter)

        yours_label = QLabel("Your Username")
        yours_label.setStyleSheet("background:transparent;color:#d8d8d8;")
        grid.addWidget(yours_label, 1, 0, Qt.AlignmentFlag.AlignVCenter)
        self.spoof_yours = QLineEdit()
        self.spoof_yours.setPlaceholderText("Spoofed username")
        self.spoof_yours.setMinimumHeight(34)
        grid.addWidget(self.spoof_yours, 1, 1)
        self.spoof_yours_apply = BrightCheckBox("Apply Ingame")
        grid.addWidget(self.spoof_yours_apply, 1, 2, Qt.AlignmentFlag.AlignVCenter)
        self.spoof_yours_verified = BrightCheckBox("Verified")
        grid.addWidget(self.spoof_yours_verified, 1, 3, Qt.AlignmentFlag.AlignVCenter)
        card_layout.addLayout(grid)

        divider = QFrame()
        divider.setFixedHeight(1)
        divider.setStyleSheet("background:#202020;border:0;")
        card_layout.addWidget(divider)

        self.spoof_creator = BrightCheckBox("Make Yourself Game Creator")
        card_layout.addWidget(self.spoof_creator, 0, Qt.AlignmentFlag.AlignLeft)
        layout.addWidget(card)

        layout.addStretch(1)

        for control in (self.spoof_others, self.spoof_others_apply, self.spoof_others_verified,
                        self.spoof_yours, self.spoof_yours_apply, self.spoof_yours_verified, self.spoof_creator):
            signal = getattr(control, "textChanged", None) or getattr(control, "toggled", None)
            if signal is not None:
                signal.connect(self.schedule_username_persist)
        return page

    def _username_settings(self):
        return {
            "save": True,
            "others_username": self.spoof_others.text().strip(),
            "others_apply": self.spoof_others_apply.isChecked(),
            "others_verified": self.spoof_others_verified.isChecked(),
            "your_username": self.spoof_yours.text().strip(),
            "your_apply": self.spoof_yours_apply.isChecked(),
            "your_verified": self.spoof_yours_verified.isChecked(),
            "make_creator": self.spoof_creator.isChecked(),
        }

    def schedule_username_persist(self, *_):
        if not self._reloading:
            self.username_save_timer.start()

    def persist_username_spoofer(self, *_):
        if self._reloading:
            return
        settings = self._username_settings()
        changed = settings != self._baseline_username_settings
        save_username_spoofer_settings(settings)
        save_username_proxy_runtime(settings)
        self._baseline_username_settings = dict(settings)
        if changed and self.owner.roblox_running is True:
            self.owner.set_fastflags_restart_required(True)
            self.update_change_state()

    def build_custom_page(self):
        page = QWidget()
        page.setObjectName("customModsPage")
        page.setAutoFillBackground(False)
        layout = QVBoxLayout(page)
        layout.setContentsMargins(4, 4, 4, 4)
        layout.setSpacing(12)
        top = QHBoxLayout()
        top.setContentsMargins(0, 0, 0, 0)
        title = QLabel("Custom Modifications")
        title.setStyleSheet("font-size:14px;font-weight:600;color:#eee;background:transparent;")
        top.addWidget(title)
        top.addStretch(1)
        add = QPushButton("Add modification")
        add.setFixedHeight(32)
        add.clicked.connect(self.add_custom_modification)
        top.addWidget(add)
        layout.addLayout(top)
        self.custom_scroll = QScrollArea()
        self.custom_scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.custom_scroll.setWidgetResizable(True)
        self.custom_scroll.setStyleSheet("QScrollArea{border:0;background:transparent;} QScrollArea QWidget{background:transparent;}")
        self.custom_content = QWidget()
        self.custom_content.setStyleSheet("background:transparent;")
        self.custom_layout = QVBoxLayout(self.custom_content)
        self.custom_layout.setContentsMargins(0, 0, 0, 0)
        self.custom_layout.setSpacing(8)
        self.custom_empty = QLabel("No custom modifications yet.")
        self.custom_empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.custom_empty.setStyleSheet("color:#666;background:transparent;padding:28px;")
        self.custom_layout.addWidget(self.custom_empty)
        self.custom_layout.addStretch(1)
        self.custom_scroll.setWidget(self.custom_content)
        layout.addWidget(self.custom_scroll, 1)
        return page

    def add_custom_modification(self):
        dialog = CustomModificationDialog(self)
        if dialog.exec() != QDialog.DialogCode.Accepted: return
        try:
            set_modification(dialog.display_name.text().strip(), dialog.target.text().strip(), dialog.source.text().strip(), "custom")
            self.owner.set_fastflags_restart_required(self.owner.roblox_running is True)
            self.owner.log(f"Applied {dialog.display_name.text().strip()}.", "success")
            self.refresh_custom_mods()
        except Exception as exc:
            QMessageBox.warning(self, "Custom Modification", str(exc))

    def refresh_custom_mods(self):
        if not hasattr(self, "custom_layout"):
            return
        while self.custom_layout.count() > 1:
            item = self.custom_layout.takeAt(0)
            widget = item.widget()
            if widget is not None and widget is not getattr(self, "custom_empty", None):
                widget.deleteLater()
        entries = [entry for entry in _read_modifications_data().get("entries", []) if entry.get("kind") == "custom"]
        self.custom_empty.setVisible(not entries)
        if self.custom_layout.indexOf(self.custom_empty) < 0:
            self.custom_layout.insertWidget(0, self.custom_empty)
        insert_at = 1 if self.custom_empty.isVisible() else 0
        for entry in entries:
            card = QFrame()
            card.setObjectName("modRow")
            row = QHBoxLayout(card)
            row.setContentsMargins(12, 9, 10, 9)
            details = QVBoxLayout()
            name = QLabel(str(entry.get("display_name") or "Modification"))
            name.setStyleSheet("color:#eee;font-weight:600;background:transparent;")
            details.addWidget(name)
            target = QLabel(str(entry.get("target") or ""))
            target.setStyleSheet("color:#777;font-size:10px;background:transparent;")
            details.addWidget(target)
            row.addLayout(details, 1)
            remove = QPushButton("Remove")
            remove.setFixedWidth(72)
            remove.clicked.connect(lambda checked=False, target=entry.get("target"): self.remove_custom_mod(target))
            row.addWidget(remove)
            self.custom_layout.insertWidget(insert_at, card)
            insert_at += 1

    def remove_custom_mod(self, target):
        try:
            remove_modification(target); self.owner.set_fastflags_restart_required(self.owner.roblox_running is True); self.refresh_custom_mods()
        except Exception as exc: QMessageBox.warning(self, "Custom Modification", str(exc))

    def _update_slider_labels(self, *_):
        value = self.mesh_slider.value(); self.mesh_value.setText("Default" if value == 0 else f"Level {value-1}")
        value = self.frm_slider.value(); self.frm_value.setText("Default" if value == 0 else f"Quality {value}")

    def on_manager_toggled(self, enabled):
        self.managed_panel.setVisible(bool(enabled)); self.update_change_state()

    def reload(self):
        self._reloading = True
        try:
            self.current_flags = self.owner.load_fastflags(); keys = FASTFLAG_KEYS; enabled = self.owner.fastflags_enabled()
            self.manager_check.setChecked(enabled); self.managed_panel.setVisible(enabled)
            mode = None
            if self.current_flags.get(keys["render_d3d11"]) == "True": mode = "D3D11"
            elif self.current_flags.get(keys["render_vulkan"]) == "True": mode = "Vulkan"
            elif self.current_flags.get(keys["render_opengl"]) == "True": mode = "OpenGL"
            self.render_combo.setCurrentIndex(max(0, self.render_combo.findData(mode)))
            self.msaa_combo.setCurrentIndex(max(0, self.msaa_combo.findData(self.current_flags.get(keys["msaa"]))))
            self.scaling_check.setChecked(self.current_flags.get(keys["display_scaling"]) == "True")
            self.fullscreen_check.setChecked(self.current_flags.get(keys["manual_fullscreen"]) == "True")
            self.texture_combo.setCurrentIndex(max(0, self.texture_combo.findData(self.current_flags.get(keys["texture_level"]))))
            static = self.current_flags.get(keys["lod_static"])
            self.mesh_check.setChecked(static is not None)
            self.mesh_slider.setValue(max(0, min(4, int(static)+1)) if str(static).lstrip("-").isdigit() else 0)
            frm = self.current_flags.get(keys["frm_quality"])
            self.frm_check.setChecked(frm is not None)
            self.frm_slider.setValue(max(0, min(21, int(frm))) if str(frm).isdigit() else 0)
            self.grey_sky_check.setChecked(self.current_flags.get(keys["grey_sky"]) == "True")
            self.pause_voxelizer_check.setChecked(self.current_flags.get(keys["pause_voxelizer"]) == "True")
            for spin, key in ((self.grass_max,"grass_max"),(self.grass_min,"grass_min"),(self.grass_motion,"grass_motion")):
                value = self.current_flags.get(keys[key]); spin.setValue(int(value) if str(value).lstrip("-").isdigit() else spin.minimum())
            saved_fps = self.owner.settings.value("global/framerate_cap", None)
            if saved_fps is None: saved_fps = read_roblox_framerate_cap() or 0
            try: saved_fps = int(saved_fps)
            except (TypeError, ValueError): saved_fps = 0
            self.fps_cap.setValue(max(0,min(1000,saved_fps)))
            self._baseline_fps = self.fps_cap.value(); self._baseline_flags = normalize_fastflags(self.current_flags); self._baseline_enabled = bool(enabled)
            custom_flags = self.owner.load_custom_fastflags()
            self._sync_custom_json_from_saved(custom_flags)
            self._baseline_custom_flags = normalize_fastflags(custom_flags)
            self._load_custom_flag_table()
            self._update_slider_labels()
            saved = load_username_spoofer_settings()
            self.spoof_others.setText(str(saved.get("others_username", ""))); self.spoof_others_apply.setChecked(bool(saved.get("others_apply")))
            self.spoof_others_verified.setChecked(bool(saved.get("others_verified"))); self.spoof_yours.setText(str(saved.get("your_username", ""))); self.spoof_yours_apply.setChecked(bool(saved.get("your_apply")))
            self.spoof_yours_verified.setChecked(bool(saved.get("your_verified"))); self.spoof_creator.setChecked(bool(saved.get("make_creator")))
            self._baseline_username_settings = dict(self._username_settings())
            for row in self.asset_rows: row.refresh()
            self.refresh_custom_mods()
        finally:
            self._reloading = False
        self.update_attached_state()
        self.update_change_state()

    def collect_flags(self):
        flags = dict(self.current_flags); keys = FASTFLAG_KEYS
        for key in keys.values(): flags.pop(key, None)
        mode = self.render_combo.currentData()
        if mode:
            flags[keys[{"D3D11":"render_d3d11","Vulkan":"render_vulkan","OpenGL":"render_opengl"}[mode]]] = "True"
            if mode in ("Vulkan", "OpenGL"): flags[keys["render_disable_d3d11"]] = "True"
        msaa = self.msaa_combo.currentData()
        if msaa is not None: flags[keys["msaa"]] = str(msaa)
        if self.scaling_check.isChecked(): flags[keys["display_scaling"]] = "True"
        if self.fullscreen_check.isChecked(): flags[keys["manual_fullscreen"]] = "True"
        texture = self.texture_combo.currentData()
        if texture is not None: flags[keys["texture_enabled"]] = "True"; flags[keys["texture_level"]] = str(texture)
        if self.mesh_check.isChecked() and self.mesh_slider.value() > 0:
            level = self.mesh_slider.value()
            for i, key in enumerate(("lod_l0","lod_l12","lod_l23","lod_l34")):
                flags[keys[key]] = str(max(0,min(level-1-i,3)))
            flags[keys["lod_static"]] = str(level-1)
        if self.frm_check.isChecked() and self.frm_slider.value() > 0: flags[keys["frm_quality"]] = str(self.frm_slider.value())
        if self.grey_sky_check.isChecked(): flags[keys["grey_sky"]] = "True"
        if self.pause_voxelizer_check.isChecked(): flags[keys["pause_voxelizer"]] = "True"
        for spin, key in ((self.grass_max,"grass_max"),(self.grass_min,"grass_min"),(self.grass_motion,"grass_motion")):
            if spin.value() > spin.minimum(): flags[keys[key]] = str(spin.value())
        return normalize_fastflags(flags)

    def has_unsaved_changes(self):
        return not self._reloading and (bool(self.manager_check.isChecked()) != self._baseline_enabled or self.collect_flags() != self._baseline_flags or self.fps_cap.value() != self._baseline_fps)

    def update_change_state(self, *_):
        if self._reloading:
            return
        dirty = self.has_unsaved_changes()
        self.restart_bar.setVisible(
            self.owner.roblox_running is True
            and (dirty or self.owner.fastflags_restart_required())
        )
        if dirty:
            self.auto_save_timer.start()

    def save_changes(self, _checked=False, quiet=False):
        flags = self.collect_flags(); enabled = self.manager_check.isChecked(); changed = flags != self._baseline_flags or enabled != self._baseline_enabled
        fps_changed = self.fps_cap.value() != self._baseline_fps
        if enabled != self._baseline_enabled and not enabled: self.owner.set_fastflags_enabled(False)
        if flags != self._baseline_flags: self.current_flags = self.owner.save_fastflags(flags)
        else: self.current_flags = dict(flags)
        if enabled != self._baseline_enabled and enabled: self.owner.set_fastflags_enabled(True)
        elif enabled and flags != self._baseline_flags: self.owner.request_fastflag_sync(force=True)
        if fps_changed:
            value = self.fps_cap.value()
            self.owner.settings.setValue("global/framerate_cap", value)
            self.owner.settings.sync()
            if self.owner.roblox_running is not True:
                self.owner.apply_saved_framerate_cap()
        self._baseline_flags = normalize_fastflags(self.current_flags); self._baseline_enabled = bool(enabled); self._baseline_fps = self.fps_cap.value()
        if changed or fps_changed:
            self.owner.set_fastflags_restart_required(self.owner.roblox_running is True)
            if enabled:
                prime_windows_fastflag_cache(self.owner.load_effective_fastflags())
                self.owner.refresh_proxy_for_active_session()
        if not quiet and (changed or fps_changed): self.owner.log("Client settings saved.", "success")
        self.update_change_state(); return changed or fps_changed

    def reset_configuration(self):
        self.render_combo.setCurrentIndex(0); self.msaa_combo.setCurrentIndex(0); self.scaling_check.setChecked(False); self.fullscreen_check.setChecked(False); self.texture_combo.setCurrentIndex(0)
        self.mesh_check.setChecked(False); self.mesh_slider.setValue(0); self.frm_check.setChecked(False); self.frm_slider.setValue(0); self.grey_sky_check.setChecked(False); self.pause_voxelizer_check.setChecked(False)
        for spin in (self.grass_max,self.grass_min,self.grass_motion): spin.setValue(spin.minimum())
        self.fps_cap.setValue(0); self.update_change_state()

    def restart_now(self, _link="restart"):
        self.save_changes(quiet=True); self.owner.restart_roblox_from_fastflags() if self.owner.roblox_running is True else self.update_change_state()

    def closeEvent(self, event):
        try: self.save_changes(quiet=True); self.persist_username_spoofer(); self.persist_custom_fastflags()
        except Exception as exc: self.owner.log(f"Could not save client settings: {exc}", "warning")
        event.accept()


