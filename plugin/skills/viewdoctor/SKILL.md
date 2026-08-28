---
name: viewdoctor
description: Run deterministic SwiftUI and multi-module analysis after editing Swift code, before review, or when an AI-generated change may have introduced performance, task-lifetime, or module-boundary risks.
---

# ViewDoctor

Use ViewDoctor after changing SwiftUI code or module relationships.

## Workflow

1. From the repository root, prefer changed-file analysis:

   `viewdoctor scan . --git-diff --format agent`

2. If the branch has a known base revision, use:

   `viewdoctor scan . --base <revision> --format agent`

3. For a pre-commit check, scan only the index and make warnings fail:

   `viewdoctor scan . --staged --fail-on warning`

4. Read only the returned findings. Fix error and warning findings first.
5. Run the same command once after fixes. Do not repeatedly scan the entire
   repository when changed-file mode is sufficient.
6. Use `viewdoctor graph .` when a finding's module ownership is surprising.

## Rules

- Treat findings as deterministic evidence, not as permission for broad refactors.
- Preserve module dependency direction and ownership.
- Do not upload source code or reports to external services.
- A suppression must include a short code comment explaining why the pattern is
  safe for that call site.
- If the executable is unavailable, report that installation is required; do
  not imitate ViewDoctor findings from memory.
