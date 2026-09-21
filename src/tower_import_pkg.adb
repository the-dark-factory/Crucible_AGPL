--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 62fadc94fd4da7717abf3fc4a6f18d18d1ecd92fe883e13cf8ce3880a602a3bf
--
--  Tower_Import_Pkg body -- template with FOUR slots (facts, policy, verdict, verdict_word), filled by a Wu edge round.
--  PROVENANCE OF THE FIXED TEXT, said so that nobody has to guess:
--    LIFTED from FORGED, shipped text, unchanged but for names and indentation:
--      Strip and the two-line reading block ........ Tower_Base_Check_Edge (itself lifted from stamp_tower_main)
--      Write_Bytes, Remove, and the VERIFY CALL .... Palais_Enrol_Pkg body, lines 166-180 and 443-475:
--          GNAT.Expect.Get_Command_Output (ssh-keygen, -Y verify -f <signers> -I <identity> -n <namespace>
--          -s <sigfile>, <message>, Code'Access, Err_To_Out => True); Code = 0 is the verdict. The runtime feeds
--          the message on standard input and appends exactly ONE line feed, so a seal is over the text AS A LINE.
--          DIFFERENCES from the forged call, all of them: -I carries the principal MEASURED by find-principals (the
--          forged call passes a literal), kept only when Is_Safe_Name; -n is a parameter, df-tower for the bundle's
--          seal and df-admission for the receipt's (the owner's rulings O4 and R1, 2026-09-20); the verdict is read
--          inside the block; the signature file is this process's own (seal-<pid>.sig), removed on the exception
--          path too.
--      the clock as text ........................... stamp_build_main lineage 2 (To_Unix_Time_64, Trim).
--    SEAT-WRITTEN plumbing -- I/O and copying -- said in full (the second read found "none of it deciding" false):
--      Signers_Path (beside argv[0]; a bare name started through PATH names NO signers: that guard is the seat's,
--      ruled to stay under T1); File_Digest (the sha256 of the signers file, recorded in every row: O-2);
--      find-principals (the same package as the verify call, a different argument vector, empty input); the three
--      closing quotes and the three hex slices (FIXED here so that a fill can never transpose the two offsets);
--      Read_Ledger, which reads the ledger in BOUNDED lines and hands every one to the fold unit; Append_Row; the
--      policy file; the rows. THREE things here are not pure measurement, each said: a row is appended only when the
--      decider said Accepted (I/O gated on the verdict, not a verdict); a principal is trusted only when
--      Is_Safe_Name holds (ruled 2026-09-20 22:12); In_Date is recorded True only under a seal that verified (inert
--      for the verdict: Decide refuses integrity first).
--    Every judgement is a call into a proven package: Tower_Envelope_Pkg (414/418), Tower_Payload_Pkg (411/415),
--      Tower_Ledger_Line_Pkg (413/417), Tower_Ledger_Fold_Pkg (419: the fold, "unchanged", the running version,
--      whether the row LANDED, and the outcome word), Tower_Stamp_Pkg (408), Hex_Text_Pkg; the verdict is
--      Tower_Admission_Pkg.Decide's and nothing else's. The edge itself compares no version and takes no maximum.
with Ada.Calendar;
with Ada.Calendar.Conversions;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with GNAT.Expect;
with GNAT.OS_Lib;
with GNAT.SHA256;
with Interfaces.C;
with Crucible_Build;
with Crucible_Tower;
with Hex_Text_Pkg;
with Json_Scan_Pkg;
with Tower_Admission_Pkg;
with Tower_Envelope_Pkg;
with Tower_Ledger_Fold_Pkg;
with Tower_Ledger_Line_Pkg;
with Tower_Payload_Pkg;
with Tower_Stamp_Pkg;

