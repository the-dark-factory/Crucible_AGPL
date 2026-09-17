--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 7af89b1e56c85443d6150c284e20bb7dbef245a09a2ff02b7b3278e255504d58
--
package Pipeline_Stage_Pkg with SPARK_Mode is

   type Stage is (Intake, Decompose, Emit_Contract, Prove_Spec, Vacuity, Fill_Body, Prove_Body, Seam, Provenance,
                  Admission, Emit, Done, Refused, Unmeasured);

   type Outcome is (Passed, Refused_Here, Unmeasured_Here);

   function Is_Terminal (S : Stage) return Boolean is
     (S = Done or else S = Refused or else S = Unmeasured)
     with Post => (Is_Terminal'Result = (S = Done or else S = Refused or else S = Unmeasured));

   function Following (S : Stage) return Stage is
     (case S is
        when Intake => Decompose,
        when Decompose => Emit_Contract,
        when Emit_Contract => Prove_Spec,
        when Prove_Spec => Vacuity,
        when Vacuity => Fill_Body,
        when Fill_Body => Prove_Body,
        when Prove_Body => Seam,
        when Seam => Provenance,
        when Provenance => Admission,
        when Admission => Emit,
        when Emit => Done,
        when Done => Done,
        when Refused => Refused,
        when Unmeasured => Unmeasured)
     with Post => ((Following'Result = Emit) = (S = Admission)) and then
                  (if not Is_Terminal (S) then Stage'Pos (Following'Result) = Stage'Pos (S) + 1);

   function Next (S : Stage; O : Outcome) return Stage is
     (if Is_Terminal (S) then S
      elsif O = Passed then Following (S)
      elsif O = Refused_Here then Refused
      else Unmeasured)
     with Post => ((Next'Result = Emit) = (S = Admission and then O = Passed)) and then
                  (if Is_Terminal (S) then Next'Result = S) and then
                  ((Next'Result = Refused) = (S = Refused or else (not Is_Terminal (S) and then O = Refused_Here))) and then
                  ((Next'Result = Unmeasured) = (S = Unmeasured or else (not Is_Terminal (S) and then O = Unmeasured_Here))) and then
                  (if not Is_Terminal (S) then Stage'Pos (Next'Result) > Stage'Pos (S));

end Pipeline_Stage_Pkg;
