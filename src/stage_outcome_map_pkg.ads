--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 4b687ce420a0f95493f8b6f133023e2e8314559e6e7a1067d96ece78035847a1
--
with Pipeline_Stage_Pkg;
with Prover_Rail_Pkg;
with Model_Reply_Pkg;

package Stage_Outcome_Map_Pkg with SPARK_Mode is

   use type Pipeline_Stage_Pkg.Outcome;
   use type Prover_Rail_Pkg.Outcome_Kind;
   use type Model_Reply_Pkg.Outcome_Kind;

   function From_Prover (O : Prover_Rail_Pkg.Outcome_Kind) return Pipeline_Stage_Pkg.Outcome
     is (if O = Prover_Rail_Pkg.Outcome_Proved then Pipeline_Stage_Pkg.Passed
         elsif O = Prover_Rail_Pkg.Outcome_Not_Proved or else O = Prover_Rail_Pkg.Outcome_Reply_Refused
         then Pipeline_Stage_Pkg.Refused_Here
         else Pipeline_Stage_Pkg.Unmeasured_Here)
     with Post => ((From_Prover'Result = Pipeline_Stage_Pkg.Passed) = (O = Prover_Rail_Pkg.Outcome_Proved))
       and then ((From_Prover'Result = Pipeline_Stage_Pkg.Refused_Here) =
                 (O = Prover_Rail_Pkg.Outcome_Not_Proved or else O = Prover_Rail_Pkg.Outcome_Reply_Refused));

   function From_Model (O : Model_Reply_Pkg.Outcome_Kind) return Pipeline_Stage_Pkg.Outcome
     is (if O = Model_Reply_Pkg.Model_Text then Pipeline_Stage_Pkg.Passed else Pipeline_Stage_Pkg.Unmeasured_Here)
     with Post => ((From_Model'Result = Pipeline_Stage_Pkg.Passed) = (O = Model_Reply_Pkg.Model_Text))
       and then (From_Model'Result /= Pipeline_Stage_Pkg.Refused_Here);

   function From_Verdict (May_Proceed : Boolean) return Pipeline_Stage_Pkg.Outcome
     is (if May_Proceed then Pipeline_Stage_Pkg.Passed else Pipeline_Stage_Pkg.Refused_Here)
     with Post => ((From_Verdict'Result = Pipeline_Stage_Pkg.Passed) = May_Proceed);

   function Audit_Code (S : Pipeline_Stage_Pkg.Stage; O : Pipeline_Stage_Pkg.Outcome) return Natural
     is (3 * Pipeline_Stage_Pkg.Stage'Pos (S) + Pipeline_Stage_Pkg.Outcome'Pos (O))
     with Post => (Audit_Code'Result = 3 * Pipeline_Stage_Pkg.Stage'Pos (S) + Pipeline_Stage_Pkg.Outcome'Pos (O))
       and then (Audit_Code'Result <= 41);

end Stage_Outcome_Map_Pkg;
