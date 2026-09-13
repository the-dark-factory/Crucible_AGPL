--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Body of Design_Input_Pkg: Read only. body-fill-bench, qwen3-coder:30b via ollama; the tier-3 gate
--  no_unreferenced.bb refused three earlier candidates (pragma Unreferenced; an initialiser with no effect);
--  this candidate passed gnatprove level 2 and the gate, 2026-09-13. Never hand-edited.
package body Design_Input_Pkg with SPARK_Mode is

   procedure Read (Set : out Mascot_Scan_Pkg.Line_Set) is
      Buf  : String (1 .. Mascot_Scan_Pkg.Max_Line) with Relaxed_Initialization;
      Last : Natural;
   begin
      Set := (Lines => (others => (Text => (others => ' '), Len => 0)), Count => 0);
      while Set.Count < Mascot_Measure_Pkg.Max_Nodes and then not Ada.Text_IO.End_Of_File loop
         pragma Loop_Invariant (for all I in 1 .. Set.Count =>
                                  Set.Lines (I).Len >= 1
                                  and then not Blank (Set.Lines (I).Text (1 .. Set.Lines (I).Len)));
         pragma Loop_Invariant (for all I in Mascot_Measure_Pkg.Node_Index =>
                                   (if I > Set.Count then Set.Lines (I).Len = 0));
         begin
            Ada.Text_IO.Get_Line (Buf, Last);
         exception
            when Ada.Text_IO.End_Error => exit;
         end;
         if Last >= 1 and then not Blank (Buf (1 .. Last)) then
            Set.Count := Set.Count + 1;
            Set.Lines (Set.Count).Len := Last;
            Set.Lines (Set.Count).Text (1 .. Last) := Buf (1 .. Last);
            pragma Assert (Set.Lines (Set.Count).Text (1 .. Last) = Buf (1 .. Last));
            pragma Assert (not Blank (Set.Lines (Set.Count).Text (1 .. Last)));
         end if;
      end loop;
   end Read;

end Design_Input_Pkg;