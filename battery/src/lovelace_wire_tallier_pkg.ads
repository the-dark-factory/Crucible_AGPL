--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 4e5b383dcd74da28182b04ae7b58d5e5342d46fe551e25d812a3555f5aab93fb
--
package Lovelace_Wire_Tallier_Pkg with SPARK_Mode, Pure is

   Max_Functions : constant := 10_000;

   subtype Grade_Value is Integer range -1 .. 2;

   type Function_Record is record
      Definition : Boolean     := False;
      Grade      : Grade_Value := -1;
   end record;

   type Record_Array is array (Positive range <>) of Function_Record;

   type Tally_Class is (Theorem, Runtime_Only, Unexercised, Refused);

   type Tallies is record
      Theorem_Count      : Natural := 0;
      Runtime_Only_Count : Natural := 0;
      Unexercised_Count  : Natural := 0;
      Refused_Count      : Natural := 0;
      Grade_Lines        : Natural := 0;
   end record;

   function Class_Of (G : Grade_Value) return Tally_Class is
     (if G = 2 then Theorem
      elsif G = 1 then Runtime_Only
      elsif G = 0 then Unexercised
      else Refused)
     with Post => ((Class_Of'Result = Refused) = (G = -1));

   function Counts_As (R : Function_Record; C : Tally_Class) return Natural is
     (if not R.Definition and then Class_Of (R.Grade) = C then 1 else 0)
     with Post => Counts_As'Result <= 1;

   function Line_Weight (R : Function_Record) return Natural is
     (if R.Definition then 0 else 1)
     with Post => Line_Weight'Result <= 1;

   function Count_Class (Rs : Record_Array; N : Natural; C : Tally_Class) return Natural is
     (if N = 0 then 0 else Count_Class (Rs, N - 1, C) + Counts_As (Rs (N), C))
     with Pre  => Rs'First = 1 and then Rs'Length <= Max_Functions and then N <= Rs'Length,
          Post => Count_Class'Result <= N,
          Subprogram_Variant => (Decreases => N);

   function Line_Count (Rs : Record_Array; N : Natural) return Natural is
     (if N = 0 then 0 else Line_Count (Rs, N - 1) + Line_Weight (Rs (N)))
     with Pre  => Rs'First = 1 and then Rs'Length <= Max_Functions and then N <= Rs'Length,
          Post => Line_Count'Result <= N
                  and then Line_Count'Result = Count_Class (Rs, N, Theorem) + Count_Class (Rs, N, Runtime_Only)
                                               + Count_Class (Rs, N, Unexercised) + Count_Class (Rs, N, Refused),
          Subprogram_Variant => (Decreases => N);

   function Tally (Rs : Record_Array) return Tallies is
     ((Theorem_Count      => Count_Class (Rs, Rs'Length, Theorem),
       Runtime_Only_Count => Count_Class (Rs, Rs'Length, Runtime_Only),
       Unexercised_Count  => Count_Class (Rs, Rs'Length, Unexercised),
       Refused_Count      => Count_Class (Rs, Rs'Length, Refused),
       Grade_Lines        => Line_Count (Rs, Rs'Length)))
     with Pre  => Rs'First = 1 and then Rs'Length <= Max_Functions,
          Post => Tally'Result.Grade_Lines = Tally'Result.Theorem_Count + Tally'Result.Runtime_Only_Count
                                             + Tally'Result.Unexercised_Count + Tally'Result.Refused_Count
                  and then Tally'Result.Grade_Lines <= Rs'Length;

   function Nth_From (Rs : Record_Array; K : Positive; N : Positive) return Natural is
     (if K > Rs'Length then 0
      elsif Rs (K).Definition then Nth_From (Rs, K + 1, N)
      elsif N = 1 then K
      else Nth_From (Rs, K + 1, N - 1))
     with Pre  => Rs'First = 1 and then Rs'Length <= Max_Functions and then K <= Rs'Length + 1,
          Post => Nth_From'Result = 0
                  or else (Nth_From'Result >= K and then Nth_From'Result <= Rs'Length
                           and then not Rs (Nth_From'Result).Definition),
          Subprogram_Variant => (Decreases => Rs'Length - K + 1);

   function Line_Order (Rs : Record_Array; N : Positive) return Natural is
     (Nth_From (Rs, 1, N))
     with Pre  => Rs'First = 1 and then Rs'Length <= Max_Functions,
          Post => Line_Order'Result = 0
                  or else (Line_Order'Result <= Rs'Length and then not Rs (Line_Order'Result).Definition);

end Lovelace_Wire_Tallier_Pkg;
