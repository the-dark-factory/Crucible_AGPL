--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1bbbb9310b52a343968fc0d05cffe805cf7ac1aa5ff0877a90be2f47576810b3
--
--  Vacuity_Rail_Call_Pkg body -- template (seat-written plumbing) with TWO slots (request-facts, reply-facts),
--  filled by a Wu edge round. Sibling of the prover rail client edge (wu-crucible-prover-rail-call), whose
--  fixed text this reproduces line for line but for the rail, the request line and the trailer's meaning.
--  Brief BRIEF_crucible_step5a5_vacuity_rail_2026-09-18 (5a-5c-3).
with Ada.Text_IO;
with GNAT.SHA256;
with Json_Scan_Pkg;
with Rail_Config_Pkg;
with Rail_Socket_Edge;
with Sovereign_Gate_Pkg;
with Hex_Text_Pkg;
with Vacuity_Facts_Pkg;

package body Vacuity_Rail_Call_Pkg with SPARK_Mode => Off is

   use type Json_Scan_Pkg.Kind_Type;
   use type Rail_Config_Pkg.Rail_Kind;
   use type Sovereign_Gate_Pkg.Route_Kind;

   Max_Conf_Line : constant := 4096;

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

   --  A count the battery reports outside Vacuity_Facts_Pkg.Count's range is not a fact this rail can carry:
   --  the caller is told so by Valid, never by a silently clamped number.
   procedure Read_Count (Line : String; Key : String; Value : out Vacuity_Facts_Pkg.Count; Valid : out Boolean) is
      N  : Natural := 0;
      Ok : Boolean := False;
   begin
      Value := 0;
      Read_Natural (Line, Key, N, Ok);
      if Ok and then N <= Vacuity_Facts_Pkg.Max_Count then
         Value := N;
         Valid := True;
      else
         Value := 0;
         Valid := False;
      end if;
   end Read_Count;

   procedure Judge_Full
     (Unit_Name : String;
      Spec_Text : String;
      Outcome   : out Vacuity_Rail_Pkg.Outcome_Kind;
      Facts     : out Vacuity_Rail_Pkg.Reply_Facts;
      Grades    : out Text_Access)
   is
      Request : Vacuity_Rail_Pkg.Request_Facts;
      Reply   : Vacuity_Rail_Pkg.Reply_Facts;

      Conf_Buf : String (1 .. Max_Conf_Line);
      Conf_Len : Natural := 0;
      Found    : Boolean := False;   --  a valid rail line whose rail is "vacuity" was read
   begin
      Grades := new String'("");
      --  Configuration: ONLY from the file; the first VALID vacuity line (Rail_Config_Pkg judges validity).
      declare
         F : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Conf_Path);
         while not Found and then not Ada.Text_IO.End_Of_File (F) loop
            declare
               L : constant String := Ada.Text_IO.Get_Line (F);
               L1 : constant String (1 .. L'Length) := L;
            begin
               if L1'Length <= Max_Conf_Line
                 and then Rail_Config_Pkg.Is_Valid (L1)
                 and then Rail_Config_Pkg.Rail_Of (L1) = Rail_Config_Pkg.Rail_Vacuity
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

      declare
         Conf       : constant String (1 .. Conf_Len) := Conf_Buf (1 .. Conf_Len);
         Host       : constant String :=
           (if Found then Conf (Rail_Config_Pkg.Host_Span (Conf).first .. Rail_Config_Pkg.Host_Span (Conf).last) else "");
         Endpoint   : constant String := "http://" & Host;
         Endpoint_1 : constant String (1 .. Endpoint'Length) := Endpoint;
         Sovereign  : constant Boolean := Found and then Rail_Config_Pkg.Sovereign_Of (Conf);
         On_Estate  : constant Boolean :=
           Found and then Endpoint_1'Length <= Sovereign_Gate_Pkg.Max_Endpoint
           and then Sovereign_Gate_Pkg.Route_Of (Endpoint_1, Sovereign) = Sovereign_Gate_Pkg.On_Estate;
         Unit_Bytes : constant Natural := Spec_Text'Length;
         Digest     : GNAT.SHA256.Message_Digest;
      begin
         --  The vacuity rail measures a SPECIFICATION: the digest is over the spec alone, and the request's
         --  body_hex is empty. The service digests the same bytes, so digest_matches is a real check.
         declare
            Ctx : GNAT.SHA256.Context := GNAT.SHA256.Initial_Context;
         begin
            GNAT.SHA256.Update (Ctx, Spec_Text);
            Digest := GNAT.SHA256.Digest (Ctx);
         end;

         --  SLOT BEGIN (request-facts)
Request.rail_is_vacuity := Found;
Request.endpoint_on_estate := On_Estate;
Request.unit_bytes := Unit_Bytes;
Request.max_unit_bytes := Max_Unit_Bytes;
         --  SLOT END (request-facts)

         if Vacuity_Rail_Pkg.May_Send (Request) then
            declare
               Max_Reply : constant Positive := Rail_Config_Pkg.Max_Reply_Of (Conf);
               Reply_Buf : constant Text_Access := new String (1 .. Max_Reply);
               Reply_Len : Natural;
               Reached, Timed_Out, Over_Bound, Complete : Boolean;
               Line : constant String :=
                 "{""unit"":""" & Unit_Name & """,""level"":""2""" &
                 ",""digest"":""" & Digest &
                 """,""spec_hex"":""" & Hex_Text_Pkg.Encode (Spec_Text) &
                 """,""body_hex"":""""}" & Character'Val (10);
            begin
               Rail_Socket_Edge.Exchange
                 (Host            => Host,
                  Port            => Rail_Config_Pkg.Port_Of (Conf),
                  Request         => Line,
                  Timeout_Seconds => Rail_Config_Pkg.Timeout_Of (Conf),
                  Max_Reply       => Max_Reply,
                  Until_Line_Feed => False,   --  read to the service's close; the line ends at the first LF
                  Reply           => Reply_Buf.all,
                  Reply_Len       => Reply_Len,
                  Reached         => Reached,
                  Timed_Out       => Timed_Out,
                  Over_Bound      => Over_Bound,
                  Complete        => Complete);
               Reply.connected := Reached;
               Reply.timed_out := Timed_Out;

               --  The stream is the reply LINE (up to the first line feed) followed by the raw grade lines the
               --  service sent after it. A stream without a line feed holds no complete reply line. The line is
               --  judged exactly as the prover rail's is; the trailer never touches Reply.
               declare
                  LF       : constant Character := Character'Val (10);
                  Line_End : Natural := 0;
               begin
                  for I in 1 .. Reply_Len loop
                     if Reply_Buf (I) = LF then
                        Line_End := I;
                        exit;
                     end if;
                  end loop;
                  Reply.reply_complete := Complete and then Line_End > 0;

                  if Reply.reply_complete and then Line_End - 1 <= 65_536 then
                     declare
                        R : constant String (1 .. Line_End - 1) := Reply_Buf (1 .. Line_End - 1);
                        Err, Rd, Gr, Def, Dec, Pr, Th, Ro, Un, Rf : Vacuity_Facts_Pkg.Count := 0;
                        Err_Ok, Rd_Ok, Gr_Ok, Def_Ok, Dec_Ok, Pr_Ok : Boolean := False;
                        Th_Ok, Ro_Ok, Un_Ok, Rf_Ok : Boolean := False;
                        N     : Natural := 0;
                        N_Ok  : Boolean := False;
                        Lines : Natural := 0;
                     begin
                        Read_Count (R, "error_count", Err, Err_Ok);
                        Read_Count (R, "functions_read", Rd, Rd_Ok);
                        Read_Count (R, "functions_graded", Gr, Gr_Ok);
                        Read_Count (R, "definitions_only", Def, Def_Ok);
                        Read_Count (R, "postconditions_declared", Dec, Dec_Ok);
                        Read_Count (R, "postconditions_read", Pr, Pr_Ok);
                        Read_Count (R, "theorem_count", Th, Th_Ok);
                        Read_Count (R, "runtime_only_count", Ro, Ro_Ok);
                        Read_Count (R, "unexercised_count", Un, Un_Ok);
                        Read_Count (R, "refused_count", Rf, Rf_Ok);
                        --  SLOT BEGIN (reply-facts)
Reply.reply_well_formed := Is_Present (R, "digest") and then Is_Present (R, "battery") and then Is_Present (R, "battery_ran") and then Is_Present (R, "refusal_present") and then Is_Present (R, "refusal") and then Err_Ok and then Rd_Ok and then Gr_Ok and then Def_Ok and then Dec_Ok and then Pr_Ok and then Th_Ok and then Ro_Ok and then Un_Ok and then Rf_Ok;
Reply.digest_matches := Value_Text (R, "digest") = Digest;
Reply.battery_identified := Value_Text (R, "battery") = "check-cores-mcp";
Reply.facts.battery_ran := Value_Text (R, "battery_ran") = "true";
Reply.facts.refusal_present := Value_Text (R, "refusal_present") = "true";
Reply.facts.error_count := Err;
Reply.facts.functions_read := Rd;
Reply.facts.functions_graded := Gr;
Reply.facts.definitions_only := Def;
Reply.facts.postconditions_declared := Dec;
Reply.facts.postconditions_read := Pr;
Reply.facts.theorem_count := Th;
Reply.facts.runtime_only_count := Ro;
Reply.facts.unexercised_count := Un;
Reply.facts.refused_count := Rf;
                        --  SLOT END (reply-facts)

                        --  Grades: kept only when the declared count and the complete lines received agree.
                        Read_Natural (R, "grade_lines", N, N_Ok);
                        for I in Line_End + 1 .. Reply_Len loop
                           if Reply_Buf (I) = LF then
                              Lines := Lines + 1;
                           end if;
                        end loop;
                        if N_Ok and then Lines = N
                          and then (Reply_Len = Line_End or else Reply_Buf (Reply_Len) = LF)
                        then
                           Grades := new String'(Reply_Buf (Line_End + 1 .. Reply_Len));
                        end if;
                     end;
                  end if;
               end;
            end;
         end if;
      end;

      Facts := Reply;
      Outcome := Vacuity_Rail_Pkg.Decide (Request, Reply);
   exception
      when others =>
         --  Anything unexpected is never a pass: the facts gathered so far are judged as they stand.
         Facts := Reply;
         Outcome := Vacuity_Rail_Pkg.Decide (Request, Reply);
         Grades := new String'("");
   end Judge_Full;

   function Judge
     (Unit_Name : String;
      Spec_Text : String) return Vacuity_Rail_Pkg.Outcome_Kind
   is
      Outcome : Vacuity_Rail_Pkg.Outcome_Kind;
      Facts   : Vacuity_Rail_Pkg.Reply_Facts;
      Grades  : Text_Access;
   begin
      Judge_Full (Unit_Name, Spec_Text, Outcome, Facts, Grades);
      return Outcome;
   end Judge;

end Vacuity_Rail_Call_Pkg;
