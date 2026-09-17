--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: e9809840b99bc95175035c9c3bf0c9d6050792dd3c57f35ec8ff46d88fcec1a9
--
--  Model_Rail_Call_Pkg body -- template (seat-written plumbing) with TWO slots (sent_fact, reply_facts), filled by a
--  Wu edge round. Brief BRIEF_crucible_step4_wiring_2026-09-17 (step 5 unit 5).
with Ada.Text_IO;
with Json_Scan_Pkg;
with Json_String_Pkg;
with Rail_Config_Pkg;
with Model_Rail_Fields_Pkg;
with Model_Request_Pkg;
with Http_Reply_Pkg;
with Rail_Socket_Edge;
with Sovereign_Gate_Pkg;

package body Model_Rail_Call_Pkg with SPARK_Mode => Off is

   use type Rail_Config_Pkg.Rail_Kind;
   use type Model_Rail_Fields_Pkg.Protocol_Kind;
   use type Sovereign_Gate_Pkg.Route_Kind;

   Max_Conf_Line : constant := 4096;
   CRLF          : constant String := Character'Val (13) & Character'Val (10);

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

   procedure Complete
     (Prompt  : String;
      Text    : out Text_Access;
      Outcome : out Model_Reply_Pkg.Outcome_Kind)
   is
      F        : Model_Reply_Pkg.Facts_Type;
      Conf_Buf : String (1 .. Max_Conf_Line);
      Conf_Len : Natural := 0;
      Found    : Boolean := False;   --  a line valid for Rail_Config_Pkg (rail model) AND Model_Rail_Fields_Pkg
   begin
      Text := null;

      declare
         File : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Conf_Path);
         while not Found and then not Ada.Text_IO.End_Of_File (File) loop
            declare
               L  : constant String := Ada.Text_IO.Get_Line (File);
               L1 : constant String (1 .. L'Length) := L;
            begin
               if L1'Length <= Max_Conf_Line
                 and then Rail_Config_Pkg.Is_Valid (L1)
                 and then Rail_Config_Pkg.Rail_Of (L1) = Rail_Config_Pkg.Rail_Model
                 and then Model_Rail_Fields_Pkg.Is_Valid_Model_Line (L1)
               then
                  Conf_Buf (1 .. L1'Length) := L1;
                  Conf_Len := L1'Length;
                  Found := True;
               end if;
            end;
         end loop;
         Ada.Text_IO.Close (File);
      exception
         when others =>
            Found := False;
            Conf_Len := 0;
      end;

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
         Enc        : constant Text_Access := new String (1 .. Natural'Max (1, 2 * P1'Length));
         Enc_Len    : Natural := 0;
         Enc_Ok     : Boolean := False;
      begin
         if Found and then Route_Ok and then Prompt_Ok then
            Json_String_Pkg.Encode (P1, Enc.all, Enc_Len, Enc_Ok);
         end if;

         --  SLOT BEGIN (sent_fact)
F.sent := Found and then Route_Ok and then Prompt_Ok and then Enc_Ok;
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
                 (if Is_Ollama then Model_Request_Pkg.Request_Text (Model_1, Encoded, Model_Rail_Fields_Pkg.Max_Tokens_Of (Conf))
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
               Reply_Buf : constant Text_Access := new String (1 .. Max_Reply);
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
                                 Out_Buf : constant Text_Access := new String (1 .. Raw'Length);
                                 Out_Len : Natural;
                              begin
                                 Json_String_Pkg.Decode (Raw, Out_Buf.all, Out_Len, Decoded_Ok);
                                 if Decoded_Ok then
                                    Text := new String'(Out_Buf (1 .. Out_Len));
                                 end if;
                              end;
                           end if;
                        end;
                     end if;
                  end;
               end if;

               --  SLOT BEGIN (reply_facts)
F.reached := Reached;
F.timed_out := Timed_Out;
F.over_bound := Over_Bound;
F.http_usable := Http_Ok;
F.truncated := Truncated_Ok;
F.content_present := Content_Ok;
F.complete := Complete_Ok;
F.decoded_ok := Decoded_Ok;
               --  SLOT END (reply_facts)
            end;
         end if;
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

end Model_Rail_Call_Pkg;
