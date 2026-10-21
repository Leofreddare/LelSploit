from __future__ import annotations

APP_VERSION = "1.1.1"

import os
import sys
import traceback
from pathlib import Path


def _runtime_dir() -> Path:
    return Path(__file__).resolve().parent


def _appdata_dir() -> Path:
    root = os.environ.get("APPDATA")
    if root:
        return Path(root).expanduser().resolve() / "LelSploit"
    return (Path.home() / "AppData" / "Roaming" / "LelSploit").resolve()


def _report_error(exc: BaseException, appdata: Path) -> None:
    detail = "".join(traceback.format_exception(type(exc), exc, exc.__traceback__))
    try:
        (appdata / "logs").mkdir(parents=True, exist_ok=True)
        (appdata / "logs" / "startup_error.log").write_text(detail, encoding="utf-8")
    except Exception:
        pass
    if sys.platform == "win32":
        try:
            import ctypes
            ctypes.windll.user32.MessageBoxW(
                None,
                "LelSploit could not start.\n\n"
                + str(exc)
                + "\n\nDetails were written to "
                + str(appdata / "logs" / "startup_error.log"),
                "LelSploit",
                0x10,
            )
        except Exception:
            pass


def main() -> int:
    appdata = _appdata_dir()
    try:
        runtime = _runtime_dir()
        runtime_text = str(runtime)
        if runtime_text not in sys.path:
            sys.path.insert(0, runtime_text)
        from api.lelsploit_api import ensure_appdata_dlls
        ensure_appdata_dlls()
        appdata.mkdir(parents=True, exist_ok=True)
        os.chdir(appdata)
        args = list(sys.argv[1:])
        if "--lelsploit-proxy" in args:
            args.remove("--lelsploit-proxy")
            from lelsploit_local_proxy import main as run_proxy
            return int(run_proxy(args) or 0)
        from lelsploit_ui import main as run_ui
        return int(run_ui(app_version=APP_VERSION) or 0)
    except BaseException as exc:
        _report_error(exc, appdata)
        return 1


if __name__ == "__main__":
    sys.exit(main())