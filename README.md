# Cloudticon skills

Claude Code skills for [Cloudticon](https://github.com/cloudticon) (CT) — Kubernetes
manifests defined in TypeScript instead of Helm charts.

| Skill | Covers |
|---|---|
| `ct-cli` | `ct init`, `ct template`, `ct apply`, `ct delete`, `ct list`, `ct types`, `main.ct`, `values.json` |
| `ct-dev` | `ct dev`, `dev.ct`, live sync to a pod, port forwarding, dev namespaces |
| `ct-patterns` | `resource()`, `webApp`, `expose`, `createFactory`, `env`/`vol` helpers, GitHub URL imports |

## Install as a plugin (recommended)

In Claude Code:

```
/plugin marketplace add cloudticon/skills
/plugin install cloudticon@cloudticon
```

The skills load automatically whenever a task matches their description.
`/plugin marketplace update cloudticon` pulls later changes.

## Install manually

Copy the skill directories into your personal or project skills directory:

```bash
git clone https://github.com/cloudticon/skills.git /tmp/ct-skills

# for every project (personal)
cp -r /tmp/ct-skills/skills/* ~/.claude/skills/

# or just this project
mkdir -p .claude/skills && cp -r /tmp/ct-skills/skills/* .claude/skills/
```

Restart Claude Code afterwards so the skills are picked up.

## Layout

```
.claude-plugin/
  plugin.json        # plugin manifest
  marketplace.json   # lets this repo serve as its own marketplace
skills/
  ct-cli/      SKILL.md  reference.md
  ct-dev/      SKILL.md  reference.md
  ct-patterns/ SKILL.md  reference.md  examples.md
```

Each `SKILL.md` carries the frontmatter (`name`, `description`) Claude uses to decide
when to load it; the `reference.md` / `examples.md` files are read on demand.
