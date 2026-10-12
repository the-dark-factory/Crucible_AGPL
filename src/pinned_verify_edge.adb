--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 262b9249e0714c5abe27d089bc635756b86e5b1b468355f72430ff6c115fc179
--
with Pinned_Signer_Pkg;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with GNAT.Expect;
with GNAT.OS_Lib;
with GNAT.SHA256;
with System;

procedure Pinned_Verify_Edge
  (Signers_Path     : in String;
   Pin              : in String;
   Message          : in String;
   Signature        : in String;
   Ssh_Keygen       : in String;
   Work_Dir         : in String;
   Verify_Signature : in Boolean;
   Refusal          : out Pinned_Signer_Pkg.Signer_Reason;
   Verified         : out Boolean;
   Signer_Digest    : out Ada.Strings.Unbounded.Unbounded_String)
is
   package ASU renames Ada.Strings.Unbounded;

   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Directories.File_Kind;
   use type Pinned_Signer_Pkg.Signer_Reason;
   use type GNAT.OS_Lib.File_Descriptor;

   --  The one raw buffer and its filled count, set by the single read in step 3.
   Buffer        : Ada.Streams.Stream_Element_Array
                     (1 .. Pinned_Signer_Pkg.Max_Signers_Bytes + 1);
   N_Read        : Ada.Streams.Stream_Element_Offset := 0;
   Bytes_Present : Boolean := False;

   --  The private paths, held as unbounded so the exception handler can see them.
   Dir_Path     : ASU.Unbounded_String := ASU.Null_Unbounded_String;
   Signers_File : ASU.Unbounded_String := ASU.Null_Unbounded_String;
   Sig_File     : ASU.Unbounded_String := ASU.Null_Unbounded_String;

   procedure Free_Arg (A : in out GNAT.OS_Lib.String_Access) is
   begin
      GNAT.OS_Lib.Free (A);
   end Free_Arg;

   function Hex_Byte (B : Ada.Streams.Stream_Element) return String is
      Digit_Set : constant String := "0123456789abcdef";
      V         : constant Integer := Integer (B);
   begin
      return Digit_Set (Digit_Set'First + V / 16)
           & Digit_Set (Digit_Set'First + V mod 16);
   end Hex_Byte;

   procedure Guarded_Delete_File (Name : String) is
   begin
      if Name'Length > 0 and then Ada.Directories.Exists (Name) then
         Ada.Directories.Delete_File (Name);
      end if;
   exception
      when others =>
         null;
   end Guarded_Delete_File;

   procedure Guarded_Delete_Dir (Name : String) is
   begin
      if Name'Length > 0 and then Ada.Directories.Exists (Name) then
         Ada.Directories.Delete_Directory (Name);
      end if;
   exception
      when others =>
         null;
   end Guarded_Delete_Dir;

   procedure Cleanup is
   begin
      Guarded_Delete_File (ASU.To_String (Sig_File));
      Guarded_Delete_File (ASU.To_String (Signers_File));
      Guarded_Delete_Dir (ASU.To_String (Dir_Path));
   end Cleanup;

   function None_Exist return Boolean is
   begin
      return
        not Ada.Directories.Exists (ASU.To_String (Sig_File))
        and then not Ada.Directories.Exists (ASU.To_String (Signers_File))
        and then not Ada.Directories.Exists (ASU.To_String (Dir_Path));
   exception
      when others =>
         return False;
   end None_Exist;

begin
   --  Step 1: start state.
   Verified      := False;
   Signer_Digest := ASU.Null_Unbounded_String;
   Refusal       := Pinned_Signer_Pkg.No_File;

   --  Step 2: pin first. A zero or malformed pin opens nothing, runs nothing.
   if Pinned_Signer_Pkg.Signer_Refusal (Pin, False, "", "")
        = Pinned_Signer_Pkg.No_Network
   then
      Refusal := Pinned_Signer_Pkg.No_Network;
      return;
   end if;

   --  Step 3: read once, raw. Close on every path.
   declare
      File : Ada.Streams.Stream_IO.File_Type;
      Last : Ada.Streams.Stream_Element_Offset := 0;
   begin
      if Ada.Directories.Kind (Signers_Path) = Ada.Directories.Ordinary_File then
         Ada.Streams.Stream_IO.Open
           (File, Ada.Streams.Stream_IO.In_File, Signers_Path);
         Ada.Streams.Stream_IO.Read (File, Buffer, Last);
         Ada.Streams.Stream_IO.Close (File);

         if Last = Ada.Streams.Stream_Element_Offset'Min
                     (Ada.Streams.Stream_Element_Offset
                        (Ada.Directories.Size (Signers_Path)),
                      Pinned_Signer_Pkg.Max_Signers_Bytes + 1)
         then
            Bytes_Present := True;
            N_Read        := Last;
         end if;
      end if;
   exception
      when others =>
         Bytes_Present := False;
         N_Read        := 0;
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
   end;

   --  The one buffer Judged, the digest, the judgement and all later work.
   declare
      function Build return String is
         R : String (1 .. Natural (N_Read));
      begin
         for I in R'Range loop
            R (I) := Character'Val
                       (Integer (Buffer (Ada.Streams.Stream_Element_Offset (I))));
         end loop;
         return R;
      end Build;

      Judged      : constant String := Build;
      Line_Digest : constant String :=
        GNAT.SHA256.Digest (Pinned_Signer_Pkg.Line_Span (Judged));
      Verify_OK   : Boolean := False;
   begin
      --  Step 5: judge.
      Refusal := Pinned_Signer_Pkg.Signer_Refusal
                   (Pin, Bytes_Present, Judged, Line_Digest);

      if Refusal = Pinned_Signer_Pkg.None then
         Signer_Digest := ASU.To_Unbounded_String (Line_Digest);
      end if;

      if Refusal /= Pinned_Signer_Pkg.None or else not Verify_Signature then
         return;
      end if;

      --  Step 6: private directory (reached only when None and verifying).
      declare
         Rand      : Ada.Streams.Stream_Element_Array (1 .. 8);
         Rand_Last : Ada.Streams.Stream_Element_Offset := 0;
         RF        : Ada.Streams.Stream_IO.File_Type;
         Hex16     : String (1 .. 16);
         Pid       : constant Integer :=
           GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id);
      begin
         begin
            Ada.Streams.Stream_IO.Open
              (RF, Ada.Streams.Stream_IO.In_File, "/dev/urandom");
            Ada.Streams.Stream_IO.Read (RF, Rand, Rand_Last);
            Ada.Streams.Stream_IO.Close (RF);
         exception
            when others =>
               if Ada.Streams.Stream_IO.Is_Open (RF) then
                  Ada.Streams.Stream_IO.Close (RF);
               end if;
               return;
         end;

         if Rand_Last /= 8 then
            return;
         end if;

         for I in Rand'Range loop
            declare
               H : constant String := Hex_Byte (Rand (I));
            begin
               Hex16 (Natural (I) * 2 - 1) := H (1);
               Hex16 (Natural (I) * 2)     := H (2);
            end;
         end loop;

         Dir_Path := ASU.To_Unbounded_String
           (Work_Dir & "/pinned-verify-"
            & Ada.Strings.Fixed.Trim (Integer'Image (Pid), Ada.Strings.Both)
            & "-" & Hex16);
         Signers_File :=
           ASU.To_Unbounded_String (ASU.To_String (Dir_Path) & "/signers");
         Sig_File :=
           ASU.To_Unbounded_String (ASU.To_String (Dir_Path) & "/sig");

         --  A path is never reused.
         if Ada.Directories.Exists (ASU.To_String (Dir_Path)) then
            return;
         end if;

         --  Make it with /bin/mkdir, no shell.
         declare
            AM  : GNAT.OS_Lib.Argument_List (1 .. 3);
            Okm : Boolean := False;
            DP  : constant String := ASU.To_String (Dir_Path);
         begin
            AM (1) := new String'("-m");
            AM (2) := new String'("0700");
            AM (3) := new String'(DP);
            GNAT.OS_Lib.Spawn ("/bin/mkdir", AM, Okm);
            Free_Arg (AM (1));
            Free_Arg (AM (2));
            Free_Arg (AM (3));

            if not (Okm and then Ada.Directories.Exists (DP)
                    and then Ada.Directories.Kind (DP)
                               = Ada.Directories.Directory)
            then
               return;
            end if;
         end;

         --  Steps 7 and 8: write the private files, then verify.
         declare
            Step_Failure    : exception;
            Signers_Content : constant String :=
              Pinned_Signer_Pkg.Signers_File_Text (Judged);
            SPath           : constant String := ASU.To_String (Signers_File);
            GPath           : constant String := ASU.To_String (Sig_File);
         begin
            --  signers file
            declare
               FD  : GNAT.OS_Lib.File_Descriptor;
               Nw  : Integer;
               Okc : Boolean := False;
               AC  : GNAT.OS_Lib.Argument_List (1 .. 2);
            begin
               FD := GNAT.OS_Lib.Create_New_File (SPath, GNAT.OS_Lib.Binary);
               if FD = GNAT.OS_Lib.Invalid_FD then
                  raise Step_Failure;
               end if;
               AC (1) := new String'("0600");
               AC (2) := new String'(SPath);
               GNAT.OS_Lib.Spawn ("/bin/chmod", AC, Okc);
               Free_Arg (AC (1));
               Free_Arg (AC (2));
               Nw := GNAT.OS_Lib.Write
                       (FD, Signers_Content'Address, Signers_Content'Length);
               GNAT.OS_Lib.Close (FD);
               if Nw /= Signers_Content'Length then
                  raise Step_Failure;
               end if;
            end;

            --  sig file
            declare
               FD  : GNAT.OS_Lib.File_Descriptor;
               Nw  : Integer;
               Okc : Boolean := False;
               AC  : GNAT.OS_Lib.Argument_List (1 .. 2);
            begin
               FD := GNAT.OS_Lib.Create_New_File (GPath, GNAT.OS_Lib.Binary);
               if FD = GNAT.OS_Lib.Invalid_FD then
                  raise Step_Failure;
               end if;
               AC (1) := new String'("0600");
               AC (2) := new String'(GPath);
               GNAT.OS_Lib.Spawn ("/bin/chmod", AC, Okc);
               Free_Arg (AC (1));
               Free_Arg (AC (2));
               Nw := GNAT.OS_Lib.Write
                       (FD, Signature'Address, Signature'Length);
               GNAT.OS_Lib.Close (FD);
               if Nw /= Signature'Length then
                  raise Step_Failure;
               end if;
            end;

            --  the settled verify call
            declare
               AV     : GNAT.OS_Lib.Argument_List (1 .. 10);
               Status : aliased Integer := 1;
            begin
               AV (1)  := new String'("-Y");
               AV (2)  := new String'("verify");
               AV (3)  := new String'("-f");
               AV (4)  := new String'(SPath);
               AV (5)  := new String'("-I");
               AV (6)  := new String'("reef");
               AV (7)  := new String'("-n");
               AV (8)  := new String'("df-reef-key");
               AV (9)  := new String'("-s");
               AV (10) := new String'(GPath);

               declare
                  Result : constant String := GNAT.Expect.Get_Command_Output
                    (Ssh_Keygen, AV, Message, Status'Access, True);
               begin
                  if Result'Length >= 0 then
                     null;
                  end if;
               end;

               for I in AV'Range loop
                  Free_Arg (AV (I));
               end loop;

               Verify_OK := (Status = 0);
            end;
         exception
            when others =>
               Verify_OK := False;
         end;

         --  Step 9: clean up on this path, then settle the verdict.
         Cleanup;
         Verified := Verify_OK and then None_Exist;
      end;
   end;

exception
   when others =>
      Verified := False;
      Cleanup;
end Pinned_Verify_Edge;

