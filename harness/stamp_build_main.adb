--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: e24ed05d51a40a0e9d66b315f5319b74f606af3b552493c6884dd23cf3932a6f
--
with Build_Stamp_Pkg;
with Tower_Payload_Pkg;
with Ada.Calendar;
with Ada.Calendar.Conversions;
with Ada.Strings;
with Ada.Strings.Fixed;
with Interfaces.C;

with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;
with GNAT.OS_Lib;

procedure Stamp_Build_Main is
   use type GNAT.OS_Lib.String_Access;

   procedure Say (S : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, S);
   exception
      when others =>
         null;
   end Say;

   function Read_All (Path : String; On_Failure : String) return String is
      File : Ada.Text_IO.File_Type;
      Buf  : String (1 .. 65536);
      Last : Natural := 0;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            for I in Line'Range loop
               if Last < Buf'Last then
                  Buf (Last + 1) := Line (I);
                  Last := Last + 1;
               end if;
            end loop;
            if Last < Buf'Last then
               Buf (Last + 1) := ASCII.LF;
               Last := Last + 1;
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      return Buf (1 .. Last);
   exception
      when others =>
         return On_Failure;
   end Read_All;

   function Strip (S : String) return String is
   begin
      if S'Length = 0 then
         return "";
      end if;
      declare
         Last : Natural := S'Last;
      begin
         while Last >= S'First and then (S (Last) = ASCII.LF or else S (Last) = ASCII.CR) loop
            Last := Last - 1;
         end loop;
         return S (S'First .. Last);
      end;
   end Strip;

   procedure Run_Git (Git : String; A1, A2, Out_File : String; Ok : out Boolean) is
      Args        : GNAT.OS_Lib.Argument_List := (1 => new String'(A1), 2 => new String'(A2));
      Success     : Boolean;
      Return_Code : Integer;
   begin
      GNAT.OS_Lib.Spawn (Git, Args, Out_File, Success, Return_Code, Err_To_Out => False);
      GNAT.OS_Lib.Free (Args (1));
      GNAT.OS_Lib.Free (Args (2));
      Ok := Success and then Return_Code = 0;
   end Run_Git;

   procedure Run_Git_3 (Git : String; A1, A2, A3, Out_File : String; Ok : out Boolean) is
      Args        : GNAT.OS_Lib.Argument_List := (1 => new String'(A1), 2 => new String'(A2), 3 => new String'(A3));
      Success     : Boolean;
      Return_Code : Integer;
   begin
      GNAT.OS_Lib.Spawn (Git, Args, Out_File, Success, Return_Code, Err_To_Out => False);
      GNAT.OS_Lib.Free (Args (1));
      GNAT.OS_Lib.Free (Args (2));
      GNAT.OS_Lib.Free (Args (3));
      Ok := Success and then Return_Code = 0;
   end Run_Git_3;

   Commit_Ok : Boolean := False;
   Status_Ok : Boolean := False;
   Time_Ok   : Boolean := False;
   Git_Path  : GNAT.OS_Lib.String_Access;
begin
   if Ada.Command_Line.Argument_Count > 0 then
      Ada.Command_Line.Set_Exit_Status (3);
      Say ("stamp_build_main: takes no arguments");
      return;
   end if;

   begin
      Ada.Directories.Create_Path ("obj");
   exception
      when others =>
         null;
   end;

   Git_Path := GNAT.OS_Lib.Locate_Exec_On_Path ("git");
   if Git_Path /= null then
      Run_Git (Git_Path.all, "rev-parse", "HEAD", "obj/stamp-commit.txt", Commit_Ok);
      Run_Git (Git_Path.all, "status", "--porcelain", "obj/stamp-status.txt", Status_Ok);
      Run_Git_3 (Git_Path.all, "log", "-1", "--format=%ct", "obj/stamp-time.txt", Time_Ok);
      GNAT.OS_Lib.Free (Git_Path);
   end if;

   declare
      Commit_Raw  : constant String := (if Commit_Ok then Strip (Read_All ("obj/stamp-commit.txt", "")) else "");
      Commit      : constant String := Build_Stamp_Pkg.Recorded_Commit (Commit_Raw);
      Porcelain   : constant String := (if Status_Ok and then Commit'Length > 0 then Read_All ("obj/stamp-status.txt", "X") else "X");
      Clean       : constant Boolean := Build_Stamp_Pkg.Is_Clean (Porcelain);
      Time_Raw    : constant String := (if Time_Ok then Strip (Read_All ("obj/stamp-time.txt", "X")) else "");
      Commit_Time : constant String := Build_Stamp_Pkg.Recorded_Time (Time_Raw);
      Now_Text    : constant String := Ada.Strings.Fixed.Trim (Interfaces.C.long_long'Image (Ada.Calendar.Conversions.To_Unix_Time_64 (Ada.Calendar.Clock)), Ada.Strings.Both);
      Unrecordable : constant Boolean := Time_Raw'Length > 0 and then Commit_Time'Length = 0;
      Clock_Bad   : constant Boolean := not Tower_Payload_Pkg.Is_Seconds_Text (Now_Text);
      Refused     : constant Boolean := Unrecordable or else (Commit_Time'Length > 0 and then (Clock_Bad or else Tower_Payload_Pkg.Before (Now_Text, Commit_Time)));
   begin
      if Refused then
         Ada.Command_Line.Set_Exit_Status (4);
         if Unrecordable then
            Say ("BUILD STAMP REFUSED: commit time " & Time_Raw & " is not a ten-digit unix time and cannot be recorded");
         elsif Clock_Bad then
            Say ("BUILD STAMP REFUSED: this machine's clock reads " & Now_Text & ", not a usable time; commit time " & Commit_Time);
         else
            Say ("BUILD STAMP REFUSED: commit time " & Commit_Time & " is later than this machine's clock " & Now_Text);
         end if;
         return;
      end if;

      declare
         F : Ada.Text_IO.File_Type;
      begin
         Ada.Directories.Create_Path ("src/generated");
         Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, "src/generated/crucible_build.ads");
         Ada.Text_IO.Put_Line (F, "--  Copyright (C) 2026 Anthony Gair");
         Ada.Text_IO.Put_Line (F, "--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0");
         Ada.Text_IO.Put_Line (F, "--");
         Ada.Text_IO.Put_Line (F, "--  GENERATED by stamp_build_main at build time. Do not edit: the next build overwrites it.");
         Ada.Text_IO.Put_Line (F, "--  The binary reports the tree it was BUILT FROM, measured, never a version string someone typed.");
         Ada.Text_IO.Put_Line (F, "package Crucible_Build with SPARK_Mode is");
         Ada.Text_IO.Put_Line (F, "   Commit     : constant String := """ & Commit & """;");
         Ada.Text_IO.Put_Line (F, "   Tree_Clean : constant Boolean := " & Build_Stamp_Pkg.Clean_Word (Clean) & ";");
         Ada.Text_IO.Put_Line (F, "   Commit_Time : constant String := """ & Commit_Time & """;");
         Ada.Text_IO.Put_Line (F, "   function Recorded return Boolean is (Commit'Length >= 7)");
         Ada.Text_IO.Put_Line (F, "     with Post => (Recorded'Result = (Commit'Length >= 7));");
         Ada.Text_IO.Put_Line (F, "end Crucible_Build;");
         Ada.Text_IO.Close (F);
      exception
         when others =>
            Ada.Command_Line.Set_Exit_Status (2);
            Say ("stamp_build_main: cannot write src/generated/crucible_build.ads");
            return;
      end;

      declare
         Display  : constant String := (if Commit'Length = 0 then "none" else Commit (Commit'First .. Commit'First + 11));
         Lower    : constant String := (if Clean then "true" else "false");
         Timeword : constant String := (if Commit_Time'Length = 0 then "none" else Commit_Time);
      begin
         Ada.Text_IO.Put_Line ("stamped: src/generated/crucible_build.ads  commit=" & Display & " clean=" & Lower & " time=" & Timeword);
      exception
         when others =>
            null;
      end;

      Ada.Command_Line.Set_Exit_Status (0);
   end;

exception
   when others =>
      Ada.Command_Line.Set_Exit_Status (2);
      Say ("stamp_build_main: unexpected error");
end Stamp_Build_Main;
