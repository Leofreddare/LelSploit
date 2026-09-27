






import base64
import fnmatch
import hashlib
import inspect
import json
import os
import queue
import secrets
import sqlite3
import stat
import shutil
import ssl
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

from PyQt6.QtCore import Qt, QTimer, QSize
from PyQt6.QtGui import QIcon, QPixmap
from PyQt6.QtWidgets import (
    QApplication,
    QButtonGroup,
    QDialog,
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QInputDialog,
    QLabel,
    QLineEdit,
    QMessageBox,
    QPushButton,
    QScrollArea,
    QStackedWidget,
    QVBoxLayout,
    QWidget,
)

RUNTIME_DIR = Path(__file__).resolve().parent
_APPDATA_ROOT = os.environ.get("APPDATA")
APPDATA_DIR = (
    Path(_APPDATA_ROOT).expanduser().resolve() / "LelSploit"
    if _APPDATA_ROOT
    else (Path.home() / "AppData" / "Roaming" / "LelSploit").resolve()
)
BASE_DIR = APPDATA_DIR
ICON_DIR = RUNTIME_DIR / "icons"
IMAGES_DIR = RUNTIME_DIR / "images"
EXTENSIONS_DIR = BASE_DIR / "extensions"
EXTENSION_DATA_DIR = BASE_DIR / "extension_data"
EXTENSION_PACKAGE_LIMIT = 10 * 1024 * 1024
MARKETPLACE_PACKAGE_LIMIT = 10 * 1024 * 1024
MARKETPLACE_RESPONSE_LIMIT = 4 * 1024 * 1024
MARKETPLACE_ICON_LIMIT = 512 * 1024
MARKETPLACE_DEFAULT_API = "https://marketplace.lelsploit.workers.dev"
MARKETPLACE_CA_BUNDLE = RUNTIME_DIR / "cacert.pem"

_HOST_CONFIGURED = False
_HOST_GLOBALS = None


def configure_host(**helpers):





    global _HOST_CONFIGURED, _HOST_GLOBALS
    required = {
        "LelComboBox",
        "app_icon",
        "apply_blur_style",
        "apply_window_icon",
        "blur_content_layout",
        "lelsploit_icon",
        "extension_folder_signature",
        "extension_template_icon",
        "load_extension_state",
        "read_extension_package",
        "save_extension_state",
        "scan_extension_packages",
        "write_extension_template",
        "EXTENSION_TEMPLATES",
    }
    missing = sorted(required.difference(helpers))
    if missing:
        raise RuntimeError("Missing LelSploit extension host helpers: " + ", ".join(missing))
    globals().update(helpers)
    frame = inspect.currentframe()
    caller = frame.f_back.f_globals if frame is not None and frame.f_back is not None else None
    _HOST_GLOBALS = caller if isinstance(caller, dict) else _HOST_GLOBALS
    _install_power_api(_HOST_GLOBALS)
    _schedule_documentation_patch()
    _HOST_CONFIGURED = True


def _marketplace_api_base(_settings=None):
    
    return MARKETPLACE_DEFAULT_API.rstrip("/")


def _marketplace_api_token(settings=None):
    if settings is None:
        return ""
    try:
        return str(settings.value("extension_marketplace/token", "") or "").strip()
    except Exception:
        return ""


def _is_certificate_error(exc):
    reason = getattr(exc, "reason", exc)
    if isinstance(reason, ssl.SSLCertVerificationError):
        return True
    text = str(reason).casefold()
    return "certificate_verify_failed" in text or "certificate verify failed" in text


def _marketplace_ssl_contexts():





    contexts = []
    seen = set()

    def add(label, factory):
        try:
            ctx = factory()
        except Exception:
            return
        key = (label, getattr(ctx, "verify_mode", None))
        if key not in seen:
            seen.add(key)
            contexts.append((label, ctx))

    if MARKETPLACE_CA_BUNDLE.is_file():
        add("bundled CA certificates", lambda: ssl.create_default_context(cafile=str(MARKETPLACE_CA_BUNDLE)))

    try:
        import certifi  
        certifi_path = Path(certifi.where())
        if certifi_path.is_file() and certifi_path.resolve() != MARKETPLACE_CA_BUNDLE.resolve():
            add("certifi CA certificates", lambda: ssl.create_default_context(cafile=str(certifi_path)))
    except Exception:
        pass

    add("system CA certificates", ssl.create_default_context)
    return contexts


def _marketplace_error_message(exc):
    if isinstance(exc, urllib.error.HTTPError):
        try:
            raw = exc.read(MARKETPLACE_RESPONSE_LIMIT + 1)
            if len(raw) <= MARKETPLACE_RESPONSE_LIMIT:
                payload = json.loads(raw.decode("utf-8", errors="replace"))
                if isinstance(payload, dict) and payload.get("error"):
                    return str(payload["error"])
        except Exception:
            pass
        return f"Marketplace request failed (HTTP {exc.code})."
    if isinstance(exc, urllib.error.URLError):
        if _is_certificate_error(exc):
            return (
                "Could not make a secure connection to the marketplace because certificate verification failed. "
                "LelSploit tried its bundled CA certificates and the system certificate store. "
                "Check that Windows date/time is correct and that antivirus/HTTPS inspection is not presenting an expired certificate."
            )
        return f"Could not reach the marketplace: {getattr(exc, 'reason', exc)}"
    if isinstance(exc, ssl.SSLCertVerificationError):
        return (
            "Could not make a secure connection to the marketplace because certificate verification failed. "
            "Check Windows date/time and any antivirus/HTTPS-inspection certificate."
        )
    return str(exc) or exc.__class__.__name__


