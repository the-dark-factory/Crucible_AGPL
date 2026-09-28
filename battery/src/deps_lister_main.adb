--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 76ee835052c166a61eb80041903ed5fe736d07f59e588c9aa44f26092a5a1e6a
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Containers.Indefinite_Vectors;
with GNAT.OS_Lib;
with Lovelace_Carried_Unit_Rule_Pkg;

procedure Deps_Lister_Main is
   use type GNAT.OS_Lib.File_Descriptor;
   use type Ada.Directories.File_Kind;
   package Name_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);
   package Name_Sorting is new Name_Vectors.Generic_Sorting;
   Max_Entries : constant := 10_000;
   Names  : Name_Vectors.Vector;
   Search : Ada.Directories.Search_Type;
   Item   : Ada.Directories.Directory_Entry_Type;
   Seen   : Natural := 0;

   procedure Print_Failure (Dir : String; Reason : String) is
   begin
      Ada.Text_IO.Put_Line ("open " & Dir & ": " & Reason);
      Ada.Command_Line.Set_Exit_Status (1);
   end Print_Failure;

begin
   if Ada.Command_Line.Argument_Count /= 2 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "deps-lister: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;

   declare
      Dir  : constant String := Ada.Command_Line.Argument (1);
      Unit : constant String := Ada.Command_Line.Argument (2);
      FD   : GNAT.OS_Lib.File_Descriptor;
      E    : Integer;
   begin
      FD := GNAT.OS_Lib.Open_Read (Dir, GNAT.OS_Lib.Binary);
      if FD = GNAT.OS_Lib.Invalid_FD then
         E := GNAT.OS_Lib.Errno;
         case E is
            when 2 => Print_Failure (Dir, "no such file or directory");
            when 13 => Print_Failure (Dir, "permission denied");
            when 20 => Print_Failure (Dir, "not a directory");
            when 62 => Print_Failure (Dir, "too many levels of symbolic links");
            when 63 => Print_Failure (Dir, "file name too long");
            when others => Print_Failure (Dir, "errno " & Integer'Image (E));
         end case;
         return;
      end if;

      GNAT.OS_Lib.Close (FD);
      if not GNAT.OS_Lib.Is_Directory (Dir) then
         Print_Failure (Dir, "not a directory");
         return;
      end if;

      Ada.Directories.Start_Search (Search, Directory => Dir, Pattern => "");
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Raw_Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Raw_Name /= "." and then Raw_Name /= ".." then
               Seen := Seen + 1;
               if Seen > Max_Entries then
                  Print_Failure (Dir, "too many entries");
                  Ada.Directories.End_Search (Search);
                  return;
               end if;
               declare
                  Name   : constant String := Raw_Name (Raw_Name'First .. Raw_Name'Last);
                  Full   : constant String := Dir & "/" & Name;
                  Is_Dir : constant Boolean :=
                    not GNAT.OS_Lib.Is_Symbolic_Link (Full) and then
                    GNAT.OS_Lib.Is_Directory (Full);
               begin
                  if Lovelace_Carried_Unit_Rule_Pkg.Stages (Name, Is_Dir, Unit) then
                     Name_Vectors.Append (Names, Name);
                  end if;
               end;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);

      Name_Sorting.Sort (Names);
      for K in Names.First_Index .. Names.Last_Index loop
         Ada.Text_IO.Put_Line (Names.Element (K));
      end loop;
      Ada.Command_Line.Set_Exit_Status (0);
   end;
end Deps_Lister_Main;
