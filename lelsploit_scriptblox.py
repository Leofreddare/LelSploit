




import html
import json
import queue
import re
import shutil
import subprocess
import threading
import time
import urllib.error
import urllib.parse
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


SCRIPTBLOX_API = "https://scriptblox.com/api/script"
SCRIPTBLOX_RESPONSE_LIMIT = 8 * 1024 * 1024
SCRIPTBLOX_USER_AGENT = "LelSploit ScriptBloxApi/1.0"

def scriptblox_script_key(script):
    if not isinstance(script, dict):
        return ""
    game_data = script.get("game") if isinstance(script.get("game"), dict) else {}
    return str(script.get("_id") or script.get("slug") or (
        str(script.get("title")) + "\0" + str(game_data.get("name"))
    ))


def load_saved_scripts():
    value = read_json_object(SAVED_SCRIPTS_PATH, {})
    return {
        str(key): item for key, item in value.items()
        if isinstance(key, str) and isinstance(item, dict)
    }


def save_saved_scripts(value):
    clean = {
        str(key): item for key, item in value.items()
        if isinstance(key, str) and isinstance(item, dict)
    }
    write_json_object(SAVED_SCRIPTS_PATH, clean)


def read_limited(response, limit=SCRIPTBLOX_RESPONSE_LIMIT):
    data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("ScriptBlox response was too large.")
    return data


def scriptblox_curl_bytes(url, accept, timeout=12):
    curl = shutil.which("curl.exe") or shutil.which("curl")
    if not curl:
        raise OSError("curl is not available")
    result = subprocess.run(
        [
            curl, "-fLsS", "--compressed",
            "--connect-timeout", str(max(1, min(int(timeout), 10))),
            "--max-time", str(max(1, int(timeout))),
            "--retry", "2", "--retry-all-errors", "--retry-delay", "1",
            "-A", SCRIPTBLOX_USER_AGENT,
            "-H", f"Accept: {accept}",
            "-H", "Cache-Control: no-cache",
            "-H", "Referer: https://scriptblox.com/",
            url,
        ],
        capture_output=True,
        timeout=max(3, int(timeout) + 4),
        creationflags=NO_WINDOW,
        check=False,
    )
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise ConnectionError(detail or f"curl failed with exit code {result.returncode}.")
    if len(result.stdout) > SCRIPTBLOX_RESPONSE_LIMIT:
        raise ValueError("ScriptBlox response was too large.")
    return result.stdout


def scriptblox_request_bytes(url, accept, timeout=20):
    request = urllib.request.Request(
        url,
        headers={
            "Accept": accept,
            "User-Agent": SCRIPTBLOX_USER_AGENT,
        },
    )
    retry_statuses = {429, 502, 503, 504}
    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return read_limited(response)
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code in retry_statuses and attempt < 2:
                retry_after = 0.0
                if exc.code == 429:
                    try:
                        retry_after = float(exc.headers.get("Retry-After", 0) or 0)
                    except (TypeError, ValueError):
                        retry_after = 0.0
                time.sleep(min(4.0, max(retry_after, 0.45 * (2 ** attempt))))
                continue
            break
        except urllib.error.URLError as exc:
            last_error = exc
            if attempt < 2:
                time.sleep(0.45 * (2 ** attempt))
                continue
            break

    if isinstance(last_error, urllib.error.HTTPError):
        detail = ""
        try:
            body = last_error.read(4096).decode("utf-8", errors="replace")
            payload = json.loads(body)
            if isinstance(payload, dict):
                detail = str(payload.get("message", "") or "").strip()
        except Exception:
            pass
        raise ConnectionError(
            detail or f"ScriptBlox request failed (HTTP {last_error.code})."
        ) from last_error

    try:
        return scriptblox_curl_bytes(url, accept, timeout)
    except Exception as curl_exc:
        if isinstance(last_error, urllib.error.URLError):
            reason = getattr(last_error, "reason", last_error)
            raise ConnectionError(f"Could not reach ScriptBlox: {reason}") from last_error
        raise ConnectionError(f"Could not reach ScriptBlox: {curl_exc}") from curl_exc


