--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 04b0f21838a8532f7dac6ecbd462c28975a332809dc7c65b913a74396e93b620
--
with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with GNAT.SHA256;
with Tower_Stamp_Pkg;
with Json_Scan_Pkg;

procedure Stamp_Tower_Main is
   use type Json_Scan_Pkg.Kind_Type;

   function Strip (S : String) return String is
      Last : Integer := S'Last;
   begin
      while Last >= S'First and then S (Last) in ASCII.CR | ASCII.LF loop
         Last := Last - 1;
      end loop;
      if Last < S'First then
         return "";
      else
         declare
            R : constant String (1 .. Last - S'First + 1) := S (S'First .. Last);
         begin
            return R;
         end;
      end if;
   end Strip;

   procedure Fail (Message : String; Code : Ada.Command_Line.Exit_Status) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
      Ada.Command_Line.Set_Exit_Status (Code);
   end Fail;

   Read_Ok : Boolean := False;
   L1 : Ada.Strings.Unbounded.Unbounded_String;
   L2 : Ada.Strings.Unbounded.Unbounded_String;

begin
   declare
      Stale : constant String := "src/generated/crucible_tower.ads";
   begin
      if Ada.Directories.Exists (Stale) then
         Ada.Directories.Delete_File (Stale);
      end if;
   exception
      when others =>
         null;
   end;

   if Ada.Directories.Exists ("src/generated/crucible_tower.ads") then
      Fail ("stale unit could not be removed", 2);
      return;
   end if;

   if Ada.Command_Line.Argument_Count > 0 then
      Fail ("unexpected command-line arguments", 3);
      return;
   end if;

   declare
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "tower/base.bundle");
      if Ada.Text_IO.End_Of_File (F) then
         Ada.Text_IO.Close (F);
      else
         L1 := Ada.Strings.Unbounded.To_Unbounded_String (Ada.Text_IO.Get_Line (F));
         if Ada.Text_IO.End_Of_File (F) then
            Ada.Text_IO.Close (F);
         else
            L2 := Ada.Strings.Unbounded.To_Unbounded_String (Ada.Text_IO.Get_Line (F));
            Read_Ok := Ada.Text_IO.End_Of_File (F);
            Ada.Text_IO.Close (F);
         end if;
      end if;
   exception
      when others =>
         Read_Ok := False;
         if Ada.Text_IO.Is_Open (F) then
            Ada.Text_IO.Close (F);
         end if;
   end;

   if not Read_Ok then
      Fail ("tower/base.bundle is missing or does not have two lines", 4);
      return;
   end if;

   declare
      Line_1 : constant String := Strip (Ada.Strings.Unbounded.To_String (L1));
      Line_2 : constant String := Strip (Ada.Strings.Unbounded.To_String (L2));
   begin
      if Line_1'Length = 0 or else Line_1'Length > 1048576 then
         Fail ("tower/base.bundle is missing or does not have two lines", 4);
         return;
      end if;

      declare
         function Non_Blank (S : String) return Boolean is
            (for some I in S'Range => S (I) /= ' ' and then S (I) /= ASCII.HT);
      begin
         if not Non_Blank (Line_2) then
            Fail ("tower/base.bundle is missing or does not have two lines", 4);
            return;
         end if;
      end;

      declare
         Digest_Raw : constant String := GNAT.SHA256.Digest (Line_1);
         First_Key_Ok : constant Boolean :=
           Line_1'Length >= 11 and then Line_1 (1) = '{' and then Json_Scan_Pkg.Key_Position (Line_1, "version") = 2;
      begin
         if not First_Key_Ok then
            Fail ("version is not the first key", 5);
            return;
         end if;

         declare
            Span : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line_1, "version");
            Version_Raw : constant String :=
              (if Span.found and then Span.kind = Json_Scan_Pkg.K_Bare
               then Line_1 (Span.first .. Span.last)
               else "");
            Digest : constant String := Tower_Stamp_Pkg.Recorded_Digest (Digest_Raw);
            Version_Ok : constant Boolean := Tower_Stamp_Pkg.Is_Version_Text (Version_Raw);
            Version : constant String := Tower_Stamp_Pkg.Recorded_Version (Version_Raw);
         begin
            if Digest'Length = 0 then
               Fail ("digest refused", 5);
               return;
            end if;
            if not Version_Ok then
               Fail ("version refused", 5);
               return;
            end if;

            declare
               Out_F : Ada.Text_IO.File_Type;
            begin
               Ada.Directories.Create_Path ("src/generated");
               Ada.Text_IO.Create (Out_F, Ada.Text_IO.Out_File, "src/generated/crucible_tower.ads");
               Ada.Text_IO.Put_Line (Out_F, "--  Copyright (C) 2026 Anthony Gair");
               Ada.Text_IO.Put_Line (Out_F, "--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0");
               Ada.Text_IO.Put_Line (Out_F, "--");
               Ada.Text_IO.Put_Line (Out_F, "--  GENERATED by stamp_tower_main at build time. Do not edit: the next build overwrites it.");
               Ada.Text_IO.Put_Line (Out_F, "--  The binary carries the BASE TOWER BUNDLE it was built with, by digest and version, measured, never typed.");
               Ada.Text_IO.Put_Line (Out_F, "package Crucible_Tower with SPARK_Mode is");
               Ada.Text_IO.Put_Line (Out_F, "   Base_Digest  : constant String := """ & Digest & """;");
               Ada.Text_IO.Put_Line (Out_F, "   Base_Version : constant := " & Version & ";");
               Ada.Text_IO.Put_Line (Out_F, "   function Base_Measured return Boolean is (Base_Digest'Length = 64)");
               Ada.Text_IO.Put_Line (Out_F, "     with Post => (Base_Measured'Result = (Base_Digest'Length = 64));");
               Ada.Text_IO.Put_Line (Out_F, "end Crucible_Tower;");
               Ada.Text_IO.Close (Out_F);
            exception
               when others =>
                  if Ada.Text_IO.Is_Open (Out_F) then
                     Ada.Text_IO.Close (Out_F);
                  end if;
                  Fail ("cannot write src/generated/crucible_tower.ads", 2);
                  return;
            end;

            Ada.Text_IO.Put_Line ("stamped: src/generated/crucible_tower.ads  digest=" & Digest (Digest'First .. Digest'First + 11) & " version=" & Version);
         end;
      end;
   end;

exception
   when others =>
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "unexpected failure");
      Ada.Command_Line.Set_Exit_Status (2);
end Stamp_Tower_Main;
