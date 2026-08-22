# Observed public-playtest protocol

## Session setup

- Use the exact same zipped candidate for every participant.
- First-time player, no coaching, 20–30 minutes available.
- Record hardware, input device, resolution and shader state.
- Ask permission before screen/audio recording.

## Observe without prompting

Record whether and when the player understands movement, manual attack and its
cooldown, biomass/XP, mutation confirmation, dash, Blood Memory, Kinetic Charge,
enemy spawn warnings and the cause of death. Note the first mutation time, run
outcome, crash/softlock, and every point where the player stops or guesses.

After the run, ask what they believed each resource and meter did, what killed
them, which upgrade changed their build most, and what felt unfair or unclear.
Do not explain the intended answer before recording theirs.

## Severity and release rule

- P0: crash, save loss, unrecoverable softlock, cannot start/finish a run.
- P1: frequent unavoidable damage, unreadable lethal telegraph, broken core
  progression, severe sustained performance loss, or a primary control failing.
- P2: confusing but recoverable UX/balance issue.
- P3: polish, copy or low-impact visual issue.

Any P0 or reproducible P1 blocks the next release candidate. Link each fix to a
reproduction, affected build, verification result and regression test when the
behavior can be automated.
