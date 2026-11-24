# Contributing

Issues and pull requests are welcome. For anything larger than a fix, open an
issue first so the approach can be agreed before you write it.

## What this repository is

The first thing a new user runs. The same two examples, an order workflow and
an AI agent that waits for approval, are written in Python, TypeScript and
Rust, and the README walks through them.

So a change has to keep three things true:

- **The three languages do the same thing.** A change to an example is made in
  all three, and the README's snippets match the code.
- **The examples stay small.** They show a workflow surviving a crash. Other
  features belong in each SDK's own documentation.
- **The README's commands work as written.** CI runs them.

## Check a change

You need Docker with Compose v2, and the toolchain for the language you are
changing: Python 3.11 or later, Node.js 22 or later, or stable Rust.

Start the engine, then install or build the example:

```bash
docker compose up -d --wait

# Python
(cd python && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt)
export PYTHON=$PWD/python/.venv/bin/python

# TypeScript
(cd typescript && npm install && npm run build)

# Rust
(cd rust && cargo build --bins)
```

Then run the three checks CI runs, naming the language:

```bash
scripts/run-example.sh python            # the order workflow runs and returns its result
scripts/kill-and-resume.sh python        # the worker is killed during the timer; no step repeats
scripts/agent-kill-and-resume.sh python  # the agent's worker is killed while it waits for approval
```

A check that fails prints a line starting `FAIL:` and the worker's and the
starter's logs, and exits non-zero. Stop the engine with
`docker compose down -v`.

If port 50051 or 8080 is taken, choose others. The scripts follow
`ORCHER_GRPC_PORT`:

```bash
export ORCHER_GRPC_PORT=50061 ORCHER_HTTP_PORT=8081
docker compose up -d --wait
```

## Versions

- The engine version is named once, in `docker-compose.yml` (`ORCHER_IMAGE`).
- Each example names its SDK version range in its own manifest:
  `python/requirements.txt`, `typescript/package.json`, `rust/Cargo.toml`.
- Lockfiles are not committed. Every CI run, and the weekly scheduled one,
  installs the newest SDK release in the range, which is what a new user gets.

## Pull requests

Keep a pull request to one change. CI runs all three languages on every pull
request, including those from forks, and needs no secrets.
