import argparse
import datetime
import gzip
import hashlib
import ipaddress
import json
import re
import os
import socket
import socketserver
import ssl
import threading
import urllib.request
from pathlib import Path

INTERCEPT_HOSTS = {
    "apis.roblox.com",
    "gamejoin.roblox.com",
    "clientsettings.roblox.com",
    "clientsettingscdn.roblox.com",
}
PROFILE_PATH = "/v1/user/profiles/get-profiles"
GAMEJOIN_PATHS = (
    "/v1/join-game",
    "/v1/join-game-instance",
    "/v1/join-reserved-game",
)
CLIENT_SETTINGS_MARKERS = (
    "/settings/application/",
    "/settings-compressed/application/",
)
DYNAMIC_RELOAD_FLAG = "DFIntSecondsBetweenDynamicVariableReloading"
DYNAMIC_RELOAD_SECONDS = "1"
DCZ_DICTIONARY_RE = re.compile(r"/([0-9a-f]{64})\.dcz(?:$|[?])", re.IGNORECASE)
_DCZ_CACHE = {}
_DCZ_LOCK = threading.Lock()
_FRESH_SIGNATURES = {}
_FRESH_LOCK = threading.Lock()
NAME_KEYS = (
    "username",
    "displayName",
    "combinedName",
    "inExperienceCombinedName",
    "contactName",
    "platformName",
    "alias",
)
EMPTY_NAME = "\u200b"
MAX_HEADER = 1024 * 1024
MAX_BODY = 64 * 1024 * 1024
LIVE_STATUS_NAME = "proxy_live_fastflags.json"


def read_json(path, default):
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
        return value
    except Exception:
        return default


def write_json(path, value):
    path = Path(path)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding="utf-8")
        tmp.replace(path)
    except Exception:
        pass


def normalize_username_state(base):
    state = read_json(base / "proxy_username_active.json", {})
    return state if isinstance(state, dict) else {}


def proxy_suspended(base):
    state = read_json(base / "proxy_runtime.json", {})
    return bool(state.get("suspended", False)) if isinstance(state, dict) else False


def _setting_enabled(settings, path, default=False):
    node = settings
    for part in path.split("/"):
        if not isinstance(node, dict):
            return bool(default)
        node = node.get(part)
    if isinstance(node, str):
        return node.strip().casefold() not in {"", "0", "false", "no", "off"}
    return bool(node)


def managed_fastflags_enabled(base):
    settings = read_json(base / "settings.json", {})
    return _setting_enabled(settings, "fastflags/enabled", False)


def custom_fastflags_enabled(base):
    return True


def fastflags_enabled(base):
    return managed_fastflags_enabled(base) or custom_fastflags_enabled(base)


def effective_fastflags(base):
    flags = {}
    if managed_fastflags_enabled(base):
        managed = read_json(base / "fastflags.json", {})
        if isinstance(managed, dict):
            flags.update(managed)
    custom = read_json(base / "custom_fastflags.json", {})
    state = read_json(base / "custom_fastflag_state.json", {})
    disabled = set(state.get("disabled", [])) if isinstance(state, dict) and isinstance(state.get("disabled", []), list) else set()
    if isinstance(custom, dict):
        flags.update({name: value for name, value in custom.items() if str(name) not in disabled})
    return {str(key): str(value) for key, value in flags.items() if str(key).strip() and value is not None}


def runtime_fastflags(base):
    flags = effective_fastflags(base)
    flags[DYNAMIC_RELOAD_FLAG] = DYNAMIC_RELOAD_SECONDS
    return flags


def clientsettings_requires_fresh(base):
    state = read_json(Path(base) / "proxy_state.json", {})
    generation = int(state.get("custom_fastflags_generation", 0) or 0) if isinstance(state, dict) else 0
    signature = (generation, tuple(sorted(runtime_fastflags(base).items())))
    key = str(Path(base).resolve())
    with _FRESH_LOCK:
        if _FRESH_SIGNATURES.get(key) == signature:
            return False
        _FRESH_SIGNATURES[key] = signature
        return True


