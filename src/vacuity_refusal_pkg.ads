--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged by ANVIL through the lane, ab-20260911-0755. Proved: zero unproved, zero justified,
--  zero cheat markers. Carried here unchanged — a header may be added, a contract may not drift.
--
package Vacuity_Refusal_Pkg with SPARK_Mode is

   type Facts_Type is record
      battery_ran                      : Boolean := False;
      postcondition_present            : Boolean := False;
      precondition_satisfiable         : Boolean := False;
      conjunct_count                   : Natural := 0;
      conjuncts_mentioning_result      : Natural := 0;
      conjuncts_surviving_negated_body : Natural := 0;
   end record;

   type Verdict_Type is record
      battery_ran                      : Boolean := False;
      postcondition_present            : Boolean := False;
      precondition_satisfiable         : Boolean := False;
      conjunct_count                   : Natural := 0;
      conjuncts_mentioning_result      : Natural := 0;
      conjuncts_surviving_negated_body : Natural := 0;
      fault_battery_did_not_run        : Boolean := False;
      fault_no_postcondition           : Boolean := False;
      fault_precondition_empty         : Boolean := False;
      fault_unconstraining_conjunct    : Boolean := False;
      fault_survives_negation          : Boolean := False;
      fault_count                      : Natural := 0;
      contract_is_meaningful           : Boolean := False;
   end record;

   function Every_Conjunct_Constrains (facts : Facts_Type) return Boolean
     is ((facts.conjunct_count >= 1) and then facts.conjuncts_mentioning_result = facts.conjunct_count)
     with Post => (Every_Conjunct_Constrains'Result = ((facts.conjunct_count >= 1) and then facts.conjuncts_mentioning_result = facts.conjunct_count));

   function No_Conjunct_Survives_Negation (facts : Facts_Type) return Boolean
     is (facts.conjuncts_surviving_negated_body = 0)
     with Post => (No_Conjunct_Survives_Negation'Result = (facts.conjuncts_surviving_negated_body = 0));

   function Measurements_Trustworthy (facts : Facts_Type) return Boolean
     is (facts.battery_ran and then facts.conjuncts_mentioning_result <= facts.conjunct_count and then facts.conjuncts_surviving_negated_body <= facts.conjunct_count)
     with Post => (Measurements_Trustworthy'Result = (facts.battery_ran and then facts.conjuncts_mentioning_result <= facts.conjunct_count and then facts.conjuncts_surviving_negated_body <= facts.conjunct_count));

   function Fault_Count (facts : Facts_Type) return Natural
     is ((if not Measurements_Trustworthy (facts) then 1 else 0) +
         (if not facts.postcondition_present then 1 else 0) +
         (if not facts.precondition_satisfiable then 1 else 0) +
         (if not Every_Conjunct_Constrains (facts) then 1 else 0) +
         (if not No_Conjunct_Survives_Negation (facts) then 1 else 0))
     with Post => (Fault_Count'Result = ((if not Measurements_Trustworthy (facts) then 1 else 0) +
                                        (if not facts.postcondition_present then 1 else 0) +
                                        (if not facts.precondition_satisfiable then 1 else 0) +
                                        (if not Every_Conjunct_Constrains (facts) then 1 else 0) +
                                        (if not No_Conjunct_Survives_Negation (facts) then 1 else 0)) and
                   Fault_Count'Result <= 5 and
                   ((Fault_Count'Result = 0) = (Measurements_Trustworthy (facts) and facts.postcondition_present and facts.precondition_satisfiable and Every_Conjunct_Constrains (facts) and No_Conjunct_Survives_Negation (facts))));

   function Assemble (facts : Facts_Type) return Verdict_Type
     is ((battery_ran                      => facts.battery_ran,
          postcondition_present            => facts.postcondition_present,
          precondition_satisfiable         => facts.precondition_satisfiable,
          conjunct_count                   => facts.conjunct_count,
          conjuncts_mentioning_result      => facts.conjuncts_mentioning_result,
          conjuncts_surviving_negated_body => facts.conjuncts_surviving_negated_body,
          fault_battery_did_not_run        => not facts.battery_ran,
          fault_no_postcondition           => not facts.postcondition_present,
          fault_precondition_empty         => not facts.precondition_satisfiable,
          fault_unconstraining_conjunct    => not Every_Conjunct_Constrains (facts),
          fault_survives_negation          => not No_Conjunct_Survives_Negation (facts),
          fault_count                      => Fault_Count (facts),
          contract_is_meaningful           => Fault_Count (facts) = 0))
     with Post => (Assemble'Result.battery_ran = facts.battery_ran and
                   Assemble'Result.postcondition_present = facts.postcondition_present and
                   Assemble'Result.precondition_satisfiable = facts.precondition_satisfiable and
                   Assemble'Result.conjunct_count = facts.conjunct_count and
                   Assemble'Result.conjuncts_mentioning_result = facts.conjuncts_mentioning_result and
                   Assemble'Result.conjuncts_surviving_negated_body = facts.conjuncts_surviving_negated_body and
                   (Assemble'Result.fault_battery_did_not_run = (not facts.battery_ran)) and
                   (Assemble'Result.fault_no_postcondition = (not facts.postcondition_present)) and
                   (Assemble'Result.fault_precondition_empty = (not facts.precondition_satisfiable)) and
                   (Assemble'Result.fault_unconstraining_conjunct = (not Every_Conjunct_Constrains (facts))) and
                   (Assemble'Result.fault_survives_negation = (not No_Conjunct_Survives_Negation (facts))) and
                   (Assemble'Result.fault_count = Fault_Count (facts)) and
                   (Assemble'Result.contract_is_meaningful = (Assemble'Result.fault_count = 0)) and
                   (if not facts.battery_ran then not Assemble'Result.contract_is_meaningful));

   function Is_Vacuous (v : Verdict_Type) return Boolean
     is (not v.contract_is_meaningful)
     with Post => (Is_Vacuous'Result = (not v.contract_is_meaningful));

end Vacuity_Refusal_Pkg;
