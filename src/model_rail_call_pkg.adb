--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 4948cf9e190c93301a46a8afc09369debd4cac297bfc701ba2b0b96f289cf8f6
--
--  Model_Rail_Call_Pkg body -- template (seat-written plumbing) with TWO slots (sent_fact, reply_facts), filled by a
--  Wu edge round. Brief BRIEF_crucible_step4_wiring_2026-09-17 (step 5 unit 5).
--  Lineage 4 (2026-09-28, Tony: "make the door send num_ctx"): the eight lineage-3 slots are frozen as fixed text.
--  ONE slot, req-body: the Ollama request carries the model line's context size (Model_Rail_Fields_Pkg.Num_Ctx_Of,
--  32768 when the line names none), so Ollama never loads a model at its full native context. OpenAI: unchanged.
--  Lineage 5 (2026-09-28, Tony 17:07: refuse a prompt too long for the configured context, by name): req-body frozen;
--  sent_fact reopened: an Ollama prompt that Model_Rail_Fields_Pkg.Prompt_Fits_Context refuses is never sent, and the
--  refusal prompt_exceeds_context is said with the estimated tokens, num_ctx and max_tokens.
--  Lineage 6 (2026-09-28, Tony: refusals name the real fault, A11): sent_fact reopened; the same refusal is also handed
--  back to the caller in Refusal, so the forge reply names it. The three-parameter Complete calls this one.
--  Lineage 7 (2026-09-28, Tony 18:05 "yes do all three qwen fixes", fix 3): every earlier slot frozen; THREE slots:
--  runaway-decl, runaway-measure (the longest blank run and longest one-character run over the decoded reply, judged by
--  the admitted Reply_Runaway_Pkg; a runaway is said and handed back as reply_runaway) and runaway-verdict (a runaway
--  reply is never text: Reply_Unreadable). The request itself gains the stop sequence in Model_Request_Pkg lineage 6.
--  Lineage 8 (2026-10-18, Tony 17:05 "stick em all in", fix 6 of the fail-loudly audit, items 8 and 9): every earlier
--  slot frozen; FIVE slots: say (Say marks that the call said something, and a failed rail-log write is said and
--  flagged), detail-decl + call-reset, http-detail (an unusable HTTP reply keeps its status line and up to 256 body
--  bytes), outcome-notes (a non-text outcome not already said is said; the caller is handed the server's words and a
--  note when the rail log is incomplete). Every other reason the caller builds is unchanged.
with Ada.Unchecked_Deallocation;
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Json_Scan_Pkg;
with Json_String_Pkg;
with Rail_Config_Pkg;
with Model_Rail_Fields_Pkg;
with Model_Tier_Select_Pkg;
with Model_Request_Pkg;
with Http_Reply_Pkg;
with Rail_Socket_Edge;
with Sovereign_Gate_Pkg;
with Reply_Runaway_Pkg;
with Ada.Exceptions;
with Ada.Characters.Handling;