def scriptblox_catalog_request(endpoint, parameter_sets):
    errors = []
    seen = set()
    for params in parameter_sets:
        query = urllib.parse.urlencode(params)
        url = f"{SCRIPTBLOX_API}/{endpoint}" + (f"?{query}" if query else "")
        if url in seen:
            continue
        seen.add(url)
        try:
            raw = scriptblox_request_bytes(url, "application/json")
            payload = json.loads(raw.decode("utf-8-sig"))
            if not isinstance(payload, dict):
                raise ValueError("ScriptBlox returned an invalid response.")
            if payload.get("message"):
                raise ValueError(str(payload["message"]))
            result = payload.get("result")
            if not isinstance(result, dict) or not isinstance(result.get("scripts"), list):
                raise ValueError("ScriptBlox returned an invalid result.")
            return result
        except Exception as exc:
            errors.append(str(exc))
    if errors:
        raise ConnectionError(errors[-1])
    raise ConnectionError("ScriptBlox did not return a usable response.")


def _scriptblox_title_from_slug(slug):
    text = urllib.parse.unquote(str(slug or "")).strip("/")
    text = re.sub(r"-\d+$", "", text)
    text = text.replace("-", " ").replace("_", " ")
    text = re.sub(r"\s+", " ", text).strip()
    return text or "Untitled script"


def _scriptblox_parse_site_scripts(document, keyless=False):
    
    
    pattern = re.compile(
        r'<a\b[^>]*href\s*=\s*(?P<q>["\'])'
        r'(?:(?:https?:)?//(?:www\.)?scriptblox\.com)?'
        r'(?P<href>/script/[^"\']+)(?P=q)[^>]*>(?P<body>.*?)</a>',
        re.IGNORECASE | re.DOTALL,
    )
    scripts = []
    seen = set()
    for match in pattern.finditer(document):
        href = html.unescape(match.group("href"))
        slug = href.split("/script/", 1)[-1].split("?", 1)[0].split("#", 1)[0].strip("/")
        if not slug or slug in seen:
            continue
        body = re.sub(r"<[^>]+>", " ", match.group("body"))
        body = html.unescape(re.sub(r"\s+", " ", body)).strip()
        lowered = body.casefold()
        has_key = "key system" in lowered
        if keyless and has_key:
            continue
        paid = bool(re.search(r"\bpaid\b", lowered))
        universal = "universal script" in lowered
        patched = "patched" in lowered and "unpatched" not in lowered and "not patched" not in lowered
        seen.add(slug)
        scripts.append({
            "_id": slug,
            "slug": slug,
            "title": _scriptblox_title_from_slug(slug),
            "game": {"name": "Universal" if universal else "ScriptBlox"},
            "verified": "verified" in lowered,
            "key": has_key,
            "views": None,
            "scriptType": "paid" if paid else "free",
            "isUniversal": universal,
            "isPatched": patched,
            "_lelsploit_raw_url": f"{SCRIPTBLOX_RAW_SITE}/{urllib.parse.quote(slug, safe='')}",
        })
        if len(scripts) >= 20:
            break
    return scripts


