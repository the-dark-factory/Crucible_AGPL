--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 43036eeaafcde6105efcd34b0db73dad255fe9f4598a79cb906068a74106e94b
--
--  Tower_Import_Pkg -- CRUCIBLE's import edge for ONE signed SHARER bundle (tower/sharer.bundle).
--  PURPOSE: the bundle becomes measured FACTS; the proven Tower_Admission_Pkg.Decide decides; the ledger is folded
--  by the proven Tower_Ledger_Fold_Pkg; the word is recorded in state/tower.jsonl. This edge never stops a forge and
--  never raises: whatever is wrong with a sharer bundle, the door forges on the base and the ledger says why.
--  USAGE: call Import once per forge, AFTER Tower_Base_Check_Edge.Check has let the door through. Word comes back
--  as one of: absent, unchanged, accepted, declined_by_policy, refused_receipt, refused_integrity -- or
--  unrecorded, when the decider said Accepted and the machine row was not READ BACK from the ledger: the ROW is
--  the acceptance, so nothing was accepted and the door forges on the base.
--  The trusted signers are the allowed_signers file BESIDE THE BINARY (the owner's ruling K1, 2026-09-20); its
--  sha256 is recorded in every row it writes (O-2, 2026-09-21). The bundle's seal is under Namespace and the
--  receipt's seal under Receipt_Namespace (the owner's rulings O4 and R1, 2026-09-20).
--  SEAT-WRITTEN (an edge spec; SPARK_Mode Off). The judgements are in the six proven packages the body names.
with Ada.Strings.Unbounded;

package Tower_Import_Pkg with SPARK_Mode => Off is

   Bundle_Path       : constant String := "tower/sharer.bundle";
   Ledger_Path       : constant String := "state/tower.jsonl";
   Policy_Path       : constant String := "config/tower.conf";
   Work_Dir          : constant String := "state/tower-import";
   Signers_Name      : constant String := "allowed_signers";
   Ssh_Keygen        : constant String := "/usr/bin/ssh-keygen";
   Namespace         : constant String := "df-tower";
   Receipt_Namespace : constant String := "df-admission";

   --  A ledger line is read in at most this many characters; a machine row is 101. What lies beyond the bound on
   --  one line is skipped, so one long line can hide nothing that follows it.
   Line_Bound        : constant := 4096;

   procedure Import (Word : out Ada.Strings.Unbounded.Unbounded_String);

end Tower_Import_Pkg;
