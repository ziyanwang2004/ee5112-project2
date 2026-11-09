# V4: anytime refinement and tangent-aware STOMP

V4 is isolated from V1/V2/V3. The mounted workcell, endpoints, primary
objective, direction projector and final collision/tilt gates are retained.
The new algorithm features are independently switchable:

- `baseline`: ambient samples with V3 first-feasible stopping.
- `anytime`: the same primary search, then feasible-only quality refinement.
- `tangent`: 75% tangent / 25% ambient antithetic pairs, still projected,
  with first-feasible stopping.
- `combined`: tangent sampling plus feasible-only refinement.

The secondary quality score is joint length + 5*smoothness + a soft 45 mm
clearance preference. The hard gate stays 35 mm and Task 5 tilt <=5 degrees.
Refinement cannot overwrite a feasible incumbent with an invalid or worse
secondary score. Search objective and refinement score are recorded separately.

Protocol: [TASK45_V4_PROTOCOL.md](../../docs/TASK45_V4_PROTOCOL.md).
Use fresh MATLAB R2023b sessions when switching source versions.

```matlab
addpath('scripts')
r = run_task45_v4('task5','combined',5500,newRunRoot);
audit = verify_task45_v4(newRunRoot);
```

Development and formal results must be distinguished. Algorithm changes are
not claimed to improve success, time or quality until paired results and
independent verification support that particular claim.
