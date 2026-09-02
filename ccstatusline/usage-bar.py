#!/usr/bin/env python3
"""Coloured usage bar with pace marker and end-of-window projection for ccstatusline.

Usage (as a ccstatusline custom-command widget, preserveColors on):
    usage-bar.py session   # 5-hour window
    usage-bar.py weekly    # 7-day, all models
    usage-bar.py fable     # 7-day, Fable only

Output example:  ▓▓░░░│░░░░ 15% →33%
  fill  = usage so far
  │     = where usage would be if it tracked time exactly
  →N%   = projected usage at reset if the current rate holds

Data sources: the JSON ccstatusline pipes to stdin (rate_limits, fresh every render)
for session/weekly, and ccstatusline's own cache (~/.cache/ccstatusline/usage.json)
for fable. No network, no credentials.
"""
import json
import os
import sys
import time
from datetime import datetime

BAR_WIDTH = 10
FILL, EMPTY, MARK = "▓", "░", "│"
def _palette():
    """good/warn/bad as RGB tuples, from palette.json written by ccs-theme; Kanagawa Wave if absent."""
    defaults = {"good": "98bb6c", "warn": "e6c384", "bad": "ff5d62"}
    try:
        defaults.update(json.load(open(os.path.expanduser("~/.config/ccstatusline/palette.json"))))
    except Exception:
        pass
    to_rgb = lambda h: (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
    return to_rgb(defaults["good"]), to_rgb(defaults["warn"]), to_rgb(defaults["bad"])


GREEN, AMBER, RED = _palette()
CACHE_STALE_AFTER = 3600  # seconds

WINDOWS = {
    "session": {"seconds": 5 * 3600, "usage": "sessionUsage", "reset": "sessionResetAt", "rl": "five_hour"},
    "weekly": {"seconds": 7 * 86400, "usage": "weeklyUsage", "reset": "weeklyResetAt", "rl": "seven_day"},
    "fable": {"seconds": 7 * 86400, "usage": "fableUsage", "reset": "fableResetAt", "rl": None},
}


def colour(text, code):
    # Foreground + bold only: ccstatusline's powerline background must survive.
    r, g, b = code
    return f"\x1b[1m\x1b[38;2;{r};{g};{b}m{text}\x1b[39m\x1b[22m"


def dim(text):
    return f"\x1b[2m{text}\x1b[22m"


def read_stdin_json():
    try:
        if sys.stdin.isatty():
            return {}
        return json.loads(sys.stdin.read() or "{}")
    except Exception:
        return {}


def read_cache(now):
    path = os.environ.get("USAGE_BAR_CACHE") or os.path.expanduser("~/.cache/ccstatusline/usage.json")
    try:
        if now - os.path.getmtime(path) > CACHE_STALE_AFTER:
            return None
        data = json.load(open(path))
        if data.get("error"):
            return None
        return data
    except Exception:
        return None


def to_epoch(value):
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).timestamp()
    except Exception:
        return None


def load(kind, now):
    """Return (used_percent, reset_epoch) or None."""
    spec = WINDOWS[kind]
    stdin = read_stdin_json()
    bucket = (stdin.get("rate_limits") or {}).get(spec["rl"]) if spec["rl"] else None
    if bucket and bucket.get("used_percentage") is not None:
        return float(bucket["used_percentage"]), to_epoch(bucket.get("resets_at"))
    cache = read_cache(now)
    if cache and cache.get(spec["usage"]) is not None:
        return float(cache[spec["usage"]]), to_epoch(cache.get(spec["reset"]))
    return None


def make_bar(used, elapsed):
    filled = round(max(0.0, min(100.0, used)) / 100 * BAR_WIDTH)
    chars = [FILL if i < filled else EMPTY for i in range(BAR_WIDTH)]
    if elapsed is not None:
        chars[min(int(elapsed * BAR_WIDTH), BAR_WIDTH - 1)] = MARK
    return "".join(chars)


def pick_colour(kind, used, projected):
    # Weekly windows colour by where you'll land; the 5h window by where you are
    # (its projection swings too much early in the window to drive the colour).
    value = projected if (kind != "session" and projected is not None) else used
    if kind == "session":
        return GREEN if value < 50 else AMBER if value < 80 else RED
    return GREEN if value < 80 else AMBER if value <= 100 else RED


def render(kind, now):
    loaded = load(kind, now)
    if loaded is None:
        return dim("n/a")
    used, reset = loaded
    elapsed = projected = None
    if reset is not None:
        length = WINDOWS[kind]["seconds"]
        elapsed = max(0.0, min(1.0, (now - (reset - length)) / length))
        if elapsed >= 0.02:
            projected = used / elapsed
    text = f"{make_bar(used, elapsed)} {used:.0f}%"
    if projected is not None:
        text += f" →{min(projected, 999):.0f}%"
    return colour(text, pick_colour(kind, used, projected))


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else ""
    if kind not in WINDOWS:
        print("usage-bar.py session|weekly|fable", file=sys.stderr)
        return 2
    now = float(os.environ.get("USAGE_BAR_NOW") or time.time())
    print(render(kind, now))
    return 0


if __name__ == "__main__":
    sys.exit(main())
