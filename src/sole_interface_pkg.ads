--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged by ANVIL through the lane, ab-20260911-0818. Proved: zero unproved, zero justified,
--  zero cheat markers. Carried here unchanged — a header may be added, a contract may not drift.
--
package Sole_Interface_Pkg with SPARK_Mode is

   type Facts_Type is record
      entry_points_enumerated  : Boolean := False;
      mcp_endpoint_present     : Boolean := False;
      prose_door_retired       : Boolean := False;
      non_mcp_entry_points     : Natural := 0;
      tools_declared           : Natural := 0;
      tools_with_schema        : Natural := 0;
      unauthenticated_entries  : Natural := 0;
   end record;

   type Verdict_Type is record
      facts                        : Facts_Type;
      fault_not_enumerated         : Boolean := False;
      fault_no_mcp_endpoint        : Boolean := False;
      fault_another_door_open      : Boolean := False;
      fault_tool_without_schema    : Boolean := False;
      fault_unauthenticated_entry  : Boolean := False;
      fault_count                  : Natural := 0;
      interface_is_sole            : Boolean := False;
   end record;

   function Enumeration_Observed (facts : Facts_Type) return Boolean
     is (facts.entry_points_enumerated)
     with Post => (Enumeration_Observed'Result = facts.entry_points_enumerated);

   function Only_Mcp_Remains (facts : Facts_Type) return Boolean
     is ((facts.mcp_endpoint_present and then facts.prose_door_retired and then facts.non_mcp_entry_points = 0))
     with Post => ((Only_Mcp_Remains'Result = True) = (facts.mcp_endpoint_present and then facts.prose_door_retired and then facts.non_mcp_entry_points = 0));

   function Tools_Fully_Described (facts : Facts_Type) return Boolean
     is ((facts.tools_declared >= 1 and then facts.tools_with_schema = facts.tools_declared))
     with Post => ((Tools_Fully_Described'Result = True) = (facts.tools_declared >= 1 and then facts.tools_with_schema = facts.tools_declared));

   function Fault_Count (facts : Facts_Type) return Natural
     is ((if Enumeration_Observed (facts) then 0 else 1) +
         (if Only_Mcp_Remains (facts) then 0 else 1) +
         (if Tools_Fully_Described (facts) then 0 else 1) +
         (if facts.unauthenticated_entries = 0 then 0 else 1))
     with Post => (Fault_Count'Result = ((if Enumeration_Observed (facts) then 0 else 1) +
                                        (if Only_Mcp_Remains (facts) then 0 else 1) +
                                        (if Tools_Fully_Described (facts) then 0 else 1) +
                                        (if facts.unauthenticated_entries = 0 then 0 else 1)) and
                   Fault_Count'Result <= 4 and
                   ((Fault_Count'Result = 0) = (Enumeration_Observed (facts) and
                                                Only_Mcp_Remains (facts) and
                                                Tools_Fully_Described (facts) and
                                                facts.unauthenticated_entries = 0)));

   function Assemble (facts : Facts_Type) return Verdict_Type
     is ((facts => facts,
          fault_not_enumerated => not Enumeration_Observed (facts),
          fault_no_mcp_endpoint => not facts.mcp_endpoint_present,
          fault_another_door_open => not Only_Mcp_Remains (facts),
          fault_tool_without_schema => not Tools_Fully_Described (facts),
          fault_unauthenticated_entry => facts.unauthenticated_entries >= 1,
          fault_count => Fault_Count (facts),
          interface_is_sole => Fault_Count (facts) = 0))
     with Post => (Assemble'Result.facts = facts and
                   ((Assemble'Result.fault_not_enumerated = True) = not Enumeration_Observed (facts)) and
                   ((Assemble'Result.fault_no_mcp_endpoint = True) = not facts.mcp_endpoint_present) and
                   ((Assemble'Result.fault_another_door_open = True) = not Only_Mcp_Remains (facts)) and
                   ((Assemble'Result.fault_tool_without_schema = True) = not Tools_Fully_Described (facts)) and
                   ((Assemble'Result.fault_unauthenticated_entry = True) = (facts.unauthenticated_entries >= 1)) and
                   (Assemble'Result.fault_count = Fault_Count (facts) and
                    ((Assemble'Result.interface_is_sole = True) = (Fault_Count (facts) = 0))) and
                   (if not facts.entry_points_enumerated then not Assemble'Result.interface_is_sole));

   function Absence_Was_Established (v : Verdict_Type) return Boolean
     is (not v.fault_not_enumerated)
     with Post => ((Absence_Was_Established'Result = True) = not v.fault_not_enumerated);

end Sole_Interface_Pkg;
