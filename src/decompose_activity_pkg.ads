--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 803f5ee68ca25d4498b06f42c3c2563746ed0ec6365e2db459bce0b5dd607717
--
--  Decompose_Activity_Pkg -- the Decompose stage of CRUCIBLE's pipeline, in process (step 4c unit 3).
--  Purpose: ask the model rail for a MASCOT design of the brief, and judge it with the proven MASCOT scanner, measurer
--  and judge. It decides nothing: the model's outcome is judged by Model_Reply_Pkg (inside Model_Rail_Call_Pkg), the
--  design by Mascot_Scan_Pkg / Mascot_Measure_Pkg / Mascot_Judge_Pkg, and the stage outcome by Stage_Outcome_Map_Pkg.
--  A design that does not fit the scanner's bounds (a line over Max_Line, or more than Max_Nodes lines) is REFUSED,
--  never measured on a clipped prefix. Any model outcome other than text is Unmeasured_Here (retry policy is step 5a's).
--  Usage:
--     Decompose_Activity_Pkg.Run (Brief => Sheet_Text, Result => O, Reason => R);
with Ada.Strings.Unbounded;
with Pipeline_Stage_Pkg;

package Decompose_Activity_Pkg with SPARK_Mode => Off is

   Design_Instruction : constant String :=
     "Emit a MASCOT design as JSON lines: exactly one subsystem per line, "
     & "each line one flat JSON object with string values only and no nesting. "
     & "Keys: id (required); kind (required: activity, pool, channel or composite); "
     & "element (typed channel or pool); buffer (buffered channel); producer (one) or "
     & "producers (many); consumer (one) or consumers (many); reporting:true on the one "
     & "events channel; reads, writes, reports (activity); accessed (pool); discharge "
     & "(any leaf: what is proved here); children (composite). No prose, no fences. Brief: ";

   procedure Run
     (Brief  : String;
      Result : out Pipeline_Stage_Pkg.Outcome;
      Reason : out Ada.Strings.Unbounded.Unbounded_String);

end Decompose_Activity_Pkg;
