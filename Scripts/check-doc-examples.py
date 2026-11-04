#!/usr/bin/env python3
"""Type-checks every Swift example in the documentation against the built module.

Reads the code blocks of the DocC articles, the README and the `///` comments in
Sources/MidiDSL, wraps each one in whichever context it needs (a file, a function
body, a Section, a Track, a Session, or the end of a modifier chain), and runs
`swiftc -typecheck` on it. A block that compiles in none of them is reported with
its file and line.

A `…` in an example stands for "anything": `Section { … }` is filled with a note,
and a block whose `…` cannot be filled that way is skipped and counted.

Run `swift build` first. Usage: Scripts/check-doc-examples.py [module-dir]
"""
import concurrent.futures as cf
import glob
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODULES = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, ".build", "debug")


def markdown_blocks(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    i = 0
    while i < len(lines):
        if lines[i].strip() == "```swift":
            j, body = i + 1, []
            while not lines[j].strip().startswith("```"):
                body.append(lines[j])
                j += 1
            yield i + 1, "\n".join(body)
            i = j
        i += 1


def comment_blocks(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    i = 0
    while i < len(lines):
        m = re.match(r"^\s*/// ?```swift\s*$", lines[i])
        if m:
            j, body = i + 1, []
            while not re.match(r"^\s*/// ?```\s*$", lines[j]):
                body.append(re.sub(r"^\s*/// ?", "", lines[j]))
                j += 1
            yield i + 1, "\n".join(body)
            i = j
        i += 1


ARGS = r"\((?:[^()]|\([^()]*\))*\)"   # a parenthesised argument list, one level of nesting


def fill(code):
    code = re.sub(r"(Section(?:" + ARGS + r")?\s*)\{\s*…\s*\}", r'\1{ "C" }', code)
    code = re.sub(r"(Track" + ARGS + r"\s*)\{\s*…\s*\}", r'\1{ Section { "C" } }', code)
    code = re.sub(r"(Loop" + ARGS + r"\s*)\{\s*(\w+\s+in\s*)?…\s*\}",
                  lambda m: m.group(1) + "{ " + (m.group(2) or "") + 'Section { "C" } }', code)
    code = re.sub(r"(Session\s*)\{\s*(\w+\s+in\s*)?…\s*\}",
                  lambda m: m.group(1) + "{ " + (m.group(2) or "") + 'Track("t") { Section { "C" } } }', code)
    code = re.sub(r"(Grid" + ARGS + r"\s*)\{\s*…\s*\}", r'\1{ _ in "x" }', code)
    code = re.sub(r"(Phrase" + ARGS + r"\s*)\{\s*…\s*\}", r'\1{ _ in "C" }', code)
    lines = [l.replace("@main", "") for l in code.split("\n") if not l.strip().startswith("import ")]
    return "\n".join(lines)


def unfilled(code):
    """Whether a `…` is left outside a comment, where it would stand for code."""
    return any("…" in line.split("//")[0] for line in code.split("\n"))


def file_scope(code):
    return "\n".join("private " + l if re.match(r"^(struct|enum|class|let|var|func)\b", l) else l
                     for l in code.split("\n"))


WRAPS = [
    lambda c: file_scope(c),
    lambda c: "private func _b() {\n" + c + "\n}",
    lambda c: "private func _b() throws {\n" + c + "\n}",
    lambda c: "private func _b() -> Section { Section {\n" + c + "\n} }",
    lambda c: 'private func _b() -> Track { Track("t") {\n' + c + "\n} }",
    lambda c: "private func _b() -> Session { Session {\n" + c + "\n} }",
    lambda c: 'private func _b() -> Session { Session { pass in\n' + c + "\n} }",
    lambda c: 'private func _b() -> Section { Section { "C" }\n' + c + "\n}",
    lambda c: 'private func _b() -> Track { Track("t") { Section { "C" } }\n' + c + "\n}",
    lambda c: 'private func _b() -> Session { Session { Track("t") { Section { "C" } } }\n' + c + "\n}",
    lambda c: 'private func _b() -> Section { Section { "C D E F"\n' + c + "\n} }",
]


def compiles(code, scratch, name):
    path = os.path.join(scratch, name + ".swift")
    best = None
    for wrap in WRAPS:
        open(path, "w", encoding="utf-8").write("import MidiDSL\nimport Foundation\n" + wrap(code) + "\n")
        r = subprocess.run(["swiftc", "-typecheck", "-parse-as-library", "-I", MODULES, path],
                           capture_output=True, text=True)
        if r.returncode == 0:
            return None
        errors = [l.split(": error: ", 1)[1] for l in (r.stdout + r.stderr).split("\n") if ": error: " in l]
        if best is None or len(errors) < len(best):
            best = errors
    return (best or ["does not compile"])[:3]


def main():
    blocks = []
    for path in sorted(glob.glob(os.path.join(ROOT, "Sources/MidiDSL/MidiDSL.docc/*.md"))) + [os.path.join(ROOT, "README.md")]:
        blocks += [(path, line, code) for line, code in markdown_blocks(path)]
    for path in sorted(glob.glob(os.path.join(ROOT, "Sources/MidiDSL/*.swift"))):
        blocks += [(path, line, code) for line, code in comment_blocks(path)]

    skipped, failures = 0, []
    with tempfile.TemporaryDirectory() as scratch, cf.ThreadPoolExecutor(os.cpu_count() or 4) as pool:
        jobs = {}
        for n, (path, line, code) in enumerate(blocks):
            if ".package(" in code:      # a Package.swift excerpt, not code against the module
                continue
            filled = fill(code)
            if unfilled(filled):
                skipped += 1
                continue
            jobs[pool.submit(compiles, filled, scratch, f"B{n:04d}")] = (path, line)
        for job in cf.as_completed(jobs):
            errors = job.result()
            if errors:
                failures.append((jobs[job], errors))

    for (path, line), errors in sorted(failures):
        print(f"{os.path.relpath(path, ROOT)}:{line}: example does not compile")
        for e in errors:
            print(f"    {e}")
    checked = len(jobs)
    print(f"{checked - len(failures)} of {checked} examples compile; {skipped} with an unfilled … skipped.")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
