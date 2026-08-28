# Why the workflow changed in 0.1.7

This release does not add another SwiftUI rule. It fixes four places where the
analysis loop could be ambiguous, wasteful, or quietly wrong.

## Evidence

| Observed pain | Public signal | ViewDoctor change |
|---|---|---|
| “Diff scan” did not say whether it belonged after every edit or at pre-commit. | A developer asked this directly on the [ViewDoctor SwiftUI thread](https://www.reddit.com/r/SwiftUI/comments/1w0vaou/i_built_a_local_swiftui_analyzer_that_maps/). SwiftLint also documents a distinct [pre-commit hook with strict failure](https://github.com/realm/SwiftLint#git-pre-commit-hook). | `--git-diff` is the edit checkpoint; `--staged` is the index-only pre-commit checkpoint. |
| A new file could be absent from `git diff HEAD` and therefore absent from analysis. | This follows from [`git diff`'s tracked-diff boundary](https://git-scm.com/docs/git-diff) and is easy to hit when an agent creates a new view before staging it. | Changed and base modes union the Git diff with untracked, non-ignored Swift files. |
| Guidance in a prompt can be forgotten; a quality gate needs a deterministic failure. | In a [modular-iOS agent discussion](https://www.reddit.com/r/iOSProgramming/comments/1rz6h9y/how_i_got_an_ai_coding_agent_to_actually_respect/), developers described build-time enforcement as more durable than architecture prose. SwiftLint exposes the same choice through strict mode. | `--fail-on note|warning|error` makes the threshold explicit for hooks and CI. |
| Machine output repeated context that the next edit did not need. | Swift agent authors have been [separating guidance by concern](https://www.reddit.com/r/SwiftUI/comments/1rnf25c/23_agent_skills_for_ios_26_development_swiftui/) specifically to reduce loaded context. | `--format agent` keeps rule, severity, path, location, owner, message, and fix. It omits verbose explanation and replaces the repeated module list with a count. |
| A regex-derived module graph could look complete while dependencies leaked across target declarations or Tuist helpers hid targets. | Tuist documents both the [target dependency graph](https://docs.tuist.dev/en/guides/features/projects/dependencies) and [`ProjectDescriptionHelpers` as compiled reusable Swift](https://docs.tuist.dev/guides/develop/projects/code-sharing). | Manifest target calls are bounded with SwiftSyntax, literal source paths are honored, Tuist project paths are normalized, self-edges are removed, and helper imports produce a graph diagnostic. |

## Deliberate limits

- ViewDoctor still does not execute Tuist helpers. Doing so would change a fast,
  static scan into project generation with a larger trust and runtime surface.
- Existing findings do not have baseline support yet. Changed-file mode covers
  the immediate agent loop; baseline design remains a separate compatibility
  decision.
- No new rule ships in this release. Workflow reliability comes first because
  a wider rule set would only amplify a bad scope or an inaccurate graph.

The intended loop is now explicit:

```text
coherent edit -> changed scan -> fix -> changed scan once -> stage -> staged gate
```
