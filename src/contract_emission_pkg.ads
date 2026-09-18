--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: d54d9ba5f6e611cefaf9cadccce4dfab5293af5568bc24cc962a341debabe7cd
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
      sheet_states_precondition     : Boolean := False;
   end record;

   type Verdict_Type is record
      facts                       : Facts_Type;
      fault_no_operations         : Boolean := False;
      fault_missing_postcondition : Boolean := False;
      fault_undeclared_name       : Boolean := False;
      fault_vocabulary_open       : Boolean := False;
      fault_over_bound            : Boolean := False;
      fault_precondition_missing  : Boolean := False;
      fault_count                 : Natural := 0;
      may_emit                    : Boolean := False;
   end record;

   function Is_Non_Empty (facts : Facts_Type) return Boolean is
     (facts.operation_count >= 1)
   with Post =>
     (Is_Non_Empty'Result = (facts.operation_count >= 1));

   function Every_Operation_Contracted (facts : Facts_Type) return Boolean is
     (facts.operations_with_postcondition = facts.operation_count)
   with Post =>
     (Every_Operation_Contracted'Result = (facts.operations_with_postcondition = facts.operation_count));

   function Vocabulary_Closed (facts : Facts_Type) return Boolean is
     (facts.vocabulary_is_stated and then facts.names_undeclared = 0)
   with Post =>
     (Vocabulary_Closed'Result = (facts.vocabulary_is_stated and then facts.names_undeclared = 0));

   function Precondition_Obligation_Met (facts : Facts_Type) return Boolean is
     ((not facts.sheet_states_precondition) or else facts.preconditions_stated)
   with Post =>
     (Precondition_Obligation_Met'Result = ((not facts.sheet_states_precondition) or else facts.preconditions_stated))
     and then
     ((if not facts.sheet_states_precondition then Precondition_Obligation_Met'Result))
     and then
     ((if facts.sheet_states_precondition and then not facts.preconditions_stated then not Precondition_Obligation_Met'Result))
     and then
     ((if facts.preconditions_stated then Precondition_Obligation_Met'Result));

   function Fault_Count (facts : Facts_Type) return Natural is
     ((if not Is_Non_Empty (facts) then 1 else 0) +
      (if not Every_Operation_Contracted (facts) then 1 else 0) +
      (if not Vocabulary_Closed (facts) then 1 else 0) +
      (if not Precondition_Obligation_Met (facts) then 1 else 0) +
      (if facts.operation_count > 8 then 1 else 0))
   with Post =>
     (Fault_Count'Result = ((if not Is_Non_Empty (facts) then 1 else 0) + (if not Every_Operation_Contracted (facts) then 1 else 0) + (if not Vocabulary_Closed (facts) then 1 else 0) + (if not Precondition_Obligation_Met (facts) then 1 else 0) + (if facts.operation_count > 8 then 1 else 0)))
     and then
     (Fault_Count'Result <= 5)
     and then
     ((Fault_Count'Result = 0) = ((Is_Non_Empty (facts)) and then (Every_Operation_Contracted (facts)) and then (Vocabulary_Closed (facts)) and then (Precondition_Obligation_Met (facts)) and then (facts.operation_count <= 8)));

   function Assemble (facts : Facts_Type) return Verdict_Type is
     ((facts => facts,
       fault_no_operations => not Is_Non_Empty (facts),
       fault_missing_postcondition => not Every_Operation_Contracted (facts),
       fault_undeclared_name => facts.names_undeclared >= 1,
       fault_vocabulary_open => not Vocabulary_Closed (facts),
       fault_over_bound => facts.operation_count > 8,
       fault_precondition_missing => not Precondition_Obligation_Met (facts),
       fault_count => Fault_Count (facts),
       may_emit => Fault_Count (facts) = 0))
   with Post =>
     (Assemble'Result.facts = facts)
     and then
     (Assemble'Result.fault_no_operations = not Is_Non_Empty (facts))
     and then
     (Assemble'Result.fault_missing_postcondition = not Every_Operation_Contracted (facts))
     and then
     (Assemble'Result.fault_undeclared_name = (facts.names_undeclared >= 1))
     and then
     (Assemble'Result.fault_vocabulary_open = not Vocabulary_Closed (facts))
     and then
     (Assemble'Result.fault_over_bound = (facts.operation_count > 8))
     and then
     (Assemble'Result.fault_precondition_missing = not Precondition_Obligation_Met (facts))
     and then
     (Assemble'Result.fault_count = Fault_Count (facts))
     and then
     (Assemble'Result.may_emit = (Fault_Count (facts) = 0))
     and then
     ((if facts.operation_count = 0 then not Assemble'Result.may_emit))
     and then
     ((if not facts.sheet_states_precondition then not Assemble'Result.fault_precondition_missing))
     and then
     ((if Assemble'Result.may_emit then not Assemble'Result.fault_precondition_missing));

   function Contract_Is_Local (v : Verdict_Type) return Boolean is
     (not v.fault_vocabulary_open and then not v.fault_undeclared_name)
   with Post =>
     (Contract_Is_Local'Result = (not v.fault_vocabulary_open and then not v.fault_undeclared_name));

end Contract_Emission_Pkg;
