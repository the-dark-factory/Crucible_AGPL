--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 79d50ebd94d3195c74ae6cc98d493982744802dab1434c923a830f7b2bd378e2
--
--  Tower_Pack_Edge body -- template with THREE slots (facts, outcome, outcome_word), filled by a Wu edge round.
--  PROVENANCE OF THE FIXED TEXT, said so that nobody has to guess:
--    LIFTED from FORGED, shipped text, unchanged but for names and indentation:
--      Strip, One_Based, the bounded line read, Append_Row, File_Digest ..... Tower_Import_Pkg body (crucible fef88e0)
--      the ssh-keygen call by ARGUMENT VECTOR (-f <key>) ................... Palais_Enrol_Pkg body (key generation)
--      the clock as text ................................................. stamp_build_main lineage 2
--    SEAT-WRITTEN plumbing, I/O and copying, said in full: String_Value (one JSON string field of one bounded row,
--      through Json_Scan_Pkg); the ledger fold (every row asked of Tower_Pack_Pkg.Shareable; the LATEST row per core
--      kept -- the comparison is Tower_Pack_Pkg.Later's, the keeping is a loop); the ORDER of entries by core name
--      (an insertion sort; the order is a claim, said, so the bundle is reproducible byte for byte from one ledger);
--      the version counter (the highest version in state/tower-pack.jsonl, plus one); Sign (write line 1 as a LINE,
--      spawn ssh-keygen -Y sign, read the signature file, hex through Hex_Text_Pkg.Encode); the two writers; the
--      completion read; the record row. TWO things here are not pure measurement, each said: a fresh pack is
--      attempted only when the ledger, the key and at least one entry are present (I/O gated on facts); completion is
--      chosen when tower/pack.receipt exists (a measured fact chooses the decider).
--    Every judgement is a call into a proven package: Tower_Pack_Pkg (Is_Core_Name, Shareable, Later,
--      Component_Entry, Head, Line_1, Envelope_Text, Outcome, Completion), Tower_Envelope_Pkg (Is_Hex_Text,
--      Receipt_Names on the given receipt), Tower_Payload_Pkg (Is_Seconds_Text, Max_Line), Tower_Stamp_Pkg
--      (Is_Hex_Digest, Is_Version_Text), Json_Scan_Pkg, Hex_Text_Pkg. The edge shapes no text of its own but the
--      record row and the unreceipted line 2, both said.
with Ada.Calendar;
with Ada.Calendar.Conversions;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.OS_Lib;
with GNAT.SHA256;
with Interfaces.C;
with Hex_Text_Pkg;
with Json_Scan_Pkg;
with Tower_Envelope_Pkg;
with Tower_Pack_Pkg;
with Tower_Payload_Pkg;
with Tower_Stamp_Pkg;

package body Tower_Pack_Edge with SPARK_Mode => Off is

   use type Json_Scan_Pkg.Kind_Type;
   use type Ada.Directories.File_Size;
   use type Ada.Streams.Stream_Element_Offset;
   use type Interfaces.C.long_long;

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

   function One_Based (S : String) return String is
      R : constant String (1 .. S'Length) := S;
   begin
      return R;
   end One_Based;

   function Now_Seconds return Interfaces.C.long_long is
     (Ada.Calendar.Conversions.To_Unix_Time_64 (Ada.Calendar.Clock));

   function Seconds_Text (T : Interfaces.C.long_long) return String is
     (Ada.Strings.Fixed.Trim (Interfaces.C.long_long'Image (T), Ada.Strings.Both));

   function Img (N : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Both));

   --  One line, bounded: at most Line_Bound characters; the rest of a longer line is skipped.
   procedure Get_Bounded (File : Ada.Text_IO.File_Type; Buf : out String; Last : out Natural) is
   begin
      Ada.Text_IO.Get_Line (File, Buf, Last);
      if Last = Buf'Last and then not Ada.Text_IO.End_Of_File (File) then
         Ada.Text_IO.Skip_Line (File);
      end if;
   end Get_Bounded;

   --  The contents of one JSON STRING field of a one-based row, or "" when absent or not a string.
   function String_Value (Row : String; Key : String) return String is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Row, Key);
   begin
      if S.found and then S.kind = Json_Scan_Pkg.K_String and then S.first + 1 <= S.last - 1 then
         return One_Based (Row (S.first + 1 .. S.last - 1));
      end if;
      return "";
   end String_Value;

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

   --  SEAL line 1 AS A LINE: the text and one line feed are written to a file of this process's own, ssh-keygen -Y sign
   --  writes <file>.sig, and the signature file's bytes come back as hex. Nothing of the key is read by this text.
   procedure Sign (Key_Path : String; Line_1 : String; Seal_Hex : out U.Unbounded_String; Ok : out Boolean) is
      Pid  : constant String :=
        Ada.Strings.Fixed.Trim (Integer'Image (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id)), Ada.Strings.Both);
      Msg  : constant String := Ada.Directories.Compose (Work_Dir, "line1-" & Pid);
      Sig  : constant String := Msg & ".sig";
      Out_F : constant String := Ada.Directories.Compose (Work_Dir, "sign-" & Pid & ".out");
      F    : Ada.Streams.Stream_IO.File_Type;
   begin
      Ok := False;
      Seal_Hex := U.Null_Unbounded_String;
      if not Ada.Directories.Exists (Work_Dir) then
         Ada.Directories.Create_Path (Work_Dir);
      end if;
      Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Msg);
      String'Write (Ada.Streams.Stream_IO.Stream (F), Line_1 & ASCII.LF);
      Ada.Streams.Stream_IO.Close (F);
      declare
         Args : GNAT.OS_Lib.Argument_List :=
           (new String'("-Y"), new String'("sign"), new String'("-f"), new String'(Key_Path),
            new String'("-n"), new String'(Namespace), new String'(Msg));
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
      if Ada.Directories.Exists (Msg) then
         Ada.Directories.Delete_File (Msg);
      end if;
      if Ada.Directories.Exists (Sig) then
         Ada.Directories.Delete_File (Sig);
      end if;
      if Ada.Directories.Exists (Out_F) then
         Ada.Directories.Delete_File (Out_F);
      end if;
   exception
      when others =>
         Ok := False;
         Seal_Hex := U.Null_Unbounded_String;
   end Sign;

   procedure Pack (Word : out U.Unbounded_String) is

      --  FRESH facts. Every one starts False: a fact nobody measured refuses.
      Have_Ledger  : Boolean := False;
      Have_Key     : Boolean := False;
      Have_Entries : Boolean := False;
      Fits         : Boolean := False;
      Signed       : Boolean := False;
      Written      : Boolean := False;
      --  COMPLETION facts.
      Completing       : Boolean := False;
      Have_Source      : Boolean := False;
      Sealed           : Boolean := False;
      Receipt_Names_It : Boolean := False;
      C_Written        : Boolean := False;

      F : Tower_Pack_Pkg.Pack_Facts;
      C : Tower_Pack_Pkg.Completion_Facts;
      O : Tower_Pack_Pkg.Outcome_Kind := Tower_Pack_Pkg.Out_Refused_No_Ledger;

      Names   : array (1 .. Max_Entries) of U.Unbounded_String;
      Digests : array (1 .. Max_Entries) of U.Unbounded_String;
      Stamps  : array (1 .. Max_Entries) of U.Unbounded_String;
      Count   : Natural := 0;
      Overflow : Boolean := False;

      Version_Text : U.Unbounded_String;
      Expires_Text : U.Unbounded_String;
      Line_1       : U.Unbounded_String;
      Digest       : String (1 .. 64) := (others => '0');
      Seal_Hex     : U.Unbounded_String;
      Home         : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME") then Ada.Environment_Variables.Value ("HOME") else ".");
      Key_Path     : constant String := Home & Key_Rel;

      procedure Say (The_Word : String) is
      begin
         Append_Row
           (Record_Path,
            '{' & '"' & "tower_pack" & '"' & ':' & '"' & The_Word & '"' & ','
            & '"' & "version" & '"' & ':' & '"' & U.To_String (Version_Text) & '"' & ','
            & '"' & "digest" & '"' & ':' & '"' & Digest & '"' & ','
            & '"' & "entries" & '"' & ':' & '"' & Img (Count) & '"' & ','
            & '"' & "key_pub_sha256" & '"' & ':' & '"' & File_Digest (Key_Path & ".pub") & '"' & ','
            & '"' & "at" & '"' & ':' & '"' & Seconds_Text (Now_Seconds) & '"' & '}');
         Word := U.To_Unbounded_String (The_Word);
      end Say;

   begin
      Word := U.To_Unbounded_String ("unmeasured");
      Have_Key := Ada.Directories.Exists (Key_Path);
      Completing := Ada.Directories.Exists (Receipt_Path);

      if Completing then
         --  COMPLETION: the source is out/tower.unreceipted; its line 1 and seal are reused VERBATIM.
         declare
            Text : constant String := Read_Small (Unreceipted_Path, Tower_Payload_Pkg.Max_Line + Tower_Envelope_Pkg.Max_Line + 2);
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
                  Have_Source := L1'Length <= Tower_Payload_Pkg.Max_Line and then L2'Length in 12 .. Tower_Envelope_Pkg.Max_Line
                    and then (for all K of L2 => K /= ASCII.LF);
                  if Have_Source then
                     Line_1 := U.To_Unbounded_String (L1);
                     Digest := GNAT.SHA256.Digest (L1);
                     declare
                        Seal : constant String := String_Value (L2, "seal");
                     begin
                        Sealed := Seal'Length > 0 and then Tower_Envelope_Pkg.Is_Hex_Text (Seal);
                        if Sealed then
                           Seal_Hex := U.To_Unbounded_String (Seal);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
         if Sealed then
            declare
               Text : constant String := Read_Small (Receipt_Path, 2 * Tower_Envelope_Pkg.Max_Line);
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
                     R_Hex  : constant String := One_Based (Text (1 .. Cut - 1));
                     RS_Hex : constant String := Strip (Text (Cut + 1 .. Text'Last));
                     Seal   : constant String := U.To_String (Seal_Hex);
                  begin
                     if R_Hex'Length = 2 * Tower_Envelope_Pkg.Receipt_Length
                       and then Tower_Envelope_Pkg.Is_Hex_Text (R_Hex)
                       and then Tower_Envelope_Pkg.Is_Hex_Text (RS_Hex)
                       and then Seal'Length + RS_Hex'Length <= Tower_Envelope_Pkg.Max_Line - Tower_Pack_Pkg.Envelope_Fixed
                     then
                        Receipt_Names_It :=
                          Tower_Envelope_Pkg.Receipt_Names (One_Based (Hex_Text_Pkg.Decode (R_Hex)), Digest);
                        if Receipt_Names_It then
                           Write_Two (Bundle_Path, U.To_String (Line_1),
                                      Tower_Pack_Pkg.Envelope_Text (Seal, R_Hex, RS_Hex), C_Written);
                        end if;
                     end if;
                  end;
               end if;
            end;
         end if;
      else
         --  FRESH. 1. The ledger copy, every row bounded; the latest shareable row per core is kept.
         if Ada.Directories.Exists (Ledger_Path) then
            declare
               File : Ada.Text_IO.File_Type;
               Buf  : String (1 .. Line_Bound);
               Last : Natural;
            begin
               Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Ledger_Path);
               while not Ada.Text_IO.End_Of_File (File) loop
                  Get_Bounded (File, Buf, Last);
                  declare
                     Row    : constant String := Strip (Buf (1 .. Last));
                     Name   : constant String := String_Value (Row, "core");
                     Dg     : constant String := String_Value (Row, "source_sha256");
                     Ts     : constant String := String_Value (Row, "measured_ts");
                     Prove  : constant Boolean := String_Value (Row, "prove") = "PROVE_OK";
                     Clean  : constant Boolean := String_Value (Row, "meathead") = "CLEAN";
                     Found  : Natural := 0;
                  begin
                     if Tower_Pack_Pkg.Shareable (Prove, Clean, Tower_Pack_Pkg.Is_Core_Name (Name),
                                                  Tower_Stamp_Pkg.Is_Hex_Digest (Dg))
                       and then Tower_Pack_Pkg.Is_Timestamp_Text (Ts)
                     then
                        for J in 1 .. Count loop
                           if U.To_String (Names (J)) = Name then
                              Found := J;
                              exit;
                           end if;
                        end loop;
                        if Found > 0 then
                           if Tower_Pack_Pkg.Later (Ts, U.To_String (Stamps (Found))) then
                              Digests (Found) := U.To_Unbounded_String (Dg);
                              Stamps (Found) := U.To_Unbounded_String (Ts);
                           end if;
                        elsif Count < Max_Entries then
                           Count := Count + 1;
                           Names (Count) := U.To_Unbounded_String (Name);
                           Digests (Count) := U.To_Unbounded_String (Dg);
                           Stamps (Count) := U.To_Unbounded_String (Ts);
                        else
                           Overflow := True;
                        end if;
                     end if;
                  end;
               end loop;
               Ada.Text_IO.Close (File);
               Have_Ledger := True;
            exception
               when others =>
                  Have_Ledger := False;
                  if Ada.Text_IO.Is_Open (File) then
                     Ada.Text_IO.Close (File);
                  end if;
            end;
         end if;
         Have_Entries := Have_Ledger and then Count > 0;

         if Have_Ledger and then Have_Key and then Have_Entries then
            --  2. The ORDER: by core name, ascending (an insertion sort; the order is a claim of this edge).
            for I in 2 .. Count loop
               declare
                  N : constant U.Unbounded_String := Names (I);
                  D : constant U.Unbounded_String := Digests (I);
                  S : constant U.Unbounded_String := Stamps (I);
                  J : Natural := I;
               begin
                  while J > 1 and then U.To_String (Names (J - 1)) > U.To_String (N) loop
                     Names (J) := Names (J - 1);
                     Digests (J) := Digests (J - 1);
                     Stamps (J) := Stamps (J - 1);
                     J := J - 1;
                  end loop;
                  Names (J) := N;
                  Digests (J) := D;
                  Stamps (J) := S;
               end;
            end loop;

            --  3. The version: this packer's own counter, the highest version recorded plus one.
            declare
               Highest : Natural := 0;
            begin
               if Ada.Directories.Exists (Record_Path) then
                  declare
                     File : Ada.Text_IO.File_Type;
                     Buf  : String (1 .. Line_Bound);
                     Last : Natural;
                  begin
                     Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Record_Path);
                     while not Ada.Text_IO.End_Of_File (File) loop
                        Get_Bounded (File, Buf, Last);
                        declare
                           V : constant String := String_Value (Strip (Buf (1 .. Last)), "version");
                        begin
                           if Tower_Stamp_Pkg.Is_Version_Text (V) and then Natural'Value (V) > Highest then
                              Highest := Natural'Value (V);
                           end if;
                        end;
                     end loop;
                     Ada.Text_IO.Close (File);
                  exception
                     when others =>
                        if Ada.Text_IO.Is_Open (File) then
                           Ada.Text_IO.Close (File);
                        end if;
                  end;
               end if;
               if Highest < 999_999_999 then
                  Version_Text := U.To_Unbounded_String (Img (Highest + 1));
               end if;
            end;
            Expires_Text := U.To_Unbounded_String (Seconds_Text (Now_Seconds + Expires_After));

            --  4. Line 1, as the import side pins it; every piece is the core's.
            declare
               V : constant String := U.To_String (Version_Text);
               E : constant String := U.To_String (Expires_Text);
               Interior : U.Unbounded_String;
            begin
               for I in 1 .. Count loop
                  if I > 1 then
                     U.Append (Interior, ",");
                  end if;
                  U.Append (Interior, Tower_Pack_Pkg.Component_Entry
                              (One_Based (U.To_String (Names (I))), One_Based (U.To_String (Digests (I)))));
               end loop;
               if Tower_Stamp_Pkg.Is_Version_Text (V) and then Tower_Payload_Pkg.Is_Seconds_Text (E)
                 and then not Overflow
               then
                  declare
                     H : constant String := Tower_Pack_Pkg.Head (V, E);
                     I : constant String := U.To_String (Interior);
                  begin
                     if H'Length <= Tower_Payload_Pkg.Max_Line and then I'Length <= Tower_Payload_Pkg.Max_Line
                       and then H'Length + I'Length + 2 <= Tower_Payload_Pkg.Max_Line
                     then
                        Fits := True;
                        Line_1 := U.To_Unbounded_String (Tower_Pack_Pkg.Line_1 (H, I));
                        Digest := GNAT.SHA256.Digest (U.To_String (Line_1));
                     end if;
                  end;
               end if;
            end;

            --  5. The seal, then the unreceipted bundle.
            if Fits then
               Sign (Key_Path, U.To_String (Line_1), Seal_Hex, Signed);
               if Signed then
                  Write_Two (Unreceipted_Path, U.To_String (Line_1),
                             '{' & '"' & "seal" & '"' & ':' & '"' & U.To_String (Seal_Hex) & '"' & '}', Written);
               end if;
            end if;
         end if;
      end if;

      --  SLOT BEGIN (facts)
      F := (have_ledger => Have_Ledger, have_key => Have_Key, have_entries => Have_Entries, fits => Fits,
            signed => Signed, written => Written);
      C := (have_source => Have_Source, sealed => Sealed, receipt_names_it => Receipt_Names_It, written => C_Written);
      --  SLOT END (facts)

      --  SLOT BEGIN (outcome)
      O := (if Completing then Tower_Pack_Pkg.Completion (C) else Tower_Pack_Pkg.Outcome (F));
      --  SLOT END (outcome)

      declare
         The_Word : constant String :=
           (
            --  SLOT BEGIN (outcome_word)
            case O is
               when Tower_Pack_Pkg.Out_Packed => "packed",
               when Tower_Pack_Pkg.Out_Packed_Unreceipted => "packed_unreceipted",
               when Tower_Pack_Pkg.Out_Refused_No_Ledger => "refused_no_ledger",
               when Tower_Pack_Pkg.Out_Refused_No_Key => "refused_no_key",
               when Tower_Pack_Pkg.Out_Refused_Nothing_Shareable => "refused_nothing_shareable",
               when Tower_Pack_Pkg.Out_Refused_Too_Large => "refused_too_large",
               when Tower_Pack_Pkg.Out_Refused_Sign_Failed => "refused_sign_failed",
               when Tower_Pack_Pkg.Out_Refused_Write_Failed => "refused_write_failed",
               when Tower_Pack_Pkg.Out_Refused_No_Source => "refused_no_source",
               when Tower_Pack_Pkg.Out_Refused_Receipt_Mismatch => "refused_receipt_mismatch"
            --  SLOT END (outcome_word)
           );
      begin
         Say (The_Word);
      end;
   exception
      when others =>
         --  This edge never raises. What it could not measure, it did not pack.
         Word := U.To_Unbounded_String ("unmeasured");
   end Pack;

end Tower_Pack_Edge;
