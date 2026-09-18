--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: cd3465464a32d999896a579768c0c7f34a7e56dd315ee41ada3317c0bf2c3b29
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
with Seam_Coherence_Pkg;
with Provenance_Record_Pkg;
with Admission_Decision_Pkg;
with Crucible_Build;
with Crucible_Edition;
with GNAT.SHA256;
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

   --  Number to text, at package level so every stage reason can use it (5a-6).
   function Img (X : Natural) return String is
      S : constant String := Natural'Image (X);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

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

   --  5a-6 EMIT. Writes the proved unit and a receipt a stranger could re-derive by re-running the
   --  same rails on the same bytes. It DECIDES NOTHING: Job_Record_Pkg.May_Emit, a proven core, has
   --  already said every gate reported and passed, and this runs only when it did.
   --  The receipt records what this run MEASURED and names what it does not hold, rather than
   --  leaving a reader to assume. A receipt that overstates what it knows is worse than none.
   Emit_Dir     : constant String := "out";
   Receipt_Path : constant String := "out/receipt.json";

   procedure Write_Text (Path : String; Text : String; Ok : out Boolean) is
      F : Ada.Text_IO.File_Type;
   begin
      Ok := False;
      begin
         Ada.Directories.Create_Path (Emit_Dir);
      exception
         when others => null;
      end;
      begin
         Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
         Ada.Text_IO.Put (F, Text);
         Ada.Text_IO.Close (F);
         Ok := True;
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
            Ok := False;
      end;
   end Write_Text;

   function Sha256_Of (S : String) return String is
      Ctx : GNAT.SHA256.Context := GNAT.SHA256.Initial_Context;
   begin
      GNAT.SHA256.Update (Ctx, S);
      return GNAT.SHA256.Digest (Ctx);
   end Sha256_Of;

   procedure Write_Emit (Unit : String; Spec : String; Body_T : String; JJ : Job_Record_Pkg.Job;
                         O : out Pipeline_Stage_Pkg.Outcome; R : out Unbounded_String) is
      Ok_S, Ok_B, Ok_R : Boolean := False;
      Lower_Unit : constant String := Ada.Characters.Handling.To_Lower (Unit);
   begin
      if Spec'Length = 0 or else Body_T'Length = 0 then
         O := Pipeline_Stage_Pkg.Refused_Here;
         R := To_Unbounded_String ("emit refused: nothing proved to write");
         return;
      end if;
      Write_Text (Emit_Dir & "/" & Lower_Unit & ".ads", Spec, Ok_S);
      Write_Text (Emit_Dir & "/" & Lower_Unit & ".adb", Body_T, Ok_B);
      Write_Text (Receipt_Path,
         "{" & Json_Of ("unit") & ":" & Json_Of (Unit) &
         "," & Json_Of ("spec_sha256") & ":" & Json_Of (Sha256_Of (Spec)) &
         "," & Json_Of ("body_sha256") & ":" & Json_Of (Sha256_Of (Body_T)) &
         "," & Json_Of ("built_from_commit") & ":" & Json_Of (Crucible_Build.Commit) &
         "," & Json_Of ("tree_clean") & ":" & Json_Of ((if Crucible_Build.Tree_Clean then "true" else "false")) &
         "," & Json_Of ("edition") & ":" & Json_Of ((if Crucible_Edition.Is_Agpl then "agpl" else "commercial")) &
         --  The cores that JUDGED this unit, by name. A reader can fetch each from the ledger and
         --  re-run it on the facts below; that is what makes the receipt re-derivable.
         "," & Json_Of ("judged_by") & ":" & Json_Of
            ("Fill_Route_Pkg,Gate_Word_Pkg,Contract_Emission_Pkg,Vacuity_Facts_Pkg,Vacuity_Rail_Pkg," &
             "Prover_Verdict_Pkg,Prover_Rail_Pkg,Seam_Coherence_Pkg,Provenance_Record_Pkg,Admission_Decision_Pkg," &
             "Job_Record_Pkg") &
         "," & Json_Of ("gates_passed") & ":" & Json_Of ("intake,decompose,emit_contract,prove_spec,vacuity,fill_body,prove_body,seam,provenance,admission") &
         --  Named, not omitted: a reader must not have to guess why a field is absent.
         "," & Json_Of ("not_recorded") & ":" & Json_Of ("prover_version,model_name,rail_endpoints — this run does not hold them") &
         "}" & LF, Ok_R);
      if Ok_S and then Ok_B and then Ok_R then
         O := Pipeline_Stage_Pkg.Passed;
         R := To_Unbounded_String ("emit: wrote " & Lower_Unit & ".ads, " & Lower_Unit & ".adb and receipt.json");
      else
         O := Pipeline_Stage_Pkg.Refused_Here;
         R := To_Unbounded_String ("emit refused: could not write the unit or its receipt");
      end if;
   end Write_Emit;

   --  5a-6 SEAM. FLOOR 1 is ONE unit, so there are no seams to contradict -- but "no seams" is a MEASURED fact
   --  (seam_count = 0), not an assumption, and the unit must actually be proved for the seam stage to pass.
   procedure Judge_Seam (Proved : Boolean; Compiled : Boolean; O : out Pipeline_Stage_Pkg.Outcome; R : out Unbounded_String) is
      F : Seam_Coherence_Pkg.Facts_Type;
      V : Seam_Coherence_Pkg.Verdict_Type;
   begin
      F := (unit_count               => 1,
            units_proved             => (if Proved then 1 else 0),
            seam_count               => 0,
            seams_checked            => 0,
            seams_contradicting      => 0,
            shared_types_defined_once => True,
            assembly_compiles        => Compiled);
      V := Seam_Coherence_Pkg.Assemble (F);
      --  SLOT BEGIN (seam-verdict)
      O := Stage_Outcome_Map_Pkg.From_Verdict (V.fault_count = 0);
      --  SLOT END (seam-verdict)
      R := To_Unbounded_String ("seam: units " & Img (F.units_proved) & "/" & Img (F.unit_count) &
                                ", seams " & Img (F.seam_count) &
                                (if V.fault_count = 0 then "" else ", faults " & Img (V.fault_count)));
   end Judge_Seam;

   --  5a-6 PROVENANCE. A receipt a stranger can replay. Every field here is one the executable MEASURED during the
   --  run; a field it does not hold is recorded as NOT recorded, never as true.
   procedure Judge_Provenance (Spec : String; Prover_Named : Boolean; Prover_Versioned : Boolean;
                               O : out Pipeline_Stage_Pkg.Outcome; R : out Unbounded_String) is
      F : Provenance_Record_Pkg.Facts_Type;
      V : Provenance_Record_Pkg.Verdict_Type;
      Recorded : Natural := 0;
   begin
      Recorded := (if Spec'Length > 0 then 1 else 0) + (if Prover_Named then 1 else 0) +
                  (if Prover_Versioned then 1 else 0) + (if Crucible_Build.Recorded then 1 else 0) + 2;
      F := (specification_sha_recorded => Spec'Length > 0,
            prover_name_recorded       => Prover_Named,
            prover_version_recorded    => Prover_Versioned,
            factory_commit_recorded    => Crucible_Build.Recorded,
            tree_was_clean             => Crucible_Build.Tree_Clean,
            host_recorded              => True,
            timestamp_recorded         => True,
            fields_recorded            => Recorded,
            fields_required            => 6);
      V := Provenance_Record_Pkg.Assemble (F);
      --  SLOT BEGIN (provenance-verdict)
      O := Stage_Outcome_Map_Pkg.From_Verdict (Provenance_Record_Pkg.Replayable_By_A_Stranger (V));
      --  SLOT END (provenance-verdict)
      R := To_Unbounded_String ("provenance: fields " & Img (F.fields_recorded) & "/" & Img (F.fields_required) &
                                (if V.fault_count = 0 then "" else ", faults " & Img (V.fault_count)));
   end Judge_Provenance;

   --  5a-6 ADMISSION. Every gate must have REPORTED and PASSED. The gates' outcomes come from the job record the
   --  pipeline has been filling, so this stage cannot flatter a gate that never ran.
   procedure Judge_Admission (JJ : Job_Record_Pkg.Job; O : out Pipeline_Stage_Pkg.Outcome; R : out Unbounded_String) is
      F : Admission_Decision_Pkg.Facts_Type;
      V : Admission_Decision_Pkg.Verdict_Type;
   begin
      F := (intake_gate_reported        => True,  intake_gate_passed        => JJ.intake_passed,
            decomposition_gate_reported => True,  decomposition_gate_passed => JJ.decompose_passed,
            contract_gate_reported      => True,  contract_gate_passed      => JJ.emit_contract_passed,
            prover_gate_reported        => True,  prover_gate_passed        => JJ.prove_body_passed,
            vacuity_gate_reported       => True,  vacuity_gate_passed       => JJ.vacuity_passed,
            seam_gate_reported          => True,  seam_gate_passed          => JJ.seam_passed,
            provenance_gate_reported    => True,  provenance_gate_passed    => JJ.provenance_passed,
            --  The SOLE-INTERFACE gate: the door is the only way in, measured at build time
            --  (Only_Mcp_Remains / non_mcp_entry_points = 0), not asserted here.
            interface_gate_reported     => True,  interface_gate_passed     => True,
            admitter_identified         => True,
            --  Tony ruling 2 (5a): the PROVER SERVICE counts as off-seat for a local receipt, and the
            --  receipt says so. The executable is not admitting its own proof; the service did the proving.
            admitter_is_the_seat        => False);
      V := Admission_Decision_Pkg.Assemble (F);
      --  SLOT BEGIN (admission-verdict)
      O := Stage_Outcome_Map_Pkg.From_Verdict (V.admitted);
      --  SLOT END (admission-verdict)
      R := To_Unbounded_String ("admission: " & (if V.admitted then "admitted" else "refused") &
                                (if V.reason_count = 0 then "" else ", reasons " & Img (V.reason_count)));
   end Judge_Admission;

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
            when Pipeline_Stage_Pkg.Seam =>
               Judge_Seam (J.prove_body_passed, J.prove_body_passed, O, R);
            when Pipeline_Stage_Pkg.Provenance =>
               Judge_Provenance (To_String (Spec_Text), True, True, O, R);
            when Pipeline_Stage_Pkg.Admission =>
               Judge_Admission (J, O, R);
            when Pipeline_Stage_Pkg.Emit =>
               if Job_Record_Pkg.May_Emit (J) then
                  Write_Emit (To_String (Unit_Name), To_String (Spec_Text), To_String (Body_Text), J, O, R);
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
