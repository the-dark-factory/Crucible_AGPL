--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 5f402c941033b00a1fea9878f2448766eef356099c824b2126af1722c2c5a9dc
--
--  Decompose_Activity_Pkg body -- template (seat-written plumbing) with TWO slots (model_result, design_result), filled
--  by a Wu edge round. Brief BRIEF_crucible_step4_wiring_2026-09-17 (4c unit 3, Decompose).
with Ada.Characters.Handling;
with Model_Reply_Pkg;
with Model_Rail_Call_Pkg;
with Mascot_Scan_Pkg;
with Mascot_Measure_Pkg;
with Mascot_Judge_Pkg;
with Stage_Outcome_Map_Pkg;

package body Decompose_Activity_Pkg with SPARK_Mode => Off is

   use Ada.Strings.Unbounded;

   Think_End : constant String := "</think>";
   LF        : constant Character := Character'Val (10);

   type Set_Access is access Mascot_Scan_Pkg.Line_Set;

   function Lower (S : String) return String renames Ada.Characters.Handling.To_Lower;

   procedure Run_Keeping_Design
     (Brief  : String;
      Result : out Pipeline_Stage_Pkg.Outcome;
      Reason : out Unbounded_String;
      Design : out Unbounded_String)
   is
      Text     : Model_Rail_Call_Pkg.Text_Access;
      O        : Model_Reply_Pkg.Outcome_Kind;
      Accepted : Boolean := False;
   begin
      Design := Null_Unbounded_String;
      Model_Rail_Call_Pkg.Complete (Design_Instruction & Brief, Text, O);

      if not Model_Reply_Pkg.Is_Text (O) then
         Reason := To_Unbounded_String ("model: " & Lower (Model_Reply_Pkg.Outcome_Kind'Image (O)));
         --  SLOT BEGIN (model_result)
Result := Stage_Outcome_Map_Pkg.From_Model (O);
         --  SLOT END (model_result)
         return;
      end if;

      declare
         Raw   : constant String := Text.all;
         Start : Positive := Raw'First;
         Set   : constant Set_Access := new Mascot_Scan_Pkg.Line_Set;
         Fits  : Boolean := True;
      begin
         --  Drop a reasoning section: the design starts after the LAST "</think>", if any.
         for K in Raw'Range loop
            if K + Think_End'Length - 1 <= Raw'Last and then Raw (K .. K + Think_End'Length - 1) = Think_End then
               Start := K + Think_End'Length;
            end if;
         end loop;

         Set.Count := 0;
         for L in Set.Lines'Range loop
            Set.Lines (L).Len := 0;
         end loop;

         --  One design line per text line; blank lines skipped; anything that does not fit is refused, never clipped.
         declare
            From : Positive := Start;
         begin
            for P in Start .. Raw'Last + 1 loop
               exit when not Fits;
               if P = Raw'Last + 1 or else Raw (P) = LF then
                  if P > From then
                     declare
                        Line  : constant String := Raw (From .. P - 1);
                        Blank : Boolean := True;
                     begin
                        for C of Line loop
                           if C /= ' ' and then C /= Character'Val (9) and then C /= Character'Val (13) then
                              Blank := False;
                           end if;
                        end loop;
                        if not Blank then
                           if Line'Length > Mascot_Scan_Pkg.Max_Line or else Set.Count = Mascot_Measure_Pkg.Max_Nodes then
                              Fits := False;
                           else
                              Set.Count := Set.Count + 1;
                              Set.Lines (Set.Count).Text (1 .. Line'Length) := Line;
                              Set.Lines (Set.Count).Len := Line'Length;
                           end if;
                        end if;
                     end;
                  end if;
                  From := P + 1;
               end if;
            end loop;
         end;

         if not Fits then
            Reason := To_Unbounded_String ("design does not fit the scanner bounds");
         else
            --  5a-2f: the design as the judge sees it, kept for Emit_Contract (one subsystem per line, LF-terminated).
            for L in 1 .. Set.Count loop
               Append (Design, Set.Lines (L).Text (1 .. Set.Lines (L).Len));
               Append (Design, LF);
            end loop;
            declare
               SR : constant Mascot_Scan_Pkg.Scan_Result := Mascot_Scan_Pkg.Scan (Set.all);
            begin
               if not SR.Ok then
                  Reason := To_Unbounded_String ("design scan: " & Lower (Mascot_Scan_Pkg.Fault_Kind'Image (SR.Fault)));
               else
                  declare
                     Facts : constant Mascot_Judge_Pkg.Fact_Set := Mascot_Measure_Pkg.Measure (SR.Table);
                  begin
                     Accepted := Mascot_Judge_Pkg.Accepted (Facts);
                     Reason := To_Unbounded_String
                       ((if Accepted then "design accepted" else "design refused by the judge") &
                        ": " & Natural'Image (Set.Count) & " subsystems");
                     if not Accepted then
                        --  Name every judge fact that failed (5a-0: the refusal says WHAT is missing).
                        declare
                           Failed : constant Mascot_Judge_Pkg.Failed_Set := Mascot_Judge_Pkg.Failed (Facts);
                        begin
                           Append (Reason, "; failed:");
                           for N in Mascot_Judge_Pkg.Fact_Name loop
                              if Failed (N) then
                                 Append (Reason, " " & Lower (Mascot_Judge_Pkg.Fact_Name'Image (N)));
                              end if;
                           end loop;
                        end;
                     end if;
                  end;
               end if;
            end;
         end if;
      end;

      --  SLOT BEGIN (design_result)
Result := Stage_Outcome_Map_Pkg.From_Verdict (Accepted);
      --  SLOT END (design_result)
   exception
      when others =>
         Reason := To_Unbounded_String ("decompose: unreadable");
         Result := Pipeline_Stage_Pkg.Unmeasured_Here;
         Design := Null_Unbounded_String;
   end Run_Keeping_Design;

   procedure Run
     (Brief  : String;
      Result : out Pipeline_Stage_Pkg.Outcome;
      Reason : out Unbounded_String)
   is
      Design : Unbounded_String;
   begin
      Run_Keeping_Design (Brief, Result, Reason, Design);
   end Run;

end Decompose_Activity_Pkg;
