--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 6a1556f87f8906c626474c9e33e380597313b03e52a068750108cf4a24dc8f3f
--
with Intake_Line_Pkg;
with Intake_Names_Pkg;
with Intake_Refusal_Pkg;

package Intake_Measure_Pkg with SPARK_Mode is

   use type Intake_Line_Pkg.Line_Kind;

   Max_Lines : constant := 512;

   subtype Line_Index is Positive range 1 .. Max_Lines;
   subtype Line_Count is Natural range 0 .. Max_Lines;
   subtype Text_Length is Natural range 0 .. Intake_Line_Pkg.Max_Line;

   type Sheet_Line is record
      Text : String (1 .. Intake_Line_Pkg.Max_Line);
      Len  : Text_Length;
   end record;

   type Line_Array is array (Line_Index) of Sheet_Line;

   type Sheet is record
      Lines : Line_Array;
      Count : Line_Count;
   end record;

   type Name_Place is record
      Line : Line_Count;
      Pos  : Text_Length;
   end record;

   function Text_Of (S : Sheet; I : Line_Index) return String is
     (S.Lines (I).Text (1 .. S.Lines (I).Len))
   with
     Pre  => I <= S.Count,
     Post => Text_Of'Result'First = 1 and then Text_Of'Result'Length = S.Lines (I).Len;

   function Kind (S : Sheet; I : Line_Index) return Intake_Line_Pkg.Line_Kind is
     (Intake_Line_Pkg.Kind_Of (Text_Of (S, I)))
   with
     Pre  => I <= S.Count,
     Post => (Kind'Result = Intake_Line_Pkg.Kind_Of (Text_Of (S, I)));

   function Is_Operation (S : Sheet; I : Line_Index) return Boolean is
     ((if Kind (S, I) in Intake_Line_Pkg.Function_Line | Intake_Line_Pkg.Other_Operation_Line then True else False))
   with
     Pre  => I <= S.Count,
     Post => (if Is_Operation'Result then Kind (S, I) /= Intake_Line_Pkg.Commentary_Line);

   function Has_Deliverable (S : Sheet) return Boolean is
     ((for some I in 1 .. S.Count => Kind (S, I) = Intake_Line_Pkg.Deliverable_Line))
   with
     Post => (if Has_Deliverable'Result then S.Count >= 1);

   function All_Named_As_Functions (S : Sheet) return Boolean is
     (((for some I in 1 .. S.Count => Is_Operation (S, I)) and then (for all I in 1 .. S.Count => (if Is_Operation (S, I) then Kind (S, I) = Intake_Line_Pkg.Function_Line)))
      or else False)
   with
     Post => (if All_Named_As_Functions'Result then S.Count >= 1);

   function Has_Post_After (S : Sheet; I : Line_Index) return Boolean is
     ((for some J in I + 1 .. S.Count => (Kind (S, J) = Intake_Line_Pkg.Post_Line and then (for all K in I + 1 .. J - 1 => not Is_Operation (S, K)))))
   with
     Pre  => I <= S.Count and then Is_Operation (S, I),
     Post => (if Has_Post_After'Result then I < S.Count);

   function Every_Operation_Has_Post (S : Sheet) return Boolean is
     ((for all I in 1 .. S.Count => (if Is_Operation (S, I) then Has_Post_After (S, I))))
   with
     Post => (if S.Count = 0 then Every_Operation_Has_Post'Result);

   function Declared_In (S : Sheet; I : Line_Index; P : Positive) return Boolean is
     ((for some J in 1 .. S.Count => Intake_Names_Pkg.Declares (Text_Of (S, J), Text_Of (S, I), P)))
   with
     Pre  => I <= S.Count and then P <= S.Lines (I).Len and then Intake_Line_Pkg.Is_Letter (S.Lines (I).Text (P)),
     Post => (if Declared_In'Result then S.Count >= 1);

   function Is_Undefined_At (S : Sheet; I : Line_Index; P : Positive) return Boolean is
     ((Kind (S, I) = Intake_Line_Pkg.Function_Line and then Intake_Names_Pkg.Is_Used_Name_Start (Text_Of (S, I), P) and then not Intake_Names_Pkg.Is_Known_Name (Text_Of (S, I), P) and then not Declared_In (S, I, P)))
   with
     Pre  => I <= S.Count and then P <= S.Lines (I).Len,
     Post => (if Is_Undefined_At'Result then Kind (S, I) = Intake_Line_Pkg.Function_Line and Intake_Line_Pkg.Is_Letter (S.Lines (I).Text (P)));

   function Operation_Count (S : Sheet) return Line_Count
   with
     Pre  => True,
     Post => (Operation_Count'Result <= S.Count and then ((Operation_Count'Result = 0) = (for all I in 1 .. S.Count => not Is_Operation (S, I))));

   function Undefined_Count (S : Sheet) return Natural
   with
     Pre  => True,
     Post => (Undefined_Count'Result <= S.Count * Intake_Line_Pkg.Max_Line and then ((Undefined_Count'Result = 0) = (for all I in 1 .. S.Count => (for all P in 1 .. S.Lines (I).Len => not Is_Undefined_At (S, I, P)))));

   function First_Undefined (S : Sheet) return Name_Place
   with
     Pre  => True,
     Post => ((if First_Undefined'Result.Line = 0 then (for all I in 1 .. S.Count => (for all P in 1 .. S.Lines (I).Len => not Is_Undefined_At (S, I, P)))) and then (if First_Undefined'Result.Line /= 0 then First_Undefined'Result.Line <= S.Count and then First_Undefined'Result.Pos in 1 .. S.Lines (First_Undefined'Result.Line).Len and then Is_Undefined_At (S, First_Undefined'Result.Line, First_Undefined'Result.Pos)));

   function Measure (S : Sheet) return Intake_Refusal_Pkg.Facts_Type is
     ((has_deliverable_clause => Has_Deliverable (S), operations_named_as_functions => All_Named_As_Functions (S), every_named_type_is_defined => (Undefined_Count (S) = 0), every_operation_has_postcondition => Every_Operation_Has_Post (S), undefined_name_count => Undefined_Count (S), operation_count => Operation_Count (S)))
   with
     Post => ((Measure'Result.has_deliverable_clause = Has_Deliverable (S)) and then (Measure'Result.operations_named_as_functions = All_Named_As_Functions (S)) and then (Measure'Result.every_named_type_is_defined = (Undefined_Count (S) = 0)) and then (Measure'Result.every_operation_has_postcondition = Every_Operation_Has_Post (S)) and then (Measure'Result.undefined_name_count = Undefined_Count (S)) and then (Measure'Result.operation_count = Operation_Count (S)));

end Intake_Measure_Pkg;
