--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: fc12e3e89bf18dcc387608ff0c5e67f50ce811dc8feb990f3528e5e80e604beb
--
with Pipeline_Stage_Pkg;

package Job_Record_Pkg with SPARK_Mode is

   use type Pipeline_Stage_Pkg.Stage;
   use type Pipeline_Stage_Pkg.Outcome;

   type Job is record
      intake_passed        : Boolean := False;
      decompose_passed     : Boolean := False;
      emit_contract_passed : Boolean := False;
      prove_spec_passed    : Boolean := False;
      vacuity_passed       : Boolean := False;
      fill_body_passed     : Boolean := False;
      prove_body_passed    : Boolean := False;
      seam_passed          : Boolean := False;
      provenance_passed    : Boolean := False;
      admission_passed     : Boolean := False;
      reached              : Pipeline_Stage_Pkg.Stage := Pipeline_Stage_Pkg.Intake;
   end record;

   Fresh : constant Job := (others => <>);

   function Record_Outcome (J : Job; S : Pipeline_Stage_Pkg.Stage; O : Pipeline_Stage_Pkg.Outcome) return Job is
     ((intake_passed        => J.intake_passed        or else (S = Pipeline_Stage_Pkg.Intake        and then O = Pipeline_Stage_Pkg.Passed),
       decompose_passed     => J.decompose_passed     or else (S = Pipeline_Stage_Pkg.Decompose     and then O = Pipeline_Stage_Pkg.Passed),
       emit_contract_passed => J.emit_contract_passed or else (S = Pipeline_Stage_Pkg.Emit_Contract and then O = Pipeline_Stage_Pkg.Passed),
       prove_spec_passed    => J.prove_spec_passed    or else (S = Pipeline_Stage_Pkg.Prove_Spec    and then O = Pipeline_Stage_Pkg.Passed),
       vacuity_passed       => J.vacuity_passed       or else (S = Pipeline_Stage_Pkg.Vacuity       and then O = Pipeline_Stage_Pkg.Passed),
       fill_body_passed     => J.fill_body_passed     or else (S = Pipeline_Stage_Pkg.Fill_Body     and then O = Pipeline_Stage_Pkg.Passed),
       prove_body_passed    => J.prove_body_passed    or else (S = Pipeline_Stage_Pkg.Prove_Body    and then O = Pipeline_Stage_Pkg.Passed),
       seam_passed          => J.seam_passed          or else (S = Pipeline_Stage_Pkg.Seam          and then O = Pipeline_Stage_Pkg.Passed),
       provenance_passed    => J.provenance_passed    or else (S = Pipeline_Stage_Pkg.Provenance    and then O = Pipeline_Stage_Pkg.Passed),
       admission_passed     => J.admission_passed     or else (S = Pipeline_Stage_Pkg.Admission     and then O = Pipeline_Stage_Pkg.Passed),
       reached              => Pipeline_Stage_Pkg.Next (S, O)))
     with Post =>
       (Record_Outcome'Result.intake_passed        = J.intake_passed        or else (S = Pipeline_Stage_Pkg.Intake        and then O = Pipeline_Stage_Pkg.Passed)) and then
       (Record_Outcome'Result.decompose_passed     = J.decompose_passed     or else (S = Pipeline_Stage_Pkg.Decompose     and then O = Pipeline_Stage_Pkg.Passed)) and then
       (Record_Outcome'Result.emit_contract_passed = J.emit_contract_passed or else (S = Pipeline_Stage_Pkg.Emit_Contract and then O = Pipeline_Stage_Pkg.Passed)) and then
       (Record_Outcome'Result.prove_spec_passed    = J.prove_spec_passed    or else (S = Pipeline_Stage_Pkg.Prove_Spec    and then O = Pipeline_Stage_Pkg.Passed)) and then
       (Record_Outcome'Result.vacuity_passed       = J.vacuity_passed       or else (S = Pipeline_Stage_Pkg.Vacuity       and then O = Pipeline_Stage_Pkg.Passed)) and then
       (Record_Outcome'Result.fill_body_passed     = J.fill_body_passed     or else (S = Pipeline_Stage_Pkg.Fill_Body     and then O = Pipeline_Stage_Pkg.Passed)) and then
       (Record_Outcome'Result.prove_body_passed    = J.prove_body_passed    or else (S = Pipeline_Stage_Pkg.Prove_Body    and then O = Pipeline_Stage_Pkg.Passed)) and then
       (Record_Outcome'Result.seam_passed          = J.seam_passed          or else (S = Pipeline_Stage_Pkg.Seam          and then O = Pipeline_Stage_Pkg.Passed)) and then
       (Record_Outcome'Result.provenance_passed    = J.provenance_passed    or else (S = Pipeline_Stage_Pkg.Provenance    and then O = Pipeline_Stage_Pkg.Passed)) and then
       (Record_Outcome'Result.admission_passed     = J.admission_passed     or else (S = Pipeline_Stage_Pkg.Admission     and then O = Pipeline_Stage_Pkg.Passed)) and then
       (Record_Outcome'Result.reached              = Pipeline_Stage_Pkg.Next (S, O));

   function May_Emit (J : Job) return Boolean is
     (J.intake_passed and then J.decompose_passed and then J.emit_contract_passed and then J.prove_spec_passed
      and then J.vacuity_passed and then J.fill_body_passed and then J.prove_body_passed and then J.seam_passed
      and then J.provenance_passed and then J.admission_passed)
     with Post =>
       (May_Emit'Result = (J.intake_passed and then J.decompose_passed and then J.emit_contract_passed
        and then J.prove_spec_passed and then J.vacuity_passed and then J.fill_body_passed and then J.prove_body_passed
        and then J.seam_passed and then J.provenance_passed and then J.admission_passed));

end Job_Record_Pkg;
