--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: f919a9f9ab3568e039056d213c08b55d807f34679659b1493dcdeba957250e3a
--
--  Diagnosis_Activity_Pkg -- the diagnosis step of CRUCIBLE's repair rounds (step 5a-3d/e), in process.
--  Purpose: from the prover's lines, the unit's spec and its body, produce ONE diagnosis paragraph for the next round —
--  its class chosen by the proven Diagnosis_Select_Pkg over the proven Diagnosis_Class_Pkg evidence; when no deterministic
--  class applies and the budget allows, a reasoner (the model rail) is asked, and its CLAIMED class is believed only when
--  Reasoner_Check_Pkg says the evidence supports it. This package decides nothing: it holds the hint TEXTS (the seat's
--  prose, the lane's measured healing texts) and the reasoner prompt, and calls the cores. Consumers: the body-fill
--  activity (5a-4) every round; the spec round (5a-2) never — a body-less round has no loop for these classes to speak of.
--  Usage:
--     S := Diagnosis_Select_Pkg.Fresh;  ... each failed round:
--     Diagnosis_Activity_Pkg.Diagnose (Lines, Spec, Body_Text, S, Text, Class_Word, Catalogue_Word, Source_Word);
with Ada.Strings.Unbounded;
with Diagnosis_Class_Pkg;
with Diagnosis_Select_Pkg;

package Diagnosis_Activity_Pkg with SPARK_Mode => Off is

   LF : constant Character := Character'Val (10);

   --  One paragraph per deterministic class: the texts the lane's diagnosis layer sends (measured to heal in a round).
   function Hint_Text (H : Diagnosis_Class_Pkg.Hint_Class) return String is
     (case H is
        when Diagnosis_Class_Pkg.Initialization =>
          "INITIALIZATION: a variable might be read before every component of it is written. Give it a complete value" & LF &
          "AT ITS DECLARATION, before any loop fills it -- for a String, X : String (1 .. N) := (others => ' '); for another" & LF &
          "array, (others => <a value of the component type>). Filling it element by element is not initialisation.",
        when Diagnosis_Class_Pkg.Termination =>
          "TERMINATION: a while or plain loop cannot be shown to terminate here. Add pragma Loop_Variant" & LF &
          "(Increases => <the index>) or (Decreases => <the remaining count>) as the first pragma of the loop body, or" & LF &
          "rewrite it as a for loop over a static range.",
        when Diagnosis_Class_Pkg.Frame_In_Place =>
          "FRAME / IN-PLACE: the postcondition compares against 'Old, but a loop invariant may NOT use 'Old. Take a" & LF &
          "snapshot before the loop (a constant copy, or X'Loop_Entry inside the invariant) and state the frame" & LF &
          "condition over it: every element outside the range touched so far equals its entry value.",
        when Diagnosis_Class_Pkg.Non_Inductive_Invariant =>
          "NON-INDUCTIVE INVARIANT: the invariant holds initially but not after an arbitrary iteration. Strengthen it" & LF &
          "so that, assuming it before the body, it holds again after: name every variable the body changes, with the" & LF &
          "relation between them the postcondition needs.",
        when Diagnosis_Class_Pkg.Wrong_Extremum =>
          "WRONG EXTREMUM: the invariants hold, only the postcondition fails -- the loop exits with the wrong element." & LF &
          "The contract asks for the LAST (or FIRST) occurrence and the body finds the other: scan in the opposite" & LF &
          "direction (for I in reverse ...), exit at the first match met, and state the invariant over the part scanned.",
        when Diagnosis_Class_Pkg.Missing_Prefix_Invariant =>
          "MISSING PREFIX INVARIANT: the postcondition cannot be carried out of the loop. Add a pragma Loop_Invariant" & LF &
          "at the END of the loop body stating the postcondition's property for the prefix scanned so far (quantify over" & LF &
          "A'First .. I), so that at loop exit the invariant IS the postcondition.",
        when Diagnosis_Class_Pkg.Placement =>
          "LOOP_INVARIANT PLACEMENT: pragma Loop_Invariant must appear immediately within the statements of the loop," & LF &
          "as the first statement(s) of the loop body, all invariants together, never inside an if or a nested block.",
        when Diagnosis_Class_Pkg.Discriminant =>
          "VARIANT RECORD BUILT FROM A RUNTIME DISCRIMINANT: an aggregate of a variant record needs a STATIC discriminant." & LF &
          "Branch on the variable, and write one aggregate per variant with a literal discriminant in each branch.",
        when Diagnosis_Class_Pkg.No_Hint => "");

   --  The reasoner is asked to name ONE catalogue class and a fix; its class is CHECKED before it is believed.
   Reasoner_Instruction : constant String :=
     "You are diagnosing a SPARK proof failure. Read the prover's lines, the specification and the body below." & LF &
     "First line of your answer, exactly:  CLASS: <one of omission | inductive_strength | hard_frame | idiom | logic>" & LF &
     "  omission = a loop invariant is missing; inductive_strength = an invariant exists but is not inductive;" & LF &
     "  hard_frame = an in-place mutation needs a frame condition; idiom = 'Old in an invariant, exists, a while loop" & LF &
     "  without a variant; logic = the invariants hold but the loop computes the wrong result." & LF &
     "Then, starting with  FIX:  say in at most four sentences what to change. The class you name is checked against" & LF &
     "the prover's lines, the body and the spec; a class they do not support is recorded as unclassified." & LF;

   Max_Lines_Chars : constant := 32_768;   --  the prover's lines are bounded before they enter a prompt

   procedure Diagnose
     (Lines          : String;   --  the prover's severity lines (5a-1), LF-separated
      Spec_Text      : String;
      Body_Text      : String;   --  "" for a spec-only round: the layer then speaks only where no loop is needed
      State          : in out Diagnosis_Select_Pkg.Select_State;
      Text           : out Ada.Strings.Unbounded.Unbounded_String;   --  the ONE paragraph, or empty
      Class_Word     : out Ada.Strings.Unbounded.Unbounded_String;   --  hint class or claimed class, lower-case
      Catalogue_Word : out Ada.Strings.Unbounded.Unbounded_String;   --  omission | inductive_strength | ... | unclassified
      Source_Word    : out Ada.Strings.Unbounded.Unbounded_String);  --  deterministic | reasoner-agreed | reasoner-unclassified | none

end Diagnosis_Activity_Pkg;
