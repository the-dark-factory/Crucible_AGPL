--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 6ab5f60e7453787827ac761106c7a47e9994d245dad379a48c5d79b92bd6095b
--
--  Tower_Fetch_Pkg body -- seat-written plumbing, no slot (the loopback build brief of 2026-09-21, piece B; the cover
--  table BRIEF_tower_index_pkg_cover_table_2026-09-21 section 4). Every judgement is a call into a proven package.
--  PROVENANCE OF THE TEXT, said so that nobody has to guess:
--    LIFTED from shipped text, unchanged but for names:
--      Strip, One_Based, Write_Bytes, Remove, Now_Text, Img, Signers_Path, Is_Safe_Name, First_Line, Measure_Seal,
--      Read_Ledger, Append_Row ...................... Tower_Import_Pkg body (2026-09-21); the verify call is the one
--                                                    Palais_Enrol_Pkg forged (find-principals, then -Y verify).
--      Ask (one line out on the reef rail, one line back) ... Palais_Enrol_Pkg body, with the reply bound a parameter
--                                                    because the fetch reply outgrows the rail line's max_reply_bytes.
--      the reef line from config/rail.conf ........... Palais_Enrol_Pkg.Step (Rail_Config_Pkg judges validity).
--    SEAT-WRITTEN here, I/O only: the row; hex decode into a heap buffer; the first line feed's position and the brace
--      positions (handed to Tower_Index_Pkg.Two_Lines_At / Object_At, which judge them); text-to-number of a version
--      ('Value, as the import edge does it); writing tower/sharer.bundle; the word as text.
--    JUDGED by proven packages and nothing else: Tower_Index_Pkg (Reply_Is, Hex_Last, Two_Lines_At, Index_Ok, Fresh,
--      Entry_Ok, Object_At, Taken, Consider, May_Ask, Digest_Names, Outcome), Tower_Receipt_Pkg (Is_Seal_Line,
--      Seal_Last: the index envelope), Tower_Payload_Pkg (Version_Span, Expires_Span, Is_Seconds_Text),
--      Tower_Ledger_Fold_Pkg (Running), Rail_Config_Pkg, Hex_Text_Pkg, Tower_Stamp_Pkg.
--    Every version and every name is read from SIGNED text only: nothing in the index is read before its seal verifies.
with Ada.Calendar;
with Ada.Calendar.Conversions;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with GNAT.Expect;
with GNAT.OS_Lib;
with GNAT.SHA256;
with Interfaces.C;
with Crucible_Tower;
with Hex_Text_Pkg;
with Json_Scan_Pkg;
with Rail_Config_Pkg;
with Rail_Socket_Edge;
with Tower_Admission_Pkg;
with Tower_Envelope_Pkg;
with Tower_Index_Pkg;
with Tower_Ledger_Fold_Pkg;
with Tower_Payload_Pkg;
with Tower_Receipt_Pkg;
with Tower_Stamp_Pkg;

package body Tower_Fetch_Pkg with SPARK_Mode => Off is

   use type Json_Scan_Pkg.Kind_Type;
   use type Rail_Config_Pkg.Rail_Kind;
   use type Tower_Admission_Pkg.Version_Number;
   use type Tower_Index_Pkg.Outcome_Kind;
   use type Ada.Directories.File_Size;

   package U renames Ada.Strings.Unbounded;

   type Text_Access is access String;
   procedure Free is new Ada.Unchecked_Deallocation (String, Text_Access);

   LF : constant Character := ASCII.LF;

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

   function Now_Text return String is
     (Ada.Strings.Fixed.Trim
        (Interfaces.C.long_long'Image (Ada.Calendar.Conversions.To_Unix_Time_64 (Ada.Calendar.Clock)),
         Ada.Strings.Both));

   function Img (N : Tower_Admission_Pkg.Version_Number) return String is
     (Ada.Strings.Fixed.Trim (Tower_Admission_Pkg.Version_Number'Image (N), Ada.Strings.Both));

   function Img (N : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (N), Ada.Strings.Both));

   --  Seconds text as a number (the edge's 'Value, on text the proven Is_Seconds_Text approved); -1 otherwise.
   function Seconds_Of (S : String) return Long_Long_Integer is
   begin
      if Tower_Payload_Pkg.Is_Seconds_Text (S) then
         return Long_Long_Integer'Value (S);
      end if;
      return -1;
   exception
      when others =>
         return -1;
   end Seconds_Of;

   --  The allowed_signers file BESIDE THE BINARY. "" when the binary's directory cannot be named: no file, no signer.
   function Signers_Path return String is
      Name : constant String := Ada.Command_Line.Command_Name;
   begin
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

   --  MEASURE one seal (lifted). Known = a key the trust file names made it; Valid = ssh-keygen -Y verify exits 0
   --  for that principal under the namespace Under, over Message AS A LINE.
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

   --  THE LEDGER, read in BOUNDED lines and handed to the proven fold (lifted): the running version comes from S.
   procedure Read_Ledger (S : out Tower_Ledger_Fold_Pkg.Fold_State) is
      File : Ada.Text_IO.File_Type;
      Buf  : String (1 .. Line_Bound);
      Last : Natural;
   begin
      S := Tower_Ledger_Fold_Pkg.Initial;
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
         S := Tower_Ledger_Fold_Pkg.Add (S, Strip (Buf (1 .. Last)));
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

   --  The LAST non-empty line of the row file, read in bounded lines; "" when there is none.
   function Last_Row return String is
      File : Ada.Text_IO.File_Type;
      Buf  : String (1 .. Line_Bound);
      Last : Natural;
      Keep : U.Unbounded_String;
   begin
      if not Ada.Directories.Exists (Row_Path) then
         return "";
      end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Row_Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Buf, Last);
         if Last = Buf'Last and then not Ada.Text_IO.End_Of_File (File) then
            Ada.Text_IO.Skip_Line (File);
         end if;
         if Strip (Buf (1 .. Last))'Length > 0 then
            Keep := U.To_Unbounded_String (Strip (Buf (1 .. Last)));
         end if;
      end loop;
      Ada.Text_IO.Close (File);
      return U.To_String (Keep);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Last_Row;

   --  One row and its line feed, in ONE write (lifted; a torn final line gets its line feed first).
   procedure Append_Row (Row : String) is
      F    : Ada.Streams.Stream_IO.File_Type;
      Torn : Boolean := False;
   begin
      if Ada.Directories.Exists (Row_Path) and then Ada.Directories.Size (Row_Path) > 0 then
         declare
            G    : Ada.Streams.Stream_IO.File_Type;
            Last : Character;
         begin
            Ada.Streams.Stream_IO.Open (G, Ada.Streams.Stream_IO.In_File, Row_Path);
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
      if not Ada.Directories.Exists (Ada.Directories.Containing_Directory (Row_Path)) then
         Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Row_Path));
      end if;
      if Ada.Directories.Exists (Row_Path) then
         Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.Append_File, Row_Path);
      else
         Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Row_Path);
      end if;
      String'Write (Ada.Streams.Stream_IO.Stream (F), (if Torn then (1 => ASCII.LF) else "") & Row & ASCII.LF);
      Ada.Streams.Stream_IO.Close (F);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (F) then
            Ada.Streams.Stream_IO.Close (F);
         end if;
   end Append_Row;

   --  The contents of a string value, "" when absent or not a string. Line one-based and at most 1 MiB.
   function Value_Text (Line : String; Key : String) return String is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, Key);
   begin
      if S.found and then S.kind = Json_Scan_Pkg.K_String then
         declare
            C : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, S);
         begin
            if C.first <= C.last then
               return One_Based (Line (C.first .. C.last));
            end if;
         end;
      end if;
      return "";
   end Value_Text;

   --  One line out on the reef rail, one line back, up to the first line feed (lifted, the bound a parameter).
   procedure Ask (Conf : String; Line : String; Max_Reply : Positive; Answer : out Text_Access; Ok : out Boolean) is
      Buf  : Text_Access := new String (1 .. Max_Reply);
      Len  : Natural;
      Reached, Timed_Out, Over_Bound, Complete : Boolean;
      Host : constant String :=
        Conf (Rail_Config_Pkg.Host_Span (Conf).first .. Rail_Config_Pkg.Host_Span (Conf).last);
   begin
      Answer := new String'("");
      Ok := False;
      Rail_Socket_Edge.Exchange
        (Host            => Host,
         Port            => Rail_Config_Pkg.Port_Of (Conf),
         Request         => Line & LF,
         Timeout_Seconds => Rail_Config_Pkg.Timeout_Of (Conf),
         Max_Reply       => Max_Reply,
         Until_Line_Feed => True,
         Reply           => Buf.all,
         Reply_Len       => Len,
         Reached         => Reached,
         Timed_Out       => Timed_Out,
         Over_Bound      => Over_Bound,
         Complete        => Complete);
      if Complete then
         Answer := new String'(Buf (1 .. Len));
         Ok := True;
      end if;
      Free (Buf);
   exception
      when others =>
         Answer := new String'("");
         Ok := False;
         Free (Buf);
   end Ask;

   --  The word, as text, for the proven decider's outcome.
   function Word_Of (O : Tower_Index_Pkg.Outcome_Kind) return String is
     (case O is
         when Tower_Index_Pkg.Out_Fetched          => "fetched",
         when Tower_Index_Pkg.Out_No_Reef_Rail     => "no_reef_rail",
         when Tower_Index_Pkg.Out_Rate_Limited     => "rate_limited",
         when Tower_Index_Pkg.Out_Reef_Unreachable => "reef_unreachable",
         when Tower_Index_Pkg.Out_Index_Unreadable => "index_unreadable",
         when Tower_Index_Pkg.Out_Index_Unverified => "index_unverified",
         when Tower_Index_Pkg.Out_Index_Stale      => "index_stale",
         when Tower_Index_Pkg.Out_Current          => "current",
         when Tower_Index_Pkg.Out_Fetch_Failed     => "fetch_failed");

   procedure Fetch (Word : out U.Unbounded_String) is
      Conf_Buf : String (1 .. Line_Bound);
      Conf_Len : Natural := 0;

      --  The facts, every one False until measured; the proven Outcome names the word.
      F : Tower_Index_Pkg.Fetch_Facts;

      --  What the row records.
      Index_Version  : U.Unbounded_String := U.To_Unbounded_String ("0");
      Candidate      : Tower_Admission_Pkg.Version_Number := 0;
      Running        : Tower_Admission_Pkg.Version_Number := 0;
      Name           : U.Unbounded_String;
      Digest         : U.Unbounded_String;
      Digest_Matches : Boolean := False;
      Bytes          : Natural := 0;
      Signers        : constant String := Signers_Path;

      procedure Finish (With_Row : Boolean) is
         The_Word : constant String := Word_Of (Tower_Index_Pkg.Outcome (F));
      begin
         if With_Row then
            Append_Row
              ('{' & '"' & "fetch" & '"' & ':' & '"' & The_Word & '"' & ','
               & '"' & "index_version" & '"' & ':' & '"' & U.To_String (Index_Version) & '"' & ','
               & '"' & "candidate" & '"' & ':' & '"' & Img (Candidate) & '"' & ','
               & '"' & "running" & '"' & ':' & '"' & Img (Running) & '"' & ','
               & '"' & "name" & '"' & ':' & '"' & U.To_String (Name) & '"' & ','
               & '"' & "digest" & '"' & ':' & '"' & U.To_String (Digest) & '"' & ','
               & '"' & "digest_matches" & '"' & ':' & '"' & (if Digest_Matches then "true" else "false") & '"' & ','
               & '"' & "bytes" & '"' & ':' & '"' & Img (Bytes) & '"' & ','
               & '"' & "at" & '"' & ':' & '"' & Now_Text & '"' & '}');
         end if;
         Word := U.To_Unbounded_String (The_Word);
      end Finish;

   begin
      Word := U.To_Unbounded_String ("no_reef_rail");

      --  1. The reef rail: ONLY from the file; the first VALID reef line (Rail_Config_Pkg judges validity).
      declare
         Fh : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (Fh, Ada.Text_IO.In_File, Conf_Path);
         while not F.have_rail and then not Ada.Text_IO.End_Of_File (Fh) loop
            declare
               L  : constant String := Ada.Text_IO.Get_Line (Fh);
               L1 : constant String (1 .. L'Length) := L;
            begin
               if L1'Length <= Line_Bound
                 and then Rail_Config_Pkg.Is_Valid (L1)
                 and then Rail_Config_Pkg.Rail_Of (L1) = Rail_Config_Pkg.Rail_Reef
               then
                  Conf_Buf (1 .. L1'Length) := L1;
                  Conf_Len := L1'Length;
                  F.have_rail := True;
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (Fh);
      exception
         when others =>
            F.have_rail := False;
            Conf_Len := 0;
      end;
      if not F.have_rail then
         Finish (With_Row => False);
         return;
      end if;

      --  2. The rate gate (proven May_Ask): the newest row's `at` against the clock. No row: may ask.
      declare
         Row     : constant String := Last_Row;
         Last_At : constant Long_Long_Integer :=
           (if Row'Length in 1 .. 1_048_576 then Seconds_Of (Value_Text (Row, "at")) else -1);
         Now     : constant Long_Long_Integer := Seconds_Of (Now_Text);
      begin
         if Last_At < 0 then
            F.may_ask := True;
         elsif Now >= 0 then
            F.may_ask := Tower_Index_Pkg.May_Ask
              (Tower_Index_Pkg.Seconds_Count (Now), Tower_Index_Pkg.Seconds_Count (Last_At));
         end if;
      end;
      if not F.may_ask then
         Finish (With_Row => False);
         return;
      end if;

      --  3. The running version, by the proven fold: the larger of the ledger's highest accepted and the base.
      declare
         S : Tower_Ledger_Fold_Pkg.Fold_State;
      begin
         Read_Ledger (S);
         Running := Tower_Ledger_Fold_Pkg.Running (S, Crucible_Tower.Base_Version);
      end;

      declare
         Conf   : constant String := Conf_Buf (1 .. Conf_Len);
         Answer : Text_Access;
         Ok     : Boolean;
      begin
         --  4. The index, through the relay. No usable line: reef_unreachable, and the forge continues.
         Ask (Conf, Index_Request, Rail_Config_Pkg.Max_Reply_Of (Conf), Answer, Ok);
         F.reached := Ok;
         if not F.reached then
            Finish (With_Row => True);
            return;
         end if;

         --  5. The reply's shape and the two lines are Tower_Index_Pkg's judgements; the edge only finds the
         --  first line feed and decodes the span the core approved.
         if not Tower_Index_Pkg.Reply_Is (Answer.all, Tower_Index_Pkg.Index_Reply_Head) then
            Finish (With_Row => True);   --  index_unreadable
            return;
         end if;
         declare
            Hex_First : constant Positive := Tower_Index_Pkg.Index_Reply_Head'Length + 1;
            Hex_Last  : constant Natural := Tower_Index_Pkg.Hex_Last (Answer.all, Tower_Index_Pkg.Index_Reply_Head);
            File      : constant String := Hex_Text_Pkg.Decode (Answer (Hex_First .. Hex_Last));
            P         : Natural := 0;
         begin
            Free (Answer);
            for I in File'Range loop
               if File (I) = LF then
                  P := I;
                  exit;
               end if;
            end loop;
            if P = 0 or else not Tower_Index_Pkg.Two_Lines_At (File, P) then
               Finish (With_Row => True);   --  index_unreadable
               return;
            end if;
            declare
               L1 : constant String := One_Based (File (1 .. P - 1));
               L2 : constant String := One_Based (File (P + 1 .. File'Length - 1));
            begin
               --  The envelope is the admitted Tower_Receipt_Pkg's one-seal line; line 1 the core's index shape.
               if not Tower_Receipt_Pkg.Is_Seal_Line (L2) or else not Tower_Index_Pkg.Index_Ok (L1) then
                  Finish (With_Row => True);   --  index_unreadable
                  return;
               end if;
               F.index_readable := True;
               declare
                  Seal_Hex : constant String :=
                    One_Based (L2 (Tower_Envelope_Pkg.Seal_First .. Tower_Receipt_Pkg.Seal_Last (L2)));
                  Known, Valid : Boolean;
                  Signer : U.Unbounded_String;
                  Now    : constant String := Now_Text;
               begin
                  --  6. The seal over line 1 AS A LINE, under df-index, against the trust file beside the binary.
                  --  Nothing is read from the index before this verifies -- not even expires.
                  Measure_Seal (L1, Seal_Hex, Signers, Index_Namespace, Known, Valid, Signer);
                  F.sealed := Known and then Valid;
                  if not F.sealed then
                     Finish (With_Row => True);   --  index_unverified
                     return;
                  end if;
                  Index_Version := U.To_Unbounded_String
                    (L1 (Tower_Payload_Pkg.Version_Span (L1).first .. Tower_Payload_Pkg.Version_Span (L1).last));
                  --  7. Freshness (proven Fresh): expires after the clock, else index_stale and the forge continues.
                  F.fresh := Tower_Payload_Pkg.Is_Seconds_Text (Now) and then Tower_Index_Pkg.Fresh (L1, Now);
                  if not F.fresh then
                     Finish (With_Row => True);
                     return;
                  end if;
               end;
               --  8. Walk EVERY entry of `current` (an array: one stream today, more than one source later), handing
               --  each to the proven fold: the pick is the highest version forward of running, whatever its name.
               declare
                  Cur  : constant Json_Scan_Pkg.Span_Type := Tower_Index_Pkg.Current_Span (L1);
                  I    : Positive := Cur.first + 1;
                  Pick : Tower_Index_Pkg.Pick_State;
                  Best_Entry : U.Unbounded_String;
               begin
                  while I <= L1'Last and then L1 (I) /= ']' loop
                     if L1 (I) = '{' then
                        declare
                           J : Positive := I;
                        begin
                           while J < L1'Last and then L1 (J) /= '}' loop
                              J := J + 1;
                           end loop;
                           if Tower_Index_Pkg.Object_At (L1, I, J) then
                              declare
                                 E : constant String := One_Based (L1 (I .. J));
                              begin
                                 if Tower_Index_Pkg.Entry_Ok (E) then
                                    declare
                                       V : constant Tower_Admission_Pkg.Version_Number :=
                                         Tower_Admission_Pkg.Version_Number'Value
                                           (E (Tower_Payload_Pkg.Version_Span (E).first
                                               .. Tower_Payload_Pkg.Version_Span (E).last));
                                    begin
                                       if Tower_Index_Pkg.Taken (Pick, V, Running) then
                                          Best_Entry := U.To_Unbounded_String (E);
                                       end if;
                                       Pick := Tower_Index_Pkg.Consider (Pick, V, Running);
                                    end;
                                 end if;
                              end;
                           end if;
                           I := J + 1;
                        end;
                     else
                        I := I + 1;
                     end if;
                  end loop;
                  F.newer := Pick.have;
                  if not F.newer then
                     Finish (With_Row => True);   --  current
                     return;
                  end if;
                  Candidate := Pick.best;
                  declare
                     E : constant String := U.To_String (Best_Entry);
                  begin
                     Name := U.To_Unbounded_String
                       (E (Tower_Index_Pkg.Name_Span (E).first + 1 .. Tower_Index_Pkg.Name_Span (E).last - 1));
                     --  9. Fetch that ONE file, by name, under the core's fetch bound (a hex-encoded 1 MiB fits).
                     declare
                        Reply : Text_Access;
                        F_Ok  : Boolean;
                     begin
                        Ask (Conf, Fetch_Head & U.To_String (Name) & Fetch_Tail,
                             Tower_Index_Pkg.Fetch_Max_Reply, Reply, F_Ok);
                        if not F_Ok or else not Tower_Index_Pkg.Reply_Is (Reply.all, Tower_Index_Pkg.Fetch_Reply_Head) then
                           Free (Reply);
                           Finish (With_Row => True);   --  fetch_failed
                           return;
                        end if;
                        declare
                           Data : constant Text_Access := new String'
                             (Hex_Text_Pkg.Decode
                                (Reply (Tower_Index_Pkg.Fetch_Reply_Head'Length + 1
                                        .. Tower_Index_Pkg.Hex_Last (Reply.all, Tower_Index_Pkg.Fetch_Reply_Head))));
                        begin
                           Free (Reply);
                           Bytes := Data'Length;
                           Digest := U.To_Unbounded_String (GNAT.SHA256.Digest (Data.all));
                           --  RECORDED against the index (proven Digest_Names), not judged: the import refuses on its own.
                           Digest_Matches := Tower_Stamp_Pkg.Is_Hex_Digest (U.To_String (Digest))
                             and then Tower_Index_Pkg.Digest_Names (U.To_String (Digest), E);
                           --  10. Into the place the shipped import reads from. Nothing else changes.
                           if not Ada.Directories.Exists (Ada.Directories.Containing_Directory (Bundle_Path)) then
                              Ada.Directories.Create_Path (Ada.Directories.Containing_Directory (Bundle_Path));
                           end if;
                           Write_Bytes (Bundle_Path, Data.all);
                           F.fetched := True;
                           Finish (With_Row => True);   --  fetched
                        end;
                     end;
                  end;
               end;
            end;
         end;
      end;
   exception
      when others =>
         --  A belt, never a verdict: whatever broke, the forge continues on what it has.
         Word := U.To_Unbounded_String ("fetch_failed");
   end Fetch;

end Tower_Fetch_Pkg;
