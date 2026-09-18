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

## Install for every cloud session in an environment

Cloud session containers are ephemeral, so anything copied into `~/.claude/skills`
by hand disappears with the container. To have the skills present in *every*
session started in a cloud environment, put them in the environment's **setup
script** instead.

At [claude.ai/code](https://claude.ai/code), open the environment's settings and
paste the contents of [`setup/install-skills.sh`](setup/install-skills.sh) into
the **Setup script** field.

The script runs once per environment; Anthropic then snapshots the filesystem and
reuses it for later sessions, so startup stays fast. The snapshot is rebuilt when
you edit the setup script or allowed hosts, and after roughly seven days — that is
also when the skills are refreshed from `master`. To pull a new version sooner,
make any edit to the setup script field and save.

The repository is public, so the clone needs no credentials.

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
