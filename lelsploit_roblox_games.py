"""Public Roblox experience search, place-name resolution, and thumbnail cache."""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import copy
import json
import re
import threading
import time
import urllib.parse
import urllib.request
import uuid

SESSION_ID = str(uuid.uuid4())
_CACHE = {}
_CACHE_LOCK = threading.Lock()


def place_id(value):
    text = str(value or '').strip()
    return str(int(text)) if re.fullmatch(r'[0-9]{1,19}', text) and 0 < int(text) <= 9223372036854775807 else ''


def _bytes(url, limit=4 * 1024 * 1024, timeout=8):
    request = urllib.request.Request(url, headers={'User-Agent': 'LelSploit/1.0', 'Accept': '*/*'})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError('Roblox response exceeds the size limit.')
    return data


def _json(url):
    with _CACHE_LOCK:
        entry = _CACHE.get(url)
        if entry and entry[0] > time.monotonic():
            return copy.deepcopy(entry[1])
    data = json.loads(_bytes(url).decode('utf-8'))
    with _CACHE_LOCK:
        if len(_CACHE) >= 256:
            _CACHE.clear()
        _CACHE[url] = (time.monotonic() + 180, data)
    return data


def parse_search(payload, limit=6):
    games, seen = [], set()
    for group in payload.get('searchResults', []):
        if not isinstance(group, dict) or group.get('contentGroupType') != 'Game':
            continue
        for item in group.get('contents', []):
            if not isinstance(item, dict):
                continue
            universe = place_id(item.get('universeId'))
            root = place_id(item.get('rootPlaceId'))
            name = str(item.get('name') or '').strip()
            if universe and universe not in seen and name:
                seen.add(universe)
                games.append({'universe_id': universe, 'place_id': root, 'name': name[:200]})
                if len(games) >= limit:
                    return games
    return games


def _details(universe_ids):
    payload = _json('https://games.roblox.com/v1/games?' + urllib.parse.urlencode({'universeIds': ','.join(universe_ids)}))
    return {place_id(item.get('id')): item for item in payload.get('data', []) if isinstance(item, dict)}


def _icon_bytes(url):
    parsed = urllib.parse.urlsplit(url)
    host = (parsed.hostname or '').lower()
    if parsed.scheme != 'https' or not (host == 'rbxcdn.com' or host.endswith('.rbxcdn.com')):
        return b''
    with _CACHE_LOCK:
        entry = _CACHE.get(url)
        if entry and entry[0] > time.monotonic():
            return entry[1]
    try:
        data = _bytes(url, limit=2 * 1024 * 1024, timeout=8)
    except Exception:
        return b''
    with _CACHE_LOCK:
        if len(_CACHE) >= 256:
            _CACHE.clear()
        _CACHE[url] = (time.monotonic() + 600, data)
    return data


def game_icons(games):
    if not games:
        return {}
    try:
        payload = _json('https://thumbnails.roblox.com/v1/games/icons?' + urllib.parse.urlencode({
            'universeIds': ','.join(g['universe_id'] for g in games),
            'size': '150x150', 'format': 'Png', 'isCircular': 'false'}))
        urls = [(place_id(item.get('targetId')), str(item.get('imageUrl') or ''))
                for item in payload.get('data', []) if isinstance(item, dict) and item.get('state') == 'Completed']
        with ThreadPoolExecutor(max_workers=4) as pool:
            values = list(pool.map(_icon_bytes, [url for _, url in urls]))
        return {key: data for (key, _), data in zip(urls, values) if data}
    except Exception:
        # Thumbnail failures must not discard usable search results.
        return {}


def search_games(query):
    query = str(query).strip()[:100]
    if len(query) < 2:
        return []
    payload = _json('https://apis.roblox.com/search-api/omni-search?' + urllib.parse.urlencode({
        'searchQuery': query, 'sessionId': SESSION_ID, 'pageType': 'all'}))
    games = parse_search(payload)
    missing = [g['universe_id'] for g in games if not g['place_id']]
    if missing:
        details = _details(missing)
        for game in games:
            item = details.get(game['universe_id'], {})
            if not game['place_id']:
                game['place_id'] = place_id(item.get('rootPlaceId'))
    return [g for g in games if g['place_id']]


def resolve_place(value):
    requested = place_id(value)
    if not requested:
        raise ValueError('Paste a numeric Roblox place ID.')
    universe = place_id(_json(f'https://apis.roblox.com/universes/v1/places/{requested}/universe').get('universeId'))
    if not universe:
        raise ValueError('Roblox did not return an experience for that place.')
    detail = _details([universe]).get(universe, {})
    name = str(detail.get('name') or '').strip()
    if not name:
        raise ValueError('The experience name is not available.')
    # Keep the exact pasted/detected subplace, not its universe's root place.
    return {'universe_id': universe, 'place_id': requested, 'name': name[:200]}
