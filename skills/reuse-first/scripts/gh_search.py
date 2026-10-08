#!/usr/bin/env python3
"""Search GitHub for existing solutions before building something new.

Thin wrapper over the GitHub REST API so queries never have to be hand-assembled
with curl. Uses the local Clash proxy when no proxy environment variable is set.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import textwrap
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.github.com"
DEFAULT_PROXY = "http://127.0.0.1:7897"
USER_AGENT = "reuse-first-skill/1.0"
TIMEOUT = 30


def ensure_proxy() -> None:
    """Fall back to the host's local Clash proxy when nothing is configured."""
    if os.environ.get("https_proxy") or os.environ.get("HTTPS_PROXY"):
        return
    os.environ.setdefault("https_proxy", DEFAULT_PROXY)
    os.environ.setdefault("http_proxy", DEFAULT_PROXY)


def token() -> str | None:
    from_env = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if from_env:
        return from_env.strip()
    codex_home = os.environ.get("CODEX_HOME") or os.path.expanduser("~/.codex")
    for name in ("github_token", "github_token.txt"):
        path = os.path.join(codex_home, name)
        try:
            with open(path, encoding="utf-8") as handle:
                value = handle.read().strip()
        except OSError:
            continue
        if value:
            return value
    return None


def call(path: str, params: dict | None = None, raw: bool = False):
    url = API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    headers = {"User-Agent": USER_AGENT, "Accept": "application/vnd.github+json"}
    tok = token()
    if tok:
        headers["Authorization"] = f"Bearer {tok}"
    if raw:
        headers["Accept"] = "application/vnd.github.raw"
    request = urllib.request.Request(url, headers=headers)
    opener = urllib.request.build_opener()
    try:
        with opener.open(request, timeout=TIMEOUT) as response:
            payload = response.read()
            return payload.decode("utf-8", "replace") if raw else json.loads(payload)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace").strip()
        hint = ""
        if exc.code in (401, 403) and "rate limit" in body.lower():
            hint = (
                "\nHint: rate limited. Unauthenticated requests share the proxy exit IP's quota"
                " (60/hour core, 10/min search) and it is often already used up."
                "\n      Export GITHUB_TOKEN or GH_TOKEN to raise the limit."
                "\n      Meanwhile `git clone --depth 1` and raw.githubusercontent.com stay usable."
            )
        elif exc.code in (401, 403):
            hint = (
                "\nHint: this endpoint may require authentication."
                "\n      Export GITHUB_TOKEN (or GH_TOKEN) with a personal access token."
            )
        elif exc.code == 404:
            hint = "\nHint: check the owner/repo spelling."
        sys.exit(f"GitHub returned HTTP {exc.code} for {url}\n{body[:400]}{hint}")
    except urllib.error.URLError as exc:
        sys.exit(
            f"Cannot reach {url}: {exc.reason}\n"
            "Check the proxy, e.g.\n"
            "  export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897 "
            "all_proxy=socks5://127.0.0.1:7897"
        )


def clip(text: str | None, width: int) -> str:
    if not text:
        return ""
    text = " ".join(text.split())
    return textwrap.shorten(text, width=width, placeholder="…")


def result_block(repo: dict, index: int | None = None) -> str:
    license_info = (repo.get("license") or {}).get("spdx_id") or "no license"
    topics = repo.get("topics") or []
    lines = [
        f"{f'{index}. ' if index else ''}{repo['full_name']}  "
        f"★{repo['stargazers_count']}  forks:{repo['forks_count']}  "
        f"{repo.get('language') or '?'}  {license_info}",
        f"   {repo['html_url']}",
        f"   updated {str(repo.get('pushed_at'))[:10]}  "
        f"open issues {repo.get('open_issues_count')}"
        + (f"  archived {repo.get('archived')}" if repo.get("archived") else "")
        + (f"  topics: {', '.join(topics[:6])}" if topics else ""),
    ]
    description = clip(repo.get("description"), 160)
    if description:
        lines.append(f"   {description}")
    return "\n".join(lines)


