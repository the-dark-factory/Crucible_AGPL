--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged by ANVIL through the lane, ab-20260911-0753. Proved: zero unproved, zero justified,
--  zero cheat markers. Carried here unchanged — a header may be added, a contract may not drift.
--
package Intake_Refusal_Pkg with SPARK_Mode is

   type Facts_Type is record
      has_deliverable_clause              : Boolean := False;
      operations_named_as_functions       : Boolean := False;
      every_named_type_is_defined         : Boolean := False;
      every_operation_has_postcondition   : Boolean := False;
      undefined_name_count                : Natural := 0;
      operation_count                     : Natural := 0;
   end record;

   type Verdict_Type is record
      has_deliverable_clause              : Boolean := False;
      operations_named_as_functions       : Boolean := False;
      every_named_type_is_defined         : Boolean := False;
      every_operation_has_postcondition   : Boolean := False;
      undefined_name_count                : Natural := 0;
      operation_count                     : Natural := 0;
      gap_no_deliverable                  : Boolean := False;
      gap_operations_not_functions        : Boolean := False;
      gap_vocabulary_unsound              : Boolean := False;
      gap_contracts_incomplete            : Boolean := False;
      gap_no_operations                   : Boolean := False;
      gap_count                           : Natural := 0;
      may_forge                           : Boolean := False;
   end record;

   function Vocabulary_Sound (facts : Facts_Type) return Boolean
     is (if facts.every_named_type_is_defined then facts.undefined_name_count = 0 else False)
     with Post => ((Vocabulary_Sound'Result = True) = (facts.every_named_type_is_defined and then facts.undefined_name_count = 0));

   function Contracts_Complete (facts : Facts_Type) return Boolean
     is (facts.every_operation_has_postcondition)
     with Post => ((Contracts_Complete'Result = True) = (facts.every_operation_has_postcondition));

   function Is_Non_Empty (facts : Facts_Type) return Boolean
     is (facts.operation_count >= 1)
     with Post => ((Is_Non_Empty'Result = True) = (facts.operation_count >= 1));

   function Gap_Count (facts : Facts_Type) return Natural
     is ((if not facts.has_deliverable_clause then 1 else 0) + (if not facts.operations_named_as_functions then 1 else 0) + (if not Vocabulary_Sound (facts) then 1 else 0) + (if not Contracts_Complete (facts) then 1 else 0) + (if not Is_Non_Empty (facts) then 1 else 0))
     with Post => ((Gap_Count'Result = (if not facts.has_deliverable_clause then 1 else 0) + (if not facts.operations_named_as_functions then 1 else 0) + (if not Vocabulary_Sound (facts) then 1 else 0) + (if not Contracts_Complete (facts) then 1 else 0) + (if not Is_Non_Empty (facts) then 1 else 0)) and then Gap_Count'Result <= 5 and then ((Gap_Count'Result = 0) = (facts.has_deliverable_clause and then facts.operations_named_as_functions and then Vocabulary_Sound (facts) and then Contracts_Complete (facts) and then Is_Non_Empty (facts))));

   function Assemble (facts : Facts_Type) return Verdict_Type
     is ((has_deliverable_clause => facts.has_deliverable_clause, operations_named_as_functions => facts.operations_named_as_functions, every_named_type_is_defined => facts.every_named_type_is_defined, every_operation_has_postcondition => facts.every_operation_has_postcondition, undefined_name_count => facts.undefined_name_count, operation_count => facts.operation_count, gap_no_deliverable => not facts.has_deliverable_clause, gap_operations_not_functions => not facts.operations_named_as_functions, gap_vocabulary_unsound => not Vocabulary_Sound (facts), gap_contracts_incomplete => not Contracts_Complete (facts), gap_no_operations => not Is_Non_Empty (facts), gap_count => Gap_Count (facts), may_forge => Gap_Count (facts) = 0))
     with Post => ((Assemble'Result.has_deliverable_clause = facts.has_deliverable_clause) and then (Assemble'Result.operations_named_as_functions = facts.operations_named_as_functions) and then (Assemble'Result.every_named_type_is_defined = facts.every_named_type_is_defined) and then (Assemble'Result.every_operation_has_postcondition = facts.every_operation_has_postcondition) and then (Assemble'Result.undefined_name_count = facts.undefined_name_count) and then (Assemble'Result.operation_count = facts.operation_count) and then ((Assemble'Result.gap_no_deliverable = True) = (facts.has_deliverable_clause = False)) and then ((Assemble'Result.gap_operations_not_functions = True) = (facts.operations_named_as_functions = False)) and then ((Assemble'Result.gap_vocabulary_unsound = True) = (Vocabulary_Sound (facts) = False)) and then ((Assemble'Result.gap_contracts_incomplete = True) = (Contracts_Complete (facts) = False)) and then ((Assemble'Result.gap_no_operations = True) = (Is_Non_Empty (facts) = False)) and then (Assemble'Result.gap_count = Gap_Count (facts)) and then ((Assemble'Result.may_forge = True) = (Assemble'Result.gap_count = 0)) and then (if facts.operation_count = 0 then Assemble'Result.may_forge = False));

   function Is_Refused (v : Verdict_Type) return Boolean
     is (not v.may_forge)
     with Post => ((Is_Refused'Result = True) = (v.may_forge = False));

end Intake_Refusal_Pkg;
