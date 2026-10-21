"""Non-blocking update checks and a compact update card for the desktop UI."""
from __future__ import annotations

import threading
import time
from pathlib import Path

from PyQt6.QtCore import QObject, Qt, QTimer, pyqtSignal, QSize
from PyQt6.QtGui import QIcon
from PyQt6.QtWidgets import QDialog, QFrame, QHBoxLayout, QLabel, QTextBrowser, QProgressBar, QPushButton, QStyle

from lelsploit_updates import (DownloadCancelled, fetch_release,
                              has_start_menu_install, select_asset, download_asset, launch_installer)


class LocalNotesBrowser(QTextBrowser):
    """Render release notes without fetching embedded images or other resources."""
    def loadResource(self, resource_type, name):
        return None


class UpdateDialog(QDialog):
    def __init__(self, manager):
        super().__init__(manager.owner)
        self.manager = manager
        self.setWindowTitle('LelSploit updates')
        self.setModal(True)
        self.resize(540, 460)
        self.setMinimumWidth(430)
        manager.apply_icon(self)
        layout = manager.blur_layout(self, self, 'LelSploit updates', (22, 18, 22, 20), 12)
        heading = QHBoxLayout()
        mark = QLabel()
        self.mark = mark
        mark.setObjectName('updateMark')
        mark.setAlignment(Qt.AlignmentFlag.AlignCenter)
        mark.setFixedSize(44, 44)
        heading.addWidget(mark)
        self.heading = QLabel('Checking for updates')
        self.heading.setObjectName('updateHeading')
        self.heading.setWordWrap(True)
        heading.addWidget(self.heading, 1)
        layout.addLayout(heading)
        self.versions = QLabel()
        self.versions.setObjectName('updateVersions')
        self.versions.setTextFormat(Qt.TextFormat.PlainText)
        layout.addWidget(self.versions)
        self.description = QLabel()
        self.description.setWordWrap(True)
        self.description.setTextFormat(Qt.TextFormat.PlainText)
        layout.addWidget(self.description)
        self.notes = LocalNotesBrowser()
        self.notes.setOpenLinks(False)
        self.notes.setOpenExternalLinks(False)
        self.notes.document().setDefaultStyleSheet("h1,h2,h3 { color:#eff5f1; margin-top:14px; } p,li { line-height:145%; } code { color:#b7d6c1; } a { color:#a8cbb4; }")
        self.notes.setReadOnly(True)
        self.notes.setAccessibleName('What changed in this update')
        self.notes.setMinimumHeight(115)
        self.notes.setMaximumHeight(190)
        layout.addWidget(self.notes, 1)
        self.progress = QProgressBar()
        self.progress.setTextVisible(False)
        self.progress.setFixedHeight(5)
        layout.addWidget(self.progress)
        self.detail = QLabel()
        self.detail.setObjectName('updateDetail')
        self.detail.setWordWrap(True)
        self.detail.setTextFormat(Qt.TextFormat.PlainText)
        layout.addWidget(self.detail)
        actions = QHBoxLayout()
        actions.addStretch(1)
        self.later = QPushButton('Later')
        self.later.clicked.connect(self.reject)
        actions.addWidget(self.later)
        self.update = QPushButton('Update now')
        self.update.setObjectName('updatePrimary')
        self.update.setDefault(True)
        self.update.clicked.connect(self._primary)
        actions.addWidget(self.update)
        layout.addLayout(actions)
        self.setStyleSheet('''
            QDialog { background:#0c0e10; color:#e9edef; }
            QLabel { color:#bac2c8; background:transparent; font-size:12px; }
            QLabel#updateHeading { color:#f6f7f8; font-size:20px; font-weight:600; }
            QLabel#updateMark { color:#c4dfca; background:#1d2b23; border:1px solid #3b5543; border-radius:12px; font-size:28px; }
            QLabel#updateVersions { color:#d3e3d7; background:#171d19; border:1px solid #303d33; padding:9px; border-radius:6px; }
            QLabel#updateDetail { color:#929da5; font-size:11px; }
            QTextBrowser { color:#c7cfd5; background:#111518; border:1px solid #2c343a; border-radius:7px; padding:8px; font-size:12px; }
            QProgressBar { border:none; background:#232b2e; border-radius:2px; }
            QProgressBar::chunk { background:#9ebca5; border-radius:2px; }
            QPushButton { color:#d5dce0; background:#171d21; border:1px solid #303a40; border-radius:6px; padding:8px 12px; }
            QPushButton:hover { background:#252e33; border-color:#536168; }
            QPushButton:disabled { color:#657078; background:#14191c; }
            QPushButton#updatePrimary { color:#eff8f1; background:#344d3b; border-color:#698b72; font-weight:600; }
            QPushButton#updatePrimary:hover { background:#45654e; }
            QPushButton#updateLink { color:#9db2a5; background:transparent; border:none; padding-left:0; }
        ''')
        manager.apply_blur(self)
        manager.status_changed.connect(self.refresh)
        manager.progress_changed.connect(self.show_progress)
        self.refresh()

    def refresh(self):
        manager = self.manager
        state = manager.state
        release = manager.release
        tag = str(release.get('tag_name', '')) if release else ''
        self.versions.setText(f'v{manager.version}  →  {tag}' if release else f'Current version  v{manager.version}')
        self.notes.setMarkdown(str(release.get('body') or 'No release notes were provided.')[:30000] if release else '')
        self.notes.setVisible(bool(release))
        self.detail.setText(manager.status)
        self.progress.setVisible(state in ('checking', 'downloading', 'launching'))
        if state == 'checking':
            self.heading.setText('Checking for updates')
            self.description.clear()
            self.progress.setRange(0, 0)
        elif state == 'downloading':
            self.heading.setText('Downloading update')
            self.description.setText('LelSploit will close after the downloaded update opens.')
        elif state == 'launching':
            self.heading.setText('Opening update')
            self.description.setText('Starting the downloaded update and closing LelSploit.')
        elif release:
            self.heading.setText('An update is available')
            self.description.clear()
        elif state == 'error':
            self.heading.setText('Could not check for updates')
            self.description.setText('Check your connection and try again.')
        else:
            self.heading.setText("You're up to date")
            self.description.clear()
        self.description.setVisible(bool(self.description.text()))
        self.detail.setVisible(state in ('error', 'downloading', 'launching') or manager.status.startswith(('Could not', 'Update download', 'Download cancelled')))
        icon_name, fallback = ('download', QStyle.StandardPixmap.SP_ArrowDown) if release else ('refresh', QStyle.StandardPixmap.SP_BrowserReload)
        self.update.setIcon(self._icon(icon_name, fallback))
        self.update.setIconSize(QSize(17, 17))
        self.later.setIcon(self._icon('close', QStyle.StandardPixmap.SP_DialogCloseButton))
        self.mark.setPixmap(self._icon('update', QStyle.StandardPixmap.SP_ArrowUp).pixmap(26, 26))
        busy = state in ('checking', 'downloading', 'launching')
        self.update.setText('Downloading…' if state == 'downloading' else 'Opening…' if state == 'launching' else 'Update now' if release else 'Check again')
        self.update.setEnabled(not busy)
        self.later.setEnabled(state != 'launching')
        self.later.setText('Cancel' if state == 'downloading' else 'Later' if release else 'Close')

    def _icon(self, name, fallback):
        path = Path(__file__).resolve().parent / 'icons' / (name + '.png')
        icon = QIcon(str(path)) if path.is_file() else QIcon()
        return icon if not icon.isNull() else self.style().standardIcon(fallback)

    def show_progress(self, percent, detail):
        if self.manager.state != 'downloading':
            return
        self.progress.setRange(0, 100 if percent >= 0 else 0)
        if percent >= 0:
            self.progress.setValue(percent)
        self.detail.setText(detail)

    def _primary(self):
        if self.manager.release:
            self.manager.start_update()
        else:
            self.manager.check(manual=True)

    def reject(self):
        if self.manager.state == 'launching':
            return
        if self.manager.state == 'downloading':
            self.manager.cancel_download()
        super().reject()

    def closeEvent(self, event):
        if self.manager.state == 'launching':
            event.ignore()
            return
        if self.manager.state == 'downloading':
            self.manager.cancel_download()
        super().closeEvent(event)


