--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged by ANVIL through the lane, ab-20260911-0804. Proved: zero unproved, zero justified,
--  zero cheat markers. Carried here unchanged — a header may be added, a contract may not drift.
--
package Admission_Decision_Pkg with SPARK_Mode is

   type Facts_Type is record
      intake_gate_reported        : Boolean := False;
      intake_gate_passed          : Boolean := False;
      decomposition_gate_reported : Boolean := False;
      decomposition_gate_passed   : Boolean := False;
      prover_gate_reported        : Boolean := False;
      prover_gate_passed          : Boolean := False;
      vacuity_gate_reported       : Boolean := False;
      vacuity_gate_passed         : Boolean := False;
      admitter_identified         : Boolean := False;
      admitter_is_the_seat        : Boolean := False;
   end record;

   type Verdict_Type is record
      intake_gate_reported        : Boolean := False;
      intake_gate_passed          : Boolean := False;
      decomposition_gate_reported : Boolean := False;
      decomposition_gate_passed   : Boolean := False;
      prover_gate_reported        : Boolean := False;
      prover_gate_passed          : Boolean := False;
      vacuity_gate_reported       : Boolean := False;
      vacuity_gate_passed         : Boolean := False;
      admitter_identified         : Boolean := False;
      admitter_is_the_seat        : Boolean := False;
      reason_a_gate_was_silent    : Boolean := False;
      reason_a_gate_refused       : Boolean := False;
      reason_admitter_on_seat     : Boolean := False;
      reason_count                : Natural := 0;
      admitted                    : Boolean := False;
   end record;

   function All_Gates_Reported (facts : Facts_Type) return Boolean is
     (facts.intake_gate_reported and then
      facts.decomposition_gate_reported and then
      facts.prover_gate_reported and then
      facts.vacuity_gate_reported)
     with Post =>
       (All_Gates_Reported'Result =
          (facts.intake_gate_reported and then
           facts.decomposition_gate_reported and then
           facts.prover_gate_reported and then
           facts.vacuity_gate_reported));

   function All_Gates_Passed (facts : Facts_Type) return Boolean is
     (facts.intake_gate_passed and then
      facts.decomposition_gate_passed and then
      facts.prover_gate_passed and then
      facts.vacuity_gate_passed)
     with Post =>
       (All_Gates_Passed'Result =
          (facts.intake_gate_passed and then
           facts.decomposition_gate_passed and then
           facts.prover_gate_passed and then
           facts.vacuity_gate_passed));

   function Admitter_Is_Off_Seat (facts : Facts_Type) return Boolean is
     (facts.admitter_identified and then not facts.admitter_is_the_seat)
     with Post =>
       (Admitter_Is_Off_Seat'Result =
          (facts.admitter_identified and then not facts.admitter_is_the_seat));

   function Reason_Count (facts : Facts_Type) return Natural is
     ((if All_Gates_Reported (facts) then 0 else 1) +
      (if All_Gates_Passed (facts) then 0 else 1) +
      (if Admitter_Is_Off_Seat (facts) then 0 else 1))
     with Post =>
       (Reason_Count'Result =
          ((if All_Gates_Reported (facts) then 0 else 1) +
           (if All_Gates_Passed (facts) then 0 else 1) +
           (if Admitter_Is_Off_Seat (facts) then 0 else 1)) and then
        Reason_Count'Result <= 3 and then
        (Reason_Count'Result = 0) =
          (All_Gates_Reported (facts) and then
           All_Gates_Passed (facts) and then
           Admitter_Is_Off_Seat (facts)));

   function Assemble (facts : Facts_Type) return Verdict_Type is
     ((intake_gate_reported        => facts.intake_gate_reported,
       intake_gate_passed          => facts.intake_gate_passed,
       decomposition_gate_reported => facts.decomposition_gate_reported,
       decomposition_gate_passed   => facts.decomposition_gate_passed,
       prover_gate_reported        => facts.prover_gate_reported,
       prover_gate_passed          => facts.prover_gate_passed,
       vacuity_gate_reported       => facts.vacuity_gate_reported,
       vacuity_gate_passed         => facts.vacuity_gate_passed,
       admitter_identified         => facts.admitter_identified,
       admitter_is_the_seat        => facts.admitter_is_the_seat,
       reason_a_gate_was_silent    => not All_Gates_Reported (facts),
       reason_a_gate_refused       => not All_Gates_Passed (facts),
       reason_admitter_on_seat     => not Admitter_Is_Off_Seat (facts),
       reason_count                => Reason_Count (facts),
       admitted                    => Reason_Count (facts) = 0))
     with Post =>
       (Assemble'Result.intake_gate_reported = facts.intake_gate_reported and then
        Assemble'Result.intake_gate_passed = facts.intake_gate_passed and then
        Assemble'Result.decomposition_gate_reported = facts.decomposition_gate_reported and then
        Assemble'Result.decomposition_gate_passed = facts.decomposition_gate_passed and then
        Assemble'Result.prover_gate_reported = facts.prover_gate_reported and then
        Assemble'Result.prover_gate_passed = facts.prover_gate_passed and then
        Assemble'Result.vacuity_gate_reported = facts.vacuity_gate_reported and then
        Assemble'Result.vacuity_gate_passed = facts.vacuity_gate_passed and then
        Assemble'Result.admitter_identified = facts.admitter_identified and then
        Assemble'Result.admitter_is_the_seat = facts.admitter_is_the_seat and then
        (Assemble'Result.reason_a_gate_was_silent = not All_Gates_Reported (facts)) and then
        (Assemble'Result.reason_a_gate_refused = not All_Gates_Passed (facts)) and then
        (Assemble'Result.reason_admitter_on_seat = not Admitter_Is_Off_Seat (facts)) and then
        Assemble'Result.reason_count = Reason_Count (facts) and then
        (Assemble'Result.admitted = (Reason_Count (facts) = 0)) and then
        (if not All_Gates_Reported (facts) then not Assemble'Result.admitted));

   function Refused_With_A_Reason (v : Verdict_Type) return Boolean is
     (not v.admitted and then v.reason_count >= 1)
     with Post =>
       (Refused_With_A_Reason'Result = (not v.admitted and then v.reason_count >= 1));

end Admission_Decision_Pkg;
