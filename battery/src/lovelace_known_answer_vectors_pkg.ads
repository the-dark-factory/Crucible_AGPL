--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 7f415884b91fc58daec88bfd6ea8d2718252247a678c784340238a9c3e640f56
--
package Lovelace_Known_Answer_Vectors_Pkg with SPARK_Mode, Pure is

   type Edge_Mode is (Worst_Mode, Roll_Mode, Grade_Mode);

   subtype Answer_Digit is Natural range 0 .. 2;

   subtype Vector_Index is Positive range 1 .. 9;

   subtype Operand_Count is Positive range 2 .. 8;

   type Operand_List is array (1 .. 8) of Answer_Digit;

   type Known_Answer is record
      Mode     : Edge_Mode;
      Count    : Operand_Count;
      Operands : Operand_List;
      Want     : Answer_Digit;
   end record;

   Vectors : constant array (Vector_Index) of Known_Answer := (
      1 => (Mode => Worst_Mode, Count => 2, Operands => (1 => 0, 2 => 2, others => 0), Want => 0),
      2 => (Mode => Worst_Mode, Count => 2, Operands => (1 => 1, 2 => 1, others => 0), Want => 1),
      3 => (Mode => Worst_Mode, Count => 2, Operands => (1 => 2, 2 => 2, others => 0), Want => 2),
      4 => (Mode => Roll_Mode, Count => 2, Operands => (1 => 2, 2 => 0, others => 0), Want => 0),
      5 => (Mode => Roll_Mode, Count => 2, Operands => (1 => 2, 2 => 2, others => 0), Want => 2),
      6 => (Mode => Grade_Mode, Count => 8, Operands => (1 => 1, 2 => 2, 3 => 1, 4 => 1, 5 => 1, 6 => 1, 7 => 1, 8 => 1), Want => 2),
      7 => (Mode => Grade_Mode, Count => 8, Operands => (1 => 0, 2 => 2, 3 => 1, 4 => 1, 5 => 1, 6 => 1, 7 => 1, 8 => 1), Want => 0),
      8 => (Mode => Grade_Mode, Count => 8, Operands => (1 => 1, 2 => 1, 3 => 1, 4 => 1, 5 => 1, 6 => 1, 7 => 1, 8 => 1), Want => 0),
      9 => (Mode => Grade_Mode, Count => 8, Operands => (1 => 1, 2 => 2, 3 => 1, 4 => 1, 5 => 1, 6 => 1, 7 => 2, 8 => 1), Want => 1)
   );

   function Mode_Word (M : Edge_Mode) return String is
     ((if M = Worst_Mode then "worst" elsif M = Roll_Mode then "roll" else "grade"))
   with Post =>
     (Mode_Word'Result'First = 1
      and then
       (if M = Roll_Mode then Mode_Word'Result'Length = 4 else Mode_Word'Result'Length = 5));

   function Arity (M : Edge_Mode) return Operand_Count is
     ((if M = Grade_Mode then 8 else 2))
   with Post =>
     (((Arity'Result = 8) = (M = Grade_Mode)));

   function Why (V : Vector_Index) return String is
     ((if V = 1 then "Worst: not-reached dominates anything"
       elsif V = 2 then "Worst: failed with failed is failed"
       elsif V = 3 then "Worst: proved with proved is proved"
       elsif V = 4 then "Roll_Up: a theorem rolled with an unexercised is unexercised"
       elsif V = 5 then "Roll_Up: only all-theorem rolls up to theorem"
       elsif V = 6 then "Grade_Of: every check good is a theorem"
       elsif V = 7 then "Grade_Of: T0 not reached is unexercised"
       elsif V = 8 then "Grade_Of: run-time checks not discharged is unexercised"
       else "Grade_Of: one derived lemma proved is run-time-only"))
   with Post =>
     (Why'Result'First = 1
      and then
       (if Vectors (V).Mode = Worst_Mode then (Why'Result'Length > 7 and then Why'Result (1 .. 7) = "Worst: "))
      and then
       (if Vectors (V).Mode = Roll_Mode then (Why'Result'Length > 9 and then Why'Result (1 .. 9) = "Roll_Up: "))
      and then
       (if Vectors (V).Mode = Grade_Mode then (Why'Result'Length > 10 and then Why'Result (1 .. 10) = "Grade_Of: ")));

   function Well_Formed (V : Vector_Index) return Boolean is
     ((Vectors (V).Count = Arity (Vectors (V).Mode))
      and then
       (for all K in Vectors (V).Count + 1 .. 8 => Vectors (V).Operands (K) = 0))
   with Post =>
     (Well_Formed'Result = ((Vectors (V).Count = Arity (Vectors (V).Mode)) and then
        (for all K in Vectors (V).Count + 1 .. 8 => Vectors (V).Operands (K) = 0)));

   function Mode_Total (M : Edge_Mode) return Natural is
     (((if Vectors (1).Mode = M then 1 else 0)
       + (if Vectors (2).Mode = M then 1 else 0)
       + (if Vectors (3).Mode = M then 1 else 0)
       + (if Vectors (4).Mode = M then 1 else 0)
       + (if Vectors (5).Mode = M then 1 else 0)
       + (if Vectors (6).Mode = M then 1 else 0)
       + (if Vectors (7).Mode = M then 1 else 0)
       + (if Vectors (8).Mode = M then 1 else 0)
       + (if Vectors (9).Mode = M then 1 else 0)))
   with Post =>
     (Mode_Total'Result <= 9);

   function Table_Is_The_Go_Table return Boolean is
     ((for all V in Vector_Index => Well_Formed (V))
      and then
       Mode_Total (Worst_Mode) = 3
      and then
       Mode_Total (Roll_Mode) = 2
      and then
       Mode_Total (Grade_Mode) = 4
      and then
       (for all V in Vector_Index =>
          Vectors (V).Mode = (if V <= 3 then Worst_Mode elsif V <= 5 then Roll_Mode else Grade_Mode)))
   with Post =>
     (Table_Is_The_Go_Table'Result);

end Lovelace_Known_Answer_Vectors_Pkg;
