# CRUCIBLE

🌐 [简体中文](README.zh-Hans.md) · [Français](README.fr.md) — quick guides: [中文](GUIDE.zh-Hans.md) · [FR](GUIDE.fr.md). Translations; the English text governs.

A factory that turns a written specification into Ada/SPARK with a machine-checked proof, refuses to deliver
anything it could not prove, and — in this release — can send what it could not close up to a networked tower and
take down what others have.

**What this release is, plainly.** You write a specification in prose. Crucible reads it, decides whether it is
fit to forge, designs the unit, writes the contract and the body through a language model you point it at, and
hands both to AdaCore's prover. If the prover closes every check, you get the unit and a receipt you can
re-derive. If it does not, you get a refusal that names the stage it stopped at, and the case is *parked*, not
thrown away. A parked case can be packed into a catalog and sent up the tower, where another factory may take it.

**It does not finish most of the time yet.** On the sheets we have measured it on, the whole pipeline ends in a
proved unit in a minority of runs — figures below, ours, unflattering. What we claim is narrower and we think
more useful: **when it says proved, the prover said so; when it cannot, it says why; and what crosses the network
is a signed, provenanced claim, never a silent trust.**

CRUCIBLE is itself written the way it builds: the parts that make decisions are proven SPARK packages, and
every one of them was produced by the factory from prose, not hand-written.

---

## The two guards

**Proof.** A model may propose. It is never believed. `gnatprove` decides, and a gate rejects the usual ways of
faking a pass — `SPARK_Mode Off`, `Warnings Off`, an assumed body, a contract that says nothing.

**Determinism.** A verdict you cannot reproduce is not a verdict. The checks run again and give the same answer,
or they do not count.

---

## What the widened form covers

The first release could only emit a narrow house form. This one is **widened** to ordinary SPARK as the manuals
teach it. The emitter may write:

- quantified expressions in contracts (`for all`, `for some`);
- constrained arrays;
- `Contract_Cases`;
- discriminated record results;
- loop bodies carrying `pragma Loop_Invariant` and `pragma Loop_Variant`;
- for "the number of…" specifications, one recursive counting helper, in a fixed shape.

When a round leaves loop checks unproved, the residue is classified (omission, idiom, inductive strength, hard
frame) and exactly one diagnosis goes back to the model. Two idioms are rewritten deterministically and cost no
round: `'Old` inside a loop invariant becomes `'Loop_Entry`, and `exists |` becomes `for some =>`.

The widening opens no new way to fake a proof. `pragma Assume`, `SPARK_Mode Off`, `Annotate` and
`Warnings Off` are refused whether the specification asks for them or not.

## What parks by design

Some classes of specification **park by design**. Crucible does not spend its round budget on them and does
not pretend; it says which class it met.

| class | what it is | what you get |
|---|---|---|
| **Hard frame** | in-place mutation of an array or record, where the proof needs a frame condition over everything *not* touched | PARKED, with the diagnosis |
| **Floating point** | anything whose proof turns on exact floating-point behaviour | REFUSED at intake, rather than failed at proof |
| **Outside what SPARK can prove here** | unbounded heap; I/O inside a decider; fixed-point conversion; concurrency beyond Jorvik | REFUSED at intake, or routed to an edge labelled *built, not proved* — never presented as proved |
| **A specification built to exhaust the prover** | huge quantifier nests, deep recursion | STOPPED as UNMEASURED; the run is never extended |

A parked case is not a failure of yours. It is kept, with what was measured, so that it can be worked on — or
sent up the tower for someone else to close.

## What we measured, and what it does not show

**The examples were in the model's training data.** The planner model we used — a qwen3.8-27b model — was
fine-tuned on a corpus that includes AdaCore's `spark-examples`. FLOOR 1, the example we quote most
(`Linear_Search`), is from that tree: **the model had seen it.** A pass on FLOOR 1 shows the pipeline works end
to end. It does **not** show that the model can design a proof it has never met. We have not yet published a
result on unseen code, and until we do, read every FLOOR figure as a floor.

Measured on our own machines, 2026-09-19, through the shipped door with all three rails, with a qwen3.8-27b
model:

