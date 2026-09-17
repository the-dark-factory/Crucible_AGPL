--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 8327c352dfcda6ea16765a30819151d34eadce1cf1b637bf914c3e0c9340c616
--
--  Crucible_Main v5 -- the door's edge: a read loop, one declare block, one call into the frame
--  decider, one case over the action calling the proved cores. It holds no decision.
--  v5 (CRUCIBLE v0.2.0 step 4a) adds the intake_check tool: the sheet argument is decoded by the proven
--  Json_String_Pkg, split on line feeds into Intake_Measure_Pkg.Sheet (bounded; a sheet that does not fit is
--  refused, never measured on a prefix), measured by Intake_Measure_Pkg.Measure and judged by
--  Intake_Refusal_Pkg.Assemble. The tool result text is the same one line harness/intake_main prints.
--  Template (seat-written plumbing, v4 unchanged around it) with ONE slot (gaps), filled by a Wu edge round;
--  brief BRIEF_crucible_step4_wiring_2026-09-17.
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

procedure Crucible_Main is
   Null_Id       : constant String := "null";
   Server_Agpl   : constant String := "crucible-agpl";
   Server_Comm   : constant String := "crucible-commercial";
   Bad_Tool_Msg  : constant String := "unknown tool";
   Frame_Msg     : constant String := "request refused by the frame decider";
   Server_Name   : constant String :=
     (if Crucible_Edition.Is_Agpl then Server_Agpl else Server_Comm);
   Buffer        : String (1 .. 65536);
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

begin
   while not Ada.Text_IO.End_Of_File loop
      Ada.Text_IO.Get_Line (Buffer, Last);
      declare
         Line  : constant String := Buffer (1 .. Last);
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