def note_live_fastflags(base, path, flags, modified=True):
    status = {
        "active": bool(modified),
        "time": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "path": str(path or "")[:512],
        "flag_count": len(flags or {}),
        "reload_seconds": DYNAMIC_RELOAD_SECONDS,
    }
    write_json(Path(base) / LIVE_STATUS_NAME, status)


def dcz_dictionary_hash(path):
    match = DCZ_DICTIONARY_RE.search(str(path or ""))
    return match.group(1).lower() if match else None


def fetch_dcz_dictionary(digest):
    if not digest or not re.fullmatch(r"[0-9a-f]{64}", digest):
        return None
    with _DCZ_LOCK:
        cached = _DCZ_CACHE.get(digest)
    if cached is not None:
        return cached
    request = urllib.request.Request(
        f"https://clientsettings.roblox.com/v2/compression-dictionaries/{digest}",
        headers={"Accept": "application/octet-stream", "Accept-Encoding": "identity", "User-Agent": "LelSploit/1.0"},
    )
    try:
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(request, timeout=12) as response:
            data = response.read(MAX_BODY + 1)
        if len(data) > MAX_BODY or hashlib.sha256(data).hexdigest() != digest:
            return None
    except Exception:
        return None
    with _DCZ_LOCK:
        _DCZ_CACHE[digest] = data
    return data


def decode_dcz(body, dictionary):
    if not body or dictionary is None:
        return None
    try:
        import zstandard
        zdict = zstandard.ZstdCompressionDict(dictionary, dict_type=zstandard.DICT_TYPE_RAWCONTENT)
        return zstandard.ZstdDecompressor(dict_data=zdict).decompress(body, max_output_size=MAX_BODY)
    except Exception:
        return None


def encode_dcz(body, dictionary):
    if dictionary is None:
        return None
    try:
        import zstandard
        zdict = zstandard.ZstdCompressionDict(dictionary, dict_type=zstandard.DICT_TYPE_RAWCONTENT)
        return zstandard.ZstdCompressor(dict_data=zdict).compress(body)
    except Exception:
        return None


