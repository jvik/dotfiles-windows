---
name: git-worktrees
description: Create, inspect, use, and clean up Git worktrees for isolated tasks or parallel branches. Use when the user asks to work in a separate checkout, manage worktrees, or recover a moved or missing worktree.
---

# Git worktrees

Keep each task in its own checkout while preserving existing branches and uncommitted work.
Follow the repository's AGENTS.md and the user's chosen branch, base, and location.
Use commands compatible with the user's shell: fish inside WSL, PowerShell on Windows.
Invoke another shell explicitly if a script needs it. The git commands below work in both.

## Inspect before changing state

Run these from the relevant repository:

```shell
git rev-parse --show-toplevel
git rev-parse --path-format=absolute --git-common-dir
git status --short --branch
git worktree list --porcelain
```

Identify the task's base commit and whether its branch already exists or is checked out
elsewhere. Use explicit refs when local and remote branch names could be ambiguous.
Honor a specified base; otherwise use the repository's documented integration branch
or established default. Ask if the choice remains ambiguous. Fetch the relevant remote
when freshness matters and network access is available; disclose when using cached refs.

A dirty starting checkout is compatible with creating another worktree. Leave its changes
in place; do not stash, reset, move, or copy them unless the task calls for it. A new
worktree starts from a commit, so uncommitted changes will not follow automatically.

## Create or reuse a checkout

- Reuse a worktree already assigned to the requested branch after inspecting its state.
  If it contains unrelated work, choose another branch or clarify the intended task.
- Follow existing path and branch conventions. Otherwise prefer a sibling directory such
  as `<repo>.worktrees/<task-slug>`, outside the source tree. Use a readable branch name
  derived from the task. Check both the path and branch for collisions before creating.
- Keep a worktree on the same filesystem as its repository. Inside WSL that is the Linux
  (ext4) home, not `/mnt/c`: Windows drives are slow from WSL and bring CRLF and
  permission problems. Do not create a worktree on the other side of the WSL boundary
  from its repository; Windows Git and WSL Git record paths differently.
- For a new branch, use `git worktree add -b BRANCH PATH BASE`. For an existing branch,
  use `git worktree add PATH BRANCH`. Substitute quoted, concrete values before running.
  Do not use `-B` to overwrite a branch or `--force` to bypass an occupied branch.
- Verify the new checkout's branch, HEAD, and status. Read its applicable repository
  instructions before editing, and run subsequent commands with that checkout as the
  working directory or with an explicit `git -C PATH`.

Linked worktrees share objects, refs, stashes, and usually repository configuration and
hooks; their working files and indexes are separate. Treat `.git` as potentially a file.
Do not assume creating a worktree isolates config changes, hook effects, or branch deletion.

## Set up and work

Use the project's documented bootstrap and validation commands. Dependencies, ignored
files, local configuration, and secrets may be absent in the new checkout. Recreate only
what the task needs; do not automatically copy `.env` files or symlink dependency trees
from another checkout. Avoid port and output-path collisions when running services.

Inside a sandbox, both the checkout and the resolved common Git directory must be
accessible with the permissions the operation needs. If Git cannot access shared metadata,
fix the mount or request the required permission rather than rewriting `.git`.

Check status and review the diff in the task's checkout before handoff. Report the path,
branch, base, changes, and validation results. Creating a worktree does not itself authorize
merging, pushing, opening a PR, or deleting it; follow the scope of the user's task.

## Clean up or repair

- Remove a worktree when cleanup is requested or included in the task. Inspect its status,
  including untracked and ignored files that removal could discard, and check for unique
  commits. Keep unfinished work and useful local files unless their disposal is authorized.
- Run `git worktree remove PATH` from a checkout that will remain. Avoid `rm -rf`,
  `Remove-Item -Recurse`, and forced removal. If removal fails, inspect the cause before
  changing anything else.
- Branch deletion is separate. When authorized, use `git branch -d BRANCH` after checking
  integration into the intended destination. Squash merges may fail Git's ancestry check;
  explain that result and preserve the branch unless forced deletion is explicitly authorized.
- Use `git worktree move` for relocation. For a checkout moved outside Git, use
  `git worktree repair` with the relevant paths. Inspect stale entries with
  `git worktree prune --dry-run` before pruning; an unavailable disk is not proof a
  checkout was deleted. Respect worktree locks and do not unlock them without cause.
