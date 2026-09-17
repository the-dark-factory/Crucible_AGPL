--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 3337add41342f325fbd5f536ae3724f38cf3f5f540e18fc6cfcccbff208e7629
--
package Unit_Extract_Pkg with SPARK_Mode is

   Max_Text : constant := 65_536;
   Max_Name : constant := 64;
   LF : constant Character := Character'Val (10);
   Think_End : constant String := "</think>";
   Fence : constant String := "```";
   Fence_Ada : constant String := "```ada";

   function Is_Space (C : Character) return Boolean is
     (C = ' ' or else C = LF or else C = Character'Val (13) or else C = Character'Val (9));

   function Is_Upper (C : Character) return Boolean is
     (C in 'A' .. 'Z');

   function Lower_Eq (A : Character; B : Character) return Boolean is
     (A = B or else (Is_Upper (A) and then Character'Pos (A) + 32 = Character'Pos (B)) or else (Is_Upper (B) and then Character'Pos (B) + 32 = Character'Pos (A)));

   function Is_Ascii (Text : String) return Boolean is
     (for all I in Text'Range => Character'Pos (Text (I)) < 128);

   function Starts_With_CI (Text : String; P : Positive; Pattern : String) return Boolean is
     (P + Pattern'Length - 1 <= Text'Length and then
      (for all K in 0 .. Pattern'Length - 1 => Lower_Eq (Text (P + K), Pattern (1 + K))))
   with
     Pre =>
       Text'First = 1 and then Text'Length <= Max_Text and then Pattern'First = 1 and then Pattern'Length >= 1 and then Pattern'Length <= Max_Name + 8 and then P <= Text'Length + 1;

   function After_Think (Text : String) return Positive
   with
     Pre =>
       Text'First = 1 and then Text'Length <= Max_Text,
     Post =>
       After_Think'Result in 1 .. Text'Length + 1 and
       (After_Think'Result = 1 or else (After_Think'Result >= 9 and then Text (After_Think'Result - 8 .. After_Think'Result - 1) = Think_End)) and
       (for all I in After_Think'Result .. Text'Length - 7 => Text (I .. I + 7) /= Think_End);

   function First_Content (Text : String; From : Positive) return Positive
   with
     Pre =>
       Text'First = 1 and then Text'Length <= Max_Text and then From <= Text'Length + 1,
     Post =>
       First_Content'Result in From .. Text'Length + 1 and
       (for all I in From .. First_Content'Result - 1 => Is_Space (Text (I))) and
       (if First_Content'Result <= Text'Length then not Is_Space (Text (First_Content'Result)));

   function Last_Content (Text : String) return Natural
   with
     Pre =>
       Text'First = 1 and then Text'Length <= Max_Text,
     Post =>
       Last_Content'Result in 0 .. Text'Length and
       (for all I in Last_Content'Result + 1 .. Text'Length => Is_Space (Text (I))) and
       (if Last_Content'Result >= 1 then not Is_Space (Text (Last_Content'Result)));

   function Begins_Unit (Text : String; P : Positive) return Boolean is
     (Starts_With_CI (Text, P, "with ") or else Starts_With_CI (Text, P, "package "))
   with
     Pre =>
       Text'First = 1 and then Text'Length <= Max_Text and then P <= Text'Length + 1;

   function Names_Package (Text : String; From : Positive; Name : String) return Boolean is
     (for some I in From .. Text'Length =>
        Starts_With_CI (Text, I, "package ") and then Starts_With_CI (Text, I + 8, Name) and then I + 8 + Name'Length <= Text'Length and then Is_Space (Text (I + 8 + Name'Length)))
   with
     Pre =>
       Text'First = 1 and then Text'Length <= Max_Text and then From <= Text'Length + 1 and then Name'First = 1 and then Name'Length >= 1 and then Name'Length <= Max_Name;

   function Ends_Unit (Text : String; L : Natural; Name : String) return Boolean is
     (L >= Name'Length + 5 and then Starts_With_CI (Text, L - Name'Length - 4, "end ") and then Starts_With_CI (Text, L - Name'Length, Name) and then Text (L) = ';')
   with
     Pre =>
       Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length and then Name'First = 1 and then Name'Length >= 1 and then Name'Length <= Max_Name;

   function Line_Start (T : String; I : Positive) return Boolean is
     (I = 1 or else T (I - 1) = LF)
   with
     Pre =>
       T'First = 1 and then T'Length <= Max_Text and then I <= T'Length;

   function Fence_Line_At (T : String; S : Positive) return Boolean is
     (Line_Start (T, S) and then ((Starts_With_CI (T, S, Fence) and then (S + 3 > T'Length or else T (S + 3) = LF)) or else (Starts_With_CI (T, S, Fence_Ada) and then (S + 6 > T'Length or else T (S + 6) = LF))))
   with
     Pre =>
       T'First = 1 and then T'Length <= Max_Text and then S <= T'Length;

   function In_Fence_Line (T : String; I : Positive) return Boolean is
     (for some S in 1 .. I => Fence_Line_At (T, S) and then (for all K in S .. I => T (K) /= LF))
   with
     Pre =>
       T'First = 1 and then T'Length <= Max_Text and then I <= T'Length;

   procedure Blank_Fences (T : in out String)
   with
     Pre =>
       T'First = 1 and then T'Length <= Max_Text,
     Post =>
       (for all I in 1 .. T'Length => T (I) = (if In_Fence_Line (T'Old, I) then ' ' else T'Old (I)));

   function Is_Unit (Text : String; Name : String) return Boolean is
     (Is_Ascii (Text) and then First_Content (Text, After_Think (Text)) <= Text'Length and then Begins_Unit (Text, First_Content (Text, After_Think (Text))) and then Names_Package (Text, First_Content (Text, After_Think (Text)), Name) and then Last_Content (Text) >= 1 and then Ends_Unit (Text, Last_Content (Text), Name))
   with
     Pre =>
       Text'First = 1 and then Text'Length <= Max_Text and then Name'First = 1 and then Name'Length >= 1 and then Name'Length <= Max_Name,
     Post =>
       (if Is_Unit'Result then Is_Ascii (Text)) and
       (if Is_Unit'Result then Begins_Unit (Text, First_Content (Text, After_Think (Text)))) and
       (if Is_Unit'Result then Ends_Unit (Text, Last_Content (Text), Name)) and
       (if not Is_Ascii (Text) then not Is_Unit'Result);

end Unit_Extract_Pkg;