def generate_certificates(ca_dir):
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.hazmat.primitives.serialization import load_pem_private_key
    from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

    ca_dir.mkdir(parents=True, exist_ok=True)
    ca_cert_path = ca_dir / "ca.crt"
    ca_key_path = ca_dir / "ca.key"
    cert_path = ca_dir / "roblox-intercept.crt"
    key_path = ca_dir / "roblox-intercept.key"

    def valid_ca():
        try:
            cert = x509.load_pem_x509_certificate(ca_cert_path.read_bytes())
            key = load_pem_private_key(ca_key_path.read_bytes(), password=None)
            cert_pub = cert.public_key().public_bytes(
                serialization.Encoding.DER,
                serialization.PublicFormat.SubjectPublicKeyInfo,
            )
            key_pub = key.public_key().public_bytes(
                serialization.Encoding.DER,
                serialization.PublicFormat.SubjectPublicKeyInfo,
            )
            now = datetime.datetime.now(datetime.timezone.utc)
            expires = getattr(cert, "not_valid_after_utc", None) or cert.not_valid_after.replace(tzinfo=datetime.timezone.utc)
            return cert_pub == key_pub and expires - now > datetime.timedelta(days=30)
        except Exception:
            return False

    if not valid_ca():
        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        name = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, "LelSploit Local Proxy CA"),
            x509.NameAttribute(NameOID.ORGANIZATION_NAME, "LelSploit"),
        ])
        now = datetime.datetime.now(datetime.timezone.utc)
        cert = (
            x509.CertificateBuilder()
            .subject_name(name)
            .issuer_name(name)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - datetime.timedelta(minutes=5))
            .not_valid_after(now + datetime.timedelta(days=3650))
            .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), critical=False)
            .add_extension(
                x509.KeyUsage(
                    digital_signature=True,
                    key_cert_sign=True,
                    crl_sign=True,
                    content_commitment=False,
                    key_encipherment=False,
                    data_encipherment=False,
                    key_agreement=False,
                    encipher_only=False,
                    decipher_only=False,
                ),
                critical=True,
            )
            .sign(key, hashes.SHA256())
        )
        ca_cert_path.write_bytes(cert.public_bytes(serialization.Encoding.PEM))
        ca_key_path.write_bytes(key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption(),
        ))
        cert_path.unlink(missing_ok=True)
        key_path.unlink(missing_ok=True)

    def valid_leaf():
        try:
            cert = x509.load_pem_x509_certificate(cert_path.read_bytes())
            key = load_pem_private_key(key_path.read_bytes(), password=None)
            cert_pub = cert.public_key().public_bytes(
                serialization.Encoding.DER,
                serialization.PublicFormat.SubjectPublicKeyInfo,
            )
            key_pub = key.public_key().public_bytes(
                serialization.Encoding.DER,
                serialization.PublicFormat.SubjectPublicKeyInfo,
            )
            san = cert.extensions.get_extension_for_class(x509.SubjectAlternativeName).value
            names = set(san.get_values_for_type(x509.DNSName))
            now = datetime.datetime.now(datetime.timezone.utc)
            expires = getattr(cert, "not_valid_after_utc", None) or cert.not_valid_after.replace(tzinfo=datetime.timezone.utc)
            return cert_pub == key_pub and INTERCEPT_HOSTS <= names and expires - now > datetime.timedelta(days=7)
        except Exception:
            return False

    if not valid_leaf():
        ca_cert = x509.load_pem_x509_certificate(ca_cert_path.read_bytes())
        ca_key = load_pem_private_key(ca_key_path.read_bytes(), password=None)
        leaf_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        now = datetime.datetime.now(datetime.timezone.utc)
        san = [x509.DNSName(host) for host in sorted(INTERCEPT_HOSTS)]
        leaf_cert = (
            x509.CertificateBuilder()
            .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "apis.roblox.com")]))
            .issuer_name(ca_cert.subject)
            .public_key(leaf_key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - datetime.timedelta(minutes=5))
            .not_valid_after(now + datetime.timedelta(days=825))
            .add_extension(x509.SubjectAlternativeName(san), critical=False)
            .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(leaf_key.public_key()), critical=False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()), critical=False)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
            .add_extension(
                x509.KeyUsage(
                    digital_signature=True,
                    key_cert_sign=False,
                    crl_sign=False,
                    content_commitment=False,
                    key_encipherment=True,
                    data_encipherment=False,
                    key_agreement=False,
                    encipher_only=False,
                    decipher_only=False,
                ),
                critical=True,
            )
            .sign(ca_key, hashes.SHA256())
        )
        cert_path.write_bytes(leaf_cert.public_bytes(serialization.Encoding.PEM))
        key_path.write_bytes(leaf_key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption(),
        ))
    return ca_cert_path, cert_path, key_path


def recv_until(sock, marker=b"\r\n\r\n", limit=MAX_HEADER):
    data = bytearray()
    while marker not in data:
        chunk = sock.recv(65536)
        if not chunk:
            return bytes(data)
        data.extend(chunk)
        if len(data) > limit:
            raise OSError("HTTP header too large")
    return bytes(data)


def split_headers(raw):
    head, sep, tail = raw.partition(b"\r\n\r\n")
    if not sep:
        return b"", {}, b""
    lines = head.split(b"\r\n")
    first = lines[0]
    headers = {}
    order = []
    for line in lines[1:]:
        if b":" not in line:
            continue
        key, value = line.split(b":", 1)
        key_l = key.strip().lower()
        value = value.strip()
        headers[key_l] = value
        order.append((key_l, value))
    return first, headers, tail


def read_chunked(sock, initial=b""):
    buf = bytearray(initial)
    body = bytearray()
    while True:
        while b"\r\n" not in buf:
            chunk = sock.recv(65536)
            if not chunk:
                raise OSError("Unexpected EOF in chunked body")
            buf.extend(chunk)
        line, _, rest = bytes(buf).partition(b"\r\n")
        buf = bytearray(rest)
        size = int(line.split(b";", 1)[0], 16)
        if size == 0:
            while b"\r\n\r\n" not in buf and len(buf) < MAX_HEADER:
                chunk = sock.recv(65536)
                if not chunk:
                    break
                buf.extend(chunk)
            return bytes(body)
        while len(buf) < size + 2:
            chunk = sock.recv(min(65536, size + 2 - len(buf)))
            if not chunk:
                raise OSError("Unexpected EOF in chunked body")
            buf.extend(chunk)
        body.extend(buf[:size])
        if len(body) > MAX_BODY:
            raise OSError("HTTP body too large")
        del buf[:size + 2]


