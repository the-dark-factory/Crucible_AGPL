# CRUCIBLE

🌐 [简体中文](README.zh-Hans.md) · [Français](README.fr.md) — quick guides: [中文](GUIDE.zh-Hans.md) · [FR](GUIDE.fr.md). Translations; the English text governs.

A factory that turns a written specification into Ada/SPARK with a machine-checked proof, and
refuses to deliver anything it could not prove.

CRUCIBLE is itself written the way it builds: the parts that make decisions are proven SPARK
packages, and every one of them was produced by the factory from prose, not hand-written.

---

## The two guards

**Proof.** A model may propose. It is never believed. `gnatprove` decides, and a gate rejects the
usual ways of faking a pass — `SPARK_Mode Off`, `Warnings Off`, an assumed body, a contract that
says nothing.

**Determinism.** A verdict you cannot reproduce is not a verdict. The checks run again and give the
same answer, or they do not count.

---

## What is in here

| path | what it holds |
|---|---|
| `src/` | The Ada. The judges are expression-function specifications: facts in, one verdict out, no I/O. |
| `src/edition-agpl/`, `src/edition-commercial/` | The edition, compiled in — never a runtime flag. |
| `crucible.gpr` | The project file. `CRUCIBLE_EDITION` selects the edition. |
| `cla/` | The unmodified Harmony CLA templates and the signature list. |

The judges decide intake, decomposition, contract emission, the prover's verdict, vacuity, seam
coherence, admission, provenance, the sole interface, and the edition's licence. Each is admitted
off-seat: re-proved on a separate machine, with a receipt signed there.

---

## Build it

Both editions build from the same source:

```sh
CRUCIBLE_EDITION=agpl       gprbuild -P crucible.gpr -p     # bin/crucible-agpl
CRUCIBLE_EDITION=commercial gprbuild -P crucible.gpr -p     # bin/crucible-commercial
```

Each binary answers MCP over stdio and reports its own edition in the `initialize` result, so you
can always tell which one you are talking to.

## Prove it

```sh
gnatprove -P crucible.gpr --level=2 --mode=all --checks-as-errors=on --warnings=error -j0
```

Zero unproved checks is the only passing result. Do not take our word for it: the prover is
AdaCore's, publicly available, and it does not care who wrote the code.

---

## Licence and contributions

CRUCIBLE is **AGPL-3.0-or-later** (`LICENSE`, the FSF's unmodified text). A commercial licence over
the same source is available on request — see `COMMERCIAL-LICENCE.md`. No legal wording in this
repository is drafted by us.

Contributions are welcome under the Harmony Contributor License Agreement v1.0, licence variant,
Outbound Licence Option Five, governed by the laws of England and Wales. It is a licence, not an
assignment: you keep your copyright, and your contribution stays AGPL. See `CLA.md` and
`CONTRIBUTING.md`.

---

## Honest status

- **Produced by an agentic AI system**, with a human holding the gate and reading before release.
- The AGPL edition's refusal to emit under any other licence is **a statement of licence, not a
  lock**. One source tree, dual-licensed; anyone can build either edition. The refusal tells an
  honest user what they are entitled to.
- A proof establishes that the code meets the contract we wrote. It cannot establish that the
  contract is the right one. Where we have found our own contracts wanting, we have said so.