def scriptblox_web_catalog(script_query, game_query, keyless, page):
    
    
    if int(page or 1) != 1:
        return {"scripts": [], "totalPages": 1, "nextPage": None, "_lelsploit_web": True}

    script_query = str(script_query or "").strip()
    game_query = str(game_query or "").strip()
    numeric_place = game_query.isdecimal()
    text_terms = [script_query]
    if game_query and not numeric_place:
        text_terms.append(game_query)
    query = " ".join(term for term in text_terms if term).strip()

    urls = []
    if numeric_place:
        
        
        urls.append(f"{SCRIPTBLOX_SITE}/game/{urllib.parse.quote(game_query, safe='')}")
    if query:
        urls.append(f"{SCRIPTBLOX_SITE}/?{urllib.parse.urlencode({'q': query})}")
    else:
        
        
        urls.append(f"{SCRIPTBLOX_SITE}/trending")

    last_error = None
    for url in urls:
        try:
            raw = scriptblox_request_bytes(url, "text/html,application/xhtml+xml")
            document = raw.decode("utf-8", errors="replace")
            scripts = _scriptblox_parse_site_scripts(document, keyless=keyless)
            if scripts:
                return {
                    "scripts": scripts,
                    "totalPages": 1,
                    "nextPage": None,
                    "_lelsploit_web": True,
                }
        except Exception as exc:
            last_error = exc

    if numeric_place and not query:
        
        
        try:
            raw = scriptblox_request_bytes(
                f"{SCRIPTBLOX_SITE}/trending", "text/html,application/xhtml+xml"
            )
            scripts = _scriptblox_parse_site_scripts(raw.decode("utf-8", errors="replace"), keyless=keyless)
            if scripts:
                return {
                    "scripts": scripts,
                    "totalPages": 1,
                    "nextPage": None,
                    "_lelsploit_web": True,
                }
        except Exception as exc:
            last_error = exc

    if last_error is not None:
        raise ConnectionError(str(last_error)) from last_error
    raise ConnectionError("ScriptBlox website did not return script cards.")


def scriptblox_raw_source(script_id, slug=None):
    script_id = str(script_id or "").strip()
    slug = str(slug or "").strip()
    candidates = []
    if script_id:
        candidates.append(f"{SCRIPTBLOX_API}/raw/{urllib.parse.quote(script_id, safe='')}")
    if slug and slug != script_id:
        candidates.append(f"{SCRIPTBLOX_API}/raw/{urllib.parse.quote(slug, safe='')}")
    raw_slug = slug or script_id
    if raw_slug:
        
        candidates.append(f"{SCRIPTBLOX_RAW_SITE}/{urllib.parse.quote(raw_slug, safe='')}")

    last_error = None
    for url in candidates:
        try:
            code = scriptblox_request_bytes(url, "text/plain,*/*;q=0.8").decode("utf-8-sig")
            if code.strip():
                return code
        except Exception as exc:
            last_error = exc
    if last_error is not None:
        raise last_error
    raise ValueError("ScriptBlox returned an empty script.")


def fetch_scriptblox(output, request_id, script_query, game_query,
                     sort_by, keyless, page, append):
    script_query = script_query.strip()
    game_query = game_query.strip()
    numeric_place = game_query.isdecimal()
    terms = [script_query]
    if game_query and not numeric_place:
        terms.append(game_query)
    query = " ".join(term for term in terms if term)
    endpoint = "search" if query else "fetch"

    full = {
        "max": 12,
        "page": page,
        "sortBy": sort_by,
        "order": "desc",
        "mode": "free",
        "patched": 0,
    }
    if query:
        full["q"] = query
        full["strict"] = "false"
    if numeric_place:
        full["placeId"] = game_query
    if keyless:
        full["key"] = 0

    
    
    
    stable = {
        "page": page,
        "max": 20,
        "sortBy": sort_by,
        "order": "desc",
    }
    if query:
        stable["q"] = query
        stable["strict"] = "false"
    if numeric_place:
        stable["placeId"] = game_query

    baseline = {"page": page, "max": 20}
    if query:
        baseline["q"] = query

    try:
        try:
            result = scriptblox_catalog_request(endpoint, (full, stable, baseline))
        except Exception:
            result = scriptblox_web_catalog(script_query, game_query, keyless, page)
        web_fallback = bool(result.get("_lelsploit_web"))
        scripts = [item for item in result.get("scripts", []) if isinstance(item, dict)]

        if keyless:
            scripts = [item for item in scripts if not bool(item.get("key"))]
        scripts = [
            item for item in scripts
            if str(item.get("scriptType", "free")).casefold() != "paid"
            and not bool(item.get("isPatched"))
        ]

        if game_query and not numeric_place and not web_fallback:
            wanted = game_query.casefold()
            scripts = [
                item for item in scripts
                if wanted in str(
                    item.get("game", {}).get("name", "")
                    if isinstance(item.get("game"), dict) else ""
                ).casefold()
            ]
        elif numeric_place:
            wanted = str(game_query)
            matching = []
            for item in scripts:
                game_data = item.get("game") if isinstance(item.get("game"), dict) else {}
                identifiers = {
                    str(game_data.get("gameId", "")),
                    str(game_data.get("placeId", "")),
                    str(game_data.get("_id", "")),
                }
                if wanted in identifiers:
                    matching.append(item)
            
            
            if matching:
                scripts = matching

        if sort_by in {"views", "likeCount"}:
            scripts.sort(
                key=lambda item: float(item.get(sort_by, 0) or 0),
                reverse=True,
            )
        elif sort_by in {"createdAt", "updatedAt"}:
            scripts.sort(key=lambda item: str(item.get(sort_by, "")), reverse=True)

        scripts = scripts[:12]
        total_pages = result.get("totalPages", page)
        try:
            total_pages = max(page, int(total_pages))
        except (TypeError, ValueError):
            total_pages = page
        next_page = result.get("nextPage")
        try:
            next_page = int(next_page) if next_page is not None else None
        except (TypeError, ValueError):
            next_page = page + 1 if page < total_pages else None
        if next_page is None and page < total_pages:
            next_page = page + 1
        if next_page is not None and next_page <= page:
            next_page = None
        output.put(("catalog", request_id, {
            "scripts": scripts,
            "page": page,
            "total_pages": total_pages,
            "next_page": next_page,
            "append": append,
        }))
    except Exception as exc:
        output.put(("catalog_error", request_id, str(exc)))


