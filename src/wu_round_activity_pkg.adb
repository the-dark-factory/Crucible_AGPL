--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 94f727bc127771c3544b1ba46564254c24c72ec8bd0a42df424f7d030121c74b
--
--  Wu_Round_Activity_Pkg body -- template (seat-written plumbing) with FOUR slots (gate-facts, route, emission-facts, fit),
--  filled by a Wu edge round. Brief BRIEF_crucible_step5a2_wu_spec_round_2026-09-17 (5a-2f).
--  Lineage 5 (2026-09-28, Tony A11: refusals name the real fault): the earlier slots are frozen; ONE slot, model-reason:
--  the four-parameter Model_Rail_Call_Pkg.Complete hands back a refusal the rail names (prompt_exceeds_context, with
--  the estimated tokens and the budget), and the Reason carries it instead of the bare outcome word.
--  Lineage 6 (2026-09-28, Tony 18:05 "yes do all three qwen fixes", fix 2): the earlier slots are frozen; FOUR slots:
--  focus-fn + focus-call (the first compiler error and the source line it names head the repair section) and
--  prev-letter + progress-check (a round repeating the previous unit byte for byte stops the stage: no_progress,
--  decided by the admitted Round_Progress_Pkg).
--  Lineage 9 (2026-10-18, Tony 17:05 "stick em all in", fix 3 of the fail-loudly audit, items 3 and 6; ruling D7): the
--  earlier slots are frozen; the old Run is now Run_Rounds, unchanged inside but for its catch-all; FIVE slots: log-flags,
--  log-catch and spec-catch (a round-log or spec-file write failure is said on standard error and named in the stage
--  reason), inner-catch (the catch-all names the exception), run-wrapper (the new Run: the last job's state/spec.ads is
--  set aside as state/spec.ads.prev first, then Run_Rounds, then the write-failure notes).
with Ada.Unchecked_Deallocation;
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
with Round_Progress_Pkg;
with Ada.Exceptions;
with Ada.Directories;

