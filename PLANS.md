````markdown
# Bootstrap Plan: Restore RK3588 Device Tree from fdtdump

## Goal

Build an initial pipeline to transform:

- Input: `fdtdump.dts` (decompiled from `/sys/firmware/fdt`)
- Output: `restored.dts` (a minimal board-level DTS)

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

### Phase A: Parse Input

Input: `fdtdump.dts`

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

### Phase B: Detect Base SoC

```text
if exists("pcie@fe150000"):
    base = rk3588
else:
    base = rk3588s
```

---

### Phase C: Load Base DTSI

* Parse `rk3588.dtsi` or `rk3588s.dtsi`
* Build indices:

  * path
  * name + unit-address
  * compatible
  * reg

---

### Phase D: Node Matching

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

### Phase E: Apply Ignore Rules

Drop nodes if:

* disabled
* reserved-memory
* thermal / OPP
* memory / chosen / memreserve
* large SoC policy blocks

---

### Phase F: Extract Deltas

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

### Phase G: Add Board Nodes

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

### Phase H: Restore Graph

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

### Phase I: Reference Naming

Priority:

1. base labels
2. aliases
3. derived stable names

Fallback allowed (bootstrap):

* internal generated names

---

### Phase J: Emit Output

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

## 8. Expected Output

The pipeline should produce:

* `input.fdtdump.dts`
* `output.restored.dts`

Where:

* `restored.dts` is:

  * minimal
  * board-focused
  * based on rk3588(s).dtsi
  * ready for further refinement

---

## 9. Task Definition (for Codex)

> Implement a bootstrap pipeline that converts a decompiled RK3588/RK3588S device tree into a minimal board-level DTS by diffing against the corresponding SoC dtsi, extracting only enabled nodes, board devices, resource bindings, graph connections, and assigned-clocks, while ignoring SoC-level policy nodes and runtime/bootloader artifacts.

```
```
