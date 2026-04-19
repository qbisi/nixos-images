````markdown
# Bootstrap Plan: Restore RK3588 Device Tree from Vendor DTS Dumps

## Goal

Re-implement these two tools around one consistent evaluation pipeline:

- `tools/dts/clean_rk3588_dump.py`
- `tools/dts/benchmark_rk3588_dump_cleanup.py`

The end-to-end goal is to start from an original vendor DTS, derive a dumped DTS by compiling and decompiling it, restore a cleaner board DTS from that dump, and then compare the restored DTS against the original vendor DTS.

Core flow:

- Input 1: `vendor.dts` (original vendor board DTS)
- Derived intermediate: `dumped.dts` (produced by compiling and then decompiling `vendor.dts`)
- Output: `restored.dts` (a minimal board-level DTS reconstructed from `dumped.dts`)
- Final comparison target: compare `restored.dts` against `vendor.dts`

The output must:

- Include only `rk3588.dtsi` or `rk3588s.dtsi`
- Represent **board-level deltas only**
- Be **compilable**
- Be **minimal and maintainable**
- Not be a DT overlay (`/plugin/;`), but a normal board `.dts`

---

## 1. Assumptions

### 1.1 SoC Detection

Use a simple heuristic:

- If node `pcie@fe150000` exists → use `rk3588.dtsi`
- Otherwise → use `rk3588s.dtsi`

---

## 2. Scope Definition

### 2.1 What to Restore

Only extract **board-level deltas**:

#### Enabled Nodes
- Nodes with `status = "okay"`

#### Resource Bindings
- `pinctrl-*`
- `gpios`
- `*-supply`
- `clocks`, `clock-names`
- `resets`, `reset-names`
- `phys`, `phy-names`
- `interrupts`, `interrupt-parent`

#### Connectivity / Topology
- `ports`
- `endpoint`
- `remote-endpoint`

#### Board Devices
- I2C/SPI devices
- sensors, codecs, panels, type-c controllers, etc.

#### Other
- `assigned-clocks*` (preserve exactly)
- top-level:
  - `model`
  - `compatible`

---

### 2.2 What to Ignore

Always exclude:

- `status = "disabled"` nodes
- `reserved-memory`
- `/memreserve/`
- `memory`
- `chosen`
- `thermal-zones`
- `operating-points-v2`
- OPP tables
- SoC-level policy/config nodes

---

### 2.3 Special Rules

#### aliases
- Do NOT emit
- Use only as **reference name hints**

#### fiq-debugger
- Treat as SoC-level
- Only emit if there is a delta from base

#### thermal-zones / OPP
- Ignore completely

#### assigned-clocks*
- Preserve as-is

#### reserved-memory
- Ignore completely

---

## 3. Output Format

Always generate:

```dts
/dts-v1/;
#include "rk3588.dtsi"
````

or:

```dts
/dts-v1/;
#include "rk3588s.dtsi"
```

Then:

* Minimal `/ {}` root
* `&node { ... }` patches
* New board devices under correct parent

---

## 4. Pipeline

---

### Phase A: Acquire Dumped Input from Vendor DTS

Input: `vendor.dts`

Produce the dumped form used by the cleanup tool:

1. compile `vendor.dts` -> `vendor.compiled.dtb`
2. decompile `vendor.compiled.dtb` -> `vendor.dumped.dts`

This dumped DTS is the effective input to the restoration pipeline.

Artifacts at this phase:

- `vendor.dts`
- `vendor.compiled.dtb`
- `vendor.dumped.dts`

---

### Phase B: Parse Dumped Input

Input: `vendor.dumped.dts`

Build AST / IR:

* node path
* node name + unit address
* properties
* phandle references
* graph connections

Also extract:

* `aliases`
* all `status = "okay"` nodes
* all device nodes
* all graph nodes

---

### Phase C: Detect Base SoC

```text
if exists("pcie@fe150000"):
    base = rk3588
else:
    base = rk3588s
