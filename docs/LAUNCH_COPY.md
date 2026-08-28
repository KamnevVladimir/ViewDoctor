# ViewDoctor launch copy

These drafts share facts, not paragraphs. Each destination gets the structure
its readers expect.

## Product Hunt

Name: `ViewDoctor`

Tagline: `Catch SwiftUI risks across multi-module Swift repos`

Description:

> ViewDoctor scans a Git diff for repeated SwiftUI body work and task-lifetime
> risks, then attaches ownership from SwiftPM, Tuist, or Xcode modules. It runs
> locally, emits text, JSON, or SARIF, and currently ships three deliberately
> narrow rules.

First comment:

> I wanted a deterministic check I could run after an AI coding pass without
> feeding the repository back to another model.
>
> ViewDoctor now does two things: it maps module ownership from SwiftPM, Tuist,
> and Xcode manifests, then scans the current Git diff for three SwiftUI risks.
> The same result can go to a person as terminal text, an agent as bounded JSON,
> or GitHub code scanning as SARIF. Source stays on the machine.
>
> Version 0.1 is intentionally small. It does not prove performance regressions
> or enforce dependency direction yet.
>
> The next decision is rule coverage. Which deterministic SwiftUI check would
> save you the most review time without creating warning fatigue?

Topics: `Developer Tools`, `Open Source`, `GitHub`

## Reddit / r/SwiftUI

Title:

`I built a local SwiftUI analyzer that maps SwiftPM, Tuist, and Xcode modules before scanning a diff`

Body:

> I wanted a check that a coding agent could run after changing SwiftUI without
> sending the repository through another general review pass.
>
> ViewDoctor first builds a normalized module graph from Package.swift,
> Project.swift, project.pbxproj, and common source folders. It then scans the
> current Git diff and attaches the owning module to each finding.
>
> Example:
>
> ```text
> Modules/Profile/Sources/ProfileView.swift:42:18: warning: VD001 [tuist:Modules/Profile/Profile]: DateFormatter is constructed inside a body property.
> ```
>
> Version 0.1 has three conservative rules: expensive construction, collection
> transformations, and detached tasks inside SwiftUI body evaluation. Output is
> text, JSON, or SARIF. The tool is MIT licensed, has no telemetry, and the
> optional MCP adapter only calls the local CLI.
>
> Repo: https://github.com/KamnevVladimir/ViewDoctor
>
> I am deliberately not adding dozens of style checks. Which SwiftUI pattern
> repeatedly costs review time in a large modular codebase, and what would keep
> that rule from becoming noisy?

Flair: `Promotion` if the community form offers it.

## OpenAI plugin

Display name: `ViewDoctor`

Subtitle: `Check SwiftUI diffs locally`

Description:

> Runs ViewDoctor on changed Swift files, returns exact rule IDs and module
> ownership, and can inspect SwiftPM, Tuist, or Xcode module graphs. Analysis
> stays on the local machine; the plugin does not upload source or guess
> findings when the CLI is unavailable.

## GitHub social preview

Repository description:

`Local SwiftUI diff checks with SwiftPM, Tuist, and Xcode module ownership.`
