# Research report: destination-native launch writing

Timestamp: 2026-08-28, Europe/Madrid

## Executive summary

Recent evidence does not support mechanical "humanization" rules. A June 2026
study of 25 million Hacker News and Reddit comments found that surface features
which distinguish generated text did not predict which human comments were
accused of being generated. Accusations increasingly act as social gatekeeping
around perceived authenticity. The useful response is stronger evidence and a
specific point of view, not detector evasion.

Swift community threads from June and July show the practical version of this
problem. Compressed promotional copy built from claims and adjectives drew an
"AI slop" response. Posts that named a real implementation, current limitation,
and precise feedback question gave readers something technical to answer.

## Method

- Date window: June-August 2026, with current platform guidance where needed.
- Sources: research paper, current Swift community threads, Product Hunt's
  launch guidance, and a July 2026 clear-writing field note.
- Evaluation: recency, direct relevance, observable community response, and
  actionable guidance for GitHub, Reddit, Product Hunt, product pages, and
  plugin listings.

## Findings

### 1. Do not optimize for detector tells

The June study found a more than tenfold rise in pejorative accusations and
reported that statistically distinguishing prose features did not predict which
human text was accused. Treat the complaint as a credibility and belonging
signal. Restore situated facts, choices, limits, and a reason for the post.

Source: [Miklian and Katsos, June 10, 2026](https://arxiv.org/abs/2606.12073).

### 2. Swift readers reward implementation detail

The June r/swift thread contains both sides: a multi-paragraph architecture
pitch received an explicit request for one concrete example, while compact
project updates that named Metal, IndexStore, concurrency checks, or module
boundaries gave readers technical hooks. The July thread shows the same split:
an adjective-heavy component-library blurb was called promotional and
AI-sounding, while a local network debugger post named protocols, current scope,
and four specific feedback questions.

Sources: [June Swift projects thread](https://www.reddit.com/r/swift/comments/1tveqcp/whats_everyone_working_on_this_month_june_2026/),
[July Swift projects thread](https://www.reddit.com/r/swift/comments/1ul6wft/whats_everyone_working_on_this_month_july_2026/).

### 3. Product Hunt needs a separate maker layer

Product Hunt recommends simple language, a first maker comment, a clear target
user, and a request for feedback rather than votes. The listing should support
a quick product decision; the first comment can explain motivation and the next
open product decision.

Source: [Product Hunt launch preparation](https://www.producthunt.com/launch/preparing-for-launch).

### 4. Signal per word beats artificial informality

A July 2026 writing note recommends progressive disclosure, front-loading the
point, plain verbs, active voice, and owner editing. This aligns with the
community evidence: clarity helps, but generic polish without a real decision
does not create a credible voice.

Source: [Zapier, July 19, 2026](https://zapier.com/blog/remove-ai-slop-from-writing/).

## Channel decisions

- GitHub: command, output, architecture, scope, requirements, limitations.
- Product page: answer the search intent first; one action; matching structured
  and visible claims.
- Reddit: disclose maker status; give useful technical detail before the link;
  ask one narrow architecture/rule-design question.
- Product Hunt: outcome tagline, short description, verified maker comment,
  feedback request, no upvote request.
- OpenAI: write a behavioral contract covering trigger, local execution, data
  boundary, failure behavior, and distinct tests.

## Unresolved questions

- Which fourth rule produces enough value without warning fatigue?
- Do Swift teams want dependency-direction checks in the same CLI or as a
  separate rule pack?
