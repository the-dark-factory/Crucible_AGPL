--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 53490b99526133d79fc4bd54c9eab623e8406a2a13668e0821f622cc04428836
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

   procedure Run
     (Brief  : String;
      Result : out Pipeline_Stage_Pkg.Outcome;
      Reason : out Unbounded_String)
   is
      Text     : Model_Rail_Call_Pkg.Text_Access;
      O        : Model_Reply_Pkg.Outcome_Kind;
      Accepted : Boolean := False;
   begin
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
   end Run;

end Decompose_Activity_Pkg;
