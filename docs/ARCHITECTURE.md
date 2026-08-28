# Architecture

ViewDoctor keeps build-system discovery separate from source rules.

```text
SwiftPM / Tuist / Xcode manifests
                |
        ViewDoctorGraph
                |
filesystem -> Discovery -> SourceFile(moduleID)
                              |
                       SwiftSyntax facts
                              |
                            Rules
                              |
                    text / JSON / SARIF
```

## Boundaries

- `ViewDoctorCore` owns stable report contracts.
- `ViewDoctorGraph` owns normalized modules, dependencies, and source roots.
- `ViewDoctorDiscovery` owns filesystem and git inputs.
- `ViewDoctorSyntax` converts source into reusable syntax facts.
- `ViewDoctorRules` contains deterministic, side-effect-free policies.
- `ViewDoctorCLI` is the composition root.

No rule reads manifests, prints output, invokes git, or terminates a process.
No graph provider needs to understand SwiftUI syntax.

## Agent design

Agents should receive the smallest sufficient result. Changed-file mode is the
default integration path. Full scans are intended for baselines, releases, and
graph migrations. JSON is versioned; compatible fields may be added, while
breaking changes require a new schema version.

## Privacy boundary

Analysis is local. A future MCP adapter must execute the local binary and return
bounded structured findings. It must not upload source to a hosted analyzer.

