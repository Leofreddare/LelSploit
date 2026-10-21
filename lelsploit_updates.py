"""Stable GitHub releases, Windows install detection, and update downloads."""
from __future__ import annotations

import ctypes
import hashlib
import json
import os
import re
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

RELEASES_URL = 'https://github.com/Leofreddare/LelSploit/releases'
RELEASES_API = 'https://api.github.com/repos/Leofreddare/LelSploit/releases'
MAX_DOWNLOAD_BYTES = 2 * 1024 * 1024 * 1024


class DownloadCancelled(Exception):
    pass


def stable_version(tag):
    """Only plain vMAJOR.MINOR.PATCH releases qualify; reject beta suffixes."""
    match = re.fullmatch(r'v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', str(tag))
    return tuple(map(int, match.groups())) if match else None


def newest_release(releases, current_version):
    current = stable_version('v' + str(current_version).removeprefix('v'))
    if current is None:
        raise ValueError('The current app version must be MAJOR.MINOR.PATCH.')
    candidates = []
    for release in releases:
        if not isinstance(release, dict) or release.get('draft') or release.get('prerelease'):
            continue
        version = stable_version(release.get('tag_name', ''))
        if version and version > current:
            candidates.append((version, release))
    return max(candidates, key=lambda item: item[0])[1] if candidates else None


def fetch_release(current_version, opener=None):
    opener = opener or urllib.request.urlopen
    releases = []
    # Follow pagination so a beta-heavy first page does not hide a stable release.
    for page in range(1, 101):
        request = urllib.request.Request(
            f'{RELEASES_API}?per_page=100&page={page}',
            headers={'Accept':'application/vnd.github+json', 'User-Agent':f'LelSploit/{current_version}'},
        )
        try:
            with opener(request, timeout=20) as response:
                data = response.read(8 * 1024 * 1024 + 1)
                if len(data) > 8 * 1024 * 1024:
                    raise ValueError('The update response was too large.')
                batch = json.loads(data.decode('utf-8'))
        except urllib.error.HTTPError as exc:
            if exc.code in (403, 429):
                raise RuntimeError('GitHub is limiting update checks. Please try again later.') from exc
            if exc.code == 404:
                raise RuntimeError('The LelSploit releases page is not available. Please try again later.') from exc
            raise
        if not isinstance(batch, list):
            raise ValueError('GitHub returned an invalid releases response.')
        releases.extend(batch)
        if len(batch) < 100:
            return newest_release(releases, current_version)
    raise RuntimeError('There are too many release pages to check. Please try again later.')


def start_menu_programs(environ=None):
    env = os.environ if environ is None else environ
    folders = []
    # Use the shell folder IDs too, so redirected/custom Start Menus are covered.
    if os.name == 'nt' and environ is None:
        for csidl in (0x0002, 0x0017):  # CSIDL_PROGRAMS, CSIDL_COMMON_PROGRAMS
            buffer = ctypes.create_unicode_buffer(32768)
            if ctypes.windll.shell32.SHGetFolderPathW(None, csidl, None, 0, buffer) == 0:
                folders.append(Path(buffer.value))
    for key in ('APPDATA', 'ProgramData', 'PROGRAMDATA', 'ALLUSERSPROFILE'):
        if env.get(key):
            folders.append(Path(env[key]) / 'Microsoft' / 'Windows' / 'Start Menu' / 'Programs')
    return list(dict.fromkeys(folders))


def has_start_menu_install(program_folders=None):
    for folder in start_menu_programs() if program_folders is None else program_folders:
        try:
            for entry in Path(folder).iterdir():
                if entry.is_dir() and entry.name.casefold() == 'lelsploit':
                    return True
                if entry.is_file() and entry.suffix.casefold() == '.lnk' and entry.stem.casefold() == 'lelsploit':
                    return True
        except OSError:
            continue
    return False


def select_asset(release, installed):
    extension = '.msi' if installed else '.exe'
    for asset in release.get('assets', []):
        if not isinstance(asset, dict):
            continue
        name = str(asset.get('name') or '')
        if name.casefold().endswith(extension) and '/' not in name and '\\' not in name and asset.get('state', 'uploaded') == 'uploaded':
            url = urllib.parse.urlparse(str(asset.get('browser_download_url') or ''))
            if url.scheme == 'https' and url.hostname == 'github.com' and url.path.casefold().startswith('/leofreddare/lelsploit/releases/download/'):
                return asset
    raise ValueError(f'This release has no {extension} download. Please try again later.')


def download_asset(asset, destination, progress=None, cancel=None, opener=None):
    opener = opener or urllib.request.urlopen
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    name = str(asset['name'])
    if '/' in name or '\\' in name or Path(name).suffix.casefold() not in ('.exe', '.msi'):
        raise ValueError('Invalid update filename.')
    final = destination / name
    fd, temporary = tempfile.mkstemp(prefix='.download-', suffix='.part', dir=destination)
    temporary = Path(temporary)
    received = 0
    expected = int(asset.get('size') or 0)
    digest = hashlib.sha256()
    try:
        request = urllib.request.Request(str(asset['browser_download_url']), headers={'User-Agent':'LelSploit updater', 'Accept':'application/octet-stream'})
        with os.fdopen(fd, 'wb') as handle, opener(request, timeout=30) as response:
            if urllib.parse.urlparse(response.geturl()).scheme != 'https':
                raise ValueError('The update download must use HTTPS.')
            total = expected or int(response.headers.get('Content-Length') or 0)
            if total > MAX_DOWNLOAD_BYTES:
                raise ValueError('The update download is too large.')
            while True:
                if cancel is not None and cancel.is_set():
                    raise DownloadCancelled('Download cancelled.')
                chunk = response.read(256 * 1024)
                if not chunk:
                    break
                received += len(chunk)
                if received > MAX_DOWNLOAD_BYTES:
                    raise ValueError('The update download is too large.')
                handle.write(chunk)
                digest.update(chunk)
                if progress:
                    progress(received, total)
            handle.flush()
            os.fsync(handle.fileno())
        if cancel is not None and cancel.is_set():
            raise DownloadCancelled('Download cancelled.')
        if not received or (total and total != received):
            raise ValueError('The update download was incomplete. Please retry.')
        declared = str(asset.get('digest') or '')
        if declared.startswith('sha256:') and digest.hexdigest().casefold() != declared[7:].casefold():
            raise ValueError('The update checksum did not match. Please retry.')
        os.replace(temporary, final)
        return final
    finally:
        temporary.unlink(missing_ok=True)


def launch_installer(path):
    path = Path(path).resolve()
    if os.name != 'nt':
        raise OSError('Installing updates is available on Windows only.')
    if not path.is_file() or path.suffix.casefold() not in ('.msi', '.exe'):
        raise ValueError('The downloaded installer is missing or has an unsupported type.')
    # Windows opens MSI through Windows Installer and EXE through the normal
    # application launcher, including any elevation prompt requested by it.
    os.startfile(str(path), 'open')
