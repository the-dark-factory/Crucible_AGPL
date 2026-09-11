--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged by ANVIL through the lane, ab-20260911-0616. Proved: zero unproved, zero justified,
--  zero cheat markers. Carried here unchanged — a header may be added, a contract may not drift.
--
package Mascot_Decomposition_Pkg with SPARK_Mode is

   type Facts_Type is record
      cycle_free                         : Boolean := False;
      common_types_present               : Boolean := False;
      common_types_has_no_operations     : Boolean := False;
      common_types_has_no_dependencies   : Boolean := False;
      every_type_owned_once              : Boolean := False;
      topologically_sorted               : Boolean := False;
      max_operations_in_a_subsystem      : Natural := 0;
      subsystem_count                    : Natural := 0;
   end record;

   type Verdict_Type is record
      cycle_free                         : Boolean := False;
      common_types_present               : Boolean := False;
      common_types_has_no_operations     : Boolean := False;
      common_types_has_no_dependencies   : Boolean := False;
      every_type_owned_once              : Boolean := False;
      topologically_sorted               : Boolean := False;
      max_operations_in_a_subsystem      : Natural := 0;
      subsystem_count                    : Natural := 0;
      fault_count                        : Natural := 0;
      may_accept                         : Boolean := False;
   end record;

   function Structure_Sound (facts : Facts_Type) return Boolean
     is ((if facts.cycle_free then True else False)
         and then (if facts.common_types_present then True else False)
         and then (if facts.common_types_has_no_operations then True else False)
         and then (if facts.common_types_has_no_dependencies then True else False)
         and then (if facts.every_type_owned_once then True else False)
         and then (if facts.topologically_sorted then True else False))
     with Post => ((Structure_Sound'Result = True) = (facts.cycle_free and then
                                                      facts.common_types_present and then
                                                      facts.common_types_has_no_operations and then
                                                      facts.common_types_has_no_dependencies and then
                                                      facts.every_type_owned_once and then
                                                      facts.topologically_sorted));

   function Within_Operation_Bound (facts : Facts_Type) return Boolean
     is ((if facts.max_operations_in_a_subsystem <= 8 then True else False))
     with Post => ((Within_Operation_Bound'Result = True) = (facts.max_operations_in_a_subsystem <= 8));

   function Is_Non_Empty (facts : Facts_Type) return Boolean
     is ((if facts.subsystem_count >= 1 then True else False))
     with Post => ((Is_Non_Empty'Result = True) = (facts.subsystem_count >= 1));

   function Fault_Count (facts : Facts_Type) return Natural
     is ((if not Structure_Sound (facts) then 1 else 0)
         + (if not Within_Operation_Bound (facts) then 1 else 0)
         + (if not Is_Non_Empty (facts) then 1 else 0))
     with Post => (Fault_Count'Result =
                      ((if not Structure_Sound (facts) then 1 else 0)
                       + (if not Within_Operation_Bound (facts) then 1 else 0)
                       + (if not Is_Non_Empty (facts) then 1 else 0))
                   and then Fault_Count'Result <= 3
                   and then ((Fault_Count'Result = 0) = (Structure_Sound (facts)
                                                         and then Within_Operation_Bound (facts)
                                                         and then Is_Non_Empty (facts))));

   function Assemble (facts : Facts_Type) return Verdict_Type
     is ((cycle_free                         => facts.cycle_free,
          common_types_present               => facts.common_types_present,
          common_types_has_no_operations     => facts.common_types_has_no_operations,
          common_types_has_no_dependencies   => facts.common_types_has_no_dependencies,
          every_type_owned_once              => facts.every_type_owned_once,
          topologically_sorted               => facts.topologically_sorted,
          max_operations_in_a_subsystem      => facts.max_operations_in_a_subsystem,
          subsystem_count                    => facts.subsystem_count,
          fault_count                        => Fault_Count (facts),
          may_accept                         => (if facts.cycle_free and then
                                                 facts.common_types_present and then
                                                 facts.common_types_has_no_operations and then
                                                 facts.common_types_has_no_dependencies and then
                                                 facts.every_type_owned_once and then
                                                 facts.topologically_sorted and then
                                                 facts.max_operations_in_a_subsystem <= 8 and then
                                                 facts.subsystem_count >= 1
                                                then True else False)))
     with Post => (Assemble'Result.cycle_free = facts.cycle_free
                   and then Assemble'Result.common_types_present = facts.common_types_present
                   and then Assemble'Result.common_types_has_no_operations = facts.common_types_has_no_operations
                   and then Assemble'Result.common_types_has_no_dependencies = facts.common_types_has_no_dependencies
                   and then Assemble'Result.every_type_owned_once = facts.every_type_owned_once
                   and then Assemble'Result.topologically_sorted = facts.topologically_sorted
                   and then Assemble'Result.max_operations_in_a_subsystem = facts.max_operations_in_a_subsystem
                   and then Assemble'Result.subsystem_count = facts.subsystem_count
                   and then Assemble'Result.fault_count = Fault_Count (facts)
                   and then ((Assemble'Result.may_accept = True) = (Structure_Sound (facts)
                                                                    and then Within_Operation_Bound (facts)
                                                                    and then Is_Non_Empty (facts)))
                   and then (if facts.subsystem_count = 0 then Assemble'Result.may_accept = False));

   function Is_Accepted (v : Verdict_Type) return Boolean
     is ((if v.may_accept then True else False))
     with Post => (Is_Accepted'Result = v.may_accept);

end Mascot_Decomposition_Pkg;
