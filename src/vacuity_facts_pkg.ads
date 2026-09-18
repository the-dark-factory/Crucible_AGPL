--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 9cb2b5666d0848bae0035a5c0274ce34b45277473833c64aa002c8543ae82757
--
package Vacuity_Facts_Pkg with SPARK_Mode is

   Max_Count : constant := 100_000;

   subtype Count is Natural range 0 .. Max_Count;

   type Facts_Type is record
      battery_ran            : Boolean := False;
      refusal_present        : Boolean := False;
      error_count            : Count := 0;
      functions_read         : Count := 0;
      functions_graded       : Count := 0;
      definitions_only       : Count := 0;
      postconditions_declared : Count := 0;
      postconditions_read    : Count := 0;
      theorem_count          : Count := 0;
      runtime_only_count     : Count := 0;
      unexercised_count      : Count := 0;
      refused_count          : Count := 0;
   end record;

   type Verdict_Type is record
      fault_battery_did_not_run : Boolean := False;
      fault_refused             : Boolean := False;
      fault_errors              : Boolean := False;
      fault_unread              : Boolean := False;
      fault_nothing_graded      : Boolean := False;
      fault_not_theorem         : Boolean := False;
      fault_inconsistent        : Boolean := False;
      fault_count               : Natural := 0;
      contract_is_meaningful    : Boolean := False;
   end record;

   function Counts_Consistent (F : Facts_Type) return Boolean is
     ((F.functions_graded <= F.functions_read) and then
      (F.postconditions_read <= F.postconditions_declared) and then
      (F.theorem_count + F.runtime_only_count + F.unexercised_count + F.refused_count = F.functions_graded))
     with Post => (Counts_Consistent'Result =
                    ((F.functions_graded <= F.functions_read) and then
                     (F.postconditions_read <= F.postconditions_declared) and then
                     (F.theorem_count + F.runtime_only_count + F.unexercised_count + F.refused_count = F.functions_graded)));

   function Every_Postcondition_Read (F : Facts_Type) return Boolean is
     (F.postconditions_read = F.postconditions_declared)
     with Post => (Every_Postcondition_Read'Result = (F.postconditions_read = F.postconditions_declared));

   function Something_Graded_When_Contracts_Exist (F : Facts_Type) return Boolean is
     ((if F.postconditions_declared >= 1 then F.functions_graded >= 1))
     with Post => (Something_Graded_When_Contracts_Exist'Result =
                    ((if F.postconditions_declared >= 1 then F.functions_graded >= 1)));

   function Every_Graded_Is_Theorem (F : Facts_Type) return Boolean is
     ((F.theorem_count = F.functions_graded) and then
      (F.runtime_only_count = 0) and then
      (F.unexercised_count = 0) and then
      (F.refused_count = 0))
     with Post => (Every_Graded_Is_Theorem'Result =
                    ((F.theorem_count = F.functions_graded) and then
                     (F.runtime_only_count = 0) and then
                     (F.unexercised_count = 0) and then
                     (F.refused_count = 0)));

   function Fault_Count (F : Facts_Type) return Natural is
     ((if not F.battery_ran then 1 else 0) +
      (if F.refusal_present then 1 else 0) +
      (if F.error_count >= 1 then 1 else 0) +
      (if not Every_Postcondition_Read (F) then 1 else 0) +
      (if not Something_Graded_When_Contracts_Exist (F) then 1 else 0) +
      (if not Every_Graded_Is_Theorem (F) then 1 else 0))
     with Post => (Fault_Count'Result =
                    ((if not F.battery_ran then 1 else 0) +
                     (if F.refusal_present then 1 else 0) +
                     (if F.error_count >= 1 then 1 else 0) +
                     (if not Every_Postcondition_Read (F) then 1 else 0) +
                     (if not Something_Graded_When_Contracts_Exist (F) then 1 else 0) +
                     (if not Every_Graded_Is_Theorem (F) then 1 else 0)));

   function Is_Meaningful (F : Facts_Type) return Boolean is
     ((Counts_Consistent (F)) and then (Fault_Count (F) = 0))
     with Post =>
       (Is_Meaningful'Result = (Counts_Consistent (F) and then Fault_Count (F) = 0)) and
       ((if Is_Meaningful'Result then F.battery_ran)) and
       ((if Is_Meaningful'Result then not F.refusal_present)) and
       ((if Is_Meaningful'Result then F.error_count = 0)) and
       ((if Is_Meaningful'Result then F.unexercised_count = 0 and F.runtime_only_count = 0 and F.refused_count = 0)) and
       ((if F.postconditions_declared >= 1 and then Is_Meaningful'Result then F.theorem_count >= 1)) and
       ((if Is_Meaningful'Result then F.functions_graded <= F.functions_read)) and
       ((if Is_Meaningful'Result then F.postconditions_read = F.postconditions_declared));

   function Assemble (F : Facts_Type) return Verdict_Type is
     ((fault_battery_did_not_run => not F.battery_ran,
       fault_refused             => F.refusal_present,
       fault_errors              => F.error_count >= 1,
       fault_unread              => not Every_Postcondition_Read (F),
       fault_nothing_graded      => not Something_Graded_When_Contracts_Exist (F),
       fault_not_theorem         => not Every_Graded_Is_Theorem (F),
       fault_inconsistent        => not Counts_Consistent (F),
       fault_count               => Fault_Count (F),
       contract_is_meaningful    => Is_Meaningful (F)))
     with Post =>
       (Assemble'Result.fault_battery_did_not_run = (not F.battery_ran)) and
       (Assemble'Result.fault_refused = (F.refusal_present)) and
       (Assemble'Result.fault_errors = (F.error_count >= 1)) and
       (Assemble'Result.fault_unread = (not Every_Postcondition_Read (F))) and
       (Assemble'Result.fault_nothing_graded = (not Something_Graded_When_Contracts_Exist (F))) and
       (Assemble'Result.fault_not_theorem = (not Every_Graded_Is_Theorem (F))) and
       (Assemble'Result.fault_inconsistent = (not Counts_Consistent (F))) and
       (Assemble'Result.fault_count = (Fault_Count (F))) and
       (Assemble'Result.contract_is_meaningful = (Is_Meaningful (F))) and
       (Assemble'Result.contract_is_meaningful = (not Assemble'Result.fault_inconsistent and then Assemble'Result.fault_count = 0));

end Vacuity_Facts_Pkg;
