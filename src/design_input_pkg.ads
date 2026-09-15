--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Design_Input_Pkg: the one PROVED reader of a MASCOT design from standard input into a Line_Set
--  (blank lines skipped, at most Max_Nodes lines of Max_Line): Blank as a quantified fact; Read with
--  Global (In_Out => Ada.Text_IO.File_System) and a Post that every counted line is non-blank and every
--  line beyond the count is empty. Unit 3 of the emitter re-decomposition brief, 2026-09-13 (briefed as
--  an edge; forged as a proved package because the FSF 15 runtime's Text_IO carries SPARK contracts).
--  Lane wu-crucible-design-input rounds A-C, planner qwen3.8-27b-ada:v0.3, round C accepted 0 unproved.
--  Never hand-edited. Comment-stripped sha equals the round-C spec.
with Ada.Text_IO;
with Mascot_Scan_Pkg;
with Mascot_Measure_Pkg;
with Comment_Strip_Pkg;

package Design_Input_Pkg with SPARK_Mode is

   function Blank (S : String) return Boolean
     is (for all K in S'Range => S (K) = ' ' or else S (K) = Comment_Strip_Pkg.HT)
     with Global => null,
          Pre    => S'First = 1 and then S'Length >= 1 and then S'Length <= Mascot_Scan_Pkg.Max_Line;

   procedure Read (Set : out Mascot_Scan_Pkg.Line_Set)
     with Global => (In_Out => Ada.Text_IO.File_System),
          Post   => (for all I in 1 .. Set.Count =>
                       Set.Lines (I).Len >= 1
                       and then not Blank (Set.Lines (I).Text (1 .. Set.Lines (I).Len)))
                   and then (for all I in Mascot_Measure_Pkg.Node_Index =>
                               (if I > Set.Count then Set.Lines (I).Len = 0));

end Design_Input_Pkg;
