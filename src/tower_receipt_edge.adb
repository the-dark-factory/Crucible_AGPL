--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1aea2bd73bf3afdbe9f268fe23dd5ab0b5c61c47cb710677c88cde119add111a
--
--  Tower_Receipt_Edge body -- template with THREE slots (facts, outcome, outcome_word), filled by a Wu edge round.
--  PROVENANCE OF THE FIXED TEXT, said so that nobody has to guess:
--    LIFTED from FORGED, shipped text, unchanged but for names and indentation:
--      Strip, One_Based, Write_Bytes, Remove, File_Digest, First_Line, Signers_Path, the two-line read,
--        Measure_Seal (find-principals, then -Y verify -I <measured principal> -n <namespace>) ..... Tower_Import_Pkg
--        body (wu-crucible-tower-import-2). ONE change inside Measure_Seal, said: a principal is kept when
--        Tower_Receipt_Pkg.Is_Principal holds (the proven form of that body's seat-written Is_Safe_Name).
--      Read_Small, Write_Two, Append_Row, Sign (ssh-keygen -Y sign by ARGUMENT VECTOR, -f <key> -n <namespace>,
--        the signature file read back as hex) ..... Tower_Pack_Edge body (wu-crucible-tower-pack-edge); Sign here
--        takes the namespace as a parameter, so that this text signs under df-admission and nothing else.
--      the clock as text ..... stamp_build_main lineage 2.
--    SEAT-WRITTEN plumbing, I/O and copying, said in full: Measure_Not_Self (the admitter's own public key written
--      as a one-line signers file of this process's own, then find-principals: a seal that key made is SELF-SEALED
--      and is refused -- R1's two signers, two jobs, measured rather than assumed; the public file must parse as a
--      key, ssh-keygen -l, before the answer counts); the receipt file (two hex lines, the packer's own completion
--      input); the record row. THREE things here are not pure measurement, each said: the seal is measured only when
--      the source, the key, the seal line and the payload are present (I/O gated on facts); the receipt is signed
--      only under a seal that verified and was not this key's (a signature is an act, not a measurement, so it waits
--      for every fact before it); a row is appended for every measured word (the last handler writes none).
--    Every judgement is a call into a proven package: Tower_Receipt_Pkg (Is_Seal_Line, Seal_Last, Is_Principal,
--      Outcome), Tower_Pack_Pkg (Receipt_Text -- proved to satisfy Tower_Envelope_Pkg.Receipt_Names for the digest
--      it is given -- and Envelope_Text -- proved to satisfy Tower_Envelope_Pkg.Envelope_Is), Tower_Payload_Pkg
--      (Payload_Ok, Max_Line), Tower_Envelope_Pkg (Is_Hex_Text, Seal_First, Max_Line, Receipt_Length),
--      Tower_Stamp_Pkg (Is_Hex_Digest), Hex_Text_Pkg. The edge shapes no text of its own but the record row and
--      the one-line self signers file, both said.
with Ada.Calendar;
with Ada.Calendar.Conversions;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with GNAT.Expect;
with GNAT.OS_Lib;
with GNAT.SHA256;
with Interfaces.C;
with Hex_Text_Pkg;
with Tower_Envelope_Pkg;
with Tower_Pack_Pkg;
with Tower_Payload_Pkg;
with Tower_Receipt_Pkg;
with Tower_Stamp_Pkg;

