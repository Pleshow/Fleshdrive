# Rendered late-rush performance profile

Measured: 2026-08-22 07:02:42 UTC  
Version: `0.1.0-playtest.1`  
Renderer: Forward+ / NVIDIA GeForce GTX 1650 with Max-Q Design

| Metric | Result |
| --- | ---: |
| Sampled frames | 900 |
| Live enemies | 141 |
| Average frame time | 16.67 ms |
| p95 frame time | 18.54 ms |
| p99 frame time | 24.68 ms |
| Peak frame time | 34.63 ms |
| Frames above 25 ms | 9 |
| Maximum simultaneous VFX | 4 |
| Profile result | PASS |

The profile advances the encounter director to the ten-minute late-game state,
freezes time progression, triggers a rush and samples the rendered scene. Enemy
population was not reduced to meet the frame-time target. The machine-readable
local result remains in the git-ignored `Reports/rendered_performance_profile.json`.
