--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: bddd5a7d114060a2ba4cb247b7a9515ccde5b88bed96ebc169f088c60d5208e2
--
with Lovelace_Known_Answer_Vectors_Pkg;
use Lovelace_Known_Answer_Vectors_Pkg;
with Lovelace_Refusal_Texts_Pkg;
use Lovelace_Refusal_Texts_Pkg;

package Lovelace_Known_Answer_Prober_Pkg with SPARK_Mode, Pure is

   Max_Piece : constant := 2_048;

   type Answer_Kind is (Ask_Failed, Not_A_Digit, Number);

   type Edge_Reply is record
      Kind : Answer_Kind      := Ask_Failed;
      Got  : Long_Long_Integer := 0;
   end record;

   type Reply_Array is array (Vector_Index) of Edge_Reply;

   Edge_Word      : constant String := "edge ";
   Returned_Word  : constant String := " returned ";
   Not_Digit_Tail : constant String := ", not a digit";
   Want_Word      : constant String := ", want ";
   Open_Why       : constant String := " (";
   Close_Why      : constant String := ") ";
   Verdict_Tail   : constant String := " this binary does not answer as Vacuity_Verdict_Pkg does, so no grade from it means anything";

   function Em_Dash return String is
     (String'(1 => Character'Val (226), 2 => Character'Val (128), 3 => Character'Val (148)))
     with Post => Em_Dash'Result'Length = 3;

   function Passes (V : Vector_Index; R : Edge_Reply) return Boolean is
     (R.Kind = Number and then R.Got = Long_Long_Integer (Vectors (V).Want));

   function All_Pass_Upto (Replies : Reply_Array; N : Natural) return Boolean is
     ((for all V in 1 .. N => Passes (V, Replies (V))))
     with Pre => N <= 9;

   function First_Failure_From (Replies : Reply_Array; V : Positive) return Natural is
     (if V > 9 then 0
      elsif not Passes (V, Replies (V)) then V
      else First_Failure_From (Replies, V + 1))
     with Pre  => V <= 10,
          Post => (First_Failure_From'Result = 0 or else
                     (First_Failure_From'Result >= V and then First_Failure_From'Result <= 9
                      and then not Passes (First_Failure_From'Result, Replies (First_Failure_From'Result))))
                  and then (if First_Failure_From'Result = 0 then
                              (for all K in V .. 9 => Passes (K, Replies (K)))),
          Subprogram_Variant => (Decreases => 10 - V);

   function First_Failure (Replies : Reply_Array) return Natural is
     (First_Failure_From (Replies, 1))
     with Post => ((First_Failure'Result = 0) = All_Pass_Upto (Replies, 9));

   function Trusted (Replies : Reply_Array) return Boolean is
     (First_Failure (Replies) = 0);

   function Digit_Char (D : Answer_Digit) return Character is
     (Character'Val (48 + D))
     with Post => Digit_Char'Result in '0' .. '2';

   function Digits_From (V : Vector_Index; K : Positive) return String is
     (if K >= Vectors (V).Count then String'(1 => Digit_Char (Vectors (V).Operands (K)))
      else Digit_Char (Vectors (V).Operands (K)) & " " & Digits_From (V, K + 1))
     with Pre  => K <= Vectors (V).Count,
          Post => Digits_From'Result'Length = 2 * (Vectors (V).Count - K) + 1,
          Subprogram_Variant => (Decreases => 8 - K);

   function Digit_List (V : Vector_Index) return String is
     ("[" & Digits_From (V, 1) & "]")
     with Post => Digit_List'Result'Length = 2 * Vectors (V).Count + 1;

   subtype Non_Positive is Long_Long_Integer range Long_Long_Integer'First .. 0;

   function Digit_Image (D : Long_Long_Integer) return String is
     (String'(1 => Character'Val (48 + Integer (D))))
     with Pre  => D >= 0 and then D <= 9,
          Post => Digit_Image'Result'First = 1 and then Digit_Image'Result'Length = 1;

   function Neg_Width (N : Non_Positive) return Positive is
     (if N > -10 then 1
      elsif N > -100 then 2
      elsif N > -1_000 then 3
      elsif N > -10_000 then 4
      elsif N > -100_000 then 5
      elsif N > -1_000_000 then 6
      elsif N > -10_000_000 then 7
      elsif N > -100_000_000 then 8
      elsif N > -1_000_000_000 then 9
      elsif N > -10_000_000_000 then 10
      elsif N > -100_000_000_000 then 11
      elsif N > -1_000_000_000_000 then 12
      elsif N > -10_000_000_000_000 then 13
      elsif N > -100_000_000_000_000 then 14
      elsif N > -1_000_000_000_000_000 then 15
      elsif N > -10_000_000_000_000_000 then 16
      elsif N > -100_000_000_000_000_000 then 17
      elsif N > -1_000_000_000_000_000_000 then 18
      else 19)
     with Post => Neg_Width'Result <= 19;

   function Neg_Digits (N : Non_Positive) return String is
     (if N > -10 then Digit_Image (-N)
      else Neg_Digits (N / 10) & Digit_Image (-(N rem 10)))
     with Post => Neg_Digits'Result'First = 1 and then Neg_Digits'Result'Length = Neg_Width (N),
          Subprogram_Variant => (Increases => N);

   function Signed_Image (N : Long_Long_Integer) return String is
     (if N >= 0 then Neg_Digits (-N) else "-" & Neg_Digits (N))
     with Post => Signed_Image'Result'Length >= 1 and then Signed_Image'Result'Length <= 20;

   function Asked (V : Vector_Index) return String is
     (Edge_Word & Mode_Word (Vectors (V).Mode) & " " & Digit_List (V))
     with Post => Asked'Result'Length <= 28;

   function Detail_Of (V : Vector_Index; R : Edge_Reply; Err_Text : String; Quoted_Word : String) return String is
     (if R.Kind = Ask_Failed then Asked (V) & ": " & Err_Text
      elsif R.Kind = Not_A_Digit then Asked (V) & Returned_Word & Quoted_Word & Not_Digit_Tail
      else Asked (V) & Returned_Word & Signed_Image (R.Got) & Want_Word
           & Digit_Char (Vectors (V).Want) & Open_Why & Why (V) & Close_Why & Em_Dash & Verdict_Tail)
     with Pre  => Err_Text'Length <= Max_Piece and then Quoted_Word'Length <= Max_Piece,
          Post => Detail_Of'Result'Length <= 4_096;

   function Refusal_Of (V : Vector_Index; R : Edge_Reply; Err_Text : String; Quoted_Word : String) return String is
     (Edge_Verification_Failed (Detail_Of (V, R, Err_Text, Quoted_Word)))
     with Pre  => Err_Text'Length <= Max_Piece and then Quoted_Word'Length <= Max_Piece,
          Post => Refusal_Of'Result'Length > 26;

end Lovelace_Known_Answer_Prober_Pkg;
