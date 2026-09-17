--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: d32f3f741850727d729e564be68cf771a9095e0296ee6eb9c8fb80ac9425e8a7
--
--  Body_Fill_Activity_Pkg — CRUCIBLE's Fill_Body stage (step 5a-4c): the body-fill candidate loop inside the executable.
--  Purpose: given a FIT specification (5a-2) and its unit name, obtain a SPARK package BODY through the model rail, make it
--  hygienic by proven judgements (Body_Hygiene_Pkg blanks contract aspects in place and says where SPARK_Mode is missing;
--  Idiom_Rewrite_Pkg names the position of each 'Old-in-invariant and exists-quantifier idiom and re-judges the text CLEAN after
--  the splice; Duplicate_Completion_Pkg gives every body line a BLANK/KEEP verdict against the spec's completed functions), judge
--  it with the prover rail (Prover_Rail_Call_Pkg.Prove_Full on spec + body), and accept it only when the proven route says
--  Route_Fill (compiled, no cheat, >= 1 check, 0 unproved, 0 skipped). A refused round gets a repair prompt carrying the ONE
--  diagnosis paragraph (Diagnosis_Activity_Pkg, 5a-3), the prover's lines and the previous body, until Round_Budget_Pkg refuses.
--  This package decides NOTHING itself: every verdict is a proven core's; this is plumbing (SPARK_Mode => Off, an edge).
--  Usage: Run (Spec_Text, Unit_Name, Body_Text, Result, Reason). State: state/body-rounds.jsonl (one JSON line per round),
--  state/body.adb (the accepted body). A spec whose subprograms are all completed needs no body: Passed with zero rounds.
with Ada.Strings.Unbounded;
with Pipeline_Stage_Pkg;

package Body_Fill_Activity_Pkg with SPARK_Mode => Off is

   LF : constant Character := Character'Val (10);

   --  The house form for a BODY: what the model is told before the specification. Prose only; the cores judge the result.
   Body_Form : constant String :=
     "OUTPUT FORMAT - READ THIS FIRST AND OBEY IT BEFORE ANYTHING ELSE." & LF &
     "Emit ONLY the compilation unit. The very first character of your reply is the 'p' of 'package body'" & LF &
     "(or the 'w' of 'with' if a context clause is needed). No preamble, no restatement, no reasoning, no plan," & LF &
     "no thinking aloud, no markdown fences, no closing explanation. ASCII only." & LF & LF &
     "Emit the complete SPARK package BODY (.adb source) for the package whose SPECIFICATION is shown below." & LF &
     "The body declaration carries the SPARK_Mode aspect, in this exact form:" & LF &
     "  package body <Name> with SPARK_Mode is" & LF & LF &
     "WHAT TO WRITE. Implement EVERY subprogram the specification declares WITHOUT an expression (each one is named" & LF &
     "on a  --  BODY-DEFERRED: <Name>  line). Implement NOTHING else: a function the specification completes with" & LF &
     "is (...) already has its body there, and a second one is a compile error. Write NO contract aspect (Pre, Post," & LF &
     "Contract_Cases, Subprogram_Variant) on a body subprogram: the specification already states them." & LF & LF &
     "PROOF FORM. A loop carries  pragma Loop_Invariant (...)  as the FIRST statement inside the loop, stating what" & LF &
     "holds for every index already visited (a prefix property: for all J in L'First .. I - 1 => ...). The value of" & LF &
     "an object at loop entry is  X'Loop_Entry , NEVER X'Old (which is legal only in a postcondition). An existential" & LF &
     "is written  (for some J in R => P) , never  exists J in R | P . A while loop also carries" & LF &
     "pragma Loop_Variant (Increases => I)  or  (Decreases => N). Every local variable is initialised at its" & LF &
     "declaration. A search that returns the FIRST match scans forward from the first index and exits at the first" & LF &
     "hit; one that returns the LAST match scans in reverse." & LF & LF &
     "FORBIDDEN, each refuses the unit: pragma Assume, pragma Annotate (GNATprove, ...), SPARK_Mode => Off," & LF &
     "pragma Warnings (Off), Import. End with  end <Name>;  and nothing after it." & LF;

   function Gate_Hint (Word : String) return String is
     (if Word = "refused-compile" then
        "THE BODY DID NOT COMPILE: fix exactly the lines the compiler names below." & LF
      elsif Word = "refused-cheat" then
        "A PROOF-BYPASS CONSTRUCT WAS FOUND (pragma Assume, Annotate, SPARK_Mode => Off, Warnings (Off) or Import):" & LF &
        "remove it; the contract must be proved, not assumed." & LF
      elsif Word = "refused-assumed-body" then
        "A DECLARED SUBPROGRAM STILL HAS NO BODY: implement every subprogram the specification declares without an" & LF &
        "expression, in this package body." & LF
      elsif Word = "refused-no-checks" then
        "NO CHECKS WERE GENERATED: the body implements nothing the specification declares." & LF
      elsif Word = "refused-unproved" then
        "SOME CHECKS WERE NOT PROVED. The diagnosis below names the ONE thing to change; the prover's lines follow." & LF
      elsif Word = "refused-hygiene" then
        "AN IDIOM COULD NOT BE REPAIRED IN PLACE: write 'Loop_Entry (never 'Old) inside loop invariants and" & LF &
        "(for some J in R => P) for an existential." & LF
      else "");

   Max_Repair_Chars : constant := 32_768;   --  the repair section is bounded: the previous body and the rail's lines
   Max_Splices      : constant := 1_000;    --  idiom splices per round are bounded; beyond it the round is refused-hygiene

   procedure Run
     (Spec_Text : String;
      Unit_Name : String;
      Body_Text : out Ada.Strings.Unbounded.Unbounded_String;
      Result    : out Pipeline_Stage_Pkg.Outcome;
      Reason    : out Ada.Strings.Unbounded.Unbounded_String);

end Body_Fill_Activity_Pkg;
