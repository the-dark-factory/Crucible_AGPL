--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 0d7ce346462f73d45dab06a31ab84636007ed4edb2f2be1f3f776e2605e9d993
--
with Json_Scan_Pkg;

package Model_Reply_Pkg with SPARK_Mode is

   use type Json_Scan_Pkg.Kind_Type;

   Content_Key       : constant String := "content";
   Done_Key          : constant String := "done";
   Done_Reason_Key   : constant String := "done_reason";
   Finish_Reason_Key : constant String := "finish_reason";
   Stop_Word         : constant String := "stop";
   Length_Word       : constant String := "length";
   True_Word         : constant String := "true";
   Max_Body          : constant := 1_048_576;

   No_Span : constant Json_Scan_Pkg.Span_Type := (found => False, kind => Json_Scan_Pkg.K_None, first => 0, last => 0);

   type Outcome_Kind is (Model_Not_Sent, Model_Unreachable, Model_Timeout, Reply_Over_Bound, Http_Error,
                         Reply_Unreadable, Truncated, Model_Text);

   type Facts_Type is record
      sent            : Boolean := False;
      reached         : Boolean := False;
      timed_out       : Boolean := False;
      over_bound      : Boolean := False;
      http_usable     : Boolean := False;
      truncated       : Boolean := False;
      content_present : Boolean := False;
      complete        : Boolean := False;
      decoded_ok      : Boolean := False;
   end record;

   function String_Field (Payload : String; Key : String) return Json_Scan_Pkg.Span_Type is
     ((if Json_Scan_Pkg.Value_Span (Payload, Key).found
          and then Json_Scan_Pkg.Value_Span (Payload, Key).kind = Json_Scan_Pkg.K_String
          and then Json_Scan_Pkg.Value_Span (Payload, Key).first < Json_Scan_Pkg.Value_Span (Payload, Key).last
       then Json_Scan_Pkg.String_Contents (Payload, Json_Scan_Pkg.Value_Span (Payload, Key))
       else No_Span))
     with Pre  => Payload'First = 1 and then Payload'Length <= Max_Body and then Key'First = 1 and then Key'Length in 1 .. 64,
          Post => (if String_Field'Result.found then String_Field'Result.first in Payload'Range and then String_Field'Result.last in Payload'Range and then String_Field'Result.first - 1 <= String_Field'Result.last);

   function Is_Stop (Payload : String; Key : String) return Boolean is
     (String_Field (Payload, Key).found and then Json_Scan_Pkg.Equals_Literal (Payload, String_Field (Payload, Key), Stop_Word))
     with Pre  => Payload'First = 1 and then Payload'Length <= Max_Body and then Key'First = 1 and then Key'Length in 1 .. 64,
          Post => (Is_Stop'Result = (String_Field (Payload, Key).found
             and then Json_Scan_Pkg.Equals_Literal (Payload, String_Field (Payload, Key), Stop_Word)));

   function Done_True (Payload : String) return Boolean is
     (Json_Scan_Pkg.Value_Span (Payload, Done_Key).found
      and then Json_Scan_Pkg.Value_Span (Payload, Done_Key).kind = Json_Scan_Pkg.K_Bare
      and then Json_Scan_Pkg.Equals_Literal (Payload, Json_Scan_Pkg.Value_Span (Payload, Done_Key), True_Word))
     with Pre  => Payload'First = 1 and then Payload'Length <= Max_Body,
          Post => (Done_True'Result = (Json_Scan_Pkg.Value_Span (Payload, Done_Key).found
             and then Json_Scan_Pkg.Value_Span (Payload, Done_Key).kind = Json_Scan_Pkg.K_Bare
             and then Json_Scan_Pkg.Equals_Literal (Payload, Json_Scan_Pkg.Value_Span (Payload, Done_Key), True_Word)));

   function Is_Complete_Ollama (Payload : String) return Boolean is
     (Done_True (Payload) and then Is_Stop (Payload, Done_Reason_Key))
     with Pre  => Payload'First = 1 and then Payload'Length <= Max_Body,
          Post => (Is_Complete_Ollama'Result = (Done_True (Payload) and then Is_Stop (Payload, Done_Reason_Key)));

   function Is_Complete_Openai (Payload : String) return Boolean is
     (Is_Stop (Payload, Finish_Reason_Key))
     with Pre  => Payload'First = 1 and then Payload'Length <= Max_Body,
          Post => (Is_Complete_Openai'Result = Is_Stop (Payload, Finish_Reason_Key));

   function Is_Truncated_Ollama (Payload : String) return Boolean is
     (String_Field (Payload, Done_Reason_Key).found
      and then Json_Scan_Pkg.Equals_Literal (Payload, String_Field (Payload, Done_Reason_Key), Length_Word))
     with Pre  => Payload'First = 1 and then Payload'Length <= Max_Body,
          Post => (Is_Truncated_Ollama'Result = (String_Field (Payload, Done_Reason_Key).found
             and then Json_Scan_Pkg.Equals_Literal (Payload, String_Field (Payload, Done_Reason_Key), Length_Word)));

   function Is_Truncated_Openai (Payload : String) return Boolean is
     (String_Field (Payload, Finish_Reason_Key).found
      and then Json_Scan_Pkg.Equals_Literal (Payload, String_Field (Payload, Finish_Reason_Key), Length_Word))
     with Pre  => Payload'First = 1 and then Payload'Length <= Max_Body,
          Post => (Is_Truncated_Openai'Result = (String_Field (Payload, Finish_Reason_Key).found
             and then Json_Scan_Pkg.Equals_Literal (Payload, String_Field (Payload, Finish_Reason_Key), Length_Word)));

   function Has_Content (Payload : String) return Boolean is
     (String_Field (Payload, Content_Key).found and then String_Field (Payload, Content_Key).first <= String_Field (Payload, Content_Key).last)
     with Pre  => Payload'First = 1 and then Payload'Length <= Max_Body,
          Post => (Has_Content'Result = (String_Field (Payload, Content_Key).found and then String_Field (Payload, Content_Key).first <= String_Field (Payload, Content_Key).last));

   function Decide (F : Facts_Type) return Outcome_Kind is
     (if not F.sent then Model_Not_Sent
      elsif not F.reached then Model_Unreachable
      elsif F.timed_out then Model_Timeout
      elsif F.over_bound then Reply_Over_Bound
      elsif not F.http_usable then Http_Error
      elsif F.truncated then Truncated
      elsif not F.content_present then Reply_Unreadable
      elsif not F.complete then Reply_Unreadable
      elsif not F.decoded_ok then Reply_Unreadable
      else Model_Text)
     with Post => (((Decide'Result = Model_Text) = (F.sent and then F.reached and then not F.timed_out and then not F.over_bound
        and then F.http_usable and then not F.truncated and then F.content_present and then F.complete
        and then F.decoded_ok))
     and then (if not F.sent then Decide'Result = Model_Not_Sent)
     and then (if F.sent and then not F.reached then Decide'Result = Model_Unreachable)
     and then (if F.sent and then F.reached and then F.timed_out then Decide'Result = Model_Timeout)
     and then ((Decide'Result = Truncated) = (F.sent and then F.reached and then not F.timed_out
        and then not F.over_bound and then F.http_usable and then F.truncated)));

   function Is_Text (O : Outcome_Kind) return Boolean is
     (O = Model_Text)
     with Post => (Is_Text'Result = (O = Model_Text));

end Model_Reply_Pkg;
