--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1dd3bac940c89ba69fcce25e1f05fc321305b5ce68180b0c9e6cf9b2e1ff12a6
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
with Vacuity_Rail_Call_Pkg;
with Vacuity_Rail_Pkg;
with Vacuity_Facts_Pkg;
with Ada.Characters.Handling;
with Ada.Text_IO;
with Ada.Directories;
with Json_String_Pkg;

package body Pipeline_Run_Pkg with SPARK_Mode => Off is

   use Ada.Strings.Unbounded;
   use type Pipeline_Stage_Pkg.Stage;
   use type Fill_Route_Pkg.Route_Kind;
   use type Prover_Rail_Pkg.Outcome_Kind;
   use type Vacuity_Rail_Pkg.Outcome_Kind;
   use type Vacuity_Rail_Call_Pkg.Text_Access;

   LF : constant Character := Character'Val (10);
   Vacuity_Path : constant String := "state/vacuity.jsonl";

   --  The activities' own idiom: Encode is a procedure with a bound, so a string too long to encode is reported
   --  as such rather than silently truncated -- a record that lies by omission is worse than one that says it cannot.
   function Json_Of (S : String) return String is
      S1  : constant String (1 .. S'Length) := S;
      Enc : String (1 .. Natural'Max (1, 2 * S1'Length));
      Len : Natural;
      Ok  : Boolean;
   begin
      if S1'Length > Json_String_Pkg.Max_Raw then
         return """too-long-to-encode""";
      end if;
      Json_String_Pkg.Encode (S1, Enc, Len, Ok);
      return (if Ok then """" & Enc (1 .. Len) & """" else """unencodable""");
   end Json_Of;

   --  The faults by name, so a refusal says WHICH promise was empty rather than only that one was.
   function Fault_Names (V : Vacuity_Facts_Pkg.Verdict_Type) return String is
     ((if V.fault_battery_did_not_run then " battery_did_not_run" else "") &
      (if V.fault_refused then " refused" else "") &
      (if V.fault_errors then " errors" else "") &
      (if V.fault_unread then " unread" else "") &
      (if V.fault_nothing_graded then " nothing_graded" else "") &
      (if V.fault_not_theorem then " not_theorem" else "") &
      (if V.fault_inconsistent then " inconsistent" else ""));

   --  One JSON line into state/vacuity.jsonl: the counts the verdict was reached from, and the battery's own grade
   --  lines. A stage that refuses must leave behind the evidence it refused on.
   procedure Record_Vacuity (Name   : String;
                             VO     : Vacuity_Rail_Pkg.Outcome_Kind;
                             Facts  : Vacuity_Rail_Pkg.Reply_Facts;
                             Grades : Vacuity_Rail_Call_Pkg.Text_Access) is
      F : Ada.Text_IO.File_Type;
      function N (X : Natural) return String is
         S : constant String := Natural'Image (X);
      begin
         return S (S'First + 1 .. S'Last);
      end N;
   begin
      begin
         Ada.Directories.Create_Path ("state");
      exception
         when others => null;
      end;
      begin
         if Ada.Directories.Exists (Vacuity_Path) then
            Ada.Text_IO.Open (F, Ada.Text_IO.Append_File, Vacuity_Path);
         else
            Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Vacuity_Path);
         end if;
         Ada.Text_IO.Put_Line
           (F,
            "{""unit"":" & Json_Of (Name) &
            ",""outcome"":""" & Ada.Characters.Handling.To_Lower (Vacuity_Rail_Pkg.Outcome_Kind'Image (VO)) &
            """,""battery_ran"":""" & (if Facts.facts.battery_ran then "true" else "false") &
            """,""functions_read"":""" & N (Facts.facts.functions_read) &
            """,""functions_graded"":""" & N (Facts.facts.functions_graded) &
            """,""definitions_only"":""" & N (Facts.facts.definitions_only) &
            """,""postconditions_declared"":""" & N (Facts.facts.postconditions_declared) &
            """,""postconditions_read"":""" & N (Facts.facts.postconditions_read) &
            """,""theorem_count"":""" & N (Facts.facts.theorem_count) &
            """,""runtime_only_count"":""" & N (Facts.facts.runtime_only_count) &
            """,""unexercised_count"":""" & N (Facts.facts.unexercised_count) &
            """,""refused_count"":""" & N (Facts.facts.refused_count) &
            """,""grades"":" & Json_Of ((if Grades = null then "" else Grades.all)) & "}");
         Ada.Text_IO.Close (F);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;
   end Record_Vacuity;

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

   --  Vacuity (5a-5d): the fit specification is MEASURED on the vacuity rail — "proved" is not "claims something".
   --  CRUCIBLE never runs the battery itself (the sole-door rule): it sends the spec, and the proven
   --  Vacuity_Rail_Pkg.Decide judges the reply's facts through Vacuity_Facts_Pkg's rules. A rail that could not be
   --  reached, or a run that did not finish, leaves the stage UNMEASURED — never passed, and never called hollow.
   procedure Judge_Vacuity (Name, Spec : String; O : out Pipeline_Stage_Pkg.Outcome; R : out Unbounded_String) is
      N1 : constant String (1 .. Name'Length) := Name;
      S1 : constant String (1 .. Spec'Length) := Spec;
      Facts  : Vacuity_Rail_Pkg.Reply_Facts;
      VO     : Vacuity_Rail_Pkg.Outcome_Kind;
      Grades : Vacuity_Rail_Call_Pkg.Text_Access;
      V      : Vacuity_Facts_Pkg.Verdict_Type;
   begin
      Vacuity_Rail_Call_Pkg.Judge_Full (N1, S1, VO, Facts, Grades);
      Record_Vacuity (N1, VO, Facts, Grades);
      if VO /= Vacuity_Rail_Pkg.Outcome_Meaningful and then VO /= Vacuity_Rail_Pkg.Outcome_Hollow then
         O := Pipeline_Stage_Pkg.Unmeasured_Here;
         R := To_Unbounded_String ("vacuity: rail: " & Ada.Characters.Handling.To_Lower (Vacuity_Rail_Pkg.Outcome_Kind'Image (VO)));
         return;
      end if;
      V := Vacuity_Facts_Pkg.Assemble (Facts.facts);
      --  SLOT BEGIN (vacuity-verdict)
      O := Stage_Outcome_Map_Pkg.From_Verdict (Vacuity_Rail_Pkg.Is_Pass (VO) and then V.contract_is_meaningful);
      --  SLOT END (vacuity-verdict)
      R := To_Unbounded_String ("vacuity: " & Ada.Characters.Handling.To_Lower (Vacuity_Rail_Pkg.Outcome_Kind'Image (VO)) &
                                (if V.contract_is_meaningful then "" else ", faults:" & Fault_Names (V)));
   end Judge_Vacuity;

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
            when Pipeline_Stage_Pkg.Vacuity =>
               Judge_Vacuity (To_String (Unit_Name), To_String (Spec_Text), O, R);
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
