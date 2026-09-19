--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 016778b12989d72bb44b13e24effbef708a6a1094e3fc8340f4cda5733e35ce0
--
--  Palais_Enrol_Pkg body -- template (seat-written plumbing) with THREE slots (request-facts, reply-facts,
--  refusal-reason), filled by a Wu edge round. Same shape as the vacuity rail client edge
--  (wu-crucible-vacuity-rail-call): the plumbing reads, sends, measures and writes; the slots only RECORD FACTS; the
--  decision is Reef_Key_Claim_Pkg.Accept_Key's. Brief BRIEF_palais_enrol_edge_2026-09-19.
with Ada.Calendar;
with Ada.Calendar.Conversions;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;
with GNAT.Expect;
with GNAT.OS_Lib;
with GNAT.SHA256;
with Interfaces.C;
with Hex_Text_Pkg;
with Json_Scan_Pkg;
with Rail_Config_Pkg;
with Rail_Socket_Edge;
with Reef_Key_Claim_Pkg;

package body Palais_Enrol_Pkg with SPARK_Mode => Off is

   use type Json_Scan_Pkg.Kind_Type;
   use type Rail_Config_Pkg.Rail_Kind;
   use type Reef_Key_Claim_Pkg.Role_Kind;
   use type Interfaces.C.long;

   Max_Conf_Line : constant := 4096;
   Max_Line      : constant := 65_536;
   Q             : constant String := """";

   function Value_Text (Line : String; Key : String) return String is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, Key);
   begin
      if S.found and then S.kind = Json_Scan_Pkg.K_String and then S.first < S.last then
         declare
            C : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, S);
         begin
            if C.first <= C.last then
               return Line (C.first .. C.last);
            end if;
         end;
      end if;
      return "";
   end Value_Text;

   function Is_Present (Line : String; Key : String) return Boolean is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, Key);
   begin
      return S.found and then S.kind = Json_Scan_Pkg.K_String;
   end Is_Present;

   --  A number that does not read as a Natural is NEVER 0-and-valid: Valid stays False.
   procedure Read_Natural (Line : String; Key : String; Value : out Natural; Valid : out Boolean) is
   begin
      Value := 0;
      Valid := False;
      if Is_Present (Line, Key) then
         begin
            Value := Natural'Value (Value_Text (Line, Key));
            Valid := True;
         exception
            when Constraint_Error =>
               Value := 0;
               Valid := False;
         end;
      end if;
   end Read_Natural;

   --  A text of any other length becomes 64 'x' characters, which Is_Digest refuses: never a silent pad or cut.
   function To_Digest (S : String) return Reef_Key_Claim_Pkg.Digest_Text is
   begin
      if S'Length = 64 then
         return Reef_Key_Claim_Pkg.Digest_Text (S);
      end if;
      return (others => 'x');
   end To_Digest;

   --  Text the edge may place inside a JSON string it writes: printable, no quote, no backslash.
   function Is_Safe (S : String) return Boolean is
     (for all C of S => C in ' ' .. '~' and then C /= '"' and then C /= '\');

   function Is_Codename (S : String) return Boolean is
     (S'Length in 1 .. 32
      and then (for all C of S => C in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '-'));

   function Sha_Hex (S : String) return String is
      Ctx : GNAT.SHA256.Context := GNAT.SHA256.Initial_Context;
   begin
      GNAT.SHA256.Update (Ctx, S);
      return GNAT.SHA256.Digest (Ctx);
   end Sha_Hex;

   function Now_Seconds return Natural is
      T : constant Interfaces.C.long := Ada.Calendar.Conversions.To_Unix_Time (Ada.Calendar.Clock);
   begin
      if T < 0 then
         return 0;
      end if;
      return Natural (T);
   end Now_Seconds;

   function Random_Hex_32 return String is
      use Ada.Streams;
      F   : Stream_IO.File_Type;
      Buf : Stream_Element_Array (1 .. 32);
      Got : Stream_Element_Offset;
      S   : String (1 .. 32);
   begin
      Stream_IO.Open (F, Stream_IO.In_File, "/dev/urandom");
      Stream_IO.Read (F, Buf, Got);
      Stream_IO.Close (F);
      if Got /= 32 then
         raise Program_Error;
      end if;
      for I in S'Range loop
         S (I) := Character'Val (Natural (Buf (Stream_Element_Offset (I))));
      end loop;
      return Hex_Text_Pkg.Encode (S);
   end Random_Hex_32;

   --  The first line of a file, or "" (Ok False) when it cannot be read or is longer than Max_Line.
   procedure Read_First_Line (Path : String; Line : out Text_Access; Ok : out Boolean) is
      F : Ada.Text_IO.File_Type;
   begin
      Line := new String'("");
      Ok := False;
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      if not Ada.Text_IO.End_Of_File (F) then
         declare
            L : constant String := Ada.Text_IO.Get_Line (F);
         begin
            if L'Length <= Max_Line then
               Line := new String'(L);
               Ok := True;
            end if;
         end;
      end if;
      Ada.Text_IO.Close (F);
   exception
      when others =>
         Line := new String'("");
         Ok := False;
   end Read_First_Line;

   procedure Write_Line (Path : String; Text : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put_Line (F, Text);
      Ada.Text_IO.Close (F);
   end Write_Line;

   --  Exact bytes, no line terminator added (the signature file must be what the Reef signed with).
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

   function Refused (Word : String) return Text_Access is
     (new String'("{" & Q & "enrol" & Q & ":" & Q & "refused" & Q & "," & Q & "reason" & Q & ":" & Q & Word & Q & "}"));

   function Pending_Reply (Code : String; Url : String) return Text_Access is
     (new String'("{" & Q & "enrol" & Q & ":" & Q & "pending" & Q & "," & Q & "user_code" & Q & ":" & Q & Code & Q
                  & "," & Q & "url" & Q & ":" & Q & Url & Q & "}"));

   --  One line out on the reef rail, one line back (up to the first line feed). Ok False: not reached, timed out,
   --  over bound, or no complete line.
   procedure Ask (Conf : String; Line : String; Answer : out Text_Access; Ok : out Boolean) is
      Max_Reply : constant Positive := Rail_Config_Pkg.Max_Reply_Of (Conf);
      Buf       : constant Text_Access := new String (1 .. Max_Reply);
      Len       : Natural;
      Reached, Timed_Out, Over_Bound, Complete : Boolean;
      Host      : constant String :=
        Conf (Rail_Config_Pkg.Host_Span (Conf).first .. Rail_Config_Pkg.Host_Span (Conf).last);
      LF        : constant Character := Character'Val (10);
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
      --  With Until_Line_Feed, Complete means the line feed arrived; the socket edge stores the line WITHOUT it.
      if Complete and then Len <= Max_Line then
         Answer := new String'(Buf (1 .. Len));
         Ok := True;
      end if;
   exception
      when others =>
         Answer := new String'("");
         Ok := False;
   end Ask;

   procedure Step
     (Codename : String;
      Where    : Paths;
      Reply    : out Text_Access)
   is
      Key_Path     : constant String := Where.Key_Dir.all & "/id_ed25519";
      Pub_Path     : constant String := Key_Path & ".pub";
      Id_Path      : constant String := Where.Key_Dir.all & "/factory-id";
      Pending_Path : constant String := Where.State_Dir.all & "/reef-enrol-pending.json";
      Key_File     : constant String := Where.State_Dir.all & "/reef-key.json";
      Sig_Path     : constant String := Where.State_Dir.all & "/reef-sig.tmp";

      Conf_Buf : String (1 .. Max_Conf_Line);
      Conf_Len : Natural := 0;
      Found    : Boolean := False;   --  a valid rail line whose rail is "reef" was read
      Line     : Text_Access;
      Ok       : Boolean;
   begin
      --  Already enrolled: say so, touch nothing.
      Read_First_Line (Key_File, Line, Ok);
      if Ok then
         Reply := new String'("{" & Q & "enrol" & Q & ":" & Q & "already" & Q & "," & Q & "fingerprint" & Q & ":"
                              & Q & (if Is_Safe (Value_Text (Line.all, "fingerprint"))
                                     then Value_Text (Line.all, "fingerprint") else "") & Q & "}");
         return;
      end if;

      --  Configuration: ONLY from the file; the first VALID reef line (Rail_Config_Pkg judges validity).
      declare
         F : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Where.Conf_Path.all);
         while not Found and then not Ada.Text_IO.End_Of_File (F) loop
            declare
               L  : constant String := Ada.Text_IO.Get_Line (F);
               L1 : constant String (1 .. L'Length) := L;
            begin
               if L1'Length <= Max_Conf_Line
                 and then Rail_Config_Pkg.Is_Valid (L1)
                 and then Rail_Config_Pkg.Rail_Of (L1) = Rail_Config_Pkg.Rail_Reef
               then
                  Conf_Buf (1 .. L1'Length) := L1;
                  Conf_Len := L1'Length;
                  Found := True;
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (F);
      exception
         when others =>
            Found := False;
            Conf_Len := 0;
      end;
      if not Found then
         Reply := Refused ("no_reef_rail");
         return;
      end if;

      --  The pinned Reef key: the file must exist and have exactly the digest the caller pins.
      declare
         Signers : Text_Access;
         S_Ok    : Boolean;
      begin
         Read_First_Line (Where.Signers_Path.all, Signers, S_Ok);
         if not S_Ok or else Sha_Hex (Signers.all) /= Where.Signers_Digest.all then
            Reply := Refused ("no_reef_key_pinned");
            return;
         end if;
      end;

      --  This factory's own key pair and per-install id, made once. The private half never leaves Key_Dir.
      if not Ada.Directories.Exists (Where.Key_Dir.all) then
         Ada.Directories.Create_Path (Where.Key_Dir.all);
      end if;
      if not Ada.Directories.Exists (Pub_Path) then
         declare
            Args : GNAT.OS_Lib.Argument_List :=
              (new String'("-q"), new String'("-t"), new String'("ed25519"), new String'("-N"), new String'(""),
               new String'("-C"), new String'("crucible"), new String'("-f"), new String'(Key_Path));
            Spawned : Boolean;
         begin
            GNAT.OS_Lib.Spawn (Where.Ssh_Keygen.all, Args, Spawned);
            for A of Args loop
               GNAT.OS_Lib.Free (A);
            end loop;
            if not Spawned or else not Ada.Directories.Exists (Pub_Path) then
               Reply := Refused ("keygen_failed");
               return;
            end if;
         end;
      end if;
      if not Ada.Directories.Exists (Id_Path) then
         Write_Line (Id_Path, Random_Hex_32);
      end if;

      declare
         Conf        : constant String (1 .. Conf_Len) := Conf_Buf (1 .. Conf_Len);
         Pub         : Text_Access;
         Id          : Text_Access;
         Pub_Ok      : Boolean;
         Id_Ok       : Boolean;
         Pending     : Text_Access;
         Pending_Ok  : Boolean;
      begin
         Read_First_Line (Pub_Path, Pub, Pub_Ok);
         Read_First_Line (Id_Path, Id, Id_Ok);
         if not Pub_Ok or else not Id_Ok then
            Reply := Refused ("key_unreadable");
            return;
         end if;

         declare
            Fingerprint : constant String := Sha_Hex (Pub.all);
            Factory_Id  : constant String := Id.all;
         begin
            Read_First_Line (Pending_Path, Pending, Pending_Ok);

            if not Pending_Ok then
               ------------------------------------------------------------------------------------------------
               --  START: no enrolment in flight. Ask the Reef for a code a human will approve.
               ------------------------------------------------------------------------------------------------
               if not Is_Codename (Codename) then
                  Reply := Refused ("bad_codename");
                  return;
               end if;
               declare
                  Nonce  : constant String := Random_Hex_32;
                  Answer : Text_Access;
                  A_Ok   : Boolean;
                  Secs   : Natural;
                  S_Ok   : Boolean;
               begin
                  Ask (Conf,
                       "{" & Q & "op" & Q & ":" & Q & "enrol_start" & Q & "," & Q & "fingerprint" & Q & ":" & Q
                       & Fingerprint & Q & "," & Q & "factory_id" & Q & ":" & Q & Factory_Id & Q & "," & Q & "nonce"
                       & Q & ":" & Q & Nonce & Q & "," & Q & "codename" & Q & ":" & Q & Codename & Q & "}",
                       Answer, A_Ok);
                  if not A_Ok then
                     Reply := Refused ("reef_unreachable");
                     return;
                  end if;
                  if Is_Present (Answer.all, "refused") then
                     Reply := Refused ("reef_refused");
                     return;
                  end if;
                  Read_Natural (Answer.all, "expires_in", Secs, S_Ok);
                  if Value_Text (Answer.all, "op") /= "enrol_start"
                    or else Value_Text (Answer.all, "nonce") /= Nonce
                    or else not S_Ok
                    or else Value_Text (Answer.all, "user_code")'Length not in 1 .. 16
                    or else not Is_Safe (Value_Text (Answer.all, "user_code"))
                    or else Value_Text (Answer.all, "url")'Length not in 1 .. 256
                    or else not Is_Safe (Value_Text (Answer.all, "url"))
                  then
                     Reply := Refused ("malformed");
                     return;
                  end if;
                  Write_Line (Pending_Path,
                              "{" & Q & "nonce" & Q & ":" & Q & Nonce & Q & "," & Q & "user_code" & Q & ":" & Q
                              & Value_Text (Answer.all, "user_code") & Q & "," & Q & "url" & Q & ":" & Q
                              & Value_Text (Answer.all, "url") & Q & "," & Q & "expires_at" & Q & ":" & Q
                              & Natural'Image (Now_Seconds + Secs) (2 .. Natural'Image (Now_Seconds + Secs)'Last)
                              & Q & "," & Q & "codename" & Q & ":" & Q & Codename & Q & "}");
                  Reply := Pending_Reply (Value_Text (Answer.all, "user_code"), Value_Text (Answer.all, "url"));
                  return;
               end;
            end if;

            ------------------------------------------------------------------------------------------------------
            --  POLL: an enrolment is in flight. Ask ONCE; never wait here.
            ------------------------------------------------------------------------------------------------------
            declare
               Nonce      : constant String := Value_Text (Pending.all, "nonce");
               Code       : constant String := Value_Text (Pending.all, "user_code");
               Url        : constant String := Value_Text (Pending.all, "url");
               Until_T    : Natural;
               Until_Ok   : Boolean;
               Answer     : Text_Access;
               A_Ok       : Boolean;
            begin
               Read_Natural (Pending.all, "expires_at", Until_T, Until_Ok);
               if not Until_Ok or else Now_Seconds >= Until_T then
                  Remove (Pending_Path);
                  Reply := Refused ("code_expired");
                  return;
               end if;
               Ask (Conf,
                    "{" & Q & "op" & Q & ":" & Q & "enrol_poll" & Q & "," & Q & "nonce" & Q & ":" & Q & Nonce & Q & "}",
                    Answer, A_Ok);
               if not A_Ok then
                  Reply := Refused ("reef_unreachable");
                  return;
               end if;
               if Value_Text (Answer.all, "op") /= "enrol_poll" or else Value_Text (Answer.all, "nonce") /= Nonce then
                  Reply := Refused ("malformed");
                  return;
               end if;
               if Value_Text (Answer.all, "state") = "pending" then
                  Reply := Pending_Reply (Code, Url);
                  return;
               end if;
               if Value_Text (Answer.all, "state") /= "granted" then
                  Remove (Pending_Path);
                  Reply := Refused ("reef_refused");
                  return;
               end if;

               --  GRANTED: measure the record, then ask the decider.
               declare
                  Rec_Hex : constant String := Value_Text (Answer.all, "record");
                  Sig_Hex : constant String := Value_Text (Answer.all, "signature");
               begin
                  if not Hex_Text_Pkg.Is_Hex_Text (Rec_Hex) or else not Hex_Text_Pkg.Is_Hex_Text (Sig_Hex)
                    or else Rec_Hex'Length = 0 or else Sig_Hex'Length = 0
                  then
                     Reply := Refused ("malformed");
                     return;
                  end if;
                  declare
                     Rec          : constant String := Hex_Text_Pkg.Decode (Rec_Hex);
                     Verify_Code  : aliased Integer := 1;
                     Signed_Ok    : Boolean := False;
                     Revoked_Word : Text_Access := new String'("");
                     K            : Reef_Key_Claim_Pkg.Key_Record;
                     Req          : Reef_Key_Claim_Pkg.Request;
                     Record_Ok    : Boolean := False;
                     Issued_Ok    : Boolean := False;
                     Expires_Ok   : Boolean := False;
                     Reason       : Text_Access := new String'("refused");
                     Now          : constant Natural := Now_Seconds;
                  begin
                     --  Signature: ssh-keygen -Y verify against the PINNED signers, the record on stdin.
                     --  The Reef signs the record AS A LINE (record, then one line feed). Get_Command_Output's Send
                     --  appends exactly that one line feed (Add_LF defaults True), so Rec is passed without it.
                     Write_Bytes (Sig_Path, Hex_Text_Pkg.Decode (Sig_Hex));
                     declare
                        Args : GNAT.OS_Lib.Argument_List :=
                          (new String'("-Y"), new String'("verify"), new String'("-f"),
                           new String'(Where.Signers_Path.all), new String'("-I"), new String'("reef"),
                           new String'("-n"), new String'("df-reef-key"), new String'("-s"), new String'(Sig_Path));
                        Out_Text : constant String :=
                          GNAT.Expect.Get_Command_Output
                            (Where.Ssh_Keygen.all, Args, Rec, Verify_Code'Access, Err_To_Out => True);
                        pragma Unreferenced (Out_Text);
                     begin
                        for A of Args loop
                           GNAT.OS_Lib.Free (A);
                        end loop;
                     end;
                     Remove (Sig_Path);
                     Signed_Ok := Verify_Code = 0;

                     --  Revocation: one more line. An unreadable answer is recorded as it is ("").
                     declare
                        R_Answer : Text_Access;
                        R_Ok     : Boolean;
                     begin
                        Ask (Conf,
                             "{" & Q & "op" & Q & ":" & Q & "revoked" & Q & "," & Q & "fingerprint" & Q & ":" & Q
                             & Fingerprint & Q & "}",
                             R_Answer, R_Ok);
                        if R_Ok then
                           Revoked_Word := new String'(Value_Text (R_Answer.all, "revoked"));
                        end if;
                     end;

                     --  SLOT BEGIN (request-facts)
Req.Factory_Id := To_Digest (Factory_Id);
Req.Nonce := To_Digest (Nonce);
Req.Now := Now;
                     --  SLOT END (request-facts)

                     --  SLOT BEGIN (reply-facts)
K.Key_Fingerprint := To_Digest (Value_Text (Rec, "fingerprint"));
K.Factory_Id := To_Digest (Value_Text (Rec, "factory_id"));
K.Nonce_Echo := To_Digest (Value_Text (Rec, "nonce_echo"));
if Value_Text (Rec, "role") = "solver" then
   K.Role := Reef_Key_Claim_Pkg.Role_Solver;
else
   K.Role := Reef_Key_Claim_Pkg.Role_Sender;
end if;
Read_Natural (Rec, "issued_at", K.Issued_At, Issued_Ok);
Read_Natural (Rec, "expires_at", K.Expires_At, Expires_Ok);
K.CLA_Signed := Value_Text (Rec, "cla_signed") = "true";
K.Reef_Signed := Signed_Ok;
K.Revoked := Revoked_Word.all /= "false";
Record_Ok := Issued_Ok and then Expires_Ok;
                     --  SLOT END (reply-facts)

                     if not Record_Ok then
                        Remove (Pending_Path);
                        Reply := Refused ("malformed");
                        return;
                     end if;

                     if Reef_Key_Claim_Pkg.Accept_Key (K, Req) then
                        Write_Line (Key_File,
                                    "{" & Q & "fingerprint" & Q & ":" & Q & Fingerprint & Q & "," & Q & "record" & Q
                                    & ":" & Q & Rec_Hex & Q & "," & Q & "signature" & Q & ":" & Q & Sig_Hex & Q & "}");
                        Remove (Pending_Path);
                        Reply := new String'("{" & Q & "enrol" & Q & ":" & Q & "accepted" & Q & "," & Q & "codename"
                                             & Q & ":" & Q & (if Is_Codename (Value_Text (Rec, "codename"))
                                                              then Value_Text (Rec, "codename") else "") & Q
                                             & "," & Q & "role" & Q & ":" & Q
                                             & (if K.Role = Reef_Key_Claim_Pkg.Role_Solver then "solver" else "sender")
                                             & Q & "," & Q & "expires_at" & Q & ":" & Q
                                             & Natural'Image (K.Expires_At) (2 .. Natural'Image (K.Expires_At)'Last)
                                             & Q & "}");
                        return;
                     end if;

                     --  SLOT BEGIN (refusal-reason)
if not (Reef_Key_Claim_Pkg.Is_Digest (K.Key_Fingerprint) and then Reef_Key_Claim_Pkg.Is_Digest (K.Factory_Id) and then Reef_Key_Claim_Pkg.Is_Digest (K.Nonce_Echo) and then Reef_Key_Claim_Pkg.Is_Digest (Req.Factory_Id) and then Reef_Key_Claim_Pkg.Is_Digest (Req.Nonce)) then
   Reason := new String'("not_hex");
elsif not K.Reef_Signed then
   Reason := new String'("unsigned");
elsif K.Revoked then
   Reason := new String'("revoked");
elsif K.Factory_Id /= Req.Factory_Id then
   Reason := new String'("another_factory");
elsif K.Nonce_Echo /= Req.Nonce then
   Reason := new String'("replay");
elsif K.Issued_At > Req.Now then
   Reason := new String'("not_yet_valid");
elsif Req.Now >= K.Expires_At then
   Reason := new String'("expired");
elsif K.Role = Reef_Key_Claim_Pkg.Role_Solver and then not K.CLA_Signed then
   Reason := new String'("solver_without_cla");
else
   Reason := new String'("refused");
end if;
                     --  SLOT END (refusal-reason)

                     Remove (Pending_Path);
                     Reply := Refused (Reason.all);
                     return;
                  end;
               end;
            end;
         end;
      end;
   exception
      when others =>
         --  Anything unexpected is never an acceptance: nothing is written by this path.
         Reply := Refused ("edge_fault");
   end Step;

end Palais_Enrol_Pkg;
