# Evaluation: RK3588 DTS Restore

## Scope

Compare:
- Input: dts/vendor/**$board_name.dts
- Base: rk3588(s).dtsi
- Output: /tmp/$board_name.restored.dts

## Metrics

### 1. Build Validity (20)
- DTS compiles with dtc
- No unresolved references

### 2. Delta Correctness (40)
- No SoC-level nodes incorrectly emitted
- Board-level nodes correctly extracted
- Disabled nodes not included

### 3. Semantic Fidelity (40)
Compare merged tree (base + restored) with input:

Must match:
- enabled nodes
- board devices
- resource bindings
- graph connections
- assigned-clocks

Ignore:
- reserved-memory
- thermal-zones
- OPP
- chosen/memory

## Output

Return:

- total score (0–100)
- per-metric breakdown
- list of errors:
  - missing nodes
  - extra nodes
  - mismatched properties
