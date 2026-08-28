# ViewDoctor

**Static analysis for SwiftUI, multi-module Swift projects, and AI coding agents.**

ViewDoctor gives developers and coding agents compact, deterministic feedback
without building an Xcode workspace or uploading source code. It understands
Swift Package Manager, Tuist, Xcode projects, and common folder-based module
layouts, then attaches module ownership to every finding.

```text
Modules/Profile/Sources/ProfileView.swift:42:18: warning: VD001 [tuist:Modules/Profile/Profile]: DateFormatter is constructed inside a body property.
ViewDoctor: 1 finding(s) in 12 file(s), 4 module(s).
```

## Why ViewDoctor

AI can generate Swift code faster than a team can review it. General style
linters are valuable, but they do not give an agent a small contract for
SwiftUI performance risks, task lifetime, and module ownership. ViewDoctor is
designed for the loop:

`edit -> scan changed files -> fix findings -> verify once`

- Local-first: no source uploads and no telemetry.
- Multi-module-first: manifest-derived graph and stable module identifiers.
- Agent-friendly: versioned JSON with explanations and remediation.
- CI-friendly: SARIF, relative paths, deterministic ordering, and exit codes.
- Complementary: use it with the Swift compiler, SwiftLint, Periphery, and Instruments.

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

## GitHub Action

```yaml
permissions:
  contents: read
  security-events: write

steps:
  - uses: actions/checkout@v4
    with:
      fetch-depth: 0
  - uses: KamnevVladimir/ViewDoctor@v0
    with:
      diff-base: origin/main
```

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

## Roadmap

- explicit configuration and baselines;
- module dependency-cycle and undeclared-import rules;
- body complexity and identity rules with low-noise fixtures;
- prebuilt release artifacts and Homebrew installation;
- signed release artifacts and package-manager installation;
- incremental cache and dependency-cone analysis.

## Privacy

ViewDoctor reads local Swift and manifest files. It does not make network
requests during analysis and does not collect telemetry. Public examples and
tests use synthetic source only.

Built by [KamnevApps](https://kamnevapps.com) while shipping production SwiftUI
applications. Licensed under MIT.
