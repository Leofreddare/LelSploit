




import ast
import base64
import codecs
import csv
import hashlib
import html
import ipaddress
import json
import math
import queue
import random
import re
import socket
import statistics
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
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

class HoverCopyButton(QPushButton):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._opacity = QGraphicsOpacityEffect(self)
        self._opacity.setOpacity(0.72)
        self.setGraphicsEffect(self._opacity)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.setFixedSize(26, 26)
        self.setIcon(app_icon("copy"))
        self.setIconSize(QSize(14, 14))
        self.setStyleSheet("""
            QPushButton {
                background: transparent;
                border: 0;
                border-radius: 5px;
                padding: 0;
            }
            QPushButton:hover { background: #1b1b1b; }
            QPushButton:pressed { background: #121212; }
        """)

    def enterEvent(self, event):
        self._opacity.setOpacity(1.0)
        self.setIconSize(QSize(16, 16))
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._opacity.setOpacity(0.72)
        self.setIconSize(QSize(14, 14))
        super().leaveEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self._opacity.setOpacity(0.55)
            self.setIconSize(QSize(12, 12))
        super().mousePressEvent(event)

    def mouseReleaseEvent(self, event):
        super().mouseReleaseEvent(event)
        if event.button() == Qt.MouseButton.LeftButton:
            self._opacity.setOpacity(1.0 if self.underMouse() else 0.72)
            self.setIconSize(QSize(13, 13))
            QTimer.singleShot(
                85,
                lambda: self.setIconSize(QSize(16, 16) if self.underMouse() else QSize(14, 14)),
            )


