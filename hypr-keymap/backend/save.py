#!/usr/bin/env python3
"""Saves edits made in the keymap panel.

  save.py <hyprland config> '<json list of edits>'

Finds keymap-overrides.lua through the keymap hook in your Hyprland config,
writes the edits there, and reloads Hyprland. If the reload reports new config
errors, the previous file is put back. Prints {"ok": true, "data": <gen.lua
output>} or {"ok": false, "error": "..."}.
"""

import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))

HEADER = """\
-- Edits made in the keymap panel, applied by keymap.lua (the keymap hook).
-- Written by the Hyprland Keymap Noctalia plugin; you can also edit it by hand.
-- An entry with bind (+ name, the bind's description) changes that bind: new
-- keys, description, command, or disabled = true. An entry without bind adds one.
"""

KEYS_RE = re.compile(r"^[A-Za-z0-9_:+ \-]{1,80}$")
MODS = {"SUPER", "CTRL", "CONTROL", "ALT", "SHIFT"}


class SaveError(Exception):
    pass


def generate(config):
    out = subprocess.run(["lua", os.path.join(HERE, "gen.lua"), config], capture_output=True, text=True, timeout=15)
    if out.returncode != 0:
        raise SaveError(out.stderr.strip() or "gen.lua failed")
    return json.loads(out.stdout)


def check_keys(keys):
    if not isinstance(keys, str) or not KEYS_RE.match(keys):
        raise ValueError(f"Not a valid shortcut: {keys!r}")
    parts = [p.strip() for p in keys.split("+")]
    if not parts[-1] or parts[-1].upper() in MODS or any(p.upper() not in MODS for p in parts[:-1]):
        raise ValueError(f"Not a valid shortcut: {keys!r}")


def check_text(value, field, limit):
    if not isinstance(value, str) or not value.strip() or len(value) > limit or "\n" in value or "\r" in value:
        raise ValueError(f"The {field} must be a single line of text")


def validate(items):
    if items == {}:  # an empty Lua table encodes as an object
        items = []
    if not isinstance(items, list) or len(items) > 500:
        raise ValueError("Expected a list of edits")
    clean = []
    for item in items:
        if not isinstance(item, dict):
            raise ValueError("Each edit must be an object")
        edit = {}
        if item.get("bind") is not None:
            check_keys(item["bind"])
            edit["bind"] = item["bind"]
            if item.get("name") is not None:
                check_text(item["name"], "name", 200)
                edit["name"] = item["name"]
            if item.get("disabled") is True:
                edit["disabled"] = True
        if not edit.get("disabled"):
            if item.get("keys") is not None:
                check_keys(item["keys"])
                edit["keys"] = item["keys"]
            for field, limit in (("description", 200), ("command", 2000)):
                if item.get(field) is not None:
                    check_text(item[field], field, limit)
                    edit[field] = item[field]
        if "bind" not in edit and not all(edit.get(f) for f in ("keys", "description", "command")):
            raise ValueError("A new bind needs a shortcut, a description and a command")
        clean.append(edit)
    return clean


def lua_string(text):
    out = ['"']
    for ch in text:
        code = ord(ch)
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif code < 32 or code == 127:
            out.append("\\%03d" % code)
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def to_lua(edits):
    lines = [HEADER, "return {"]
    for edit in edits:
        fields = []
        for field in ("bind", "name", "keys", "description", "command", "disabled"):
            if field in edit:
                value = "true" if edit[field] is True else lua_string(edit[field])
                fields.append(f"{field} = {value}")
        lines.append("    { " + ", ".join(fields) + " },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def write_file(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def config_errors():
    return subprocess.run(["hyprctl", "configerrors"], capture_output=True, text=True, timeout=10).stdout.strip()


def reload_hyprland():
    subprocess.run(["hyprctl", "reload"], capture_output=True, timeout=10)
    time.sleep(0.5)


def save(config, edits):
    info = generate(config)
    path = info.get("overrides_path")
    if not info.get("hook") or not path:
        raise SaveError("Editing needs the keymap hook in your Hyprland config. See the plugin README.")

    previous = open(path, encoding="utf-8").read() if os.path.exists(path) else None
    errors_before = config_errors()
    write_file(path, to_lua(edits))
    try:
        data = generate(config)
        reload_hyprland()
        errors = config_errors()
        if errors and errors != errors_before:
            raise SaveError("Hyprland reported: " + errors)
    except Exception as e:
        if previous is None:
            os.remove(path)
        else:
            write_file(path, previous)
        reload_hyprland()
        raise SaveError(f"Not saved, your previous binds are back. {e}")
    if previous is not None:
        write_file(path + ".bak", previous)
    return data


def main():
    try:
        config = os.path.expanduser(sys.argv[1])
        result = {"ok": True, "data": save(config, validate(json.loads(sys.argv[2])))}
    except (IndexError, ValueError, SaveError) as e:
        result = {"ok": False, "error": str(e)}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
