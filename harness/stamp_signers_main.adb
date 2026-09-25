--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 0b2b8f57c6175d998c51c5d69b32a11f8fc8135e313e22c7236d8a99525a932c
--
with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;
with Tower_Keys_Pkg;

procedure Stamp_Signers_Main is
   function Own_Directory return String is
      Name : constant String := Ada.Command_Line.Command_Name;
      Has_Separator : Boolean := False;
   begin
      for C of Name loop
         if C = '/' or else C = '\' then
            Has_Separator := True;
            exit;
         end if;
      end loop;

      if not Has_Separator then
         return "";
      end if;

      begin
         return Ada.Directories.Containing_Directory (Name);
      exception
         when others =>
            return "";
      end;
   end Own_Directory;

   procedure Fail (Msg : String; Status : Ada.Command_Line.Exit_Status) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "stamp_signers: " & Msg);
      Ada.Command_Line.Set_Exit_Status (Status);
      return;
   end Fail;

   function Build_Line (Namespace : String; Key : String) return String is
   begin
      return Tower_Keys_Pkg.Principal & " namespaces=" & """ & Namespace & """ & " " & Key;
   end Build_Line;

   Dir : constant String := Own_Directory;
   File_Path : constant String := Ada.Directories.Compose (Dir, "allowed_signers");
   File : Ada.Text_IO.File_Type;
begin
   if Ada.Command_Line.Argument_Count > 0 then
      Fail ("unexpected command-line arguments", 3);
      return;
   end if;

   if Dir'Length = 0 then
      Fail ("started by bare name; must be run by path", 2);
      return;
   end if;

   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, File_Path);
      Ada.Text_IO.Put_Line (File, Build_Line (Tower_Keys_Pkg.Tower_Namespace, Tower_Keys_Pkg.Df_Tower_Public));
      Ada.Text_IO.Put_Line (File, Build_Line (Tower_Keys_Pkg.Admission_Namespace, Tower_Keys_Pkg.Df_Admission_Public));
      Ada.Text_IO.Put_Line (File, Build_Line (Tower_Keys_Pkg.Index_Namespace, Tower_Keys_Pkg.Df_Index_Public));
      Ada.Text_IO.Close (File);

      if Tower_Keys_Pkg.Df_Tower_Is_Stand_In then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "stamp_signers: WARNING stand-in key in namespace " & Tower_Keys_Pkg.Tower_Namespace);
      end if;
      if Tower_Keys_Pkg.Df_Admission_Is_Stand_In then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "stamp_signers: WARNING stand-in key in namespace " & Tower_Keys_Pkg.Admission_Namespace);
      end if;
      if Tower_Keys_Pkg.Df_Index_Is_Stand_In then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "stamp_signers: WARNING stand-in key in namespace " & Tower_Keys_Pkg.Index_Namespace);
      end if;

      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Output, "stamp_signers: wrote " & File_Path & " (3 lines, principal " & Tower_Keys_Pkg.Principal & ")");
      Ada.Command_Line.Set_Exit_Status (0);
   exception
      when others =>
         Fail ("cannot write file", 2);
   end;
end Stamp_Signers_Main;