```

---

### Phase D: Load Base DTSI

* Parse `rk3588.dtsi` or `rk3588s.dtsi`
* Build indices:

  * path
  * name + unit-address
  * compatible
  * reg

---

### Phase E: Node Matching

Match input nodes to base nodes:

Priority:

1. full path
2. name + unit-address
3. parent + reg
4. compatible + bus context

Classify nodes:

* `matched_base_node`
* `new_board_node`
* `unresolved_node`

---

### Phase F: Apply Ignore Rules

Drop nodes if:

* disabled
* reserved-memory
* thermal / OPP
* memory / chosen / memreserve
* large SoC policy blocks

---

### Phase G: Extract Deltas

For each matched node:

#### Status

* If `status = "okay"` → emit
* Otherwise → ignore (bootstrap rule)

#### Properties (keep only):

* pinctrl / gpio / supply
* clocks / resets / phys
* interrupts
* assigned-clocks*
* graph (ports/endpoints)
* board config fields (e.g. `dr_mode`, `phy-mode`)

#### Delta Rule

* If identical to base → skip
* If different → emit

#### fiq-debugger

* Emit only if delta exists

---

### Phase H: Add Board Nodes

For nodes not in base:

Typical:

* i2c devices
* spi devices
* panel / codec / sensor
* regulators (board-level)

Rules:

* Attach under matched parent
* Keep essential properties
* Drop if only contains ignored content

---

### Phase I: Restore Graph

Handle:

* `ports`
* `endpoint`
* `remote-endpoint`

Rules:

1. Preserve graph if node is kept
2. Try to resolve endpoints to:

   * restored nodes
   * base nodes
3. If unresolved:

   * keep reference
   * mark as unresolved (optional)

---

### Phase J: Reference Naming

Priority:

1. base labels
2. aliases
3. derived stable names

Fallback allowed (bootstrap):

* internal generated names

---

### Phase K: Emit Output

Structure:

```dts
/dts-v1/;
#include "rk3588.dtsi"

/ {
    model = "...";
    compatible = "...";
};

&node {
    status = "okay";
    ...
};

