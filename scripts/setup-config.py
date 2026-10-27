#!/usr/bin/env python3
"""Targeted configuration transforms for the approved installer additions."""
import argparse
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import tempfile

PHP_CONFIG = "zz-omarchy-configuration.ini"
PHP_EXTENSIONS = ("bcmath", "curl", "iconv", "intl", "pdo_mysql", "pdo_sqlite", "zip")


def render_php(directory, builtins):
    """Avoid duplicate extension loads from distro/user configuration."""
    loaded = {name.casefold() for name in builtins.splitlines()}
    for path in [directory / "php.ini", *sorted((directory / "conf.d").glob("*.ini"))]:
        if path.name == PHP_CONFIG or not path.exists():
            continue
        for line in path.read_text().splitlines():
            match = re.match(r"\s*(?:zend_)?extension\s*=\s*([^;]+)", line, re.I)
            if match:
                name = Path(match[1].strip().strip('\"\'')).name.removesuffix(".so")
                loaded.add(name.casefold())
    lines = ["; Managed by omarchy-configuration; other PHP settings are preserved."]
    lines += [f"extension={name}" for name in PHP_EXTENSIONS if name not in loaded]
    if "xdebug" not in loaded:
        lines.append("zend_extension=xdebug.so")
    lines.append("xdebug.mode=debug")
    return "\n".join(lines) + "\n"


def configure_shell(config):
    """Replace the stock clock and add OmaConnect without resetting the bar."""
    bar = config.setdefault("bar", {})
    layout = bar.setdefault("layout", {})
    for section in ("left", "center", "right"):
        layout.setdefault(section, [])
    target = next((entry for entries in layout.values() for entry in entries
                   if entry.get("id") == "instrument-cluster"), None)
    if target is None:
        target = next((entry for entries in layout.values() for entry in entries
                       if entry.get("id") == "omarchy.clock"), None)
    if target is None:
        target = {"id": "instrument-cluster"}
        layout["center"].append(target)
    target["id"] = "instrument-cluster"
    kept = False
    for section, entries in layout.items():
        result = []
        for entry in entries:
            if entry.get("id") in ("omarchy.clock", "instrument-cluster"):
                if entry is not target or kept:
                    continue
                kept = True
            result.append(entry)
        layout[section] = result
    bar["centerAnchor"] = "instrument-cluster"
    if not any(entry.get("id") == "omaconnect"
               for entries in layout.values() for entry in entries):
        layout["right"].append({"id": "omaconnect"})
    return config


def write_shell(path, fallback):
    original = path.read_text() if path.exists() else None
    config = json.loads(original if original is not None else fallback.read_text())
    before = json.dumps(config, sort_keys=True)
    configure_shell(config)
    if original is not None and before == json.dumps(config, sort_keys=True):
        print("==> Shell plugin configuration already current")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if original is not None:
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        shutil.copy2(path, path.with_name(path.name + ".bak." + stamp))
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix=".shell-")
    try:
        with os.fdopen(descriptor, "w") as stream:
            stream.write(json.dumps(config, indent=2) + "\n")
        if path.exists():
            shutil.copymode(path, temporary)
        os.replace(temporary, path)
    finally:
        Path(temporary).unlink(missing_ok=True)
    print("==> Configured Instrument Cluster and OmaConnect")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="action", required=True)
    php = subparsers.add_parser("php")
    php.add_argument("directory", type=Path)
    php.add_argument("builtins", help="Output of php -n -m")
    shell = subparsers.add_parser("shell")
    shell.add_argument("path", type=Path)
    shell.add_argument("fallback", type=Path)
    args = parser.parse_args()
    if args.action == "php":
        print(render_php(args.directory, args.builtins), end="")
    else:
        write_shell(args.path, args.fallback)


if __name__ == "__main__":
    main()
