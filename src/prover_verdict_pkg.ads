--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged by ANVIL through the lane, ab-20260911-0802. Proved: zero unproved, zero justified,
--  zero cheat markers. Carried here unchanged — a header may be added, a contract may not drift.
--
package Prover_Verdict_Pkg with SPARK_Mode is

   type Facts_Type is record
      prover_ran            : Boolean := False;
      prover_exited_cleanly : Boolean := False;
      unit_compiled         : Boolean := False;
      level_run_at          : Natural := 0;
      level_demanded        : Natural := 0;
      checks_generated      : Natural := 0;
      checks_unproved       : Natural := 0;
      checks_justified      : Natural := 0;
   end record;

   type Verdict_Type is record
      prover_ran            : Boolean := False;
      prover_exited_cleanly : Boolean := False;
      unit_compiled         : Boolean := False;
      level_run_at          : Natural := 0;
      level_demanded        : Natural := 0;
      checks_generated      : Natural := 0;
      checks_unproved       : Natural := 0;
      checks_justified      : Natural := 0;
      fault_prover_not_observed : Boolean := False;
      fault_did_not_compile     : Boolean := False;
      fault_no_checks_generated : Boolean := False;
      fault_unproved_remain     : Boolean := False;
      fault_level_too_low       : Boolean := False;
      fault_count               : Natural := 0;
      unit_is_proved            : Boolean := False;
   end record;

   function Run_Observed (facts : Facts_Type) return Boolean is
     ((if facts.prover_ran then facts.prover_exited_cleanly else False))
   with Post =>
     (Run_Observed'Result = (facts.prover_ran and then facts.prover_exited_cleanly));

   function Checks_Were_Generated (facts : Facts_Type) return Boolean is
     (facts.checks_generated >= 1)
   with Post =>
     (Checks_Were_Generated'Result = (facts.checks_generated >= 1));

   function Nothing_Unproved (facts : Facts_Type) return Boolean is
     (facts.checks_unproved = 0)
   with Post =>
     (Nothing_Unproved'Result = (facts.checks_unproved = 0));

   function Level_Met (facts : Facts_Type) return Boolean is
     (facts.level_run_at >= facts.level_demanded)
   with Post =>
     (Level_Met'Result = (facts.level_run_at >= facts.level_demanded));

   function Assemble (facts : Facts_Type) return Verdict_Type is
     ((prover_ran            => facts.prover_ran,
       prover_exited_cleanly => facts.prover_exited_cleanly,
       unit_compiled         => facts.unit_compiled,
       level_run_at          => facts.level_run_at,
       level_demanded        => facts.level_demanded,
       checks_generated      => facts.checks_generated,
       checks_unproved       => facts.checks_unproved,
       checks_justified      => facts.checks_justified,
       fault_prover_not_observed => (not Run_Observed (facts)),
       fault_did_not_compile     => (not facts.unit_compiled),
       fault_no_checks_generated => (not Checks_Were_Generated (facts)),
       fault_unproved_remain     => (not Nothing_Unproved (facts)),
       fault_level_too_low       => (not Level_Met (facts)),
       fault_count               =>
         (if Run_Observed (facts) then 0 else 1) +
         (if facts.unit_compiled then 0 else 1) +
         (if Checks_Were_Generated (facts) then 0 else 1) +
         (if Nothing_Unproved (facts) then 0 else 1) +
         (if Level_Met (facts) then 0 else 1),
       unit_is_proved            =>
         (Run_Observed (facts) and then facts.unit_compiled and then
          Checks_Were_Generated (facts) and then Nothing_Unproved (facts) and then
          Level_Met (facts))))
   with Post =>
     ((Assemble'Result.prover_ran = facts.prover_ran) and then
      (Assemble'Result.prover_exited_cleanly = facts.prover_exited_cleanly) and then
      (Assemble'Result.unit_compiled = facts.unit_compiled) and then
      (Assemble'Result.level_run_at = facts.level_run_at) and then
      (Assemble'Result.level_demanded = facts.level_demanded) and then
      (Assemble'Result.checks_generated = facts.checks_generated) and then
      (Assemble'Result.checks_unproved = facts.checks_unproved) and then
      (Assemble'Result.checks_justified = facts.checks_justified) and then
      ((Assemble'Result.fault_prover_not_observed) = (not Run_Observed (facts))) and then
      ((Assemble'Result.fault_did_not_compile) = (not facts.unit_compiled)) and then
      ((Assemble'Result.fault_no_checks_generated) = (not Checks_Were_Generated (facts))) and then
      ((Assemble'Result.fault_unproved_remain) = (not Nothing_Unproved (facts))) and then
      ((Assemble'Result.fault_level_too_low) = (not Level_Met (facts))) and then
      (Assemble'Result.fault_count =
         (if Run_Observed (facts) then 0 else 1) +
         (if facts.unit_compiled then 0 else 1) +
         (if Checks_Were_Generated (facts) then 0 else 1) +
         (if Nothing_Unproved (facts) then 0 else 1) +
         (if Level_Met (facts) then 0 else 1)) and then
      ((Assemble'Result.unit_is_proved) = (Assemble'Result.fault_count = 0)) and then
      (if not facts.prover_ran then not Assemble'Result.unit_is_proved));

   function Justifications_Reported (v : Verdict_Type) return Natural is
     (v.checks_justified)
   with Post =>
     (Justifications_Reported'Result = v.checks_justified);

end Prover_Verdict_Pkg;
