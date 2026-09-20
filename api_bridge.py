from __future__ import annotations

import time
from lelsploit_api import LelSploit


_API_CLASS = None


def _get_api_class():
    """Return the compiled/imported API class lazily."""
    global _API_CLASS

    if _API_CLASS is None:
        _API_CLASS = LelSploit
    return _API_CLASS


class CombinedStop:
    def __init__(self, *events):
        self.events = tuple(event for event in events if event is not None)

    def is_set(self):
        return any(event.is_set() for event in self.events)

    def wait(self, timeout=None):
        if self.is_set():
            return True

        if timeout is None:
            while not self.is_set():
                time.sleep(0.05)
            return True

        deadline = time.monotonic() + max(0.0, float(timeout))

        while not self.is_set():
            remaining = deadline - time.monotonic()

            if remaining <= 0:
                return False

            time.sleep(min(0.05, remaining))

        return True


def attach_api(log, stop, api=None, force=False):
    if api is None:
        api_class = _get_api_class()
        api = api_class()
        api.initialize()
        force = True

    if force or not api.is_attached():
        api.attach()

    deadline = time.monotonic() + 20

    while not api.is_attached():
        if stop.is_set():
            return None

        if time.monotonic() >= deadline:
            raise TimeoutError(
                "LelSploit API did not report an attached client."
            )

        stop.wait(0.25)

    if stop.is_set():
        return None

    log("LelSploit API reports attached.")
    return api


def run_script(source, log, stop, api=None):
    api = attach_api(log, stop, api)

    if api is None:
        return None

    api.execute(source)
    log("Script sent. Check the client's output.")
    return api


def reattach_api(log, stop, api=None, initial=False):
    api = attach_api(log, stop, api, force=True)

    if api is not None:
        log("Attached successfully." if initial else "Reattached successfully.")

    return api


def detach_api(api, log=None):
    if api is None:
        return None

    detached = False

    for name in (
        "detach",
        "disconnect",
        "deattach",
        "close",
        "dispose",
        "shutdown",
    ):
        method = getattr(api, name, None)

        if not callable(method):
            continue

        try:
            method()
            detached = True
            break
        except TypeError:
            continue
        except Exception:
            break

    if log is not None:
        log(
            "Detached from Roblox."
            if detached
            else "Attachment state cleared."
        )

    return None
