--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: c120dfd7b42541b65fd71d65b0524037aae9b176f6a2080eeba9855a185fb563
--
--  Crucible_Main v7 -- the door's edge: a read loop, one declare block, one call into the frame
--  decider, one case over the action calling the proved cores. It holds no decision.
--  v5 (CRUCIBLE v0.2.0 step 4a) adds the intake_check tool: the sheet argument is decoded by the proven
--  Json_String_Pkg, split on line feeds into Intake_Measure_Pkg.Sheet (bounded; a sheet that does not fit is
--  refused, never measured on a prefix), measured by Intake_Measure_Pkg.Measure and judged by
--  Intake_Refusal_Pkg.Assemble. The tool result text is the same one line harness/intake_main prints.
--  Template (seat-written plumbing, v4 unchanged around it) with ONE slot (gaps), filled by a Wu edge round;
--  brief BRIEF_crucible_step4_wiring_2026-09-17.
--  v6 (step 4b) adds the prove_unit tool: unit, spec, body and level are read from the call, spec and body decoded
--  by Json_String_Pkg, and Prover_Rail_Call_Pkg.Prove gathers the rail facts; the outcome is decided by the
--  proven Prover_Rail_Pkg.Decide. Second slot (outcome_word) turns that outcome into its word.
--  v7 (step 4c) adds the forge tool: the sheet is decoded as for intake_check and carried through Pipeline_Run_Pkg, whose
--  every step is decided by proven cores (Pipeline_Stage_Pkg, Job_Record_Pkg, Stage_Outcome_Map_Pkg); the reply is its report.
--  v9 (release plan T1; Tony's ruling 1 of 2026-09-19, "base missing or tampered => the door STOPS") makes the forge tool
--  USE the pin: before the sheet is even looked for, on EVERY forge call, Tower_Base_Check_Edge.Check measures
--  tower/base.bundle against the compiled-in Crucible_Tower.Base_Digest and the admitted Tower_Base_Verdict_Pkg decides.
--  A refusal is reported as stopped_at "tower" (Tony's ruling of 2026-09-20 15:16) with the decider's own reason word.
--  intake_check, prove_unit, licence_gate and the palais tools do not call it and behave exactly as in v8.
--  Seat-written plumbing, no new slot; brief BRIEF_door_base_check_wiring_2026-09-20.
--  v10 (release plan T3, piece 4 wired) makes the forge tool IMPORT the sharer bundle: once per forge call, AFTER the
--  base check has let the door through and BEFORE the sheet is looked for, Tower_Import_Pkg.Import measures
--  tower/sharer.bundle, the proven Tower_Admission_Pkg decides, the proven Tower_Ledger_Fold_Pkg folds the ledger, and
--  the word is recorded in state/tower.jsonl. THE IMPORT NEVER BLOCKS THE FORGE (the design ruling this lineage
--  carries): whatever the word -- absent, unchanged, accepted, declined_by_policy, refused_receipt, refused_integrity,
--  unrecorded -- the forge proceeds on the ledger as it stands; only the base check stops it. The word surfaces as ONE
--  line on standard error (the MCP stdio server's logging channel), never in the reply. Seat-written plumbing, no new
--  slot; brief BRIEF_door_import_wiring_2026-09-21.
--  v17 (lineage 17, 2026-09-28; security fix CWE-444, request smuggling): a line longer than the 1 MiB buffer was read
--  by Get_Line in pieces, and the tail of an over-long line became the next frame (a request hidden behind 1 MiB of
--  padding was executed). Read_Frame (the ONE new slot) drains an over-long line through its terminator and says so;
--  the loop then answers it with ONE error reply -- the frame decider's own parse-failure code (-32700), id null,
--  message "frame_too_long" -- and goes on to the next line. A line of exactly Max_Line_Bytes is a normal frame: GNAT
--  leaves its terminator unread when the buffer fills, and Read_Frame skips it, so it no longer yields an empty frame.
--  v18 (lineage 18, 2026-09-28; Tony 16:17 "fix the refusal messages before v0.3", release test A11): three refusals
--  now say what is wrong; every JSON-RPC code is unchanged. (1) prove_unit with a unit name the prover rail would
--  refuse (Frame_Facts_Pkg.Unit_Name_Valid) is answered input_refused / unit_name_invalid and never sent. (2) a
--  tools/call carrying a duplicated key the named tool reads (Frame_Facts_Pkg.Duplicate_Key, over Json_Scan_Pkg
--  lineage 6) is refused -32602 "duplicate_key" -- it was answered as if the key were absent. (3) a -32700 whose line
--  opens an object or array that never closes (Frame_Facts_Pkg.Brackets_Unclosed) names that class. Three slots.
with Ada.Unchecked_Deallocation;
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Json_Scan_Pkg;
with Json_String_Pkg;
with Frame_Facts_Pkg;
with Json_Rpc_Frame_Pkg;
with Edition_Licence_Pkg;
with Crucible_Edition;
with Tool_Run_Pkg;
with Reply_Text_Pkg;
with Intake_Line_Pkg;
with Intake_Names_Pkg;
with Intake_Measure_Pkg;
with Intake_Refusal_Pkg;
with Prover_Rail_Pkg;
with Prover_Rail_Call_Pkg;
with Pipeline_Stage_Pkg;
with Pipeline_Run_Pkg;
with Ada.Characters.Handling;
with Ada.Environment_Variables;
with Ada.Command_Line;
with Ada.Directories;
with Palais_Enrol_Pkg;
with Tower_Base_Verdict_Pkg;
with Tower_Base_Check_Edge;
with Tower_Import_Pkg;
with Rail_Config_Pkg;
with Model_Rail_Fields_Pkg;
with Model_Tier_Select_Pkg;
with Sovereign_Gate_Pkg;
with Rail_Verb_Pkg;
with Report_Mode_Pkg;
with Ada.Strings.Fixed;
with GNAT.OS_Lib;

procedure Crucible_Main is
   Null_Id       : constant String := "null";
   Server_Agpl   : constant String := "crucible-agpl";
   Server_Comm   : constant String := "crucible-commercial";
   Bad_Tool_Msg  : constant String := "unknown tool";
   Frame_Msg     : constant String := "request refused by the frame decider";
   Server_Name   : constant String :=
     (if Crucible_Edition.Is_Agpl then Server_Agpl else Server_Comm);
   Max_Line_Bytes : constant := 1_048_576;  --  one limit across the factory (Tony 2026-09-17: 1 MiB door)
   type Buffer_Access is access String;
   Buffer        : constant Buffer_Access := new String (1 .. Max_Line_Bytes);
   Last          : Natural;
   Too_Long      : Boolean := False;
   Too_Long_Msg  : constant String := "frame_too_long";
   Duplicate_Msg : constant String := "duplicate_key";
   Brackets_Msg  : constant String := "parse error: unbalanced or mismatched brackets, or an unclosed string";

   use type Json_Rpc_Frame_Pkg.Reply_Type;
   use type Json_Rpc_Frame_Pkg.Action_Type;
   use type Frame_Facts_Pkg.Tool_Type;
   use type Json_Scan_Pkg.Kind_Type;

   type Sheet_Access is access Intake_Measure_Pkg.Sheet;
   type Origin_Array is array (Intake_Measure_Pkg.Line_Index) of Positive;
   type Origin_Access is access Origin_Array;

   S      : constant Sheet_Access := new Intake_Measure_Pkg.Sheet;
   Origin : constant Origin_Access := new Origin_Array'(others => 1);

   --  One frame from standard input into Buffer (1 .. Last). A line longer than the buffer is drained through its
   --  terminator and reported as Too_Long, so its tail never becomes a frame. A line of exactly Max_Line_Bytes is a
   --  normal frame: Get_Line leaves its terminator unread when the buffer fills, so it is skipped here.
   procedure Read_Frame (Too_Long : out Boolean) is
   begin
      Too_Long := False;
      Ada.Text_IO.Get_Line (Buffer.all, Last);
      if Last = Buffer'Last then
         if not Ada.Text_IO.End_Of_Line then
            Too_Long := True;
            Ada.Text_IO.Skip_Line;
         elsif not Ada.Text_IO.End_Of_File then
            Ada.Text_IO.Skip_Line;
         end if;
      end if;
   end Read_Frame;

   --  A Natural as decimal digits with no leading space.
   function Img (N : Natural) return String is
      T : constant String := Natural'Image (N);
   begin
      return T (T'First + 1 .. T'Last);
   end Img;

   --  The intake_check tool: the one-line verdict text for the sheet argument of Line.
   function Intake_Check_Text (Line : String) return String is
      use Ada.Strings.Unbounded;
      Reply  : Unbounded_String;
      First  : Boolean := True;

      procedure Append (Text : String) is
      begin
         Append (Reply, Text);
      end Append;

      procedure Add_Gap (Word : String) is
      begin
         if not First then
            Append (",");
         end if;
         Append ("""" & Word & """");
         First := False;
      end Add_Gap;

      Span     : constant Json_Scan_Pkg.Span_Type := Frame_Facts_Pkg.Sheet_Span (Line);
      Raw_Span : Json_Scan_Pkg.Span_Type;
      Count    : Intake_Measure_Pkg.Line_Count := 0;
      File_Line : Natural := 0;
   begin
      S.Count := 0;
      for I in Intake_Measure_Pkg.Line_Index loop
         S.Lines (I).Len := 0;
      end loop;

      --  An absent or non-string sheet, or an empty one, is measured as an empty sheet.
      if Span.found and then Span.kind = Json_Scan_Pkg.K_String and then Span.first < Span.last then
         Raw_Span := Json_Scan_Pkg.String_Contents (Line, Span);
         if Raw_Span.first <= Raw_Span.last then
            declare
               Raw     : constant String (1 .. Raw_Span.last - Raw_Span.first + 1) :=
                 Line (Raw_Span.first .. Raw_Span.last);
               Decoded : String (1 .. Raw'Length);
               Dec_Len : Natural;
               Ok      : Boolean;
               Start   : Positive := 1;
            begin
               Json_String_Pkg.Decode (Raw, Decoded, Dec_Len, Ok);
               if not Ok then
                  return "{""verdict"":""input_refused"",""reason"":""bad_string""}";
               end if;
               --  Split the decoded text on line feeds, exactly as harness/intake_main reads lines.
               for P in 1 .. Dec_Len + 1 loop
                  if P = Dec_Len + 1 or else Decoded (P) = Json_String_Pkg.LF then
                     if P > Start or else P <= Dec_Len then
                        File_Line := File_Line + 1;
                        declare
                           Text  : constant String := Decoded (Start .. P - 1);
                           Blank : Boolean := True;
                        begin
                           if Text'Length > Intake_Line_Pkg.Max_Line then
                              return "{""verdict"":""input_refused"",""reason"":""line_too_long"",""line"":""" &
                                Img (File_Line) & """}";
                           end if;
                           for C of Text loop
                              if not Intake_Line_Pkg.Is_Space (C) then
                                 Blank := False;
                              end if;
                           end loop;
                           if not Blank then
                              if Count = Intake_Measure_Pkg.Max_Lines then
                                 return "{""verdict"":""input_refused"",""reason"":""too_many_lines"",""limit"":""" &
                                   Img (Intake_Measure_Pkg.Max_Lines) & """}";
                              end if;
                              Count := Count + 1;
                              S.Lines (Count).Text (1 .. Text'Length) := Text;
                              S.Lines (Count).Len := Text'Length;
                              Origin (Count) := File_Line;
                           end if;
                        end;
                     end if;
                     Start := P + 1;
                  end if;
               end loop;
            end;
         end if;
      end if;
      S.Count := Count;

      declare
         Facts : constant Intake_Refusal_Pkg.Facts_Type := Intake_Measure_Pkg.Measure (S.all);
         V     : constant Intake_Refusal_Pkg.Verdict_Type := Intake_Refusal_Pkg.Assemble (Facts);
      begin
         if V.may_forge then
            return "{""verdict"":""may_forge"",""operation_count"":""" & Img (V.operation_count) & """}";
         end if;

         Append ("{""verdict"":""refused"",""gaps"":[");
         if V.gap_no_deliverable then Add_Gap ("no_deliverable"); end if;
         if V.gap_no_operations then Add_Gap ("no_operations"); end if;
         if V.gap_operations_not_functions then Add_Gap ("operations_not_functions"); end if;
         if V.gap_contracts_incomplete then Add_Gap ("contracts_incomplete"); end if;
         if V.gap_vocabulary_unsound then Add_Gap ("vocabulary_unsound"); end if;
         Append ("],""operation_count"":""" & Img (V.operation_count) & """");
         Append (",""undefined_name_count"":""" & Img (V.undefined_name_count) & """");

         if V.undefined_name_count > 0 then
            declare
               Place : constant Intake_Measure_Pkg.Name_Place := Intake_Measure_Pkg.First_Undefined (S.all);
            begin
               if Place.Line /= 0 then
                  declare
                     Text   : constant String := Intake_Measure_Pkg.Text_Of (S.all, Place.Line);
                     Last_P : constant Positive := Intake_Names_Pkg.Used_Name_End (Text, Place.Pos);
                  begin
                     Append (",""first_undefined"":{""line"":""" & Img (Origin (Place.Line)) &
                             """,""name"":""" & Text (Place.Pos .. Last_P) & """}");
                  end;
               end if;
            end;
         end if;

         Append ("}");
         return To_String (Reply);
      end;
   exception
      when others =>
         return "{""verdict"":""input_refused"",""reason"":""unreadable""}";
   end Intake_Check_Text;

   --  The prove_unit tool: the one-line outcome text for the unit, spec, body and level arguments of Line.
   function Prove_Unit_Text (Line : String) return String is
      type Text_Access is access String;

      --  A string argument's raw contents, or "" when absent, not a string, or empty.
      function Raw_Of (S : Json_Scan_Pkg.Span_Type) return String is
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
      end Raw_Of;

      Unit_Raw  : constant String := Raw_Of (Frame_Facts_Pkg.Unit_Span (Line));
      Spec_Raw  : constant String := Raw_Of (Frame_Facts_Pkg.Spec_Span (Line));
      Body_Raw  : constant String := Raw_Of (Frame_Facts_Pkg.Body_Span (Line));
      Level_Raw : constant String := Raw_Of (Frame_Facts_Pkg.Level_Span (Line));
      Spec_R    : constant String (1 .. Spec_Raw'Length) := Spec_Raw;
      Body_R    : constant String (1 .. Body_Raw'Length) := Body_Raw;
      Spec_Buf  : constant Text_Access := new String (1 .. Natural'Max (1, Spec_R'Length));
      Body_Buf  : constant Text_Access := new String (1 .. Natural'Max (1, Body_R'Length));
      Spec_Len, Body_Len : Natural;
      Spec_Ok, Body_Ok   : Boolean;
      Level     : Natural := 0;
      O         : Prover_Rail_Pkg.Outcome_Kind;
   begin
      Json_String_Pkg.Decode (Spec_R, Spec_Buf.all, Spec_Len, Spec_Ok);
      Json_String_Pkg.Decode (Body_R, Body_Buf.all, Body_Len, Body_Ok);
      if not (Spec_Ok and then Body_Ok) then
         return "{""outcome"":""input_refused"",""reason"":""bad_string""}";
      end if;
      begin
         Level := Natural'Value (Level_Raw);
      exception
         when Constraint_Error =>
            Level := 0;   --  an unreadable level is 0, which the proven May_Send refuses
      end;
      --  SLOT BEGIN (unit-name)
      --  A unit name the prover rail would refuse is refused here, by name, and never sent.
      if not Frame_Facts_Pkg.Unit_Name_Valid (Line) then
         return "{""outcome"":""input_refused"",""reason"":""unit_name_invalid""}";
      end if;
      --  SLOT END (unit-name)
      O := Prover_Rail_Call_Pkg.Prove (Unit_Raw, Spec_Buf (1 .. Spec_Len), Body_Buf (1 .. Body_Len), Level);
      declare
         Word : constant String := (
            case O is
     when Prover_Rail_Pkg.Outcome_Not_Sent => "not_sent",
     when Prover_Rail_Pkg.Outcome_Prover_Unreachable => "prover_unreachable",
     when Prover_Rail_Pkg.Outcome_Unmeasured => "unmeasured",
     when Prover_Rail_Pkg.Outcome_Reply_Refused => "reply_refused",
     when Prover_Rail_Pkg.Outcome_Not_Proved => "not_proved",
     when Prover_Rail_Pkg.Outcome_Proved => "proved"
         );
      begin
         return "{""outcome"":""" & Word & """}";
      end;
   exception
      when others =>
         return "{""outcome"":""input_refused"",""reason"":""unreadable""}";
   end Prove_Unit_Text;

   --  The forge tool: the one-line pipeline report for the sheet argument of Line.
   --  palais.enrol: one step of enrolment with the Reef (DESIGN_palais_enrol_2026-09-19). The edge decides nothing;
   --  Reef_Key_Claim_Pkg does. The pinned Reef signers digest is 64 zeros until the Reef has a signing key, so every
   --  enrolment is honestly refused no_reef_key_pinned until then.
   Pinned_Reef_Signers : constant String := (1 .. 64 => '0');

   --  ★ RAIL.SHOW (lineage 12, v0.3 Phase 7). Read-only: which models this factory is pointed at. The door
   --  reads config/rail.conf (the self-root has already put it in its install root) and, for every line
   --  that says it is the model rail, reports what the PROVEN judges say about it -- valid or not
   --  (Rail_Config_Pkg + Model_Rail_Fields_Pkg), its tier (Tier_Of), its model, protocol and host, and
   --  its route (Sovereign_Gate_Pkg.Route_Of) -- plus the whole file's verdict from the admitted
   --  Model_Tier_Select_Pkg fold, the same fold the model rail obeys. It decides nothing itself and
   --  changes nothing. Every value it copies is a character class the judges already confine (model
   --  names, dotted IPv4 hosts), so no escaping is needed; an unreadable file says so.
   function Rail_Show_Text return String is
      use Ada.Strings.Unbounded;
      use type Rail_Config_Pkg.Rail_Kind;
      use type Model_Tier_Select_Pkg.Select_Verdict;
      use type Model_Rail_Fields_Pkg.Protocol_Kind;
      Max_Rows : constant := 6;   --  6 x ~220 chars, doubled by Tool_Call_Result, stays inside Result_Reply's 4096
      Tally    : Model_Tier_Select_Pkg.Tier_Tally := Model_Tier_Select_Pkg.Empty;
      Rows     : Unbounded_String;
      Count    : Natural := 0;
      More     : Boolean := False;
      Err      : Boolean := False;
      F        : Ada.Text_IO.File_Type;
      function Lo (S : String) return String renames Ada.Characters.Handling.To_Lower;
      function Word (V : Model_Tier_Select_Pkg.Select_Verdict) return String is
        (case V is
            when Model_Tier_Select_Pkg.Select_Ok          => "select_ok",
            when Model_Tier_Select_Pkg.Invalid_Model_Line => "invalid_model_line",
            when Model_Tier_Select_Pkg.Unknown_Tier       => "unknown_tier",
            when Model_Tier_Select_Pkg.Duplicate_Tier     => "duplicate_tier",
            when Model_Tier_Select_Pkg.No_Standard_Line   => "no_standard_line");
      function Tier_Word (K : Model_Rail_Fields_Pkg.Tier_Kind) return String is
        (case K is
            when Model_Rail_Fields_Pkg.Tier_Standard => "standard",
            when Model_Rail_Fields_Pkg.Tier_Elevated => "elevated",
            when Model_Rail_Fields_Pkg.Tier_Unknown  => "unknown");
      procedure Add_Row (Row : String) is
      begin
         if Count < Max_Rows then
            Rows := Rows & (if Count > 0 then "," else "") & Row;
            Count := Count + 1;
         else
            More := True;
         end if;
      end Add_Row;
   begin
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "config/rail.conf");
         while not Ada.Text_IO.End_Of_File (F) loop
            declare
               L  : constant String := Ada.Text_IO.Get_Line (F);
               L1 : constant String (1 .. L'Length) := L;
            begin
               if L1'Length > 4096 then
                  raise Ada.Text_IO.Data_Error;
               elsif Rail_Config_Pkg.Rail_Of (L1) /= Rail_Config_Pkg.Rail_Model then
                  null;
               elsif Rail_Config_Pkg.Is_Valid (L1) and then Model_Rail_Fields_Pkg.Is_Valid_Model_Line (L1) then
                  Tally := Model_Tier_Select_Pkg.Add (Tally, Model_Rail_Fields_Pkg.Tier_Of (L1));
                  declare
                     M  : constant Json_Scan_Pkg.Span_Type := Model_Rail_Fields_Pkg.Model_Span (L1);
                     H  : constant Json_Scan_Pkg.Span_Type := Rail_Config_Pkg.Host_Span (L1);
                     Hs : constant String := L1 (H.first .. H.last);
                     Ep : constant String := "http://" & Hs;
                     E1 : constant String (1 .. Ep'Length) := Ep;
                     Rt : constant String :=
                       (if E1'Length <= Sovereign_Gate_Pkg.Max_Endpoint
                        then Lo (Sovereign_Gate_Pkg.Route_Kind'Image
                                   (Sovereign_Gate_Pkg.Route_Of (E1, Rail_Config_Pkg.Sovereign_Of (L1))))
                        else "unmeasured");
                  begin
                     Add_Row ("{""tier"":""" & Tier_Word (Model_Rail_Fields_Pkg.Tier_Of (L1)) &
                              """,""model"":""" & L1 (M.first .. M.last) &
                              """,""protocol"":""" &
                              (if Model_Rail_Fields_Pkg.Protocol_Of (L1) = Model_Rail_Fields_Pkg.Protocol_Openai
                               then "openai" else "ollama") &
                              """,""host"":""" & Hs & """,""route"":""" & Rt & """}");
                  end;
               else
                  Tally := Model_Tier_Select_Pkg.Add_Invalid (Tally);
                  Add_Row ("{""tier"":""invalid"",""why"":""a model rail line the proven judges refuse""}");
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (F);
      exception
         when others =>
            Err := True;
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
      end;
      if Err then
         return "{""verdict"":""conf_unreadable"",""path"":""config/rail.conf""}";
      end if;
      return "{""verdict"":""" & Word (Model_Tier_Select_Pkg.Verdict (Tally)) &
             """,""models"":[" & To_String (Rows) & "]" &
             (if More then ",""more"":""true""" else "") & "}";
   end Rail_Show_Text;

   --  ★ RAIL.SET (lineage 13, v0.3 Phase 7; Tony 2026-09-25: "go with that boundary"). An operator may reassign
   --  WHICH model line rail.conf ALREADY declares serves a tier -- nothing else. The admitted Rail_Verb_Pkg.Decide
   --  makes every decision from facts this door measures with proven judges; the door acts ONLY on Set_Swap (swap
   --  the two declared model lines' tier values) or Set_Unchanged (write nothing). Arguments naming any other
   --  rail.conf key -- rail, host, port, sovereign, protocol, timeout_seconds, max_reply_bytes, max_tokens -- are
   --  refused_estate_boundary before anything else is looked at; an argument given twice counts as not given; a
   --  model name must match exactly one declared line. A swap is written to a temp file, re-judged by the proven
   --  cores (select_ok, and every model line's model, host, port, protocol and sovereignty byte-identical), the
   --  live file must still be exactly what was read, the previous file is kept as config/rail.conf.pre-set, and
   --  only then does the temp file replace it. Any failed check refuses and leaves rail.conf untouched.
   function Rail_Set_Text (Line : String) return String is
      use Ada.Strings.Unbounded;
      use type Rail_Config_Pkg.Rail_Kind;
      use type Model_Tier_Select_Pkg.Select_Verdict;
      use type Model_Rail_Fields_Pkg.Tier_Kind;
      use type Model_Rail_Fields_Pkg.Protocol_Kind;
      use type Rail_Verb_Pkg.Verdict_Type;
      use type Rail_Verb_Pkg.Tier_Request;
      Conf     : constant String := "config/rail.conf";
      Tmp      : constant String := "config/rail.conf.set-tmp";
      Backup   : constant String := "config/rail.conf.pre-set";
      Max_L    : constant := 64;
      type Line_Array is array (1 .. Max_L) of Unbounded_String;
      L1       : constant String (1 .. Line'Length) := Line;
      Q        : constant String := """";

      function Arg (Key : String; Given : out Boolean) return String is
         K1 : constant String (1 .. Key'Length) := Key;
         S  : Json_Scan_Pkg.Span_Type;
         C  : Json_Scan_Pkg.Span_Type;
      begin
         Given := False;
         if L1'Length > 1_048_576 or else K1'Length not in 1 .. 64
           or else Ada.Strings.Fixed.Count (L1, Q & K1 & Q) /= 1
         then
            return "";   --  absent, or given more than once: never guessed
         end if;
         S := Frame_Facts_Pkg.Arg_Span (L1, K1);   --  params.arguments.<Key>, nowhere else
         if not S.found or else S.kind /= Json_Scan_Pkg.K_String then
            return "";
         end if;
         C := Json_Scan_Pkg.String_Contents (L1, S);
         if not C.found or else C.last < C.first then
            return "";
         end if;
         Given := True;
         return L1 (C.first .. C.last);
      end Arg;

      function Has (Key : String) return Boolean is
         K1 : constant String (1 .. Key'Length) := Key;
      begin
         return L1'Length <= 1_048_576 and then K1'Length in 1 .. 64
           and then Frame_Facts_Pkg.Arg_Span (L1, K1).found;   --  params.arguments.<Key>
      end Has;

      function Read (Path : String; Lines : out Line_Array; N : out Natural; All_Text : out Unbounded_String)
        return Boolean
      is
         F : Ada.Text_IO.File_Type;
      begin
         N := 0;
         All_Text := Null_Unbounded_String;
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
         while not Ada.Text_IO.End_Of_File (F) loop
            declare
               S : constant String := Ada.Text_IO.Get_Line (F);
            begin
               if N = Max_L or else S'Length > 4096 then
                  Ada.Text_IO.Close (F);
                  return False;
               end if;
               N := N + 1;
               Lines (N) := To_Unbounded_String (S);
               All_Text := All_Text & S & ASCII.LF;
            end;
         end loop;
         Ada.Text_IO.Close (F);
         return True;
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
            return False;
      end Read;

      function Is_Model (S : String) return Boolean is
         S1 : constant String (1 .. S'Length) := S;
      begin
         return Rail_Config_Pkg.Rail_Of (S1) = Rail_Config_Pkg.Rail_Model;
      end Is_Model;

      function Valid (S : String) return Boolean is
         S1 : constant String (1 .. S'Length) := S;
      begin
         return Rail_Config_Pkg.Is_Valid (S1) and then Model_Rail_Fields_Pkg.Is_Valid_Model_Line (S1);
      end Valid;

      function Field (S : String; Key : String) return String is
         S1 : constant String (1 .. S'Length) := S;
         K1 : constant String (1 .. Key'Length) := Key;
         C  : constant Json_Scan_Pkg.Span_Type := Rail_Config_Pkg.Contents (S1, K1);
      begin
         return (if C.found and then C.first <= C.last then S1 (C.first .. C.last) else "");
      end Field;

      function Tier (S : String) return Model_Rail_Fields_Pkg.Tier_Kind is
         S1 : constant String (1 .. S'Length) := S;
      begin
         return Model_Rail_Fields_Pkg.Tier_Of (S1);
      end Tier;

      function Verdict_Of (Lines : Line_Array; N : Natural) return Model_Tier_Select_Pkg.Select_Verdict is
         T : Model_Tier_Select_Pkg.Tier_Tally := Model_Tier_Select_Pkg.Empty;
      begin
         for I in 1 .. N loop
            declare
               S : constant String := To_String (Lines (I));
            begin
               if Is_Model (S) then
                  T := (if Valid (S) then Model_Tier_Select_Pkg.Add (T, Tier (S)) else Model_Tier_Select_Pkg.Add_Invalid (T));
               end if;
            end;
         end loop;
         return Model_Tier_Select_Pkg.Verdict (T);
      end Verdict_Of;

      --  The tier value of one model line set to Word: the "tier" string replaced in place, or (no tier key --
      --  standard by absence) appended before the line's closing brace. Nothing else in the line is touched.
      function With_Tier (S : String; Word : String) return String is
         S1 : constant String (1 .. S'Length) := S;
         C  : constant Json_Scan_Pkg.Span_Type := Rail_Config_Pkg.Contents (S1, Model_Rail_Fields_Pkg.Tier_Key);
         P  : constant Natural := Ada.Strings.Fixed.Index (S1, "}", Ada.Strings.Backward);
      begin
         if C.found and then C.first <= C.last then
            return S1 (1 .. C.first - 1) & Word & S1 (C.last + 1 .. S1'Last);
         elsif P > 0 then
            return S1 (1 .. P - 1) & "," & Q & "tier" & Q & ":" & Q & Word & Q & S1 (P .. S1'Last);
         else
            return S1;
         end if;
      end With_Tier;

      function Reply (V : String; More : String := "") return String is
        ("{" & Q & "verdict" & Q & ":" & Q & V & Q & More & "}");

      Tier_Given, Model_Given : Boolean;
      Tier_Arg  : constant String := Arg ("tier", Tier_Given);
      Model_Arg : constant String := Arg ("model", Model_Given);
      F         : Rail_Verb_Pkg.Facts_Type;
      Lines     : Line_Array;
      N         : Natural;
      Before    : Unbounded_String;
      Target, Other, Matches, Models : Natural := 0;
   begin
      F.forbidden_key := Has ("rail") or else Has ("host") or else Has ("port") or else Has ("sovereign")
        or else Has ("protocol") or else Has ("timeout_seconds") or else Has ("max_reply_bytes")
        or else Has ("max_tokens");
      F.tier_given  := Tier_Given;
      F.model_given := Model_Given;
      F.requested   := (if Tier_Arg = "standard" then Rail_Verb_Pkg.Want_Standard
                        elsif Tier_Arg = "elevated" then Rail_Verb_Pkg.Want_Elevated
                        else Rail_Verb_Pkg.Want_Unknown);
      if not Read (Conf, Lines, N, Before) then
         F.conf_ok := False;
      else
         F.conf_ok := Verdict_Of (Lines, N) = Model_Tier_Select_Pkg.Select_Ok;
         for I in 1 .. N loop
            declare
               S : constant String := To_String (Lines (I));
            begin
               if Is_Model (S) and then Valid (S) then
                  Models := Models + 1;
                  if Model_Given and then Field (S, Model_Rail_Fields_Pkg.Model_Key) = Model_Arg then
                     Matches := Matches + 1;
                     Target := I;
                  else
                     Other := I;
                  end if;
               end if;
            end;
         end loop;
      end if;
      F.target_found      := Matches = 1;
      F.target_serves     := F.target_found and then
        ((F.requested = Rail_Verb_Pkg.Want_Standard and then Tier (To_String (Lines (Target))) = Model_Rail_Fields_Pkg.Tier_Standard)
         or else (F.requested = Rail_Verb_Pkg.Want_Elevated and then Tier (To_String (Lines (Target))) = Model_Rail_Fields_Pkg.Tier_Elevated));
      F.other_line_exists := F.target_found and then Models = 2 and then Other /= 0;

      declare
         V : constant Rail_Verb_Pkg.Verdict_Type := Rail_Verb_Pkg.Decide (F);
         W : constant String := Rail_Verb_Pkg.Word_Of (V);
      begin
         if V = Rail_Verb_Pkg.Set_Unchanged then
            return Reply (W, "," & Q & "tier" & Q & ":" & Q & Tier_Arg & Q & "," & Q & "model" & Q & ":" & Q & Model_Arg & Q);
         elsif V /= Rail_Verb_Pkg.Set_Swap then
            return Reply (W);
         end if;
      end;

      --  Set_Swap: the two declared model lines exchange tier values; everything else byte-identical.
      declare
         Want  : constant String := Tier_Arg;
         Other_Word : constant String := (if Want = "standard" then "elevated" else "standard");
         New_Lines  : Line_Array := Lines;
         After_Lines : Line_Array;
         After_N     : Natural;
         Now_Text, Scratch : Unbounded_String;
         Ok     : Boolean := True;
         Out_F  : Ada.Text_IO.File_Type;
         Renamed : Boolean;
      begin
         New_Lines (Target) := To_Unbounded_String (With_Tier (To_String (Lines (Target)), Want));
         New_Lines (Other)  := To_Unbounded_String (With_Tier (To_String (Lines (Other)), Other_Word));
         begin
            Ada.Text_IO.Create (Out_F, Ada.Text_IO.Out_File, Tmp);
            for I in 1 .. N loop
               Ada.Text_IO.Put_Line (Out_F, To_String (New_Lines (I)));
            end loop;
            Ada.Text_IO.Close (Out_F);
         exception
            when others =>
               return Reply ("refused_write_failed");
         end;
         --  Re-judge the temp file with the proven cores, line by line against what was read.
         Ok := Read (Tmp, After_Lines, After_N, Scratch) and then After_N = N
           and then Verdict_Of (After_Lines, After_N) = Model_Tier_Select_Pkg.Select_Ok;
         if Ok then
            for I in 1 .. N loop
               declare
                  B : constant String := To_String (Lines (I));
                  A : constant String := To_String (After_Lines (I));
               begin
                  if not (Is_Model (B) and then Valid (B)) then
                     Ok := Ok and then A = B;
                  else
                     Ok := Ok and then Is_Model (A) and then Valid (A)
                       and then Field (A, Model_Rail_Fields_Pkg.Model_Key) = Field (B, Model_Rail_Fields_Pkg.Model_Key)
                       and then Field (A, "host") = Field (B, "host")
                       and then Field (A, "port") = Field (B, "port")
                       and then Field (A, "sovereign") = Field (B, "sovereign")
                       and then Field (A, "protocol") = Field (B, "protocol");
                  end if;
               end;
            end loop;
            Ok := Ok and then Tier (To_String (After_Lines (Target))) =
              (if Want = "standard" then Model_Rail_Fields_Pkg.Tier_Standard else Model_Rail_Fields_Pkg.Tier_Elevated);
         end if;
         --  The live file must still be exactly what was read (nobody edited it underneath us).
         Ok := Ok and then Read (Conf, After_Lines, After_N, Now_Text) and then Now_Text = Before;
         if not Ok then
            GNAT.OS_Lib.Delete_File (Tmp, Renamed);
            return Reply ("refused_write_check");
         end if;
         --  Keep the previous file, then replace it (rename over the old name; where the OS will not
         --  rename over an existing file, remove it first -- the backup already holds it).
         begin
            Ada.Text_IO.Create (Out_F, Ada.Text_IO.Out_File, Backup);
            for I in 1 .. N loop   --  line by line: one Put of the whole text let Close add a SECOND terminator
               Ada.Text_IO.Put_Line (Out_F, To_String (Lines (I)));
            end loop;
            Ada.Text_IO.Close (Out_F);
         exception
            when others =>
               GNAT.OS_Lib.Delete_File (Tmp, Renamed);
               return Reply ("refused_write_failed");
         end;
         GNAT.OS_Lib.Rename_File (Tmp, Conf, Renamed);
         if not Renamed then
            GNAT.OS_Lib.Delete_File (Conf, Renamed);
            GNAT.OS_Lib.Rename_File (Tmp, Conf, Renamed);
         end if;
         if not Renamed then
            return Reply ("refused_write_failed", "," & Q & "backup" & Q & ":" & Q & Backup & Q);
         end if;
         return Reply ("set_swap", "," & Q & "tier" & Q & ":" & Q & Want & Q & "," & Q & "model" & Q & ":" & Q & Model_Arg & Q &
                       "," & Q & "backup" & Q & ":" & Q & Backup & Q);
      end;
   end Rail_Set_Text;

   function Palais_Enrol_Text (Line : String) return String is
      Span  : constant Json_Scan_Pkg.Span_Type := Frame_Facts_Pkg.Codename_Span (Line);
      Home  : constant String :=
        (if Ada.Environment_Variables.Exists ("HOME") then Ada.Environment_Variables.Value ("HOME") else ".");
      Reply : Palais_Enrol_Pkg.Text_Access;
      Name  : constant String :=
        (if Span.found and then Span.kind = Json_Scan_Pkg.K_String and then Span.first < Span.last
         then Line (Json_Scan_Pkg.String_Contents (Line, Span).first .. Json_Scan_Pkg.String_Contents (Line, Span).last)
         else "");
   begin
      Palais_Enrol_Pkg.Step
        (Codename => Name,
         Where    => (Conf_Path      => new String'("config/rail.conf"),
                      Key_Dir        => new String'(Home & "/.crucible/key"),
                      State_Dir      => new String'("state"),
                      Signers_Path   => new String'("config/reef-allowed-signers"),
                      Signers_Digest => new String'(Pinned_Reef_Signers),
                      Ssh_Keygen     => new String'("/usr/bin/ssh-keygen")),
         Reply    => Reply);
      return Reply.all;
   end Palais_Enrol_Text;

   function Forge_Text (Line : String) return String is
      use Ada.Strings.Unbounded;
      function Low (S : String) return String renames Ada.Characters.Handling.To_Lower;
      Span : constant Json_Scan_Pkg.Span_Type := Frame_Facts_Pkg.Sheet_Span (Line);
   begin
      --  v14: the REPORT-MODE switch is read FIRST, on every forge call, before the tower. The door decides nothing
      --  here: the edge reads config/report.conf WHOLE, line by line with the unbounded Get_Line (never a fixed buffer,
      --  never trimmed, no CR or BOM stripped), and the proven Report_Mode_Pkg judges it. Only a malformed file speaks,
      --  one line on standard error. The forge never waits on it, and no fault here can turn the mode on. The mode
      --  itself is kept by D1's lineage, which is its first reader.
      declare
         Conf    : constant String := "config/report.conf";
         Present : constant Boolean := Ada.Directories.Exists (Conf);
         Lines   : Natural := 0;
         Found   : Report_Mode_Pkg.Fact_Kind := Report_Mode_Pkg.Fact_Not_Exact;
         Fact    : Report_Mode_Pkg.Fact_Kind;
         F       : Ada.Text_IO.File_Type;
         function Is_Blank (S : String) return Boolean is
           (for all C of S => C = ' ' or else C = ASCII.HT);
      begin
         if Present and then Ada.Directories.Kind (Conf) in Ada.Directories.Ordinary_File then
            Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Conf);
            while Lines < 2 and then not Ada.Text_IO.End_Of_File (F) loop
               declare
                  L : constant String := Ada.Text_IO.Get_Line (F);
               begin
                  if not Is_Blank (L) then
                     Lines := Lines + 1;
                     if Lines = 1 then
                        Found := Report_Mode_Pkg.Line_Fact (L);
                     end if;
                  end if;
               end;
            end loop;
            Ada.Text_IO.Close (F);
         end if;
         Fact := Report_Mode_Pkg.Decide (Present, Lines, Found);
         if Report_Mode_Pkg.Is_Malformed (Fact) then
            Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
              "report: " & Conf & " " & Report_Mode_Pkg.Word_Of (Fact) & "; report mode is OFF");
         end if;
      exception
         when others =>
            if Ada.Text_IO.Is_Open (F) then
               Ada.Text_IO.Close (F);
            end if;
            Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "report: " & Conf & " unreadable; report mode is OFF");
      end;
      --  v9: the tower base is checked FIRST, before the sheet is looked for. The door decides nothing here:
      --  the edge measures, Tower_Base_Verdict_Pkg.May_Forge permits or refuses, Reason_Word names the refusal.
      declare
         Base_Verdict : Tower_Base_Verdict_Pkg.Verdict_Kind;
         Tower_Facts  : Tower_Base_Verdict_Pkg.Base_Facts;
         Base_Line_1  : Unbounded_String;
      begin
         Tower_Base_Check_Edge.Check (Verdict => Base_Verdict, Facts => Tower_Facts, Line_1 => Base_Line_1);
         if not Tower_Base_Verdict_Pkg.May_Forge (Base_Verdict) then
            return "{""final"":""refused"",""stopped_at"":""tower"",""reason"":""" &
              Tower_Base_Verdict_Pkg.Reason_Word (Base_Verdict) &
              """,""hint"":""restore the base bundle this binary was built with, or replace the binary""}";
         end if;
      end;
      --  v10: the SHARER bundle is imported, best effort, once the base has let the door through and before the
      --  sheet is looked for. Tower_Import_Pkg measures, the proven Tower_Admission_Pkg decides, the proven
      --  Tower_Ledger_Fold_Pkg folds the ledger, and the word is recorded in state/tower.jsonl. THE FORGE NEVER WAITS
      --  ON IT: whatever the word, the forge proceeds on the ledger as it stands. The word goes to standard error,
      --  one line, so it is seen and can never be mistaken for the reply. Import never raises; the handler is a belt.
      declare
         Import_Word : Unbounded_String;
      begin
         Tower_Import_Pkg.Import (Word => Import_Word);
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "tower_import: " & To_String (Import_Word));
      exception
         when others =>
            Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "tower_import: unreadable");
      end;
      if not (Span.found and then Span.kind = Json_Scan_Pkg.K_String and then Span.first < Span.last) then
         return "{""final"":""refused"",""stopped_at"":""intake"",""reason"":""no sheet""}";
      end if;
      declare
         C       : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, Span);
         Raw     : constant String (1 .. Natural'Max (0, C.last - C.first + 1)) := Line (C.first .. C.last);
         Decoded : String (1 .. Natural'Max (1, Raw'Length));
         Dec_Len : Natural;
         Ok      : Boolean;
      begin
         Json_String_Pkg.Decode (Raw, Decoded, Dec_Len, Ok);
         if not Ok then
            return "{""final"":""refused"",""stopped_at"":""intake"",""reason"":""bad_string""}";
         end if;
         declare
            type Buf_Access is access String;
            procedure Free is new Ada.Unchecked_Deallocation (String, Buf_Access);
            R       : constant Pipeline_Run_Pkg.Report := Pipeline_Run_Pkg.Run (Decoded (1 .. Dec_Len));
            Why     : constant String := To_String (R.Reason);
            W1      : constant String (1 .. Why'Length) := Why;
            Enc     : Buf_Access := new String (1 .. Natural'Max (1, 6 * W1'Length));
            Enc_Len : Natural;
            Enc_Ok  : Boolean;
         begin
            Json_String_Pkg.Encode (W1, Enc.all, Enc_Len, Enc_Ok);
            declare
               Result : constant String :=
                 "{""final"":""" & Low (Pipeline_Stage_Pkg.Stage'Image (R.Final)) &
                 """,""stopped_at"":""" & Low (Pipeline_Stage_Pkg.Stage'Image (R.Stopped_At)) &
                 """,""transitions"":""" & Img (R.Transitions) &
                 """,""emit_allowed"":""" & (if R.Emit_Allowed then "true" else "false") &
                 """,""reason"":""" & (if Enc_Ok then Enc (1 .. Enc_Len) else "unencodable") & """}";
            begin
               Free (Enc);
               return Result;
            end;
         exception
            when others =>
               Free (Enc);
               raise;
         end;
      end;
   exception
      when others =>
         return "{""final"":""unmeasured"",""stopped_at"":""intake"",""reason"":""unreadable""}";
   end Forge_Text;

begin
   --  ★ SELF-ROOT (lineage 11). The door resolves config/, tower/ and state/ RELATIVE to the
   --  directory it is started in, so started anywhere else it refused every forge with
   --  tower_base_missing, and a launcher had to cd for it. A launcher cannot: Windows has no
   --  /bin/sh. So the door now puts itself in its own install directory, which is what the
   --  owners ruling of 2026-09-23 -- Crucible ships as ONE executable -- asks for.
   --  BOTH path separators count: on Windows Command_Name carries backslashes, and testing
   --  for / alone made an absolute path look like a bare name (the stamp_signers defect,
   --  measured 2026-09-25). If the directory cannot be determined the door leaves the working
   --  directory alone and behaves exactly as before: this step can help, never refuse.
   declare
      Name : constant String := Ada.Command_Line.Command_Name;
      Sep  : Boolean := False;
   begin
      for C of Name loop
         if C = '/' or else C = '\' then
            Sep := True;
         end if;
      end loop;
      if Sep then
         declare
            Bin_Dir : constant String :=
              Ada.Directories.Containing_Directory (Ada.Directories.Full_Name (Name));
            Root    : constant String := Ada.Directories.Containing_Directory (Bin_Dir);
         begin
            --  The install root is the PARENT of bin/, because config/, tower/ and state/
            --  sit beside bin/ and not inside it. Move only if that parent really is an
            --  install: tower/base.bundle is the file the door would otherwise refuse for.
            if Ada.Directories.Exists
                 (Ada.Directories.Compose (Root, "tower") & "/base.bundle")
            then
               Ada.Directories.Set_Directory (Root);
            end if;
         end;
      end if;
   exception
      when others => null;
   end;
   while not Ada.Text_IO.End_Of_File loop
      Read_Frame (Too_Long);
      if Too_Long then
         Ada.Text_IO.Put_Line
           (Reply_Text_Pkg.Error_Reply
              (Null_Id,
               Json_Rpc_Frame_Pkg.Error_Code
                 (Json_Rpc_Frame_Pkg.Facts_Type'(parse_failed   => True,
                                                 jsonrpc_is_2_0 => False,
                                                 has_id         => False,
                                                 method         => Json_Rpc_Frame_Pkg.M_Unknown,
                                                 has_params     => False)),
               Too_Long_Msg));
         Ada.Text_IO.Flush;
      else
         declare
            Line  : constant String := Buffer.all (1 .. Last);
            Facts : constant Json_Rpc_Frame_Pkg.Facts_Type := Frame_Facts_Pkg.Facts_Of (Line);
            V     : constant Json_Rpc_Frame_Pkg.Verdict_Type := Json_Rpc_Frame_Pkg.Assemble (Facts);
            Span  : constant Json_Scan_Pkg.Span_Type := Frame_Facts_Pkg.Id_Span (Line);
            Id    : constant String (1 .. (if Span.found then Span.last - Span.first + 1 else Null_Id'Length)) :=
              (if Span.found then Line (Span.first .. Span.last) else Null_Id);
         begin
            if V.reply = Json_Rpc_Frame_Pkg.Reply_Error then
               --  SLOT BEGIN (frame-error)
               if V.error_code = -32700 and then Frame_Facts_Pkg.Brackets_Unclosed (Line) then
                  Ada.Text_IO.Put_Line (Reply_Text_Pkg.Error_Reply (Id, V.error_code, Brackets_Msg));
               else
                  Ada.Text_IO.Put_Line (Reply_Text_Pkg.Error_Reply (Id, V.error_code, Frame_Msg));
               end if;
               --  SLOT END (frame-error)
            elsif V.reply = Json_Rpc_Frame_Pkg.Reply_Result then
               case V.action is
                  when Json_Rpc_Frame_Pkg.Do_Initialize =>
                     Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Initialize_Result (Server_Name)));
                  when Json_Rpc_Frame_Pkg.Do_List_Tools =>
                     Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tools_List_Result));
                  when Json_Rpc_Frame_Pkg.Do_Call_Tool =>
                     --  SLOT BEGIN (duplicate-key)
                     if Frame_Facts_Pkg.Duplicate_Key (Line) then
                        Ada.Text_IO.Put_Line (Reply_Text_Pkg.Error_Reply (Id, -32602, Duplicate_Msg));
                     elsif Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Licence_Gate then
                     --  SLOT END (duplicate-key)
                        Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Tool_Run_Pkg.Licence_Gate (Crucible_Edition.Current, Line))));
                     elsif Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Intake_Check then
                        Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Intake_Check_Text (Line))));
                     elsif Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Prove_Unit then
                        Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Prove_Unit_Text (Line))));
                     elsif Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Forge then
                        Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Forge_Text (Line))));
                     elsif Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Palais_Enrol then
                        Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Palais_Enrol_Text (Line))));
                     elsif Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Rail_Show then
                        Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Rail_Show_Text)));
                     elsif Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Rail_Set then
                        Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Rail_Set_Text (Line))));
                     else
                        Ada.Text_IO.Put_Line (Reply_Text_Pkg.Error_Reply (Id, -32602, Bad_Tool_Msg));
                     end if;
                  when Json_Rpc_Frame_Pkg.Do_Nothing =>
                     null;
               end case;
            end if;
            Ada.Text_IO.Flush;
         end;
      end if;
   end loop;
end Crucible_Main;