class UpdateController(QObject):
    status_changed = pyqtSignal()
    progress_changed = pyqtSignal(int, str)
    _checked = pyqtSignal(object, str, bool)
    _downloaded = pyqtSignal(str, str)

    def __init__(self, owner, version, appdata, blur_layout, apply_blur, apply_icon):
        super().__init__(owner)
        self.owner = owner
        self.version = version
        self.appdata = Path(appdata)
        self.blur_layout = blur_layout
        self.apply_blur = apply_blur
        self.apply_icon = apply_icon
        self.release = None
        self.dialog = None
        self.state = 'idle'
        self.status = f'Current version: v{version}'
        self._notified_tag = None
        self._cancel = threading.Event()
        self._checked.connect(self._check_finished)
        self._downloaded.connect(self._download_finished)
        self.timer = QTimer(self)
        self.timer.setInterval(24 * 60 * 60 * 1000)
        self.timer.timeout.connect(self.check)
        if self.auto_enabled():
            self.timer.start()
            QTimer.singleShot(1600, self._startup_check)

    def auto_enabled(self):
        value = self.owner.settings.value('updates/automatic_checks', True)
        return value is True or str(value).strip().casefold() in ('true', '1', 'yes')

    def set_auto_enabled(self, enabled):
        self.owner.settings.setValue('updates/automatic_checks', bool(enabled))
        self.owner.settings.sync()
        if enabled:
            self.timer.start()
            self.check()
        else:
            self.timer.stop()
        self.status_changed.emit()

    def _startup_check(self):
        if self.auto_enabled():
            try:
                last = float(self.owner.settings.value('updates/last_check', 0) or 0)
            except (ValueError, TypeError):
                last = 0
            if not 0 <= time.time() - last < 86400:
                self.check()

    def show_dialog(self):
        if self.dialog is None:
            self.dialog = UpdateDialog(self)
        self.dialog.refresh()
        self.dialog.show()
        self.dialog.raise_()
        self.dialog.activateWindow()

    def settings_action(self):
        if self.release:
            self.show_dialog()
        else:
            self.check(manual=True)

    def check(self, manual=False):
        if not manual and not self.auto_enabled():
            return
        if self.state in ('checking', 'downloading', 'launching'):
            if manual:
                self.show_dialog()
            return
        self.state = 'checking'
        self.status = 'Checking for stable releases…'
        self.status_changed.emit()
        if manual:
            self.show_dialog()
        def worker():
            try:
                release = fetch_release(self.version)
                self._checked.emit(release, '', manual)
            except Exception as exc:
                self._checked.emit(None, str(exc), manual)
        threading.Thread(target=worker, daemon=True, name='LelSploit-update-check').start()

    def _check_finished(self, release, error, manual):
        if error:
            self.state = 'error'
            self.status = f'Update check failed: {error}'
        else:
            self.owner.settings.setValue('updates/last_check', time.time())
            self.owner.settings.sync()
            self.release = release
            self.state = 'available' if release else 'current'
            self.status = f"Update available: {release['tag_name']}" if release else f'Up to date · v{self.version}'
        self.status_changed.emit()
        if release and not error and (manual or (self.auto_enabled() and self._notified_tag != release['tag_name'])):
            self._notified_tag = release['tag_name']
            self.show_dialog()

    def start_update(self):
        if not self.release or self.state in ('checking', 'downloading', 'launching'):
            return
        try:
            installed = has_start_menu_install()
            asset = select_asset(self.release, installed)
        except Exception as exc:
            self.state = 'available'
            self.status = str(exc)
            self.status_changed.emit()
            return
        self._cancel = threading.Event()
        cancel = self._cancel
        release = self.release
        self.state = 'downloading'
        self.status = f"Downloading {asset['name']}…"
        self.status_changed.emit()
        self.progress_changed.emit(0, self.status)
        def progress(received, total):
            percent = min(100, int(received*100/total)) if total else -1
            detail = f'{received / 1048576:.1f} MB' + (f' / {total / 1048576:.1f} MB · {percent}%' if total else '')
            self.progress_changed.emit(percent, detail)
        def worker():
            try:
                destination = self.appdata / 'updates' / str(release['tag_name'])
                path = download_asset(asset, destination, progress=progress, cancel=cancel)
                self._downloaded.emit(str(path), '')
            except DownloadCancelled:
                self._downloaded.emit('', 'Download cancelled.')
            except Exception as exc:
                self._downloaded.emit('', f'Update download failed: {exc}')
        threading.Thread(target=worker, daemon=True, name='LelSploit-update-download').start()

    def cancel_download(self):
        self._cancel.set()

    def _download_finished(self, path, error):
        if error or self._cancel.is_set():
            self.state = 'available'
            self.status = error or 'Download cancelled.'
            self.status_changed.emit()
            return
        self.state = 'launching'
        self.status = 'Opening the downloaded update…'
        self.status_changed.emit()
        try:
            launch_installer(path)
        except Exception as exc:
            self.state = 'available'
            self.status = f'Could not open the update: {exc}'
            self.status_changed.emit()
            return
        # Bypass close-to-tray behavior. The window's exit path stops its timers
        # and worker requests before quitting the application.
        self.owner.quit_application()