package body Model_Rail_Call_Pkg with SPARK_Mode => Off is

   use type Rail_Config_Pkg.Rail_Kind;
   use type Model_Rail_Fields_Pkg.Protocol_Kind;
   use type Sovereign_Gate_Pkg.Route_Kind;
   use type Model_Rail_Fields_Pkg.Tier_Kind;
   use type Model_Tier_Select_Pkg.Select_Verdict;

   --  v0.3 I-tiers: the tier verdict, SAID. A rail.conf the proven fold refuses never reaches the model, and the
   --  operator is told why -- on stderr and as one row in state/model-rail.jsonl -- instead of the edit doing nothing.
   function Verdict_Word (V : Model_Tier_Select_Pkg.Select_Verdict) return String is
     (case V is
         when Model_Tier_Select_Pkg.Select_Ok        => "select_ok",
         when Model_Tier_Select_Pkg.Invalid_Model_Line => "invalid_model_line",
         when Model_Tier_Select_Pkg.Unknown_Tier     => "unknown_tier",
         when Model_Tier_Select_Pkg.Duplicate_Tier   => "duplicate_tier",
         when Model_Tier_Select_Pkg.No_Standard_Line => "no_standard_line");

   --  SLOT BEGIN (say)
   --  Lineage 8: whether this call said anything, and whether a row could not be written to state/model-rail.jsonl.
   Said_This_Call : Boolean := False;
   Say_Unwritten  : Boolean := False;

   procedure Say (Row : String) is
      F : Ada.Text_IO.File_Type;
   begin
      Said_This_Call := True;
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Row);
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.Append_File, "state/model-rail.jsonl");
      exception
         when Ada.Text_IO.Name_Error =>
            Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, "state/model-rail.jsonl");
      end;
      Ada.Text_IO.Put_Line (F, Row);
      Ada.Text_IO.Close (F);
   exception
      when E : others =>
         --  Lineage 8: a file failure still never changes the rail outcome, but the caller is told the log is
         --  incomplete (audit item 8).
         Say_Unwritten := True;
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
           "model rail: state/model-rail.jsonl unwritable: " & Ada.Exceptions.Exception_Name (E));
   end Say;

   --  Lineage 8: S as the contents of a JSON string, encoded by the proven Json_String_Pkg.
   function Json_Text (S : String) return String is
      S1  : constant String (1 .. S'Length) := S;
      Buf : String (1 .. Natural'Max (1, 6 * S1'Length));
      Len : Natural;
      Ok  : Boolean;
   begin
      Json_String_Pkg.Encode (S1, Buf, Len, Ok);
      return (if Ok then Buf (1 .. Len) else "unencodable");
   end Json_Text;
   --  SLOT END (say)

   Max_Conf_Line : constant := 4096;
   CRLF          : constant String := Character'Val (13) & Character'Val (10);

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

   function Int_Img (N : Integer) return String is
      S : constant String := Integer'Image (N);
   begin
      return (if N < 0 then S else S (S'First + 1 .. S'Last));
   end Int_Img;

   procedure Complete
     (Prompt  : String;
      Text    : out Text_Access;
      Outcome : out Model_Reply_Pkg.Outcome_Kind;
      Refusal : out Ada.Strings.Unbounded.Unbounded_String)
   is
      F        : Model_Reply_Pkg.Facts_Type;
      Conf_Buf : String (1 .. Max_Conf_Line);
      Conf_Len : Natural := 0;
      Found    : Boolean := False;   --  a line valid for Rail_Config_Pkg (rail model) AND Model_Rail_Fields_Pkg
      Tally    : Model_Tier_Select_Pkg.Tier_Tally := Model_Tier_Select_Pkg.Empty;   --  v0.3 I-tiers: EVERY valid model line, by tier
      Std_Seen : Boolean := False;   --  the first STANDARD line is held in Conf_Buf; any other line only counts
      Conf_Err : Boolean := False;   --  the file could not be read to its end: a partial tally is never trusted
      --  Lineage 7: the two run lengths the edge measures over a decoded reply, and the admitted verdict on them.
      Blank_Run : Natural := 0;
      Same_Run  : Natural := 0;
      Runaway   : Boolean := False;
      --  SLOT BEGIN (detail-decl)
      --  Lineage 8: the status line and a bounded body slice of an HTTP reply that was not usable (audit item 9).
      Http_Detail : Ada.Strings.Unbounded.Unbounded_String;
      --  SLOT END (detail-decl)
   begin
      Text := null;
      Refusal := Ada.Strings.Unbounded.Null_Unbounded_String;
      --  SLOT BEGIN (call-reset)
      Said_This_Call := False;
      Say_Unwritten := False;
      --  SLOT END (call-reset)

      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Conf_Path);
         while not Ada.Text_IO.End_Of_File (File) loop   --  every line: a second model line is never silently ignored
            declare
               L  : constant String := Ada.Text_IO.Get_Line (File);
               L1 : constant String (1 .. L'Length) := L;
            begin
               if L1'Length > Max_Conf_Line then
                  raise Ada.Text_IO.Data_Error;   --  a line too long to judge: the file is refused as unreadable, never half-read
               elsif Rail_Config_Pkg.Rail_Of (L1) /= Rail_Config_Pkg.Rail_Model then
                  null;   --  another rail's line: not the model rail's to judge
               elsif Rail_Config_Pkg.Is_Valid (L1)
                 and then Model_Rail_Fields_Pkg.Is_Valid_Model_Line (L1)
               then
                  Tally := Model_Tier_Select_Pkg.Add (Tally, Model_Rail_Fields_Pkg.Tier_Of (L1));
                  if not Std_Seen and then Model_Rail_Fields_Pkg.Tier_Of (L1) = Model_Rail_Fields_Pkg.Tier_Standard then
                     Conf_Buf (1 .. L1'Length) := L1;
                     Conf_Len := L1'Length;
                     Std_Seen := True;
                  end if;
               else
                  --  a line that says it is the model rail but that the proven judges refuse (bad host, port,
                  --  model, protocol, ...): counted, never silently skipped
                  Tally := Model_Tier_Select_Pkg.Add_Invalid (Tally);
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (File);
      exception
         when others =>
            if Ada.Text_IO.Is_Open (File) then
               Ada.Text_IO.Close (File);
            end if;
            Std_Seen := False;
            Conf_Err := True;
            Conf_Len := 0;
      end;

      --  The proven fold decides; this only acts on its verdict and says it.
      Found := not Conf_Err and then Std_Seen and then Model_Tier_Select_Pkg.Verdict (Tally) = Model_Tier_Select_Pkg.Select_Ok;
      if Conf_Err then
         Say ("{""rail"":""model"",""refused"":""conf_unreadable"",""path"":""" & Conf_Path & """}");
      elsif Model_Tier_Select_Pkg.Verdict (Tally) /= Model_Tier_Select_Pkg.Select_Ok then
         Say ("{""rail"":""model"",""refused"":""" & Verdict_Word (Model_Tier_Select_Pkg.Verdict (Tally)) &
              """,""standard_lines"":""" & Img (Tally.standard_lines) & """,""elevated_lines"":""" &
              Img (Tally.elevated_lines) & """,""unknown_lines"":""" & Img (Tally.unknown_lines) &
              """,""invalid_lines"":""" & Img (Tally.invalid_lines) & """,""counts"":""2 means two or more""}");
      elsif Model_Tier_Select_Pkg.Elevated_Declared (Tally) then
         Say ("{""rail"":""model"",""note"":""elevated_declared_not_used"",""why"":""escalation is not built yet""}");
      end if;

      declare
         Conf       : constant String (1 .. Conf_Len) := Conf_Buf (1 .. Conf_Len);
         Host       : constant String :=
           (if Found then Conf (Rail_Config_Pkg.Host_Span (Conf).first .. Rail_Config_Pkg.Host_Span (Conf).last) else "");
         Endpoint   : constant String := "http://" & Host;
         Endpoint_1 : constant String (1 .. Endpoint'Length) := Endpoint;
         Route_Ok   : constant Boolean :=
           Found and then Endpoint_1'Length <= Sovereign_Gate_Pkg.Max_Endpoint
           and then Sovereign_Gate_Pkg.Route_Of (Endpoint_1, Rail_Config_Pkg.Sovereign_Of (Conf))
                    /= Sovereign_Gate_Pkg.Refused_Sovereign_Off_Estate;
         Prompt_Ok  : constant Boolean := Prompt'Length <= Model_Request_Pkg.Max_Prompt;
         P1         : constant String (1 .. Prompt'Length) := Prompt;
         procedure Free is new Ada.Unchecked_Deallocation (String, Text_Access);
         Enc        : Text_Access := new String (1 .. Natural'Max (1, 6 * P1'Length));
         Enc_Len    : Natural := 0;
         Enc_Ok     : Boolean := False;
      begin
         if Found and then Route_Ok and then Prompt_Ok then
            Json_String_Pkg.Encode (P1, Enc.all, Enc_Len, Enc_Ok);
         end if;

         F.sent := Found and then Route_Ok and then Prompt_Ok and then Enc_Ok
                   and then Enc_Len <= 2 * Model_Request_Pkg.Max_Prompt
                   and then Model_Rail_Fields_Pkg.Prompt_Fits_Context (Conf, P1'Length);
         if Enc_Ok and then Enc_Len > 2 * Model_Request_Pkg.Max_Prompt then
            Say ("{""rail"":""model"",""refused"":""not sent: encoded prompt too long"",""encoded_length"":""" &
                 Img (Enc_Len) & """,""bound"":""" & Img (2 * Model_Request_Pkg.Max_Prompt) & """}");
         elsif Found and then Route_Ok and then Prompt_Ok and then Enc_Ok
           and then not Model_Rail_Fields_Pkg.Prompt_Fits_Context (Conf, P1'Length)
         then
            Say ("{""rail"":""model"",""refused"":""prompt_exceeds_context"",""prompt_bytes"":""" & Img (P1'Length) &
                 """,""estimated_tokens"":""" & Img (Model_Rail_Fields_Pkg.Estimated_Tokens (P1'Length)) &
                 """,""num_ctx"":""" & Img (Model_Rail_Fields_Pkg.Num_Ctx_Of (Conf)) &
                 """,""max_tokens"":""" & Img (Model_Rail_Fields_Pkg.Max_Tokens_Of (Conf)) &
                 """,""bytes_per_token"":""" & Img (Model_Rail_Fields_Pkg.Chars_Per_Token) & """}");
            Refusal := Ada.Strings.Unbounded.To_Unbounded_String
              ("prompt_exceeds_context (estimated " & Img (Model_Rail_Fields_Pkg.Estimated_Tokens (P1'Length)) &
               " tokens > budget " & Int_Img (Model_Rail_Fields_Pkg.Context_Budget (Conf)) &
               " = num_ctx " & Img (Model_Rail_Fields_Pkg.Num_Ctx_Of (Conf)) &
               " - max_tokens " & Img (Model_Rail_Fields_Pkg.Max_Tokens_Of (Conf)) & ")");
         end if;

         if F.sent then
            declare
               Model     : constant String :=
                 Conf (Model_Rail_Fields_Pkg.Model_Span (Conf).first .. Model_Rail_Fields_Pkg.Model_Span (Conf).last);
               Model_1   : constant String (1 .. Model'Length) := Model;
               Encoded   : constant String (1 .. Enc_Len) := Enc (1 .. Enc_Len);
               Is_Ollama : constant Boolean :=
                 Model_Rail_Fields_Pkg.Protocol_Of (Conf) = Model_Rail_Fields_Pkg.Protocol_Ollama;
               Req_Body  : constant String :=
                 (if Is_Ollama then Model_Request_Pkg.Request_Text
                                      (Model_1, Encoded, Model_Rail_Fields_Pkg.Max_Tokens_Of (Conf),
                                       Model_Rail_Fields_Pkg.Num_Ctx_Of (Conf))
                  else Model_Request_Pkg.Request_Text_Openai
                         (Model_1, Encoded, Model_Rail_Fields_Pkg.Max_Tokens_Of (Conf)));
               Path      : constant String := (if Is_Ollama then "/api/chat" else "/v1/chat/completions");
               Request   : constant String :=
                 "POST " & Path & " HTTP/1.0" & CRLF &
                 "Host: " & Host & CRLF &
                 "Content-Type: application/json" & CRLF &
                 "Content-Length: " & Img (Req_Body'Length) & CRLF &
                 "Connection: close" & CRLF & CRLF & Req_Body;
               Max_Reply : constant Positive := Rail_Config_Pkg.Max_Reply_Of (Conf);
               Reply_Buf : Text_Access := new String (1 .. Max_Reply);
               Reply_Len : Natural;
               Reached, Timed_Out, Over_Bound, Closed_Clean : Boolean;
               Http_Ok, Content_Ok, Complete_Ok, Truncated_Ok, Decoded_Ok : Boolean := False;
            begin
               Rail_Socket_Edge.Exchange
                 (Host            => Host,
                  Port            => Rail_Config_Pkg.Port_Of (Conf),
                  Request         => Request,
                  Timeout_Seconds => Rail_Config_Pkg.Timeout_Of (Conf),
                  Max_Reply       => Max_Reply,
                  Until_Line_Feed => False,
                  Reply           => Reply_Buf.all,
                  Reply_Len       => Reply_Len,
                  Reached         => Reached,
                  Timed_Out       => Timed_Out,
                  Over_Bound      => Over_Bound,
                  Complete        => Closed_Clean);

               if Closed_Clean then
                  declare
                     R : constant String (1 .. Reply_Len) := Reply_Buf (1 .. Reply_Len);
                  begin
                     Http_Ok := Http_Reply_Pkg.Is_Usable (R);
                     --  SLOT BEGIN (http-detail)
                     if not Http_Ok then
                        --  Lineage 8: keep what the server said -- its status line (to the first CR or LF, at most 80
                        --  characters) and up to 256 bytes of its body -- so "model not found" is not just http_error.
                        declare
                           Stop  : Natural := Natural'Min (R'Last, 80);
                           First : constant Natural := Http_Reply_Pkg.Body_First (R);
                        begin
                           for I in 1 .. Natural'Min (R'Last, 80) loop
                              if R (I) = Http_Reply_Pkg.CR or else R (I) = Http_Reply_Pkg.LF then
                                 Stop := I - 1;
                                 exit;
                              end if;
                           end loop;
                           Http_Detail := Ada.Strings.Unbounded.To_Unbounded_String (R (1 .. Stop));
                           if First /= 0 and then First <= R'Last then
                              Ada.Strings.Unbounded.Append
                                (Http_Detail, "; body: " & R (First .. Natural'Min (R'Last, First + 255)));
                           end if;
                        end;
                     end if;
                     --  SLOT END (http-detail)
                     if Http_Ok then
                        declare
                           Payload : constant String (1 .. R'Last - Http_Reply_Pkg.Body_First (R) + 1) :=
                             R (Http_Reply_Pkg.Body_First (R) .. R'Last);
                           C       : Json_Scan_Pkg.Span_Type;
                        begin
                           Content_Ok := Model_Reply_Pkg.Has_Content (Payload);
                           Complete_Ok :=
                             (if Is_Ollama then Model_Reply_Pkg.Is_Complete_Ollama (Payload)
                              else Model_Reply_Pkg.Is_Complete_Openai (Payload));
                           Truncated_Ok :=
                             (if Is_Ollama then Model_Reply_Pkg.Is_Truncated_Ollama (Payload)
                              else Model_Reply_Pkg.Is_Truncated_Openai (Payload));
                           if Content_Ok then
                              C := Model_Reply_Pkg.String_Field (Payload, Model_Reply_Pkg.Content_Key);
                              declare
                                 Raw     : constant String (1 .. C.last - C.first + 1) := Payload (C.first .. C.last);
                                 Out_Buf : Text_Access := new String (1 .. Raw'Length);
                                 Out_Len : Natural;
                              begin
                                 Json_String_Pkg.Decode (Raw, Out_Buf.all, Out_Len, Decoded_Ok);
                                 if Decoded_Ok then
                                    Text := new String'(Out_Buf (1 .. Out_Len));
                                 end if;
                                 Free (Out_Buf);
                              exception
                                 when others =>
                                    Free (Out_Buf);
                                    raise;
                              end;
                           end if;
                        end;
                     end if;
                  end;
               end if;

         F.reached := Reached;
         F.timed_out := Timed_Out;
         F.over_bound := Over_Bound;
         F.http_usable := Http_Ok;
         F.truncated := Truncated_Ok;
         F.content_present := Content_Ok;
         F.complete := Complete_Ok;
         F.decoded_ok := Decoded_Ok;
               Free (Reply_Buf);
            exception
               when others =>
                  Free (Reply_Buf);
                  raise;
            end;
         end if;
         Free (Enc);
      exception
         when others =>
            Free (Enc);
            raise;
      end;

      --  Lineage 7 (Tony 2026-09-28 18:05, fix 3): a reply that ran away (blanks, or one character, on and on) is refused
      --  by name. The edge MEASURES the longest run of blanks and the longest run of one repeated character over the
      --  decoded reply, whether or not the model was cut at max_tokens; the admitted Reply_Runaway_Pkg decides.
      if Text /= null then
         declare
            Cur_Blank : Natural := 0;
            Cur_Same  : Natural := 0;
            Prev      : Character := ASCII.NUL;
         begin
            for C of Text.all loop
               if Reply_Runaway_Pkg.Is_Blank (C) then
                  Cur_Blank := Cur_Blank + 1;
               else
                  Cur_Blank := 0;
               end if;
               if Cur_Same > 0 and then C = Prev then
                  Cur_Same := Cur_Same + 1;
               else
                  Cur_Same := 1;
               end if;
               Prev := C;
               if Cur_Blank > Blank_Run then
                  Blank_Run := Cur_Blank;
               end if;
               if Cur_Same > Same_Run then
                  Same_Run := Cur_Same;
               end if;
            end loop;
         end;
         Runaway := Reply_Runaway_Pkg.Is_Runaway (Blank_Run, Same_Run);
         if Runaway then
            Say ("{""rail"":""model"",""refused"":""reply_runaway"",""reply_bytes"":""" & Img (Text.all'Length) &
                 """,""longest_blank_run"":""" & Img (Blank_Run) &
                 """,""longest_same_run"":""" & Img (Same_Run) & """}");
            Refusal := Ada.Strings.Unbounded.To_Unbounded_String
              ("reply_runaway (longest blank run " & Img (Blank_Run) & ", longest run of one character " & Img (Same_Run) &
               ", reply " & Img (Text.all'Length) & " bytes)");
         end if;
      end if;
      Outcome := Model_Reply_Pkg.Decide (F);
      if not Model_Reply_Pkg.Is_Text (Outcome) then
         Text := null;
      end if;
      --  Lineage 7: a runaway reply is never text, whatever the other facts said (a cut at max_tokens included).
      if Runaway then
         Text := null;
         Outcome := Model_Reply_Pkg.Reply_Unreadable;
      end if;
      --  SLOT BEGIN (outcome-notes)
      --  Lineage 8: a non-text outcome this call did not already say is said now, with the server's words when it gave
      --  any (audit item 9); the caller gets those words, and a note when the rail log is incomplete (audit item 8).
      if not Model_Reply_Pkg.Is_Text (Outcome) and then not Said_This_Call then
         Say ("{""rail"":""model"",""outcome"":""" &
              Ada.Characters.Handling.To_Lower (Model_Reply_Pkg.Outcome_Kind'Image (Outcome)) & """" &
              (if Ada.Strings.Unbounded.Length (Http_Detail) > 0
               then ",""http"":""" & Json_Text (Ada.Strings.Unbounded.To_String (Http_Detail)) & """" else "") & "}");
      end if;
      if not Model_Reply_Pkg.Is_Text (Outcome) and then Ada.Strings.Unbounded.Length (Http_Detail) > 0
        and then Ada.Strings.Unbounded.Length (Refusal) = 0
      then
         Refusal := Ada.Strings.Unbounded.To_Unbounded_String
           (Ada.Characters.Handling.To_Lower (Model_Reply_Pkg.Outcome_Kind'Image (Outcome)) & " (" &
            Ada.Strings.Unbounded.To_String (Http_Detail) & ")");
      end if;
      if Say_Unwritten then
         Refusal := Ada.Strings.Unbounded.To_Unbounded_String
           ((if Ada.Strings.Unbounded.Length (Refusal) > 0 then Ada.Strings.Unbounded.To_String (Refusal)
             else Ada.Characters.Handling.To_Lower (Model_Reply_Pkg.Outcome_Kind'Image (Outcome))) &
            "; model-rail log unwritten (state/model-rail.jsonl)");
      end if;
      --  SLOT END (outcome-notes)
   exception
      when others =>
         --  Anything unexpected is never text: the facts gathered so far are judged as they stand.
         Outcome := Model_Reply_Pkg.Decide (F);
         Text := null;
         if Model_Reply_Pkg.Is_Text (Outcome) then
            Outcome := Model_Reply_Pkg.Reply_Unreadable;
         end if;
   end Complete;

   procedure Complete
     (Prompt  : String;
      Text    : out Text_Access;
      Outcome : out Model_Reply_Pkg.Outcome_Kind)
   is
      Unused : Ada.Strings.Unbounded.Unbounded_String;
   begin
      Complete (Prompt, Text, Outcome, Unused);
   end Complete;

end Model_Rail_Call_Pkg;