def read_body(sock, headers, initial=b"", until_close=False):
    transfer = headers.get(b"transfer-encoding", b"").lower()
    if b"chunked" in transfer:
        return read_chunked(sock, initial)
    length = headers.get(b"content-length")
    if length is not None:
        try:
            wanted = int(length)
        except ValueError:
            wanted = 0
        if wanted > MAX_BODY:
            raise OSError("HTTP body too large")
        data = bytearray(initial[:wanted])
        while len(data) < wanted:
            chunk = sock.recv(min(65536, wanted - len(data)))
            if not chunk:
                break
            data.extend(chunk)
        return bytes(data)
    if until_close:
        data = bytearray(initial)
        while len(data) <= MAX_BODY:
            chunk = sock.recv(65536)
            if not chunk:
                break
            data.extend(chunk)
        if len(data) > MAX_BODY:
            raise OSError("HTTP body too large")
        return bytes(data)
    return bytes(initial)


def decode_body(body, encoding):
    encoding = (encoding or b"").lower().strip()
    if not body:
        return body, False
    if encoding == b"gzip" or body[:2] == b"\x1f\x8b":
        try:
            return gzip.decompress(body), True
        except Exception:
            return body, False
    if encoding == b"deflate":
        try:
            import zlib
            return zlib.decompress(body), True
        except Exception:
            return body, False
    if encoding == b"zstd" or body[:4] == b"\x28\xb5\x2f\xfd":
        try:
            import zstandard
            return zstandard.ZstdDecompressor().decompress(body, max_output_size=MAX_BODY), True
        except Exception:
            return body, False
    return body, not encoding


def build_message(first, headers, body, *, remove_encoding=False, force_close=False):
    skip = {b"content-length", b"transfer-encoding", b"proxy-connection"}
    if remove_encoding:
        skip.update({b"content-encoding", b"content-md5", b"etag", b"x-signature-ed25519"})
    lines = [first]
    seen_connection = False
    for key, value in headers.items():
        if key in skip:
            continue
        if key == b"connection":
            seen_connection = True
            value = b"close" if force_close else b"keep-alive"
        lines.append(key + b": " + value)
    if not seen_connection:
        lines.append(b"connection: " + (b"close" if force_close else b"keep-alive"))
    lines.append(b"content-length: " + str(len(body)).encode("ascii"))
    return b"\r\n".join(lines) + b"\r\n\r\n" + body


def set_names(profile, value):
    names = profile.get("names")
    if not isinstance(names, dict):
        names = {}
        profile["names"] = names
    value = EMPTY_NAME if str(value) == "" else str(value)
    for key in NAME_KEYS:
        names[key] = value


def is_self(profile, uid, username):
    if uid and profile.get("userId") is not None and str(profile.get("userId")) == uid:
        return True
    names = profile.get("names")
    return bool(username and isinstance(names, dict) and str(names.get("username", "")) == username)


def remember_identity(base, payload):
    found = None
    def scan(node):
        nonlocal found
        if found is not None:
            return
        if isinstance(node, dict):
            uid = node.get("userId", node.get("UserId"))
            name = node.get("username", node.get("UserName", node.get("name", "")))
            if uid is not None and name:
                found = (str(uid), str(name))
                return
            for value in node.values():
                scan(value)
        elif isinstance(node, list):
            for value in node:
                scan(value)
    scan(payload)
    if found:
        state = read_json(base / "proxy_state.json", {})
        if not isinstance(state, dict):
            state = {}
        state["user_id"] = found[0]
        state["username"] = found[1]
        write_json(base / "proxy_state.json", state)


