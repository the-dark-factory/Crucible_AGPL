--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged by ANVIL through the lane, ab-20260911-0808. Proved: zero unproved, zero justified,
--  zero cheat markers. Carried here unchanged — a header may be added, a contract may not drift.
--
package Provenance_Record_Pkg with SPARK_Mode is

   type Facts_Type is record
      specification_sha_recorded : Boolean := False;
      prover_name_recorded      : Boolean := False;
      prover_version_recorded   : Boolean := False;
      factory_commit_recorded   : Boolean := False;
      tree_was_clean            : Boolean := False;
      host_recorded             : Boolean := False;
      timestamp_recorded        : Boolean := False;
      fields_recorded           : Natural := 0;
      fields_required           : Natural := 0;
   end record;

   type Verdict_Type is record
      facts                     : Facts_Type;
      fault_source_unidentified : Boolean := False;
      fault_toolchain_unpinned  : Boolean := False;
      fault_tree_was_dirty      : Boolean := False;
      fault_environment_unknown : Boolean := False;
      fault_field_count_short   : Boolean := False;
      fault_count               : Natural := 0;
      is_re_derivable           : Boolean := False;
   end record;

   function Source_Identified (facts : Facts_Type) return Boolean
     is (facts.specification_sha_recorded)
     with Post => (Source_Identified'Result = facts.specification_sha_recorded);

   function Toolchain_Pinned (facts : Facts_Type) return Boolean
     is (facts.prover_name_recorded and then
         facts.prover_version_recorded and then
         facts.factory_commit_recorded)
     with Post => (Toolchain_Pinned'Result =
                   (facts.prover_name_recorded and then
                    facts.prover_version_recorded and then
                    facts.factory_commit_recorded));

   function Environment_Known (facts : Facts_Type) return Boolean
     is (facts.host_recorded and then facts.timestamp_recorded)
     with Post => (Environment_Known'Result =
                   (facts.host_recorded and then facts.timestamp_recorded));

   function Fault_Count (facts : Facts_Type) return Natural
     is ((if Source_Identified (facts) then 0 else 1) +
         (if Toolchain_Pinned (facts) then 0 else 1) +
         (if facts.tree_was_clean then 0 else 1) +
         (if Environment_Known (facts) then 0 else 1) +
         (if (facts.fields_required >= 1 and then
             facts.fields_recorded >= facts.fields_required)
          then 0 else 1))
     with Post => (Fault_Count'Result <= 5
                   and then
                   ((Fault_Count'Result = 0) =
                    (Source_Identified (facts) and then
                     Toolchain_Pinned (facts) and then
                     facts.tree_was_clean and then
                     Environment_Known (facts) and then
                     (facts.fields_required >= 1 and then
                      facts.fields_recorded >= facts.fields_required))));

   function Assemble (facts : Facts_Type) return Verdict_Type
     is ((facts                     => facts,
          fault_source_unidentified => not Source_Identified (facts),
          fault_toolchain_unpinned  => not Toolchain_Pinned (facts),
          fault_tree_was_dirty      => not facts.tree_was_clean,
          fault_environment_unknown => not Environment_Known (facts),
          fault_field_count_short   => not (facts.fields_required >= 1 and then
                                            facts.fields_recorded >= facts.fields_required),
          fault_count               => Fault_Count (facts),
          is_re_derivable           => Fault_Count (facts) = 0))
     with Post => (Assemble'Result.facts = facts
                   and then
                   (Assemble'Result.fault_source_unidentified = not Source_Identified (facts))
                   and then
                   (Assemble'Result.fault_toolchain_unpinned = not Toolchain_Pinned (facts))
                   and then
                   (Assemble'Result.fault_tree_was_dirty = not facts.tree_was_clean)
                   and then
                   (Assemble'Result.fault_environment_unknown = not Environment_Known (facts))
                   and then
                   (Assemble'Result.fault_count = Fault_Count (facts))
                   and then
                   (Assemble'Result.is_re_derivable = (Assemble'Result.fault_count = 0))
                   and then
                   (if facts.fields_required = 0 then not Assemble'Result.is_re_derivable));

   function Replayable_By_A_Stranger (v : Verdict_Type) return Boolean
     is (v.is_re_derivable)
     with Post => (Replayable_By_A_Stranger'Result = v.is_re_derivable);

end Provenance_Record_Pkg;
