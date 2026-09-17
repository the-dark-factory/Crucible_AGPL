--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 4a0c91e9489db9c807fcc7aa56a92141ad6d99ef36a5840eea6cc3c4e83119a8
--
--  Pipeline_Run_Pkg body -- template (seat-written plumbing) with ONE slot (transition), filled by a Wu edge round.
--  Brief BRIEF_crucible_step4_wiring_2026-09-17 (4c unit 4).
with Audit_Ledger_Pkg;
with Job_Record_Pkg;
with Pipeline_Activities_Pkg;
with Decompose_Activity_Pkg;
with Wu_Round_Activity_Pkg;
with Body_Fill_Activity_Pkg;
with Prover_Rail_Call_Pkg;
with Prover_Rail_Pkg;
with Gate_Word_Pkg;
with Fill_Route_Pkg;
with Spec_Shape_Pkg;
with Stage_Outcome_Map_Pkg;
with Ada.Characters.Handling;

package body Pipeline_Run_Pkg with SPARK_Mode => Off is

   use Ada.Strings.Unbounded;
   use type Pipeline_Stage_Pkg.Stage;
   use type Fill_Route_Pkg.Route_Kind;
   use type Prover_Rail_Pkg.Outcome_Kind;

   LF : constant Character := Character'Val (10);

   --  Prove_Spec (ruling 1, 5a-4): the second, independent judgement of the fit specification is the SAME proven route
   --  Emit_Contract used — fill or fill-deferred, skipped subprograms counted against the unit's own BODY-DEFERRED lines.
   procedure Judge_Spec (Name, Spec : String; O : out Pipeline_Stage_Pkg.Outcome; R : out Unbounded_String) is
      N1 : constant String (1 .. Name'Length) := Name;
      S1 : constant String (1 .. Spec'Length) := Spec;
      Facts : Prover_Rail_Pkg.Reply_Facts;
      PO    : Prover_Rail_Pkg.Outcome_Kind;
      Diag  : Prover_Rail_Call_Pkg.Text_Access;
      Declared : Natural := 0;
      Undeclared : Natural := 0;
      GF    : Gate_Word_Pkg.Gate_Facts;
      Route : Fill_Route_Pkg.Route_Kind := Fill_Route_Pkg.Route_Refuse;
      LS    : Positive := 1;
   begin
      Prover_Rail_Call_Pkg.Prove_Full (N1, S1, "", 2, PO, Facts, Diag);
      if PO /= Prover_Rail_Pkg.Outcome_Proved and then PO /= Prover_Rail_Pkg.Outcome_Not_Proved then
         O := Pipeline_Stage_Pkg.Unmeasured_Here;
         R := To_Unbounded_String ("prove_spec: prover rail: " & Ada.Characters.Handling.To_Lower (Prover_Rail_Pkg.Outcome_Kind'Image (PO)));
         return;
      end if;
      for P in 1 .. S1'Length + 1 loop
         if P = S1'Length + 1 or else S1 (P) = LF then
            if P > LS then
               declare
                  L1 : constant String (1 .. P - LS) := S1 (LS .. P - 1);
               begin
                  if L1'Length <= Spec_Shape_Pkg.Max_Line and then Spec_Shape_Pkg.Contains_CI (L1, "body-deferred:") then
                     Declared := Declared + 1;
                  end if;
               end;
            end if;
            LS := P + 1;
         end if;
      end loop;
      Undeclared := (if Facts.subprograms_skipped > Declared then Facts.subprograms_skipped - Declared else 0);
      --  SLOT BEGIN (prove-spec-verdict)
      GF := (unit_compiled => Facts.run.unit_compiled, checks_generated => Facts.run.checks_generated,
             checks_unproved => Facts.run.checks_unproved, subprograms_skipped => Facts.subprograms_skipped, cheat_markers => 0);
      Route := Fill_Route_Pkg.Decide (Gate_Word_Pkg.Word_Of (GF), Gate_Word_Pkg.Compile_Errors_Of (GF), 0,
                GF.checks_unproved, GF.subprograms_skipped, Undeclared);
      O := Stage_Outcome_Map_Pkg.From_Verdict (Route /= Fill_Route_Pkg.Route_Refuse);
      --  SLOT END (prove-spec-verdict)
      R := To_Unbounded_String ("prove_spec: " & Gate_Word_Pkg.Word_Of (GF) & ", " &
                                Ada.Characters.Handling.To_Lower (Fill_Route_Pkg.Route_Kind'Image (Route)));
   end Judge_Spec;

   --  Prove_Body: the prover judges specification + body together; with a body present nothing may remain deferred.
   procedure Judge_Body (Name, Spec, Body_T : String; O : out Pipeline_Stage_Pkg.Outcome; R : out Unbounded_String) is
      N1 : constant String (1 .. Name'Length) := Name;
      S1 : constant String (1 .. Spec'Length) := Spec;
      B1 : constant String (1 .. Body_T'Length) := Body_T;
      Facts : Prover_Rail_Pkg.Reply_Facts;
      PO    : Prover_Rail_Pkg.Outcome_Kind;
      Diag  : Prover_Rail_Call_Pkg.Text_Access;
      GF    : Gate_Word_Pkg.Gate_Facts;
      Route : Fill_Route_Pkg.Route_Kind := Fill_Route_Pkg.Route_Refuse;
   begin
      if B1'Length = 0 then
         O := Pipeline_Stage_Pkg.Refused_Here;
         R := To_Unbounded_String ("prove_body refused: no body was filled");
         return;
      end if;
      Prover_Rail_Call_Pkg.Prove_Full (N1, S1, B1, 2, PO, Facts, Diag);
      if PO /= Prover_Rail_Pkg.Outcome_Proved and then PO /= Prover_Rail_Pkg.Outcome_Not_Proved then
         O := Pipeline_Stage_Pkg.Unmeasured_Here;
         R := To_Unbounded_String ("prove_body: prover rail: " & Ada.Characters.Handling.To_Lower (Prover_Rail_Pkg.Outcome_Kind'Image (PO)));
         return;
      end if;
      --  SLOT BEGIN (prove-body-verdict)
      GF := (unit_compiled => Facts.run.unit_compiled, checks_generated => Facts.run.checks_generated,
             checks_unproved => Facts.run.checks_unproved, subprograms_skipped => Facts.subprograms_skipped, cheat_markers => 0);
      Route := Fill_Route_Pkg.Decide (Gate_Word_Pkg.Word_Of (GF), Gate_Word_Pkg.Compile_Errors_Of (GF), 0,
                GF.checks_unproved, GF.subprograms_skipped, GF.subprograms_skipped);
      O := Stage_Outcome_Map_Pkg.From_Verdict (Route = Fill_Route_Pkg.Route_Fill);
      --  SLOT END (prove-body-verdict)
      R := To_Unbounded_String ("prove_body: " & Gate_Word_Pkg.Word_Of (GF) & ", " &
                                Ada.Characters.Handling.To_Lower (Fill_Route_Pkg.Route_Kind'Image (Route)));
   end Judge_Body;

   function Run (Sheet : String) return Report is
      S      : Pipeline_Stage_Pkg.Stage := Pipeline_Stage_Pkg.Intake;
      O      : Pipeline_Stage_Pkg.Outcome := Pipeline_Stage_Pkg.Unmeasured_Here;
      J      : Job_Record_Pkg.Job := Job_Record_Pkg.Fresh;
      L      : Audit_Ledger_Pkg.Ledger :=
        (Entries => (others => (Source => Audit_Ledger_Pkg.Door_Listener, Code => 0)), Count => 0, Full => False);
      R      : Unbounded_String;
      Seq    : Natural := 0;
      Last_S : Pipeline_Stage_Pkg.Stage := Pipeline_Stage_Pkg.Intake;
      --  5a-2f: the job's products travel between stages here (plumbing; every stage still decides through its cores):
      --  the accepted design (Decompose), the unit name and the fit specification (Emit_Contract), re-proved by Prove_Spec.
      Design    : Unbounded_String;
      Unit_Name : Unbounded_String;
      Spec_Text : Unbounded_String;
      Body_Text : Unbounded_String;
   begin
      for Step in 1 .. Max_Transitions loop
         exit when Pipeline_Stage_Pkg.Is_Terminal (S);

         --  Dispatch: which activity gathers the facts for this stage (plumbing; the outcome is decided inside).
         case S is
            when Pipeline_Stage_Pkg.Intake =>
               Pipeline_Activities_Pkg.Run_Intake (Sheet, O, R);
            when Pipeline_Stage_Pkg.Decompose =>
               Decompose_Activity_Pkg.Run_Keeping_Design (Sheet, O, R, Design);
            when Pipeline_Stage_Pkg.Emit_Contract =>
               Wu_Round_Activity_Pkg.Run (Sheet, To_String (Design), Unit_Name, Spec_Text, O, R);
            when Pipeline_Stage_Pkg.Prove_Spec =>
               Judge_Spec (To_String (Unit_Name), To_String (Spec_Text), O, R);
            when Pipeline_Stage_Pkg.Fill_Body =>
               Body_Fill_Activity_Pkg.Run (To_String (Spec_Text), To_String (Unit_Name), Body_Text, O, R);
            when Pipeline_Stage_Pkg.Prove_Body =>
               Judge_Body (To_String (Unit_Name), To_String (Spec_Text), To_String (Body_Text), O, R);
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
