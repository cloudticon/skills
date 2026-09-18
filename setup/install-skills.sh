#!/bin/bash
# Installs the Cloudticon skills into the session's skills directory.
#
# Paste this into the "Setup script" field of a cloud environment at
# claude.ai/code. It runs once per environment (the result is cached as a
# filesystem snapshot), so every session started in that environment has the
# skills available without any per-session work.
set -u

REPO_URL="https://github.com/cloudticon/skills.git"
REPO_REF="master"
SRC="/tmp/ct-skills-src"
DST="${HOME:-/root}/.claude/skills"

rm -rf "$SRC"
git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$SRC" || true

if [ -d "$SRC/skills" ]; then
  mkdir -p "$DST"
  for dir in "$SRC"/skills/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    name="$(basename "$dir")"
    rm -rf "${DST:?}/$name"
    cp -r "$dir" "$DST/$name"
    echo "installed skill: $name"
  done
else
  echo "WARNING: $REPO_URL@$REPO_REF has no skills/ directory - nothing installed" >&2
fi

rm -rf "$SRC"
exit 0
