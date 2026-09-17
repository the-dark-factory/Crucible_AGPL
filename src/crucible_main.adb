--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: eb8b6c9295440f4df37878ea3a2fad2cb1f13523e0cbe7208a1b5297194e7a0f
--
--  Crucible_Main v7 -- the door's edge: a read loop, one declare block, one call into the frame
--  decider, one case over the action calling the proved cores. It holds no decision.
--  v5 (CRUCIBLE v0.2.0 step 4a) adds the intake_check tool: the sheet argument is decoded by the proven
--  Json_String_Pkg, split on line feeds into Intake_Measure_Pkg.Sheet (bounded; a sheet that does not fit is
--  refused, never measured on a prefix), measured by Intake_Measure_Pkg.Measure and judged by
--  Intake_Refusal_Pkg.Assemble. The tool result text is the same one line harness/intake_main prints.
--  Template (seat-written plumbing, v4 unchanged around it) with ONE slot (gaps), filled by a Wu edge round;
--  brief BRIEF_crucible_step4_wiring_2026-09-17.
--  v6 (step 4b) adds the prove_unit tool: unit, spec, body and level are read from the call, spec and body decoded
--  by Json_String_Pkg, and Prover_Rail_Call_Pkg.Prove gathers the rail facts; the outcome is decided by the
--  proven Prover_Rail_Pkg.Decide. Second slot (outcome_word) turns that outcome into its word.
--  v7 (step 4c) adds the forge tool: the sheet is decoded as for intake_check and carried through Pipeline_Run_Pkg, whose
--  every step is decided by proven cores (Pipeline_Stage_Pkg, Job_Record_Pkg, Stage_Outcome_Map_Pkg); the reply is its report.
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Json_Scan_Pkg;
with Json_String_Pkg;
with Frame_Facts_Pkg;
with Json_Rpc_Frame_Pkg;
with Edition_Licence_Pkg;
with Crucible_Edition;
with Tool_Run_Pkg;
with Reply_Text_Pkg;
with Intake_Line_Pkg;
with Intake_Names_Pkg;
with Intake_Measure_Pkg;
with Intake_Refusal_Pkg;
with Prover_Rail_Pkg;
with Prover_Rail_Call_Pkg;
with Pipeline_Stage_Pkg;
with Pipeline_Run_Pkg;
with Ada.Characters.Handling;

