--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 8cee5f18e16e70cae7bd985a5439b4547ce43047912d05f56b07b9cd6a929621
--
package Body_Hygiene_Pkg with SPARK_Mode is

   Max_Text : constant := 65_536;
   Max_Word : constant := 32;
   LF : constant Character := Character'Val (10);

   function Is_Space (C : Character) return Boolean is
     (C = ' ' or else C = LF or else C = Character'Val (13) or else C = Character'Val (9));

   function Is_Upper (C : Character) return Boolean is
     (C in 'A' .. 'Z');

   function Lower_Eq (A : Character; B : Character) return Boolean is
     (A = B or else (Is_Upper (A) and then Character'Pos (A) + 32 = Character'Pos (B)) or else
      (Is_Upper (B) and then Character'Pos (B) + 32 = Character'Pos (A)));

   function Is_Ident_Char (C : Character) return Boolean is
     (C in 'A' .. 'Z' or else C in 'a' .. 'z' or else C in '0' .. '9' or else C = '_');

   function Starts_With_CI (Text : String; P : Positive; Pattern : String) return Boolean is
     (P + Pattern'Length - 1 <= Text'Length and then
      (for all K in 0 .. Pattern'Length - 1 => Lower_Eq (Text (P + K), Pattern (1 + K))))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Pattern'First = 1
                 and then Pattern'Length >= 1 and then Pattern'Length <= Max_Word
                 and then P <= Text'Length + 1;

   function Token_At (Text : String; P : Positive; Word : String) return Boolean is
     (Starts_With_CI (Text, P, Word) and then
      (P = 1 or else not Is_Ident_Char (Text (P - 1))) and then
      (P + Word'Length > Text'Length or else not Is_Ident_Char (Text (P + Word'Length))))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Word'First = 1
                 and then Word'Length >= 1 and then Word'Length <= Max_Word
                 and then P <= Text'Length + 1;

   function Aspect_Word_At (Text : String; Q : Positive) return Boolean is
     (Token_At (Text, Q, "pre") or else Token_At (Text, Q, "post") or else
      Token_At (Text, Q, "subprogram_variant") or else Token_At (Text, Q, "contract_cases"))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Q <= Text'Length + 1;

   function Aspect_Start (Text : String; S : Positive) return Boolean is
     (Token_At (Text, S, "with") and then
      (for some Q in S + 4 .. Text'Length =>
         (for all K in S + 4 .. Q - 1 => Is_Space (Text (K))) and then Aspect_Word_At (Text, Q)))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then S <= Text'Length;

   function In_Aspect_Region (Text : String; I : Positive) return Boolean is
     ((for some S in 1 .. I =>
        Aspect_Start (Text, S) and then (for all K in S .. I => not Token_At (Text, K, "is"))))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length;

   procedure Blank_Aspects (T : in out String)
     with Pre => T'First = 1 and then T'Length <= Max_Text,
          Post => (for all I in 1 .. T'Length =>
                    T (I) = (if In_Aspect_Region (T'Old, I) and then T'Old (I) /= LF then ' ' else T'Old (I)));

   function Head_Is_At (Text : String; E : Positive) return Boolean is
     (Token_At (Text, E, "is") and then
      (for some P in 1 .. E - 1 =>
         Token_At (Text, P, "package") and then
         (for some Q in P + 8 .. E - 1 => Token_At (Text, Q, "body")) and then
         (for all K in P .. E - 1 => not Token_At (Text, K, "is")) and then
         (for all K in P .. E - 1 => Text (K) /= ';')))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then E <= Text'Length;

   function Spark_Mode_Before (Text : String; E : Positive) return Boolean is
     ((for some Q in 1 .. E - 1 =>
        Token_At (Text, Q, "spark_mode") and then (for all K in Q .. E - 1 => Text (K) /= ';')))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then E <= Text'Length;

   function First_Head_Is (Text : String) return Natural
     with Pre => Text'First = 1 and then Text'Length <= Max_Text,
          Post => First_Head_Is'Result in 0 .. Text'Length and then
                  (if First_Head_Is'Result >= 1 then Head_Is_At (Text, First_Head_Is'Result)) and then
                  (for all E in 1 .. First_Head_Is'Result - 1 => not Head_Is_At (Text, E)) and then
                  (if First_Head_Is'Result = 0 then (for all E in 1 .. Text'Length => not Head_Is_At (Text, E)));

   function Needs_Spark_Mode (Spec : String; Body_Text : String) return Boolean is
     ((for some Q in 1 .. Spec'Length => Token_At (Spec, Q, "spark_mode")) and then
      First_Head_Is (Body_Text) >= 1 and then
      not Spark_Mode_Before (Body_Text, First_Head_Is (Body_Text)))
     with Pre => Spec'First = 1 and then Spec'Length <= Max_Text and then
                 Body_Text'First = 1 and then Body_Text'Length <= Max_Text;

end Body_Hygiene_Pkg;
