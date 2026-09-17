--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 060088ba84fd4b55fa9349978b1382907563eb2f6a974b2b4e91eed7189ac09b
--
--  Intake_Main — CRUCIBLE's intake EDGE (harness program). It reads a spec sheet from standard input,
--  and replies with ONE line. It decides nothing: every verdict comes from the proven
--  Intake_Refusal_Pkg.Assemble over the facts the proven Intake_Measure_Pkg.Measure takes from the sheet.
--  This edge only reads bounded input (refusing, never truncating, a sheet it cannot hold), keeps each
--  sheet line's ORIGINAL line number, and prints the verdict's fields.
--  Exit: 0 may_forge; 1 refused; 2 input_refused (nothing measured). Never may_forge on an error.
--  Template with ONE slot (gaps), filled by a Wu edge round; brief BRIEF_crucible_intake_measurer_2026-09-16.
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Intake_Line_Pkg;
with Intake_Names_Pkg;
with Intake_Measure_Pkg;
with Intake_Refusal_Pkg;

procedure Intake_Main with SPARK_Mode => Off is

   use Ada.Strings.Unbounded;

   subtype Line_Index is Intake_Measure_Pkg.Line_Index;

   type Sheet_Access is access Intake_Measure_Pkg.Sheet;
   type Origin_Array is array (Line_Index) of Positive;

   S      : constant Sheet_Access := new Intake_Measure_Pkg.Sheet;
   Origin : Origin_Array := (others => 1);
   Reply  : Unbounded_String;
   First  : Boolean := True;

   --  A Natural as decimal digits with no leading space.
   function Img (N : Natural) return String is
      T : constant String := Natural'Image (N);
   begin
      return T (T'First + 1 .. T'Last);
   end Img;

   procedure Append (Text : String) is
   begin
      Append (Reply, Text);
   end Append;

   --  Append one quoted gap word to the gaps list, with a comma before every word but the first.
   procedure Add_Gap (Word : String) is
   begin
      if not First then
         Append (",");
      end if;
      Append ("""" & Word & """");
      First := False;
   end Add_Gap;

   procedure Finish (Code : Ada.Command_Line.Exit_Status) is
   begin
      Ada.Text_IO.Put_Line (To_String (Reply));
      Ada.Command_Line.Set_Exit_Status (Code);
   end Finish;

   function Is_Blank (Text : String) return Boolean is
   begin
      for C of Text loop
         if not Intake_Line_Pkg.Is_Space (C) then
            return False;
         end if;
      end loop;
      return True;
   end Is_Blank;

   Buf       : String (1 .. Intake_Line_Pkg.Max_Line + 2);
   Last      : Natural;
   File_Line : Natural := 0;
   Count     : Intake_Measure_Pkg.Line_Count := 0;

begin
   S.Count := 0;
   for I in Line_Index loop
      S.Lines (I).Len := 0;
   end loop;

   --  Read the whole sheet, bounded. A sheet that does not fit is refused, never measured on a prefix.
   while not Ada.Text_IO.End_Of_File loop
      Ada.Text_IO.Get_Line (Buf, Last);
      File_Line := File_Line + 1;
      if Last > Intake_Line_Pkg.Max_Line then
         Reply := To_Unbounded_String
           ("{""verdict"":""input_refused"",""reason"":""line_too_long"",""line"":""" & Img (File_Line) & """}");
         Finish (2);
         return;
      end if;
      if not Is_Blank (Buf (1 .. Last)) then
         if Count = Intake_Measure_Pkg.Max_Lines then
            Reply := To_Unbounded_String
              ("{""verdict"":""input_refused"",""reason"":""too_many_lines"",""limit"":""" &
               Img (Intake_Measure_Pkg.Max_Lines) & """}");
            Finish (2);
            return;
         end if;
         Count := Count + 1;
         S.Lines (Count).Text (1 .. Last) := Buf (1 .. Last);
         S.Lines (Count).Len := Last;
         Origin (Count) := File_Line;
      end if;
   end loop;
   S.Count := Count;

   declare
      Facts : constant Intake_Refusal_Pkg.Facts_Type := Intake_Measure_Pkg.Measure (S.all);
      V     : constant Intake_Refusal_Pkg.Verdict_Type := Intake_Refusal_Pkg.Assemble (Facts);
   begin
      if V.may_forge then
         Reply := To_Unbounded_String
           ("{""verdict"":""may_forge"",""operation_count"":""" & Img (V.operation_count) & """}");
         Finish (0);
         return;
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
                  Text  : constant String := Intake_Measure_Pkg.Text_Of (S.all, Place.Line);
                  Last_P : constant Positive := Intake_Names_Pkg.Used_Name_End (Text, Place.Pos);
               begin
                  Append (",""first_undefined"":{""line"":""" & Img (Origin (Place.Line)) &
                          """,""name"":""" & Text (Place.Pos .. Last_P) & """}");
               end;
            end if;
         end;
      end if;

      Append ("}");
      Finish (1);
   end;

exception
   when others =>
      Reply := To_Unbounded_String ("{""verdict"":""input_refused"",""reason"":""unreadable""}");
      Finish (2);
end Intake_Main;
