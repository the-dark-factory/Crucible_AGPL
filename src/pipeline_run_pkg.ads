--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: dd29809abccc01ee04ee889d178a0ef0dd350a475c346c3a834e452ea6238846
--
--  Pipeline_Run_Pkg -- CRUCIBLE's pipeline, sequential in one task (step 4c unit 4; v0.2.0 decision: tasks in v0.3.0).
--  Purpose: carry ONE job from Intake to a final stage, calling each stage's activity, auditing every transition, and
--  taking every step with the proven cores: the job record by Job_Record_Pkg.Record_Outcome, the next stage by
--  Pipeline_Stage_Pkg.Next (which reaches Emit only after Admission passed). The loop is bounded (14 transitions; the
--  proven Next moves every non-final stage strictly forward). Emit runs only when Job_Record_Pkg.May_Emit holds.
--  Stages whose work is not yet built (step 5a) are OWED: Unmeasured, never Passed.
--  Usage:
--     R : constant Pipeline_Run_Pkg.Report := Pipeline_Run_Pkg.Run (Sheet_Text);
with Ada.Strings.Unbounded;
with Pipeline_Stage_Pkg;

package Pipeline_Run_Pkg with SPARK_Mode => Off is

   Max_Transitions : constant := 14;

   type Report is record
      Final        : Pipeline_Stage_Pkg.Stage;      --  Done, Refused or Unmeasured
      Stopped_At   : Pipeline_Stage_Pkg.Stage;      --  the last stage whose activity ran
      Reason       : Ada.Strings.Unbounded.Unbounded_String;
      Transitions  : Natural;
      Emit_Allowed : Boolean;                       --  Job_Record_Pkg.May_Emit at the end
   end record;

   function Run (Sheet : String) return Report;

end Pipeline_Run_Pkg;
