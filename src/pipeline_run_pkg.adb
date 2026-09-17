--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 5673e8e76e3af44c105b30d7b5aa03e757ff5325b5943e819e2bd4d82c10b9fa
--
--  Pipeline_Run_Pkg body -- template (seat-written plumbing) with ONE slot (transition), filled by a Wu edge round.
--  Brief BRIEF_crucible_step4_wiring_2026-09-17 (4c unit 4).
with Audit_Ledger_Pkg;
with Job_Record_Pkg;
with Pipeline_Activities_Pkg;
with Decompose_Activity_Pkg;

package body Pipeline_Run_Pkg with SPARK_Mode => Off is

   use Ada.Strings.Unbounded;
   use type Pipeline_Stage_Pkg.Stage;

   function Run (Sheet : String) return Report is
      S      : Pipeline_Stage_Pkg.Stage := Pipeline_Stage_Pkg.Intake;
      O      : Pipeline_Stage_Pkg.Outcome := Pipeline_Stage_Pkg.Unmeasured_Here;
      J      : Job_Record_Pkg.Job := Job_Record_Pkg.Fresh;
      L      : Audit_Ledger_Pkg.Ledger :=
        (Entries => (others => (Source => Audit_Ledger_Pkg.Door_Listener, Code => 0)), Count => 0, Full => False);
      R      : Unbounded_String;
      Seq    : Natural := 0;
      Last_S : Pipeline_Stage_Pkg.Stage := Pipeline_Stage_Pkg.Intake;
   begin
      for Step in 1 .. Max_Transitions loop
         exit when Pipeline_Stage_Pkg.Is_Terminal (S);

         --  Dispatch: which activity gathers the facts for this stage (plumbing; the outcome is decided inside).
         case S is
            when Pipeline_Stage_Pkg.Intake =>
               Pipeline_Activities_Pkg.Run_Intake (Sheet, O, R);
            when Pipeline_Stage_Pkg.Decompose =>
               Decompose_Activity_Pkg.Run (Sheet, O, R);
            when Pipeline_Stage_Pkg.Emit =>
               if Job_Record_Pkg.May_Emit (J) then
                  Pipeline_Activities_Pkg.Run_Owed (O, R);   --  writing the unit and receipt is step 6's work
               else
                  O := Pipeline_Stage_Pkg.Refused_Here;
                  R := To_Unbounded_String ("emit refused: not every gate passed");
               end if;
            when others =>
               Pipeline_Activities_Pkg.Run_Owed (O, R);
         end case;

         Seq := Seq + 1;
         Pipeline_Activities_Pkg.Audit (L, Seq, S, O, To_String (R));
         Last_S := S;

         --  SLOT BEGIN (transition)
J := Job_Record_Pkg.Record_Outcome (J, S, O);
S := Pipeline_Stage_Pkg.Next (S, O);
         --  SLOT END (transition)
      end loop;

      return (Final        => S,
              Stopped_At   => Last_S,
              Reason       => R,
              Transitions  => Seq,
              Emit_Allowed => Job_Record_Pkg.May_Emit (J));
   end Run;

end Pipeline_Run_Pkg;
