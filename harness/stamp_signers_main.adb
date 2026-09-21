--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 10fe2cf3797e45dc122da76836a843e661d703a9f7d6afbcb0e2ce270b1ebe47
--
with Ada.Command_Line;
with Ada.Directories;
with Ada.Text_IO;
with Tower_Keys_Pkg;

procedure Stamp_Signers_Main is
   --  The TRUST-FILE STAMP of CRUCIBLE (the loopback build brief of 2026-09-21, piece A; settles O-3 "who writes
   --  allowed_signers": THE BUILD does, from pinned constants, nobody else).
   --  HAND-AUTHORED BOUNDARY: file I/O only. It decides nothing: the keys are Tower_Keys_Pkg's compiled-in
   --  constants, and whether a seal verifies is ssh-keygen's answer at import time.
   --  It writes allowed_signers BESIDE ITSELF -- the directory this binary was started from by path -- because
   --  that is where Tower_Import_Pkg, Tower_Fetch_Pkg and Tower_Receipt_Edge look for it ("beside the binary", the
   --  owner's ruling K1, 2026-09-20). Started through PATH with a bare name it refuses: it will not guess a directory.
   --  Three lines, each namespace-scoped so a key satisfies ONLY its own seal (the CLAIMS advisory of c28e5461):
   --    <principal> namespaces="df-tower"     ssh-ed25519 ...   the catalog's content seal
   --    <principal> namespaces="df-admission" ssh-ed25519 ...   the provenance record's seal
   --    <principal> namespaces="df-index"     ssh-ed25519 ...   the Reef index's freshness seal
   --  A STAND-IN key is written with a loud warning on standard error and exit 0 (the slice is not blocked; the
   --  warning text is the flag). Exit 2: cannot write. Exit 3: arguments given. The pins are written BLINDLY (the
   --  owner's lean, 2026-09-21: constants only in Tower_Keys_Pkg); the probe's row A2 checks ssh-keygen accepts the file.

   procedure Fail (Message : String; Code : Ada.Command_Line.Exit_Status) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "stamp_signers: " & Message);
      Ada.Command_Line.Set_Exit_Status (Code);
   end Fail;

   function Own_Directory return String is
      Name : constant String := Ada.Command_Line.Command_Name;
   begin
      if (for all C of Name => C /= '/') then
         return "";
      end if;
      return Ada.Directories.Containing_Directory (Ada.Directories.Full_Name (Name));
   exception
      when others =>
         return "";
   end Own_Directory;

   function Line (Namespace : String; Key : String) return String is
     (Tower_Keys_Pkg.Principal & " namespaces=""" & Namespace & """ " & Key);

begin
   if Ada.Command_Line.Argument_Count > 0 then
      Fail ("unexpected command-line arguments", 3);
      return;
   end if;
   declare
      Dir : constant String := Own_Directory;
   begin
      if Dir'Length = 0 then
         Fail ("started by a bare name; run it by path (bin/stamp_signers) so it knows where the binary lives", 2);
         return;
      end if;
      declare
         Path : constant String := Ada.Directories.Compose (Dir, "allowed_signers");
         F    : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
         Ada.Text_IO.Put_Line (F, Line (Tower_Keys_Pkg.Tower_Namespace, Tower_Keys_Pkg.Df_Tower_Public));
         Ada.Text_IO.Put_Line (F, Line (Tower_Keys_Pkg.Admission_Namespace, Tower_Keys_Pkg.Df_Admission_Public));
         Ada.Text_IO.Put_Line (F, Line (Tower_Keys_Pkg.Index_Namespace, Tower_Keys_Pkg.Df_Index_Public));
         Ada.Text_IO.Close (F);
         Ada.Text_IO.Put_Line ("stamped: " & Path & "  lines=3 principal=" & Tower_Keys_Pkg.Principal);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
            Fail ("cannot write " & Path, 2);
            return;
      end;
   end;

   if Tower_Keys_Pkg.Df_Tower_Is_Stand_In then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                            "stamp_signers: WARNING df-tower line is a STAND-IN key, not the real signer");
   end if;
   if Tower_Keys_Pkg.Df_Admission_Is_Stand_In then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                            "stamp_signers: WARNING df-admission line is a STAND-IN key, not the admitter's;"
                            & " a real provenance record will NOT verify until the real public half is pinned");
   end if;
   if Tower_Keys_Pkg.Df_Index_Is_Stand_In then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                            "stamp_signers: WARNING df-index line is a STAND-IN key; the Reef's index signer"
                            & " does not exist yet (the owner's Linode ceremony)");
   end if;
end Stamp_Signers_Main;
