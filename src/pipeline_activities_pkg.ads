--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: b617681e96618faa4a7559e7a1edd080d301bb57361a1d8e1646a7712c6b90f0
--
--  Pipeline_Activities_Pkg -- the in-process MASCOT activities of CRUCIBLE's pipeline that need no model (step 4c unit 3).
--  Purpose: each activity gathers the facts for ONE stage and returns that stage's outcome as decided by a proven core;
--  none decides anything itself. Stage outcomes come from Stage_Outcome_Map_Pkg (proven), which judges the verdicts of
--  Intake_Refusal_Pkg and Prover_Rail_Pkg. An OWED stage (not yet built; step 5a) is always Unmeasured_Here, never Passed.
--  Audit appends each transition to the proven in-memory Audit_Ledger_Pkg and writes the same event as one JSON line to
--  state/audit.jsonl (append-only file).
--  Usage (one transition):
--     Run_Intake (Sheet, O, Reason);  Audit (Ledger, Seq, Pipeline_Stage_Pkg.Intake, O, To_String (Reason));
with Ada.Strings.Unbounded;
with Pipeline_Stage_Pkg;
with Audit_Ledger_Pkg;

package Pipeline_Activities_Pkg with SPARK_Mode => Off is

   Audit_Path : constant String := "state/audit.jsonl";

   procedure Run_Intake
     (Sheet  : String;
      Result : out Pipeline_Stage_Pkg.Outcome;
      Reason : out Ada.Strings.Unbounded.Unbounded_String);

   procedure Run_Prove
     (Unit_Name : String;
      Spec_Text : String;
      Body_Text : String;
      Level     : Natural;
      Result    : out Pipeline_Stage_Pkg.Outcome;
      Reason    : out Ada.Strings.Unbounded.Unbounded_String);

   procedure Run_Owed
     (Result : out Pipeline_Stage_Pkg.Outcome;
      Reason : out Ada.Strings.Unbounded.Unbounded_String);

   procedure Audit
     (Ledger : in out Audit_Ledger_Pkg.Ledger;
      Seq    : Natural;
      S      : Pipeline_Stage_Pkg.Stage;
      O      : Pipeline_Stage_Pkg.Outcome;
      Reason : String);

end Pipeline_Activities_Pkg;
