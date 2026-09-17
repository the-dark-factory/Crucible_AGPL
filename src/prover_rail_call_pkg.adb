--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 013cb12640ee56b5a4d18935ad3117fc10d9e6b40684a2555278ec80cd0f8578
--
--  Prover_Rail_Call_Pkg body -- template (seat-written plumbing) with TWO slots (request-facts, reply-facts),
--  filled by a Wu edge round; the slot prose is the prover rail client edge's, whose fills passed its probes.
--  Brief BRIEF_crucible_step4_wiring_2026-09-17 (4b unit 3).
with Ada.Text_IO;
with GNAT.SHA256;
with Json_Scan_Pkg;
with Rail_Config_Pkg;
with Rail_Socket_Edge;
with Sovereign_Gate_Pkg;
with Hex_Text_Pkg;
with Prover_Verdict_Pkg;

package body Prover_Rail_Call_Pkg with SPARK_Mode => Off is

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

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

   function Prove
     (Unit_Name : String;
      Spec_Text : String;
      Body_Text : String;
      Level     : Natural) return Prover_Rail_Pkg.Outcome_Kind
   is
      Request : Prover_Rail_Pkg.Request_Facts;
      Reply   : Prover_Rail_Pkg.Reply_Facts;

      Conf_Buf : String (1 .. Max_Conf_Line);
      Conf_Len : Natural := 0;
      Found    : Boolean := False;   --  a valid rail line whose rail is "prover" was read
   begin
      --  Configuration: ONLY from the file; the first VALID prover line (Rail_Config_Pkg judges validity).
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
                 and then Rail_Config_Pkg.Rail_Of (L1) = Rail_Config_Pkg.Rail_Prover
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
         Unit_Bytes : constant Natural := Spec_Text'Length + Body_Text'Length;
         Digest     : GNAT.SHA256.Message_Digest;
      begin
         declare
            Ctx : GNAT.SHA256.Context := GNAT.SHA256.Initial_Context;
         begin
            GNAT.SHA256.Update (Ctx, Spec_Text);
            GNAT.SHA256.Update (Ctx, Body_Text);
            Digest := GNAT.SHA256.Digest (Ctx);
         end;

         --  SLOT BEGIN (request-facts)
      Request.rail_is_prover := Found;
      Request.endpoint_on_estate := On_Estate;
      Request.unit_bytes := Unit_Bytes;
      Request.max_unit_bytes := Max_Unit_Bytes;
      Request.level_demanded := Level;
         --  SLOT END (request-facts)

         if Prover_Rail_Pkg.May_Send (Request) then
            declare
               Max_Reply : constant Positive := Rail_Config_Pkg.Max_Reply_Of (Conf);
               type Text_Access is access String;
               Reply_Buf : constant Text_Access := new String (1 .. Max_Reply);
               Reply_Len : Natural;
               Reached, Timed_Out, Over_Bound, Complete : Boolean;
               Line : constant String :=
                 "{""unit"":""" & Unit_Name & """,""level"":""" & Img (Level) &
                 """,""digest"":""" & Digest & """,""spec_hex"":""" & Hex_Text_Pkg.Encode (Spec_Text) &
                 """,""body_hex"":""" & Hex_Text_Pkg.Encode (Body_Text) & """}" & Character'Val (10);
            begin
               Rail_Socket_Edge.Exchange
                 (Host            => Host,
                  Port            => Rail_Config_Pkg.Port_Of (Conf),
                  Request         => Line,
                  Timeout_Seconds => Rail_Config_Pkg.Timeout_Of (Conf),
                  Max_Reply       => Max_Reply,
                  Until_Line_Feed => True,
                  Reply           => Reply_Buf.all,
                  Reply_Len       => Reply_Len,
                  Reached         => Reached,
                  Timed_Out       => Timed_Out,
                  Over_Bound      => Over_Bound,
                  Complete        => Complete);
               Reply.connected := Reached;
               Reply.timed_out := Timed_Out;
               Reply.reply_complete := Complete;

               if Complete and then Reply_Len <= 1_048_576 then
                  declare
                     R : constant String (1 .. Reply_Len) := Reply_Buf (1 .. Reply_Len);
                     Lvl, Gen, Unp, Jus, Skp : Natural := 0;
                     Lvl_Ok, Gen_Ok, Unp_Ok, Jus_Ok, Skp_Ok : Boolean := False;
                  begin
                     Read_Natural (R, "level_run_at", Lvl, Lvl_Ok);
                     Read_Natural (R, "checks_generated", Gen, Gen_Ok);
                     Read_Natural (R, "checks_unproved", Unp, Unp_Ok);
                     Read_Natural (R, "checks_justified", Jus, Jus_Ok);
                     Read_Natural (R, "subprograms_skipped", Skp, Skp_Ok);
                     --  SLOT BEGIN (reply-facts)
      Reply.reply_well_formed := Is_Present (R, "digest") and then
        Is_Present (R, "prover") and then
        Is_Present (R, "prover_version") and then
        Is_Present (R, "prover_ran") and then
        Is_Present (R, "prover_exited_cleanly") and then
        Is_Present (R, "unit_compiled") and then
        Lvl_Ok and then Gen_Ok and then Unp_Ok and then Jus_Ok and then Skp_Ok;
      Reply.subprograms_skipped := Skp;
      Reply.digest_matches := Value_Text (R, "digest") = Digest;
      Reply.prover_identified := Value_Text (R, "prover") = "gnatprove" and then
        Value_Text (R, "prover_version")'Length > 0;
      Reply.run.prover_ran := Value_Text (R, "prover_ran") = "true";
      Reply.run.prover_exited_cleanly := Value_Text (R, "prover_exited_cleanly") = "true";
      Reply.run.unit_compiled := Value_Text (R, "unit_compiled") = "true";
      Reply.run.level_run_at := Lvl;
      Reply.run.checks_generated := Gen;
      Reply.run.checks_unproved := Unp;
      Reply.run.checks_justified := Jus;
      Reply.run.level_demanded := Request.level_demanded;
                     --  SLOT END (reply-facts)
                  end;
               end if;
            end;
         end if;
      end;

      return Prover_Rail_Pkg.Decide (Request, Reply);
   exception
      when others =>
         --  Anything unexpected is never a pass: the facts gathered so far are judged as they stand.
         return Prover_Rail_Pkg.Decide (Request, Reply);
   end Prove;

end Prover_Rail_Call_Pkg;
