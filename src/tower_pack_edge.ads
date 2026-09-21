--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 68c712896b32dc8dc1334a464f0afa419ea456de10117adef1d6aa27cc172190
--
--  Tower_Pack_Edge -- CRUCIBLE's PACK edge: this factory's admitted ledger packed into ONE signed sharer bundle, the
--  export mirror of Tower_Import_Pkg.
--  PURPOSE: TWO STAGES, one procedure. FRESH: fold the ledger copy into entries (the latest PROVE_OK + CLEAN row per
--  core, ordered by name; cope entries when a cope store exists -- none does yet), build line 1 as the import side
--  pins it, seal it with ssh-keygen -Y sign -n df-tower under the key at $HOME/.df-tower/df-tower, and write
--  out/tower.unreceipted (line 1, then {"seal":"<hex>"}). COMPLETION: when tower/pack.receipt is present (two hex
--  lines -- the receipt record and its df-admission seal, issued by the admitter for THAT line 1), reuse the
--  unreceipted bundle's line 1 and seal verbatim, assemble the envelope, write out/tower.bundle. Nothing is packed
--  twice: a receipt names one digest, and a fresh pack has a fresh expiry.
--  USAGE: run Pack in the factory's root. Word comes back as one of: packed, packed_unreceipted, refused_no_ledger,
--  refused_no_key, refused_nothing_shareable, refused_too_large, refused_sign_failed, refused_write_failed,
--  refused_no_source, refused_receipt_mismatch -- or unmeasured, the last handler's word. Every run appends one row
--  to state/tower-pack.jsonl. Version is this packer's own counter (the highest version in that record + 1);
--  expires is now + Expires_After (the owner's ruling P3, 2026-09-21: 7 days).
--  The seat never reads the private key; the binary does, at run time, as the owner accepted (O-3 ceremony).
--  SEAT-WRITTEN (an edge spec; SPARK_Mode Off). The judgements are in Tower_Pack_Pkg and the import side's units.
with Ada.Strings.Unbounded;

package Tower_Pack_Edge with SPARK_Mode => Off is

   Ledger_Path      : constant String := "state/VERIFIED_CORES.jsonl";
   Record_Path      : constant String := "state/tower-pack.jsonl";
   Receipt_Path     : constant String := "tower/pack.receipt";
   Bundle_Path      : constant String := "out/tower.bundle";
   Unreceipted_Path : constant String := "out/tower.unreceipted";
   Work_Dir         : constant String := "state/tower-pack";
   Key_Rel          : constant String := "/.df-tower/df-tower";
   Ssh_Keygen       : constant String := "/usr/bin/ssh-keygen";
   Namespace        : constant String := "df-tower";
   Expires_After    : constant := 604_800;
   Max_Entries      : constant := 4096;
   Line_Bound       : constant := 4096;

   procedure Pack (Word : out Ada.Strings.Unbounded.Unbounded_String);

end Tower_Pack_Edge;
