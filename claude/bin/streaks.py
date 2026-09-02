#!/usr/bin/env python3
"""Streaks and achievements for Claude Code.

Subcommands
  widget        ccstatusline custom-command: reads the status JSON on stdin, records the
                session's tokens/duration, checks achievements, prints the badge.
  tool          PostToolUse hook: counts a tool call for the session and day.
  tool-failed   PostToolUseFailure hook: counts a failed tool call.
  seed          Backfill active days from history.jsonl (safe to re-run).
  show          Dump streak, today's totals, and unlocked achievements.
  reset-unlocks Forget all achievements (they can be re-earned).

State lives in ~/.claude-work/streaks/state.json. Weekends never break a streak;
they only count if you used Claude that day.
"""
import json
import os
import subprocess
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
try:
    import fcntl  # macOS / Linux
except ImportError:  # Windows
    fcntl = None
    import msvcrt
from datetime import date, datetime, timedelta

CFG = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude-work")
DIR = os.path.join(CFG, "streaks")
STATE = os.path.join(DIR, "state.json")
LOCK = os.path.join(DIR, ".lock")
HISTORY = os.path.join(CFG, "history.jsonl")
USAGE_CACHE = os.path.expanduser("~/.cache/ccstatusline/usage.json")
SHOW_UNLOCK_FOR = timedelta(hours=24)
KEEP_SESSION_DAYS = 60

# key: (emoji, name, description)
ACHIEVEMENTS = {
    "hello": ("👋", "Hello World", "first day on the board"),
    "streak_7": ("🗓️", "Week Warrior", "7-day streak"),
    "streak_30": ("📆", "Habitual", "30-day streak"),
    "streak_100": ("🏛️", "Centurion", "100-day streak"),
    "tokens_10m": ("💰", "Ten Mill", "10M tokens in a day"),
    "tokens_100m": ("🐋", "Whale", "100M tokens in a day"),
    "tools_500": ("🏃", "Marathon", "500 tool calls in one session"),
    "tools_1000_day": ("🏭", "Factory", "1000 tool calls in a day"),
    "sessions_5": ("🐑", "Herder", "5 sessions in a day"),
    "long_4h": ("🚂", "Long Haul", "a 4-hour session"),
    "long_8h": ("🦉", "Overnighter", "an 8-hour session"),
    "night_owl": ("🌃", "Night Owl", "working between 1am and 5am"),
    "early_bird": ("🐦", "Early Bird", "working between 5am and 7am"),
    "clean_100": ("🧼", "Clean Hands", "100 tool calls, zero failures"),
    "context_800k": ("🧠", "Context Maxxing", "800k tokens in one context"),
    "tapped_out": ("🚰", "Tapped Out", "95% of the weekly Fable limit"),
}


# ---------- state ----------

def now():
    return datetime.now()


def today():
    return date.today().isoformat()


def empty_state():
    return {"days": {}, "achievements": {}, "last_unlock": None}


def day_rec(state, day):
    return state["days"].setdefault(day, {"tools": 0, "failed": 0, "sessions": {}})


class locked_state:
    """Read-modify-write under an exclusive lock. Writes only if the state changed."""

    def __enter__(self):
        os.makedirs(DIR, exist_ok=True)
        self.lock = open(LOCK, "w", encoding="utf-8")
        if fcntl:
            fcntl.flock(self.lock, fcntl.LOCK_EX)
        else:
            msvcrt.locking(self.lock.fileno(), msvcrt.LK_LOCK, 1)
        try:
            self.state = json.load(open(STATE, encoding="utf-8"))
        except Exception:
            self.state = empty_state()
        self.before = json.dumps(self.state, sort_keys=True)
        return self.state

    def __exit__(self, *exc):
        try:
            if exc[0] is None and json.dumps(self.state, sort_keys=True) != self.before:
                tmp = STATE + ".tmp"
                with open(tmp, "w", encoding="utf-8") as f:
                    json.dump(self.state, f)
                os.replace(tmp, STATE)
        finally:
            if fcntl:
                fcntl.flock(self.lock, fcntl.LOCK_UN)
            else:
                msvcrt.locking(self.lock.fileno(), msvcrt.LK_UNLCK, 1)
            self.lock.close()


