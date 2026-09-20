from __future__ import annotations

import os
import sys


def main() -> int:
    # Materialize the native runtime immediately on first launch. The native
    # DLLs and any folders they create therefore live under %APPDATA%\LelSploit
    # rather than Nuitka's temporary onefile extraction directory.
    from lelsploit_api import APPDATA_DIR, ensure_appdata_dlls
    ensure_appdata_dlls()

    # Keep the process working directory in AppData for the lifetime of the app.
    # Native DLL code that creates relative files/folders (including work done on
    # background threads after Attach/Execute returns) will therefore create them
    # under %APPDATA%\LelSploit instead of beside the launcher EXE.
    APPDATA_DIR.mkdir(parents=True, exist_ok=True)
    os.chdir(APPDATA_DIR)

    args = list(sys.argv[1:])
    if "--lelsploit-proxy" in args:
        args.remove("--lelsploit-proxy")
        from lelsploit_local_proxy import main as run_proxy
        return int(run_proxy(args) or 0)

    # Heavy UI code is imported only after this tiny launcher starts.
    from lelsploit_ui import main as run_ui
    return int(run_ui() or 0)


if __name__ == "__main__":
    sys.exit(main())
