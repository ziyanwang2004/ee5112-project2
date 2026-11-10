# V5: adaptive sampling and matched-input-energy control

Five independently selectable strategies retain the mounted UR5 model, PoE,
orientation projector, world/self-collision checks and feasible-only refinement.
`fixed75` retains V4 combined sampling. `fixed50` is the no-feedback ablation
for `adaptive`. `energy_control` matches per-rollout input energy to the fixed75
counterfactual before nonlinear projection. Neither covariance nor actual
post-projection variance is claimed to match.

The adaptive controller only changes the primary-search fraction. It uses
already computed rollout costs and stagnation, adding no random draws or FK.
Refinement uses fixed50 in this arm. Full controller and energy replay is saved.

See [protocol](../../docs/TASK45_V5_PROTOCOL.md). Geometry witnesses are only
for preflight and fixed-state sampling diagnostics, never optimization inputs.
Use fresh MATLAB sessions when switching versions. Course Task 4/5 demonstrations
remain available in V3; V5 is an additional controlled algorithm study.
