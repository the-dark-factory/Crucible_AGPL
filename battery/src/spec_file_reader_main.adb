--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: b50370638fb9b2c13fc12ca2d2b48940fc3ba84078b119d5feb7f349278349a9
--
with Ada.Text_IO;
with Ada.Command_Line;
with GNAT.OS_Lib;

procedure Spec_File_Reader_Main is
   use type GNAT.OS_Lib.File_Descriptor;
   Max_Spec : constant := 1_048_576;
   function Reason (E : Integer) return String is
     (case E is
      when 2 => "no such file or directory",
      when 13 => "permission denied",
      when 20 => "not a directory",
      when 21 => "is a directory",
      when 62 => "too many levels of symbolic links",
      when 63 => "file name too long",
      when others => (if E >= 0 then Integer'Image (E) (2 .. Integer'Image (E)'Last) else Integer'Image (E)));
begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "spec-file-reader: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      Path       : constant String := Ada.Command_Line.Argument (1);
      FD         : constant GNAT.OS_Lib.File_Descriptor :=
        GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
      Open_Errno : constant Integer := GNAT.OS_Lib.Errno;
   begin
      if FD = GNAT.OS_Lib.Invalid_FD then
         Ada.Text_IO.Put_Line ("read " & Path & ": open " & Path & ": " & Reason (Open_Errno));
         Ada.Command_Line.Set_Exit_Status (1);
         return;
      end if;
      if GNAT.OS_Lib.File_Length (FD) > Max_Spec then
         GNAT.OS_Lib.Close (FD);
         Ada.Text_IO.Put_Line ("read " & Path & ": spec over 1048576 bytes");
         Ada.Command_Line.Set_Exit_Status (1);
         return;
      end if;
      declare
         Buf        : String (1 .. Natural (GNAT.OS_Lib.File_Length (FD)) + 1);
         N          : constant Integer := GNAT.OS_Lib.Read (FD, Buf'Address, Buf'Length);
         Read_Errno : constant Integer := GNAT.OS_Lib.Errno;
      begin
         GNAT.OS_Lib.Close (FD);
         if N < 0 then
            Ada.Text_IO.Put_Line ("read " & Path & ": read " & Path & ": " & Reason (Read_Errno));
            Ada.Command_Line.Set_Exit_Status (1);
            return;
         end if;
         declare
            Written : constant Integer := GNAT.OS_Lib.Write (GNAT.OS_Lib.Standout, Buf'Address, N);
         begin
            if Written = N then
               Ada.Command_Line.Set_Exit_Status (0);
            else
               Ada.Command_Line.Set_Exit_Status (1);
            end if;
         end;
      end;
   end;
end Spec_File_Reader_Main;