def creator_user_value(value, key):
    if isinstance(value, str):
        return "Enum.CreatorType.User" if value.startswith("Enum.CreatorType.") else "User"
    if isinstance(value, int) and not isinstance(value, bool):
        return 0 if key == "CreatorType" else 1
    return "User"


def set_creator_fields(value, user_id):
    if isinstance(value, list):
        for child in value:
            set_creator_fields(child, user_id)
        return
    if not isinstance(value, dict):
        return
    for id_key, type_key in (
        ("CreatorId", "CreatorType"),
        ("CreatorId", "CreatorTypeEnum"),
        ("CreatorTargetId", "CreatorType"),
        ("CreatorTargetId", "CreatorTypeEnum"),
        ("creatorId", "creatorType"),
        ("creatorTargetId", "creatorType"),
    ):
        if id_key in value:
            value[id_key] = int(user_id)
        if type_key in value:
            value[type_key] = creator_user_value(value.get(type_key), type_key)
    for child in value.values():
        set_creator_fields(child, user_id)


def modify_json_response(base, host, path, body):
    if proxy_suspended(base):
        return body, False
    try:
        payload = json.loads(body.decode("utf-8"))
    except Exception:
        return body, False
    changed = False
    if host == "gamejoin.roblox.com" and any(fragment in path for fragment in GAMEJOIN_PATHS):
        remember_identity(base, payload)
        state = normalize_username_state(base)
        ident = read_json(base / "proxy_state.json", {})
        uid = str(ident.get("user_id", ""))
        if state.get("self_game_creator") and uid.isdigit():
            set_creator_fields(payload, int(uid))
            changed = True
    elif host == "apis.roblox.com" and PROFILE_PATH in path and isinstance(payload, dict):
        state = normalize_username_state(base)
        ident = read_json(base / "proxy_state.json", {})
        uid = str(ident.get("user_id", ""))
        username = str(ident.get("username", ""))
        profiles = payload.get("profileDetails")
        if isinstance(profiles, list):
            for profile in profiles:
                if not isinstance(profile, dict):
                    continue
                own = is_self(profile, uid, username)
                if own:
                    if state.get("self_apply_ingame"):
                        set_names(profile, state.get("self_name", ""))
                        changed = True
                    if state.get("self_verified") and profile.get("isVerified") is not True:
                        profile["isVerified"] = True
                        changed = True
                else:
                    if state.get("others_apply_ingame"):
                        set_names(profile, state.get("others_name", ""))
                        changed = True
                    if state.get("others_verified") and profile.get("isVerified") is not True:
                        profile["isVerified"] = True
                        changed = True
    elif host in {"clientsettings.roblox.com", "clientsettingscdn.roblox.com"} and fastflags_enabled(base):
        if any(marker in path for marker in CLIENT_SETTINGS_MARKERS) and "PCClientBootstrapper" not in path:
            app_settings = payload.get("applicationSettings") if isinstance(payload, dict) else None
            flags = runtime_fastflags(base)
            if isinstance(app_settings, dict) and flags:
                before = {name: app_settings.get(name) for name in flags}
                app_settings.update(flags)
                changed = any(app_settings.get(name) != before.get(name) for name in flags)
                note_live_fastflags(base, path, flags, True)
    if not changed:
        return body, False
    return json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode("utf-8"), True


def prepare_request(first, headers, body, host, path, base):
    headers = dict(headers)
    headers.pop(b"proxy-connection", None)
    headers[b"connection"] = b"close"
    if host == "apis.roblox.com" and PROFILE_PATH in path:
        headers.pop(b"if-none-match", None)
        headers.pop(b"if-modified-since", None)
        headers[b"cache-control"] = b"no-cache"
    if (
        host in {"clientsettings.roblox.com", "clientsettingscdn.roblox.com"}
        and fastflags_enabled(base)
        and any(marker in path for marker in CLIENT_SETTINGS_MARKERS)
        and "PCClientBootstrapper" not in path
        and clientsettings_requires_fresh(base)
    ):
        headers.pop(b"if-none-match", None)
        headers.pop(b"if-modified-since", None)
        headers.pop(b"pragma", None)
        headers[b"cache-control"] = b"no-cache, no-store"
        headers[b"pragma"] = b"no-cache"
    return build_message(first, headers, body, remove_encoding=False, force_close=True)