def fetch_scriptblox_raw(output, script_id, title, slug=None):
    try:
        code = scriptblox_raw_source(script_id, slug)
        output.put(("install", title, code))
    except Exception as exc:
        output.put(("install_error", title, str(exc)))


def fetch_scriptblox_saved_raw(output, key, script_id, slug=None):
    try:
        code = scriptblox_raw_source(script_id, slug)
        output.put(("save", key, code))
    except Exception as exc:
        output.put(("save_error", key, str(exc)))


class ScriptBloxInstallDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.behavior = None
        self.setWindowTitle("ScriptBlox install")
        self.setModal(True)
        self.resize(470, 315)
        self.setMinimumWidth(430)
        apply_window_icon(self)

        layout = blur_content_layout(self, self, "ScriptBlox install", (18, 18, 18, 18), 12)

        heading = QLabel("Choose how ScriptBlox should install scripts")
        heading.setObjectName("installHeading")
        layout.addWidget(heading)

        choices = QVBoxLayout()
        choices.setSpacing(8)
        options = (
            ("Put in current code window", "current", False),
            ("Put in current code window & run", "current_execute", False),
            ("Put in new code window", "new", False),
            ("Put in new code window & run    Recommended", "new_execute", True),
        )
        for label, behavior, recommended in options:
            button = QPushButton(label.replace("&", "&&"))
            button.setObjectName("installRecommended" if recommended else "installChoice")
            button.setMinimumHeight(42)
            button.setCursor(Qt.CursorShape.PointingHandCursor)
            button.clicked.connect(lambda checked=False, value=behavior: self.choose(value))
            choices.addWidget(button)
        layout.addLayout(choices)

        bottom = QHBoxLayout()
        bottom.addStretch(1)
        cancel = QPushButton("Cancel")
        cancel.setObjectName("installCancel")
        cancel.setFixedWidth(90)
        cancel.clicked.connect(self.reject)
        bottom.addWidget(cancel)
        layout.addLayout(bottom)

        self.setStyleSheet(r'''            QLabel#installHeading {
                color: #f1f1f1;
                font-size: 14px;
                font-weight: 600;
            }
            QPushButton#installChoice, QPushButton#installRecommended {
                text-align: left;
                padding: 9px 12px;
                border-radius: 8px;
            }
            QPushButton#installChoice {
                background: #0b0c0b;
                border: 1px solid #292929;
                color: #e4e4e4;
            }
            QPushButton#installChoice:hover {
                background: #181818;
                border-color: #3c3c3c;
            }
            QPushButton#installRecommended {
                background: #102b19;
                border: 1px solid #2e6c3d;
                color: #8febaa;
                font-weight: 600;
            }
            QPushButton#installRecommended:hover {
                background: #163922;
                border-color: #438a55;
                color: #a4f4b9;
            }
            QPushButton#installCancel {
                background: transparent;
                border: 1px solid #292929;
            }
            QPushButton#installCancel:hover {
                background: #151515;
                border-color: #3a3a3a;
            }
        ''')
        apply_blur_style(self)

    def choose(self, behavior):
        self.behavior = behavior
        self.accept()