class HoverCopyLineEdit(QLineEdit):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._copy_button = HoverCopyButton(self)
        self._copy_button.hide()
        self._copy_button.clicked.connect(self.copy_result)
        self.textChanged.connect(self._sync_copy_button)
        self.setMouseTracking(True)
        self.setTextMargins(0, 0, 30, 0)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        x = max(2, self.width() - self._copy_button.width() - 5)
        y = max(0, (self.height() - self._copy_button.height()) // 2)
        self._copy_button.move(x, y)
        self._copy_button.raise_()

    def enterEvent(self, event):
        self._sync_copy_button()
        super().enterEvent(event)

    def leaveEvent(self, event):
        super().leaveEvent(event)
        QTimer.singleShot(0, self._sync_copy_button)

    def _sync_copy_button(self, *_):
        visible = bool(self.text()) and (self.underMouse() or self._copy_button.underMouse())
        self._copy_button.setVisible(visible)
        if visible:
            self._copy_button.raise_()

    def copy_result(self):
        value = self.text()
        if value:
            QApplication.clipboard().setText(value)


class ToolsWindow(QDialog):
    TOOL_NAMES = ("Loadstring Reverser", "Loadstring Creator", "GitHub Rawifier", "Deobfuscate")

    def __init__(self, parent):
        super().__init__(parent)
        self.setWindowTitle("Tools")
        self.resize(760, 560)
        self.setMinimumSize(600, 420)
        apply_window_icon(self)

        self.owner = parent
        self.events = queue.Queue(maxsize=16)
        self.fetch_cancel = None
        self.request_id = 0
        self.fetch_url = ""

        layout = blur_content_layout(self, self, "Tools", (16, 16, 16, 16), 10)

        nav = QHBoxLayout()
        nav.setContentsMargins(0, 0, 0, 0)
        nav.setSpacing(6)
        self.tool_group = QButtonGroup(self)
        self.tool_group.setExclusive(True)
        self.tool_buttons = []
        for index, name in enumerate(self.TOOL_NAMES):
            button = QPushButton(name)
            button.setObjectName("toolNavButton")
            button.setCheckable(True)
            button.clicked.connect(lambda checked=False, i=index: self.select_tool(i))
            self.tool_group.addButton(button, index)
            self.tool_buttons.append(button)
            nav.addWidget(button)
        nav.addStretch(1)
        layout.addLayout(nav)

        self.tool_stack = QStackedWidget()
        self.tool_stack.setObjectName("toolStack")
        layout.addWidget(self.tool_stack, 1)

        self._build_reverser_page()
        self._build_creator_page()
        self._build_github_page()
        self._build_deobfuscate_page()
        self.select_tool(0)

        self.poll_timer = QTimer(self)
        self.poll_timer.setInterval(30)
        self.poll_timer.timeout.connect(self.poll_fetch)
        self.poll_timer.start()

        self.deob_timer = QTimer(self)
        self.deob_timer.setInterval(40)
        self.deob_timer.timeout.connect(self.poll_deobfuscate)
        self.deob_timer.start()

        self.setStyleSheet(r"""
            QDialog { background: #08090a; color: #e8e9ea; }
            QWidget { background: transparent; color: #e8e9ea; }
            QLabel { background: transparent; color: #a8a8a8; }
            QStackedWidget#toolStack { background: transparent; border: none; }
            QPushButton#toolNavButton {
                min-height: 30px; padding: 0 12px;
                background: #0d0d0e; color: #bcbcbc;
                border: 1px solid #242424; border-radius: 5px;
            }
            QPushButton#toolNavButton:hover { background: #151516; color: #eeeeee; }
            QPushButton#toolNavButton:checked {
                background: #1a1a1c; color: #ffffff; border-color: #383838;
            }
            QPlainTextEdit, QLineEdit {
                background: #09090a; color: #eeeeee;
                border: 1px solid #272727; border-radius: 5px;
                padding: 7px;
            }
            QLineEdit:read-only { color: #bfc0c2; background: #070708; }
            QFrame#toolOutputFrame {
                background: #070708; border: 1px solid #252525; border-radius: 6px;
            }
            QsciScintilla#toolOutput {
                background: #070708; color: #eeeeee; border: none;
            }
            QPushButton {
                background: #111112; color: #eeeeee;
                border: 1px solid #2b2b2b; border-radius: 5px;
                padding: 7px 11px;
            }
            QPushButton:hover { background: #1a1a1b; border-color: #383838; }
            QPushButton:disabled { color: #666666; }
            QScrollBar { background: #070708; }
            QScrollBar:horizontal { height: 9px; }
            QScrollBar:vertical { width: 9px; }
            QScrollBar::handle { background: #38383b; border-radius: 4px; min-width: 24px; min-height: 24px; }
            QScrollBar::handle:hover { background: #4a4a4e; }
            QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; }
        """)
        apply_blur_style(self)

    @staticmethod
    def _page_layout(page):
        layout = QVBoxLayout(page)
        layout.setContentsMargins(0, 2, 0, 0)
        layout.setSpacing(8)
        return layout

    def _build_reverser_page(self):
        page = QWidget()
        layout = self._page_layout(page)

        self.loadstring_input = QPlainTextEdit()
        self.loadstring_input.setPlaceholderText(
            'loadstring(game:HttpGet("https://example.com/script.lua"))()'
        )
        self.loadstring_input.setFixedHeight(92)
        self.loadstring_input.setFont(QFont("Consolas", 10))
        layout.addWidget(self.loadstring_input)
        self.loadstring_find = FindOverlay(self.loadstring_input)
        self.loadstring_find_shortcut = QShortcut(QKeySequence("Ctrl+F"), self.loadstring_input)
        self.loadstring_find_shortcut.setContext(Qt.ShortcutContext.WidgetWithChildrenShortcut)
        self.loadstring_find_shortcut.activated.connect(self.loadstring_find.show_find)

        fetch_actions = QHBoxLayout()
        fetch_actions.setContentsMargins(0, 0, 0, 0)
        fetch_actions.setSpacing(7)
        self.fetch_button = QPushButton("Reverse / Fetch")
        self.fetch_button.clicked.connect(self.fetch_loadstring)
        fetch_actions.addWidget(self.fetch_button, 1)
        self.fetch_to_script_button = QPushButton("Open as New Script")
        self.fetch_to_script_button.setEnabled(False)
        new_icon = app_icon("new")
        if not new_icon.isNull():
            self.fetch_to_script_button.setIcon(new_icon)
            self.fetch_to_script_button.setIconSize(QSize(16, 16))
        self.fetch_to_script_button.clicked.connect(self.open_fetch_as_script)
        fetch_actions.addWidget(self.fetch_to_script_button)
        layout.addLayout(fetch_actions)

        self.fetch_status = QLabel("")
        self.fetch_status.setTextFormat(Qt.TextFormat.PlainText)
        self.fetch_status.hide()
        layout.addWidget(self.fetch_status)

        frame = QFrame()
        frame.setObjectName("toolOutputFrame")
        frame_layout = QVBoxLayout(frame)
        frame_layout.setContentsMargins(1, 1, 1, 1)
        frame_layout.setSpacing(0)

        self.fetch_output = QsciScintilla(frame)
        self.fetch_output.setObjectName("toolOutput")
        self.fetch_output.setUtf8(True)
        self.fetch_output.setFont(QFont("Consolas", 10))
        self.fetch_output.setColor(QColor("#eeeeee"))
        self.fetch_output.setPaper(QColor("#070708"))
        self.fetch_output.setMargins(0)
        self.fetch_output.setWrapMode(QsciScintilla.WrapMode.WrapNone)
        self.fetch_output.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.fetch_output.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.fetch_output.setReadOnly(True)
        self.fetch_output.SendScintilla(self.fetch_output.SCI_SETUNDOCOLLECTION, 0)
        self.fetch_output.SendScintilla(
            self.fetch_output.SCI_SETLAYOUTCACHE, self.fetch_output.SC_CACHE_PAGE
        )
        self.fetch_output.SendScintilla(self.fetch_output.SCI_SETSCROLLWIDTH, 1)
        self.fetch_output.SendScintilla(self.fetch_output.SCI_SETSCROLLWIDTHTRACKING, 1)
        self._configure_fetch_syntax()
        frame_layout.addWidget(self.fetch_output)
        layout.addWidget(frame, 1)
        self.tool_stack.addWidget(page)

    def _configure_fetch_syntax(self, editor=None, lexer_attr="fetch_lexer"):
        editor = self.fetch_output if editor is None else editor
        lexer = LuauLexer(editor)
        setattr(self, lexer_attr, lexer)
        editor.SendScintilla(editor.SCI_SETLEXER, editor.SCLEX_NULL)
        editor.SendScintilla(editor.SCI_STYLESETFORE, editor.STYLE_DEFAULT, QColor("#eeeeee"))
        editor.SendScintilla(editor.SCI_STYLESETBACK, editor.STYLE_DEFAULT, QColor("#070708"))
        editor.SendScintilla(editor.SCI_STYLESETFONT, editor.STYLE_DEFAULT, b"Consolas")
        editor.SendScintilla(editor.SCI_STYLESETSIZE, editor.STYLE_DEFAULT, 10)
        editor.SendScintilla(editor.SCI_STYLECLEARALL)
        styles = {
            "#7f936f": (lexer.Comment, lexer.LineComment),
            "#86a8e7": (lexer.Keyword,),
            "#a8c77a": (lexer.String, lexer.Character, lexer.LiteralString, lexer.UnclosedString),
            "#c9a56f": (lexer.Number,),
            "#d7dadd": (lexer.Operator,),
            "#7db0d5": (lexer.BasicFunctions, lexer.KeywordSet5, lexer.KeywordSet6, lexer.KeywordSet7),
            "#7daee0": (lexer.StringTableMathsFunctions, lexer.CoroutinesIOSystemFacilities),
            "#b5a0d2": (lexer.KeywordSet8,),
        }
        for style in range(32):
            editor.SendScintilla(editor.SCI_STYLESETFORE, style, QColor("#eeeeee"))
            editor.SendScintilla(editor.SCI_STYLESETBACK, style, QColor("#070708"))
        for color, style_numbers in styles.items():
            for style in style_numbers:
                editor.SendScintilla(editor.SCI_STYLESETFORE, style, QColor(color))
        editor.SendScintilla(editor.SCI_SETLEXER, editor.SCLEX_LUA)
        for number in range(1, 9):
            words = (lexer.keywords(number) or "").encode("utf-8")
            editor.SendScintilla(editor.SCI_SETKEYWORDS, number - 1, words)
        editor.SendScintilla(editor.SCI_SETPROPERTY, b"fold", b"0")
        editor.SendScintilla(editor.SCI_SETIDLESTYLING, editor.SC_IDLESTYLING_ALL)

    def open_fetch_as_script(self):
        if self.fetch_output.SendScintilla(self.fetch_output.SCI_GETLENGTH) <= 0:
            return
        try:
            source = self.fetch_output.text()
        except MemoryError:
            self.show_fetch_status("Not enough memory to copy this response into a script tab.")
            return
        if not source:
            return
        name = "reversed.luau"
        if self.fetch_url:
            try:
                candidate = Path(urllib.parse.urlsplit(self.fetch_url).path).name.strip()
            except Exception:
                candidate = ""
            if candidate:
                candidate = re.sub(r'[^A-Za-z0-9._ -]+', '_', candidate).strip(' ._') or "reversed"
                name = candidate if candidate.casefold().endswith((".lua", ".luau")) else f"{candidate}.luau"
        try:
            self.owner.add_editor_tab(name, source, select=True)
            self.owner.update_editor_action_state()
            self.owner.raise_()
            self.owner.activateWindow()
            self.show_fetch_status("")
        except Exception as exc:
            self.show_fetch_status(f"Could not open script: {exc}")

    def _build_creator_page(self):
        page = QWidget()
        layout = self._page_layout(page)

        self.creator_input = QLineEdit()
        self.creator_input.setPlaceholderText("pastebin.com/raw/... or raw.githubusercontent.com/...")
        self.creator_input.textChanged.connect(self.update_loadstring_creator)
        layout.addWidget(self.creator_input)

        self.creator_output = HoverCopyLineEdit()
        self.creator_output.setPlaceholderText('loadstring(game:HttpGet("..."))()')
        self.creator_output.setReadOnly(True)
        layout.addWidget(self.creator_output)

        self.creator_status = QLabel("")
        self.creator_status.setTextFormat(Qt.TextFormat.PlainText)
        self.creator_status.hide()
        layout.addWidget(self.creator_status)
        layout.addStretch(1)
        self.tool_stack.addWidget(page)

    def _build_github_page(self):
        page = QWidget()
        layout = self._page_layout(page)

        self.github_input = QLineEdit()
        self.github_input.setPlaceholderText(
            "github.com/owner/repo/blob/branch/path/to/file.lua"
        )
        self.github_input.textChanged.connect(self.update_raw_url)
        layout.addWidget(self.github_input)

        self.github_output = HoverCopyLineEdit()
        self.github_output.setPlaceholderText("Raw URL")
        self.github_output.setReadOnly(True)
        layout.addWidget(self.github_output)

        self.github_status = QLabel("")
        self.github_status.setTextFormat(Qt.TextFormat.PlainText)
        self.github_status.hide()
        layout.addWidget(self.github_status)
        layout.addStretch(1)
        self.tool_stack.addWidget(page)

    def _build_deobfuscate_page(self):
        page = QWidget()
        layout = self._page_layout(page)

        self.deob_input = QPlainTextEdit()
        self.deob_input.setPlaceholderText("Paste obfuscated Lua/Luau here.")
        self.deob_input.setFont(QFont("Consolas", 10))
        self.deob_input.setFixedHeight(130)
        layout.addWidget(self.deob_input)

        input_actions = QHBoxLayout()
        input_actions.setContentsMargins(0, 0, 0, 0)
        input_actions.setSpacing(7)
        self.deob_button = QPushButton("Deobfuscate")
        self.deob_button.clicked.connect(self.start_deobfuscate)
        input_actions.addWidget(self.deob_button, 1)
        self.deob_new_tab_button = QPushButton("Open as New Script")
        self.deob_new_tab_button.setEnabled(False)
        new_icon = app_icon("new")
        if not new_icon.isNull():
            self.deob_new_tab_button.setIcon(new_icon)
            self.deob_new_tab_button.setIconSize(QSize(16, 16))
        self.deob_new_tab_button.clicked.connect(self.open_deobfuscated_as_script)
        input_actions.addWidget(self.deob_new_tab_button)
        layout.addLayout(input_actions)

        self.deob_status = QLabel("")
        self.deob_status.setTextFormat(Qt.TextFormat.PlainText)
        self.deob_status.setWordWrap(True)
        self.deob_status.hide()
        layout.addWidget(self.deob_status)

        frame = QFrame()
        frame.setObjectName("toolOutputFrame")
        frame_layout = QVBoxLayout(frame)
        frame_layout.setContentsMargins(1, 1, 1, 1)
        frame_layout.setSpacing(0)

        self.deob_output = QsciScintilla(frame)
        self.deob_output.setObjectName("toolOutput")
        self.deob_output.setUtf8(True)
        self.deob_output.setFont(QFont("Consolas", 10))
        self.deob_output.setColor(QColor("#eeeeee"))
        self.deob_output.setPaper(QColor("#070708"))
        self.deob_output.setMargins(0)
        self.deob_output.setWrapMode(QsciScintilla.WrapMode.WrapNone)
        self.deob_output.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.deob_output.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.deob_output.setReadOnly(True)
        self.deob_output.SendScintilla(self.deob_output.SCI_SETUNDOCOLLECTION, 0)
        self.deob_output.SendScintilla(self.deob_output.SCI_SETLAYOUTCACHE, self.deob_output.SC_CACHE_PAGE)
        self.deob_output.SendScintilla(self.deob_output.SCI_SETSCROLLWIDTH, 1)
        self.deob_output.SendScintilla(self.deob_output.SCI_SETSCROLLWIDTHTRACKING, 1)
        self._configure_fetch_syntax(self.deob_output, "deob_lexer")
        frame_layout.addWidget(self.deob_output)
        layout.addWidget(frame, 1)

        self.deob_events = queue.Queue(maxsize=8)
        self.deob_request_id = 0
        self.deob_running = False
        self.deob_result_text = ""
        self.tool_stack.addWidget(page)

    def show_deob_status(self, text):
        self.deob_status.setText(str(text or ""))
        self.deob_status.setVisible(bool(text))

    @staticmethod
    def _supported_deobfuscation_source(source):
        return isinstance(source, str) and bool(source.strip()) and '\x00' not in source

    def prefill_deobfuscate(self, source):
        source = str(source or "")
        if source and self._supported_deobfuscation_source(source):
            self.deob_input.setPlainText(source)
            self.show_deob_status("")
            return True
        return False

    def load_current_script_for_deobfuscate(self):
        editor = getattr(self.owner, "editor", None)
        if editor is None:
            self.show_deob_status("No script tab is open.")
            return False
        try:
            source = editor.text()
        except MemoryError:
            self.show_deob_status("Not enough memory to copy the current script.")
            return False
        if not source.strip():
            return False
        if self.prefill_deobfuscate(source):
            return True
        self.show_deob_status("")
        return False

    @staticmethod
    def _run_deobfuscator(events, request_id, source):
        try:
            module = __import__("lelsploit_deobfuscate")
            if hasattr(module, "deobfuscate"):
                result, report = module.deobfuscate(source, return_report=True, effort="deep", max_passes=12, time_budget=45.0)
            else:
                engine = module.Deobfuscator()
                result, report = engine.deobfuscate(source, return_report=True)
            if isinstance(result, (bytes, bytearray)):
                result = bytes(result).decode("latin-1")
            result = str(result)
            family = str(getattr(report, "best_family", "Unknown") or "Unknown")
            passes = list(getattr(report, "passes", ()) or ())
            warnings = list(getattr(report, "warnings", ()) or ())
            status = f"{family}. Applied {len(passes)} pass{'es' if len(passes) != 1 else ''}."
            if passes:
                status += " " + "; ".join(str(item) for item in passes[:5])
                if len(passes) > 5:
                    status += f"; +{len(passes) - 5} more"
            if warnings:
                status += " Warning: " + str(warnings[0])
            events.put(("done", request_id, result, status))
        except Exception as exc:
            events.put(("error", request_id, "", f"Deobfuscation failed: {exc}"))

    def start_deobfuscate(self):
        if self.deob_running:
            return
        source = self.deob_input.toPlainText()
        if not source.strip():
            self.show_deob_status("Paste an obfuscated script first.")
            return
        if not self._supported_deobfuscation_source(source):
            self.show_deob_status("This is not a supported obfuscated format.")
            return
        self.deob_request_id += 1
        request_id = self.deob_request_id
        self.deob_running = True
        self.deob_result_text = ""
        self.deob_button.setEnabled(False)
        self.deob_new_tab_button.setEnabled(False)
        self.show_deob_status("")
        self.deob_output.setReadOnly(False)
        try:
            self.deob_output.clear()
        finally:
            self.deob_output.setReadOnly(True)
        threading.Thread(
            target=self._run_deobfuscator,
            args=(self.deob_events, request_id, source),
            daemon=True,
        ).start()

    def poll_deobfuscate(self):
        terminal = None
        for _ in range(4):
            try:
                item = self.deob_events.get_nowait()
            except queue.Empty:
                break
            kind, request_id, result, status = item
            if request_id == self.deob_request_id:
                terminal = (kind, result, status)
        if terminal is None:
            return
        kind, result, status = terminal
        self.deob_running = False
        self.deob_button.setEnabled(True)
        if kind == "done":
            self.deob_result_text = result
            data = result.encode("utf-8", errors="replace")
            self.deob_output.setReadOnly(False)
            try:
                self.deob_output.setText(result)
                self.deob_output.SendScintilla(self.deob_output.SCI_EMPTYUNDOBUFFER)
                self.deob_output.SendScintilla(self.deob_output.SCI_COLOURISE, 0, -1)
            finally:
                self.deob_output.setReadOnly(True)
            has_result = bool(data)
            self.deob_new_tab_button.setEnabled(has_result)
        else:
            self.deob_result_text = ""
            self.deob_new_tab_button.setEnabled(False)
        self.show_deob_status(status if kind != "done" else "")

    def open_deobfuscated_as_script(self):
        if not self.deob_result_text:
            return
        current_name = "script.luau"
        try:
            current_name = self.owner.current_tab_name() or current_name
        except Exception:
            pass
        path = Path(current_name)
        suffix = path.suffix if path.suffix.casefold() in {".lua", ".luau"} else ".luau"
        name = f"{path.stem or 'script'}.deobfuscated{suffix}"
        try:
            self.owner.add_editor_tab(name, self.deob_result_text, select=True)
            self.owner.update_editor_action_state()
            self.owner.raise_()
            self.owner.activateWindow()
            self.show_deob_status("")
        except Exception as exc:
            self.show_deob_status(f"Could not open the deobfuscated script: {exc}")

    def select_tool(self, index):
        if index < 0 or index >= self.tool_stack.count():
            return
        self.tool_stack.setCurrentIndex(index)
        for button_index, button in enumerate(self.tool_buttons):
            button.setChecked(button_index == index)
        if index == 3:
            self.load_current_script_for_deobfuscate()

    def prefill_loadstring(self, source):
        if extract_loadstring_url(source):
            self.loadstring_input.setPlainText(source)
            self.select_tool(0)

    def clear_fetch_output(self):
        self.fetch_output.setReadOnly(False)
        try:
            self.fetch_output.clear()
            self.fetch_output.SendScintilla(self.fetch_output.SCI_EMPTYUNDOBUFFER)
        finally:
            self.fetch_output.setReadOnly(True)

    def show_fetch_status(self, text):
        self.fetch_status.setText(text)
        self.fetch_status.setVisible(bool(text))

    def show_github_status(self, text):
        self.github_status.setText(text)
        self.github_status.setVisible(bool(text))

    def fetch_loadstring(self):
        source = self.loadstring_input.toPlainText().strip()
        url = extract_loadstring_url(source)
        if url is None and source and not any(c.isspace() for c in source):
            try:
                url = normalize_http_url(source)
            except ValueError:
                pass
        if not url:
            self.show_fetch_status("No HttpGet URL found.")
            return
        if self.fetch_cancel is not None:
            self.fetch_cancel.set()
        self.request_id += 1
        request_id = self.request_id
        self.fetch_cancel = threading.Event()
        self.fetch_url = url
        self.clear_fetch_output()
        self.fetch_to_script_button.setEnabled(False)
        self.fetch_button.setEnabled(False)
        self.show_fetch_status("")
        threading.Thread(
            target=stream_remote_text,
            args=(self.events, request_id, url, self.fetch_cancel),
            daemon=True,
        ).start()

    def append_fetch_bytes(self, data):
        if not data:
            return
        self.fetch_output.setReadOnly(False)
        try:
            self.fetch_output.SendScintilla(
                self.fetch_output.SCI_APPENDTEXT, len(data), data
            )
        finally:
            self.fetch_output.setReadOnly(True)

    def poll_fetch(self):
        chunks = []
        terminal = None
        for _ in range(32):
            try:
                kind, request_id, payload = self.events.get_nowait()
            except queue.Empty:
                break
            if request_id != self.request_id:
                continue
            if kind == "chunk":
                chunks.append(payload)
            else:
                terminal = (kind, payload)
                break
        if chunks:
            self.append_fetch_bytes(b"".join(chunks))
        if terminal is None:
            return
        kind, payload = terminal
        self.fetch_button.setEnabled(True)
        if kind == "done":
            self.fetch_output.SendScintilla(self.fetch_output.SCI_COLOURISE, 0, -1)
            self.fetch_to_script_button.setEnabled(
                self.fetch_output.SendScintilla(self.fetch_output.SCI_GETLENGTH) > 0
            )
            self.show_fetch_status("")
        else:
            self.fetch_to_script_button.setEnabled(False)
            self.show_fetch_status(f"Fetch failed: {payload}")

    def show_creator_status(self, text):
        self.creator_status.setText(text)
        self.creator_status.setVisible(bool(text))

    def update_loadstring_creator(self, *_):
        value = self.creator_input.text().strip()
        if not value:
            self.creator_output.clear()
            self.show_creator_status("")
            return
        try:
            result = make_loadstring_url(value)
        except ValueError as exc:
            self.creator_output.clear()
            self.show_creator_status(str(exc))
            return
        self.creator_output.setText(result)
        self.show_creator_status("")

    def update_raw_url(self, *_):
        value = self.github_input.text().strip()
        if not value:
            self.github_output.clear()
            self.show_github_status("")
            return
        try:
            raw = github_raw_url(value)
        except ValueError as exc:
            self.github_output.clear()
            self.show_github_status(str(exc))
            return
        self.github_output.setText(raw)
        self.show_github_status("")

    def closeEvent(self, event):
        if self.fetch_cancel is not None:
            self.fetch_cancel.set()
        self.fetch_button.setEnabled(True)
        self.fetch_to_script_button.setEnabled(
            self.fetch_output.SendScintilla(self.fetch_output.SCI_GETLENGTH) > 0
        )
        if hasattr(self, "deob_button"):
            self.deob_button.setEnabled(not self.deob_running)
        self.show_fetch_status("")
        event.accept()

