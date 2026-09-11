--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged by ANVIL through the lane, ab-20260911-0814. Proved: zero unproved, zero justified,
--  zero cheat markers. Carried here unchanged — a header may be added, a contract may not drift.
--
package Contract_Emission_Pkg with SPARK_Mode is

   type Facts_Type is record
      operation_count               : Natural := 0;
      operations_with_postcondition : Natural := 0;
      names_used                    : Natural := 0;
      names_declared                : Natural := 0;
      names_undeclared              : Natural := 0;
      vocabulary_is_stated          : Boolean := False;
      preconditions_stated          : Boolean := False;
   end record;

   type Verdict_Type is record
      facts                       : Facts_Type;
      fault_no_operations         : Boolean := False;
      fault_missing_postcondition : Boolean := False;
      fault_undeclared_name       : Boolean := False;
      fault_vocabulary_open       : Boolean := False;
      fault_over_bound            : Boolean := False;
      fault_count                 : Natural := 0;
      may_emit                    : Boolean := False;
   end record;

   function Is_Non_Empty (facts : Facts_Type) return Boolean
     is ((facts.operation_count >= 1))
     with Post => (Is_Non_Empty'Result = (facts.operation_count >= 1));

   function Every_Operation_Contracted (facts : Facts_Type) return Boolean
     is ((facts.operations_with_postcondition = facts.operation_count))
     with Post => (Every_Operation_Contracted'Result = (facts.operations_with_postcondition = facts.operation_count));

   function Vocabulary_Closed (facts : Facts_Type) return Boolean
     is ((facts.vocabulary_is_stated and then facts.names_undeclared = 0))
     with Post => (Vocabulary_Closed'Result = (facts.vocabulary_is_stated and then facts.names_undeclared = 0));

   function Fault_Count (facts : Facts_Type) return Natural
     is ((if Is_Non_Empty (facts) then 0 else 1) +
         (if Every_Operation_Contracted (facts) then 0 else 1) +
         (if Vocabulary_Closed (facts) then 0 else 1) +
         (if facts.preconditions_stated then 0 else 1) +
         (if facts.operation_count <= 8 then 0 else 1))
     with Post => ((Fault_Count'Result =
                    ((if Is_Non_Empty (facts) then 0 else 1) +
                     (if Every_Operation_Contracted (facts) then 0 else 1) +
                     (if Vocabulary_Closed (facts) then 0 else 1) +
                     (if facts.preconditions_stated then 0 else 1) +
                     (if facts.operation_count <= 8 then 0 else 1))) and
                   (Fault_Count'Result <= 5) and
                   ((Fault_Count'Result = 0) =
                     (Is_Non_Empty (facts) and
                      Every_Operation_Contracted (facts) and
                      Vocabulary_Closed (facts) and
                      facts.preconditions_stated and
                      facts.operation_count <= 8)));

   function Assemble (facts : Facts_Type) return Verdict_Type
     is ((facts => facts,
          fault_no_operations         => not Is_Non_Empty (facts),
          fault_missing_postcondition => not Every_Operation_Contracted (facts),
          fault_undeclared_name       => facts.names_undeclared >= 1,
          fault_vocabulary_open       => not Vocabulary_Closed (facts),
          fault_over_bound            => facts.operation_count > 8,
          fault_count                 => Fault_Count (facts),
          may_emit                    => Fault_Count (facts) = 0))
     with Post => ((Assemble'Result.facts = facts) and
                   (Assemble'Result.fault_no_operations = not Is_Non_Empty (facts)) and
                   (Assemble'Result.fault_missing_postcondition = not Every_Operation_Contracted (facts)) and
                   (Assemble'Result.fault_undeclared_name = (facts.names_undeclared >= 1)) and
                   (Assemble'Result.fault_vocabulary_open = not Vocabulary_Closed (facts)) and
                   (Assemble'Result.fault_over_bound = (facts.operation_count > 8)) and
                   ((Assemble'Result.fault_count = Fault_Count (facts)) and
                    (Assemble'Result.may_emit = (Fault_Count (facts) = 0))) and
                   ((if facts.operation_count = 0 then Assemble'Result.may_emit = False)));

   function Contract_Is_Local (v : Verdict_Type) return Boolean
     is ((not v.fault_vocabulary_open and then not v.fault_undeclared_name))
     with Post => (Contract_Is_Local'Result = (not v.fault_vocabulary_open and then not v.fault_undeclared_name));

end Contract_Emission_Pkg;