procedure Crucible_Main is
   Null_Id       : constant String := "null";
   Server_Agpl   : constant String := "crucible-agpl";
   Server_Comm   : constant String := "crucible-commercial";
   Bad_Tool_Msg  : constant String := "unknown tool";
   Frame_Msg     : constant String := "request refused by the frame decider";
   Server_Name   : constant String :=
     (if Crucible_Edition.Is_Agpl then Server_Agpl else Server_Comm);
   Max_Line_Bytes : constant := 1_048_576;  --  one limit across the factory (Tony 2026-09-17: 1 MiB door)
   type Buffer_Access is access String;
   Buffer        : constant Buffer_Access := new String (1 .. Max_Line_Bytes);
   Last          : Natural;

   use type Json_Rpc_Frame_Pkg.Reply_Type;
   use type Json_Rpc_Frame_Pkg.Action_Type;
   use type Frame_Facts_Pkg.Tool_Type;
   use type Json_Scan_Pkg.Kind_Type;

   type Sheet_Access is access Intake_Measure_Pkg.Sheet;
   type Origin_Array is array (Intake_Measure_Pkg.Line_Index) of Positive;
   type Origin_Access is access Origin_Array;

   S      : constant Sheet_Access := new Intake_Measure_Pkg.Sheet;
   Origin : constant Origin_Access := new Origin_Array'(others => 1);

   --  A Natural as decimal digits with no leading space.
   function Img (N : Natural) return String is
      T : constant String := Natural'Image (N);
   begin
      return T (T'First + 1 .. T'Last);
   end Img;

   --  The intake_check tool: the one-line verdict text for the sheet argument of Line.
   function Intake_Check_Text (Line : String) return String is
      use Ada.Strings.Unbounded;
      Reply  : Unbounded_String;
      First  : Boolean := True;

      procedure Append (Text : String) is
      begin
         Append (Reply, Text);
      end Append;

      procedure Add_Gap (Word : String) is
      begin
         if not First then
            Append (",");
         end if;
         Append ("""" & Word & """");
         First := False;
      end Add_Gap;

      Span     : constant Json_Scan_Pkg.Span_Type := Frame_Facts_Pkg.Sheet_Span (Line);
      Raw_Span : Json_Scan_Pkg.Span_Type;
      Count    : Intake_Measure_Pkg.Line_Count := 0;
      File_Line : Natural := 0;
   begin
      S.Count := 0;
      for I in Intake_Measure_Pkg.Line_Index loop
         S.Lines (I).Len := 0;
      end loop;

      --  An absent or non-string sheet, or an empty one, is measured as an empty sheet.
      if Span.found and then Span.kind = Json_Scan_Pkg.K_String and then Span.first < Span.last then
         Raw_Span := Json_Scan_Pkg.String_Contents (Line, Span);
         if Raw_Span.first <= Raw_Span.last then
            declare
               Raw     : constant String (1 .. Raw_Span.last - Raw_Span.first + 1) :=
                 Line (Raw_Span.first .. Raw_Span.last);
               Decoded : String (1 .. Raw'Length);
               Dec_Len : Natural;
               Ok      : Boolean;
               Start   : Positive := 1;
            begin
               Json_String_Pkg.Decode (Raw, Decoded, Dec_Len, Ok);
               if not Ok then
                  return "{""verdict"":""input_refused"",""reason"":""bad_string""}";
               end if;
               --  Split the decoded text on line feeds, exactly as harness/intake_main reads lines.
               for P in 1 .. Dec_Len + 1 loop
                  if P = Dec_Len + 1 or else Decoded (P) = Json_String_Pkg.LF then
                     if P > Start or else P <= Dec_Len then
                        File_Line := File_Line + 1;
                        declare
                           Text  : constant String := Decoded (Start .. P - 1);
                           Blank : Boolean := True;
                        begin
                           if Text'Length > Intake_Line_Pkg.Max_Line then
                              return "{""verdict"":""input_refused"",""reason"":""line_too_long"",""line"":""" &
                                Img (File_Line) & """}";
                           end if;
                           for C of Text loop
                              if not Intake_Line_Pkg.Is_Space (C) then
                                 Blank := False;
                              end if;
                           end loop;
                           if not Blank then
                              if Count = Intake_Measure_Pkg.Max_Lines then
                                 return "{""verdict"":""input_refused"",""reason"":""too_many_lines"",""limit"":""" &
                                   Img (Intake_Measure_Pkg.Max_Lines) & """}";
                              end if;
                              Count := Count + 1;
                              S.Lines (Count).Text (1 .. Text'Length) := Text;
                              S.Lines (Count).Len := Text'Length;
                              Origin (Count) := File_Line;
                           end if;
                        end;
                     end if;
                     Start := P + 1;
                  end if;
               end loop;
            end;
         end if;
      end if;
      S.Count := Count;

      declare
         Facts : constant Intake_Refusal_Pkg.Facts_Type := Intake_Measure_Pkg.Measure (S.all);
         V     : constant Intake_Refusal_Pkg.Verdict_Type := Intake_Refusal_Pkg.Assemble (Facts);
      begin
         if V.may_forge then
            return "{""verdict"":""may_forge"",""operation_count"":""" & Img (V.operation_count) & """}";
         end if;

         Append ("{""verdict"":""refused"",""gaps"":[");
         --  SLOT BEGIN (gaps)
if V.gap_no_deliverable then Add_Gap ("no_deliverable"); end if;
if V.gap_no_operations then Add_Gap ("no_operations"); end if;
if V.gap_operations_not_functions then Add_Gap ("operations_not_functions"); end if;
if V.gap_contracts_incomplete then Add_Gap ("contracts_incomplete"); end if;
if V.gap_vocabulary_unsound then Add_Gap ("vocabulary_unsound"); end if;
         --  SLOT END (gaps)
         Append ("],""operation_count"":""" & Img (V.operation_count) & """");
         Append (",""undefined_name_count"":""" & Img (V.undefined_name_count) & """");

         if V.undefined_name_count > 0 then
            declare
               Place : constant Intake_Measure_Pkg.Name_Place := Intake_Measure_Pkg.First_Undefined (S.all);
            begin
               if Place.Line /= 0 then
                  declare
                     Text   : constant String := Intake_Measure_Pkg.Text_Of (S.all, Place.Line);
                     Last_P : constant Positive := Intake_Names_Pkg.Used_Name_End (Text, Place.Pos);
                  begin
                     Append (",""first_undefined"":{""line"":""" & Img (Origin (Place.Line)) &
                             """,""name"":""" & Text (Place.Pos .. Last_P) & """}");
                  end;
               end if;
            end;
         end if;

         Append ("}");
         return To_String (Reply);
      end;
   exception
      when others =>
         return "{""verdict"":""input_refused"",""reason"":""unreadable""}";
   end Intake_Check_Text;

   --  The prove_unit tool: the one-line outcome text for the unit, spec, body and level arguments of Line.
   function Prove_Unit_Text (Line : String) return String is
      type Text_Access is access String;

      --  A string argument's raw contents, or "" when absent, not a string, or empty.
      function Raw_Of (S : Json_Scan_Pkg.Span_Type) return String is
      begin
         if S.found and then S.kind = Json_Scan_Pkg.K_String and then S.first < S.last then
            declare
               C : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, S);
            begin
               if C.first <= C.last then
                  return Line (C.first .. C.last);
               end if;
            end;
         end if;
         return "";
      end Raw_Of;

      Unit_Raw  : constant String := Raw_Of (Frame_Facts_Pkg.Unit_Span (Line));
      Spec_Raw  : constant String := Raw_Of (Frame_Facts_Pkg.Spec_Span (Line));
      Body_Raw  : constant String := Raw_Of (Frame_Facts_Pkg.Body_Span (Line));
      Level_Raw : constant String := Raw_Of (Frame_Facts_Pkg.Level_Span (Line));
      Spec_R    : constant String (1 .. Spec_Raw'Length) := Spec_Raw;
      Body_R    : constant String (1 .. Body_Raw'Length) := Body_Raw;
      Spec_Buf  : constant Text_Access := new String (1 .. Natural'Max (1, Spec_R'Length));
      Body_Buf  : constant Text_Access := new String (1 .. Natural'Max (1, Body_R'Length));
      Spec_Len, Body_Len : Natural;
      Spec_Ok, Body_Ok   : Boolean;
      Level     : Natural := 0;
      O         : Prover_Rail_Pkg.Outcome_Kind;
   begin
      Json_String_Pkg.Decode (Spec_R, Spec_Buf.all, Spec_Len, Spec_Ok);
      Json_String_Pkg.Decode (Body_R, Body_Buf.all, Body_Len, Body_Ok);
      if not (Spec_Ok and then Body_Ok) then
         return "{""outcome"":""input_refused"",""reason"":""bad_string""}";
      end if;
      begin
         Level := Natural'Value (Level_Raw);
      exception
         when Constraint_Error =>
            Level := 0;   --  an unreadable level is 0, which the proven May_Send refuses
      end;
      O := Prover_Rail_Call_Pkg.Prove (Unit_Raw, Spec_Buf (1 .. Spec_Len), Body_Buf (1 .. Body_Len), Level);
      declare
         Word : constant String := (
         --  SLOT BEGIN (outcome_word)
case O is
     when Prover_Rail_Pkg.Outcome_Not_Sent => "not_sent",
     when Prover_Rail_Pkg.Outcome_Prover_Unreachable => "prover_unreachable",
     when Prover_Rail_Pkg.Outcome_Unmeasured => "unmeasured",
     when Prover_Rail_Pkg.Outcome_Reply_Refused => "reply_refused",
     when Prover_Rail_Pkg.Outcome_Not_Proved => "not_proved",
     when Prover_Rail_Pkg.Outcome_Proved => "proved"
         --  SLOT END (outcome_word)
         );
      begin
         return "{""outcome"":""" & Word & """}";
      end;
   exception
      when others =>
         return "{""outcome"":""input_refused"",""reason"":""unreadable""}";
   end Prove_Unit_Text;

   --  The forge tool: the one-line pipeline report for the sheet argument of Line.
   function Forge_Text (Line : String) return String is
      use Ada.Strings.Unbounded;
      function Low (S : String) return String renames Ada.Characters.Handling.To_Lower;
      Span : constant Json_Scan_Pkg.Span_Type := Frame_Facts_Pkg.Sheet_Span (Line);
   begin
      if not (Span.found and then Span.kind = Json_Scan_Pkg.K_String and then Span.first < Span.last) then
         return "{""final"":""refused"",""stopped_at"":""intake"",""reason"":""no sheet""}";
      end if;
      declare
         C       : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, Span);
         Raw     : constant String (1 .. Natural'Max (0, C.last - C.first + 1)) := Line (C.first .. C.last);
         Decoded : String (1 .. Natural'Max (1, Raw'Length));
         Dec_Len : Natural;
         Ok      : Boolean;
      begin
         Json_String_Pkg.Decode (Raw, Decoded, Dec_Len, Ok);
         if not Ok then
            return "{""final"":""refused"",""stopped_at"":""intake"",""reason"":""bad_string""}";
         end if;
         declare
            R       : constant Pipeline_Run_Pkg.Report := Pipeline_Run_Pkg.Run (Decoded (1 .. Dec_Len));
            Why     : constant String := To_String (R.Reason);
            W1      : constant String (1 .. Why'Length) := Why;
            Enc     : String (1 .. Natural'Max (1, 2 * W1'Length));
            Enc_Len : Natural;
            Enc_Ok  : Boolean;
         begin
            Json_String_Pkg.Encode (W1, Enc, Enc_Len, Enc_Ok);
            return "{""final"":""" & Low (Pipeline_Stage_Pkg.Stage'Image (R.Final)) &
              """,""stopped_at"":""" & Low (Pipeline_Stage_Pkg.Stage'Image (R.Stopped_At)) &
              """,""transitions"":""" & Img (R.Transitions) &
              """,""emit_allowed"":""" & (if R.Emit_Allowed then "true" else "false") &
              """,""reason"":""" & (if Enc_Ok then Enc (1 .. Enc_Len) else "unencodable") & """}";
         end;
      end;
   exception
      when others =>
         return "{""final"":""unmeasured"",""stopped_at"":""intake"",""reason"":""unreadable""}";
   end Forge_Text;

begin
   while not Ada.Text_IO.End_Of_File loop
      Ada.Text_IO.Get_Line (Buffer.all, Last);
      declare
         Line  : constant String := Buffer.all (1 .. Last);
         Facts : constant Json_Rpc_Frame_Pkg.Facts_Type := Frame_Facts_Pkg.Facts_Of (Line);
         V     : constant Json_Rpc_Frame_Pkg.Verdict_Type := Json_Rpc_Frame_Pkg.Assemble (Facts);
         Span  : constant Json_Scan_Pkg.Span_Type := Frame_Facts_Pkg.Id_Span (Line);
         Id    : constant String (1 .. (if Span.found then Span.last - Span.first + 1 else Null_Id'Length)) :=
           (if Span.found then Line (Span.first .. Span.last) else Null_Id);
      begin
         if V.reply = Json_Rpc_Frame_Pkg.Reply_Error then
            Ada.Text_IO.Put_Line (Reply_Text_Pkg.Error_Reply (Id, V.error_code, Frame_Msg));
         elsif V.reply = Json_Rpc_Frame_Pkg.Reply_Result then
            case V.action is
               when Json_Rpc_Frame_Pkg.Do_Initialize =>
                  Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Initialize_Result (Server_Name)));
               when Json_Rpc_Frame_Pkg.Do_List_Tools =>
                  Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tools_List_Result));
               when Json_Rpc_Frame_Pkg.Do_Call_Tool =>
                  if Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Licence_Gate then
                     Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Tool_Run_Pkg.Licence_Gate (Crucible_Edition.Current, Line))));
                  elsif Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Intake_Check then
                     Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Intake_Check_Text (Line))));
                  elsif Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Prove_Unit then
                     Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Prove_Unit_Text (Line))));
                  elsif Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Forge then
                     Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Forge_Text (Line))));
                  else
                     Ada.Text_IO.Put_Line (Reply_Text_Pkg.Error_Reply (Id, -32602, Bad_Tool_Msg));
                  end if;
               when Json_Rpc_Frame_Pkg.Do_Nothing =>
                  null;
            end case;
         end if;
         Ada.Text_IO.Flush;
      end;
   end loop;
end Crucible_Main;