def read_state():
    try:
        return json.load(open(STATE, encoding="utf-8"))
    except Exception:
        return empty_state()


def prune(state):
    cutoff = (date.today() - timedelta(days=KEEP_SESSION_DAYS)).isoformat()
    for day, rec in state["days"].items():
        if day < cutoff and rec.get("sessions"):
            rec["sessions"] = {}


# ---------- streak ----------

def streak(state):
    days = state["days"]
    d = date.today()
    if d.isoformat() not in days:  # nothing yet today: count up to yesterday
        d -= timedelta(days=1)
    n = 0
    while True:
        key = d.isoformat()
        if key in days:
            n += 1
        elif d.weekday() < 5:  # a missed weekday ends the streak
            break
        d -= timedelta(days=1)
        if n == 0 and (date.today() - d).days > 7:
            break
    return n


# ---------- achievements ----------

def unlock(state, key):
    if key in state["achievements"]:
        return
    stamp = now().strftime("%Y-%m-%dT%H:%M")
    state["achievements"][key] = stamp
    state["last_unlock"] = {"key": key, "at": stamp}
    emoji, name, desc = ACHIEVEMENTS[key]
    notify(f"{emoji} {name} — {desc}")


def notify(text, title="Claude Code achievement"):
    """Desktop notification: osascript on macOS, a Windows toast via PowerShell, else nothing."""
    try:
        if sys.platform == "darwin":
            cmd = ["osascript", "-e", f'display notification "{text}" with title "{title}"']
        elif sys.platform == "win32":
            ps = ("[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] > $null;"
                  "$t=[Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent('ToastText02');"
                  f"$t.GetElementsByTagName('text')[0].AppendChild($t.CreateTextNode('{title}')) > $null;"
                  f"$t.GetElementsByTagName('text')[1].AppendChild($t.CreateTextNode('{text}')) > $null;"
                  "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code').Show("
                  "[Windows.UI.Notifications.ToastNotification]::new($t))")
            cmd = ["powershell", "-NoProfile", "-NonInteractive", "-Command", ps]
        else:
            return
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, encoding="utf-8")
    except Exception:
        pass


def fable_usage():
    try:
        return float(json.load(open(USAGE_CACHE, encoding="utf-8")).get("fableUsage") or 0)
    except Exception:
        return 0.0


def check(state, session=None):
    unlock(state, "hello")
    s = streak(state)
    if s >= 7:
        unlock(state, "streak_7")
    if s >= 30:
        unlock(state, "streak_30")
    if s >= 100:
        unlock(state, "streak_100")
    t = day_rec(state, today())
    tokens = sum(x.get("tokens", 0) for x in t["sessions"].values())
    if tokens >= 10_000_000:
        unlock(state, "tokens_10m")
    if tokens >= 100_000_000:
        unlock(state, "tokens_100m")
    if t["tools"] >= 1000:
        unlock(state, "tools_1000_day")
    if len(t["sessions"]) >= 5:
        unlock(state, "sessions_5")
    h = now().hour
    if 1 <= h < 5:
        unlock(state, "night_owl")
    if 5 <= h < 7:
        unlock(state, "early_bird")
    if session:
        if session.get("tools", 0) >= 500:
            unlock(state, "tools_500")
        if session.get("duration_ms", 0) >= 4 * 3600_000:
            unlock(state, "long_4h")
        if session.get("duration_ms", 0) >= 8 * 3600_000:
            unlock(state, "long_8h")
        if session.get("tools", 0) >= 100 and session.get("failed", 0) == 0:
            unlock(state, "clean_100")
        if session.get("context", 0) >= 800_000:
            unlock(state, "context_800k")
    if fable_usage() >= 95:
        unlock(state, "tapped_out")


