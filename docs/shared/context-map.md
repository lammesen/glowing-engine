# Context & Dependency Map

> Placeholder until inventory completes. Update with Mermaid diagrams covering contexts, LiveViews, external systems, PubSub topics, and adapters. Reference diagram IDs from CODE_REVIEW findings.

## Planned Sections
1. **System Overview Diagram**: NetAuto contexts ↔ Ecto schemas ↔ LiveViews ↔ Routes.
2. **External Integrations**: Cisco sims, Oban queues, PromEx, secrets backends.
3. **State Flow**: LiveView assigns, temporary assigns, streams, Presence/PubSub usage.
4. **Security Boundaries**: Auth pipelines, session/cookie handling, CSP and CSRF notes.

Each section should include:
- Diagram (Mermaid/PlantUML) with anchor IDs.
- Text summary (≤150 words) describing critical dependencies.
- Links back to findings in CODE_REVIEW and ADR decisions.