def cmd_repos(args: argparse.Namespace) -> int:
    query = args.query
    if args.language:
        query += f" language:{args.language}"
    if args.min_stars:
        query += f" stars:>={args.min_stars}"
    if args.pushed_after:
        query += f" pushed:>{args.pushed_after}"
    data = call(
        "/search/repositories",
        {
            "q": query,
            "per_page": args.limit,
            "sort": args.sort,
            "order": "desc",
        },
    )
    if args.json:
        print(json.dumps(data.get("items", []), indent=2, ensure_ascii=False))
        return 0
    items = data.get("items", [])
    print(f"query: {query}\n{data.get('total_count', 0)} repositories match; showing {len(items)}\n")
    for i, repo in enumerate(items, 1):
        print(result_block(repo, i))
        print()
    return 0


def cmd_code(args: argparse.Namespace) -> int:
    if not token():
        sys.exit(
            "GitHub code search requires authentication.\n"
            "Export GITHUB_TOKEN (or GH_TOKEN) with a personal access token, or use "
            "`repos`/`info` instead."
        )
    query = args.query
    if args.language:
        query += f" language:{args.language}"
    data = call("/search/code", {"q": query, "per_page": args.limit})
    if args.json:
        print(json.dumps(data.get("items", []), indent=2, ensure_ascii=False))
        return 0
    items = data.get("items", [])
    print(f"query: {query}\n{data.get('total_count', 0)} files match; showing {len(items)}\n")
    for item in items:
        repo = item.get("repository", {})
        print(f"{repo.get('full_name')}  ★{repo.get('stargazers_count', '?')}")
        print(f"   {item.get('path')}")
        print(f"   {item.get('html_url')}")
    return 0


def cmd_info(args: argparse.Namespace) -> int:
    repo = call(f"/repos/{args.repo}")
    print(result_block(repo))
    print(f"   default branch: {repo.get('default_branch')}  created {str(repo.get('created_at'))[:10]}")
    if repo.get("homepage"):
        print(f"   homepage: {repo['homepage']}")
    try:
        release = call(f"/repos/{args.repo}/releases/latest")
        print(f"   latest release: {release.get('tag_name')} ({str(release.get('published_at'))[:10]})")
    except SystemExit:
        print("   latest release: none published")
    if args.readme:
        print("\n--- README (head) ---")
        content = call(f"/repos/{args.repo}/readme", raw=True)
        for line in content.splitlines()[: args.readme_lines]:
            print(line)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="gh_search.py",
        description="Search GitHub for existing solutions before building your own.",
        epilog=(
            "Examples:\n"
            '  gh_search.py repos "screen recorder x11 wayland" --limit 8\n'
            '  gh_search.py repos "lane detection" --language cpp --min-stars 50\n'
            "  gh_search.py info owner/repo --readme\n"
            '  gh_search.py code "tf2_ros::Buffer" --language cpp   (needs GITHUB_TOKEN)'
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="command", required=True)

    repos = sub.add_parser("repos", help="search repositories")
    repos.add_argument("query")
    repos.add_argument("--limit", type=int, default=10)
    repos.add_argument("--language", help="filter by language, e.g. python, cpp, rust")
    repos.add_argument("--min-stars", type=int, default=0)
    repos.add_argument("--pushed-after", help="only repos pushed after this date, e.g. 2024-01-01")
    repos.add_argument("--sort", default="stars", choices=["stars", "forks", "updated", "best-match"])
    repos.add_argument("--json", action="store_true")
    repos.set_defaults(func=cmd_repos)

    code = sub.add_parser("code", help="search code (requires GITHUB_TOKEN)")
    code.add_argument("query")
    code.add_argument("--limit", type=int, default=10)
    code.add_argument("--language")
    code.add_argument("--json", action="store_true")
    code.set_defaults(func=cmd_code)

    info = sub.add_parser("info", help="show one repository in detail")
    info.add_argument("repo", help="owner/repo")
    info.add_argument("--readme", action="store_true", help="also print the README head")
    info.add_argument("--readme-lines", type=int, default=60)
    info.set_defaults(func=cmd_info)
    return parser


def main() -> int:
    ensure_proxy()
    args = build_parser().parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
