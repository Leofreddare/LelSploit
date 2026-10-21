"""Local helpers for inspecting downloaded source and active Player sessions."""
from __future__ import annotations
import codecs
import ctypes
import gzip
import io
import re
import sys
import threading
import time
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from email.message import Message


class _DownloadLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'meta' and attrs.get('http-equiv', '').lower() == 'refresh':
            match = re.search(r'(?i)url\s*=\s*[\"\']?([^\"\']+)', attrs.get('content', ''))
            if match:
                self.links.append(match.group(1).strip())
        if tag == 'a' and 'download' in attrs and attrs.get('href'):
            self.links.append(attrs['href'])


def download_source(url, cancelled, limit, *, opener=None, max_hops=4):
    """Read text attachments regardless of URL suffix; never run their contents."""
    opener = opener or urllib.request.urlopen
    visited = set()
    for _ in range(max_hops + 1):
        if cancelled.is_set():
            return None
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme.lower() not in ('http', 'https') or not parsed.netloc:
            raise ValueError('Enter an HTTP or HTTPS source URL.')
        if url in visited:
            raise ValueError('The download link redirects in a loop.')
        visited.add(url)
        request = urllib.request.Request(url, headers={'Accept': 'text/plain,application/octet-stream,*/*;q=0.8', 'Accept-Encoding': 'gzip', 'User-Agent': 'LelSploit/1.0'})
        with opener(request, timeout=15) as response:
            headers = response.headers
            final_url = response.geturl()
            chunks = []
            size = 0
            while not cancelled.is_set():
                chunk = response.read(min(65536, limit + 1 - size))
                if not chunk:
                    break
                chunks.append(chunk)
                size += len(chunk)
                if size > limit:
                    raise ValueError('The downloaded source exceeds the display size limit.')
            if cancelled.is_set():
                return None
            raw = b''.join(chunks)
        if headers.get('Content-Encoding', '').lower() == 'gzip':
            with gzip.GzipFile(fileobj=io.BytesIO(raw)) as compressed:
                raw = compressed.read(limit + 1)
            if len(raw) > limit:
                raise ValueError('The decompressed source exceeds the display size limit.')
        if not raw:
            raise ValueError('The server returned an empty body. Use a direct source/download link.')
        content_type = headers.get('Content-Type', '')
        if raw.startswith((b'PK\x03\x04', b'MZ', b'\x7fELF')):
            raise ValueError('This download is a binary file or archive, not Lua/Luau source.')
        metadata = Message()
        metadata['content-type'] = content_type
        charset = metadata.get_content_charset()
        if raw.startswith((codecs.BOM_UTF16_LE, codecs.BOM_UTF16_BE)):
            charset = 'utf-16'
        elif raw.startswith(codecs.BOM_UTF8):
            charset = 'utf-8-sig'
        try:
            text = raw.decode(charset or 'utf-8')
        except (UnicodeDecodeError, LookupError) as exc:
            raise ValueError('The download could not be decoded as source text.') from exc
        if '\x00' in text:
            raise ValueError('The download contains binary data rather than source text.')
        if 'text/html' in content_type.lower() or re.match(r'\s*(?:<!doctype html|<html)', text, re.I):
            page = _DownloadLinks()
            page.feed(text)
            links = list(dict.fromkeys(urllib.parse.urljoin(final_url, link) for link in page.links))
            if len(links) != 1:
                raise ValueError('This URL returned a web page. Use its direct download link.')
            url = links[0]
            continue
        return text.encode('utf-8')
    raise ValueError('Too many download-page redirects.')


_process_cache = (0.0, None)
_process_lock = threading.Lock()


def newest_player_started_at():
    """Find Player creation times through local Windows APIs, cached briefly."""
    global _process_cache
    if sys.platform != 'win32':
        return None
    with _process_lock:
        now = time.monotonic()
        if now - _process_cache[0] < 0.75:
            return _process_cache[1]
        from ctypes import wintypes
        class Entry(ctypes.Structure):
            _fields_ = [('dwSize', wintypes.DWORD), ('cntUsage', wintypes.DWORD), ('th32ProcessID', wintypes.DWORD), ('th32DefaultHeapID', ctypes.c_size_t), ('th32ModuleID', wintypes.DWORD), ('cntThreads', wintypes.DWORD), ('th32ParentProcessID', wintypes.DWORD), ('pcPriClassBase', wintypes.LONG), ('dwFlags', wintypes.DWORD), ('szExeFile', wintypes.WCHAR * 260)]
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        kernel.CreateToolhelp32Snapshot.argtypes = [wintypes.DWORD, wintypes.DWORD]
        kernel.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
        kernel.Process32FirstW.argtypes = kernel.Process32NextW.argtypes = [wintypes.HANDLE, ctypes.POINTER(Entry)]
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        snapshot = kernel.CreateToolhelp32Snapshot(2, 0)
        starts = []
        if snapshot and snapshot != ctypes.c_void_p(-1).value:
            try:
                entry = Entry()
                entry.dwSize = ctypes.sizeof(entry)
                found = kernel.Process32FirstW(snapshot, ctypes.byref(entry))
                while found:
                    if entry.szExeFile.lower() in ('robloxplayerbeta.exe', 'windows10universal.exe', 'roblox.exe'):
                        handle = kernel.OpenProcess(0x1000, False, entry.th32ProcessID)
                        if handle:
                            try:
                                values = [wintypes.FILETIME() for _ in range(4)]
                                if kernel.GetProcessTimes(handle, *(ctypes.byref(v) for v in values)):
                                    created = (values[0].dwHighDateTime << 32) | values[0].dwLowDateTime
                                    starts.append(created / 10_000_000 - 11644473600)
                            finally:
                                kernel.CloseHandle(handle)
                    found = kernel.Process32NextW(snapshot, ctypes.byref(entry))
            finally:
                kernel.CloseHandle(snapshot)
        _process_cache = (now, max(starts) if starts else None)
        return _process_cache[1]
