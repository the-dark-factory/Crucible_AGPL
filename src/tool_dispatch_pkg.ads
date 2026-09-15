--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged by ANVIL through the lane, ab-20260911-1953 round B, on Tony's command. Round A: IR-27 (=> as
--  implication), fixed in prose. Proved: zero unproved, zero justified, zero cheat markers. Carried
--  here unchanged — a header may be added, a contract may not drift.
--
package Tool_Dispatch_Pkg with SPARK_Mode is

   type Tool_Type is (T_Licence_Gate, T_Self_Judge, T_Unknown);

   type Facts_Type is record
      tool              : Tool_Type := T_Unknown;
      requested_present : Boolean := False;
      judge_present     : Boolean := False;
   end record;

   type Verdict_Type is record
      facts                  : Facts_Type;
      fault_unknown_tool     : Boolean := False;
      fault_missing_argument : Boolean := False;
      may_run                : Boolean := False;
   end record;

   Tools_Declared    : constant Natural := 2;
   Tools_With_Schema : constant Natural := 2;

   function Is_Known (facts : Facts_Type) return Boolean is (facts.tool /= T_Unknown)
     with Post => ((Is_Known'Result = True) = (facts.tool /= T_Unknown));

   function Argument_Present (facts : Facts_Type) return Boolean is
     (if facts.tool = T_Licence_Gate then facts.requested_present
      elsif facts.tool = T_Self_Judge then facts.judge_present
      else False)
     with Post => ((if facts.tool = T_Licence_Gate then Argument_Present'Result = facts.requested_present) and then (if facts.tool = T_Self_Judge then Argument_Present'Result = facts.judge_present) and then (if facts.tool = T_Unknown then Argument_Present'Result = False));

   function May_Run (facts : Facts_Type) return Boolean is (Is_Known (facts) and then Argument_Present (facts))
     with Post => (((May_Run'Result = True) = (Is_Known (facts) and then Argument_Present (facts))) and then (if facts.tool = T_Unknown then May_Run'Result = False) and then (if May_Run'Result = True then Is_Known (facts)));

   function Assemble (facts : Facts_Type) return Verdict_Type is
     ((facts => facts, fault_unknown_tool => not Is_Known (facts), fault_missing_argument => Is_Known (facts) and then not Argument_Present (facts), may_run => May_Run (facts)))
     with Post => ((Assemble'Result.facts = facts) and then ((Assemble'Result.fault_unknown_tool = True) = (Is_Known (facts) = False)) and then ((Assemble'Result.fault_missing_argument = True) = (Is_Known (facts) and then Argument_Present (facts) = False)) and then (Assemble'Result.may_run = May_Run (facts)) and then (if Assemble'Result.may_run = True then (Assemble'Result.fault_unknown_tool = False and then Assemble'Result.fault_missing_argument = False)));

   function Is_Refused (v : Verdict_Type) return Boolean is (not v.may_run)
     with Post => ((Is_Refused'Result = True) = (v.may_run = False));

end Tool_Dispatch_Pkg;
