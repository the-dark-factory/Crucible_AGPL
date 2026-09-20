--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 72cd2a453b3c058a2638a1495f09d847363a084a01af340500e3ccbbfbef79b9
--
--  Tower_Base_Check_Edge -- CRUCIBLE's door-side check that the BASE TOWER BUNDLE on disk is the one this
--  binary was built with (plan T1; Tony's ruling 1 of 2026-09-19: base missing or tampered => the door STOPS).
--  Purpose: measure three facts about tower/base.bundle and let the proven Tower_Base_Verdict_Pkg judge them.
--  It decides nothing: whether the base holds, and the word said when it does not, are Tower_Base_Verdict_Pkg's.
--  What it measures, and how: the file is read by the SAME acceptance test the stamp tool (stamp_tower_main)
--  applied when it made the pin -- exactly two lines, line 1 not empty and at most 1048576 characters, line 2
--  not blank, trailing CR and LF stripped from both -- and the SHA-256 of line 1's characters ONLY is compared
--  with the compiled-in Crucible_Tower.Base_Digest. The pin covers line 1, so a third line is a refusal.
--  File: tower/base.bundle, relative to the current directory, as the stamp tool reads it. The pin is what
--  makes that safe: whichever directory the door is started in, the file there must match the digest built in.
--  Usage:
--     Tower_Base_Check_Edge.Check (Verdict => V, Facts => F, Line_1 => L);
--     Tower_Base_Verdict_Pkg.May_Forge (V) is the ONLY way to call the base good.
--     Tower_Base_Verdict_Pkg.Reason_Word (V) is the word for the refusal.
--  Line_1 is the in-memory line that was hashed, handed back ONLY when the verdict is Base_Holds, so that a
--  later reader splices entries from the very bytes that were checked and never reads the file a second time.
--  On every other verdict Line_1 is the null string.
--  A refusal means REPLACE THE BINARY OR RESTORE THE BUNDLE IT WAS BUILT WITH; editing the bundle cannot help.
with Ada.Strings.Unbounded;
with Tower_Base_Verdict_Pkg;

package Tower_Base_Check_Edge with SPARK_Mode => Off is

   Bundle_Path   : constant String := "tower/base.bundle";
   Max_Line_1    : constant := 1_048_576;  --  the same bound the stamp tool applied

   procedure Check
     (Verdict : out Tower_Base_Verdict_Pkg.Verdict_Kind;
      Facts   : out Tower_Base_Verdict_Pkg.Base_Facts;
      Line_1  : out Ada.Strings.Unbounded.Unbounded_String);

end Tower_Base_Check_Edge;
