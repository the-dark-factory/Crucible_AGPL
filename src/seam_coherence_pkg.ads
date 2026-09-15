--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged by ANVIL through the lane, ab-20260911-0813. Proved: zero unproved, zero justified,
--  zero cheat markers. Carried here unchanged — a header may be added, a contract may not drift.
--
package Seam_Coherence_Pkg with SPARK_Mode is

   type Facts_Type is record
      unit_count              : Natural := 0;
      units_proved            : Natural := 0;
      seam_count              : Natural := 0;
      seams_checked           : Natural := 0;
      seams_contradicting     : Natural := 0;
      shared_types_defined_once : Boolean := False;
      assembly_compiles       : Boolean := False;
   end record;

   type Verdict_Type is record
      facts                   : Facts_Type;
      fault_unit_unproved     : Boolean := False;
      fault_seam_unchecked    : Boolean := False;
      fault_seam_contradicts  : Boolean := False;
      fault_type_defined_twice : Boolean := False;
      fault_does_not_compile  : Boolean := False;
      fault_count             : Natural := 0;
      assembly_is_coherent    : Boolean := False;
   end record;

   function All_Units_Proved (facts : Facts_Type) return Boolean
     is ((facts.unit_count >= 1 and then facts.units_proved = facts.unit_count))
     with Post => (All_Units_Proved'Result = (facts.unit_count >= 1 and then facts.units_proved = facts.unit_count));

   function All_Seams_Checked (facts : Facts_Type) return Boolean
     is (facts.seams_checked = facts.seam_count)
     with Post => (All_Seams_Checked'Result = (facts.seams_checked = facts.seam_count));

   function No_Seam_Contradicts (facts : Facts_Type) return Boolean
     is (facts.seams_contradicting = 0)
     with Post => (No_Seam_Contradicts'Result = (facts.seams_contradicting = 0));

   function Fault_Count (facts : Facts_Type) return Natural
     is ((if All_Units_Proved (facts) then 0 else 1) +
         (if All_Seams_Checked (facts) then 0 else 1) +
         (if No_Seam_Contradicts (facts) then 0 else 1) +
         (if facts.shared_types_defined_once then 0 else 1) +
         (if facts.assembly_compiles then 0 else 1))
     with Post => (Fault_Count'Result =
                   ((if All_Units_Proved (facts) then 0 else 1) +
                    (if All_Seams_Checked (facts) then 0 else 1) +
                    (if No_Seam_Contradicts (facts) then 0 else 1) +
                    (if facts.shared_types_defined_once then 0 else 1) +
                    (if facts.assembly_compiles then 0 else 1)) and then
                  Fault_Count'Result <= 5 and then
                  ((Fault_Count'Result = 0) =
                   (All_Units_Proved (facts) and then
                    All_Seams_Checked (facts) and then
                    No_Seam_Contradicts (facts) and then
                    facts.shared_types_defined_once and then
                    facts.assembly_compiles)));

   function Assemble (facts : Facts_Type) return Verdict_Type
     is ((facts => facts,
          fault_unit_unproved => not All_Units_Proved (facts),
          fault_seam_unchecked => not All_Seams_Checked (facts),
          fault_seam_contradicts => not No_Seam_Contradicts (facts),
          fault_type_defined_twice => not facts.shared_types_defined_once,
          fault_does_not_compile => not facts.assembly_compiles,
          fault_count => Fault_Count (facts),
          assembly_is_coherent => (Fault_Count (facts) = 0 and then facts.unit_count >= 1)))
     with Post => (Assemble'Result.facts = facts and then
                  (Assemble'Result.fault_unit_unproved = not All_Units_Proved (facts)) and then
                  (Assemble'Result.fault_seam_unchecked = not All_Seams_Checked (facts)) and then
                  (Assemble'Result.fault_seam_contradicts = not No_Seam_Contradicts (facts)) and then
                  (Assemble'Result.fault_type_defined_twice = not facts.shared_types_defined_once) and then
                  (Assemble'Result.fault_does_not_compile = not facts.assembly_compiles) and then
                  (Assemble'Result.fault_count = Fault_Count (facts) and then
                   (Assemble'Result.assembly_is_coherent = (Fault_Count (facts) = 0))) and then
                  (if facts.unit_count = 0 then not Assemble'Result.assembly_is_coherent));

   function Seams_Were_Examined (v : Verdict_Type) return Boolean
     is (not v.fault_seam_unchecked)
     with Post => (Seams_Were_Examined'Result = (not v.fault_seam_unchecked));

end Seam_Coherence_Pkg;
