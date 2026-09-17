--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 850ca0039173f6780fcee0784ab78dd9ac92173226adb7ad905ae5a68d6736e6
--
package Intake_Line_Pkg with SPARK_Mode is

   Max_Line : constant := 1024;

   type Line_Kind is (Deliverable_Line, Post_Line, Other_Operation_Line, Type_Line, Function_Line, Commentary_Line);

   function Is_Space (C : Character) return Boolean is
     (C = ' ' or else C = Character'Val (9))
   with
     Pre  => True;

   function Is_Letter (C : Character) return Boolean is
     ((C in 'A' .. 'Z') or else (C in 'a' .. 'z'))
   with
     Pre  => True;

   function Is_Name_Char (C : Character) return Boolean is
     (Is_Letter (C) or else C in '0' .. '9' or else C = '_')
   with
     Pre  => True;

   function Skip_Spaces (Line : String; From : Positive) return Positive
   with
     Global => null,
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line and then From >= Line'First and then From <= Line'Last + 1,
     Post => (Skip_Spaces'Result >= From and then Skip_Spaces'Result <= Line'Last + 1 and then
              (for all I in From .. Skip_Spaces'Result - 1 => Is_Space (Line (I))) and then
              (if Skip_Spaces'Result <= Line'Last then not Is_Space (Line (Skip_Spaces'Result))));

   function Word_Last (Line : String; From : Positive) return Positive
   with
     Global => null,
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line and then From >= Line'First and then From <= Line'Last and then not Is_Space (Line (From)),
     Post => (Word_Last'Result >= From and then Word_Last'Result <= Line'Last and then
              (for all I in From .. Word_Last'Result => not Is_Space (Line (I))) and then
              (if Word_Last'Result < Line'Last then Is_Space (Line (Word_Last'Result + 1))));

   function Name_Last (Line : String; From : Positive) return Positive
   with
     Global => null,
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line and then From >= Line'First and then From <= Line'Last and then Is_Letter (Line (From)),
     Post => (Name_Last'Result >= From and then Name_Last'Result <= Line'Last and then
              (for all I in From .. Name_Last'Result => Is_Name_Char (Line (I))) and then
              (if Name_Last'Result < Line'Last then not Is_Name_Char (Line (Name_Last'Result + 1))));

   function Second_Word_First (Line : String) return Positive
   with
     Global => null,
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line and then Skip_Spaces (Line, 1) <= Line'Last,
     Post => (Second_Word_First'Result > Word_Last (Line, Skip_Spaces (Line, 1)) and then Second_Word_First'Result <= Line'Last + 1 and then
              (for all I in Word_Last (Line, Skip_Spaces (Line, 1)) + 1 .. Second_Word_First'Result - 1 => Is_Space (Line (I))) and then
              (if Second_Word_First'Result <= Line'Last then not Is_Space (Line (Second_Word_First'Result))));

   function First_Word_Is (Line : String; Word : String) return Boolean is
     ((Skip_Spaces (Line, 1) <= Line'Last) and then
      (Word_Last (Line, Skip_Spaces (Line, 1)) - Skip_Spaces (Line, 1) = Word'Length - 1) and then
      (for all I in 0 .. Word'Length - 1 => Line (Skip_Spaces (Line, 1) + I) = Word (Word'First + I)))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line and then Word'First = 1 and then Word'Length in 1 .. 16,
     Post => ((if First_Word_Is'Result then Skip_Spaces (Line, 1) <= Line'Last and then Line (Skip_Spaces (Line, 1)) = Word (Word'First) and then Word_Last (Line, Skip_Spaces (Line, 1)) = Skip_Spaces (Line, 1) + Word'Length - 1) and
              (if Skip_Spaces (Line, 1) > Line'Last then not First_Word_Is'Result));

   function Has_Name (Line : String) return Boolean is
     ((Skip_Spaces (Line, 1) <= Line'Last) and then
      (Second_Word_First (Line) <= Line'Last) and then
      Is_Letter (Line (Second_Word_First (Line))))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line;

   function Says_Deliverable (Line : String) return Boolean is
     (First_Word_Is (Line, "delivers:"))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line;

   function Says_Post (Line : String) return Boolean is
     (First_Word_Is (Line, "post:"))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line;

   function Says_Other_Operation (Line : String) return Boolean is
     (First_Word_Is (Line, "procedure") or else First_Word_Is (Line, "operation"))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line;

   function Says_Type (Line : String) return Boolean is
     (First_Word_Is (Line, "type") and then Has_Name (Line))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line;

   function Says_Function (Line : String) return Boolean is
     (First_Word_Is (Line, "function") and then Has_Name (Line))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line;

   function Kind_Of (Line : String) return Line_Kind is
     ((if Says_Deliverable (Line) then Deliverable_Line
       elsif Says_Post (Line) then Post_Line
       elsif Says_Other_Operation (Line) then Other_Operation_Line
       elsif Says_Type (Line) then Type_Line
       elsif Says_Function (Line) then Function_Line
       else Commentary_Line))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line,
     Post => (((Kind_Of'Result = Deliverable_Line) = (Says_Deliverable (Line))) and then
              ((Kind_Of'Result = Post_Line) = (not Says_Deliverable (Line) and then Says_Post (Line))) and then
              ((Kind_Of'Result = Other_Operation_Line) = (not Says_Deliverable (Line) and then not Says_Post (Line) and then Says_Other_Operation (Line))) and then
              ((Kind_Of'Result = Type_Line) = (not Says_Deliverable (Line) and then not Says_Post (Line) and then not Says_Other_Operation (Line) and then Says_Type (Line))) and then
              ((Kind_Of'Result = Function_Line) = (not Says_Deliverable (Line) and then not Says_Post (Line) and then not Says_Other_Operation (Line) and then not Says_Type (Line) and then Says_Function (Line))) and then
              ((Kind_Of'Result = Commentary_Line) =
                (not Says_Deliverable (Line) and not Says_Post (Line) and
                 not Says_Other_Operation (Line) and
                 not Says_Type (Line) and
                 not Says_Function (Line))) and then
              ((if Kind_Of'Result in Type_Line | Function_Line then Has_Name (Line))));

   function Name_First (Line : String) return Positive is
     (Second_Word_First (Line))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line and then Kind_Of (Line) in Type_Line | Function_Line,
     Post => Name_First'Result <= Line'Last and then Is_Letter (Line (Name_First'Result));

   function Name_End (Line : String) return Positive is
     (Name_Last (Line, Name_First (Line)))
   with
     Pre  => Line'First = 1 and then Line'Last in 0 .. Max_Line and then Kind_Of (Line) in Type_Line | Function_Line,
     Post => (Name_End'Result >= Name_First (Line) and then Name_End'Result <= Line'Last and then
              (for all I in Name_First (Line) .. Name_End'Result => Is_Name_Char (Line (I))));

end Intake_Line_Pkg;
