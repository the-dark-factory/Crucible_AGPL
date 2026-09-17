--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: fa42031539452ab9261f2a59a3e89872ded8fa51425d4dbd5372064d46472309
--
--  Body_Fill_Activity_Pkg body — the template: plumbing fixed by the seat; the FOUR slots are the planner's.
with Ada.Text_IO;
with Ada.Characters.Handling;
with Model_Rail_Call_Pkg;
with Model_Reply_Pkg;
with Unit_Extract_Pkg;
with Body_Unit_Pkg;
with Body_Hygiene_Pkg;
with Idiom_Rewrite_Pkg;
with Duplicate_Completion_Pkg;
with Cheat_Marker_Pkg;
with Prover_Rail_Call_Pkg;
with Prover_Rail_Pkg;
with Gate_Word_Pkg;
with Fill_Route_Pkg;
with Round_Budget_Pkg;
with Diagnosis_Select_Pkg;
with Diagnosis_Activity_Pkg;
with Stage_Outcome_Map_Pkg;

package body Body_Fill_Activity_Pkg with SPARK_Mode => Off is

   use Ada.Strings.Unbounded;
   use type Fill_Route_Pkg.Route_Kind;
   use type Round_Budget_Pkg.Round_Result;
   use type Prover_Rail_Pkg.Outcome_Kind;
   use type Pipeline_Stage_Pkg.Outcome;
   use type Duplicate_Completion_Pkg.Body_State;

   Rounds_Path : constant String := "state/body-rounds.jsonl";
   Body_Path   : constant String := "state/body.adb";

   function Lower (S : String) return String renames Ada.Characters.Handling.To_Lower;

   function Img (N : Natural) return String is
      T : constant String := Natural'Image (N);
   begin
      return T (T'First + 1 .. T'Last);
   end Img;

   function Bool (B : Boolean) return String is (if B then "true" else "false");

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

   procedure Write_Body (Text : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Body_Path);
      Ada.Text_IO.Put (F, Text);
      Ada.Text_IO.Close (F);
   exception
      when others =>
         null;
   end Write_Body;

   --  Idiom splices at PROVEN positions; the result is re-judged CLEAN by the core before it is used. Returns False when
   --  the splice budget is spent or a splice would exceed the judged bound (the round is then refused-hygiene).
   procedure Splice_Idioms (B : in out Unbounded_String; Old_Count, Exists_Count : out Natural; Ok : out Boolean) is
      Splices : Natural := 0;
   begin
      Old_Count := 0; Exists_Count := 0; Ok := True;
      loop
         exit when Length (B) > Body_Hygiene_Pkg.Max_Text or else Splices >= Max_Splices;
         declare
            T : constant String (1 .. Length (B)) := To_String (B);
            P : constant Natural := Idiom_Rewrite_Pkg.First_Old_In_Invariant (T);
         begin
            exit when P = 0;
            B := To_Unbounded_String (T (1 .. P - 1) & "'Loop_Entry" & T (P + 4 .. T'Last));
            Old_Count := Old_Count + 1; Splices := Splices + 1;
         end;
      end loop;
      loop
         exit when Length (B) > Body_Hygiene_Pkg.Max_Text or else Splices >= Max_Splices;
         declare
            T : constant String (1 .. Length (B)) := To_String (B);
            E : constant Natural := Idiom_Rewrite_Pkg.First_Exists (T);
         begin
            exit when E = 0;
            declare
               Bar : constant Positive := Idiom_Rewrite_Pkg.Bar_After (T, E);
            begin
               B := To_Unbounded_String (T (1 .. E - 1) & "for some" & T (E + 6 .. Bar - 1) & "=>" & T (Bar + 1 .. T'Last));
            end;
            Exists_Count := Exists_Count + 1; Splices := Splices + 1;
         end;
      end loop;
      if Length (B) > Body_Hygiene_Pkg.Max_Text then
         Ok := False;
      else
         declare
            T : constant String (1 .. Length (B)) := To_String (B);
         begin
            Ok := Idiom_Rewrite_Pkg.Clean_Of_Old (T) and then Idiom_Rewrite_Pkg.Clean_Of_Exists (T);
         end;
      end if;
   end Splice_Idioms;

   --  Duplicate completions: the proven per-line verdict decides; this only blanks the characters of a BLANK line.
   procedure Blank_Duplicates (Spec : String; T : in out String; Lines_Blanked : out Natural) is
      S  : Duplicate_Completion_Pkg.Body_Scan := Duplicate_Completion_Pkg.Fresh;
      LS : Positive := 1;
   begin
      Lines_Blanked := 0;
      for P in 1 .. T'Length + 1 loop
         if P = T'Length + 1 or else T (P) = LF then
            if P > LS then
               S := Duplicate_Completion_Pkg.Add (S, Spec, T, LS, P - 1);
               if S.blank then
                  for K in LS .. P - 1 loop
                     T (K) := ' ';
                  end loop;
                  Lines_Blanked := Lines_Blanked + 1;
               end if;
            end if;
            LS := P + 1;
         end if;
      end loop;
   end Blank_Duplicates;

   procedure Run
     (Spec_Text : String;
      Unit_Name : String;
      Body_Text : out Unbounded_String;
      Result    : out Pipeline_Stage_Pkg.Outcome;
      Reason    : out Unbounded_String)
   is
      Spec      : constant String (1 .. Spec_Text'Length) := Spec_Text;
      Name      : constant String (1 .. Unit_Name'Length) := Unit_Name;
      S         : Round_Budget_Pkg.Budget_State := Round_Budget_Pkg.Fresh;
      DS        : Diagnosis_Select_Pkg.Select_State := Diagnosis_Select_Pkg.Fresh;
      Prev_Body : Unbounded_String;
      Prev_Diag : Unbounded_String;
      Last_Word : Unbounded_String := To_Unbounded_String ("none");
      Last_Hint : Unbounded_String;
      Last_Class : Unbounded_String := To_Unbounded_String ("none");
   begin
      Body_Text := Null_Unbounded_String;
      Result    := Pipeline_Stage_Pkg.Refused_Here;
      if Name'Length = 0 or else Name'Length > Unit_Extract_Pkg.Max_Name
        or else Spec'Length = 0 or else Spec'Length > Body_Hygiene_Pkg.Max_Text
      then
         Reason := To_Unbounded_String ("fill_body refused: no unit name or the specification is out of bounds");
         return;
      end if;

      --  A specification whose subprograms are all completed needs no body (Ada forbids one): judge the spec alone.
      declare
         Facts : Prover_Rail_Pkg.Reply_Facts;
         PO    : Prover_Rail_Pkg.Outcome_Kind;
         Diag  : Prover_Rail_Call_Pkg.Text_Access;
      begin
         Prover_Rail_Call_Pkg.Prove_Full (Name, Spec, "", 2, PO, Facts, Diag);
         if PO /= Prover_Rail_Pkg.Outcome_Proved and then PO /= Prover_Rail_Pkg.Outcome_Not_Proved then
            Result := Pipeline_Stage_Pkg.Unmeasured_Here;
            Reason := To_Unbounded_String ("fill_body: prover rail: " & Lower (Prover_Rail_Pkg.Outcome_Kind'Image (PO)));
            Log_Round ("{""stage"":""fill_body"",""round"":""0"",""word"":""unmeasured"",""prover"":""" &
                       Lower (Prover_Rail_Pkg.Outcome_Kind'Image (PO)) & """}");
            return;
         end if;
         if Facts.subprograms_skipped = 0 and then Facts.run.unit_compiled
           and then Facts.run.checks_generated >= 1 and then Facts.run.checks_unproved = 0
         then
            Result := Pipeline_Stage_Pkg.Passed;
            Reason := To_Unbounded_String ("fill_body: spec-only discharge (every subprogram completed; no body is legal), 0 rounds");
            Log_Round ("{""stage"":""fill_body"",""round"":""0"",""word"":""accepted"",""spec_only"":""true"",""generated"":""" &
                       Img (Facts.run.checks_generated) & """}");
            return;
         end if;
      end;

      while Round_Budget_Pkg.May_Start (S) loop
         declare
            Letter : constant Character := Round_Budget_Pkg.Round_Letter (S);
            Repair : constant Boolean := Round_Budget_Pkg.Repair_Base_Available (S);
            Repair_Text : constant String :=
              (if Repair then
                 LF & "REPAIR MODE. The previous round emitted the body shown at the end, and the compiler/prover reported" & LF &
                 "the lines below. Start FROM that body; do NOT write a new one from scratch. Change ONLY what the" & LF &
                 "diagnosis and the lines name; keep every other line exactly as it is; re-emit the whole body." & LF & LF &
                 "WHY IT WAS REFUSED (" & To_String (Last_Word) & "):" & LF & To_String (Last_Hint) & LF &
                 "THE PROVER'S LINES:" & LF & To_String (Prev_Diag) & LF &
                 "THE BODY THE PREVIOUS ROUND EMITTED:" & LF & To_String (Prev_Body) & LF
               else "");
            Prompt : constant String :=
              Body_Form & LF & "PACKAGE NAME: " & Name & LF & LF & "THE SPECIFICATION:" & LF & Spec & LF & Repair_Text;
            Text : Model_Rail_Call_Pkg.Text_Access;
            MO   : Model_Reply_Pkg.Outcome_Kind;
            R    : Round_Budget_Pkg.Round_Result := Round_Budget_Pkg.Result_No_Unit;
         begin
            Model_Rail_Call_Pkg.Complete (Prompt, Text, MO);
            if not Model_Reply_Pkg.Is_Text (MO) then
               Result := Stage_Outcome_Map_Pkg.From_Model (MO);
               Reason := To_Unbounded_String ("fill_body: model: " & Lower (Model_Reply_Pkg.Outcome_Kind'Image (MO)));
               Log_Round ("{""stage"":""fill_body"",""round"":""" & Letter & """,""word"":""unmeasured"",""model"":""" &
                          Lower (Model_Reply_Pkg.Outcome_Kind'Image (MO)) & """}");
               return;
            end if;
            if Text.all'Length = 0 or else Text.all'Length > Unit_Extract_Pkg.Max_Text then
               Log_Round ("{""stage"":""fill_body"",""round"":""" & Letter & """,""word"":""no-unit"",""why"":""reply size"",""bytes"":""" &
                          Img (Text.all'Length) & """}");
            else
               declare
                  T : String (1 .. Text.all'Length) := Text.all;
               begin
                  Unit_Extract_Pkg.Blank_Fences (T);
                  if not Body_Unit_Pkg.Is_Body (T, Name) then
                     Log_Round ("{""stage"":""fill_body"",""round"":""" & Letter & """,""word"":""no-unit"",""why"":""not one body named " & Name & """}");
                  else
                     declare
                        First : constant Positive := Unit_Extract_Pkg.First_Content (T, Unit_Extract_Pkg.After_Think (T));
                        Last  : constant Natural  := Unit_Extract_Pkg.Last_Content (T);
                        Raw   : String (1 .. Last - First + 1) := T (First .. Last);
                        Aspects_Blanked : Natural := 0;
                        Spark_Mode_Added : Boolean := False;
                        Old_Count, Exists_Count, Dup_Lines : Natural := 0;
                        Hygiene_Ok : Boolean := True;
                        B : Unbounded_String;
                     begin
                        --  1. Contract aspects copied onto body subprograms: blanked in place (proven region).
                        declare
                           Before : constant String := Raw;
                        begin
                           Body_Hygiene_Pkg.Blank_Aspects (Raw);
                           for K in Raw'Range loop
                              if Raw (K) /= Before (K) then
                                 Aspects_Blanked := Aspects_Blanked + 1;
                              end if;
                           end loop;
                        end;
                        --  2. SPARK_Mode on the body header: spliced before the header's  is  at the proven position.
                        if Body_Hygiene_Pkg.Needs_Spark_Mode (Spec, Raw) then
                           declare
                              E : constant Positive := Body_Hygiene_Pkg.First_Head_Is (Raw);
                           begin
                              B := To_Unbounded_String (Raw (1 .. E - 1) & "with SPARK_Mode " & Raw (E .. Raw'Last));
                              Spark_Mode_Added := True;
                           end;
                        else
                           B := To_Unbounded_String (Raw);
                        end if;
                        --  3. Idioms: 'Old inside a loop invariant, exists ... | ; re-judged CLEAN after the splices.
                        Splice_Idioms (B, Old_Count, Exists_Count, Hygiene_Ok);
                        if not Hygiene_Ok then
                           Log_Round ("{""stage"":""fill_body"",""round"":""" & Letter & """,""word"":""refused-hygiene"",""old_rewrites"":""" &
                                      Img (Old_Count) & """,""exists_rewrites"":""" & Img (Exists_Count) & """}");
                           Last_Word := To_Unbounded_String ("refused-hygiene");
                           Last_Hint := To_Unbounded_String (Gate_Hint ("refused-hygiene"));
                           Prev_Body := B;
                           R := Round_Budget_Pkg.Result_Refused;
                        else
                           declare
                              Unit : String (1 .. Length (B)) := To_String (B);
                              Cheats   : Cheat_Marker_Pkg.Tally;
                              Facts    : Prover_Rail_Pkg.Reply_Facts;
                              PO       : Prover_Rail_Pkg.Outcome_Kind;
                              Diag     : Prover_Rail_Call_Pkg.Text_Access;
                              GF       : Gate_Word_Pkg.Gate_Facts;
                              Route    : Fill_Route_Pkg.Route_Kind := Fill_Route_Pkg.Route_Refuse;
                              Fit      : Boolean := False;
                              LS       : Positive := 1;
                              D_Text, D_Class, D_Cat, D_Source : Unbounded_String;
                           begin
                              --  4. Duplicate completions: the proven per-line verdict; BLANK lines are blanked here.
                              Blank_Duplicates (Spec, Unit, Dup_Lines);
                              --  5. Proof-bypass markers, per line.
                              for P in 1 .. Unit'Length + 1 loop
                                 if P = Unit'Length + 1 or else Unit (P) = LF then
                                    if P > LS then
                                       declare
                                          L1 : constant String (1 .. P - LS) := Unit (LS .. P - 1);
                                       begin
                                          Cheats := Cheat_Marker_Pkg.Add (Cheats, Cheat_Marker_Pkg.Marker_Of (L1));
                                       end;
                                    end if;
                                    LS := P + 1;
                                 end if;
                              end loop;
                              --  6. The prover judges spec + body together.
                              Prover_Rail_Call_Pkg.Prove_Full (Name, Spec, Unit, 2, PO, Facts, Diag);
                              if PO /= Prover_Rail_Pkg.Outcome_Proved and then PO /= Prover_Rail_Pkg.Outcome_Not_Proved then
                                 Result := Pipeline_Stage_Pkg.Unmeasured_Here;
                                 Reason := To_Unbounded_String ("fill_body: prover rail: " & Lower (Prover_Rail_Pkg.Outcome_Kind'Image (PO)));
                                 Log_Round ("{""stage"":""fill_body"",""round"":""" & Letter & """,""word"":""unmeasured"",""prover"":""" &
                                            Lower (Prover_Rail_Pkg.Outcome_Kind'Image (PO)) & """}");
                                 return;
                              end if;
                              declare
                                 D : constant String (1 .. Diag.all'Length) := Diag.all;
                              begin
                                 Prev_Diag := To_Unbounded_String
                                   (if D'Length <= Max_Repair_Chars then D else D (1 .. Max_Repair_Chars));
                              end;

                              --  SLOT BEGIN (gate-facts)
GF := (unit_compiled => Facts.run.unit_compiled, checks_generated => Facts.run.checks_generated, checks_unproved => Facts.run.checks_unproved, subprograms_skipped => Facts.subprograms_skipped, cheat_markers => Natural (Cheats.reject));
                              --  SLOT END (gate-facts)

                              --  SLOT BEGIN (route)
Route := Fill_Route_Pkg.Decide (Gate_Word_Pkg.Word_Of (GF), Gate_Word_Pkg.Compile_Errors_Of (GF), Natural (Cheats.reject), GF.checks_unproved, GF.subprograms_skipped, GF.subprograms_skipped);
                              --  SLOT END (route)

                              --  SLOT BEGIN (fit)
Fit := Route = Fill_Route_Pkg.Route_Fill;
Result := Stage_Outcome_Map_Pkg.From_Verdict (Fit);
                              --  SLOT END (fit)

                              Last_Word := To_Unbounded_String (Gate_Word_Pkg.Word_Of (GF));
                              if not Fit then
                                 --  ONE diagnosis per round (5a-3): the paragraph the repair section carries.
                                 --  SLOT BEGIN (diagnosis)
Diagnosis_Activity_Pkg.Diagnose (Diag.all, Spec, Unit, DS, D_Text, D_Class, D_Cat, D_Source);
                                 --  SLOT END (diagnosis)
                                 Last_Class := (if Length (D_Class) > 0 then D_Class else To_Unbounded_String ("none"));
                              end if;
                              Log_Round ("{""stage"":""fill_body"",""round"":""" & Letter &
                                         """,""word"":""" & Gate_Word_Pkg.Word_Of (GF) &
                                         """,""route"":""" & Lower (Fill_Route_Pkg.Route_Kind'Image (Route)) &
                                         """,""compiled"":""" & Bool (GF.unit_compiled) &
                                         """,""generated"":""" & Img (GF.checks_generated) &
                                         """,""unproved"":""" & Img (GF.checks_unproved) &
                                         """,""skipped"":""" & Img (GF.subprograms_skipped) &
                                         """,""cheats"":""" & Img (Natural (Cheats.reject)) &
                                         """,""aspects_blanked"":""" & Img (Aspects_Blanked) &
                                         """,""spark_mode_added"":""" & Bool (Spark_Mode_Added) &
                                         """,""old_rewrites"":""" & Img (Old_Count) &
                                         """,""exists_rewrites"":""" & Img (Exists_Count) &
                                         """,""duplicate_lines"":""" & Img (Dup_Lines) &
                                         """,""diagnosis_class"":""" & To_String (D_Class) &
                                         """,""catalogue"":""" & To_String (D_Cat) &
                                         """,""source"":""" & To_String (D_Source) &
                                         """,""fit"":""" & Bool (Fit) & """}");
                              if Fit then
                                 Body_Text := To_Unbounded_String (Unit);
                                 Write_Body (Unit);
                                 Reason := To_Unbounded_String
                                   ("fill_body: fit at round " & Letter & ": " & Gate_Word_Pkg.Word_Of (GF) &
                                    ", generated=" & Img (GF.checks_generated));
                                 return;
                              end if;
                              R := Round_Budget_Pkg.Result_Refused;
                              Last_Hint := To_Unbounded_String (Gate_Hint (Gate_Word_Pkg.Word_Of (GF)) & LF & To_String (D_Text));
                              Prev_Body := To_Unbounded_String (Unit);
                              if Length (Prev_Body) > Max_Repair_Chars then
                                 Prev_Body := Head (Prev_Body, Max_Repair_Chars);
                              end if;
                           end;
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
        ("fill_body refused: budget spent after " & Img (Natural (S.rounds_used)) & " rounds; last: " &
         To_String (Last_Word) & "; last class: " & To_String (Last_Class));
   exception
      when others =>
         Result := Pipeline_Stage_Pkg.Unmeasured_Here;
         Reason := To_Unbounded_String ("fill_body: unreadable");
   end Run;

end Body_Fill_Activity_Pkg;
