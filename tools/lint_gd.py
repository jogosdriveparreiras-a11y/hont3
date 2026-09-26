"""Check GDScript delimiter balance and indentation without an installed editor.

This is deliberately a narrow structural check, not a GDScript parser.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = [*sorted((ROOT / "game").glob("*.gd")), *sorted((ROOT / "tools").glob("*.gd"))]


def check(path):
    stack = []
    last_indent = None
    previous = ""
    pairs = {"(": ")", "[": "]", "{": "}"}
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if raw.startswith(" "):
            raise AssertionError(f"{path}:{line_no}: leading spaces")
        indent = len(raw) - len(raw.lstrip("\t"))
        code = []
        quote = None
        escaped = False
        at_top = not stack
        for char in raw[indent:]:
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
                continue
            if char in ('"', "'"):
                quote = char
                continue
            if char == "#":
                break
            code.append(char)
            if char in pairs:
                stack.append((char, line_no))
            elif char in pairs.values():
                assert stack and pairs[stack[-1][0]] == char, (path, line_no, char)
                stack.pop()
        stripped = "".join(code).strip()
        if at_top and stripped:
            if last_indent is not None and indent > last_indent:
                assert indent == last_indent + 1 and previous.endswith(":"), (
                    path, line_no, "unexpected indentation", previous
                )
            last_indent, previous = indent, stripped
        assert quote is None, (path, line_no, "unclosed string")
    assert not stack, (path, "unclosed delimiter", stack[-1])


for file in FILES:
    check(file)
print(f"OK: {len(FILES)} GDScript files structurally checked")
