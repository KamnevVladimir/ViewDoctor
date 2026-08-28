# ViewDoctor

<img src="docs/assets/viewdoctor-icon-1024.png" alt="ViewDoctor" width="120">

**Check SwiftUI diffs with module ownership attached.**

ViewDoctor maps modules from Swift Package Manager, Tuist, Xcode projects, and
common source layouts before it scans SwiftUI code. Run it after a human or
coding agent changes a diff; the result stays local and can be read as terminal
text, versioned JSON, or SARIF.

```text
Modules/Profile/Sources/ProfileView.swift:42:18: warning: VD001 [tuist:Modules/Profile/Profile]: DateFormatter is constructed inside a body property.
ViewDoctor: 1 finding(s) in 12 file(s), 4 module(s).
```

## The review loop

A small generated diff should not require sending the repository back to a
general model just to look for three known SwiftUI risks. ViewDoctor gives those
checks stable rule IDs, exact locations, module ownership, and bounded output:

`edit -> scan changed files -> fix findings -> verify once`

- It reads source locally and has no telemetry.
- Manifest-derived identifiers keep findings useful in large repositories.
- JSON includes explanations and remediation; SARIF works in code scanning.
- Deterministic ordering and exit codes make the same command useful in CI.

ViewDoctor complements the Swift compiler, SwiftLint, Periphery, and
Instruments. It does not replace builds, profiling, or architecture review.

## Install and run

Requires Swift 6.2 or newer for source builds.

```sh
git clone https://github.com/KamnevVladimir/ViewDoctor.git
cd ViewDoctor
swift build -c release
.build/release/viewdoctor scan /path/to/project
```

Analyze only the current git diff—the recommended mode for coding agents:

```sh
viewdoctor scan . --git-diff --format json
viewdoctor scan . --base origin/main --format json
```

Inspect discovered modules and dependencies:

```sh
viewdoctor graph .
```

Generate GitHub Code Scanning output:

```sh
viewdoctor scan . --base origin/main --format sarif > viewdoctor.sarif
```

## Multi-module architecture

ViewDoctor builds a normalized graph from all manifests it discovers:

| Build system | Discovery source | Module ownership |
|---|---|---|
| SwiftPM | `Package.swift` targets and dependencies | `Sources/<Target>` |
| Tuist | `Project.swift` targets and dependencies | project/target source roots |
| Xcode | `.xcodeproj/project.pbxproj` native targets | target source roots |
| Folder layout | `Modules`, `Apps`, `Sources`, `Tests` | deterministic fallback |

When providers overlap, the longest matching source root wins. The graph model
has a reverse dependency-cone operation so diff analysis can validate the
changed module and modules that depend on it without scanning unrelated features.

## Rules

| Rule | Default | Detects |
|---|---|---|
| `VD001` | warning | reusable or expensive object construction in SwiftUI `body` |
| `VD002` | note | collection transformations repeated inside `body` |
| `VD003` | warning | detached task creation inside `body` |

Rules intentionally use conservative language: a finding is a reviewable risk,
not a claim that profiling has proven a performance regression.

The current release has three rules. It does not yet enforce dependency
direction, detect cycles, or prove runtime performance. Those are explicit
roadmap items rather than implied capabilities.

## GitHub Action

Run ViewDoctor in CI on a macOS runner with Swift 6.2 or newer. The action
builds the pinned Swift package, scans the checked-out repository, and can
upload SARIF findings to GitHub Code Scanning.

```yaml
name: ViewDoctor

on:
  pull_request:

permissions:
  contents: read
  security-events: write

jobs:
  analyze:
    runs-on: macos-26
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - uses: KamnevVladimir/ViewDoctor@v0
        with:
          diff-base: origin/main
```

Set `upload-sarif: false` when the workflow cannot grant
`security-events: write`, such as a restricted fork workflow. Use a full
release tag such as `v0.1.6` when you need an immutable dependency; `v0` is
the maintained major-version pointer.

## Output contract

JSON reports include `schemaVersion`, relative source locations, stable rule
IDs, module IDs, remediation, and a module graph summary. Integrations should
consume JSON or SARIF instead of parsing human text.

Optional `.viewdoctor.json`:

```json
{
  "excludedPaths": ["Generated", "Vendor"],
  "disabledRules": ["VD002"],
  "minimumSeverity": "warning",
  "maxFindings": 100
}
```

Exit codes:

- `0`: scan completed without error-level findings;
- `1`: at least one error-level finding;
- `2`: arguments or scan startup failed.

## Coding-agent integration

The repository contains a Codex/OpenAI skill and local MCP server in `plugin/`.
The MCP tools call the same CLI without a shell, keep source on the local
machine, and expose scans and module graphs to coding agents. The CLI remains
the source of truth; the skill and MCP server are thin adapters.

The release also includes a macOS MCP Bundle. Install
[`ViewDoctor-v0.1.6.mcpb`](https://github.com/KamnevVladimir/ViewDoctor/releases/download/v0.1.6/ViewDoctor-v0.1.6.mcpb)
in any client that supports MCPB, or discover it in the official MCP Registry as
`io.github.KamnevVladimir/viewdoctor`. The bundle contains the local CLI and
stdio adapter; repository source is not sent to a hosted service.

## Roadmap

- baselines for existing findings;
- module dependency-cycle and undeclared-import rules;
- body complexity and identity rules with low-noise fixtures;
- signed release artifacts and package-manager installation;
- incremental cache and dependency-cone analysis.

## Privacy

ViewDoctor reads local Swift and manifest files. It does not make network
requests during analysis and does not collect telemetry. Public examples and
tests use synthetic source only.

Built by [KamnevApps](https://kamnevapps.com) while shipping production SwiftUI
applications. Licensed under MIT.
