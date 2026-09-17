--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 6510e90400f5468d99a29e36c7f688934572e5e6d6420ffc19eb061e0e8f4c76
--
with Diagnosis_Class_Pkg;

package Diagnosis_Select_Pkg with SPARK_Mode is

   use type Diagnosis_Class_Pkg.Hint_Class;

   Reasoner_After : constant := 2;

   subtype Round_Count is Integer range 0 .. 1_000;

   type Source_Kind is (Deterministic, Reasoner, Nothing);

   type Select_State is record
      last_class           : Diagnosis_Class_Pkg.Hint_Class := Diagnosis_Class_Pkg.No_Hint;
      deterministic_rounds : Round_Count := 0;
   end record;

   type Choice is record
      class  : Diagnosis_Class_Pkg.Hint_Class := Diagnosis_Class_Pkg.No_Hint;
      source : Source_Kind := Nothing;
   end record;

   function Fresh return Select_State
     is ((last_class => Diagnosis_Class_Pkg.No_Hint, deterministic_rounds => 0))
     with Post => Fresh'Result.deterministic_rounds = 0;

   function Reasoner_Eligible (S : Select_State) return Boolean
     is (S.deterministic_rounds >= Reasoner_After);

   function Choose (E : Diagnosis_Class_Pkg.Evidence; S : Select_State) return Choice
     is ((if Diagnosis_Class_Pkg.First_Hint_Except (E, S.last_class) /= Diagnosis_Class_Pkg.No_Hint
          then (class => Diagnosis_Class_Pkg.First_Hint_Except (E, S.last_class), source => Deterministic)
          elsif Reasoner_Eligible (S)
          then (class => Diagnosis_Class_Pkg.No_Hint, source => Reasoner)
          else (class => Diagnosis_Class_Pkg.No_Hint, source => Nothing)))
     with Post =>
       (if Choose'Result.source = Deterministic then Choose'Result.class /= Diagnosis_Class_Pkg.No_Hint) and
       (if Choose'Result.source = Deterministic then Diagnosis_Class_Pkg.Applies (E, Choose'Result.class)) and
       (Choose'Result.class /= S.last_class or else Choose'Result.class = Diagnosis_Class_Pkg.No_Hint) and
       (if Choose'Result.source = Reasoner then Reasoner_Eligible (S)) and
       (if Choose'Result.source /= Deterministic then Choose'Result.class = Diagnosis_Class_Pkg.No_Hint) and
       ((Choose'Result.source = Deterministic) = (Diagnosis_Class_Pkg.First_Hint_Except (E, S.last_class) /= Diagnosis_Class_Pkg.No_Hint));

   function Record_Sent (S : Select_State; C : Choice) return Select_State
     is ((last_class => (if C.source = Deterministic then C.class else S.last_class),
          deterministic_rounds => (if S.deterministic_rounds < 1_000 then S.deterministic_rounds + 1 else S.deterministic_rounds)))
     with Post =>
       (if C.source = Deterministic then Record_Sent'Result.last_class = C.class) and
       (if C.source /= Deterministic then Record_Sent'Result.last_class = S.last_class) and
       (if S.deterministic_rounds < 1_000 then Record_Sent'Result.deterministic_rounds = S.deterministic_rounds + 1) and
       (if S.deterministic_rounds = 1_000 then Record_Sent'Result.deterministic_rounds = S.deterministic_rounds);

end Diagnosis_Select_Pkg;
