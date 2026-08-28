# Contributing

ViewDoctor favors precise, explainable rules over large rule counts.

Before proposing a rule:

1. Describe a concrete SwiftUI failure mode or repeated review cost.
2. Provide a minimal positive fixture and a near-miss negative fixture.
3. Keep the diagnostic deterministic and include a practical remediation.
4. Avoid rules that duplicate compiler diagnostics, SwiftLint style rules, or
   Instruments without adding actionable static evidence.

Run `swift test` before opening a pull request. Never contribute private source,
repository names, absolute paths, or derived examples without permission.