&i2cX {
    status = "okay";

    device@xx {
        compatible = "...";
        reg = <...>;
        ...
    };
};
```

Ordering (recommended):

1. root
2. pinctrl / regulators
3. controllers
4. board devices
5. graph nodes

---

## 5. Internal IR (Recommended)

### NodeIR

```text
path
name
unit_addr
props
children
phandle
status
compatible
matched_base_path | null
classification
```

### PropertyIR

```text
name
raw_value
normalized_value
kind
```

Kinds:

* scalar
* string
* array
* phandle-ref
* bytes
* string-list
* graph-ref

---

## 6. Bootstrap Rules (Hard Constraints)

1. `status = "okay"` → treat as board enable
2. ignore `status = "disabled"`
3. ignore reserved-memory
4. ignore thermal / OPP
5. ignore chosen / memory / memreserve
6. aliases only for naming
7. fiq-debugger → only delta
8. assigned-clocks* → copy as-is
9. prefer `&node {}` over full node duplication
10. unmatched bus children → treat as board devices

---

## 7. Out of Scope (Bootstrap)

Do NOT attempt:

* restoring labels exactly
* restoring include hierarchy
* restoring macros
* restoring comments
* perfect graph resolution
* resolving all phandles
* style reconstruction

---

## 8. Tool Contracts

### `clean_rk3588_dump.py`

Purpose:

- Restore a minimal board DTS from a dumped DTS

Primary input:

- `dumped.dts`

Primary output:

- `restored.dts`

Behavior:

- detect RK3588 vs RK3588S
- load the matching base dtsi
- extract board-level deltas from the dumped DTS
- emit a compilable minimal board DTS

### `benchmark_rk3588_dump_cleanup.py`

Purpose:

- Evaluate the cleanup pipeline against original vendor DTS inputs

Primary input:

- either:
  - a board name, resolved as `dts/vendor/**/$board_name.dts`
  - or an explicit DTS path

Primary derived artifacts:

- `vendor.compiled.dtb`
- `vendor.dumped.dts`
- `restored.dts`
- optional merged / normalized intermediate artifacts needed by evaluation

Primary output:

- per-case evaluation results following `EVAL.md`

Behavior:

- compile vendor DTS
- decompile compiled DTB to produce dumped DTS
- run restoration from dumped DTS
- evaluate the result according to `EVAL.md`
- accept either board names or DTS paths as inputs
- keep input resolution efficient for repeated benchmark runs

## 9. Existing Implementation to Reuse

We already have a working implementation under `tools/dts/`. The re-implementation should begin by studying and selectively reusing the current design rather than treating this as a greenfield project.

Current reusable structure:

- thin CLI entrypoints in:
  - `tools/dts/clean_rk3588_dump.py`
  - `tools/dts/benchmark_rk3588_dump_cleanup.py`
- shared conversion pipeline in `tools/dts/lib/converter.py`
- shared data model in `tools/dts/lib/board_model.py`
- shared text/block parsing helpers in `tools/dts/lib/parse.py`
- shared rendering in `tools/dts/lib/render.py`
- shared validation and round-trip helpers in `tools/dts/lib/validate.py`

Reusable design ideas from the current implementation:

- Keep CLI wrappers thin and move the real logic into `tools/dts/lib/`
- Preserve a small intermediate board model (`BoardModel`, `NodeFact`, `OverlayFact`, `UnresolvedFact`)
- Keep parsing, classification, rendering, and validation as separate modules
- Preserve the benchmark artifact pipeline:
  - compile vendor DTS
  - decompile to dumped DTS
  - restore cleaned DTS from the dumped DTS
  - build any extra merged or normalized artifacts only when needed for `EVAL.md` evaluation
- Preserve unresolved reporting so the tool can surface partial coverage instead of failing silently

Rewrite guidance:

- Reuse architecture where it is clean and proven
- Revisit heuristics and extraction rules where the current implementation is too ad hoc or overly hardcoded
- Ignore the existing score system in `tools/dts/lib/score.py` as the benchmark design basis
- Keep the benchmark flow aligned with `EVAL.md`
- Design input resolution around efficient handling of either board names or explicit DTS paths
- Prefer preserving module boundaries even if internal logic is rewritten

## 10. Expected Artifacts

For each benchmark case, the pipeline should produce:

* `input.vendor.dts`
* `input.compiled.dtb`
* `input.dumped.dts`
* `output.restored.dts`

Where:

* `restored.dts` is:

  * minimal
  * board-focused
  * based on rk3588(s).dtsi
  * ready for further refinement

And evaluation should treat:

* `vendor.dts` as the ground-truth reference
* `dumped.dts` as the reconstruction input
* `restored.dts` as the reconstruction result

---

## 11. Evaluation Contract

The benchmark should follow `EVAL.md`, not the legacy scoring helpers.

Metrics:

- Build Validity (20)
  - restored DTS compiles with `dtc`
  - no unresolved references
- Delta Correctness (40)
  - no SoC-level nodes incorrectly emitted
  - board-level nodes correctly extracted
  - disabled nodes not included
- Semantic Fidelity (40)
  - compare merged tree `(base + restored)` with the original vendor DTS
  - must match enabled nodes, board devices, resource bindings, graph connections, and assigned-clocks
  - ignore reserved-memory, thermal-zones, OPP, chosen, and memory

Benchmark output should include:

- total score `(0-100)`
- per-metric breakdown
- list of errors:
  - missing nodes
  - extra nodes
  - mismatched properties

## 12. Benchmark Input Resolution

The benchmark interface should accept:

- a board name like `orangepi-5-plus`
- or a direct DTS path

Resolution rules:

- if the argument exists as a path, use it directly
- otherwise resolve it as `dts/vendor/**/$board_name.dts`
- fail on ambiguous matches
- keep lookup efficient enough for repeated runs and batch evaluation

## 13. Task Definition (for Codex)

> Re-implement `clean_rk3588_dump.py` and `benchmark_rk3588_dump_cleanup.py` around a bootstrap pipeline that takes an original vendor RK3588/RK3588S DTS, derives a dumped DTS by compiling and decompiling it, converts that dumped DTS into a minimal board-level restored DTS by diffing against the corresponding SoC dtsi, and evaluates the result using the `EVAL.md` contract: build validity, delta correctness, and semantic fidelity against the merged `(base + restored)` tree, while ignoring SoC-level policy nodes and runtime artifacts that are explicitly out of scope.

```
```