def read_http_request(sock):
    raw = recv_until(sock)
    if not raw:
        return None
    first, headers, initial = split_headers(raw)
    if not first:
        return None
    body = read_body(sock, headers, initial)
    parts = first.decode("latin1", errors="replace").split(" ", 2)
    if len(parts) < 2:
        return None
    method, path = parts[0], parts[1]
    return first, headers, body, method, path


def read_http_response(sock, request_method):
    raw = recv_until(sock)
    if not raw:
        return None
    first, headers, initial = split_headers(raw)
    if not first:
        return None
    status = 0
    try:
        status = int(first.split(b" ", 2)[1])
    except Exception:
        pass
    no_body = request_method.upper() == "HEAD" or status in {204, 304} or 100 <= status < 200
    body = b"" if no_body else read_body(sock, headers, initial, until_close=b"content-length" not in headers and b"chunked" not in headers.get(b"transfer-encoding", b"").lower())
    return first, headers, body


def tunnel(client, host, port):
    upstream = socket.create_connection((host, port), timeout=12)
    client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
    stop = threading.Event()
    def copy(src, dst):
        try:
            while not stop.is_set():
                data = src.recv(65536)
                if not data:
                    break
                dst.sendall(data)
        except OSError:
            pass
        finally:
            stop.set()
            try:
                dst.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
    a = threading.Thread(target=copy, args=(client, upstream), daemon=True)
    b = threading.Thread(target=copy, args=(upstream, client), daemon=True)
    a.start(); b.start(); a.join(); b.join()
    try:
        upstream.close()
    except OSError:
        pass


