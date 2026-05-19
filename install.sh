#!/bin/bash
# Install Claude Code skills to ~/.claude/skills/

set -e

SKILLS_DIR="$HOME/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/skills"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: skills/ directory not found at $SOURCE_DIR"
  exit 1
fi

mkdir -p "$SKILLS_DIR"

installed=0
backed_up=0

for skill_dir in "$SOURCE_DIR"/*/; do
  skill_name=$(basename "$skill_dir")
  target="$SKILLS_DIR/$skill_name"

  mkdir -p "$target"

  if [ -f "$target/SKILL.md" ]; then
    cp "$target/SKILL.md" "$target/SKILL.md.bak"
    backed_up=$((backed_up + 1))
  fi

  cp "$skill_dir/SKILL.md" "$target/SKILL.md"
  installed=$((installed + 1))
done

echo "Installed $installed skills to $SKILLS_DIR"
if [ $backed_up -gt 0 ]; then
  echo "Backed up $backed_up existing skills (.bak files created)"
fi
echo "Done. Restart Claude Code to pick up the new skills."
