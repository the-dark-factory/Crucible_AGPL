--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 4de888a2802bb931a76ad3d2024f4e14552c4747bec7ded66be3e31a46a32d42
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;
with Lovelace_Run_Config_Pkg;

procedure Argv_Reader_Main is
   Exe_Name : constant String := "vacuity_verdict_main";
   Env_Name : constant String := "VACUITY_EDGE";

   function Search (List : String; Exe : String) return String is
      Colon : constant Natural := Ada.Strings.Fixed.Index (List, ":");
   begin
      if Colon > 0 then
         declare
            Head : constant String := List (List'First .. Colon - 1);
            Tail : constant String := List (Colon + 1 .. List'Last);
         begin
            if Head /= "" and then GNAT.OS_Lib.Is_Executable_File (Head & "/" & Exe) then
               return Head & "/" & Exe;
            end if;
            return Search (Tail, Exe);
         end;
      else
         if List /= "" and then GNAT.OS_Lib.Is_Executable_File (List & "/" & Exe) then
            return List & "/" & Exe;
         else
            return "";
         end if;
      end if;
   end Search;

   function Started (Exe : String) return String is
     (if Ada.Strings.Fixed.Index (Exe, "/") > 0 then Exe
      elsif not Ada.Environment_Variables.Exists ("PATH") then Exe
      elsif Search (Ada.Environment_Variables.Value ("PATH"), Exe) = "" then Exe
      else Search (Ada.Environment_Variables.Value ("PATH"), Exe));

   function Absolute (P : String) return String is
     (if P'Length > 0 and then P (P'First) = '/' then P
      else Ada.Directories.Current_Directory & "/" & P);

   function Dir_Of (P : String) return String is
     (if Ada.Strings.Fixed.Index (P, "/", Ada.Strings.Backward) <= P'First then "/"
      else P (P'First .. Ada.Strings.Fixed.Index (P, "/", Ada.Strings.Backward) - 1));

   function Join (Clean : String) return String is
     (if Clean = "/" then "/" & Exe_Name else Clean & "/" & Exe_Name);

   function Default_Edge return String is
     (Join (GNAT.OS_Lib.Normalize_Pathname
              (Dir_Of (Absolute (Started (Ada.Command_Line.Command_Name))), Resolve_Links => False)));

   function Edge_Path return String is
     (if Ada.Environment_Variables.Exists (Env_Name)
        and then Ada.Environment_Variables.Value (Env_Name) /= ""
      then Ada.Environment_Variables.Value (Env_Name)
      else Default_Edge);

   Count         : constant Natural := Ada.Command_Line.Argument_Count;
   First_Is_Wire : constant Boolean := Count >= 1 and then Ada.Command_Line.Argument (1) = "wire";
begin
   if not Lovelace_Run_Config_Pkg.Is_Wire_Call (Count + 1, First_Is_Wire) then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "argv-reader: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   Ada.Text_IO.Put_Line ("ads " & Ada.Command_Line.Argument (2));
   if Lovelace_Run_Config_Pkg.Deps_Named (Count + 1) then
      Ada.Text_IO.Put_Line ("deps " & Ada.Command_Line.Argument (3));
   else
      Ada.Text_IO.Put_Line ("deps ");
   end if;
   Ada.Text_IO.Put_Line ("edge " & Edge_Path);
   Ada.Command_Line.Set_Exit_Status (0);
end Argv_Reader_Main;