| what | result |
|---|---|
| Decompose stage alone (FLOOR 1 + Count_Above) | 50 of 50, after a prompt fix; 32 of 50 before it |
| Whole pipeline, prose to proved unit, first A/B (stopped early at 19 of 40 runs) | 3 of 10, and 3 of 9 |
| Whole pipeline on Count_Above | 2 of 8 — **and one of those two was weaker than its specification** |
| Whole pipeline, later 30-run A/B of one candidate improvement | 33% against 43%; inconclusive, not adopted |

The main stopper is contract emission: the model runs out of rounds before it writes a contract the prover
accepts.

Re-checked on the release binary (macOS arm64, `crucible-agpl` `04ca4c6c…`, pinned toolchain, 2026-09-22): a
spot-check of whole-pipeline forges gave FLOOR 1 **three of four** proved and Count_Above **zero of two** — the
same minority the table shows, now on the shipped binary.

A stranger's-machine run, done for the first time on 2026-09-22: a clean `ubuntu:24.04` container holding only
the shipped Linux x86_64 binaries (`crucible-agpl` `89e93449…`) and a public toolchain — nothing copied from our
machines — ran the pipeline end to end against a public model on localhost. **Zero of seven** runs reached a
proved unit. The pipeline runs on a clean machine with nothing of ours; finishing a proof reliably needs the
model it was tuned against, which we do not ship.

**A proof is only as good as its contract — and nothing yet checks the contract against your specification.**
Twice in two days the model wrote a contract *weaker* than the sheet asked for. One passed every gate we have,
including the check for contracts that say nothing. The other dropped a single `not`, which would have left a
case pending for ever; a syntax error elsewhere caught it by luck. A check that compares a contract's strength
to a ground truth is designed and not built. **Until it is, read the emitted contract yourself.** "Proved"
means the body meets the contract Crucible wrote. It does not mean the contract is the one you meant.

---

## The exchange

This release is **networked**, and the transport is real. A factory that parks a case can pack it into a signed
catalog and send it up a tower rail; another factory pulls the index, fetches the catalog, and imports it. The
path is proven end to end over the public network as of **2026-09-21**: a certified catalog was packed on one
machine, certified by the admitter on a second, placed on the reef `/rail`, and pulled and imported **`accepted`**
by a third — digest matched, forward-only against the base held. Nothing was copied by hand; every door was named
by the tool.

What is true today, and what is not:

- **What crosses is a provenanced CLAIM, not a proof.** The provenance record attests the catalog is
  **well-formed and came from a known packer** — it does **not** attest that the components inside were proved on
  the receiver's terms. **A shared catalog is a CLAIM until it is reproduced.** The reproduction bench that turns a
  shared claim into a verified entry is **designed and not built** — it is the first work of the economy layer.
- **What leaves your machine.** Only what the factory measured or emitted. No absolute path, no hostname, none
  of your own prose. Every withheld field is *named*, with its reason.
- **Nothing in the executable listens.** An external `lsof` scan of the running binary — macOS arm64
  (`04ca4c6c…`) and Linux x86_64 (`89e93449…`) — found **zero sockets in LISTEN state** at handshake, during
  operation, and at drain, four of four measured rows on each, established from the kernel's view rather than the
  binary's own say-so.
- **Forward-only, and integrity-checked.** A catalog below the running version, or whose digest does not match
  its receipt, or sealed by an untrusted key, is refused and recorded — verified across 35 probe cases on the
  import edge.

The economy layer is **not running**. The Palais de Problème market — claiming a case for a
bounty, the reproduction bench that verifies a submitted proof, Bawbee credits, sharer standing, reciprocity
(a factory that sends none pulls nothing) — is **v0.3**, the next phase, and no part of it runs today. This
release exchanges provenanced claims; it does not yet settle them. When those pieces ship they will say so in
their own ledger rows (a Bawbee is a best-effort claim with no issuer yet), and enrolment for *solving* cases
will require signing the CLA (sending them will not).

---

## The model

Crucible does not ship a model and does not need ours. The `model` line of `config/rail.conf` takes any endpoint
you run. Install ollama and pull a model for your platform — `ollama pull qwen3-coder:30b` is the public model
this release was demonstrated with — and point Crucible at it on localhost; the rail speaks plain HTTP to a local
endpoint by design, so nothing leaves the box but what you send. The house figures above were measured with a
qwen3.8-27b model tuned for the dialect.

