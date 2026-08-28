# Architecture

ViewDoctor keeps build-system discovery separate from source rules.

```text
SwiftPM / Tuist / Xcode manifests
                |
    SwiftSyntax manifest facts
                |
        ViewDoctorGraph + diagnostics
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
default integration path and includes untracked Swift files. Staged mode is a
separate pre-commit boundary. Full scans are intended for baselines, releases,
and graph migrations. Agent JSON omits repeated explanatory context; full JSON
is versioned, compatible fields may be added, and breaking changes require a
new schema version.

## Static graph boundary

SwiftPM and direct Tuist target declarations are parsed as bounded SwiftSyntax
call expressions. Source globs and literal target dependencies are read from
the owning call only. Tuist cross-project paths are normalized before graph
edges are created.

Project description helpers execute Swift to construct targets. ViewDoctor
does not execute manifest helpers during a scan. A graph diagnostic marks that
boundary whenever a Tuist manifest imports `ProjectDescriptionHelpers`; any
unresolved dependency count is also included in the scan summary.

## Privacy boundary

Analysis is local. The MCP adapter executes the local binary and returns bounded
structured findings. It does not upload source to a hosted analyzer. The MCPB
release bundles both layers so clients do not need a separate server install.
