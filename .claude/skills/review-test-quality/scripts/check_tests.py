#!/usr/bin/env python3
"""Mechanical test-quality checks. Every finding names its fix."""
import ast, re, sys, pathlib

CANNOT_FAIL = {"True", "1 == 1", "not None"}

def check(path):
    src = path.read_text()
    tree = ast.parse(src)
    findings = []
    for node in ast.walk(tree):
        if not (isinstance(node, ast.FunctionDef) and node.name.startswith("test_")):
            continue
        body = ast.get_source_segment(src, node) or ""
        asserts = [n for n in ast.walk(node) if isinstance(n, (ast.Assert, ast.Call))
                   and (isinstance(n, ast.Assert) or getattr(getattr(n, "func", None), "attr", "").startswith("assert"))]
        if not asserts:
            findings.append((node.lineno, node.name, "no assertion at all",
                             "assert the documented outcome, not that the call returned"))
        for a in asserts:
            seg = (ast.get_source_segment(src, a) or "").strip()
            if any(p in seg for p in CANNOT_FAIL):
                findings.append((a.lineno, node.name, f"assertion cannot fail: {seg}",
                                 "assert the specific expected value"))
        if re.search(r"\b(time\.)?sleep\(", body):
            findings.append((node.lineno, node.name, "fixed sleep",
                             "poll with a deadline instead of sleeping a fixed time"))
        if "# TC-" not in body:
            findings.append((node.lineno, node.name, "no traceability annotation",
                             "add a '# TC-<id>' comment linking this to its test case"))
    return findings

def main():
    if len(sys.argv) != 2:
        print("usage: check_tests.py <file-or-dir>"); return 2
    root = pathlib.Path(sys.argv[1])
    files = sorted(root.rglob("test_*.py")) if root.is_dir() else [root]
    total = 0
    for f in files:
        found = check(f)
        total += len(found)
        for line, test, problem, fix in found:
            print(f"{f}:{line}  {test}\n    problem: {problem}\n    fix: {fix}")
    print(f"\n{total} finding(s)" if total else "\nno mechanical findings")
    return 1 if total else 0

sys.exit(main())