package body Wu_Round_Activity_Pkg with SPARK_Mode => Off is

   use Ada.Strings.Unbounded;
   use type Fill_Route_Pkg.Route_Kind;
   use type Round_Budget_Pkg.Round_Result;
   use type Prover_Rail_Pkg.Outcome_Kind;
   use type Pipeline_Stage_Pkg.Outcome;

   Rounds_Path : constant String := "state/rounds.jsonl";
   Spec_Path   : constant String := "state/spec.ads";
   --  SLOT BEGIN (log-flags)
   --  Lineage 9: set when a write of the round log or of the spec file fails during this job; Run names them in the reason.
   Log_Unwritten  : Boolean := False;
   Spec_Unwritten : Boolean := False;
   --  SLOT END (log-flags)

   function Lower (S : String) return String renames Ada.Characters.Handling.To_Lower;

   function Img (N : Natural) return String is
      T : constant String := Natural'Image (N);
   begin
      return T (T'First + 1 .. T'Last);
   end Img;

   function Bool (B : Boolean) return String is (if B then "true" else "false");

   --  Lineage 4 (Tony 2026-09-28 15:42, "fix the delivers naming slip too"): the sheet's FIRST "delivers:" line names
   --  the package when its second word ends in "_Pkg" (a package claim). The claimed word must be a valid name: a
   --  letter first, then letters, digits and underscores (the admitted Intake_Line_Pkg's Is_Letter and Name_Last), no
   --  two underscores together, at most Unit_Extract_Pkg.Max_Name characters; otherwise Claim_Of answers Invalid_Claim
   --  and Emit_Contract refuses by name. A delivers: line whose second word is prose makes no claim ("").
   Invalid_Claim : constant String := "!";

   function Claim_Of (Sheet : String) return String is
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
                    and then Intake_Line_Pkg.Says_Deliverable (L)
                  then
                     declare
                        F : constant Positive := Intake_Line_Pkg.Second_Word_First (L);
                     begin
                        if F <= L'Last then
                           declare
                              W : constant Positive := Intake_Line_Pkg.Word_Last (L, F);
                           begin
                              if W - F + 1 > 4 and then Lower (L (W - 3 .. W)) = "_pkg" then
                                 if Intake_Line_Pkg.Is_Letter (L (F))
                                   and then Intake_Line_Pkg.Name_Last (L, F) = W
                                   and then W - F + 1 <= Unit_Extract_Pkg.Max_Name
                                   and then (for all I in F .. W - 1 => not (L (I) = '_' and then L (I + 1) = '_'))
                                 then
                                    return L (F .. W);
                                 end if;
                                 return Invalid_Claim;
                              end if;
                           end;
                        end if;
                     end;
                     return "";
                  end if;
               end;
            end if;
            Start := P + 1;
         end if;
      end loop;
      return "";
   end Claim_Of;

   --  The package name when the sheet makes no delivers: claim: the sheet's first "function" line's second word (the
   --  admitted Intake_Line_Pkg reads it) & "_Pkg". "" when the sheet has no such line: Emit_Contract then refuses with a
   --  named reason.
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
      --  SLOT BEGIN (log-catch)
      when E : others =>
         --  Lineage 9: a file failure still never changes a stage outcome, but it is said and named (audit item 6).
         Log_Unwritten := True;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
           "emit_contract: " & Rounds_Path & " unwritable: " & Ada.Exceptions.Exception_Name (E));
      --  SLOT END (log-catch)
   end Log_Round;

   procedure Write_Spec (Text : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Spec_Path);
      Ada.Text_IO.Put (F, Text);
      Ada.Text_IO.Close (F);
   exception
      --  SLOT BEGIN (spec-catch)
      when E : others =>
         --  Lineage 9: the spec file was not written; said here and named in the stage reason (audit item 6).
         Spec_Unwritten := True;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
           "emit_contract: " & Spec_Path & " unwritable: " & Ada.Exceptions.Exception_Name (E));
      --  SLOT END (spec-catch)
   end Write_Spec;

   function Json_Of (S : String) return String is
      type Buf_Access is access String;
      procedure Free is new Ada.Unchecked_Deallocation (String, Buf_Access);
      S1  : constant String (1 .. S'Length) := S;
      Enc : Buf_Access := new String (1 .. Natural'Max (1, 6 * S1'Length));
      Len : Natural;
      Ok  : Boolean;
   begin
      Json_String_Pkg.Encode (S1, Enc.all, Len, Ok);
      declare
         Result : constant String := (if Ok then Enc (1 .. Len) else "unencodable");
      begin
         Free (Enc);
         return Result;
      end;
   exception
      when others =>
         Free (Enc);
         raise;
   end Json_Of;

   --  D2 (crucible-report): the prover's own lines for this round, as a JSON field of the round row, so a
   --  refusal on the record names WHICH check failed. Encoded by the proven Json_String_Pkg; when the text
   --  is not encodable the row says so and carries no text -- never a stand-in string.
   function Diag_Field (D : String) return String is
      type Buf_Access is access String;
      procedure Free is new Ada.Unchecked_Deallocation (String, Buf_Access);
      D1  : constant String (1 .. D'Length) := D;
      Enc : Buf_Access := new String (1 .. Natural'Max (1, 6 * D1'Length));
      Len : Natural;
      Ok  : Boolean;
   begin
      Json_String_Pkg.Encode (D1, Enc.all, Len, Ok);
      declare
         Result : constant String :=
           (if Ok then ",""diagnostics"":""" & Enc (1 .. Len) & """" else ",""diagnostics_encoded"":""false""");
      begin
         Free (Enc);
         return Result;
      end;
   exception
      when others =>
         Free (Enc);
         raise;
   end Diag_Field;

   --  Lineage 6 (Tony 2026-09-28 18:05, fix 2): the compiler's FIRST error line and the unit's source line it names,
   --  quoted at the top of the repair section. A measurement, deciding nothing: the first line of Diag holding
   --  ": error:", the decimal number between that line's first and second colon, and the line of Unit with that
   --  number. Empty when Diag holds no error line.
   function First_Error_Focus (Diag : String; Unit : String) return String is
      Marker  : constant String := ": error:";
      E_First : Natural := 0;
      E_Last  : Natural := 0;
      Line_No : Natural := 0;
      S_First : Natural := 0;
      S_Last  : Natural := 0;
      Seen    : Natural := 0;
      LS      : Positive := Diag'First;
   begin
      for P in Diag'Range loop
         if Diag (P) = LF or else P = Diag'Last then
            declare
               E : constant Natural := (if Diag (P) = LF then P - 1 else P);
            begin
               if E >= LS and then E - LS + 1 >= Marker'Length then
                  for K in LS .. E - Marker'Length + 1 loop
                     if Diag (K .. K + Marker'Length - 1) = Marker then
                        E_First := LS;
                        E_Last  := E;
                        exit;
                     end if;
                  end loop;
               end if;
            end;
            exit when E_First > 0;
            if P < Diag'Last then
               LS := P + 1;
            end if;
         end if;
      end loop;
      if E_First = 0 then
         return "";
      end if;
      declare
         C1 : Natural := 0;
         C2 : Natural := 0;
      begin
         for K in E_First .. E_Last loop
            if Diag (K) = ':' then
               if C1 = 0 then
                  C1 := K;
               elsif C2 = 0 then
                  C2 := K;
               end if;
            end if;
         end loop;
         if C1 > 0 and then C2 > C1 + 1 and then C2 - C1 <= 7 then
            for K in C1 + 1 .. C2 - 1 loop
               if Diag (K) in '0' .. '9' then
                  Line_No := Line_No * 10 + (Character'Pos (Diag (K)) - Character'Pos ('0'));
               else
                  Line_No := 0;
                  exit;
               end if;
            end loop;
         end if;
      end;
      if Line_No >= 1 and then Unit'Length > 0 then
         Seen := 1;
         for P in Unit'Range loop
            if Seen = Line_No and then S_First = 0 then
               S_First := P;
            end if;
            if Unit (P) = LF then
               if Seen = Line_No then
                  S_Last := P - 1;
                  exit;
               end if;
               Seen := Seen + 1;
            elsif P = Unit'Last and then Seen = Line_No then
               S_Last := P;
            end if;
         end loop;
      end if;
      return "FIRST ERROR (fix this one first): " & Diag (E_First .. E_Last) & LF &
        (if S_First > 0 and then S_Last >= S_First then "  the line it names: " & Unit (S_First .. S_Last) & LF else "") & LF;
   end First_Error_Focus;

   procedure Run_Rounds
     (Sheet     : String;
      Design    : String;
      Unit_Name : out Unbounded_String;
      Spec_Text : out Unbounded_String;
      Result    : out Pipeline_Stage_Pkg.Outcome;
      Reason    : out Unbounded_String)
   is
      Claim     : constant String := Claim_Of (Sheet);
      Raw_Name  : constant String :=
        (if Claim = Invalid_Claim then "" elsif Claim'Length > 0 then Claim else Unit_Name_Of (Sheet));
      --  First index 1: the proven cores index a Name pattern from 1, and a slice concatenation keeps the slice's
      --  lower bound (found by the 18:53 probe: "unreadable" on every real unit).
      Name      : constant String (1 .. Raw_Name'Length) := Raw_Name;
      S         : Round_Budget_Pkg.Budget_State := Round_Budget_Pkg.Fresh;
      Prev_Unit : Unbounded_String;
      Prev_Diag : Unbounded_String;
      --  Lineage 6: the round letter of the unit held in Prev_Unit (the round a repeat names).
      Prev_Letter : Character := 'A';
      Last_Word : Unbounded_String := To_Unbounded_String ("none");
      Last_Hint : Unbounded_String;   --  Gate_Hint & Substance_Hint of the previous refused round
      Last_Subst : Unbounded_String;  --  the substance faults of the last round whose route passed but may_emit did not
   begin
      Unit_Name := To_Unbounded_String (Name);
      Spec_Text := Null_Unbounded_String;
      Result    := Pipeline_Stage_Pkg.Refused_Here;
      if Claim = Invalid_Claim then
         Reason := To_Unbounded_String
           ("emit_contract refused: the sheet's delivers: line names an invalid package (a letter first, then letters," &
            " digits and single underscores, ending _Pkg, at most" & Natural'Image (Unit_Extract_Pkg.Max_Name) & " characters)");
         return;
      end if;
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
                 First_Error_Focus (To_String (Prev_Diag), To_String (Prev_Unit)) &
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
            Why  : Unbounded_String;   --  lineage 5: a refusal the model rail names (prompt_exceeds_context)
         begin
            Model_Rail_Call_Pkg.Complete (Prompt, Text, MO, Why);
            if not Model_Reply_Pkg.Is_Text (MO) then
               Result := Stage_Outcome_Map_Pkg.From_Model (MO);
               Reason := To_Unbounded_String
                 ("emit_contract: model: " &
                  (if Length (Why) > 0 then To_String (Why) else Lower (Model_Reply_Pkg.Outcome_Kind'Image (MO))));
               Log_Round ("{""stage"":""emit_contract"",""round"":""" & Letter & """,""word"":""unmeasured"",""model"":""" &
                          Lower (Model_Reply_Pkg.Outcome_Kind'Image (MO)) & """}");
               return;
            end if;

            if Text.all'Length = 0 or else Text.all'Length > Unit_Extract_Pkg.Max_Text then
               Log_Round ("{""stage"":""emit_contract"",""round"":""" & Letter & """,""word"":""no-unit"",""why"":""reply size"",""bytes"":""" &
                          Img (Text.all'Length) & """}");
               Last_Word  := To_Unbounded_String ("no-unit");
               Last_Subst := Null_Unbounded_String;
            else
               declare
                  T : String (1 .. Text.all'Length) := Text.all;
               begin
                  Unit_Extract_Pkg.Blank_Fences (T);
                  if not Unit_Extract_Pkg.Is_Unit (T, Name) then
                     Log_Round ("{""stage"":""emit_contract"",""round"":""" & Letter & """,""word"":""no-unit"",""why"":""not one unit named " & Name & """}");
                     Last_Word  := To_Unbounded_String ("no-unit");
                     Last_Subst := Null_Unbounded_String;
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

GF := (unit_compiled => Facts.run.unit_compiled, checks_generated => Facts.run.checks_generated, checks_unproved => Facts.run.checks_unproved, subprograms_skipped => Facts.subprograms_skipped, cheat_markers => Natural (Cheats.reject));

Route := Fill_Route_Pkg.Decide (Gate_Word_Pkg.Word_Of (GF), Gate_Word_Pkg.Compile_Errors_Of (GF), Natural (Cheats.reject), GF.checks_unproved, GF.subprograms_skipped, Undeclared);

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

EF := (operation_count => Natural (Shape.operations), operations_with_postcondition => Natural (Shape.operations_with_post), names_used => 0, names_declared => Natural (Shape.operations), names_undeclared => Undeclared_Names, vocabulary_is_stated => Facts.run.unit_compiled, preconditions_stated => Shape.preconditions >= 1, sheet_states_precondition => Sheet_Pre);
May_Emit := Contract_Emission_Pkg.Assemble (EF).may_emit;

Fit := Route /= Fill_Route_Pkg.Route_Refuse and then May_Emit;
Result := Stage_Outcome_Map_Pkg.From_Verdict (Fit);

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
                                   """,""fit"":""" & Bool (Fit) & """" &
                                   Diag_Field (To_String (Prev_Diag)) & "}");
                        Last_Word := To_Unbounded_String (Gate_Word_Pkg.Word_Of (GF));
                        --  Lineage 4: when the route passed but the substance judge did not, the stage's final reason
                        --  names the admitted Contract_Emission_Pkg's faults and the measured counts (A9: "last: accepted"
                        --  said nothing of why).
                        declare
                           V : constant Contract_Emission_Pkg.Verdict_Type := Contract_Emission_Pkg.Assemble (EF);
                        begin
                           if Route /= Fill_Route_Pkg.Route_Refuse and then not May_Emit then
                              Last_Subst := To_Unbounded_String
                                ((if V.fault_no_operations then "no_operations " else "") &
                                 (if V.fault_missing_postcondition then "missing_postcondition " else "") &
                                 (if V.fault_undeclared_name then "undeclared_name " else "") &
                                 (if V.fault_vocabulary_open then "vocabulary_open " else "") &
                                 (if V.fault_over_bound then "over_bound " else "") &
                                 (if V.fault_precondition_missing then "precondition_missing " else "") &
                                 "(operations=" & Img (Natural (Shape.operations)) &
                                 ", with_post=" & Img (Natural (Shape.operations_with_post)) &
                                 ", pre=" & Img (Natural (Shape.preconditions)) & ")");
                           else
                              Last_Subst := Null_Unbounded_String;
                           end if;
                        end;

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
                        --  Lineage 6 (Tony 2026-09-28 18:05, fix 2): a round whose unit is byte-identical to the previous
                        --  round's made no progress: the model ignored the compiler's lines, and every further round on the
                        --  same prompt is wasted. The admitted Round_Progress_Pkg decides; the stage stops, refused by name.
                        if Unit'Length <= Round_Progress_Pkg.Max_Unit
                          and then Length (Prev_Unit) <= Round_Progress_Pkg.Max_Unit
                          and then Round_Progress_Pkg.Repeated (To_String (Prev_Unit), Unit)
                        then
                           Log_Round ("{""stage"":""emit_contract"",""round"":""" & Letter &
                                      """,""word"":""no_progress"",""repeated"":""" & Prev_Letter & """}");
                           Result := Pipeline_Stage_Pkg.Refused_Here;
                           Reason := To_Unbounded_String
                             ("emit_contract: no_progress (round " & Letter & " repeated round " & Prev_Letter & ")");
                           return;
                        end if;
                        Prev_Letter := Letter;
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
        ("emit_contract refused: budget spent after " & Img (Natural (S.rounds_used)) & " rounds; last: " & To_String (Last_Word) &
         (if Length (Last_Subst) > 0 then "; substance: " & To_String (Last_Subst) else ""));
   exception
      --  SLOT BEGIN (inner-catch)
      when E : others =>
         --  Lineage 9: the catch-all names the exception, in the reason and on standard error (audit item 3).
         Result := Pipeline_Stage_Pkg.Unmeasured_Here;
         Reason := To_Unbounded_String ("emit_contract: internal fault: " & Ada.Exceptions.Exception_Name (E));
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
           "emit_contract: internal fault: " & Ada.Exceptions.Exception_Name (E) & ": " &
           Ada.Exceptions.Exception_Message (E));
      --  SLOT END (inner-catch)
   end Run_Rounds;

   --  SLOT BEGIN (run-wrapper)
   procedure Run
     (Sheet     : String;
      Design    : String;
      Unit_Name : out Unbounded_String;
      Spec_Text : out Unbounded_String;
      Result    : out Pipeline_Stage_Pkg.Outcome;
      Reason    : out Unbounded_String)
   is
      Prev_Path : constant String := Spec_Path & ".prev";
   begin
      Log_Unwritten := False;
      Spec_Unwritten := False;
      --  Lineage 9 (ruling D7): the last job's spec is set aside as state/spec.ads.prev BEFORE this job starts, so a stale
      --  file can never pass for this job's spec, and the last job's evidence stays readable.
      begin
         if Ada.Directories.Exists (Spec_Path) then
            if Ada.Directories.Exists (Prev_Path) then
               Ada.Directories.Delete_File (Prev_Path);
            end if;
            Ada.Directories.Rename (Spec_Path, Prev_Path);
         end if;
      exception
         when E : others =>
            Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
              "emit_contract: " & Spec_Path & " could not be set aside: " & Ada.Exceptions.Exception_Name (E));
      end;
      Run_Rounds (Sheet, Design, Unit_Name, Spec_Text, Result, Reason);
      if Log_Unwritten then
         Append (Reason, "; round log unwritten (" & Rounds_Path & ")");
      end if;
      if Spec_Unwritten then
         Append (Reason, "; spec file unwritten (" & Spec_Path & ")");
      end if;
   end Run;
   --  SLOT END (run-wrapper)

end Wu_Round_Activity_Pkg;
