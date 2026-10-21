#!/usr/bin/env python3
"""personal-strip.py : remove Legal's personal-only customizations from a packaged file copy.

stdin -> stdout. Used by sync-from-live.sh when copying the live macdock shell.qml into the repo.
The live dock has __copland_* token support (Legal's personal app launchers, never packaged).
Stripping happens on the PACKAGED copy only; the live file keeps everything.

If a new personal block appears that these rules do not match, the final assertion fails loudly
(sync-from-live.sh exits 1) and a rule must be added here - explicit rules beat clever parsing.
"""
import re
import sys

s = sys.stdin.read()

# 1) the "New note / New window" chain inside `else if (act === "new")`:
#    collapse the copland if/else-if arms, keep the final else as the body
s = re.sub(
    r'([ \t]*)else if \(act === "new"\) \{\n'
    r'(?:[ \t]*[^\n]*__copland_[^\n]*\n)+'          # the copland arms
    r'[ \t]*else \{ ([^\n]*) \}\n'
    r'[ \t]*\}\n',
    r'\1else if (act === "new") { \2 }\n',
    s,
)

# 2) any remaining standalone lines that belong to a copland block: drop them,
#    together with a comment line directly above them that introduces the block
lines = s.splitlines(keepends=True)
out = []
drop_comment = None
for ln in lines:
    if "__copland_" in ln or re.search(r'//[^\n]*[Cc]opland', ln):
        if "__copland_" in ln:
            if drop_comment is not None:
                out.pop()                      # the comment that introduced this block
                drop_comment = None
            continue
        drop_comment = len(out)                # remember where this intro comment sits
    else:
        drop_comment = None
    out.append(ln)
s = "".join(out)

if "__copland_" in s:
    sys.stderr.write("personal-strip: __copland_ refs still present - add a rule for the new block:\n")
    for i, ln in enumerate(s.splitlines(), 1):
        if "__copland_" in ln:
            sys.stderr.write(f"  line {i}: {ln.strip()[:120]}\n")
    sys.exit(1)

sys.stdout.write(s)