class ScriptBloxWindow(QDialog):
    SORTS = (
        ("Popular", "views"),
        ("Most liked", "likeCount"),
        ("Newest", "createdAt"),
        ("Recently updated", "updatedAt"),
    )

    def __init__(self, parent, install_callback):
        super().__init__(parent)
        self.install_callback = install_callback
        self.events = queue.Queue()
        self.request_id = 0
        self.next_page = None
        self.loaded_keys = set()
        self.saved_scripts = load_saved_scripts()
        self.saved_only = False
        self.browse_state = None
        self.auto_place_id = None
        self.setWindowTitle("ScriptBlox")
        self.resize(720, 560)
        self.setMinimumSize(560, 400)
        apply_window_icon(self)

        layout = blur_content_layout(self, self, "ScriptBlox", (16, 16, 16, 16), 10)
        back_row = QHBoxLayout()
        self.back_button = QPushButton()
        self.back_button.setFixedSize(34, 34)
        back_icon = app_icon("back")
        if not back_icon.isNull():
            self.back_button.setIcon(back_icon)
            self.back_button.setIconSize(QSize(18, 18))
        self.back_button.clicked.connect(lambda: self.saved_button.setChecked(False))
        self.back_button.hide()
        back_row.addWidget(self.back_button)
        back_row.addStretch(1)
        layout.addLayout(back_row)
        searches = QHBoxLayout()
        self.search = QLineEdit()
        self.search.setPlaceholderText("Search scripts...")
        self.search.setClearButtonEnabled(True)
        self.search.returnPressed.connect(self.refresh)
        searches.addWidget(self.search, 1)

        self.game_search = QLineEdit()
        self.game_search.setPlaceholderText("Search games or place ID...")
        self.game_search.setClearButtonEnabled(True)
        self.game_search.returnPressed.connect(self.refresh)
        searches.addWidget(self.game_search, 1)
        layout.addLayout(searches)

        filters = QHBoxLayout()

        self.sort = LelComboBox()
        sort_icon = app_icon("sort")
        for label, value in self.SORTS:
            self.sort.addItem(sort_icon, label, value)
        self.sort.currentIndexChanged.connect(self.refresh)
        filters.addWidget(self.sort)

        self.keyless = QPushButton("Keyless")
        self.keyless.setObjectName("keylessButton")
        self.keyless.setCheckable(True)
        self.keyless.setChecked(True)
        keyless_icon = app_icon("keyless")
        if not keyless_icon.isNull():
            self.keyless.setIcon(keyless_icon)
            self.keyless.setIconSize(QSize(18, 18))
        self.keyless.toggled.connect(self.refresh)
        filters.addWidget(self.keyless)
        filters.addStretch(1)

        self.saved_button = QPushButton("Saved Scripts")
        self.saved_button.setObjectName("savedScriptsButton")
        self.saved_button.setCheckable(True)
        saved_icon = app_icon("stared")
        if saved_icon.isNull():
            saved_icon = app_icon("star")
        if not saved_icon.isNull():
            self.saved_button.setIcon(saved_icon)
            self.saved_button.setIconSize(QSize(17, 17))
        self.saved_button.toggled.connect(self.set_saved_only)
        filters.addWidget(self.saved_button)
        layout.addLayout(filters)

        self.status = QLabel("Loading scripts...")
        self.status.setTextFormat(Qt.TextFormat.PlainText)
        layout.addWidget(self.status)
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.results = QWidget()
        self.results_layout = QVBoxLayout(self.results)
        self.results_layout.setContentsMargins(0, 0, 0, 0)
        self.results_layout.setSpacing(8)
        self.load_more_button = QPushButton("Load More")
        self.load_more_button.clicked.connect(self.load_more)
        self.load_more_button.hide()
        self.results_layout.addStretch(1)
        self.results_layout.addWidget(self.load_more_button)
        self.scroll.setWidget(self.results)
        layout.addWidget(self.scroll, 1)

        self.search_timer = QTimer(self)
        self.search_timer.setSingleShot(True)
        self.search_timer.setInterval(650)
        self.search_timer.timeout.connect(self.refresh)
        self.search.textChanged.connect(lambda: self.search_timer.start())
        self.game_search.textChanged.connect(lambda: self.search_timer.start())
        self.poll_timer = QTimer(self)
        self.poll_timer.setInterval(50)
        self.poll_timer.timeout.connect(self.poll_events)
        self.poll_timer.start()
        self.setStyleSheet("""
            QDialog { background: #08090a; color: #e8e9ea; }
            QWidget { background: transparent; color: #e8e9ea; }
            QLabel, QCheckBox { background: transparent; }
            QLabel { color: #b7bbbd; }
            QLineEdit { background: #0d0d0d; border: 1px solid #2b2b2b;
                border-radius: 7px; padding: 7px; }
            QPushButton { background: #101214; border: 1px solid #2d3235;
                border-radius: 4px; padding: 5px 10px; }
            QPushButton:hover { background: #1e2225; }
            QPushButton#starButton { background: #0d0d0d; border: 1px solid #262626;
                border-radius: 6px; padding: 0; }
            QPushButton#starButton:hover { background: #181818; border-color: #3a3a3a; }
            QPushButton#savedScriptsButton:checked { background: #27220f; color: #f0d56a;
                border-color: #66582a; }
            QPushButton#savedScriptsButton:checked:hover { background: #322b12; border-color: #806f32; }
            QFrame#scriptCard { background: #090909; border: 1px solid #121212;
                border-radius: 4px; }
            QScrollArea { background: transparent; border: none; }
            QScrollArea > QWidget > QWidget { background: transparent; }
        """)
        apply_blur_style(self)
        self.prefill_current_game(refresh_on_change=False)
        QTimer.singleShot(0, self.refresh)

    def prefill_current_game(self, refresh_on_change=True):
        if self.saved_only:
            return False
        current = self.game_search.text().strip()
        if current and current != (self.auto_place_id or ""):
            return False
        try:
            place_id = current_roblox_place_id()
        except Exception:
            return False
        if not place_id:
            return False
        place_id = str(place_id)
        changed = current != place_id
        self.auto_place_id = place_id
        if changed:
            self.game_search.blockSignals(True)
            self.game_search.setText(place_id)
            self.game_search.blockSignals(False)
            if refresh_on_change:
                QTimer.singleShot(0, self.refresh)
        return changed

    def refresh(self, *_):
        self.search_timer.stop()
        self.next_page = None
        self.loaded_keys.clear()
        self.clear_results()
        if self.saved_only:
            self.refresh_saved()
            return
        self.request_page(1, append=False)

    def set_saved_only(self, enabled):
        enabled = bool(enabled)
        if enabled == self.saved_only:
            return

        self.search_timer.stop()
        if enabled:
            self.browse_state = {
                "search": self.search.text(),
                "game_search": self.game_search.text(),
                "keyless": self.keyless.isChecked(),
                "sort": self.sort.currentIndex(),
            }
            for widget in (self.search, self.game_search, self.keyless, self.sort):
                widget.blockSignals(True)
            self.search.clear()
            self.game_search.clear()
            self.keyless.setChecked(False)
            for widget in (self.search, self.game_search, self.keyless, self.sort):
                widget.blockSignals(False)
                widget.hide()
        else:
            state = self.browse_state or {}
            for widget in (self.search, self.game_search, self.keyless, self.sort):
                widget.show()
                widget.blockSignals(True)
            self.search.setText(str(state.get("search", "")))
            self.game_search.setText(str(state.get("game_search", "")))
            self.keyless.setChecked(bool(state.get("keyless", True)))
            sort_index = state.get("sort", 0)
            if isinstance(sort_index, int) and 0 <= sort_index < self.sort.count():
                self.sort.setCurrentIndex(sort_index)
            for widget in (self.search, self.game_search, self.keyless, self.sort):
                widget.blockSignals(False)
            self.browse_state = None

        self.saved_only = enabled
        self.back_button.setVisible(enabled)
        self.request_id += 1
        self.next_page = None
        self.load_more_button.hide()
        self.load_more_button.setEnabled(False)
        self.refresh()

    def refresh_saved(self):
        scripts = list(self.saved_scripts.values())
        scripts.sort(
            key=lambda item: float(item.get("_lelsploit_saved_at", 0) or 0),
            reverse=True,
        )
        self.show_scripts(scripts, append=False)
        if not scripts:
            self.status.setText("No saved scripts.")

    def request_page(self, page, append):
        self.request_id += 1
        request_id = self.request_id
        self.status.setText("Loading more..." if append else "Loading scripts...")
        self.set_filters_enabled(False)
        self.load_more_button.setVisible(False)
        self.load_more_button.setEnabled(False)
        threading.Thread(
            target=fetch_scriptblox,
            args=(self.events, request_id, self.search.text(),
                  self.game_search.text(), self.sort.currentData(),
                  self.keyless.isChecked(), page, append),
            daemon=True,
        ).start()

    def load_more(self):
        if self.next_page is not None and self.load_more_button.isEnabled():
            self.request_page(self.next_page, append=True)

    def set_filters_enabled(self, enabled):
        active = bool(enabled) and not self.saved_only
        self.sort.setEnabled(active)
        self.keyless.setEnabled(active)

    def clear_results(self):
        while self.results_layout.count() > 2:
            item = self.results_layout.takeAt(0)
            widget = item.widget()
            if widget is not None:
                widget.deleteLater()
        self.load_more_button.hide()

    def show_scripts(self, scripts, append=False):
        if not append:
            self.clear_results()
            self.loaded_keys.clear()
        if not scripts and not self.loaded_keys:
            self.status.setText("No saved scripts." if self.saved_only else "No scripts found.")
            return
        install_icon = app_icon("install")
        for script in scripts:
            game_data = script.get("game") if isinstance(script.get("game"), dict) else {}
            key = scriptblox_script_key(script)
            if key in self.loaded_keys:
                continue
            self.loaded_keys.add(key)
            card = QFrame()
            card.setObjectName("scriptCard")
            card_layout = QHBoxLayout(card)
            card_layout.setContentsMargins(12, 10, 12, 10)
            details = QVBoxLayout()
            title = QLabel(str(script.get("title") or "Untitled script"))
            title.setTextFormat(Qt.TextFormat.PlainText)
            title.setStyleSheet("color: #eeeeee; font-weight: 600;")
            details.addWidget(title)
            game = str(game_data.get("name") or "Universal")
            views = script.get("views")
            meta = game if not isinstance(views, (int, float)) else f"{game}  •  {int(views):,} views"
            meta_label = QLabel(meta)
            meta_label.setTextFormat(Qt.TextFormat.PlainText)
            details.addWidget(meta_label)
            card_layout.addLayout(details, 1)
            install = QPushButton("Install")
            if not install_icon.isNull():
                install.setIcon(install_icon)
                install.setIconSize(QSize(18, 18))
            install.clicked.connect(lambda checked=False, item=script: self.install(item))
            card_layout.addWidget(install)

            star = QPushButton()
            star.setObjectName("starButton")
            star.setFixedSize(34, 34)
            self.update_star_button(star, key in self.saved_scripts)
            star.clicked.connect(
                lambda checked=False, item=script, button=star: self.toggle_saved(item, button)
            )
            card_layout.addWidget(star)
            self.results_layout.insertWidget(self.results_layout.count() - 2, card)
        label = "saved scripts" if self.saved_only else "scripts"
        self.status.setText(f"{len(self.loaded_keys)} {label}")

    def update_star_button(self, button, starred):
        icon = app_icon("stared" if starred else "star")
        if not icon.isNull():
            button.setIcon(icon)
            button.setIconSize(QSize(17, 17))
        button.setToolTip("Remove from saved scripts" if starred else "Save script")

    def toggle_saved(self, script, button=None):
        key = scriptblox_script_key(script)
        if not key:
            return
        if key in self.saved_scripts:
            del self.saved_scripts[key]
            starred = False
        else:
            try:
                saved = json.loads(json.dumps(script, ensure_ascii=False))
            except (TypeError, ValueError):
                saved = dict(script)
            saved["_lelsploit_saved_at"] = time.time()
            self.saved_scripts[key] = saved
            starred = True
        try:
            save_saved_scripts(self.saved_scripts)
        except OSError as exc:
            self.status.setText(f"Could not save scripts: {exc}")
            return
        if button is not None:
            self.update_star_button(button, starred)
        if starred:
            saved_item = self.saved_scripts.get(key, {})
            script_id = saved_item.get("_id") or saved_item.get("slug")
            code = saved_item.get("script")
            if script_id and not (isinstance(code, str) and code.strip()):
                self.status.setText("Saving script source...")
                threading.Thread(
                    target=fetch_scriptblox_saved_raw,
                    args=(self.events, key, script_id, saved_item.get("slug")),
                    daemon=True,
                ).start()
            else:
                self.status.setText("Script saved.")
        else:
            self.status.setText("Removed from saved scripts.")
        if self.saved_only and not starred:
            self.refresh_saved()

    def install(self, script):
        title = str(script.get("title") or "script")
        code = script.get("script")
        if isinstance(code, str) and code.strip():
            installed = self.install_callback(code, title)
            self.status.setText(f"Installed {title}." if installed else "Install cancelled.")
            return
        script_id = script.get("_id") or script.get("slug")
        if not script_id:
            self.status.setText("This script has no downloadable source.")
            return
        self.status.setText(f"Installing {title}...")
        threading.Thread(
            target=fetch_scriptblox_raw,
            args=(self.events, script_id, title, script.get("slug")),
            daemon=True,
        ).start()

    def poll_events(self):
        for _ in range(20):
            try:
                kind, first, second = self.events.get_nowait()
            except queue.Empty:
                break
            if kind == "catalog":
                if first == self.request_id:
                    self.set_filters_enabled(True)
                    self.next_page = second["next_page"]
                    self.show_scripts(second["scripts"], second["append"])
                    self.load_more_button.setVisible(self.next_page is not None)
                    self.load_more_button.setEnabled(self.next_page is not None)
            elif kind == "catalog_error":
                if first == self.request_id:
                    self.set_filters_enabled(True)
                    self.load_more_button.hide()
                    self.load_more_button.setEnabled(False)
                    if not self.loaded_keys:
                        self.clear_results()
                    self.status.setText("Could not load scripts.")
            elif kind == "install":
                installed = self.install_callback(second, first)
                self.status.setText(f"Installed {first}." if installed else "Install cancelled.")
            elif kind == "save":
                if first in self.saved_scripts:
                    self.saved_scripts[first]["script"] = second
                    try:
                        save_saved_scripts(self.saved_scripts)
                        self.status.setText("Script saved.")
                    except OSError as exc:
                        self.status.setText(f"Could not save scripts: {exc}")
            elif kind == "save_error":
                if first in self.saved_scripts:
                    self.status.setText(f"Saved script, but source could not be cached: {second}")
            else:
                self.status.setText(f"Could not install {first}: {second}")


