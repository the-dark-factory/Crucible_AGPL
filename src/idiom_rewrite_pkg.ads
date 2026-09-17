--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 62f064db8b5539ce6ab88f75cbb899bcaf849ff67581761f5406ff4e48e627c3
--
with Body_Hygiene_Pkg;

package Idiom_Rewrite_Pkg with SPARK_Mode is

   function Old_At (Text : String; I : Positive) return Boolean is
     (Body_Hygiene_Pkg.Starts_With_CI (Text, I, "'old") and then
      (I + 4 > Text'Length or else not Body_Hygiene_Pkg.Is_Ident_Char (Text (I + 4))))
     with Pre => Text'First = 1 and then Text'Length <= Body_Hygiene_Pkg.Max_Text and then I <= Text'Length;

   function In_Invariant (Text : String; I : Positive) return Boolean is
     ((for some S in 1 .. I =>
        Body_Hygiene_Pkg.Token_At (Text, S, "loop_invariant") and then
        (for all K in S .. I => Text (K) /= ';')))
     with Pre => Text'First = 1 and then Text'Length <= Body_Hygiene_Pkg.Max_Text and then I <= Text'Length;

   function Old_In_Invariant_At (Text : String; I : Positive) return Boolean is
     (Old_At (Text, I) and then In_Invariant (Text, I))
     with Pre => Text'First = 1 and then Text'Length <= Body_Hygiene_Pkg.Max_Text and then I <= Text'Length;

   function First_Old_In_Invariant (Text : String) return Natural
     with Pre => Text'First = 1 and then Text'Length <= Body_Hygiene_Pkg.Max_Text,
          Post => First_Old_In_Invariant'Result in 0 .. Text'Length and
                  (if First_Old_In_Invariant'Result >= 1 then Old_In_Invariant_At (Text, First_Old_In_Invariant'Result)) and
                  (for all I in 1 .. First_Old_In_Invariant'Result - 1 => not Old_In_Invariant_At (Text, I)) and
                  (if First_Old_In_Invariant'Result = 0 then (for all I in 1 .. Text'Length => not Old_In_Invariant_At (Text, I)));

   function Clean_Of_Old (Text : String) return Boolean is
     ((for all I in 1 .. Text'Length => not Old_In_Invariant_At (Text, I)))
     with Pre => Text'First = 1 and then Text'Length <= Body_Hygiene_Pkg.Max_Text;

   function Exists_At (Text : String; I : Positive) return Boolean is
     ((Body_Hygiene_Pkg.Token_At (Text, I, "exists") and then
       (for some J in I + 7 .. Text'Length =>
          (for all K in I + 6 .. J - 1 => Body_Hygiene_Pkg.Is_Space (Text (K))) and then
          Body_Hygiene_Pkg.Is_Ident_Char (Text (J)) and then
          (for some M in J + 1 .. Text'Length =>
             (for all K in J .. M - 1 => Body_Hygiene_Pkg.Is_Ident_Char (Text (K)) or else Body_Hygiene_Pkg.Is_Space (Text (K))) and then
             Body_Hygiene_Pkg.Token_At (Text, M, "in") and then
             (for some B in M + 2 .. Text'Length =>
                Text (B) = '|' and then
                (for all K in M + 2 .. B - 1 => Text (K) /= '|' and then Text (K) /= ';'))))))
     with Pre => Text'First = 1 and then Text'Length <= Body_Hygiene_Pkg.Max_Text and then I <= Text'Length;

   function First_Exists (Text : String) return Natural
     with Pre => Text'First = 1 and then Text'Length <= Body_Hygiene_Pkg.Max_Text,
          Post => First_Exists'Result in 0 .. Text'Length and
                  (if First_Exists'Result >= 1 then Exists_At (Text, First_Exists'Result)) and
                  (for all I in 1 .. First_Exists'Result - 1 => not Exists_At (Text, I)) and
                  (if First_Exists'Result = 0 then (for all I in 1 .. Text'Length => not Exists_At (Text, I)));

   function Bar_After (Text : String; E : Positive) return Positive
     with Pre => Text'First = 1 and then Text'Length <= Body_Hygiene_Pkg.Max_Text and then E <= Text'Length and then Exists_At (Text, E),
          Post => Bar_After'Result in E + 7 .. Text'Length and
                  Text (Bar_After'Result) = '|' and
                  (for all K in E + 7 .. Bar_After'Result - 1 => Text (K) /= '|');

   function Clean_Of_Exists (Text : String) return Boolean is
     ((for all I in 1 .. Text'Length => not Exists_At (Text, I)))
     with Pre => Text'First = 1 and then Text'Length <= Body_Hygiene_Pkg.Max_Text;

end Idiom_Rewrite_Pkg;
