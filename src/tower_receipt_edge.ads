--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 960b6d5d383c24bd7b29727bcef5b0907a38b31cc78ef99d6ee3e157ee795ae4
--
--  Tower_Receipt_Edge -- the ADMISSION side's RECEIPT ISSUER for a packed tower bundle: the second half of the SHARE
--  side (the owner's ruling P2, 2026-09-21: two units -- the packer emits an unreceipted bundle, and this unit, on the
--  build host as the admitter, completes it).
--  PURPOSE: read in/tower.unreceipted (line 1 as the packer wrote it, then {"seal":"<hex>"}); measure that line 2 is
--  one seal and nothing else, that line 1 is a payload the import side would read, that the seal was made by a
--  packer the allowed_signers file beside this binary names and verifies under df-tower, and that it was NOT made
--  with this issuer's own key; then put the admitter's name to line 1's digest: the receipt record
--  {"bundle_sha256":"<64 hex>"} (Tower_Pack_Pkg.Receipt_Text) sealed AS A LINE with ssh-keygen -Y sign -n
--  df-admission under the key at $HOME/keys/interim-2026-08.key -- the admitter's own key on gertrude, the one
--  admit-core.sh signs core admissions with; no new key. Writes out/tower.bundle (line 1 verbatim, then the envelope
--  Tower_Pack_Pkg.Envelope_Text assembles) and out/tower.receipt (two hex lines: the record and its seal -- the
--  packer's own completion input, so either host can finish the file).
--  USAGE: run Issue in the issuer's root, as the admitter. Word comes back as one of: issued, refused_no_source,
--  refused_no_key, refused_not_sealed, refused_not_a_payload, refused_seal_unknown, refused_seal_invalid,
--  refused_self_sealed, refused_sign_failed, refused_write_failed -- or unmeasured, the last handler's word. Every
--  measured run appends one row to state/tower-receipt.jsonl: the word, the digest, the packer's principal as
--  find-principals measured it, the sha256 of this key's public file and of the signers file, and the time.
--  WHAT THE RECEIPT ATTESTS, said plainly: that the admitter saw a well-formed line 1 with THIS digest, sealed by a
--  packer it knows, and put its name to that digest. It does NOT say the entries inside are true (the import side's
--  rulings R3 and plan ruling 9: content is the central tower's judgement, not this unit's).
--  The seat never reads the private key; the binary does, at run time, as the owner accepted (O-3 ceremony).
--  SEAT-WRITTEN (an edge spec; SPARK_Mode Off). The judgements are in Tower_Receipt_Pkg, Tower_Pack_Pkg and the
--  import side's units.
with Ada.Strings.Unbounded;

package Tower_Receipt_Edge with SPARK_Mode => Off is

   Source_Path       : constant String := "in/tower.unreceipted";
   Bundle_Path       : constant String := "out/tower.bundle";
   Receipt_Path      : constant String := "out/tower.receipt";
   Record_Path       : constant String := "state/tower-receipt.jsonl";
   Work_Dir          : constant String := "state/tower-receipt";
   Key_Rel           : constant String := "/keys/interim-2026-08.key";
   Signers_Name      : constant String := "allowed_signers";
   Ssh_Keygen        : constant String := "/usr/bin/ssh-keygen";
   Namespace         : constant String := "df-tower";
   Receipt_Namespace : constant String := "df-admission";
   Pub_Bound         : constant := 4096;

   procedure Issue (Word : out Ada.Strings.Unbounded.Unbounded_String);

end Tower_Receipt_Edge;
