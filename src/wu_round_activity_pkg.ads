--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 58762c1ffeb584141628c71cca4214fffaa1afe5212d3065a81d0a534837cd78
--
--  Wu_Round_Activity_Pkg -- the Emit_Contract stage of CRUCIBLE's pipeline, in process (step 5a-2f).
--  Purpose: the Wu SPECIFICATION ROUND inside the executable. Per round: the house form + the sheet + the accepted
--  design (+ a repair section) go to the model rail; the reply becomes ONE unit or is refused (Unit_Extract_Pkg);
--  proof-bypass markers are counted (Cheat_Marker_Pkg); the specification's shape is measured (Spec_Shape_Pkg); the unit
--  goes to the prover rail (Prover_Rail_Call_Pkg.Prove_Full); the gate WORD is derived (Gate_Word_Pkg) and routed
--  (Fill_Route_Pkg); the substance judge decides may_emit (Contract_Emission_Pkg); the round budget decides whether a
--  next round may start and whether it repairs (Round_Budget_Pkg). This package decides NOTHING itself: every verdict
--  above is a proven core's. What it holds that is the seat's: House_Form, the instruction the planner is given.
--  Every round appends one JSON line to state/rounds.jsonl; the fit specification is written to state/spec.ads.
--  Usage:
--     Wu_Round_Activity_Pkg.Run (Sheet, Design, Unit_Name, Spec_Text, Result, Reason);
with Ada.Strings.Unbounded;
with Pipeline_Stage_Pkg;

package Wu_Round_Activity_Pkg with SPARK_Mode => Off is

   LF : constant Character := Character'Val (10);

   --  The house form (the seat's prose, as every proven prompt of 2026-09 states it), widened (A11): expression
   --  functions completed in the file; a walking operation declared with contract only and named on a BODY-DEFERRED
   --  comment line placed before the final end, which the round counts as DECLARED deferral.
   House_Form : constant String :=
     "OUTPUT FORMAT - READ THIS FIRST AND OBEY IT BEFORE ANYTHING ELSE." & LF &
     "Emit ONLY the compilation unit. The very first character of your reply is the 'p' of 'package'" & LF &
     "(or the 'w' of 'with' if a context clause is needed). No preamble, no restatement, no reasoning, no plan," & LF &
     "no thinking aloud, no markdown fences, no closing explanation. ASCII only." & LF & LF &
     "Emit the complete SPARK package specification (.ads source) for the package named below." & LF &
     "The package declaration carries the SPARK_Mode aspect, in this exact form:" & LF &
     "  package <Name> with SPARK_Mode is" & LF & LF &
     "FORM. An implication is an IF-EXPRESSION in its own parentheses, (if <condition> then <consequence>)." & LF &
     "Ada has NO implication operator; => belongs only to aggregates, named associations, case alternatives and" & LF &
     "quantified expressions. Name a function's result as Function_Name'Result. ""The result is true exactly when P""" & LF &
     "is (Name'Result = (P)). A Boolean is already a Boolean: never (if C then True else False). No identifier may be" & LF &
     "an Ada reserved word. Never A = B = C. A double quote inside a string literal is written twice." & LF & LF &
     "SHAPE. This is ordinary SPARK: quantified expressions (for all / for some), arrays, records with discriminants," & LF &
     "and Contract_Cases are all permitted. Small helper functions are EXPRESSION FUNCTIONS completed in this file:" & LF &
     "  function Name (formals) return T is (the expression) with Post => (...);" & LF &
     "An operation that must WALK a structure (a search, a scan, a copy) is NOT an expression function: declare it" & LF &
     "with its Pre and Post only, write NO body here, and add, before the final end line, one comment line per such" & LF &
     "operation, exactly:  --  BODY-DEFERRED: <Operation_Name>" & LF &
     "Its body is written and proved separately, later. A declaration without an expression and without that line" & LF &
     "is refused. Every declared operation carries a Post that constrains its result; state a Pre where the sheet" & LF &
     "implies one. No package body, no pragma, no access type, no I/O, no pragma Assume, no Annotate," & LF &
     "no SPARK_Mode => Off, no Warnings (Off), no Import: those refuse the unit." & LF & LF &
     "WHAT TO WRITE. The specification sheet below states what is delivered, the types, the operation and its" & LF &
     "postcondition in words. The design below (one subsystem per JSON line) says what each leaf discharges. Write" & LF &
     "the types the sheet names, then the operation(s) with the postcondition the sheet states, as SPARK contracts." & LF &
     "End with  end <Name>;  and nothing after it." & LF;

   Max_Repair_Chars : constant := 32_768;   --  the repair section is bounded: the previous unit and the rail's lines

   procedure Run
     (Sheet     : String;
      Design    : String;
      Unit_Name : out Ada.Strings.Unbounded.Unbounded_String;
      Spec_Text : out Ada.Strings.Unbounded.Unbounded_String;
      Result    : out Pipeline_Stage_Pkg.Outcome;
      Reason    : out Ada.Strings.Unbounded.Unbounded_String);

end Wu_Round_Activity_Pkg;