---

## Get it

This tagged release ships factory-built, signed tarballs — one per platform — plus one checksum file:
`crucible-v0.2.1-macos-arm64.tar.gz`, `crucible-v0.2.1-linux-x86_64.tar.gz`, and
`RELEASE_TARBALLS.sha256`. Each tarball unpacks to `crucible-v0.2.1/` — a working directory with a
`crucible-launch.sh`, `bin/`, `config/` and `tower/` — that connects to the tower out of the box. The
macOS binary is Developer-ID signed and notarized (a bare CLI tool, so it cannot be stapled; clear the
quarantine attribute if a browser download is blocked). Check the download, unpack, then verify the
signed set inside:

```sh
sha256sum -c RELEASE_TARBALLS.sha256
tar xzf crucible-v0.2.1-<platform>.tar.gz && cd crucible-v0.2.1
sha256sum -c SHA256SUMS
ssh-keygen -Y verify -f SHA256SUMS.allowed_signers -I tower@thedarkfactory.co.uk -n df-release -s SHA256SUMS.sig < SHA256SUMS
```

Then point your MCP host at `crucible-launch.sh` (see `CONNECTING.md`). There are no other binaries.
Anyone who wants to build their own network reads `INSTALL.md` and builds from source.

## Build it

Both editions build from the same source:

```sh
CRUCIBLE_EDITION=agpl       gprbuild -P crucible.gpr -p     # bin/crucible-agpl
CRUCIBLE_EDITION=commercial gprbuild -P crucible.gpr -p     # bin/crucible-commercial
```

Each binary answers MCP over stdio and reports its own edition in the `initialize` result, so you can always
tell which one you are talking to.

Each binary is also pinned to the base tower bundle it was built with: `tower/base.bundle`, by the SHA-256 of its
first line. Start the door from this directory. On every `forge` call it measures that file before it reads your
sheet, and refuses — `"stopped_at":"tower"` — if the file is missing or is not the one it was built with. Editing
the bundle cannot help; restore it or rebuild. `INSTALL.md` has the full build (the two stamp tools run first)
and what each refusal means.

## Prove it

```sh
gnatprove -P crucible.gpr --level=2 --mode=all --checks-as-errors=on --warnings=error -j0
```

Zero unproved checks is the only passing result. Do not take our word for it: the prover is AdaCore's, publicly
available, and it does not care who wrote the code.

---

## Licence and contributions

CRUCIBLE is **AGPL-3.0-or-later** (`LICENSE`, the FSF's unmodified text). A commercial licence over the same
source is available on request — see `COMMERCIAL-LICENCE.md`. No legal wording in this repository is drafted by
us.

Contributions are welcome under the Harmony Contributor License Agreement v1.0, licence variant, Outbound
Licence Option Five, governed by the laws of England and Wales. It is a licence, not an assignment: you keep your
copyright, and your contribution stays AGPL. See `CLA.md` and `CONTRIBUTING.md`.

The AGPL edition emits **AGPL only**. Ask it to emit under any other licence and it refuses. That is a statement
of licence rather than a lock: one tree builds either edition, and anyone may build the commercial one — the
refusal tells you what this binary is, it does not stop you.

---

## Honest status

- **Produced by an agentic AI system**, with a human holding the gate and reading before release.
- **It finishes a minority of runs.** See the table. We would rather you knew.
- **The examples we quote were in the model's training data.** See above.
- **A proof establishes that the code meets the contract we wrote. It cannot establish that the contract is
  the right one**, and we have caught our own pipeline writing the wrong one. The check for that is not built.
- **What crosses the network is a CLAIM until reproduced.** The transport is proven live; the bench that would
  verify a shared claim on your terms is not built. Do not treat an imported catalog as proved code.
- **The chain of custody is MEASURED, not ATTESTED.** The machine that re-proves each core is separate from the
  one that forged it, and signs a receipt there — but the forging seat still holds administrative rights on the
  prover. Until that is removed, "measured" is the honest word.
- The AGPL edition's refusal to emit under any other licence is **a statement of licence, not a lock**.