package body Tower_Import_Pkg with SPARK_Mode => Off is

   use type Tower_Admission_Pkg.Verdict_Kind;
   use type Json_Scan_Pkg.Kind_Type;
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
   --  Recorded in every row so that a changed trust root leaves a trace (the owner's ruling O-2, 2026-09-21).
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

   --  One row and its line feed, in ONE write. A row that cannot be written is not an exception the door sees.
   --  A ledger whose last byte is not a line feed (a TORN final line) gets one FIRST, in the same write, so the new
   --  row never glues onto the torn one -- glued, neither would read as a row.
   procedure Append_Row (Row : String; Wrote : out Boolean) is
      F    : Ada.Streams.Stream_IO.File_Type;
      Torn : Boolean := False;
   begin
      Wrote := False;
      if Ada.Directories.Exists (Ledger_Path) and then Ada.Directories.Size (Ledger_Path) > 0 then
         declare
            G    : Ada.Streams.Stream_IO.File_Type;
            Last : Character;
         begin
            Ada.Streams.Stream_IO.Open (G, Ada.Streams.Stream_IO.In_File, Ledger_Path);
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
      if not Ada.Directories.Exists (Ada.Directories.Containing_Directory (Ledger_Path)) then
         Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Ledger_Path));
      end if;
      if Ada.Directories.Exists (Ledger_Path) then
         Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.Append_File, Ledger_Path);
      else
         Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Ledger_Path);
      end if;
      String'Write (Ada.Streams.Stream_IO.Stream (F), (if Torn then (1 => ASCII.LF) else "") & Row & ASCII.LF);
      Ada.Streams.Stream_IO.Close (F);
      Wrote := True;
   exception
      when others =>
         Wrote := False;
         if Ada.Streams.Stream_IO.Is_Open (F) then
            Ada.Streams.Stream_IO.Close (F);
         end if;
   end Append_Row;

   --  THE LEDGER, read in BOUNDED lines and handed line by line to the proven fold. The edge keeps no version, no
   --  digest and no maximum of its own: S carries them. A line longer than Line_Bound is cut there and the rest
   --  skipped (a row is 101 characters, so nothing cut can be a row, and nothing after it is hidden). The fold is
   --  WHOLE only when every line was read to the end of the file; any failure to read leaves it not whole, and a
   --  fold that is not whole is never asked "unchanged" and never lets a bundle be measured. Last_Line is the last
   --  line read, for the read-back after an append. No ledger file is an empty fold read to its end.
   procedure Read_Ledger (S : out Tower_Ledger_Fold_Pkg.Fold_State; Last_Line : out U.Unbounded_String) is
      File : Ada.Text_IO.File_Type;
      Buf  : String (1 .. Line_Bound);
      Last : Natural;
   begin
      S := Tower_Ledger_Fold_Pkg.Initial;
      Last_Line := U.Null_Unbounded_String;
      if not Ada.Directories.Exists (Ledger_Path) then
         S := Tower_Ledger_Fold_Pkg.Whole (S, True);
         return;
      end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Ledger_Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Buf, Last);
         if Last = Buf'Last and then not Ada.Text_IO.End_Of_File (File) then
            Ada.Text_IO.Skip_Line (File);
         end if;
         declare
            Row : constant String := Strip (Buf (1 .. Last));
         begin
            S := Tower_Ledger_Fold_Pkg.Add (S, Row);
            Last_Line := U.To_Unbounded_String (Row);
         end;
      end loop;
      Ada.Text_IO.Close (File);
      S := Tower_Ledger_Fold_Pkg.Whole (S, True);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         S := Tower_Ledger_Fold_Pkg.Whole (S, False);
   end Read_Ledger;

   function Now_Text return String is
     (Ada.Strings.Fixed.Trim
        (Interfaces.C.long_long'Image (Ada.Calendar.Conversions.To_Unix_Time_64 (Ada.Calendar.Clock)),
         Ada.Strings.Both));

   function Img (N : Tower_Admission_Pkg.Version_Number) return String is
     (Ada.Strings.Fixed.Trim (Tower_Admission_Pkg.Version_Number'Image (N), Ada.Strings.Both));

   --  The allowed_signers file BESIDE THE BINARY. "" when the binary's directory cannot be named: no file, no signer.
   function Signers_Path return String is
      Name : constant String := Ada.Command_Line.Command_Name;
   begin
      --  A bare name (started through PATH) would be resolved against the WORKING directory -- the tree that
      --  holds the untrusted bundle -- and whoever can write there would own the trust root. No slash, no signers.
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

   --  A principal is written into a ledger row, so it is kept only when it cannot break one.
   function Is_Safe_Name (S : String) return Boolean is
     (S'Length in 1 .. 128
      and then (for all C of S => C in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '@' | '.' | '_' | '-'));

   function First_Line (S : String) return String is
   begin
      for I in S'Range loop
         if S (I) in ASCII.LF | ASCII.CR then
            return One_Based (S (S'First .. I - 1));
         end if;
      end loop;
      return One_Based (S);
   end First_Line;

   --  MEASURE one seal. Message is signed AS A LINE (the runtime appends the one line feed). Known = the signature
   --  was made by a key the allowed_signers file names (find-principals); Valid = ssh-keygen -Y verify exits 0 for
   --  that principal under the namespace Under. Nothing is read from the bundle to say WHO signed.
   procedure Measure_Seal
     (Message   : String;
      Seal_Hex  : String;
      Signers   : String;
      Under     : String;
      Known     : out Boolean;
      Valid     : out Boolean;
      Principal : out U.Unbounded_String)
   is
      Sig_Path : constant String := Ada.Directories.Compose
        (Work_Dir, "seal-" & Ada.Strings.Fixed.Trim
           (Integer'Image (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id)), Ada.Strings.Both) & ".sig");
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
         Known := Find_Code = 0 and then Is_Safe_Name (Name);
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

   procedure Import (Word : out U.Unbounded_String) is

      --  What was measured. Every one starts False or zero: a fact nobody measured refuses.
      Well_Formed      : Boolean := False;
      Signature_Valid  : Boolean := False;
      Key_Known        : Boolean := False;
      Receipt_Verifies : Boolean := False;
      Digest_Matches   : Boolean := False;
      In_Date          : Boolean := False;
      Candidate        : Tower_Admission_Pkg.Version_Number := 0;
      Running          : Tower_Admission_Pkg.Version_Number := 0;
      Policy_On        : Boolean := False;
      Floor            : Tower_Admission_Pkg.Version_Number := 0;   --  the POLICY floor, a version (not the clock's)

      F : Tower_Admission_Pkg.Entry_Facts;
      P : Tower_Admission_Pkg.Owner_Policy;
      V : Tower_Admission_Pkg.Verdict_Kind := Tower_Admission_Pkg.Refused_Integrity;
      --  The OUTCOME, the fold unit's word for the verdict and whether the row landed. Set by the fixed text below;
      --  the verdict_word slot only reads it.
      O : Tower_Ledger_Fold_Pkg.Outcome_Kind := Tower_Ledger_Fold_Pkg.Out_Refused_Integrity;

      Read_Ok        : Boolean := False;
      L1, L2         : U.Unbounded_String;
      Digest         : String (1 .. 64) := (others => '0');
      Version_Text   : U.Unbounded_String;
      Signer         : U.Unbounded_String;
      S              : Tower_Ledger_Fold_Pkg.Fold_State := Tower_Ledger_Fold_Pkg.Initial;   --  the ledger, folded
      Ledger_Last    : U.Unbounded_String;
      Signers        : constant String := Signers_Path;
      Signers_Digest : constant String := File_Digest (Signers);

      procedure Say (The_Word : String) is
         Wrote : Boolean;
      begin
         Append_Row
           ('{' & '"' & "tower" & '"' & ':' & '"' & The_Word & '"' & ','
            & '"' & "candidate" & '"' & ':' & '"' & Img (Candidate) & '"' & ','
            & '"' & "running" & '"' & ':' & '"' & Img (Running) & '"' & ','
            & '"' & "first_accepted_row" & '"' & ':' & '"' & (if S.have_row then "false" else "true") & '"' & ','
            & '"' & "digest" & '"' & ':' & '"' & Digest & '"' & ','
            & '"' & "signer" & '"' & ':' & '"' & (if Signature_Valid then U.To_String (Signer) else "") & '"' & ','
            & '"' & "signers_sha256" & '"' & ':' & '"' & Signers_Digest & '"' & ','
            & '"' & "at" & '"' & ':' & '"' & Now_Text & '"' & '}', Wrote);
         pragma Unreferenced (Wrote);
         Word := U.To_Unbounded_String (The_Word);
      end Say;

   begin
      Word := U.To_Unbounded_String ("refused_integrity");

      --  8. THE LEDGER FIRST, folded by the proven unit: every line; the highest accepted version; the last accepted
      --  digest; whether the read reached the end. Running is the LARGER of that and the compiled-in base version
      --  (the owner's ruling R3), by the fold unit's own comparison. Nothing here is compared by the edge.
      Read_Ledger (S, Ledger_Last);
      Running := Tower_Ledger_Fold_Pkg.Running (S, Crucible_Tower.Base_Version);

      --  0. ABSENT is the normal state of most factories: a row, no decider, no slot.
      if not Ada.Directories.Exists (Bundle_Path) then
         Say ("absent");
         return;
      end if;

      --  1. The two lines, by the base's own acceptance test (lifted).
      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Bundle_Path);
         if Ada.Text_IO.End_Of_File (File) then
            Ada.Text_IO.Close (File);
         else
            L1 := U.To_Unbounded_String (Ada.Text_IO.Get_Line (File));
            if Ada.Text_IO.End_Of_File (File) then
               Ada.Text_IO.Close (File);
            else
               L2 := U.To_Unbounded_String (Ada.Text_IO.Get_Line (File));
               Read_Ok := Ada.Text_IO.End_Of_File (File);
               Ada.Text_IO.Close (File);
            end if;
         end if;
      exception
         when others =>
            Read_Ok := False;
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
      end;

      --  A bundle is measured ONLY against a ledger read whole. A ledger that could not be read to its end leaves
      --  every fact unmeasured, and the decider refuses what nobody measured.
      if Read_Ok and then Tower_Ledger_Fold_Pkg.Usable (S) then
         declare
            Text_1 : constant String := Strip (U.To_String (L1));
            Text_2 : constant String := Strip (U.To_String (L2));
         begin
            if Text_1'Length in 1 .. Tower_Payload_Pkg.Max_Line
              and then Text_2'Length in 2 .. Tower_Envelope_Pkg.Max_Line + Tower_Envelope_Pkg.Tail_Length
            then
               Digest := GNAT.SHA256.Digest (Text_1);

               --  6b. UNCHANGED: the same bundle measured again is a row, no decider, no slot. The fold unit says so
               --  (the last accepted row names this digest, and the fold is whole).
               if Tower_Ledger_Fold_Pkg.Unchanged (S, Digest) then
                  Say ("unchanged");
                  return;
               end if;

               declare
                  --  2. The three closing quotes. Nothing is searched for by NAME and no JSON is parsed: the first
                  --  double quote at or after Seal_First ends the seal; the envelope unit fixes the other two.
                  Quote  : Natural := 0;
                  Q_Last : constant Natural := Text_2'Length - Tower_Envelope_Pkg.Tail_Length;
               begin
                  for I in Tower_Envelope_Pkg.Seal_First .. Text_2'Last loop
                     if Text_2 (I) = '"' then
                        Quote := I;
                        exit;
                     end if;
                  end loop;
                  if Quote > Tower_Envelope_Pkg.Seal_First
                    and then Quote - 1 + Tower_Envelope_Pkg.Receipt_Span <= Tower_Envelope_Pkg.Max_Line
                    and then Q_Last <= Tower_Envelope_Pkg.Max_Line
                  then
                     declare
                        S_Last : constant Tower_Envelope_Pkg.Index_Type := Quote - 1;
                        R_Last : constant Tower_Envelope_Pkg.Index_Type := S_Last + Tower_Envelope_Pkg.Receipt_Span;
                     begin
                        if Tower_Envelope_Pkg.Envelope_Is (Text_2, S_Last, R_Last, Q_Last) then
                           declare
                              --  THE THREE SLICES. Fixed text: a fill can never transpose the two offsets.
                              Seal_Hex    : constant String :=
                                One_Based (Text_2 (Tower_Envelope_Pkg.Seal_First .. S_Last));
                              Receipt_Hex : constant String :=
                                One_Based (Text_2 (S_Last + Tower_Envelope_Pkg.Receipt_Offset .. R_Last));
                              R_Seal_Hex  : constant String :=
                                One_Based (Text_2 (R_Last + Tower_Envelope_Pkg.Receipt_Seal_Offset .. Q_Last));
                           begin
                              if Hex_Text_Pkg.Is_Hex_Text (Seal_Hex) and then Hex_Text_Pkg.Is_Hex_Text (Receipt_Hex)
                                and then Hex_Text_Pkg.Is_Hex_Text (R_Seal_Hex)
                              then
                                 declare
                                    Receipt   : constant String := One_Based (Hex_Text_Pkg.Decode (Receipt_Hex));
                                    R_Known   : Boolean;
                                    R_Valid   : Boolean;
                                    R_Signer  : U.Unbounded_String;
                                 begin
                                    --  3, 4. The seal over line 1 AS A LINE, under df-tower; WHO signed is measured.
                                    Measure_Seal (Text_1, Seal_Hex, Signers, Namespace, Key_Known, Signature_Valid, Signer);
                                    --  5. The receipt's own seal, over the receipt record AS A LINE, under df-admission.
                                    Measure_Seal (Receipt, R_Seal_Hex, Signers, Receipt_Namespace, R_Known, R_Valid, R_Signer);
                                    Receipt_Verifies := R_Known and then R_Valid;
                                    --  6. The receipt NAMES line 1's digest, all 64 characters.
                                    Digest_Matches := Tower_Envelope_Pkg.Receipt_Names (Receipt, Digest);
                                 end;
                                 --  1, 7. Line 1 is the pinned payload and its version reads as one.
                                 Well_Formed := Tower_Payload_Pkg.Payload_Ok (Text_1)
                                   and then Tower_Payload_Pkg.Version_Text_Ok (Text_1);
                                 if Well_Formed then
                                    Version_Text := U.To_Unbounded_String
                                      (Text_1 (Tower_Payload_Pkg.Version_Span (Text_1).first
                                               .. Tower_Payload_Pkg.Version_Span (Text_1).last));
                                    Candidate := Tower_Admission_Pkg.Version_Number'Value (U.To_String (Version_Text));
                                 end if;
                                 --  10. In date: read ONLY from signed text, and only under a seal that verified.
                                 In_Date := Signature_Valid and then Well_Formed
                                   and then Tower_Payload_Pkg.In_Date (Text_1, Now_Text, Crucible_Build.Commit_Time);
                              end if;
                           end;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end if;

      --  9. The owner's policy: ONE line, every value a string. Absent or unreadable = deliveries off, floor 0.
      if Ada.Directories.Exists (Policy_Path) then
         declare
            File : Ada.Text_IO.File_Type;
         begin
            Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Policy_Path);
            if not Ada.Text_IO.End_Of_File (File) then
               declare
                  Line : constant String := Strip (Ada.Text_IO.Get_Line (File));
               begin
                  if Line'Length in 1 .. 1048576 then
                     declare
                        A : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "accept_deliveries");
                        B : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "floor");
                     begin
                        Policy_On := A.found and then A.kind = Json_Scan_Pkg.K_String
                          and then Line (A.first .. A.last) = '"' & "true" & '"';
                        if B.found and then B.kind = Json_Scan_Pkg.K_String and then B.last - B.first >= 2
                          and then Tower_Stamp_Pkg.Is_Version_Text (One_Based (Line (B.first + 1 .. B.last - 1)))
                        then
                           Floor := Tower_Admission_Pkg.Version_Number'Value (Line (B.first + 1 .. B.last - 1));
                        else
                           --  A floor that is absent or cannot be read is not "no floor": deliveries go OFF.
                           Policy_On := False;
                        end if;
                     end;
                  end if;
               end;
            end if;
            Ada.Text_IO.Close (File);
         exception
            when others =>
               Policy_On := False;
               Floor := 0;
               if Ada.Text_IO.Is_Open (File) then
                  Ada.Text_IO.Close (File);
               end if;
         end;
      end if;

      --  SLOT BEGIN (facts)
      F := (well_formed => Well_Formed, signature_valid => Signature_Valid, key_known => Key_Known,
            receipt_verifies => Receipt_Verifies, digest_matches => Digest_Matches, in_date => In_Date,
            candidate => Candidate, running => Running);
      --  SLOT END (facts)

      --  SLOT BEGIN (policy)
      P := (accept_deliveries => Policy_On, floor => Floor);
      --  SLOT END (policy)

      --  SLOT BEGIN (verdict)
      V := Tower_Admission_Pkg.Decide (F, P);
      --  SLOT END (verdict)

      --  ACCEPTED: the machine row is appended by the proven writer (it is the mark Tower_Select_Pkg's caller reads)
      --  and then READ BACK. THE ROW IS THE ACCEPTANCE: whether it LANDED is the fold unit's question of the last
      --  line read back, and the WORD is the fold unit's Outcome -- Accepted with no row read back is unrecorded,
      --  the tower is left as it was, and the door forges on the base. The edge writes, reads, and asks.
      declare
         Landed : Boolean := False;
      begin
         if V = Tower_Admission_Pkg.Accepted
           and then Tower_Stamp_Pkg.Is_Hex_Digest (Digest)
           and then Tower_Stamp_Pkg.Is_Version_Text (U.To_String (Version_Text))
         then
            declare
               Padded_V : constant String :=
                 Tower_Ledger_Line_Pkg.Padded (One_Based (U.To_String (Version_Text)));
               Wrote    : Boolean;
               After    : Tower_Ledger_Fold_Pkg.Fold_State;
               Last     : U.Unbounded_String;
            begin
               --  The writer's own word is not the evidence: the row read back is.
               Append_Row (Tower_Ledger_Line_Pkg.Accepted_Row (Digest, Padded_V), Wrote);
               pragma Unreferenced (Wrote);
               Read_Ledger (After, Last);
               Landed := Tower_Ledger_Fold_Pkg.Usable (After)
                 and then Tower_Ledger_Fold_Pkg.Row_Landed (One_Based (U.To_String (Last)), Digest, Padded_V);
            end;
         end if;
         O := Tower_Ledger_Fold_Pkg.Outcome (V, Landed);
      end;

      declare
         The_Word : constant String :=
           (
            --  SLOT BEGIN (verdict_word)
            case O is
               when Tower_Ledger_Fold_Pkg.Out_Accepted => "accepted",
               when Tower_Ledger_Fold_Pkg.Out_Unrecorded => "unrecorded",
               when Tower_Ledger_Fold_Pkg.Out_Declined => "declined_by_policy",
               when Tower_Ledger_Fold_Pkg.Out_Refused_Receipt => "refused_receipt",
               when Tower_Ledger_Fold_Pkg.Out_Refused_Integrity => "refused_integrity"
            --  SLOT END (verdict_word)
           );
      begin
         Say (The_Word);
      end;
   exception
      when others =>
         --  This edge never raises and never stops a forge. What it could not measure, it refuses.
         Word := U.To_Unbounded_String ("refused_integrity");
   end Import;

end Tower_Import_Pkg;
