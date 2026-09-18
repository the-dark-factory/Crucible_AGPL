--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: e7dc3fac61557110d203513fefd7b84de7b42508fef588e128ade5f3a9ddb6a5
--
--  Vacuity_Rail_Call_Pkg -- CRUCIBLE's path to the vacuity battery over the VACUITY RAIL (step 5a-5c-3).
--  Purpose: gather the facts for one measurement request and one reply, and let the proven deciders judge them.
--  It decides nothing: the rail line is judged by Rail_Config_Pkg, the endpoint by Sovereign_Gate_Pkg, the
--  request by Vacuity_Rail_Pkg.May_Send (no socket is opened unless it holds), and the outcome by
--  Vacuity_Rail_Pkg.Decide over Vacuity_Facts_Pkg's rules.
--  Configuration: config/rail.conf, one JSON line per rail; the first valid line whose rail is "vacuity" is used.
--  Usage:
--     Vacuity_Rail_Call_Pkg.Judge_Full (Unit_Name => "Linear_Search", Spec_Text => S,
--                                       Outcome => O, Facts => F, Grades => G);
--     Vacuity_Rail_Pkg.Is_Pass (O) is the ONLY way to call the contract meaningful.
--  A measurement that did not finish is Outcome_Unmeasured -- never Hollow, never Meaningful.
with Vacuity_Rail_Pkg;

package Vacuity_Rail_Call_Pkg with SPARK_Mode => Off is

   Conf_Path      : constant String := "config/rail.conf";
   Max_Unit_Bytes : constant := 1_048_576;  --  the same limit as CRUCIBLE's door line

   function Judge
     (Unit_Name : String;
      Spec_Text : String) return Vacuity_Rail_Pkg.Outcome_Kind;

   --  Beside the outcome: the Reply_Facts the outcome was decided from, and the battery's own per-function
   --  grade lines, which the service sends as raw lines after its reply line ("<name> <grade> <word>", in
   --  file order). Grades is that text, LF-joined, or empty when no lines came, the declared count and the
   --  lines received disagreed, or the reply was not complete. It never changes Outcome: Vacuity_Rail_Pkg.Decide
   --  sees the reply line's facts only. The reason a stage gives names faults from Facts, and may quote Grades.
   type Text_Access is access String;

   procedure Judge_Full
     (Unit_Name : String;
      Spec_Text : String;
      Outcome   : out Vacuity_Rail_Pkg.Outcome_Kind;
      Facts     : out Vacuity_Rail_Pkg.Reply_Facts;
      Grades    : out Text_Access);

end Vacuity_Rail_Call_Pkg;