package body Tower_Receipt_Edge with SPARK_Mode => Off is

   use type Ada.Directories.File_Size;
   use type Ada.Streams.Stream_Element_Offset;

   package U renames Ada.Strings.Unbounded;

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

   --  A copy whose 'First is 1, whatever the bounds of S. Every proven package here requires it.
   function One_Based (S : String) return String is
      R : constant String (1 .. S'Length) := S;
   begin
      return R;
   end One_Based;

   function Now_Seconds return Interfaces.C.long_long is
     (Ada.Calendar.Conversions.To_Unix_Time_64 (Ada.Calendar.Clock));

   function Seconds_Text (T : Interfaces.C.long_long) return String is
     (Ada.Strings.Fixed.Trim (Interfaces.C.long_long'Image (T), Ada.Strings.Both));

   function Pid_Text return String is
     (Ada.Strings.Fixed.Trim
        (Integer'Image (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id)), Ada.Strings.Both));

   procedure Write_Bytes (Path : String; Text : String) is
      F : Ada.Streams.Stream_IO.File_Type;
   begin
      Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Path);
      String'Write (Ada.Streams.Stream_IO.Stream (F), Text);
      Ada.Streams.Stream_IO.Close (F);
   end Write_Bytes;

   procedure Remove (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
   end Remove;

   --  The sha256 of a file's bytes as 64 lower-case hex characters; "" when there is no file or it cannot be read.
   function File_Digest (Path : String) return String is
      F    : Ada.Streams.Stream_IO.File_Type;
      C    : GNAT.SHA256.Context := GNAT.SHA256.Initial_Context;
      Buf  : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last : Ada.Streams.Stream_Element_Offset;
   begin
      if Path'Length = 0 or else not Ada.Directories.Exists (Path) then
         return "";
      end if;
      Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.In_File, Path);
      while not Ada.Streams.Stream_IO.End_Of_File (F) loop
         Ada.Streams.Stream_IO.Read (F, Buf, Last);
         GNAT.SHA256.Update (C, Buf (1 .. Last));
      end loop;
      Ada.Streams.Stream_IO.Close (F);
      return GNAT.SHA256.Digest (C);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (F) then
            Ada.Streams.Stream_IO.Close (F);
         end if;
         return "";
   end File_Digest;

   --  A file of exactly two lines, each with its line feed, in ONE write; the directory made first.
   procedure Write_Two (Path : String; Line_A : String; Line_B : String; Wrote : out Boolean) is
      F : Ada.Streams.Stream_IO.File_Type;
   begin
      Wrote := False;
      if not Ada.Directories.Exists (Ada.Directories.Containing_Directory (Path)) then
         Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Path));
      end if;
      Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Path);
      String'Write (Ada.Streams.Stream_IO.Stream (F), Line_A & ASCII.LF & Line_B & ASCII.LF);
      Ada.Streams.Stream_IO.Close (F);
      Wrote := True;
   exception
      when others =>
         Wrote := False;
         if Ada.Streams.Stream_IO.Is_Open (F) then
            Ada.Streams.Stream_IO.Close (F);
         end if;
   end Write_Two;

   procedure Append_Row (Path : String; Row : String) is
      F    : Ada.Streams.Stream_IO.File_Type;
      Torn : Boolean := False;
   begin
      if Ada.Directories.Exists (Path) and then Ada.Directories.Size (Path) > 0 then
         declare
            G    : Ada.Streams.Stream_IO.File_Type;
            Last : Character;
         begin
            Ada.Streams.Stream_IO.Open (G, Ada.Streams.Stream_IO.In_File, Path);
            Ada.Streams.Stream_IO.Set_Index (G, Ada.Streams.Stream_IO.Size (G));
            Character'Read (Ada.Streams.Stream_IO.Stream (G), Last);
            Ada.Streams.Stream_IO.Close (G);
            Torn := Last /= ASCII.LF;
         exception
            when others =>
               if Ada.Streams.Stream_IO.Is_Open (G) then
                  Ada.Streams.Stream_IO.Close (G);
               end if;
         end;
      end if;
      if not Ada.Directories.Exists (Ada.Directories.Containing_Directory (Path)) then
         Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Path));
      end if;
      if Ada.Directories.Exists (Path) then
         Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.Append_File, Path);
      else
         Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Path);
      end if;
      String'Write (Ada.Streams.Stream_IO.Stream (F), (if Torn then (1 => ASCII.LF) else "") & Row & ASCII.LF);
      Ada.Streams.Stream_IO.Close (F);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (F) then
            Ada.Streams.Stream_IO.Close (F);
         end if;
   end Append_Row;

   --  The whole of a small file as a String ("" when absent or larger than the bound).
   function Read_Small (Path : String; Bound : Natural) return String is
      F    : Ada.Streams.Stream_IO.File_Type;
      Size : Ada.Directories.File_Size;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;
      Size := Ada.Directories.Size (Path);
      if Size = 0 or else Size > Ada.Directories.File_Size (Bound) then
         return "";
      end if;
      declare
         Text : String (1 .. Natural (Size));
      begin
         Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.In_File, Path);
         String'Read (Ada.Streams.Stream_IO.Stream (F), Text);
         Ada.Streams.Stream_IO.Close (F);
         return Text;
      end;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (F) then
            Ada.Streams.Stream_IO.Close (F);
         end if;
         return "";
   end Read_Small;

   function First_Line (S : String) return String is
   begin
      for I in S'Range loop
         if S (I) in ASCII.LF | ASCII.CR then
            return One_Based (S (S'First .. I - 1));
         end if;
      end loop;
      return One_Based (S);
   end First_Line;

   --  The allowed_signers file BESIDE THE BINARY. "" when the binary's directory cannot be named: no file, no signer.
   function Signers_Path return String is
      Name : constant String := Ada.Command_Line.Command_Name;
   begin
      --  A bare name (started through PATH) would be resolved against the WORKING directory -- the tree that
      --  holds the untrusted file -- and whoever can write there would own the trust root. No slash, no signers.
      if (for all C of Name => C /= '/') then
         return "";
      end if;
      return Ada.Directories.Compose
        (Ada.Directories.Containing_Directory (Ada.Directories.Full_Name (Ada.Command_Line.Command_Name)),
         Signers_Name);
   exception
      when others =>
         return "";
   end Signers_Path;

   --  MEASURE one seal. Message is signed AS A LINE (the runtime appends the one line feed). Known = the signature
   --  was made by a key the allowed_signers file names (find-principals); Valid = ssh-keygen -Y verify exits 0 for
   --  that principal under the namespace Under. Nothing is read from the file to say WHO signed.
   procedure Measure_Seal
     (Message   : String;
      Seal_Hex  : String;
      Signers   : String;
      Under     : String;
      Known     : out Boolean;
      Valid     : out Boolean;
      Principal : out U.Unbounded_String)
   is
      Sig_Path : constant String := Ada.Directories.Compose (Work_Dir, "seal-" & Pid_Text & ".sig");
   begin
      Known := False;
      Valid := False;
      Principal := U.Null_Unbounded_String;
      if Signers'Length = 0 or else not Ada.Directories.Exists (Signers)
        or else not Hex_Text_Pkg.Is_Hex_Text (Seal_Hex) or else Seal_Hex'Length = 0
      then
         return;
      end if;
      if not Ada.Directories.Exists (Work_Dir) then
         Ada.Directories.Create_Path (Work_Dir);
      end if;
      Write_Bytes (Sig_Path, Hex_Text_Pkg.Decode (Seal_Hex));
      declare
         Find_Code : aliased Integer := 1;
         Args : GNAT.OS_Lib.Argument_List :=
           (new String'("-Y"), new String'("find-principals"), new String'("-s"), new String'(Sig_Path),
            new String'("-f"), new String'(Signers));
         Out_Text : constant String :=
           GNAT.Expect.Get_Command_Output (Ssh_Keygen, Args, "", Find_Code'Access, Err_To_Out => False);
         Name : constant String := First_Line (Out_Text);
      begin
         for A of Args loop
            GNAT.OS_Lib.Free (A);
         end loop;
         Known := Find_Code = 0 and then Tower_Receipt_Pkg.Is_Principal (Name);
         if Known then
            Principal := U.To_Unbounded_String (Name);
         end if;
      end;
      if Known then
         declare
            Verify_Code : aliased Integer := 1;
            Args : GNAT.OS_Lib.Argument_List :=
              (new String'("-Y"), new String'("verify"), new String'("-f"), new String'(Signers),
               new String'("-I"), new String'(U.To_String (Principal)),
               new String'("-n"), new String'(Under), new String'("-s"), new String'(Sig_Path));
            Out_Text : constant String :=
              GNAT.Expect.Get_Command_Output (Ssh_Keygen, Args, Message, Verify_Code'Access, Err_To_Out => True);
            pragma Unreferenced (Out_Text);
         begin
            for A of Args loop
               GNAT.OS_Lib.Free (A);
            end loop;
            Valid := Verify_Code = 0;
         end;
      end if;
      Remove (Sig_Path);
   exception
      when others =>
         Known := False;
         Valid := False;
         Principal := U.Null_Unbounded_String;
         begin
            Remove (Sig_Path);
         exception
            when others =>
               null;
         end;
   end Measure_Seal;

   --  MEASURE that the seal was NOT made with this issuer's own key. The key's public file is written as a one-line
   --  signers file of this process's own ("self <public line>") and find-principals is asked whether the seal was
   --  made by it. Not_Self is True only when the public file PARSES as a key (ssh-keygen -l) and find-principals
   --  names no principal: a public file that cannot be read gives False -- a fact nobody measured refuses.
   procedure Measure_Not_Self (Seal_Hex : String; Pub_Path : String; Not_Self : out Boolean) is
      Sig_Path     : constant String := Ada.Directories.Compose (Work_Dir, "self-" & Pid_Text & ".sig");
      Signers_Path : constant String := Ada.Directories.Compose (Work_Dir, "self-" & Pid_Text & ".signers");
      Pub_Line     : constant String := First_Line (Read_Small (Pub_Path, Pub_Bound));
      Parses       : Boolean := False;
   begin
      Not_Self := False;
      if Pub_Line'Length = 0 or else not Hex_Text_Pkg.Is_Hex_Text (Seal_Hex) or else Seal_Hex'Length = 0 then
         return;
      end if;
      if not Ada.Directories.Exists (Work_Dir) then
         Ada.Directories.Create_Path (Work_Dir);
      end if;
      declare
         List_Code : aliased Integer := 1;
         Args : GNAT.OS_Lib.Argument_List :=
           (new String'("-l"), new String'("-f"), new String'(Pub_Path));
         Out_Text : constant String :=
           GNAT.Expect.Get_Command_Output (Ssh_Keygen, Args, "", List_Code'Access, Err_To_Out => True);
         pragma Unreferenced (Out_Text);
      begin
         for A of Args loop
            GNAT.OS_Lib.Free (A);
         end loop;
         Parses := List_Code = 0;
      end;
      if not Parses then
         return;
      end if;
      Write_Bytes (Signers_Path, "self " & Pub_Line & ASCII.LF);
      Write_Bytes (Sig_Path, Hex_Text_Pkg.Decode (Seal_Hex));
      declare
         Find_Code : aliased Integer := 1;
         Args : GNAT.OS_Lib.Argument_List :=
           (new String'("-Y"), new String'("find-principals"), new String'("-s"), new String'(Sig_Path),
            new String'("-f"), new String'(Signers_Path));
         Out_Text : constant String :=
           GNAT.Expect.Get_Command_Output (Ssh_Keygen, Args, "", Find_Code'Access, Err_To_Out => False);
         pragma Unreferenced (Out_Text);
      begin
         for A of Args loop
            GNAT.OS_Lib.Free (A);
         end loop;
         Not_Self := Find_Code /= 0;
      end;
      Remove (Sig_Path);
      Remove (Signers_Path);
   exception
      when others =>
         Not_Self := False;
         begin
            Remove (Sig_Path);
            Remove (Signers_Path);
         exception
            when others =>
               null;
         end;
   end Measure_Not_Self;

   --  SEAL a record AS A LINE under the namespace Under: the text and one line feed are written to a file of this
   --  process's own, ssh-keygen -Y sign writes <file>.sig, and the signature file's bytes come back as hex. Nothing
   --  of the key is read by this text.
   procedure Sign (Key_Path : String; Under : String; Text : String; Seal_Hex : out U.Unbounded_String; Ok : out Boolean) is
      Msg   : constant String := Ada.Directories.Compose (Work_Dir, "receipt-" & Pid_Text);
      Sig   : constant String := Msg & ".sig";
      Out_F : constant String := Ada.Directories.Compose (Work_Dir, "sign-" & Pid_Text & ".out");
      F     : Ada.Streams.Stream_IO.File_Type;
   begin
      Ok := False;
      Seal_Hex := U.Null_Unbounded_String;
      if not Ada.Directories.Exists (Work_Dir) then
         Ada.Directories.Create_Path (Work_Dir);
      end if;
      Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Msg);
      String'Write (Ada.Streams.Stream_IO.Stream (F), Text & ASCII.LF);
      Ada.Streams.Stream_IO.Close (F);
      declare
         Args : GNAT.OS_Lib.Argument_List :=
           (new String'("-Y"), new String'("sign"), new String'("-f"), new String'(Key_Path),
            new String'("-n"), new String'(Under), new String'(Msg));
         Success     : Boolean;
         Return_Code : Integer;
      begin
         GNAT.OS_Lib.Spawn (Ssh_Keygen, Args, Out_F, Success, Return_Code, Err_To_Out => True);
         for A of Args loop
            GNAT.OS_Lib.Free (A);
         end loop;
         if Success and then Return_Code = 0 and then Ada.Directories.Exists (Sig) then
            declare
               Bytes : constant String := Read_Small (Sig, Tower_Envelope_Pkg.Max_Line / 2);
               Hex   : constant String := Hex_Text_Pkg.Encode (Bytes);
            begin
               if Bytes'Length > 0 and then Tower_Envelope_Pkg.Is_Hex_Text (Hex) then
                  Seal_Hex := U.To_Unbounded_String (Hex);
                  Ok := True;
               end if;
            end;
         end if;
      end;
      Remove (Msg);
      Remove (Sig);
      Remove (Out_F);
   exception
      when others =>
         Ok := False;
         Seal_Hex := U.Null_Unbounded_String;
   end Sign;

   procedure Issue (Word : out U.Unbounded_String) is

      --  What was measured. Every one starts False: a fact nobody measured refuses.
      Have_Source : Boolean := False;
      Have_Key    : Boolean := False;
      Sealed      : Boolean := False;
      Payload_Ok  : Boolean := False;
      Seal_Known  : Boolean := False;
      Seal_Valid  : Boolean := False;
      Not_Self    : Boolean := False;
      Signed      : Boolean := False;
      Written     : Boolean := False;

      F : Tower_Receipt_Pkg.Issue_Facts;
      O : Tower_Receipt_Pkg.Outcome_Kind := Tower_Receipt_Pkg.Out_Refused_No_Source;

      Line_1           : U.Unbounded_String;
      Digest           : String (1 .. 64) := (others => '0');
      Seal_Hex         : U.Unbounded_String;
      Principal        : U.Unbounded_String;
      Receipt_Hex      : U.Unbounded_String;
      Receipt_Seal_Hex : U.Unbounded_String;
      Home             : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME") then Ada.Environment_Variables.Value ("HOME") else ".");
      Key_Path         : constant String := Home & Key_Rel;
      Signers          : constant String := Signers_Path;

      procedure Say (The_Word : String) is
      begin
         Append_Row
           (Record_Path,
            '{' & '"' & "tower_receipt" & '"' & ':' & '"' & The_Word & '"' & ','
            & '"' & "bundle_sha256" & '"' & ':' & '"' & Digest & '"' & ','
            & '"' & "principal" & '"' & ':' & '"' & U.To_String (Principal) & '"' & ','
            & '"' & "key_pub_sha256" & '"' & ':' & '"' & File_Digest (Key_Path & ".pub") & '"' & ','
            & '"' & "signers_sha256" & '"' & ':' & '"' & File_Digest (Signers) & '"' & ','
            & '"' & "at" & '"' & ':' & '"' & Seconds_Text (Now_Seconds) & '"' & '}');
         Word := U.To_Unbounded_String (The_Word);
      end Say;

   begin
      Word := U.To_Unbounded_String ("unmeasured");
      Have_Key := Ada.Directories.Exists (Key_Path);

      --  1. The source: two lines. Line 1 is kept VERBATIM; line 2 must be one seal and nothing else.
      declare
         Text : constant String := Read_Small (Source_Path, Tower_Payload_Pkg.Max_Line + Tower_Envelope_Pkg.Max_Line + 2);
         Cut  : Natural := 0;
      begin
         for I in Text'Range loop
            if Text (I) = ASCII.LF then
               Cut := I;
               exit;
            end if;
         end loop;
         if Cut > 1 and then Cut < Text'Last then
            declare
               L1 : constant String := One_Based (Text (1 .. Cut - 1));
               L2 : constant String := Strip (Text (Cut + 1 .. Text'Last));
            begin
               Have_Source := L1'Length <= Tower_Payload_Pkg.Max_Line and then L2'Length in 1 .. Tower_Envelope_Pkg.Max_Line
                 and then (for all K of L2 => K /= ASCII.LF);
               if Have_Source then
                  Line_1 := U.To_Unbounded_String (L1);
                  Digest := GNAT.SHA256.Digest (L1);
                  Sealed := Tower_Receipt_Pkg.Is_Seal_Line (L2);
                  if Sealed then
                     Seal_Hex := U.To_Unbounded_String
                       (One_Based (L2 (Tower_Envelope_Pkg.Seal_First .. Tower_Receipt_Pkg.Seal_Last (L2))));
                  end if;
                  Payload_Ok := Tower_Payload_Pkg.Payload_Ok (L1);
               end if;
            end;
         end if;
      end;

      --  2. The seal: made by a packer the signers file names, valid under df-tower, and not this issuer's own.
      if Have_Source and then Have_Key and then Sealed and then Payload_Ok then
         Measure_Seal (U.To_String (Line_1), U.To_String (Seal_Hex), Signers, Namespace, Seal_Known, Seal_Valid, Principal);
         if Seal_Valid then
            Measure_Not_Self (U.To_String (Seal_Hex), Key_Path & ".pub", Not_Self);
         end if;
      end if;

      --  3. The receipt: the record for THIS digest, sealed under df-admission; then the two files.
      if Seal_Valid and then Not_Self and then Tower_Stamp_Pkg.Is_Hex_Digest (Digest) then
         declare
            Rec : constant String := Tower_Pack_Pkg.Receipt_Text (Digest);
         begin
            Sign (Key_Path, Receipt_Namespace, Rec, Receipt_Seal_Hex, Signed);
            if Signed then
               declare
                  Seal   : constant String := U.To_String (Seal_Hex);
                  R_Hex  : constant String := Hex_Text_Pkg.Encode (Rec);
                  RS_Hex : constant String := U.To_String (Receipt_Seal_Hex);
                  W_Bundle  : Boolean := False;
                  W_Receipt : Boolean := False;
               begin
                  Receipt_Hex := U.To_Unbounded_String (R_Hex);
                  if Tower_Envelope_Pkg.Is_Hex_Text (Seal)
                    and then R_Hex'Length = 2 * Tower_Envelope_Pkg.Receipt_Length
                    and then Tower_Envelope_Pkg.Is_Hex_Text (R_Hex)
                    and then Tower_Envelope_Pkg.Is_Hex_Text (RS_Hex)
                    and then Seal'Length + RS_Hex'Length <= Tower_Envelope_Pkg.Max_Line - Tower_Pack_Pkg.Envelope_Fixed
                  then
                     Write_Two (Bundle_Path, U.To_String (Line_1), Tower_Pack_Pkg.Envelope_Text (Seal, R_Hex, RS_Hex), W_Bundle);
                     if W_Bundle then
                        Write_Two (Receipt_Path, R_Hex, RS_Hex, W_Receipt);
                     end if;
                     Written := W_Bundle and then W_Receipt;
                  end if;
               end;
            end if;
         end;
      end if;

      --  SLOT BEGIN (facts)
      F := (have_source => Have_Source, have_key => Have_Key, sealed => Sealed, payload_ok => Payload_Ok,
            seal_known => Seal_Known, seal_valid => Seal_Valid, not_self => Not_Self, signed => Signed,
            written => Written);
      --  SLOT END (facts)

      --  SLOT BEGIN (outcome)
      O := Tower_Receipt_Pkg.Outcome (F);
      --  SLOT END (outcome)

      declare
         The_Word : constant String :=
           (
            --  SLOT BEGIN (outcome_word)
            case O is
               when Tower_Receipt_Pkg.Out_Issued => "issued",
               when Tower_Receipt_Pkg.Out_Refused_No_Source => "refused_no_source",
               when Tower_Receipt_Pkg.Out_Refused_No_Key => "refused_no_key",
               when Tower_Receipt_Pkg.Out_Refused_Not_Sealed => "refused_not_sealed",
               when Tower_Receipt_Pkg.Out_Refused_Not_A_Payload => "refused_not_a_payload",
               when Tower_Receipt_Pkg.Out_Refused_Seal_Unknown => "refused_seal_unknown",
               when Tower_Receipt_Pkg.Out_Refused_Seal_Invalid => "refused_seal_invalid",
               when Tower_Receipt_Pkg.Out_Refused_Self_Sealed => "refused_self_sealed",
               when Tower_Receipt_Pkg.Out_Refused_Sign_Failed => "refused_sign_failed",
               when Tower_Receipt_Pkg.Out_Refused_Write_Failed => "refused_write_failed"
            --  SLOT END (outcome_word)
           );
      begin
         Say (The_Word);
      end;
   exception
      when others =>
         --  This edge never raises. What it could not measure, it did not receipt.
         Word := U.To_Unbounded_String ("unmeasured");
   end Issue;

end Tower_Receipt_Edge;
