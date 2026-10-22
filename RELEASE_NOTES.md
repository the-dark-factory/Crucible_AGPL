# Crucible v0.4.0

In this release a refused or unmeasured `forge`, and a `prove_unit` that does not prove,
come back as MCP errors (`"isError": true`). Internal faults name the stage and the exception, and the door exits
with code 70 when it stops on one. Write failures and rail failures that were silent are now reported.

This is 0.4.0, not 0.3.1, because host programs see the change. The full list is in `CHANGELOG.md`.

## Upgrading a host program

- If your host treats every tool result as success, it will now see errors for refused and unmeasured forges and
  for `not_proved`. Read `structuredContent` as before: it is unchanged. The `isError` field is the only addition.
- A refusal is still the correct answer. Change the specification and ask again. Do not retry the same request.
- If you start the door yourself, treat exit code 70 as an internal fault. Exit code 0 still means end of input.
- If you read `state/spec.ads` or `state/body.adb` after a job, note that the previous job's copies are now kept
  as `state/spec.ads.prev` and `state/body.adb.prev`.
- No configuration change is needed.

## The default model is now `qwen3.8:27b`

`config/rail.conf` now names `qwen3.8:27b` (it was `qwen3-coder:30b`). Why, measured with the release tarball:
- `qwen3.8:27b` reached `done` on the `Negate` sheet (the first forge in `INSTALL.md`) in 7 runs of 10, about 15 s
  each; on the harder `Saturating_Add` sheet, in 1 of 16.
- `qwen3-coder:30b` reached `done` on `Saturating_Add` in 0 of 3, and in 0 of 13 on our v0.3 parity sheets.

These are small samples. `qwen3.8:27b` needs ollama 0.32.12 or newer.

The choice is still yours. Name `qwen3-coder:30b`, or any other model you run, on the `"rail":"model"` line. If you
upgrade and keep your own `config/rail.conf`, nothing changes for you.

## Platforms

Linux first. The Linux x86_64 tarball ships with this release. The macOS arm64 tarball follows once its
binaries are Developer-ID signed and notarised. Until then, macOS users can build from source (`INSTALL.md`).

## The tower: the catalog needs an enrolment

- In 0.4.0 every catalog fetch is signed with your install's own key. The tower serves the catalog only to an
  enrolled install. v0.2.1 fetched without a key; 0.4.0 does not.
- A fresh install forges on the catalog it ships with (`tower/base.bundle`). Its fetch row in
  `state/tower-fetch.jsonl` reads `fetch_failed` until it is enrolled. That is expected, not a fault.
- To enrol, call the `palais.enrol` tool with a codename, then call it again to collect the record. The Dark
  Factory admits members in waves. While a wave is open and has room, approval is automatic; otherwise your key is
  queued for the next wave. `INSTALL.md` ("Enrol") has every step and every answer.
- `palais.enrol` is no longer refused with `no_reef_key_pinned`. The Reef's key is pinned in this build and shipped
  in `config/reef-allowed-signers`.
- `tower/sharer.bundle` is no longer in the tarball. The door fetches it once the install is enrolled.
- You need `ssh-keygen` at `/usr/bin/ssh-keygen` (a fresh Ubuntu does not have it: `apt-get update`, then `apt-get install openssh-client`). The signature check, enrolment and the
  signed fetch all use it.

## Install

`INSTALL.md` has every step. In short:

- **gnatprove** (the prover rail needs it; no compiler is needed): on Linux x86_64, download
  `alr-2.1.0-bin-x86_64-linux.zip` from the Alire releases, unzip it, and run `bin/alr -n install gnatprove=15.1.0`.
  The launcher finds `~/.alire/bin/gnatprove` by itself.
- **ollama:** `ollama pull qwen3.8:27b`. It needs ollama 0.32.12 or newer. Tested with 0.33.2, the ROCm build, on
  an AMD Radeon R9700. The model is named on the `"rail":"model"` line of `config/rail.conf`.
- **First forge:** `INSTALL.md` prints a three-line sheet (`Negate`) and the exact call, with and without an MCP
  host. With `qwen3.8:27b`, 7 runs of 10 reached `done`; the other 3 were refused at `vacuity`, which is a correct
  refusal. A second try usually does it. The delivered package is `Negate_Pkg`. `INSTALL.md` ("If it stops") says
  how to tell a model refusal from a broken install.
- `crucible-launch.sh --check` exits 0 even when the prover rail is `DOWN`. Read its lines.
- A second forge within the hour adds no row to `state/tower-fetch.jsonl` (`rate_limited` on standard error).

## Known limitations

See `CHANGELOG.md`. There are no deadlines yet. A live FLOOR 1 forge with `qwen3-coder:30b` (the earlier
default) may be refused at `fill_body`; the 0.3 build does the same.

---

# Crucible v0.2.1

> v0.2.1 is v0.2.0 with the install made honest: the tarball unpacks into a working directory that
> connects to the tower out of the box, the version string reports itself correctly, a shipped
> launcher starts all three rails, and the verify steps below match what you actually downloaded.

