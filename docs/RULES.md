# Rule reference

## VD001 — expensive construction in `View.body`

SwiftUI can evaluate `body` repeatedly. The rule reports construction of known
reusable Foundation, UIKit, and Core Image helpers in that evaluation path.
Move the object to stable storage, inject it, or cache it outside `body`.

## VD002 — collection work in `View.body`

Reports `map`, `filter`, `sorted`, `reduce`, and related transformations as a
note. Small collections may be harmless. For large or frequently changing
inputs, precompute in the state owner or validate with Instruments.

## VD003 — detached task in `View.body`

`body` is not a task lifetime boundary. Detached tasks also discard actor
context and structured cancellation. Move work to an explicit owner or use the
SwiftUI task modifier with cancellation-aware async code.

