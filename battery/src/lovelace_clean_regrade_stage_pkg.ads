--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: aa750741ec590141b23ad23c05d3bfe1ff82987f72e5e3c0d13541d91b6608f9
--
with Lovelace_Grade_Stage_Pkg;
use Lovelace_Grade_Stage_Pkg;

package Lovelace_Clean_Regrade_Stage_Pkg with SPARK_Mode, Pure is

   type Regrade_Result is record
      Lowered : Boolean := False;
      Errors  : Natural := 0;
   end record;

   function Should_Reask (G : Grade_Value; T3 : Outcome; Tool_Faults : Natural) return Boolean is
     (G >= 0 and then T3 = Unreached and then Tool_Faults > 0);

   function Clean_Question (Q : Question) return Question is
     ((Q with delta T3_Slot => Failed))
     with Post => Clean_Question'Result (T3_Slot) = Failed
                  and then (for all S in Slot => (if S /= T3_Slot then Clean_Question'Result (S) = Q (S)));

   function Regrade_Of (G : Grade_Value; A : Edge_Answer) return Regrade_Result is
     (if not A.Answered then (Lowered => False, Errors => 1)
      else (Lowered => A.Digit > G, Errors => 0))
     with Pre  => G >= 0,
          Post => Regrade_Of'Result.Errors <= 1
                  and then ((Regrade_Of'Result.Errors = 1) = (not A.Answered))
                  and then ((Regrade_Of'Result.Lowered) = (A.Answered and then A.Digit > G));

end Lovelace_Clean_Regrade_Stage_Pkg;