def marketplace_request(base_url, path, method="GET", token="", json_body=None,
                        multipart_fields=None, multipart_file=None, multipart_files=None, timeout=20,
                        response_limit=MARKETPLACE_RESPONSE_LIMIT, raw=False):
    base_url = str(base_url or "").strip().rstrip("/")
    if base_url != MARKETPLACE_DEFAULT_API.rstrip("/"):
        raise ValueError("The LelSploit marketplace endpoint is fixed by this build.")
    url = base_url + (path if str(path).startswith("/") else "/" + str(path))
    headers = {"Accept": "application/json", "User-Agent": "LelSploit Marketplace/1.1"}
    if token:
        headers["Authorization"] = "Bearer " + str(token)
    data = None
    if multipart_fields is not None or multipart_file is not None or multipart_files:
        boundary = "----LelSploit" + hashlib.sha256(f"{time.time_ns()}:{os.getpid()}".encode()).hexdigest()[:24]
        chunks = []
        for key, value in (multipart_fields or {}).items():
            chunks.extend([
                f"--{boundary}\r\n".encode(),
                f'Content-Disposition: form-data; name="{str(key).replace(chr(34), "")}"\r\n\r\n'.encode(),
                str(value).encode("utf-8"), b"\r\n",
            ])
        files = []
        if multipart_file is not None:
            files.append(multipart_file)
        files.extend(list(multipart_files or []))
        for entry in files:
            if len(entry) >= 4:
                field_name, filename, file_bytes, content_type = entry[:4]
            else:
                field_name, filename, file_bytes = entry[:3]
                content_type = "application/octet-stream"
            filename = Path(str(filename)).name.replace('"', '')
            chunks.extend([
                f"--{boundary}\r\n".encode(),
                f'Content-Disposition: form-data; name="{field_name}"; filename="{filename}"\r\n'.encode(),
                f"Content-Type: {content_type}\r\n\r\n".encode(),
                bytes(file_bytes), b"\r\n",
            ])
        chunks.append(f"--{boundary}--\r\n".encode())
        data = b"".join(chunks)
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
    elif json_body is not None:
        data = json.dumps(json_body, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json; charset=utf-8"

    request = urllib.request.Request(url, data=data, headers=headers, method=str(method).upper())
    tls_contexts = _marketplace_ssl_contexts() if url.startswith("https://") else [("plain HTTP", None)]
    last_cert_error = None

    for _label, context in tls_contexts:
        try:
            kwargs = {"timeout": timeout}
            if context is not None:
                kwargs["context"] = context
            with urllib.request.urlopen(request, **kwargs) as response:
                payload = response.read(response_limit + 1)
                if len(payload) > response_limit:
                    raise ValueError("Marketplace response was too large.")
                if raw:
                    return payload
                if not payload:
                    return {}
                decoded = json.loads(payload.decode("utf-8", errors="strict"))
                return decoded if isinstance(decoded, (dict, list)) else {}
        except urllib.error.URLError as exc:
            if _is_certificate_error(exc):
                last_cert_error = exc
                continue
            raise RuntimeError(_marketplace_error_message(exc)) from exc
        except ssl.SSLCertVerificationError as exc:
            last_cert_error = exc
            continue
        except Exception as exc:
            raise RuntimeError(_marketplace_error_message(exc)) from exc

    if last_cert_error is not None:
        raise RuntimeError(_marketplace_error_message(last_cert_error)) from last_cert_error
    raise RuntimeError("Could not establish a secure marketplace connection.")


def marketplace_package_manifest(path):
    record = read_extension_package(path)
    manifest = record.get("manifest") or {}
    if not manifest:
        raise ValueError("The extension package does not contain a valid manifest.")
    return record, manifest


def _marketplace_icon_file(record):
    raw = bytes(record.get("icon_bytes") or b"")
    manifest = record.get("manifest") or {}
    name = Path(str(manifest.get("icon") or "icon.png")).name or "icon.png"
    if not raw or len(raw) > MARKETPLACE_ICON_LIMIT:
        return None
    suffix = Path(name).suffix.casefold()
    content_type = {
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".webp": "image/webp",
        ".gif": "image/gif",
        ".bmp": "image/bmp",
    }.get(suffix, "application/octet-stream")
    return ("icon", name, raw, content_type)


class IssueStatusLabel(QLabel):
    def __init__(self, text="", parent=None):
        super().__init__(parent)
        self.setText("" if text.startswith("Loading") else text)

    def setText(self, text):
        super().setText(text)
        self.setVisible(bool(text))


class MarketplaceAccountDialog(QDialog):
    def __init__(self, marketplace):
        super().__init__(marketplace)
        self.marketplace = marketplace
        self.events = queue.Queue()
        self.setWindowTitle("LelSploit Account")
        self.setModal(True)
        self.resize(390, 235)
        apply_window_icon(self)
        root = blur_content_layout(self, self, "LelSploit Account", (18, 15, 18, 18), 9)
        hint = QLabel("Accounts are only required to publish and manage extensions. No email is required.")
        hint.setWordWrap(True)
        hint.setObjectName("extensionDescription")
        root.addWidget(hint)
        self.username = QLineEdit()
        self.username.setPlaceholderText("Username")
        root.addWidget(self.username)
        self.password = QLineEdit()
        self.password.setPlaceholderText("Password")
        self.password.setEchoMode(QLineEdit.EchoMode.Password)
        self.password.returnPressed.connect(lambda: self.submit("login"))
        root.addWidget(self.password)
        self.status = IssueStatusLabel("")
        self.status.setWordWrap(True)
        self.status.setObjectName("extensionMeta")
        root.addWidget(self.status)
        row = QHBoxLayout()
        row.addStretch(1)
        self.login = QPushButton("Log in")
        self.register = QPushButton("Create account")
        user_icon = app_icon("user")
        if not user_icon.isNull():
            self.login.setIcon(user_icon)
            self.login.setIconSize(QSize(17, 17))
            self.register.setIcon(user_icon)
            self.register.setIconSize(QSize(17, 17))
        self.login.clicked.connect(lambda: self.submit("login"))
        self.register.clicked.connect(lambda: self.submit("register"))
        row.addWidget(self.login)
        row.addWidget(self.register)
        root.addLayout(row)
        self.timer = QTimer(self)
        self.timer.setInterval(50)
        self.timer.timeout.connect(self.poll)
        self.timer.start()
        self.setStyleSheet("""
            QDialog { background:#08090a; color:#e8e9ea; }
            QLabel { color:#aeb0b5; }
            QLineEdit { background:#0d0d0f; border:1px solid #2c2c31; border-radius:7px; padding:8px; color:#f0f0f2; }
            QPushButton { background:#121318; color:#eee; border:1px solid #303139; border-radius:6px; padding:7px 11px; }
            QPushButton:hover { background:#1a1c22; }
        """)
        apply_blur_style(self)

    def submit(self, action):
        username = self.username.text().strip()
        password = self.password.text()
        if len(username) < 3 or not password:
            self.status.setText("Enter a username (3+ characters) and password.")
            return
        self.login.setEnabled(False)
        self.register.setEnabled(False)
        self.status.setText("")
        base = self.marketplace.api_base

        def worker():
            try:
                payload = marketplace_request(
                    base,
                    f"/api/auth/{action}",
                    "POST",
                    json_body={"username": username, "password": password},
                )
                self.events.put(("ok", payload))
            except Exception as exc:
                self.events.put(("error", str(exc)))

        threading.Thread(target=worker, daemon=True).start()

    def poll(self):
        try:
            kind, payload = self.events.get_nowait()
        except queue.Empty:
            return
        self.login.setEnabled(True)
        self.register.setEnabled(True)
        if kind == "error":
            self.status.setText(payload)
            return
        token = str(payload.get("token") or "")
        user = payload.get("user") if isinstance(payload.get("user"), dict) else {}
        if not token:
            self.status.setText("The marketplace did not return a session token.")
            return
        self.marketplace.owner.settings.setValue("extension_marketplace/token", token)
        self.marketplace.owner.settings.setValue(
            "extension_marketplace/username",
            str(user.get("username") or self.username.text().strip()),
        )
        self.marketplace.owner.settings.sync()
        self.marketplace.refresh_account_state()
        self.accept()


class ExtensionMarketplacePane(QWidget):
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
        self.token = _marketplace_api_token(owner.settings)
        self._active = False
        self._market_icon_cache = {}
        self._market_icon_pending = set()

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(9)

        self.account_button = QPushButton()
        self.account_button.setFixedHeight(34)
        self.account_button.setMinimumWidth(92)
        self._set_button_icon(self.account_button, "user")
        self.account_button.clicked.connect(self.account_action)

        search_row = QHBoxLayout()
        search_row.setContentsMargins(0, 0, 0, 0)
        search_row.setSpacing(8)
        self.search = SearchLineEdit()
        self.search.setPlaceholderText("Search extensions, authors, or descriptions...")
        self.search.setClearButtonEnabled(True)
        self.search.setFixedHeight(46)
        self.search.setMinimumWidth(420)
        self.search.returnPressed.connect(self.refresh)
        search_row.addWidget(self.search, 1)
        self.upload_button = QPushButton("Upload")
        self.upload_button.setFixedHeight(46)
        self.upload_button.setMinimumWidth(108)
        self._set_button_icon(self.upload_button, "upload")
        self.upload_button.clicked.connect(self.upload_extension)
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
        self._set_button_icon(
            self.favorites_button,
            "stared" if not app_icon("stared").isNull() else "star",
        )
        self.favorites_button.toggled.connect(self.set_favorites_only)
        filters.addWidget(self.favorites_button)

        self.my_button = QPushButton("My Extensions")
        self.my_button.setCheckable(True)
        self._set_button_icon(self.my_button, "extensions")
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

        self.setStyleSheet("""
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

    @staticmethod
    def _set_button_icon(button, name, size=17):
        icon = app_icon(name)
        if not icon.isNull():
            button.setIcon(icon)
            button.setIconSize(QSize(size, size))

    def _queue_search(self):
        if self._active:
            self.search_timer.start()

    def activate(self):
        self._active = True
        self.api_base = MARKETPLACE_DEFAULT_API.rstrip("/")
        self.token = _marketplace_api_token(self.owner.settings)
        self.refresh_account_state()
        self.refresh()

    def deactivate(self):
        self._active = False
        self.search_timer.stop()

    def favorite_ids(self):
        value = self.owner.settings.value("extension_marketplace/favorites", [])
        return {str(x) for x in value} if isinstance(value, list) else set()

    def save_favorite_ids(self, ids):
        self.owner.settings.setValue("extension_marketplace/favorites", sorted(set(ids)))
        self.owner.settings.sync()

    def refresh_account_state(self):
        self.token = _marketplace_api_token(self.owner.settings)
        username = str(self.owner.settings.value("extension_marketplace/username", "") or "")
        logged_in = bool(self.token)

        if logged_in:
            self.account_button.setText(username or "Account")
            self.account_button.setToolTip("Log out")
        else:
            self.account_button.setText("Login")
            self.account_button.setToolTip("Log in or create a LelSploit account")

        
        
        self.upload_button.setVisible(True)
        self.upload_button.setToolTip("Upload an extension" if logged_in else "Log in / register to upload an extension")

        
        self.my_button.setVisible(logged_in)
        if not logged_in and self.my_only:
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
            base = self.api_base
            self.owner.settings.setValue("extension_marketplace/token", "")
            self.owner.settings.setValue("extension_marketplace/username", "")
            self.owner.settings.sync()
            self.refresh_account_state()
            threading.Thread(
                target=lambda: self._quiet_logout(base, token),
                daemon=True,
            ).start()
            self.refresh()
            return
        MarketplaceAccountDialog(self).exec()
        self.refresh_account_state()
        if self.token:
            self.refresh()

    @staticmethod
    def _quiet_logout(base, token):
        try:
            marketplace_request(base, "/api/auth/logout", "POST", token=token)
        except Exception:
            pass

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
        base = self.api_base
        my_only = self.my_only and bool(token)

        def worker():
            try:
                if my_only:
                    payload = marketplace_request(base, "/api/me/extensions", token=token)
                else:
                    qs = urllib.parse.urlencode({"q": query, "sort": sort, "limit": 100})
                    payload = marketplace_request(base, "/api/extensions?" + qs, token=token)
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
                QMessageBox.warning(self, "Extension Marketplace", str(payload))
            elif kind == "icon":
                key = str(rid)
                self._market_icon_pending.discard(key)
                pixmap = QPixmap()
                icon = QIcon()
                if payload and pixmap.loadFromData(bytes(payload)):
                    icon = QIcon(pixmap)
                self._market_icon_cache[key] = icon
                self._refresh_market_icon_labels(key)
            elif kind == "installed":
                self.status.setText("")
                self.owner.refresh_extensions_runtime()
                window = getattr(self.owner, "extensions_window", None)
                if window is not None:
                    window.reload()

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
            empty = QLabel("No extensions found." if not self.favorite_only else "No favorite extensions yet.")
            empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
            empty.setStyleSheet("padding:28px;color:#777a80;")
            cards.addWidget(empty)
        else:
            for item in items:
                cards.addWidget(
                    self.build_card(
                        item,
                        str(item.get("id")) in favorites or bool(item.get("favorited")),
                        self.my_only,
                    )
                )
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
        icon_label.setObjectName("marketExtensionIcon")
        icon_label.setFixedSize(44, 44)
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon_label.setProperty("extensionId", str(item.get("id") or ""))
        self._apply_marketplace_icon(icon_label, item)
        root.addWidget(icon_label, 0, Qt.AlignmentFlag.AlignTop)

        info = QVBoxLayout()
        info.setSpacing(3)
        title = QLabel(str(item.get("name") or "Untitled extension"))
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
            edit.clicked.connect(lambda checked=False, x=item: self.edit_extension(x))
            actions.addWidget(edit)
            update = self._icon_button("upload", "Upload an updated .lext package")
            update.clicked.connect(lambda checked=False, x=item: self.update_package(x))
            actions.addWidget(update)
            published = bool(item.get("published", True))
            pub = self._icon_button("disable" if published else "enable", "Unpublish" if published else "Republish")
            pub.clicked.connect(lambda checked=False, x=item: self.set_published(x, not published))
            actions.addWidget(pub)
            remove = self._icon_button("remove", "Permanently remove extension", "marketDanger")
            remove.clicked.connect(lambda checked=False, x=item: self.delete_extension(x))
            actions.addWidget(remove)
        else:
            install = QPushButton("Install")
            self._set_button_icon(install, "install")
            button_height = max(34, install.sizeHint().height())
            install.setFixedHeight(button_height)
            install.clicked.connect(lambda checked=False, x=item: self.install_extension(x))
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

    @staticmethod
    def _missing_extension_icon():
        path = ICON_DIR / "missing.png"
        if path.is_file():
            icon = QIcon(str(path))
            if not icon.isNull():
                return icon
        icon = app_icon("missing")
        return icon if not icon.isNull() else QIcon()

    def _apply_marketplace_icon(self, label, item):
        key = str(item.get("id") or "")
        icon = self._market_icon_cache.get(key)
        if isinstance(icon, QIcon) and not icon.isNull():
            label.setPixmap(icon.pixmap(38, 38))
            return
        missing = self._missing_extension_icon()
        if not missing.isNull():
            label.setPixmap(missing.pixmap(38, 38))
        if key and bool(item.get("hasIcon")) and key not in self._market_icon_cache and key not in self._market_icon_pending:
            self._market_icon_pending.add(key)
            base = self.api_base
            def worker():
                try:
                    raw = marketplace_request(
                        base,
                        f"/api/extensions/{urllib.parse.quote(key)}/icon",
                        raw=True,
                        timeout=15,
                        response_limit=MARKETPLACE_ICON_LIMIT,
                    )
                    self.events.put(("icon", key, raw))
                except Exception:
                    self.events.put(("icon", key, b""))
            threading.Thread(target=worker, daemon=True).start()

    def _refresh_market_icon_labels(self, key):
        icon = self._market_icon_cache.get(str(key))
        if not isinstance(icon, QIcon) or icon.isNull():
            return
        for label in self.findChildren(QLabel, "marketExtensionIcon"):
            if str(label.property("extensionId") or "") == str(key):
                label.setPixmap(icon.pixmap(38, 38))

    def toggle_favorite(self, item):
        key = str(item.get("id") or "")
        if not key:
            return
        ids = self.favorite_ids()
        was_favorite = key in ids or bool(item.get("favorited"))
        if was_favorite:
            ids.discard(key)
        else:
            ids.add(key)
        self.save_favorite_ids(ids)
        item["favorited"] = not was_favorite
        if self.token:
            try:
                count = int(item.get("favorites") or 0)
                item["favorites"] = max(0, count + (-1 if was_favorite else 1))
            except Exception:
                pass
        self.render_items()
        if self.token:
            base = self.api_base
            token = self.token
            method = "DELETE" if was_favorite else "POST"
            path = f"/api/extensions/{urllib.parse.quote(key)}/favorite"

            def worker():
                try:
                    marketplace_request(base, path, method, token=token)
                except Exception:
                    pass

            threading.Thread(target=worker, daemon=True).start()

    def ensure_login(self):
        if self.token:
            return True
        result = MarketplaceAccountDialog(self).exec()
        self.refresh_account_state()
        return result == QDialog.DialogCode.Accepted and bool(self.token)

    def upload_extension(self):
        if not self.ensure_login():
            return
        path, _ = QFileDialog.getOpenFileName(self, "Upload Extension", "", "LelSploit extensions (*.lext)")
        if not path:
            return
        source = Path(path)
        try:
            if source.stat().st_size > MARKETPLACE_PACKAGE_LIMIT:
                raise ValueError("Marketplace extensions are limited to 10 MiB.")
            record, manifest = marketplace_package_manifest(source)
            raw = source.read_bytes()
        except Exception as exc:
            QMessageBox.warning(self, "Upload Extension", str(exc))
            return
        name, ok = QInputDialog.getText(
            self,
            "Extension name",
            "Name:",
            QLineEdit.EchoMode.Normal,
            str(manifest.get("name") or source.stem),
        )
        if not ok or not name.strip():
            return
        version, ok = QInputDialog.getText(
            self,
            "Extension version",
            "Version:",
            QLineEdit.EchoMode.Normal,
            str(manifest.get("version") or "1.0"),
        )
        if not ok or not version.strip():
            return
        description, ok = QInputDialog.getMultiLineText(
            self,
            "Extension description",
            "Description:",
            str(manifest.get("description") or ""),
        )
        if not ok:
            return
        icon_file = _marketplace_icon_file(record)
        fields = {
            "name": name.strip(),
            "version": version.strip(),
            "description": description.strip(),
            "manifestId": str(manifest.get("id") or ""),
            "iconState": "present" if icon_file is not None else "missing",
        }
        self.action_request(
            "POST",
            "/api/extensions",
            fields=fields,
            file_tuple=("package", source.name, raw),
            extra_files=[icon_file] if icon_file is not None else None,
            success="Extension uploaded.",
        )

    def edit_extension(self, item):
        name, ok = QInputDialog.getText(
            self, "Edit extension", "Name:", QLineEdit.EchoMode.Normal, str(item.get("name") or "")
        )
        if not ok or not name.strip():
            return
        version, ok = QInputDialog.getText(
            self,
            "Edit extension",
            "Version:",
            QLineEdit.EchoMode.Normal,
            str(item.get("version") or "1.0"),
        )
        if not ok or not version.strip():
            return
        description, ok = QInputDialog.getMultiLineText(
            self, "Edit extension", "Description:", str(item.get("description") or "")
        )
        if not ok:
            return
        self.action_request(
            "PATCH",
            f"/api/extensions/{urllib.parse.quote(str(item.get('id')))}",
            json_body={"name": name.strip(), "version": version.strip(), "description": description.strip()},
            success="Extension updated.",
        )

    def update_package(self, item):
        path, _ = QFileDialog.getOpenFileName(self, "Update Extension Package", "", "LelSploit extensions (*.lext)")
        if not path:
            return
        source = Path(path)
        try:
            if source.stat().st_size > MARKETPLACE_PACKAGE_LIMIT:
                raise ValueError("Marketplace extensions are limited to 10 MiB.")
            record, manifest = marketplace_package_manifest(source)
            raw = source.read_bytes()
        except Exception as exc:
            QMessageBox.warning(self, "Update Extension", str(exc))
            return
        icon_file = _marketplace_icon_file(record)
        fields = {
            "version": str(manifest.get("version") or item.get("version") or "1.0"),
            "manifestId": str(manifest.get("id") or ""),
            "iconState": "present" if icon_file is not None else "missing",
        }
        self.action_request(
            "PUT",
            f"/api/extensions/{urllib.parse.quote(str(item.get('id')))}/package",
            fields=fields,
            file_tuple=("package", source.name, raw),
            extra_files=[icon_file] if icon_file is not None else None,
            success="Package updated.",
        )

    def set_published(self, item, published):
        self.action_request(
            "PATCH",
            f"/api/extensions/{urllib.parse.quote(str(item.get('id')))}",
            json_body={"published": bool(published)},
            success="Extension republished." if published else "Extension unpublished.",
        )

    def delete_extension(self, item):
        answer = QMessageBox.question(
            self,
            "Remove extension?",
            f"Permanently remove {item.get('name') or 'this extension'} from the marketplace?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        if answer != QMessageBox.StandardButton.Yes:
            return
        self.action_request(
            "DELETE",
            f"/api/extensions/{urllib.parse.quote(str(item.get('id')))}",
            success="Extension removed.",
        )

    def action_request(self, method, path, json_body=None, fields=None, file_tuple=None, extra_files=None, success="Done."):
        if not self.ensure_login():
            return
        base = self.api_base
        token = self.token

        def worker():
            try:
                marketplace_request(
                    base,
                    path,
                    method,
                    token=token,
                    json_body=json_body,
                    multipart_fields=fields,
                    multipart_file=file_tuple,
                    multipart_files=extra_files,
                    timeout=30,
                )
                self.events.put(("action_ok", self.request_id, success))
            except Exception as exc:
                self.events.put(("action_error", self.request_id, str(exc)))

        threading.Thread(target=worker, daemon=True).start()
        self.status.setText("")

    def install_extension(self, item):
        ext_id = urllib.parse.quote(str(item.get("id") or ""))
        name = str(item.get("name") or "extension")
        base = self.api_base
        self.status.setText("")

        def worker():
            try:
                raw = marketplace_request(
                    base,
                    f"/api/extensions/{ext_id}/download",
                    response_limit=MARKETPLACE_PACKAGE_LIMIT,
                    raw=True,
                    timeout=30,
                )
                if not raw or len(raw) > MARKETPLACE_PACKAGE_LIMIT:
                    raise ValueError("Downloaded extension exceeds the 10 MiB limit.")
                EXTENSIONS_DIR.mkdir(parents=True, exist_ok=True)
                temp = EXTENSIONS_DIR / (".marketplace-" + hashlib.sha256(raw).hexdigest()[:16] + ".lext")
                temp.write_bytes(raw)
                try:
                    record = read_extension_package(temp)
                    target = EXTENSIONS_DIR / (str(record["manifest"]["id"]) + ".lext")
                    if target.exists():
                        target.unlink()
                    os.replace(temp, target)
                    self.events.put(("installed", self.request_id, f"Installed {record['manifest']['name']}."))
                finally:
                    temp.unlink(missing_ok=True)
            except Exception as exc:
                self.events.put(("action_error", self.request_id, str(exc)))

        threading.Thread(target=worker, daemon=True).start()


class ExtensionsWindow(QDialog):


    def __init__(self, parent):
        if not _HOST_CONFIGURED:
            raise RuntimeError("lelsploit_extensions.configure_host() must be called before opening ExtensionsWindow.")
        super().__init__(parent)
        self.owner = parent
        self.view_mode = "installed"
        self.setWindowTitle("Extensions")
        self.resize(820, 660)
        self.setMinimumSize(650, 470)
        apply_window_icon(self)

        layout = blur_content_layout(self, self, "Extensions", (18, 12, 18, 16), 9)
        top = QHBoxLayout()
        top.setContentsMargins(0, 0, 0, 0)

        self.view_group = QButtonGroup(self)
        self.view_group.setExclusive(True)

        self.installed_button = QPushButton("Installed")
        self.installed_button.setCheckable(True)
        self.installed_button.setChecked(True)
        icon = app_icon("extensions")
        if not icon.isNull():
            self.installed_button.setIcon(icon)
            self.installed_button.setIconSize(QSize(17, 17))
        self.installed_button.clicked.connect(lambda: self.set_view("installed"))
        self.view_group.addButton(self.installed_button)
        top.addWidget(self.installed_button)

        self.templates_button = QPushButton("Templates")
        self.templates_button.setCheckable(True)
        template_icon = app_icon("template")
        if not template_icon.isNull():
            self.templates_button.setIcon(template_icon)
            self.templates_button.setIconSize(QSize(17, 17))
        self.templates_button.clicked.connect(lambda: self.set_view("templates"))
        self.view_group.addButton(self.templates_button)
        top.addWidget(self.templates_button)

        self.marketplace_button = QPushButton("Marketplace")
        self.marketplace_button.setCheckable(True)
        market_icon = app_icon("marketplace")
        if not market_icon.isNull():
            self.marketplace_button.setIcon(market_icon)
            self.marketplace_button.setIconSize(QSize(17, 17))
        self.marketplace_button.clicked.connect(lambda: self.set_view("marketplace"))
        self.view_group.addButton(self.marketplace_button)
        top.addWidget(self.marketplace_button)

        top.addStretch(1)
        self.install_button = QPushButton("Import Extension")
        self.install_button.setObjectName("extensionPrimary")
        if not icon.isNull():
            self.install_button.setIcon(icon)
            self.install_button.setIconSize(QSize(17, 17))
        self.install_button.setCursor(Qt.CursorShape.PointingHandCursor)
        self.install_button.clicked.connect(self.install_extension)
        top.addWidget(self.install_button)

        self.marketplace_page = ExtensionMarketplacePane(self.owner, self)
        top.addWidget(self.marketplace_page.account_button, 0, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        layout.addLayout(top)

        self.stack = QStackedWidget()
        self.stack.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.stack, 1)

        self.local_page = QWidget()
        local_layout = QVBoxLayout(self.local_page)
        local_layout.setContentsMargins(0, 0, 0, 0)
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QFrame.Shape.NoFrame)
        self.scroll.setObjectName("extensionScroll")
        local_layout.addWidget(self.scroll)
        self.stack.addWidget(self.local_page)

        self.stack.addWidget(self.marketplace_page)

        self.setStyleSheet(r"""
            QDialog { background: #08090a; color: #e8e9ea; }
            QWidget { background: transparent; color: #e8e9ea; }
            QLabel { background: transparent; }
            QScrollArea#extensionScroll { background: transparent; border: none; }
            QFrame#extensionCard, QFrame#templateCard { background: #0a0a0c; border: 1px solid #25252a; border-radius: 8px; }
            QFrame#extensionCard:hover, QFrame#templateCard:hover { border-color: #33333a; background: #0d0d10; }
            QLabel#extensionTitle { color: #f1f1f3; font-size: 13px; font-weight: 600; }
            QLabel#extensionMeta { color: #85858c; font-size: 10px; }
            QLabel#extensionDescription { color: #aaaaaf; }
            QLabel#extensionDescription a { color: #82aee8; }
            QLabel#extensionError { color: #e99191; }
            QLabel#extensionEmpty { color: #77777d; padding: 22px 10px; }
            QLabel#extensionSection { color:#d6d6da; font-size:12px; font-weight:600; padding: 8px 1px 2px 1px; }
            QPushButton { background:#121214; color:#e9e9eb; border:1px solid #2b2b30; border-radius:5px; padding:6px 10px; }
            QPushButton:hover { background:#1a1a1e; border-color:#3a3a41; }
            QPushButton:checked { background:#1c2025; border-color:#3d4855; color:#fff; }
            QPushButton:disabled { color:#5f5f66; background:#0c0c0e; border-color:#202024; }
            QPushButton#extensionPrimary { background:#15181d; border-color:#303641; }
            QPushButton#extensionPrimary:hover { background:#1d222a; border-color:#424a58; }
            QPushButton#extensionIconButton, QPushButton#extensionRemoveIcon { padding:0; min-width:30px; max-width:30px; min-height:30px; max-height:30px; }
            QPushButton#extensionRemoveIcon:hover { background:#241516; border-color:#553033; }
            QScrollBar:vertical { width:9px; background:transparent; }
            QScrollBar::handle:vertical { background:#35353b; border-radius:4px; min-height:28px; }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height:0; }
        """)
        apply_blur_style(self)
        self._folder_signature = None
        self.reload()
        self._folder_watch_timer = QTimer(self)
        self._folder_watch_timer.setInterval(1200)
        self._folder_watch_timer.timeout.connect(self._poll_extension_folder)
        self._folder_watch_timer.start()

    def showEvent(self, event):
        super().showEvent(event)
        if self.view_mode == "marketplace":
            self.marketplace_page.activate()
        else:
            self.reload()

    def hideEvent(self, event):
        self.marketplace_page.deactivate()
        super().hideEvent(event)

    def set_view(self, mode):
        mode = str(mode or "installed")
        if mode not in {"installed", "templates", "marketplace"}:
            mode = "installed"
        self.view_mode = mode

        mapping = {
            "installed": self.installed_button,
            "templates": self.templates_button,
            "marketplace": self.marketplace_button,
        }
        for key, button in mapping.items():
            button.blockSignals(True)
            button.setChecked(key == mode)
            button.blockSignals(False)

        if mode == "marketplace":
            self.install_button.setVisible(False)
            self.stack.setCurrentWidget(self.marketplace_page)
            self.marketplace_page.activate()
        else:
            self.marketplace_page.deactivate()
            self.install_button.setVisible(mode == "installed")
            self.stack.setCurrentWidget(self.local_page)
            self.reload()

    @staticmethod
    def _markdown_label(text):
        label = QLabel(str(text or "No description found"))
        label.setObjectName("extensionDescription")
        label.setWordWrap(True)
        label.setTextFormat(Qt.TextFormat.MarkdownText)
        label.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        return label

    @staticmethod
    def _image_action_button(icon_name, tooltip, object_name="extensionIconButton"):
        button = QPushButton()
        button.setObjectName(object_name)
        button.setFixedSize(30, 30)
        button.setToolTip(tooltip)
        button.setCursor(Qt.CursorShape.PointingHandCursor)
        button.setProperty("_lel_icon_name", icon_name)
        icon = app_icon(icon_name)
        if icon.isNull():
            for path in (IMAGES_DIR / f"{icon_name}.png", ICON_DIR / f"{icon_name}.png"):
                if path.is_file():
                    icon = QIcon(str(path))
                    break
        if not icon.isNull():
            button.setIcon(icon)
            button.setIconSize(QSize(17, 17))
        return button

    def _extension_icon(self, record):
        icon_bytes = record.get("icon_bytes", b"")
        if icon_bytes:
            pixmap = QPixmap()
            if pixmap.loadFromData(icon_bytes):
                return QIcon(pixmap)
        missing = ICON_DIR / "missing.png"
        if missing.is_file():
            icon = QIcon(str(missing))
            if not icon.isNull():
                return icon
        icon = app_icon("missing")
        return icon if not icon.isNull() else QIcon()

    @staticmethod
    def _extension_folder_signature():
        return extension_folder_signature()

    def _poll_extension_folder(self):
        if not self.isVisible():
            return
        signature = self._extension_folder_signature()
        if signature != self._folder_signature:
            self.owner.refresh_extensions_runtime()
            if self.view_mode != "marketplace":
                self.reload()
            else:
                self._folder_signature = signature

    def _clear_cards(self):
        old = self.scroll.takeWidget()
        if old is not None:
            old.deleteLater()

    def reload(self):
        records = scan_extension_packages()
        self._folder_signature = self._extension_folder_signature()
        if self.view_mode == "marketplace":
            return

        self._clear_cards()
        disabled = set(load_extension_state().get("disabled", []))
        installed_ids = {r["manifest"]["id"] for r in records if r.get("manifest")}
        content = QWidget()
        content.setStyleSheet("background:transparent;")
        cards = QVBoxLayout(content)
        cards.setContentsMargins(0, 2, 4, 2)
        cards.setSpacing(8)

        if self.view_mode == "templates":
            available = [t for t in EXTENSION_TEMPLATES if t["id"] not in installed_ids]
            if not available:
                empty = QLabel("All built-in templates are already installed.")
                empty.setObjectName("extensionEmpty")
                empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
                cards.addWidget(empty)
            else:
                for template in available:
                    cards.addWidget(self._build_template_card(template))
        else:
            if not records:
                empty = QLabel("No extensions installed.")
                empty.setObjectName("extensionEmpty")
                empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
                cards.addWidget(empty)
            else:
                for record in records:
                    cards.addWidget(self._build_card(record, disabled))
        cards.addStretch(1)
        self.scroll.setWidget(content)

    def _build_card(self, record, disabled):
        card = QFrame()
        card.setObjectName("extensionCard")
        root = QHBoxLayout(card)
        root.setContentsMargins(12, 11, 11, 11)
        root.setSpacing(11)
        icon_label = QLabel()
        icon_label.setFixedSize(46, 46)
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon = self._extension_icon(record)
        if not icon.isNull():
            icon_label.setPixmap(icon.pixmap(40, 40))
            root.addWidget(icon_label, 0, Qt.AlignmentFlag.AlignTop)
        info = QVBoxLayout()
        info.setContentsMargins(0, 0, 0, 0)
        info.setSpacing(3)
        manifest = record.get("manifest")
        if manifest is None:
            title = QLabel("No title found")
            title.setObjectName("extensionTitle")
            info.addWidget(title)
            info.addWidget(self._markdown_label("No description found"))
            error = QLabel(record.get("error", "Invalid extension package"))
            error.setObjectName("extensionError")
            error.setWordWrap(True)
            info.addWidget(error)
        else:
            title = QLabel(manifest.get("name") or "No title found")
            title.setObjectName("extensionTitle")
            info.addWidget(title)
            meta_bits = [f"v{manifest['version']}", manifest["id"]]
            if manifest.get("permissions"):
                meta_bits.append("permissions: " + ", ".join(manifest["permissions"]))
            meta = QLabel("  ·  ".join(meta_bits))
            meta.setObjectName("extensionMeta")
            meta.setWordWrap(True)
            info.addWidget(meta)
            info.addWidget(self._markdown_label(manifest.get("description") or "No description found"))
        root.addLayout(info, 1)
        buttons = QVBoxLayout()
        buttons.setContentsMargins(0, 0, 0, 0)
        buttons.setSpacing(6)
        if manifest is not None:
            ext_id = manifest["id"]
            is_disabled = ext_id in disabled
            toggle = self._image_action_button(
                "run" if is_disabled else "disable",
                "Enable extension" if is_disabled else "Disable extension",
            )
            toggle.clicked.connect(lambda checked=False, eid=ext_id: self.toggle_extension(eid))
            buttons.addWidget(toggle)
        remove = self._image_action_button("remove", "Remove extension", "extensionRemoveIcon")
        remove.clicked.connect(lambda checked=False, r=record: self.remove_extension(r))
        buttons.addWidget(remove)
        buttons.addStretch(1)
        root.addLayout(buttons)
        return card

    def _build_template_card(self, template):
        card = QFrame()
        card.setObjectName("templateCard")
        root = QHBoxLayout(card)
        root.setContentsMargins(12, 11, 11, 11)
        root.setSpacing(11)
        icon_label = QLabel()
        icon_label.setFixedSize(46, 46)
        icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon = app_icon("template")
        if icon.isNull():
            icon = extension_template_icon()
        if not icon.isNull():
            icon_label.setPixmap(icon.pixmap(40, 40))
            root.addWidget(icon_label, 0, Qt.AlignmentFlag.AlignTop)
        info = QVBoxLayout()
        info.setSpacing(3)
        title = QLabel(template["name"])
        title.setObjectName("extensionTitle")
        info.addWidget(title)
        meta = QLabel("Template  ·  " + ", ".join(template.get("permissions", [])))
        meta.setObjectName("extensionMeta")
        info.addWidget(meta)
        info.addWidget(self._markdown_label(template["description"]))
        root.addLayout(info, 1)
        install = self._image_action_button("install", "Install template")
        install.clicked.connect(lambda checked=False, t=template: self.install_template(t))
        root.addWidget(install, 0, Qt.AlignmentFlag.AlignTop)
        return card

    def install_template(self, template):
        try:
            target = write_extension_template(template)
            record = read_extension_package(target)
            self.owner.log(f"Installed extension template {record['manifest']['name']}.", "success")
            self.owner.refresh_extensions_runtime(restart_id=record["manifest"]["id"])
            self.reload()
        except Exception as exc:
            QMessageBox.warning(self, "Install template", f"Could not install this template.\n\n{exc}")

    def install_extension(self):
        path, _ = QFileDialog.getOpenFileName(self, "Import Extension", "", "LelSploit extensions (*.lext)")
        if not path:
            return
        source = Path(path)
        try:
            if source.stat().st_size > EXTENSION_PACKAGE_LIMIT:
                raise ValueError("Extensions are limited to 10 MiB.")
            record = read_extension_package(source)
            EXTENSIONS_DIR.mkdir(parents=True, exist_ok=True)
            target = EXTENSIONS_DIR / source.name
            if target.exists() and target.resolve() != source.resolve():
                answer = QMessageBox.question(
                    self,
                    "Replace extension?",
                    f"{target.name} is already installed. Replace it?",
                    QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                    QMessageBox.StandardButton.No,
                )
                if answer != QMessageBox.StandardButton.Yes:
                    return
            if target.resolve() != source.resolve():
                shutil.copy2(source, target)
            self.owner.log(f"Installed extension {record['manifest']['name']}.", "success")
            self.owner.refresh_extensions_runtime(restart_id=record["manifest"]["id"])
            self.reload()
        except Exception as exc:
            QMessageBox.warning(self, "Import Extension", f"Could not import this extension.\n\n{exc}")

    def toggle_extension(self, ext_id):
        state = load_extension_state()
        disabled = set(state.get("disabled", []))
        if ext_id in disabled:
            disabled.discard(ext_id)
        else:
            disabled.add(ext_id)
        state["disabled"] = sorted(disabled)
        save_extension_state(state)
        self.owner.refresh_extensions_runtime(restart_id=ext_id if ext_id not in disabled else None)
        self.reload()

    def remove_extension(self, record):
        manifest = record.get("manifest")
        try:
            record["path"].unlink(missing_ok=True)
            if manifest:
                ext_id = manifest["id"]
                state = load_extension_state()
                disabled = set(state.get("disabled", []))
                disabled.discard(ext_id)
                state["disabled"] = sorted(disabled)
                state.get("data", {}).pop(ext_id, None)
                save_extension_state(state)
                shutil.rmtree(EXTENSION_DATA_DIR / ext_id, ignore_errors=True)
                self.owner.refresh_extensions_runtime()
            self.reload()
        except OSError as exc:
            QMessageBox.warning(self, "Remove extension", str(exc))


POWER_API_VERSION = 5
_POWER_API_INSTALLED = False
_POWER_OPERATIONS = {
    "storage.get": "storage",
    "storage.keys": "storage",
    "storage.has": "storage",
    "file.glob": "files",
    "file.hash": "files",
    "archive.create": "files",
    "archive.list": "files",
    "archive.extract": "files",
    "database.execute": "database",
    "database.query": "database",
    "database.scalar": "database",
    "ui.screen.list": "ui",
    "ui.window.list": "ui",
    "ui.view.close": "ui",
    "ui.view.update": "ui",
    "ui.widget.children": "ui",
    "ui.widget.snapshot": "ui",
    "json.keys": None,
    "json.length": None,
    "json.merge": None,
    "list.get": None,
    "list.length": None,
    "list.join": None,
    "list.sort": None,
    "list.unique": None,
    "list.slice": None,
    "crypto.hash": None,
    "random.secure": None,
    "date.add": None,
    "flow.try": None,
    "flow.switch": None,
}

EXTENSION_API5_DOCUMENTATION_HTML = r"""
<style>
body { color:#d4d4d4; font-family:'Segoe UI'; font-size:10.5pt; line-height:1.55; background:#0b0c0d; margin:0; }
h1,h2,h3 { color:#f0f0f2; } h1 { font-size:20pt; } h2 { margin-top:22px; font-size:14pt; } h3 { margin-top:15px; font-size:11.5pt; }
code,pre { font-family:Consolas,monospace; } code { color:#a9d8ff; } pre { background:#0b0b0d; border:1px solid #242429; padding:10px; border-radius:6px; white-space:pre-wrap; }
table { border-collapse:collapse; width:100%; margin:8px 0 14px 0; } th,td { border:1px solid #29292f; padding:6px 8px; text-align:left; vertical-align:top; } th { background:#101014; color:#f2f2f4; }
strong { color:#f3f3f5; } li { margin:3px 0; } .good { border-left:3px solid #316d4c; padding:7px 10px; background:#09100c; }
</style>
<h1>Extensions / LExt API 5</h1>
<p>LExt is LelSploit's capability-based extension platform. API 5 keeps the declarative package format while adding more application, data and UI building blocks so extensions can implement substantial features without arbitrary native execution.</p>
<p class="good"><b>Security boundary:</b> extensions do not receive Python execution, shell/process creation, DLL loading, registry access, arbitrary filesystem paths, private/LAN networking, raw credential access, or unrestricted OS automation. Writable files and databases stay inside the extension's own data directory. External files require a user picker. Public HTTP remains bounded and private-address destinations are rejected.</p>
<h2>Manifest</h2>
<pre>{
  "format": 1,
  "api": 5,
  "id": "author.extension",
  "name": "My Extension",
  "version": "1.0.0",
  "permissions": ["ui", "editor", "storage", "files", "database"]
}</pre>
<p>Existing API 1-4 extensions remain compatible. Permissions include <code>editor</code>, <code>clipboard</code>, <code>storage</code>, <code>ui</code>, <code>execute</code>, <code>fastflags</code>, <code>files</code>, <code>network</code>, <code>picker</code>, <code>settings</code>, <code>theme</code>, <code>roblox</code>, <code>proxy</code>, <code>app_files</code>, <code>extensions</code>, <code>sound</code> and API 5's sandboxed <code>database</code>.</p>
<h2>Application and UI</h2>
<p><code>ui.open</code>, <code>ui.window</code>, <code>ui.window.state</code>, <code>ui.window.list</code>, <code>ui.screen.list</code>, <code>ui.panel.open/close/update</code>, <code>ui.view.open/close/update</code>, <code>ui.toolbar.add/remove</code>, <code>ui.titlebar.add/remove</code>, <code>ui.menu.open</code>, <code>ui.widget.get/set/invoke/list/children/snapshot</code>, <code>ui.icon.list</code>, <code>ui.smooth_scroll</code> and <code>visual_wizard.enable</code>.</p>
<p>Declarative views support headings, Markdown, labels, text inputs, text areas, switches, checkboxes, combos, lists, sliders, colors, buttons, icon buttons, icons, cards, sections, rows, separators and spacers. Runtime views can now be closed and updated by id. Widget inspection remains restricted to LelSploit's own Qt widget tree.</p>
<h2>Editor and tabs</h2>
<p><code>editor.set/append/prepend/insert/clear/replace/select_all/goto_line/cursor/line/undo/redo/cut/copy/paste/duplicate_line/delete_line/new_tab</code>, <code>selection.info/replace/copy/delete</code> and <code>tabs.list/read/set/select/rename/close_current</code>.</p>
<h2>State, storage and data</h2>
<p><code>storage.set/get/delete/clear/keys/has</code>, <code>var.set/append/delete/number</code>, <code>json.get/set/keys/length/merge</code>, <code>list.get/length/join/sort/unique/slice</code>, <code>text.transform</code>, <code>math.eval/stats/vector/random</code>, <code>crypto.hash</code>, <code>random.secure</code>, <code>system.now/uuid/info</code> and <code>date.add</code>.</p>
<h2>Sandbox files, archives and database</h2>
<p><code>file.read/write/append/read_bytes/write_bytes/delete/list/exists/stat/mkdir/copy/move/glob/hash</code>. <code>archive.create/list/extract</code> works only inside the extension data sandbox and enforces entry/count/size/path-traversal limits. <code>database.execute/query/scalar</code> provides a private SQLite database per extension; dangerous database attachment, PRAGMA, VACUUM and extension-loading features are blocked.</p>
<h2>Dialogs, clipboard and flow</h2>
<p><code>dialog.input/multiline/choice/color/confirm</code>, <code>clipboard.get/set/append/clear</code>, <code>notify</code>, <code>message</code>, <code>flow.if/repeat/foreach/try/switch</code>, <code>action.run</code> and <code>timer.after/every/cancel</code>.</p>
<h2>Network and integrations</h2>
<p><code>http.request/download</code> supports bounded public HTTP(S). <code>roblox.state/join_context/players/server/client/request/attach/reattach/detach/execute</code>, <code>proxy.state/enable/disable/restart</code>, <code>fastflag.set/remove</code>, <code>extension.list/info/set_enabled/reload/remove</code>, <code>settings.get/set</code>, <code>theme.get/set/preset/reset</code>, <code>sound.beep/play/stop</code>, <code>package.read/list</code> and read-only <code>app.file.list/read/stat</code> are also available subject to their permissions.</p>
<h2>API 5 examples</h2>
<pre>{"op":"database.execute","sql":"CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY, text TEXT)"}
{"op":"database.query","sql":"SELECT id,text FROM notes ORDER BY id DESC LIMIT 25","save_as":"notes"}
{"op":"archive.create","path":"backup.zip","files":["settings.json","presets"]}
{"op":"ui.window.list","save_as":"windows"}
{"op":"ui.view.update","id":"dashboard","control":"status","property":"text","value":"Ready"}
{"op":"flow.try","steps":[{"op":"file.read","path":"data.json","save_as":"data"}],"catch":[{"op":"var.set","name":"data","value":"{}"}]}</pre>
"""


def _power_save(runtime, context, step, fallback, value):
    name = runtime._safe_save_name(step.get("save_as", fallback), fallback)
    if isinstance(value, (dict, list)):
        value = json.dumps(value, ensure_ascii=False)
    elif isinstance(value, bool):
        value = "true" if value else "false"
    elif value is None:
        value = ""
    context[f"var.{name}"] = runtime._bounded(value)
    return name


def _power_render_structure(runtime, value, context, depth=0):
    if depth > 12:
        raise ValueError("Structured extension value nests too deeply.")
    if isinstance(value, str):
        return runtime._render(value, context)
    if isinstance(value, list):
        if len(value) > 512:
            raise ValueError("Structured extension value is too large.")
        return [_power_render_structure(runtime, item, context, depth + 1) for item in value]
    if isinstance(value, dict):
        if len(value) > 256:
            raise ValueError("Structured extension value is too large.")
        return {str(key): _power_render_structure(runtime, item, context, depth + 1) for key, item in value.items()}
    return value


def _power_json_source(runtime, step, context, key="source", default="[]"):
    raw = runtime._render(step.get(key, default), context)
    try:
        return json.loads(raw)
    except Exception as exc:
        raise ValueError(f"{key} must contain valid JSON.") from exc


def _database_path(runtime, ext_id):
    root = EXTENSION_DATA_DIR / ext_id
    root.mkdir(parents=True, exist_ok=True)
    return root / "extension.sqlite3"


def _database_params(runtime, step, context):
    value = step.get("params", [])
    if isinstance(value, str):
        rendered = runtime._render(value, context).strip()
        if not rendered:
            return []
        try:
            value = json.loads(rendered)
        except Exception as exc:
            raise ValueError("database params must be a JSON array or object.") from exc
    value = _power_render_structure(runtime, value, context)
    if not isinstance(value, (list, dict)):
        raise ValueError("database params must be an array or object.")
    if len(value) > 128:
        raise ValueError("database params are limited to 128 values.")
    return value


def _database_sql(runtime, step, context, query=False):
    sql = runtime._render(step.get("sql", ""), context).strip()
    if not sql or len(sql) > 65536:
        raise ValueError("database sql must contain 1 to 65536 characters.")
    lowered = re.sub(r"\s+", " ", sql.casefold()).strip()
    blocked = ("attach ", "detach ", "pragma ", "vacuum", "load_extension", "readfile(", "writefile(")
    if any(token in lowered for token in blocked):
        raise PermissionError("This database statement is outside the extension database sandbox.")
    first = re.match(r"[a-z]+", lowered)
    keyword = first.group(0) if first else ""
    if query:
        if keyword != "select":
            raise ValueError("database.query and database.scalar only accept SELECT statements.")
    elif keyword not in {"create", "insert", "update", "delete", "replace", "drop", "alter"}:
        raise ValueError("database.execute accepts CREATE, INSERT, UPDATE, DELETE, REPLACE, DROP or ALTER statements.")
    return sql


def _database_json_value(value):
    if isinstance(value, bytes):
        return {"base64": base64.b64encode(value).decode("ascii")}
    return value


def _run_power_step(runtime, package, manifest, step, context):
    op = str(step.get("op", "")).strip()
    ext_id = manifest["id"]
    if op == "storage.get":
        key = runtime._render(step.get("key", ""), context).strip()
        state = load_extension_state()
        value = str(state.get("data", {}).get(ext_id, {}).get(key, runtime._render(step.get("default", ""), context)))
        context[f"storage.{key}"] = value
        _power_save(runtime, context, step, "value", value)
    elif op == "storage.keys":
        state = load_extension_state()
        keys = sorted(str(key) for key in state.get("data", {}).get(ext_id, {}).keys())
        _power_save(runtime, context, step, "keys", keys)
    elif op == "storage.has":
        key = runtime._render(step.get("key", ""), context).strip()
        state = load_extension_state()
        _power_save(runtime, context, step, "exists", key in state.get("data", {}).get(ext_id, {}))
    elif op == "file.glob":
        pattern = runtime._render(step.get("pattern", "**/*"), context).strip().replace("\\", "/") or "**/*"
        if pattern.startswith("/") or re.match(r"^[A-Za-z]:", pattern) or ".." in Path(pattern).parts:
            raise ValueError("file.glob pattern must stay inside the extension data folder.")
        root = EXTENSION_DATA_DIR / ext_id
        rows = []
        if root.is_dir():
            for path in sorted(root.rglob("*"), key=lambda item: str(item).casefold()):
                try:
                    rel = path.relative_to(root).as_posix()
                except ValueError:
                    continue
                if Path(rel).match(pattern) or fnmatch.fnmatch(rel, pattern):
                    rows.append({"path": rel, "file": path.is_file(), "directory": path.is_dir(), "size": int(path.stat().st_size) if path.is_file() else 0})
                if len(rows) >= 512:
                    break
        _power_save(runtime, context, step, "files", rows)
    elif op == "file.hash":
        target = runtime._extension_data_path(ext_id, runtime._render(step.get("path", ""), context))
        if not target.is_file():
            raise FileNotFoundError(str(target))
        if target.stat().st_size > 64 * 1024 * 1024:
            raise ValueError("file.hash is limited to 64 MiB files.")
        algorithm = runtime._render(step.get("algorithm", "sha256"), context).strip().casefold()
        if algorithm not in {"sha256", "sha512", "blake2b"}:
            raise ValueError("file.hash algorithm must be sha256, sha512 or blake2b.")
        digest = hashlib.new(algorithm)
        with target.open("rb") as handle:
            while True:
                chunk = handle.read(1024 * 1024)
                if not chunk:
                    break
                digest.update(chunk)
        _power_save(runtime, context, step, "hash", digest.hexdigest())
    elif op == "archive.create":
        destination = runtime._extension_data_path(ext_id, runtime._render(step.get("path", "archive.zip"), context), create_parent=True)
        root = (EXTENSION_DATA_DIR / ext_id).resolve()
        raw_files = step.get("files", [])
        if isinstance(raw_files, str):
            raw_files = [raw_files]
        if not isinstance(raw_files, list) or len(raw_files) > 128:
            raise ValueError("archive.create files must be an array of at most 128 paths.")
        candidates = []
        for item in raw_files:
            relative = runtime._render(item, context).strip().replace("\\", "/")
            source = runtime._extension_data_path(ext_id, relative)
            if source.is_file():
                candidates.append(source)
            elif source.is_dir():
                candidates.extend(path for path in source.rglob("*") if path.is_file())
        unique = []
        total = 0
        seen = set()
        for source in candidates:
            source = source.resolve()
            if source == destination.resolve() or source in seen:
                continue
            if source != root and root not in source.parents:
                raise PermissionError("Archive source escaped the extension data folder.")
            size = int(source.stat().st_size)
            total += size
            if total > 32 * 1024 * 1024 or len(unique) >= 256:
                raise ValueError("archive.create is limited to 256 files and 32 MiB of input data.")
            seen.add(source)
            unique.append(source)
        with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for source in unique:
                archive.write(source, source.relative_to(root).as_posix())
        _power_save(runtime, context, step, "archive", destination.relative_to(root).as_posix())
    elif op == "archive.list":
        target = runtime._extension_data_path(ext_id, runtime._render(step.get("path", ""), context))
        if not target.is_file() or not zipfile.is_zipfile(target):
            raise ValueError("archive.list needs a ZIP file in the extension data folder.")
        rows = []
        with zipfile.ZipFile(target, "r") as archive:
            for info in archive.infolist()[:512]:
                rows.append({"name": info.filename, "size": int(info.file_size), "compressed_size": int(info.compress_size), "directory": info.is_dir()})
        _power_save(runtime, context, step, "entries", rows)
    elif op == "archive.extract":
        target = runtime._extension_data_path(ext_id, runtime._render(step.get("path", ""), context))
        if not target.is_file() or not zipfile.is_zipfile(target):
            raise ValueError("archive.extract needs a ZIP file in the extension data folder.")
        dest_name = runtime._render(step.get("destination", "extracted"), context).strip() or "extracted"
        destination = runtime._extension_data_path(ext_id, dest_name, create_parent=True)
        destination.mkdir(parents=True, exist_ok=True)
        destination = destination.resolve()
        count = 0
        total = 0
        with zipfile.ZipFile(target, "r") as archive:
            infos = archive.infolist()
            if len(infos) > 256:
                raise ValueError("archive.extract is limited to 256 entries.")
            for info in infos:
                name = str(info.filename or "").replace("\\", "/")
                parts = [part for part in name.split("/") if part not in {"", "."}]
                if not parts or any(part == ".." for part in parts) or name.startswith("/"):
                    raise PermissionError("Archive contains an unsafe path.")
                mode = (int(info.external_attr) >> 16) & 0xFFFF
                if stat.S_ISLNK(mode):
                    raise PermissionError("Archive symbolic links are not allowed.")
                total += int(info.file_size)
                if total > 32 * 1024 * 1024:
                    raise ValueError("archive.extract is limited to 32 MiB of uncompressed data.")
                output = (destination / Path(*parts)).resolve()
                if output != destination and destination not in output.parents:
                    raise PermissionError("Archive path escaped the extraction folder.")
                if info.is_dir():
                    output.mkdir(parents=True, exist_ok=True)
                    continue
                output.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(info, "r") as source, output.open("wb") as dest:
                    shutil.copyfileobj(source, dest, length=1024 * 1024)
                count += 1
        _power_save(runtime, context, step, "extracted", {"files": count, "bytes": total, "destination": dest_name})
    elif op in {"database.execute", "database.query", "database.scalar"}:
        query = op != "database.execute"
        sql = _database_sql(runtime, step, context, query=query)
        params = _database_params(runtime, step, context)
        database = _database_path(runtime, ext_id)
        with sqlite3.connect(str(database), timeout=3.0) as connection:
            connection.row_factory = sqlite3.Row
            connection.execute("PRAGMA trusted_schema=OFF")
            cursor = connection.execute(sql, params)
            if op == "database.execute":
                connection.commit()
                payload = {"changes": max(0, int(cursor.rowcount)), "last_row_id": int(cursor.lastrowid or 0)}
                _power_save(runtime, context, step, "database", payload)
            elif op == "database.query":
                columns = [str(item[0]) for item in (cursor.description or [])]
                rows = []
                for row in cursor.fetchmany(501):
                    if len(rows) >= 500:
                        break
                    rows.append({columns[index]: _database_json_value(row[index]) for index in range(len(columns))})
                name = _power_save(runtime, context, step, "rows", rows)
                context[f"var.{name}.count"] = str(len(rows))
            else:
                row = cursor.fetchone()
                value = "" if row is None or len(row) == 0 else _database_json_value(row[0])
                _power_save(runtime, context, step, "value", value)
    elif op == "ui.screen.list":
        rows = []
        for screen in QApplication.screens():
            geometry = screen.geometry(); available = screen.availableGeometry()
            rows.append({"name": screen.name(), "x": geometry.x(), "y": geometry.y(), "width": geometry.width(), "height": geometry.height(), "available_x": available.x(), "available_y": available.y(), "available_width": available.width(), "available_height": available.height(), "device_pixel_ratio": screen.devicePixelRatio()})
        _power_save(runtime, context, step, "screens", rows)
    elif op == "ui.window.list":
        rows = []
        for window in QApplication.topLevelWidgets():
            if not isinstance(window, QWidget):
                continue
            geometry = window.geometry()
            rows.append({"title": str(window.windowTitle() or ""), "object_name": str(window.objectName() or ""), "class": window.metaObject().className() if window.metaObject() else window.__class__.__name__, "x": geometry.x(), "y": geometry.y(), "width": geometry.width(), "height": geometry.height(), "visible": window.isVisible(), "active": window.isActiveWindow(), "minimized": window.isMinimized(), "maximized": window.isMaximized(), "fullscreen": window.isFullScreen()})
            if len(rows) >= 128:
                break
        _power_save(runtime, context, step, "windows", rows)
    elif op == "ui.view.close":
        view_id = runtime._render(step.get("id", "runtime"), context).strip()[:64] or "runtime"
        panel = runtime._panels.pop((ext_id, "view:" + view_id), None)
        if panel is not None:
            panel.close(); panel.deleteLater()
    elif op == "ui.view.update":
        view_id = runtime._render(step.get("id", "runtime"), context).strip()[:64] or "runtime"
        control_id = runtime._render(step.get("control", ""), context).strip()
        prop = runtime._render(step.get("property", "text"), context).strip()
        value = runtime._render(step.get("value", ""), context)
        panel = runtime._panels.get((ext_id, "view:" + view_id))
        if panel is None:
            raise ValueError("The requested runtime view is not open.")
        panel.set_control_property(control_id, prop, value)
    elif op == "ui.widget.children":
        widget = runtime._find_widget(runtime._render(step.get("target", ""), context))
        if widget is None:
            raise ValueError("ui.widget.children could not find the target widget.")
        rows = []
        for child in widget.findChildren(QWidget):
            text = str(child.text())[:200] if hasattr(child, "text") else ""
            rows.append({"object_name": str(child.objectName() or ""), "class": child.metaObject().className() if child.metaObject() else child.__class__.__name__, "text": text, "visible": child.isVisible(), "enabled": child.isEnabled()})
            if len(rows) >= 500:
                break
        _power_save(runtime, context, step, "children", rows)
    elif op == "ui.widget.snapshot":
        widget = runtime._find_widget(runtime._render(step.get("target", ""), context))
        if widget is None:
            raise ValueError("ui.widget.snapshot could not find the target widget.")
        geometry = widget.geometry()
        payload = {"object_name": str(widget.objectName() or ""), "class": widget.metaObject().className() if widget.metaObject() else widget.__class__.__name__, "x": geometry.x(), "y": geometry.y(), "width": geometry.width(), "height": geometry.height(), "visible": widget.isVisible(), "enabled": widget.isEnabled(), "tooltip": str(widget.toolTip() or ""), "text": str(widget.text())[:8192] if hasattr(widget, "text") else ""}
        if hasattr(widget, "isChecked"):
            payload["checked"] = bool(widget.isChecked())
        if hasattr(widget, "currentText"):
            payload["current_text"] = str(widget.currentText())
        if hasattr(widget, "value"):
            try: payload["value"] = widget.value()
            except Exception: pass
        _power_save(runtime, context, step, "widget", payload)
    elif op == "json.keys":
        value = _power_json_source(runtime, step, context, default="{}")
        keys = list(value.keys()) if isinstance(value, dict) else list(range(len(value))) if isinstance(value, list) else []
        _power_save(runtime, context, step, "keys", keys)
    elif op == "json.length":
        value = _power_json_source(runtime, step, context, default="null")
        length = len(value) if isinstance(value, (dict, list, str)) else 0
        _power_save(runtime, context, step, "length", length)
    elif op == "json.merge":
        base_value = _power_json_source(runtime, step, context, key="base", default="{}")
        patch_value = _power_json_source(runtime, step, context, key="patch", default="{}")
        if isinstance(base_value, dict) and isinstance(patch_value, dict):
            result = dict(base_value); result.update(patch_value)
        elif isinstance(base_value, list) and isinstance(patch_value, list):
            result = base_value + patch_value
        else:
            raise ValueError("json.merge requires two objects or two arrays.")
        _power_save(runtime, context, step, "json", result)
    elif op.startswith("list."):
        value = _power_json_source(runtime, step, context, default="[]")
        if not isinstance(value, list):
            raise ValueError(f"{op} requires a JSON array source.")
        if len(value) > 5000:
            raise ValueError("List operations are limited to 5000 items.")
        if op == "list.length":
            result = len(value)
        elif op == "list.get":
            try: index = int(float(runtime._render(step.get("index", "0"), context)))
            except Exception: raise ValueError("list.get index must be numeric.")
            result = value[index] if -len(value) <= index < len(value) else step.get("default", "")
        elif op == "list.join":
            separator = runtime._render(step.get("separator", "\n"), context)
            result = separator.join(str(item) for item in value)
        elif op == "list.sort":
            reverse = runtime._as_bool(runtime._render(step.get("reverse", "false"), context))
            numeric = runtime._as_bool(runtime._render(step.get("numeric", "false"), context))
            result = sorted(value, key=(lambda item: float(item)) if numeric else (lambda item: str(item).casefold()), reverse=reverse)
        elif op == "list.unique":
            seen = set(); result = []
            for item in value:
                key = json.dumps(item, sort_keys=True, ensure_ascii=False) if isinstance(item, (dict, list)) else repr(item)
                if key not in seen:
                    seen.add(key); result.append(item)
        else:
            try:
                start = int(float(runtime._render(step.get("start", "0"), context)))
                end_raw = runtime._render(step.get("end", str(len(value))), context)
                end = int(float(end_raw))
            except Exception:
                raise ValueError("list.slice start/end must be numeric.")
            result = value[start:end]
        _power_save(runtime, context, step, "list", result)
    elif op == "crypto.hash":
        algorithm = runtime._render(step.get("algorithm", "sha256"), context).strip().casefold()
        if algorithm not in {"sha256", "sha512", "blake2b"}:
            raise ValueError("crypto.hash algorithm must be sha256, sha512 or blake2b.")
        value = runtime._render(step.get("value", step.get("text", "")), context).encode("utf-8")
        _power_save(runtime, context, step, "hash", hashlib.new(algorithm, value).hexdigest())
    elif op == "random.secure":
        try: length = max(1, min(4096, int(float(runtime._render(step.get("bytes", "32"), context)))))
        except Exception: raise ValueError("random.secure bytes must be numeric.")
        encoding = runtime._render(step.get("encoding", "hex"), context).strip().casefold()
        raw = secrets.token_bytes(length)
        value = base64.b64encode(raw).decode("ascii") if encoding == "base64" else raw.hex()
        if encoding not in {"hex", "base64"}:
            raise ValueError("random.secure encoding must be hex or base64.")
        _power_save(runtime, context, step, "random", value)
    elif op == "date.add":
        source = runtime._render(step.get("value", ""), context).strip()
        if source:
            try: moment = datetime.fromisoformat(source.replace("Z", "+00:00"))
            except Exception as exc: raise ValueError("date.add value must be an ISO-8601 date/time.") from exc
        else:
            moment = datetime.now().astimezone()
        def amount(name):
            try: return float(runtime._render(step.get(name, "0"), context) or 0)
            except Exception: raise ValueError(f"date.add {name} must be numeric.")
        delta = timedelta(days=max(-36500, min(36500, amount("days"))), hours=max(-100000, min(100000, amount("hours"))), minutes=max(-1000000, min(1000000, amount("minutes"))), seconds=max(-10000000, min(10000000, amount("seconds"))))
        result = (moment + delta).isoformat(timespec="seconds")
        _power_save(runtime, context, step, "date", result)
    elif op == "flow.try":
        body = step.get("steps", [])
        catch = step.get("catch", [])
        final = step.get("finally", [])
        if not isinstance(body, list) or not isinstance(catch, list) or not isinstance(final, list) or any(len(part) > 64 for part in (body, catch, final)):
            raise ValueError("flow.try sections must be arrays of at most 64 steps.")
        try:
            runtime.run(package, {"inputs": [], "steps": body}, _context=context)
            context["var.error"] = ""
        except Exception as exc:
            context["var.error"] = runtime._bounded(str(exc), "Error text")
            if catch:
                runtime.run(package, {"inputs": [], "steps": catch}, _context=context)
        finally:
            if final:
                runtime.run(package, {"inputs": [], "steps": final}, _context=context)
    elif op == "flow.switch":
        value = runtime._render(step.get("value", ""), context)
        cases = step.get("cases", [])
        if not isinstance(cases, list) or len(cases) > 64:
            raise ValueError("flow.switch cases must be an array of at most 64 entries.")
        selected = None
        for case in cases:
            if isinstance(case, dict) and runtime._render(case.get("value", ""), context) == value:
                selected = case.get("steps", [])
                break
        if selected is None:
            selected = step.get("default", [])
        if not isinstance(selected, list) or len(selected) > 64:
            raise ValueError("flow.switch selected steps must be an array of at most 64 steps.")
        if selected:
            runtime.run(package, {"inputs": [], "steps": selected}, _context=context)
    else:
        raise ValueError(f"Unsupported API 5 extension operation: {op}")


def _install_power_api(host_globals):
    global _POWER_API_INSTALLED
    if not isinstance(host_globals, dict):
        return
    runtime_class = host_globals.get("LelExtensionRuntime")
    permissions = host_globals.get("EXTENSION_STEP_PERMISSIONS")
    permission_names = host_globals.get("EXTENSION_PERMISSION_NAMES")
    if runtime_class is None or not isinstance(permissions, dict) or permission_names is None:
        return
    try:
        host_globals["EXTENSION_API_VERSION"] = max(POWER_API_VERSION, int(host_globals.get("EXTENSION_API_VERSION", 1) or 1))
    except Exception:
        host_globals["EXTENSION_API_VERSION"] = POWER_API_VERSION
    host_globals["EXTENSION_PERMISSION_NAMES"] = frozenset(set(permission_names) | {"database"})
    permissions.update(_POWER_OPERATIONS)
    if getattr(runtime_class, "_lelsploit_api5_installed", False):
        _POWER_API_INSTALLED = True
        return
    original_run = runtime_class.run

    def run_api5(runtime, package, action, seed_context=None, _context=None):
        manifest = package["manifest"]
        ext_id = manifest["id"]
        state = load_extension_state()
        if ext_id in set(state.get("disabled", [])):
            raise PermissionError("This extension is disabled.")
        if _context is None:
            context = runtime._snapshot_context(manifest)
            context["extension.id"] = ext_id
            context["extension.name"] = manifest["name"]
            context["extension.api"] = str(host_globals.get("EXTENSION_API_VERSION", POWER_API_VERSION))
            if isinstance(seed_context, dict):
                for key, value in seed_context.items():
                    context[str(key)] = runtime._bounded(value, "Seed context")
        else:
            context = _context
        for spec in action.get("inputs", []):
            text, ok = QInputDialog.getText(runtime.owner, spec.get("title", manifest["name"]), spec.get("prompt", spec["id"]), text=spec.get("default", ""))
            if not ok:
                return False
            context[f"input.{spec['id']}"] = runtime._bounded(text, "Input")
        for step in action.get("steps", []):
            if not isinstance(step, dict):
                raise ValueError("Extension action contains an invalid step.")
            if not runtime._condition_passes(step, context):
                continue
            op = str(step.get("op", "")).strip()
            runtime._require_permission(manifest, op)
            if op in _POWER_OPERATIONS:
                _run_power_step(runtime, package, manifest, step, context)
            else:
                original_run(runtime, package, {"inputs": [], "steps": [step]}, _context=context)
        return True

    runtime_class._lelsploit_api4_run = original_run
    runtime_class.run = run_api5
    runtime_class._lelsploit_api5_installed = True
    _POWER_API_INSTALLED = True


def _schedule_documentation_patch():
    host = _HOST_GLOBALS
    if not isinstance(host, dict):
        return
    def worker():
        for _ in range(100):
            if "EXTENSIONS_DOCUMENTATION_HTML" in host:
                host["EXTENSIONS_DOCUMENTATION_HTML"] = EXTENSION_API5_DOCUMENTATION_HTML
                return
            time.sleep(0.02)
    threading.Thread(target=worker, daemon=True).start()


__all__ = [
    "configure_host",
    "ExtensionsWindow",
    "ExtensionMarketplacePane",
    "MarketplaceAccountDialog",
    "marketplace_request",
    "MARKETPLACE_DEFAULT_API",
]
