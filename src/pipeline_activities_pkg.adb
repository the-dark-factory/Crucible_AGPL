--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: c1fa34f463b948eb55ca4cc343439af954e0175ea6fc85d58b21ef04c40709f0
--
--  Pipeline_Activities_Pkg body -- template (seat-written plumbing) with TWO slots (intake_result, prove_result), filled
--  by a Wu edge round. Brief BRIEF_crucible_step4_wiring_2026-09-17 (4c unit 3).
--  SLOT BEGIN (context)
with Ada.Unchecked_Deallocation;
--  SLOT END (context)
with Ada.Text_IO;
with Ada.Characters.Handling;
with Json_String_Pkg;
with Intake_Line_Pkg;
with Intake_Measure_Pkg;
with Intake_Refusal_Pkg;
with Prover_Rail_Pkg;
with Prover_Rail_Call_Pkg;
with Stage_Outcome_Map_Pkg;

package body Pipeline_Activities_Pkg with SPARK_Mode => Off is

   use Ada.Strings.Unbounded;

   type Sheet_Access is access Intake_Measure_Pkg.Sheet;

   function Img (N : Natural) return String is
      T : constant String := Natural'Image (N);
   begin
      return T (T'First + 1 .. T'Last);
   end Img;

   function Lower (S : String) return String renames Ada.Characters.Handling.To_Lower;

   procedure Run_Intake
     (Sheet  : String;
      Result : out Pipeline_Stage_Pkg.Outcome;
      Reason : out Unbounded_String)
   is
      S         : constant Sheet_Access := new Intake_Measure_Pkg.Sheet;
      Count     : Intake_Measure_Pkg.Line_Count := 0;
      Start     : Positive := Sheet'First;
      Fits      : Boolean := True;
      May_Forge : Boolean := False;
   begin
      S.Count := 0;
      for I in Intake_Measure_Pkg.Line_Index loop
         S.Lines (I).Len := 0;
      end loop;
      --  Split on line feeds into the bounded sheet; a sheet that does not fit is refused, never measured on a prefix.
      for P in Sheet'First .. Sheet'Last + 1 loop
         exit when not Fits;
         if P = Sheet'Last + 1 or else Sheet (P) = Json_String_Pkg.LF then
            if P > Start or else P <= Sheet'Last then
               declare
                  Text  : constant String := Sheet (Start .. P - 1);
                  Blank : Boolean := True;
               begin
                  for C of Text loop
                     if not Intake_Line_Pkg.Is_Space (C) then
                        Blank := False;
                     end if;
                  end loop;
                  if Text'Length > Intake_Line_Pkg.Max_Line then
                     Fits := False;
                  elsif not Blank then
                     if Count = Intake_Measure_Pkg.Max_Lines then
                        Fits := False;
                     else
                        Count := Count + 1;
                        S.Lines (Count).Text (1 .. Text'Length) := Text;
                        S.Lines (Count).Len := Text'Length;
                     end if;
                  end if;
               end;
            end if;
            Start := P + 1;
         end if;
      end loop;
      S.Count := Count;

      if Fits then
         declare
            V : constant Intake_Refusal_Pkg.Verdict_Type :=
              Intake_Refusal_Pkg.Assemble (Intake_Measure_Pkg.Measure (S.all));
         begin
            May_Forge := V.may_forge;
            Reason := To_Unbounded_String
              ((if V.may_forge then "may_forge" else "refused: gaps=" & Img (V.gap_count)) &
               " operations=" & Img (V.operation_count));
         end;
      else
         Reason := To_Unbounded_String ("input_refused: sheet does not fit");
      end if;

Result := Stage_Outcome_Map_Pkg.From_Verdict (May_Forge);
   end Run_Intake;

   procedure Run_Prove
     (Unit_Name : String;
      Spec_Text : String;
      Body_Text : String;
      Level     : Natural;
      Result    : out Pipeline_Stage_Pkg.Outcome;
      Reason    : out Unbounded_String)
   is
      O : constant Prover_Rail_Pkg.Outcome_Kind := Prover_Rail_Call_Pkg.Prove (Unit_Name, Spec_Text, Body_Text, Level);
   begin
      Reason := To_Unbounded_String (Lower (Prover_Rail_Pkg.Outcome_Kind'Image (O)));
Result := Stage_Outcome_Map_Pkg.From_Prover (O);
   end Run_Prove;

   procedure Run_Owed
     (Result : out Pipeline_Stage_Pkg.Outcome;
      Reason : out Unbounded_String)
   is
   begin
      Result := Pipeline_Stage_Pkg.Unmeasured_Here;
      Reason := To_Unbounded_String ("stage owed");
   end Run_Owed;

   procedure Audit
     (Ledger : in out Audit_Ledger_Pkg.Ledger;
      Seq    : Natural;
      S      : Pipeline_Stage_Pkg.Stage;
      O      : Pipeline_Stage_Pkg.Outcome;
      Reason : String)
   is
      Code    : constant Natural := Stage_Outcome_Map_Pkg.Audit_Code (S, O);
      R1      : constant String (1 .. Reason'Length) := Reason;
      --  SLOT BEGIN (encode-buffer)
      type Buf_Access is access String;
      procedure Free is new Ada.Unchecked_Deallocation (String, Buf_Access);
      Enc     : Buf_Access := new String (1 .. Natural'Max (1, 6 * R1'Length));
      --  SLOT END (encode-buffer)
      Enc_Len : Natural;
      Enc_Ok  : Boolean;
      F       : Ada.Text_IO.File_Type;
   begin
      Ledger := Audit_Ledger_Pkg.Appended
        (Ledger, (Source => Audit_Ledger_Pkg.Door_Listener, Code => Audit_Ledger_Pkg.Event_Code (Code)));
      --  SLOT BEGIN (encode-call)
      Json_String_Pkg.Encode (R1, Enc.all, Enc_Len, Enc_Ok);
      --  SLOT END (encode-call)
      begin
         Ada.Text_IO.Open (F, Ada.Text_IO.Append_File, Audit_Path);
      exception
         when Ada.Text_IO.Name_Error =>
            Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, Audit_Path);
      end;
      Ada.Text_IO.Put_Line
        (F, "{""seq"":""" & Img (Seq) & """,""stage"":""" & Lower (Pipeline_Stage_Pkg.Stage'Image (S)) &
            """,""outcome"":""" & Lower (Pipeline_Stage_Pkg.Outcome'Image (O)) & """,""code"":""" & Img (Code) &
            """,""reason"":""" & (if Enc_Ok then Enc (1 .. Enc_Len) else "unencodable") & """}");
      Ada.Text_IO.Close (F);
      --  SLOT BEGIN (release)
      Free (Enc);
      --  SLOT END (release)
   exception
      when others =>
         --  SLOT BEGIN (release-on-failure)
         Free (Enc);
         --  SLOT END (release-on-failure)
         null;  --  the in-memory ledger entry stands; a file failure never changes a stage outcome
   end Audit;

end Pipeline_Activities_Pkg;