class ProxyHandler(socketserver.BaseRequestHandler):
    def handle(self):
        client = self.request
        client.settimeout(20)
        try:
            raw = recv_until(client)
            if not raw:
                return
            first, headers, initial = split_headers(raw)
            if not first:
                return
            parts = first.decode("latin1", errors="replace").split(" ", 2)
            if len(parts) < 2:
                return
            method, target = parts[0].upper(), parts[1]
            if method != "CONNECT":
                self.handle_plain_http(client, first, headers, initial, target)
                return
            host_port = target.rsplit(":", 1)
            host = host_port[0].strip("[]").lower()
            port = int(host_port[1]) if len(host_port) == 2 and host_port[1].isdigit() else 443
            if host not in INTERCEPT_HOSTS:
                tunnel(client, host, port)
                return
            client.sendall(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.minimum_version = ssl.TLSVersion.TLSv1_2
            context.set_alpn_protocols(["http/1.1"])
            context.load_cert_chain(str(self.server.cert_path), str(self.server.key_path))
            tls_client = context.wrap_socket(client, server_side=True)
            self.handle_intercepted_tls(tls_client, host, port)
        except (OSError, ssl.SSLError, ValueError):
            return

    def handle_plain_http(self, client, first, headers, initial, target):
        try:
            from urllib.parse import urlsplit
            parsed = urlsplit(target.decode("latin1") if isinstance(target, bytes) else target)
            host = parsed.hostname or headers.get(b"host", b"").decode("latin1").split(":", 1)[0]
            port = parsed.port or 80
            path = parsed.path or "/"
            if parsed.query:
                path += "?" + parsed.query
            method = first.split(b" ", 1)[0]
            new_first = method + b" " + path.encode("latin1") + b" HTTP/1.1"
            body = read_body(client, headers, initial)
            upstream = socket.create_connection((host, port), timeout=12)
            upstream.sendall(prepare_request(new_first, headers, body, host.lower(), path, self.server.base_dir))
            response = read_http_response(upstream, method.decode("ascii", errors="ignore"))
            if response:
                rfirst, rheaders, rbody = response
                client.sendall(build_message(rfirst, rheaders, rbody, force_close=True))
            upstream.close()
        except OSError:
            pass

    def handle_intercepted_tls(self, client, host, port):
        client.settimeout(30)
        while True:
            request = read_http_request(client)
            if request is None:
                return
            first, headers, body, method, path = request
            try:
                upstream_raw = socket.create_connection((host, port), timeout=12)
                upstream_context = ssl.create_default_context()
                upstream_context.set_alpn_protocols(["http/1.1"])
                upstream = upstream_context.wrap_socket(upstream_raw, server_hostname=host)
                upstream.sendall(prepare_request(first, headers, body, host, path, self.server.base_dir))
                response = read_http_response(upstream, method)
                upstream.close()
            except (OSError, ssl.SSLError):
                return
            if response is None:
                return
            rfirst, rheaders, rbody = response
            encoding = (rheaders.get(b"content-encoding", b"") or b"").lower().strip()
            is_clientsettings = (
                host in {"clientsettings.roblox.com", "clientsettingscdn.roblox.com"}
                and fastflags_enabled(self.server.base_dir)
                and any(marker in path for marker in CLIENT_SETTINGS_MARKERS)
                and "PCClientBootstrapper" not in path
            )
            if is_clientsettings and encoding == b"dcz":
                digest = dcz_dictionary_hash(path)
                dictionary = fetch_dcz_dictionary(digest) if digest else None
                decoded = decode_dcz(rbody, dictionary)
                if decoded is not None:
                    out_body, modified = modify_json_response(self.server.base_dir, host, path, decoded)
                    recompressed = encode_dcz(out_body, dictionary) if modified else None
                else:
                    modified = False
                    recompressed = None
                    write_json(self.server.base_dir / LIVE_STATUS_NAME, {
                        "active": False,
                        "time": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                        "path": str(path)[:512],
                        "error": "Could not decode the dictionary-compressed ClientSettings response.",
                    })
                if modified and recompressed is not None:
                    rheaders = dict(rheaders)
                    for stale in (b"etag", b"content-md5", b"x-signature-ed25519"):
                        rheaders.pop(stale, None)
                    rheaders[b"cache-control"] = b"no-store, no-cache, must-revalidate"
                    rheaders[b"pragma"] = b"no-cache"
                    client.sendall(build_message(rfirst, rheaders, recompressed, remove_encoding=False, force_close=False))
                else:
                    client.sendall(build_message(rfirst, rheaders, rbody, remove_encoding=False, force_close=False))
                continue
            decoded, decodable = decode_body(rbody, encoding)
            out_body, modified = modify_json_response(self.server.base_dir, host, path, decoded if decodable else rbody)
            if modified:
                rheaders = dict(rheaders)
                rheaders[b"cache-control"] = b"no-store, no-cache, must-revalidate"
                rheaders[b"pragma"] = b"no-cache"
                client.sendall(build_message(rfirst, rheaders, out_body, remove_encoding=True, force_close=False))
            else:
                client.sendall(build_message(rfirst, rheaders, rbody, remove_encoding=False, force_close=False))


class ThreadedProxy(socketserver.ThreadingMixIn, socketserver.TCPServer):
    daemon_threads = True
    allow_reuse_address = True


def _default_appdata_dir():
    roaming = os.environ.get("APPDATA")
    if roaming:
        return Path(roaming).expanduser().resolve() / "LelSploit"
    return (Path.home() / "AppData" / "Roaming" / "LelSploit").resolve()


def main(argv=None):
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--base", default=str(_default_appdata_dir()))
    args = parser.parse_args(argv)
    base = Path(args.base).expanduser().resolve()
    base.mkdir(parents=True, exist_ok=True)
    ca_dir = base / ".lelsploit_proxy"
    ca_cert, cert_path, key_path = generate_certificates(ca_dir)
    ready = base / "proxy_ready.json"
    with ThreadedProxy(("127.0.0.1", int(args.port)), ProxyHandler) as server:
        server.base_dir = base
        server.cert_path = cert_path
        server.key_path = key_path
        write_json(ready, {"port": int(args.port), "pid": os.getpid(), "ca": str(ca_cert)})
        try:
            server.serve_forever(poll_interval=0.25)
        finally:
            try:
                ready.unlink(missing_ok=True)
            except OSError:
                pass


if __name__ == "__main__":
    main()
