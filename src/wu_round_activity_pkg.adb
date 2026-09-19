--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: f6a7a8cf952d36d86d28ce13be69f02c93c940c276ff8a7e85fab939e05a8b94
--
--  Wu_Round_Activity_Pkg body -- template (seat-written plumbing) with FOUR slots (gate-facts, route, emission-facts, fit),
--  filled by a Wu edge round. Brief BRIEF_crucible_step5a2_wu_spec_round_2026-09-17 (5a-2f).
with Ada.Text_IO;
with Ada.Characters.Handling;
with Intake_Line_Pkg;
with Model_Rail_Call_Pkg;
with Model_Reply_Pkg;
with Unit_Extract_Pkg;
with Cheat_Marker_Pkg;
with Spec_Shape_Pkg;
with Prover_Rail_Call_Pkg;
with Prover_Rail_Pkg;
with Gate_Word_Pkg;
with Fill_Route_Pkg;
with Round_Budget_Pkg;
with Contract_Emission_Pkg;
with Stage_Outcome_Map_Pkg;
with Json_String_Pkg;

package body Wu_Round_Activity_Pkg with SPARK_Mode => Off is

   use Ada.Strings.Unbounded;
   use type Fill_Route_Pkg.Route_Kind;
   use type Round_Budget_Pkg.Round_Result;
   use type Prover_Rail_Pkg.Outcome_Kind;
   use type Pipeline_Stage_Pkg.Outcome;

   Rounds_Path : constant String := "state/rounds.jsonl";
   Spec_Path   : constant String := "state/spec.ads";

   function Lower (S : String) return String renames Ada.Characters.Handling.To_Lower;

   function Img (N : Natural) return String is
      T : constant String := Natural'Image (N);
   begin
      return T (T'First + 1 .. T'Last);
   end Img;

   function Bool (B : Boolean) return String is (if B then "true" else "false");

   --  The package name: the sheet's first "function" line's second word (the admitted Intake_Line_Pkg reads it) & "_Pkg".
   --  "" when the sheet has no such line: Emit_Contract then refuses with a named reason.
   function Unit_Name_Of (Sheet : String) return String is
      Start : Positive := Sheet'First;
   begin
      for P in Sheet'First .. Sheet'Last + 1 loop
         if P = Sheet'Last + 1 or else Sheet (P) = LF then
            if P > Start then
               declare
                  L : constant String (1 .. P - Start) := Sheet (Start .. P - 1);
               begin
                  if L'Length <= Intake_Line_Pkg.Max_Line
                    and then Intake_Line_Pkg.Skip_Spaces (L, 1) <= L'Last
                    and then Intake_Line_Pkg.First_Word_Is (L, "function")
                  then
                     declare
                        F : constant Positive := Intake_Line_Pkg.Second_Word_First (L);
                     begin
                        if F <= L'Last and then Intake_Line_Pkg.Is_Letter (L (F)) then
                           return L (F .. Intake_Line_Pkg.Name_Last (L, F)) & "_Pkg";
                        end if;
                     end;
                  end if;
               end;
            end if;
            Start := P + 1;
         end if;
      end loop;
      return "";
   end Unit_Name_Of;

   --  One JSON line per round into state/rounds.jsonl (the unit's provenance, as wu-run.sh records a round).
   procedure Log_Round (Line : String) is
      F : Ada.Text_IO.File_Type;
   begin
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.Append_File, Rounds_Path);
      exception
         when Ada.Text_IO.Name_Error =>
            Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Rounds_Path);
      end;
      Ada.Text_IO.Put_Line (F, Line);
      Ada.Text_IO.Close (F);
   exception
      when others =>
         null;   --  a file failure never changes a stage outcome
   end Log_Round;

   procedure Write_Spec (Text : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Spec_Path);
      Ada.Text_IO.Put (F, Text);
      Ada.Text_IO.Close (F);
   exception
      when others =>
         null;
   end Write_Spec;

   function Json_Of (S : String) return String is
      S1  : constant String (1 .. S'Length) := S;
      Enc : String (1 .. Natural'Max (1, 2 * S1'Length));
      Len : Natural;
      Ok  : Boolean;
   begin
      Json_String_Pkg.Encode (S1, Enc, Len, Ok);
      return (if Ok then Enc (1 .. Len) else "unencodable");
   end Json_Of;

   procedure Run
     (Sheet     : String;
      Design    : String;
      Unit_Name : out Unbounded_String;
      Spec_Text : out Unbounded_String;
      Result    : out Pipeline_Stage_Pkg.Outcome;
      Reason    : out Unbounded_String)
   is
      Raw_Name  : constant String := Unit_Name_Of (Sheet);
      --  First index 1: the proven cores index a Name pattern from 1, and a slice concatenation keeps the slice's
      --  lower bound (found by the 18:53 probe: "unreadable" on every real unit).
      Name      : constant String (1 .. Raw_Name'Length) := Raw_Name;
      S         : Round_Budget_Pkg.Budget_State := Round_Budget_Pkg.Fresh;
      Prev_Unit : Unbounded_String;
      Prev_Diag : Unbounded_String;
      Last_Word : Unbounded_String := To_Unbounded_String ("none");
      Last_Hint : Unbounded_String;   --  Gate_Hint & Substance_Hint of the previous refused round
   begin
      Unit_Name := To_Unbounded_String (Name);
      Spec_Text := Null_Unbounded_String;
      Result    := Pipeline_Stage_Pkg.Refused_Here;
      if Name'Length = 0 or else Name'Length > Unit_Extract_Pkg.Max_Name then
         Reason := To_Unbounded_String ("emit_contract refused: the sheet names no function to specify");
         return;
      end if;

      while Round_Budget_Pkg.May_Start (S) loop
         declare
            Letter : constant Character := Round_Budget_Pkg.Round_Letter (S);
            Repair : constant Boolean := Round_Budget_Pkg.Repair_Base_Available (S);
            Repair_Text : constant String :=
              (if Repair then
                 LF & "REPAIR MODE. The previous round emitted the unit shown at the end, and the compiler/prover reported" & LF &
                 "the lines below. Start FROM that unit; do NOT write a new one from scratch. Change ONLY what those lines" & LF &
                 "or the sheet name; re-emit the whole unit." & LF & LF &
                 "WHY IT WAS REFUSED (" & To_String (Last_Word) & "):" & LF & To_String (Last_Hint) & LF &
                 "THE PROVER'S LINES:" & LF &
                 To_String (Prev_Diag) & LF & "THE UNIT THE PREVIOUS ROUND EMITTED:" & LF & To_String (Prev_Unit) & LF
               else "");
            Prompt : constant String :=
              "/no_think" & LF & House_Form & LF & "PACKAGE NAME: " & Name & LF & LF &
              "THE SPECIFICATION SHEET:" & LF & Sheet & LF & LF &
              "THE DESIGN (one subsystem per line):" & LF & Design & LF & Repair_Text;
            Text : Model_Rail_Call_Pkg.Text_Access;
            MO   : Model_Reply_Pkg.Outcome_Kind;
            R    : Round_Budget_Pkg.Round_Result := Round_Budget_Pkg.Result_No_Unit;
         begin
            Model_Rail_Call_Pkg.Complete (Prompt, Text, MO);
            if not Model_Reply_Pkg.Is_Text (MO) then
               Result := Stage_Outcome_Map_Pkg.From_Model (MO);
               Reason := To_Unbounded_String ("emit_contract: model: " & Lower (Model_Reply_Pkg.Outcome_Kind'Image (MO)));
               Log_Round ("{""stage"":""emit_contract"",""round"":""" & Letter & """,""word"":""unmeasured"",""model"":""" &
                          Lower (Model_Reply_Pkg.Outcome_Kind'Image (MO)) & """}");
               return;
            end if;

            if Text.all'Length = 0 or else Text.all'Length > Unit_Extract_Pkg.Max_Text then
               Log_Round ("{""stage"":""emit_contract"",""round"":""" & Letter & """,""word"":""no-unit"",""why"":""reply size"",""bytes"":""" &
                          Img (Text.all'Length) & """}");
            else
               declare
                  T : String (1 .. Text.all'Length) := Text.all;
               begin
                  Unit_Extract_Pkg.Blank_Fences (T);
                  if not Unit_Extract_Pkg.Is_Unit (T, Name) then
                     Log_Round ("{""stage"":""emit_contract"",""round"":""" & Letter & """,""word"":""no-unit"",""why"":""not one unit named " & Name & """}");
                  else
                     declare
                        First : constant Positive := Unit_Extract_Pkg.First_Content (T, Unit_Extract_Pkg.After_Think (T));
                        Last  : constant Natural  := Unit_Extract_Pkg.Last_Content (T);
                        Unit  : constant String (1 .. Last - First + 1) := T (First .. Last);
                        Cheats   : Cheat_Marker_Pkg.Tally;
                        Shape    : Spec_Shape_Pkg.Shape;
                        Declared : Natural := 0;
                        Sheet_Pre : Boolean := False;   --  the SHEET asked for a precondition (Contract_Emission v2)
                        Facts    : Prover_Rail_Pkg.Reply_Facts;
                        PO       : Prover_Rail_Pkg.Outcome_Kind;
                        Diag     : Prover_Rail_Call_Pkg.Text_Access;
                        Undeclared       : Natural := 0;
                        Undeclared_Names : Natural := 0;
                        GF       : Gate_Word_Pkg.Gate_Facts;
                        Route    : Fill_Route_Pkg.Route_Kind := Fill_Route_Pkg.Route_Refuse;
                        EF       : Contract_Emission_Pkg.Facts_Type;
                        May_Emit : Boolean := False;
                        Fit      : Boolean := False;
                        LS       : Positive := 1;
                     begin
                        --  Every line of the unit: the proven marker classifier, the proven shape measurer, and the
                        --  count of BODY-DEFERRED declarations the unit itself makes.
                        for P in 1 .. Unit'Length + 1 loop
                           if P = Unit'Length + 1 or else Unit (P) = LF then
                              if P > LS then
                                 declare
                                    L1 : constant String (1 .. P - LS) := Unit (LS .. P - 1);
                                 begin
                                    Cheats := Cheat_Marker_Pkg.Add (Cheats, Cheat_Marker_Pkg.Marker_Of (L1));
                                    Shape  := Spec_Shape_Pkg.Add (Shape, L1);
                                    if Spec_Shape_Pkg.Contains_CI (L1, "body-deferred:") then
                                       Declared := Declared + 1;
                                    end if;
                                 end;
                              end if;
                              LS := P + 1;
                           end if;
                        end loop;
                        Shape := Spec_Shape_Pkg.Finish (Shape);

                        Prover_Rail_Call_Pkg.Prove_Full (Name, Unit, "", 2, PO, Facts, Diag);
                        if PO /= Prover_Rail_Pkg.Outcome_Proved and then PO /= Prover_Rail_Pkg.Outcome_Not_Proved then
                           Result := Pipeline_Stage_Pkg.Unmeasured_Here;
                           Reason := To_Unbounded_String ("emit_contract: prover rail: " & Lower (Prover_Rail_Pkg.Outcome_Kind'Image (PO)));
                           Log_Round ("{""stage"":""emit_contract"",""round"":""" & Letter & """,""word"":""unmeasured"",""prover"":""" &
                                      Lower (Prover_Rail_Pkg.Outcome_Kind'Image (PO)) & """}");
                           return;
                        end if;

                        --  The rail's error lines that name an undeclared identifier (Contract_Emission's names_undeclared).
                        --  The diagnostics arrive as a slice whose bounds are not 1-based: normalised first (found 19:01).
                        declare
                           D : constant String (1 .. Diag.all'Length) := Diag.all;
                        begin
                           LS := 1;
                           for P in 1 .. D'Length + 1 loop
                              if P = D'Length + 1 or else D (P) = LF then
                                 if P > LS then
                                    declare
                                       L1 : constant String (1 .. P - LS) := D (LS .. P - 1);
                                    begin
                                       if L1'Length <= Spec_Shape_Pkg.Max_Line and then Spec_Shape_Pkg.Is_Undeclared_Name_Error (L1) then
                                          Undeclared_Names := Undeclared_Names + 1;
                                       end if;
                                    end;
                                 end if;
                                 LS := P + 1;
                              end if;
                           end loop;
                           Prev_Diag := To_Unbounded_String
                             (if D'Length <= Max_Repair_Chars then D else D (1 .. Max_Repair_Chars));
                        end;
                        --  Skipped subprograms the unit did not declare deferred (a COUNT: the known weakening, see the brief).
                        Undeclared := (if Facts.subprograms_skipped > Declared then Facts.subprograms_skipped - Declared else 0);

                        --  SLOT BEGIN (gate-facts)
GF := (unit_compiled => Facts.run.unit_compiled, checks_generated => Facts.run.checks_generated, checks_unproved => Facts.run.checks_unproved, subprograms_skipped => Facts.subprograms_skipped, cheat_markers => Natural (Cheats.reject));
                        --  SLOT END (gate-facts)

                        --  SLOT BEGIN (route)
Route := Fill_Route_Pkg.Decide (Gate_Word_Pkg.Word_Of (GF), Gate_Word_Pkg.Compile_Errors_Of (GF), Natural (Cheats.reject), GF.checks_unproved, GF.subprograms_skipped, Undeclared);
                        --  SLOT END (route)

                        --  Contract_Emission_Pkg.Facts_Type fields, in order: operation_count, operations_with_postcondition,
                        --  names_used (default 0), names_declared, names_undeclared, vocabulary_is_stated, preconditions_stated,
                        --  sheet_states_precondition (v2 — set from Sheet_Pre, measured above).
                        --  Contract_Emission v2 (Tony 2026-09-18): a precondition is a fault ONLY when the SHEET
                        --  states one. Measured here from the sheet's own lines, never assumed: v1's fault was
                        --  demanding what the sheet never asked for.
                        declare
                           SS : constant String (1 .. Sheet'Length) := Sheet;
                           K  : Natural := 1;
                        begin
                           for P in 1 .. SS'Length + 1 loop
                              if P = SS'Length + 1 or else SS (P) = Character'Val (10) then
                                 if P > K then
                                    declare
                                       L2 : constant String (1 .. P - K) := SS (K .. P - 1);
                                    begin
                                       if L2'Length <= Spec_Shape_Pkg.Max_Line
                                         and then Spec_Shape_Pkg.Contains_CI (L2, "pre:")
                                       then
                                          Sheet_Pre := True;
                                       end if;
                                    end;
                                 end if;
                                 K := P + 1;
                              end if;
                           end loop;
                        end;

                        --  SLOT BEGIN (emission-facts)
EF := (operation_count => Natural (Shape.operations), operations_with_postcondition => Natural (Shape.operations_with_post), names_used => 0, names_declared => Natural (Shape.operations), names_undeclared => Undeclared_Names, vocabulary_is_stated => Facts.run.unit_compiled, preconditions_stated => Shape.preconditions >= 1, sheet_states_precondition => Sheet_Pre);
May_Emit := Contract_Emission_Pkg.Assemble (EF).may_emit;
                        --  SLOT END (emission-facts)

                        --  SLOT BEGIN (fit)
Fit := Route /= Fill_Route_Pkg.Route_Refuse and then May_Emit;
Result := Stage_Outcome_Map_Pkg.From_Verdict (Fit);
                        --  SLOT END (fit)

                        Log_Round ("{""stage"":""emit_contract"",""round"":""" & Letter &
                                   """,""word"":""" & Gate_Word_Pkg.Word_Of (GF) &
                                   """,""route"":""" & Lower (Fill_Route_Pkg.Route_Kind'Image (Route)) &
                                   """,""compiled"":""" & Bool (GF.unit_compiled) &
                                   """,""generated"":""" & Img (GF.checks_generated) &
                                   """,""unproved"":""" & Img (GF.checks_unproved) &
                                   """,""skipped"":""" & Img (GF.subprograms_skipped) &
                                   """,""declared"":""" & Img (Declared) &
                                   """,""cheats"":""" & Img (Natural (Cheats.reject)) &
                                   """,""review"":""" & Img (Natural (Cheats.review)) &
                                   """,""operations"":""" & Img (Natural (Shape.operations)) &
                                   """,""with_post"":""" & Img (Natural (Shape.operations_with_post)) &
                                   """,""pre"":""" & Img (Natural (Shape.preconditions)) &
                                   """,""undeclared_names"":""" & Img (Undeclared_Names) &
                                   """,""may_emit"":""" & Bool (May_Emit) &
                                   """,""fit"":""" & Bool (Fit) & """}");
                        Last_Word := To_Unbounded_String (Gate_Word_Pkg.Word_Of (GF));

                        if Fit then
                           Spec_Text := To_Unbounded_String (Unit);
                           Write_Spec (Unit);
                           Reason := To_Unbounded_String
                             ("emit_contract: fit at round " & Letter & ": " & Gate_Word_Pkg.Word_Of (GF) & ", " &
                              Lower (Fill_Route_Pkg.Route_Kind'Image (Route)) & ", operations=" & Img (Natural (Shape.operations)));
                           return;
                        end if;
                        R := Round_Budget_Pkg.Result_Refused;
                        declare
                           V : constant Contract_Emission_Pkg.Verdict_Type := Contract_Emission_Pkg.Assemble (EF);
                        begin
                           Last_Hint := To_Unbounded_String
                             (Gate_Hint (Gate_Word_Pkg.Word_Of (GF)) &
                              (if Route /= Fill_Route_Pkg.Route_Refuse and then not May_Emit then
                                 Substance_Hint (V.fault_no_operations, V.fault_missing_postcondition, V.fault_undeclared_name,
                                                 V.fault_vocabulary_open, V.fault_over_bound, not EF.preconditions_stated)
                               else ""));
                        end;
                        Prev_Unit := To_Unbounded_String (Unit);
                        if Length (Prev_Unit) > Max_Repair_Chars then
                           Prev_Unit := Head (Prev_Unit, Max_Repair_Chars);
                        end if;
                     end;
                  end if;
               end;
            end if;
            S := Round_Budget_Pkg.Record_Round (S, R);
         end;
      end loop;

      Result := Pipeline_Stage_Pkg.Refused_Here;
      Reason := To_Unbounded_String
        ("emit_contract refused: budget spent after " & Img (Natural (S.rounds_used)) & " rounds; last: " & To_String (Last_Word));
   exception
      when others =>
         Result := Pipeline_Stage_Pkg.Unmeasured_Here;
         Reason := To_Unbounded_String ("emit_contract: unreadable");
   end Run;

end Wu_Round_Activity_Pkg;
