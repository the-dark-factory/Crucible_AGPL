--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 54a666d9c0b773467fcb5b2111c8011285984f902ab31361c085bdeff7317311
--
with Diagnosis_Class_Pkg;

package Reasoner_Check_Pkg with SPARK_Mode is

   use type Diagnosis_Class_Pkg.Catalogue_Class;

   type Class_Set is record
      omission         : Boolean := False;
      inductive_strength : Boolean := False;
      hard_frame       : Boolean := False;
      idiom            : Boolean := False;
      logic            : Boolean := False;
   end record;

   type Check_Kind is (Agreed, Unsupported, No_Label);

   function Invariant_Fails (E : Diagnosis_Class_Pkg.Evidence) return Boolean
     is (E.invariant_fails_lines >= 1 or else E.not_preserved_lines >= 1);

   function Post_Fails (E : Diagnosis_Class_Pkg.Evidence) return Boolean
     is (E.post_fails_lines >= 1);

   function Evidence_Set (E : Diagnosis_Class_Pkg.Evidence) return Class_Set
     is ((idiom => E.body_has_loop and then (E.body_invariant_uses_old or else (E.body_has_while and then E.termination_lines >= 1)),
          hard_frame => E.body_has_loop and then (E.spec_uses_old or else E.spec_has_in_out) and then (Invariant_Fails (E) or else Post_Fails (E)),
          inductive_strength => E.body_has_loop and then E.body_has_invariant and then Invariant_Fails (E),
          omission => E.body_has_loop and then (Post_Fails (E) or else not E.body_has_invariant),
          logic => E.body_has_loop and then E.body_has_invariant and then Post_Fails (E) and then not Invariant_Fails (E)))
     with Post => ((if not E.body_has_loop then not Evidence_Set'Result.omission and then not Evidence_Set'Result.inductive_strength
                    and then not Evidence_Set'Result.hard_frame and then not Evidence_Set'Result.idiom and then not Evidence_Set'Result.logic)
                   and then (if Evidence_Set'Result.inductive_strength then E.body_has_invariant)
                   and then (if Evidence_Set'Result.logic then Post_Fails (E) and then not Invariant_Fails (E))
                   and then (if Evidence_Set'Result.hard_frame then E.spec_uses_old or else E.spec_has_in_out));

   function Supports (S : Class_Set; C : Diagnosis_Class_Pkg.Catalogue_Class) return Boolean
     is (case C is
           when Diagnosis_Class_Pkg.Omission => S.omission,
           when Diagnosis_Class_Pkg.Inductive_Strength => S.inductive_strength,
           when Diagnosis_Class_Pkg.Hard_Frame => S.hard_frame,
           when Diagnosis_Class_Pkg.Idiom => S.idiom,
           when Diagnosis_Class_Pkg.Logic => S.logic,
           when Diagnosis_Class_Pkg.Unclassified => False)
     with Post => (if C = Diagnosis_Class_Pkg.Unclassified then not Supports'Result);

   function Is_Empty (S : Class_Set) return Boolean
     is (not S.omission and then not S.inductive_strength and then not S.hard_frame and then not S.idiom and then not S.logic);

   function Check (Claimed : Diagnosis_Class_Pkg.Catalogue_Class; S : Class_Set) return Check_Kind
     is ((if Claimed = Diagnosis_Class_Pkg.Unclassified then No_Label
          elsif Supports (S, Claimed) then Agreed
          else Unsupported))
     with Post => (((Check'Result = Agreed) = (Claimed /= Diagnosis_Class_Pkg.Unclassified and then Supports (S, Claimed)))
                   and then (if Is_Empty (S) then Check'Result /= Agreed)
                   and then ((Check'Result = No_Label) = (Claimed = Diagnosis_Class_Pkg.Unclassified)));

   function Believed_Class (Claimed : Diagnosis_Class_Pkg.Catalogue_Class; S : Class_Set) return Diagnosis_Class_Pkg.Catalogue_Class
     is ((if Check (Claimed, S) = Agreed then Claimed else Diagnosis_Class_Pkg.Unclassified))
     with Post => ((if Believed_Class'Result /= Diagnosis_Class_Pkg.Unclassified then Supports (S, Believed_Class'Result))
                   and then (if Is_Empty (S) then Believed_Class'Result = Diagnosis_Class_Pkg.Unclassified));

end Reasoner_Check_Pkg;
