--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: cfb33617e6ece2824141d5c4458ff0a0c6bce65e0bde37e41d0a521d12226561
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

   procedure Say (Row : String) is
      F : Ada.Text_IO.File_Type;
   begin
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
      when others =>
         null;   --  a file failure never changes the rail outcome
   end Say;

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
   begin
      Text := null;
      Refusal := Ada.Strings.Unbounded.Null_Unbounded_String;

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

         --  SLOT BEGIN (sent_fact)
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
         --  SLOT END (sent_fact)

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

      Outcome := Model_Reply_Pkg.Decide (F);
      if not Model_Reply_Pkg.Is_Text (Outcome) then
         Text := null;
      end if;
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
