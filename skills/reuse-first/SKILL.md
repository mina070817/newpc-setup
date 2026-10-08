---
name: reuse-first
description: "Search GitHub and public registries for an existing, maintained solution before writing new code, scripts, configs, or tooling; report what you found and reuse it when it fits."
---

# Reuse First

Before building something new, spend a short, bounded effort checking whether someone already solved it well.
The goal is fewer reinvented wheels and more working results — not exhaustive research.

## When this applies

Apply by default to work that creates or materially changes something:

- writing a script, tool, CLI, service, or automation
- adding a feature or wiring up an integration
- installing, configuring, or deploying software
- setting up environments, build systems, or CI
- solving a known technical problem (parsing a format, talking to a device, converting files, scraping, monitoring)

Skip it, or keep it to a quick check, when:

- the request is an explanation, review, diagnosis, or read-only investigation
- the change is small and local to an existing codebase the user already chose
- the user says to implement from scratch, forbids dependencies, or asks for no searching
- the target is proprietary/closed or clearly project-specific

Searching is not a gate. Do the search, then keep moving.

## Procedure

1. **Restate the need in searchable terms.** Reduce the request to the underlying problem
   ("record the X11 screen to mp4 with audio", not the user's phrasing), and generate 2–4 query
   variants: English technical terms, common library names, and domain-specific vocabulary
   (e.g. ROS, Linux desktop, embedded). Chinese-only phrasing usually finds less.

2. **Search.** Prefer, in this order:
   - GitHub repository and code search via `scripts/gh_search.py` (see below)
   - the package registry for the ecosystem in play: PyPI, npm, crates.io, Maven, apt,
     ROS index, Homebrew, AUR
   - an "awesome-<topic>" list when the domain is unfamiliar

   Useful filters: pushed recently, a real license, more than a handful of stars,
   issues answered, releases/tags present.

3. **Judge fit against the actual constraint**, not popularity alone. Check the license
   (GPL in a commercial closed product is a real problem), the language/runtime already present
   in the project, maintenance recency, and whether the dependency footprint is proportionate.

4. **Decide and say so.**
   - An existing solution covers most of the need → use it, say which one and why, then continue the task.
   - Nothing fits → say briefly what you checked and what you rejected, then build it.
   - The user should learn the outcome either way; one or two sentences is enough.

5. **Prefer installing over copying, and reading over installing.** Check the README and release
   notes before running a third-party install script. Do not execute unvetted setup scripts from
   an unknown repository without telling the user what the script does.

## Network and GitHub API

Commands that reach the network must be run with escalated permissions in this environment; the
sandbox blocks outbound traffic. The host proxy is a local Clash instance:

```bash
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897 all_proxy=socks5://127.0.0.1:7897
```

These are usually already exported by the shell environment; set them explicitly when they are not.
GitHub may be slow for a few seconds while the proxy picks a node — retry once before concluding
it is unreachable. `git clone`, `raw.githubusercontent.com`, and the REST API all work once connected.

If the proxy stops responding or GitHub is unreachable after a retry, tell the user and ask them for
working proxy environment variables rather than silently skipping the search.

GitHub API notes:

- `api.github.com` root returns 403; that is normal, it is not a connectivity failure.
- Always send a `User-Agent` header.
- Unauthenticated requests share the *proxy exit IP's* quota (60/hour core, 10/minute search), so
  rate-limit 403s are common here even with light use. Set `GITHUB_TOKEN` or `GH_TOKEN` — a plain
  read-only token is enough — to get reliable limits. Repository *code* search requires a token.
- `scripts/gh_search.py` also accepts a token stored in `~/.codex/github_token` (chmod 600) when the
  environment variable is absent, so a token does not have to be re-exported every session.
- When rate limited, `git clone --depth 1` and `raw.githubusercontent.com` still work; use them to
  inspect a repository you already identified. Do not let a rate limit turn into a skipped search —
  say what you could not check instead of silently building from scratch.

## Scripts

`scripts/gh_search.py` wraps the GitHub REST API over the proxy, so queries do not need to be
hand-assembled with `curl`. Run it with elevated permissions when the sandbox blocks network.

```bash
python3 scripts/gh_search.py repos "screen recorder x11 wayland" --limit 8
python3 scripts/gh_search.py repos "ros lane detection" --language cpp --min-stars 50
python3 scripts/gh_search.py info owner/repo
python3 scripts/gh_search.py code "tf2_ros::Buffer" --language cpp   # needs GITHUB_TOKEN
```