Crucible turns a written specification into Ada/SPARK with a machine-checked proof. It refuses to deliver
anything it could not prove. This release adds the tower: what it cannot close, it sends up; what another
factory could not close, it takes down and re-checks. Nothing in it listens. Every connection is opened by you.

## What it does

You write a specification in prose. Crucible reads it, decides whether to forge it, designs the unit, writes the
contract and the body through a model you point it at, and hands both to the prover. The proof closes and you get
the unit and a receipt you can re-derive. It does not close and you get a refusal that names the stage it stopped
at. The case is parked, not thrown away. A parked case can be packed and sent up the tower. Another factory may
take it.

Crucible is built the way it builds. The parts that decide are proven SPARK. Every one was forged from prose.

## Prove, not generate

The tool that writes the code and the tool that checks it are not the same tool. Crucible writes through a model
you choose and proves through AdaCore's prover. When it says proved, the prover said so. When it cannot, it says
why. What crosses the network is a signed claim, never a silent trust.

We were preparing to launch this when AdaCore released GNAT Foundry. The same conviction: deterministic proof over
AI output. Theirs is a demonstrator — AI driving their formal tools, shown on a traffic light. Crucible is a
shipped factory. It forges an arbitrary specification, refuses what it cannot prove, and its own deciding parts
are proven. It is open. You do not bring proof to its output. It is proof, end to end.

## What is honest

It finishes a minority of runs. The figures are ours and below.

The examples we quote were in the model's training data. A pass on them shows the pipeline works end to end. It
does not show the model can design a proof it has never met.

A proof establishes the code meets the contract we wrote. It does not establish the contract is the one you
meant. The check that compares a contract to your specification is not built. Read the contract yourself.

What crosses the network is a claim until it is reproduced. The bench that would verify a shared claim on your
terms is not built. Do not treat an imported catalog as proved code.

The chain of custody is measured, not attested. The machine that re-proves each core is separate from the one
that forged it, and signs a receipt there. The forging seat still holds rights on the prover. Until that is
removed, measured is the honest word.

## What we measured

Ours, on our machines.

- Spot-check on the release binary: FLOOR 1 three of four, Count_Above zero of two.
- A stranger's-machine run, first time done: a clean container holding only the shipped binaries and a public
  toolchain, nothing copied from us, ran the pipeline end to end. With a public model, zero of seven reached a
  proved unit. The pipeline runs on a clean machine with nothing of ours. Completing proofs reliably needs the
  tuned model, and this release does not ship one.

Read those together. The thing runs anywhere. It finishes rarely without the model it was tuned against, and we
do not hand you that model.

## The model

Crucible ships no model and does not need ours. You set the model in `config/rail.conf`. Any endpoint you run.
Install ollama, pull a model — `qwen3-coder:30b` is the one this release was demonstrated with — and point
Crucible at it on localhost. The rail speaks plain HTTP to a local endpoint by design. Nothing leaves the box but
what you send.

## Get it and check it

Release assets are factory-built, signed tarballs — one per platform — plus one checksum file:

- `crucible-v0.2.1-macos-arm64.tar.gz`
- `crucible-v0.2.1-linux-x86_64.tar.gz`
- `RELEASE_TARBALLS.sha256`

The macOS binary is signed with a Developer ID and notarized. (It is a bare CLI executable, so
Gatekeeper cannot staple a ticket to it; if macOS blocks it on a browser download, clear the
quarantine attribute — `xattr -d com.apple.quarantine bin/crucible-agpl` — or approve it once in
System Settings. `spctl -t execute` reports a bare tool as "not an app" even though the signature is
valid; that is expected for a CLI binary.)

Check what you downloaded, unpack it, then verify the signed set inside:

```sh
# 1. integrity of the download
sha256sum -c RELEASE_TARBALLS.sha256

# 2. unpack, and step into the working directory
tar xzf crucible-v0.2.1-<platform>.tar.gz
cd crucible-v0.2.1

# 3. verify the signed file set inside the tarball (the df-release signature)
sha256sum -c SHA256SUMS
ssh-keygen -Y verify -f SHA256SUMS.allowed_signers -I tower@thedarkfactory.co.uk \
    -n df-release -s SHA256SUMS.sig < SHA256SUMS
```

Step 1 proves the tarball is the one we published. Step 3 proves every file inside it is the one we
signed; a good run prints `Good "df-release" signature for tower@thedarkfactory.co.uk`.

The tarball unpacks to `crucible-v0.2.1/`, holding `crucible-launch.sh`, `bin/`, `config/` and
`tower/`. Point your MCP host at `crucible-launch.sh` — it starts the rails and serves the door from
the right directory — see INSTALL.md and CONNECTING.md. There are no other binaries; anyone who wants
to build their own reads INSTALL.md.

## Licence

AGPL-3.0, with a commercial exception. The AGPL edition refuses to emit under any other licence. You own your
output — one carve-out: you may not build a competing factory. The commercial licence drops the AGPL terms and
adds support.

## Not in this release

Reciprocity, the Palais market, the reproduction bench, credits — the economy layer. That is the next phase. This
release exchanges provenanced claims. It does not yet settle them.
