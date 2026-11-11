"""Runs RepKeeper's tests in real Lua 5.1 (the language World of Warcraft uses).

Usage: python tests/run_tests.py   (GitHub Actions runs this before every CurseForge upload)
Needs: pip install lupa

Every test runs twice: as World of Warcraft: Midnight (Retail 12.1.5) and as World of Warcraft: Forever (1.60.1, where
characters have a first and a last name). Both games run the same modern client and interface code.

Optional API check: with clones of Blizzard's UI source (https://github.com/Gethe/wow-ui-source) the run also checks that
every game function, widget method, event, template, texture and atlas RepKeeper uses exists in the game it ran as:
  git clone --depth 1 -b live https://github.com/Gethe/wow-ui-source ref/ui-live
  git clone --depth 1 -b forever https://github.com/Gethe/wow-ui-source ref/ui-forever
(or point WOW_UI_SOURCES at the folder that holds the ui-* clones).
"""
import locale
import os
import pathlib
import re
import sys

from lupa.lua51 import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parent.parent
SUITES = ["test_main.lua"]
DOCS = "Interface/AddOns/Blizzard_APIDocumentationGenerated"
GAMES = {"midnight": ("Midnight", "ui-live"), "forever": ("Forever", "ui-forever")}
KINDS = ("methods", "globals", "templates", "textures", "atlases", "fields")
# Game files that exist in both clients (checked on wago.tools) although no Blizzard code names them.
VERIFIED_FILES = {
    "interface\\buttons\\ui-panel-minimizebutton-up",
    "interface\\buttons\\ui-panel-minimizebutton-down",
    "interface\\buttons\\ui-panel-minimizebutton-highlight",
}


def sources_root():
    for candidate in (os.environ.get("WOW_UI_SOURCES"), ROOT / "ref", ROOT.parent / "ref"):
        if candidate and pathlib.Path(candidate).is_dir():
            return pathlib.Path(candidate)
    return None


def ui_sources():
    root = sources_root()
    found = {}
    if root:
        for flavor, (game, folder) in GAMES.items():
            if (root / folder / DOCS).is_dir():
                found[flavor] = root / folder
    return found


def read(path):
    return path.read_text(encoding="utf-8", errors="replace")


def known_events(sources):
    """Events documented in every game (an event missing from one fails RegisterEvent in the tests)."""
    events = None
    for path in sources.values():
        names = set()
        for doc in (path / DOCS).glob("*.lua"):
            names.update(re.findall(r'LiteralName = "([A-Z0-9_]+)"', read(doc)))
        events = names if events is None else events & names
    return events


def new_runtime(suite, flavor, events):
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    g.ROOT = ROOT.as_posix()
    g.MOCK_FLAVOR = flavor
    if events:
        g.KNOWN_EVENTS = lua.table_from(sorted(events))
    lua.execute(f'dofile(ROOT .. "/tests/harness.lua"); dofile(ROOT .. "/tests/{suite}")')
    return lua


def run_suite(suite, flavor, events, used, only=None):
    print(f"== {suite} ({GAMES[flavor][0]})")
    names = list(new_runtime(suite, flavor, events).globals().TestNames().values())
    if only:
        names = [n for n in names if only.lower() in n.lower()]
    failed = 0
    for name in names:
        lua = new_runtime(suite, flavor, events)
        ok, err = lua.globals().RunOne(name)
        for kind, text in zip(KINDS, lua.globals().UsedApi()):
            used[kind].update(x for x in text.split("\n") if x)
        if ok:
            print(f"  PASS  {name}")
        else:
            failed += 1
            print(f"  FAIL  {name}\n      {err}")
    print(f"{suite} ({GAMES[flavor][0]}): {len(names) - failed} passed, {failed} failed")
    return failed


def normal_path(path):
    return re.sub(r"[\\/]+", "\\\\", path.lower()).removesuffix(".blp")


def check_api(flavor, path, used):
    """Every widget method must be documented (or called by Blizzard's own code), every game global, namespaced
    function, template, texture and atlas must appear in Blizzard's code of the game the tests ran as."""
    game = GAMES[flavor][0]
    problems = 0
    methods, namespaces = set(), {}
    for doc in (path / DOCS).glob("*.lua"):
        text = read(doc)
        functions = set(re.findall(r'Name = "([A-Za-z0-9_]+)",\s*Type = "Function"', text))
        if 'Type = "ScriptObject"' in text:
            methods.update(functions)
        for namespace in re.findall(r'Namespace = "([A-Za-z0-9_]+)"', text):
            namespaces.setdefault(namespace, set()).update(functions)
    identifiers, called, templates, textures, strings, members = set(), set(), set(), set(), set(), set()
    for file in (path / "Interface").rglob("*"):
        if file.suffix in (".lua", ".xml"):
            text = read(file)
            identifiers.update(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", text))
            called.update(re.findall(r":([A-Za-z_][A-Za-z0-9_]*)\(", text))
            members.update(re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*[.:][A-Za-z_][A-Za-z0-9_]*)", text))
            textures.update(normal_path(t) for t in re.findall(r"[Ii]nterface[\\/][\w\\/\-. ]+", text))
            strings.update(re.findall(r'"([^"\n]{2,80})"', text))
            if file.suffix == ".xml":
                templates.update(re.findall(r'<[A-Za-z]+ name="([A-Za-z0-9_]+)"[^>]*virtual="true"', text))
    for entry in sorted(used["methods"]):
        kind, method = entry.split(":")
        if method not in methods and method not in called:
            problems += 1
            print(f"  API   {game}: widget method {kind}:{method} is not in the API documentation")
    for name in sorted(used["globals"]):
        if name not in identifiers:
            problems += 1
            print(f"  API   {game}: {name} doesn't appear anywhere in Blizzard's UI code")
    for entry in sorted(used["fields"]):
        namespace, field = entry.split(".", 1)
        documented = field in namespaces.get(namespace, ())
        if not documented and entry not in members and f"{namespace}:{field}" not in members:
            problems += 1
            print(f"  API   {game}: {entry} isn't documented or used by any Blizzard code")
    for name in sorted(used["templates"]):
        if name not in templates:
            problems += 1
            print(f"  API   {game}: template {name} isn't defined")
    for name in sorted(used["textures"]):
        key = normal_path(name)
        if key not in textures and key not in VERIFIED_FILES:
            problems += 1
            print(f"  API   {game}: texture {name} isn't used by any Blizzard code (is it in the game?)")
    for name in sorted(used["atlases"]):
        if name not in strings:
            problems += 1
            print(f"  API   {game}: atlas {name} isn't used by any Blizzard code (is it in the game?)")
    if problems == 0:
        counts = ", ".join(f"{len(used[k])} {k}" for k in KINDS)
        print(f"API check ({game}): {counts} exist")
    return problems


def main():
    # Like the game: Lua's string.lower and %a know only A to Z. Python starts with the computer's locale, which would
    # also change letters like Ö (and bytes of UTF-8 text) on Windows.
    locale.setlocale(locale.LC_ALL, "C")
    only = sys.argv[1] if len(sys.argv) > 1 else None
    sources = ui_sources()
    events = known_events(sources) if len(sources) == len(GAMES) else None
    failed = 0
    for flavor in GAMES:
        used = {k: set() for k in KINDS}
        failed += sum(run_suite(s, flavor, events, used, only) for s in SUITES)
        if flavor in sources and not only:
            failed += check_api(flavor, sources[flavor], used)
    if len(sources) < len(GAMES):
        print("API check skipped (no Blizzard UI source clones for both games, see the top of this file)")
    print("ALL PASSED" if failed == 0 else f"{failed} FAILED")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
