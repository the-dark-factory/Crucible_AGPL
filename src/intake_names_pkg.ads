--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: f0cca05118d59a5cf03816cee356036049d119ba91a6b4152cdb8e26827c8cb5
--
with Intake_Line_Pkg;

package Intake_Names_Pkg with SPARK_Mode is

   use type Intake_Line_Pkg.Line_Kind;

   function After_Colon (Line : String; P : Positive) return Boolean is
     ((P in Line'Range and then
       Intake_Line_Pkg.Is_Letter (Line (P)) and then
       (for some Q in Line'First .. P - 1 =>
         Line (Q) = ':' and then
         (for all R in Q + 1 .. P - 1 => Intake_Line_Pkg.Is_Space (Line (R))))))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Intake_Line_Pkg.Max_Line and then P in Line'Range,
     Post => ((if After_Colon'Result then P >= 2 and then Intake_Line_Pkg.Is_Letter (Line (P)) and then (Line (P - 1) = ':' or else Intake_Line_Pkg.Is_Space (Line (P - 1)))));

   function After_Return (Line : String; P : Positive) return Boolean is
     ((P in Line'Range and then
       Intake_Line_Pkg.Is_Letter (Line (P)) and then
       (for some Q in Line'First .. P - 8 =>
         (Q = 1 or else Intake_Line_Pkg.Is_Space (Line (Q - 1))) and then
         (Q + 6 <= Line'Last and then Line (Q .. Q + 5) = "return") and then
         (for all R in Q + 6 .. P - 1 => Intake_Line_Pkg.Is_Space (Line (R))))))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Intake_Line_Pkg.Max_Line and then P in Line'Range,
     Post => ((if After_Return'Result then P >= 8 and then Intake_Line_Pkg.Is_Letter (Line (P)) and then Intake_Line_Pkg.Is_Space (Line (P - 1))));

   function Is_Used_Name_Start (Line : String; P : Positive) return Boolean is
     ((After_Colon (Line, P) or else After_Return (Line, P)))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Intake_Line_Pkg.Max_Line and then P in Line'Range,
     Post => ((if Is_Used_Name_Start'Result then Intake_Line_Pkg.Is_Letter (Line (P)) and then P >= 2) and then
              (if P >= 2 and then Line (P - 1) /= ':' and then not Intake_Line_Pkg.Is_Space (Line (P - 1)) then not Is_Used_Name_Start'Result));

   function Used_Name_End (Line : String; P : Positive) return Positive is
     (Intake_Line_Pkg.Name_Last (Line, P))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Intake_Line_Pkg.Max_Line and then P in Line'Range and then Is_Used_Name_Start (Line, P),
     Post => ((Used_Name_End'Result >= P and then Used_Name_End'Result <= Line'Last) and then
              (for all I in P .. Used_Name_End'Result => Intake_Line_Pkg.Is_Name_Char (Line (I))) and then
              (if Used_Name_End'Result < Line'Last then not Intake_Line_Pkg.Is_Name_Char (Line (Used_Name_End'Result + 1))));

   function Name_Is (Line : String; P : Positive; Word : String) return Boolean is
     ((P in Line'Range and then
       Intake_Line_Pkg.Is_Letter (Line (P)) and then
       Intake_Line_Pkg.Name_Last (Line, P) - P + 1 = Word'Length and then
       (if Word'Length > 0 then P + Word'Length - 1 <= Line'Last and then Line (P .. P + Word'Length - 1) = Word)))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Intake_Line_Pkg.Max_Line and then P in Line'Range and then Intake_Line_Pkg.Is_Letter (Line (P)) and then Word'First = 1 and then Word'Length in 1 .. 16,
     Post => ((if Name_Is'Result then Line (P) = Word (Word'First) and then Intake_Line_Pkg.Name_Last (Line, P) - P + 1 = Word'Length));

   function Is_Known_Name (Line : String; P : Positive) return Boolean is
     ((Name_Is (Line, P, "Integer") or else
       Name_Is (Line, P, "Natural") or else
       Name_Is (Line, P, "Positive") or else
       Name_Is (Line, P, "Boolean") or else
       Name_Is (Line, P, "Character") or else
       Name_Is (Line, P, "String")))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Intake_Line_Pkg.Max_Line and then P in Line'Range and then Intake_Line_Pkg.Is_Letter (Line (P)),
     Post => ((if Is_Known_Name'Result then (Intake_Line_Pkg.Name_Last (Line, P) - P + 1 >= 6 and then Intake_Line_Pkg.Name_Last (Line, P) - P + 1 <= 9) and then
               (Line (P) = 'I' or else Line (P) = 'N' or else Line (P) = 'P' or else Line (P) = 'B' or else Line (P) = 'C' or else Line (P) = 'S')));

   function Same_Name (A : String; PA : Positive; B : String; PB : Positive) return Boolean is
     ((PA in A'Range and then
       PB in B'Range and then
       Intake_Line_Pkg.Is_Letter (A (PA)) and then
       Intake_Line_Pkg.Is_Letter (B (PB)) and then
       Intake_Line_Pkg.Name_Last (A, PA) - PA = Intake_Line_Pkg.Name_Last (B, PB) - PB and then
       (for all I in 0 .. Intake_Line_Pkg.Name_Last (A, PA) - PA => A (PA + I) = B (PB + I))))
   with
     Pre  => A'First = 1 and then A'Last in 0 .. Intake_Line_Pkg.Max_Line and then B'First = 1 and then B'Last in 0 .. Intake_Line_Pkg.Max_Line and then PA in A'Range and then PB in B'Range and then Intake_Line_Pkg.Is_Letter (A (PA)) and then Intake_Line_Pkg.Is_Letter (B (PB)),
     Post => ((if Same_Name'Result then A (PA) = B (PB) and then Intake_Line_Pkg.Name_Last (A, PA) - PA = Intake_Line_Pkg.Name_Last (B, PB) - PB));

   function Declares (T : String; Line : String; P : Positive) return Boolean is
     ((Intake_Line_Pkg.Kind_Of (T) = Intake_Line_Pkg.Type_Line and then
       Same_Name (T, Intake_Line_Pkg.Name_First (T), Line, P)))
   with
     Pre  => T'First = 1 and then T'Last in 0 .. Intake_Line_Pkg.Max_Line and then Line'First = 1 and then Line'Last in 0 .. Intake_Line_Pkg.Max_Line and then P in Line'Range and then Intake_Line_Pkg.Is_Letter (Line (P)),
     Post => ((if Declares'Result then Intake_Line_Pkg.Kind_Of (T) = Intake_Line_Pkg.Type_Line and then T (Intake_Line_Pkg.Name_First (T)) = Line (P)) and then
              (if Intake_Line_Pkg.Kind_Of (T) /= Intake_Line_Pkg.Type_Line then not Declares'Result));

end Intake_Names_Pkg;
