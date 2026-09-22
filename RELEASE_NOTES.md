# Crucible v0.2.0

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

Release assets are factory-built: a macOS arm64 binary and a Linux x86_64 binary, a `SHA256SUMS`, and one detached
signature. The macOS binary is signed with a Developer ID and notarized — it opens without the unidentified-
developer prompt on first online run. Verify the checksums, then verify the signature:

```
sha256sum -c SHA256SUMS
ssh-keygen -Y verify -f SHA256SUMS.allowed_signers -I tower@thedarkfactory.co.uk -n df-release -s SHA256SUMS.sig < SHA256SUMS
```

There are no other binaries. Anyone who wants to build their own reads INSTALL.md and builds from source.

## Licence

AGPL-3.0, with a commercial exception. The AGPL edition refuses to emit under any other licence. You own your
output — one carve-out: you may not build a competing factory. The commercial licence drops the AGPL terms and
adds support.

## Not in this release

Reciprocity, the Palais market, the reproduction bench, credits — the economy layer. That is the next phase. This
release exchanges provenanced claims. It does not yet settle them.
