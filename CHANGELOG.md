# Changelog

All notable changes to Crucible are recorded here. The format follows Keep a Changelog. Version numbers follow
semantic versioning; before 1.0 the middle number changes when behaviour that host programs rely on changes.

## [0.4.0] - 2026-10-19

### Why 0.4.0

This release is 0.4.0, not 0.3.1, because it changes behaviour that host programs rely on.

- A refused or unmeasured `forge` now comes back as an MCP error (`"isError": true`). Before, it came back as an
  ordinary result.
- A `prove_unit` call that does not prove (`not_proved`) now comes back as an MCP error. Before, it came back as an
  ordinary result.
- An internal fault now stops the door with exit code 70 and names the stage and the exception. Before, the exit
  code did not say what had happened.

A host that treated every reply as success will now see errors. Before 1.0, the middle number is how we signal
that.

A refusal is still the correct answer. The unit could not be proved as asked, and the right move is to change the
request. It is now also flagged, so it cannot be mistaken for success.

### Changed

- `forge`: a result whose final state is `refused` or `unmeasured` carries `"isError": true`. The content and
  `structuredContent` are unchanged.
- `prove_unit`: an outcome of `not_proved` carries `"isError": true`. Other outcomes (`proved`, `not_sent`,
  `prover_unreachable`, `unmeasured`, `reply_refused`, `input_refused`) carry no `isError` field.
- `intake_check`, `licence_gate`, `rail.show` and the other tools are unchanged.
- An internal fault inside `forge` is reported as `"stopped_at":"<phase>"` (report, tower, intake or pipeline) with
  `"reason":"internal_fault:<exception name>"`, plus one line on standard error. Before, every such fault was
  reported as an unreadable intake.
- An unknown fault in the door's main loop sets exit code 70 and writes one line on standard error. The door
  serves no further requests after it. End of input still exits 0.
- The stages' catch-all handlers name the exception (`<stage>: internal fault: <name>`) instead of
  `<stage>: unreadable`.
- Before each job, the previous job's `state/spec.ads` and `state/body.adb` are renamed to `state/spec.ads.prev`
  and `state/body.adb.prev`. A stale file can no longer be taken for the current job's output.
- When the reasoner is asked to diagnose a failed proof and does not answer, the diagnosis source is recorded as
  `reasoner-failed:<outcome>`. Before, it was recorded as `reasoner-unclassified`.
- A diagnosis that raises an exception is recorded as `internal-fault:<exception name>` instead of `none`.
- The server reports version `0.4.0`.

### Fixed

- A failed write of a round log, `state/spec.ads` or `state/body.adb` is said on standard error and named at the end
  of the stage reason. The stage outcome is unchanged.
- A failed write of an audit row is said on standard error, and the forge reply's reason ends
  `; audit_unrecorded (<n> of <rows> rows)`.
- A failed write of the vacuity evidence is said on standard error, and the reply's reason ends
  `; vacuity evidence unrecorded (state/vacuity.jsonl)`.
- The model rail records every outcome that is not text (unreachable, timeout, HTTP error) in standard error and
  `state/model-rail.jsonl`. Before, these left no record.
- An HTTP error from the model server keeps the server's status line and up to 256 bytes of its body, and the
  stage reason shows them. For example, a missing model is reported with the server's own message instead of only
  `http_error`.
- A failed write to `state/model-rail.jsonl` is said on standard error and noted in the reason.
- The prover and vacuity rails say why a request was not sent: `conf_unreadable` (with the exception) or
  `no_prover_line` / `no_vacuity_line`, on standard error and in `state/prover-rail.jsonl` /
  `state/vacuity-rail.jsonl`.
- The MASCOT design judge reads `producers` and `consumers` as well as `producer` and `consumer`, and every name in
  the value. Before, a backwards data edge written with the plural keys was not checked.
- Enrolment checks the network's signature against the key pinned in the build. Before, an unpinned key allowed any
  signer.
- Tower fetches are signed.

### Added

- Probe rows for each change above. Each row fails on the previous build and passes on this one.
- The trust file accepts admission receipts issued through a certificate from the admission roots, in addition to
  the earlier admission key.

### Docs

- `AGENTS.md`, `README.md`, `README.fr.md` and `README.zh-Hans.md`: a paragraph on refusals and `isError`. The
  existing text on refusals is kept.
- `INSTALL.md`, `CONNECTING.md`, `README.md`: tarball names and paths say `0.4.0`.
- Licence wording: a commercial licence is available only by a signed agreement with The Dark Factory Ltd.

### Known limitations

- There are no per-round or per-job deadlines yet. A stage can wait on a rail for as long as the rail's own
  timeouts allow. Deadlines are planned.
- A live `forge` of the FLOOR 1 sheet with the default local model may be refused at `fill_body` after 8 rounds.
  This also happens with the 0.3 build, so it is not a regression.
- Socket errors are still reported as `unreachable` or `timed_out`; connect timeouts and connection resets are not
  yet told apart.
- The rail services do not yet log the requests they drop.
- Rail liveness is checked only at start-up.
- Faults that reach only standard error (for example a tower fetch failure) are not yet carried in the forge reply.
- The model prompt changes tested for the House_Form rules are not included.
- `README.fr.md` and `README.zh-Hans.md` describe an earlier release. The English text governs.
