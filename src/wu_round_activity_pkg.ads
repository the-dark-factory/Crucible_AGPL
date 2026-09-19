--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: a8b9a2b73731edf092e9b50c78f71ad73c7982bcb629dda3b6e190aeae219e92
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
     "and Contract_Cases are all permitted. The unit has TWO kinds of operation and no third:" & LF &
     "(1) HELPERS, which are EXPRESSION FUNCTIONS completed in this file, in exactly this form and never Ghost:" & LF &
     "      function Name (formals) return Boolean is (the expression) with Post => (Name'Result = (the expression));" & LF &
     "    A helper written as a bare declaration with a Post and no  is (...)  is WRONG: it has no body, the prover" & LF &
     "    skips it, and the unit is refused." & LF &
     "(2) THE WALKING OPERATION the sheet asks for (a search, a scan, a copy): declared with its Pre and Post ONLY," & LF &
     "    NO expression and NO body here, and named on one comment line placed BEFORE the final end line, exactly:" & LF &
     "      --  BODY-DEFERRED: <Operation_Name>" & LF &
     "    Its body is written and proved separately, later. A declared-only operation WITHOUT that line is refused." & LF &
     "REQUIRED: at least ONE helper expression function that states the sheet's postcondition property over the" & LF &
     "structure (for example Absent (L, V) is (for all I in L'Range => L (I) /= V)), used by the walking operation's" & LF &
     "Post; and a Pre on the walking operation (the sheet implies one, such as a non-empty structure or a valid" & LF &
     "index). A unit whose prover run generates NO checks (only declared-only operations) is refused as hollow." & LF &
     "No package body, no pragma, no access type, no I/O, no pragma Assume, no Annotate, no SPARK_Mode => Off," & LF &
     "no Warnings (Off), no Import: those refuse the unit." & LF & LF &
     "COUNTING. When the sheet asks for the NUMBER of elements with some property, a Boolean helper cannot" & LF &
     "say it. Then write ONE counting helper instead: a recursive expression function returning Natural over" & LF &
     "the structure from an index, with a Pre, a Post that RESTATES its expression AND bounds it, and a" & LF &
     "Subprogram_Variant, in this form (a Post that only bounds the result is refused as hollow):" & LF &
     "      function Zeros_From (L : List; From : Positive) return Natural is" & LF &
     "        (if From > L'Last then 0 else (if L (From) = 0 then 1 else 0) + Zeros_From (L, From + 1))" & LF &
     "      with Pre  => L'Last < Positive'Last and then From >= L'First," & LF &
     "           Post => Zeros_From'Result = (if From > L'Last then 0 else (if L (From) = 0 then 1 else 0) + Zeros_From (L, From + 1))" & LF &
     "                   and then Zeros_From'Result <= (if From > L'Last then 0 else L'Last - From + 1)," & LF &
     "           Subprogram_Variant => (Increases => From);" & LF &
     "    and state the walking operation's Post as  Name'Result = <Helper> (<structure>, ..., <structure>'First)." & LF & LF &
     "WHAT TO WRITE. The specification sheet below states what is delivered, the types, the operation and its" & LF &
     "postcondition in words. The design below (one subsystem per JSON line) says what each leaf discharges. Write" & LF &
     "the types the sheet names, then the helper(s), then the walking operation with the postcondition the sheet" & LF &
     "states as a SPARK contract, then its BODY-DEFERRED line. End with  end <Name>;  and nothing after it." & LF;

   --  When the previous round left a unit but the prover printed no failing line (the gate word is the whole
   --  finding), the repair section carries the lane's own message for that word — 5a-3's deterministic tier, keyed
   --  on the gate word only; the diagnosis classes over prover lines are 5a-3's proper work.
   function Gate_Hint (Word : String) return String is
     (if Word = "refused-no-checks" then
        "NO CHECKS WERE GENERATED: every operation was declared only, so nothing was proved. Add at least one" & LF &
        "helper EXPRESSION FUNCTION (completed by  is (...)  with a Post) stating the postcondition property, and" & LF &
        "make the walking operation's Post use it." & LF
      elsif Word = "refused-assumed-body" then
        "A DECLARED-ONLY OPERATION IS NOT NAMED AS DEFERRED: add, before the final end line, the comment line" & LF &
        "  --  BODY-DEFERRED: <Operation_Name>  for each operation declared without an expression." & LF
      elsif Word = "refused-cheat" then
        "A PROOF-BYPASS CONSTRUCT WAS FOUND (pragma Assume, Annotate, SPARK_Mode => Off, Warnings (Off) or Import):" & LF &
        "remove it; the contract must be proved, not assumed." & LF
      elsif Word = "refused-compile" then
        "THE UNIT DID NOT COMPILE: fix exactly the lines the compiler names below." & LF
      elsif Word = "refused-unproved" then
        "SOME CHECKS WERE NOT PROVED: the lines below name them; strengthen or correct those contracts." & LF
      else "");

   --  When the route ACCEPTED the round (fill or fill-deferred) but the substance judge refused it, the repair
   --  section names each fault the admitted Contract_Emission_Pkg found — otherwise the model is told nothing.
   function Substance_Hint
     (No_Operations, Missing_Postcondition, Undeclared_Name, Vocabulary_Open, Over_Bound, No_Precondition : Boolean)
      return String is
     ((if No_Operations then "NO OPERATION IS DECLARED: declare the sheet's operation." & LF else "") &
      (if Missing_Postcondition then
         "AN OPERATION HAS NO CONTRACT: every declared operation carries a Post, or is completed by an expression." & LF
       else "") &
      (if Undeclared_Name then "A NAME IS USED THAT THE UNIT NEVER DECLARES: declare every type and helper it uses." & LF else "") &
      (if Vocabulary_Open then "THE UNIT DID NOT COMPILE, so its vocabulary is not established." & LF else "") &
      (if Over_Bound then "TOO MANY OPERATIONS: at most eight in one unit." & LF else "") &
      (if No_Precondition then
         "NO PRECONDITION IS STATED: give the walking operation a  Pre =>  the sheet implies (a non-empty structure, a valid index)." & LF
       else ""));

   Max_Repair_Chars : constant := 32_768;   --  the repair section is bounded: the previous unit and the rail's lines

   procedure Run
     (Sheet     : String;
      Design    : String;
      Unit_Name : out Ada.Strings.Unbounded.Unbounded_String;
      Spec_Text : out Ada.Strings.Unbounded.Unbounded_String;
      Result    : out Pipeline_Stage_Pkg.Outcome;
      Reason    : out Ada.Strings.Unbounded.Unbounded_String);

end Wu_Round_Activity_Pkg;
