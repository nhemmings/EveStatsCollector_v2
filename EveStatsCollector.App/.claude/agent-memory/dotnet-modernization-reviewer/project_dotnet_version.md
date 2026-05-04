---
name: .NET / C# version in use
description: Confirms the project targets net10.0 with nullable + implicit usings; C# 12 primary constructors and ConfigureAwaitOptions.SuppressThrowing are in active use.
type: project
---

EveStatsCollector targets `net10.0` (Worker SDK), with `Nullable=enable` and `ImplicitUsings=enable`. C# language version is the implicit default (latest, currently 13).

**Why:** Determines which modernisation suggestions are valid — `ConfigureAwaitOptions` (.NET 8+), `[LoggerMessage]` source generator (.NET 6+), `ValidateOnStart()` (.NET 8+), collection expressions / primary constructors (C# 12), `required` members (C# 11), and `FrozenDictionary` (.NET 8+) are all available without conditional notes.

**How to apply:** When reviewing, assume every modern feature in the rule set is on the table. Do not bother flagging "this requires C# 11" caveats. Confirmed-modern choices already in code: `Host.CreateApplicationBuilder`, `builder.Services.AddSerilog`, `ConfigureAwaitOptions.SuppressThrowing`, primary constructor on `Worker`, per-signal `AddOtlpExporter()` (the latter avoids a current `UseOtlpExporter()` namespace bug).
