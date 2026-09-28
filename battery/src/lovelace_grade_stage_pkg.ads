--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: c474bd85315a90c01a1fd0a02863ef74df323c86b9b1492703f5824ebd6d7412
--
package Lovelace_Grade_Stage_Pkg with SPARK_Mode, Pure is

   subtype Outcome is Natural range 0 .. 3;
   Unreached    : constant Outcome := 0;
   Failed       : constant Outcome := 1;
   Proved       : constant Outcome := 2;
   Inapplicable : constant Outcome := 3;

   subtype Grade_Value is Integer range -1 .. 2;
   subtype Edge_Digit is Natural range 0 .. 2;

   subtype Slot is Positive range 1 .. 8;
   type Question is array (Slot) of Outcome;

   type Checks is record
      T0  : Outcome := Unreached;
      RTE : Outcome := Unreached;
      TB  : Outcome := Unreached;
      TC  : Outcome := Unreached;
      T1  : Outcome := Unreached;
      T3  : Outcome := Unreached;
      T4  : Outcome := Unreached;
      T5  : Outcome := Unreached;
   end record;

   type Edge_Answer is record
      Answered : Boolean    := False;
      Digit    : Edge_Digit := 0;
   end record;

   T3_Slot : constant Slot := 7;

   function Grade_Question (C : Checks) return Question is
     ((1 => C.T0, 2 => C.RTE, 3 => C.TB, 4 => C.TC, 5 => C.T1, 6 => C.T5, 7 => C.T3, 8 => C.T4))
     with Post => Grade_Question'Result (1) = C.T0
                  and then Grade_Question'Result (2) = C.RTE
                  and then Grade_Question'Result (6) = C.T5
                  and then Grade_Question'Result (T3_Slot) = C.T3
                  and then Grade_Question'Result (8) = C.T4;

   function Grade_Of (A : Edge_Answer) return Grade_Value is
     (if A.Answered then A.Digit else -1)
     with Post => ((Grade_Of'Result = -1) = (not A.Answered))
                  and then (if A.Answered then Grade_Of'Result = A.Digit);

   function Errors_From (A : Edge_Answer) return Natural is
     (if A.Answered then 0 else 1)
     with Post => Errors_From'Result <= 1 and then ((Errors_From'Result = 1) = (not A.Answered));

   function Stage_Grade (Is_Definition : Boolean; A : Edge_Answer) return Grade_Value is
     (if Is_Definition then -1 else Grade_Of (A))
     with Post => (if Is_Definition then Stage_Grade'Result = -1)
                  and then (if not Is_Definition then Stage_Grade'Result = Grade_Of (A));

end Lovelace_Grade_Stage_Pkg;