# ---------- commands ----------

def read_json_stdin():
    try:
        return json.loads(sys.stdin.read() or "{}")
    except Exception:
        return {}


def cmd_tool(failed):
    data = read_json_stdin()
    sid = data.get("session_id") or "unknown"
    with locked_state() as state:
        t = day_rec(state, today())
        sess = t["sessions"].setdefault(sid, {"tokens": 0, "duration_ms": 0, "tools": 0, "failed": 0, "context": 0})
        t["tools"] += 1
        sess["tools"] += 1
        if failed:
            t["failed"] += 1
            sess["failed"] += 1
        check(state, sess)


def cmd_widget():
    data = read_json_stdin()
    sid = data.get("session_id") or "unknown"
    cw = data.get("context_window") or {}
    tokens = int(cw.get("total_input_tokens") or 0) + int(cw.get("total_output_tokens") or 0)
    cu = cw.get("current_usage") or {}
    context = sum(int(cu.get(k) or 0) for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens")) if isinstance(cu, dict) else int(cu or 0)
    duration = int((data.get("cost") or {}).get("total_duration_ms") or 0)
    with locked_state() as state:
        t = day_rec(state, today())
        sess = t["sessions"].setdefault(sid, {"tokens": 0, "duration_ms": 0, "tools": 0, "failed": 0, "context": 0})
        sess["tokens"] = max(sess["tokens"], tokens)
        sess["duration_ms"] = max(sess["duration_ms"], duration)
        sess["context"] = max(sess["context"], context)
        prune(state)
        check(state, sess)
        s = streak(state)
        badge = f"🔥 {s}d"
        lu = state.get("last_unlock")
        if lu:
            try:
                if now() - datetime.strptime(lu["at"], "%Y-%m-%dT%H:%M") <= SHOW_UNLOCK_FOR:
                    emoji, name, _ = ACHIEVEMENTS[lu["key"]]
                    badge += f" · {emoji} {name}"
            except Exception:
                pass
    print(badge)


def cmd_seed():
    days = set()
    try:
        for line in open(HISTORY, encoding="utf-8"):
            try:
                ts = json.loads(line).get("timestamp")
                if ts:
                    days.add(datetime.fromtimestamp(ts / 1000).date().isoformat())
            except Exception:
                continue
    except OSError:
        pass
    with locked_state() as state:
        added = 0
        for d in days:
            if d not in state["days"]:
                day_rec(state, d)
                added += 1
    print(f"seeded {added} new day(s); {len(days)} active days in history; streak now {streak(read_state())}d")


def cmd_show():
    state = read_state()
    t = state["days"].get(today(), {"tools": 0, "failed": 0, "sessions": {}})
    tokens = sum(x.get("tokens", 0) for x in t["sessions"].values())
    print(f"streak: {streak(state)}d   today: {len(t['sessions'])} sessions, {t['tools']} tools ({t['failed']} failed), {tokens:,} tokens")
    print("unlocked:")
    for key, at in sorted(state["achievements"].items(), key=lambda kv: kv[1]):
        e, n, d = ACHIEVEMENTS.get(key, ("?", key, ""))
        print(f"  {at}  {e} {n} — {d}")
    locked = [f"{e} {n} ({d})" for k, (e, n, d) in ACHIEVEMENTS.items() if k not in state["achievements"]]
    if locked:
        print("still locked:")
        for item in locked:
            print("  " + item)


def main(argv):
    cmd = argv[0] if argv else "show"
    if cmd == "widget":
        cmd_widget()
    elif cmd == "tool":
        cmd_tool(False)
    elif cmd == "tool-failed":
        cmd_tool(True)
    elif cmd == "seed":
        cmd_seed()
    elif cmd == "show":
        cmd_show()
    elif cmd == "reset-unlocks":
        with locked_state() as state:
            state["achievements"] = {}
            state["last_unlock"] = None
        print("achievements reset")
    else:
        print(__doc__.strip())
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
