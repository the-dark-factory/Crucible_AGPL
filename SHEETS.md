# The specification sheet — what Crucible's intake gate actually reads

**Every claim in this file was verified by running the shipped v0.2.1 binary**, one test sheet per
rule, each gap triggered in isolation. Worked examples are in `examples/`.

Crucible's front gate (`intake_check`, and the first stage of `forge`) does **not** read free prose.
It reads a **line-oriented sheet** whose first word decides what each line is. A sheet that does not
use these keywords is refused with `operation_count: 0`, whatever it says in English.

## The five line kinds

| First word | Kind | Meaning |
|---|---|---|
| `delivers:` | deliverable | what the unit is for. **At least one required.** |
| `function <Name> ...` | operation | an operation. `<Name>` must start with a letter. |
| `procedure <Name>` / `operation <Name>` | operation | **counts as an operation but is REFUSED** — see below |
| `type <Name>` | type definition | defines a name so it can be used as a parameter or return type |
| `post:` | postcondition | what must be true of the result |
| anything else | commentary | ignored |

Leading spaces and tabs are allowed. A line is at most 1024 characters; a sheet at most 512 lines.

## The five gaps — a sheet may be forged only when all five are clear

| Gap | Cleared by |
|---|---|
| `no_deliverable` | at least one `delivers:` line |
| `no_operations` | at least one operation line |
| `operations_not_functions` | **every** operation is a `function` — `procedure` and `operation` are refused |
| `contracts_incomplete` | **every** operation is followed by a `post:` line before the next operation |
| `vocabulary_unsound` | every type name used is either built in or defined by a `type` line |

`may_forge` is returned only when the gap count is zero. Anything else returns `refused` with the
gaps named.

### Operations must be functions
`procedure Do_It (A : Integer)` is counted as an operation and then refused with
`operations_not_functions`. Crucible forges functions with postconditions; a procedure has no result
to state a postcondition about. Express the work as a function returning its outcome.

### A postcondition belongs to the operation above it
`post:` attaches to the nearest preceding operation. An operation with no `post:` before the next
operation raises `contracts_incomplete`. Several `post:` lines may follow one operation.

### Type names must be known or defined
A name is *used* when it appears after a colon (a parameter type) or after `return`. These six are
built in and need no declaration:

```
Integer   Natural   Positive   Boolean   Character   String
```

Any other name must be defined by a `type <Name>` line anywhere in the sheet. An undefined name
gives `vocabulary_unsound`, and the refusal names the offender:

```json
{"verdict":"refused","gaps":["vocabulary_unsound"],
 "undefined_name_count":"1","first_undefined":{"line":"2","name":"Widget"}}
```

## A sheet that passes

```
delivers: Saturating_Add
function Saturating_Add (A, B : Integer) return Integer
post: saturates to Integer'Last on overflow and Integer'First on underflow, else equals A + B
```

```json
{"verdict":"may_forge","operation_count":"1"}
```

## Using a type you define

```
delivers: Thing
type Widget
function F (A : Widget) return Integer
post: returns something
```

## ⚠ What the sheet does NOT yet do — read this before trusting a result

**Nothing compares the contract Crucible produces back to your sheet.** The `post:` line is prose;
the model reads it and authors the Ada `Pre`/`Post`. If the model writes a contract narrower than
you asked for — most easily by adding a `Pre` that excludes the hard cases — the unit can be proved,
pass the vacuity battery, and still not mean what your sheet said.

This is not hypothetical. Measured 2026-09-24 on this binary, from the passing sheet above, the
model produced:

```ada
function Saturating_Add (A, B : Integer) return Integer
  with Pre  => (if B > 0 then A <= Integer'Last - B else A >= Integer'First - B),
       Post => (... elsif A > 0 and then B > 0 then Result = Integer'Last ...);
```

The `Pre` forbids overflow — the whole point of a saturating add — making its own `Post` saturation
branches unreachable. It proved clean and the vacuity battery graded it meaningful.

**So: read the contract Crucible emits. Do not take a proof as agreement with your sheet.** Writing
the hard cases explicitly into your `post:` line makes drift easier to spot; it does not prevent it.
A contract-fidelity check is owed work.

## Calling the door directly

The door speaks JSON-RPC over stdio, **one compact JSON object per line**. Pretty-printed
multi-line JSON is rejected by the frame decider with `-32700`.

```sh
printf '%s\n' \
 '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"you","version":"1"}}}' \
 "$(jq -Rsc '{jsonrpc:"2.0",id:2,method:"tools/call",params:{name:"intake_check",arguments:{sheet:.}}}' examples/saturating_add.sheet)" \
 | ./crucible-launch.sh
```
