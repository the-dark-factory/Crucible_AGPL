--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: f27f9e67ce695a715a57141dc17c9b19e220cbd5c8a1119c274c8c132994da6f
--
with Lovelace_Lex_Rules_Pkg;
use Lovelace_Lex_Rules_Pkg;
with Lovelace_Text_Rules_Pkg;
use Lovelace_Text_Rules_Pkg;

package Lovelace_Claim_Screen_Pkg with SPARK_Mode, Pure is

   type Claim_Range is record
      First : Positive := 1;
      Last  : Natural  := 0;
   end record;

   type Bad_Word is (No_Bad_Word, Bad_If, Bad_Not, Bad_Or_Else, Bad_For_All, Bad_For_Some, Bad_In);

   If_Kw   : constant String := "if";
   Not_Kw  : constant String := "not";
   Or_Kw   : constant String := "or";
   Else_Kw : constant String := "else";
   For_Kw  : constant String := "for";
   All_Kw  : constant String := "all";
   Some_Kw : constant String := "some";
   In_Kw   : constant String := "in";

   function Range_Of (First : Positive; Last : Natural) return Claim_Range is
     ((First => First, Last => Last));

   function Inner_First (Text : String; F : Positive; L : Natural) return Positive is
     (First_Non_Trim (Text, F + 1, L - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                  and then F < L,
          Post => Inner_First'Result >= F + 1 and then Inner_First'Result <= L;

   function Inner_Last (Text : String; F : Positive; L : Natural) return Natural is
     (Last_Non_Trim (Text, Inner_First (Text, F, L), L - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                  and then F < L,
          Post => Inner_Last'Result >= Inner_First (Text, F, L) - 1 and then Inner_Last'Result <= L - 1;

   function Wraps_Whole (Text : String; Mask : Mask_Array; F : Positive; L : Natural) return Boolean is
     (F < L
      and then Text (F) = '('
      and then Text (L) = ')'
      and then Group_Close (Text, Mask, F, F, 0) = L)
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                 and then Mask'Last = Text'Last and then L <= Text'Length;

   function Strip_Outer (Text : String; Mask : Mask_Array; F : Positive; L : Natural) return Claim_Range is
     (if Wraps_Whole (Text, Mask, F, L)
      then Strip_Outer (Text, Mask, Inner_First (Text, F, L), Inner_Last (Text, F, L))
      else Range_Of (F, L))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then L <= Text'Length and then F <= L + 1,
          Post => Strip_Outer'Result.First >= F and then Strip_Outer'Result.Last <= L
                  and then Strip_Outer'Result.First <= Strip_Outer'Result.Last + 1
                  and then not Wraps_Whole (Text, Mask, Strip_Outer'Result.First, Strip_Outer'Result.Last),
          Subprogram_Variant => (Decreases => L - F + 1);

   function Trimmed_First (Text : String) return Positive is
     (First_Non_Trim (Text, 1, Text'Length))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text,
          Post => Trimmed_First'Result <= Text'Length + 1;

   function Trimmed_Last (Text : String) return Natural is
     (Last_Non_Trim (Text, Trimmed_First (Text), Text'Length))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text,
          Post => Trimmed_Last'Result >= Trimmed_First (Text) - 1 and then Trimmed_Last'Result <= Text'Length;

   function Screened (Text : String; Mask : Mask_Array) return Claim_Range is
     (Strip_Outer (Text, Mask, Trimmed_First (Text), Trimmed_Last (Text)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last,
          Post => Screened'Result.Last <= Text'Length
                  and then Screened'Result.First <= Screened'Result.Last + 1;

   function Is_Re_Space (C : Character) return Boolean is
     (C = ' ' or else C = Character'Val (9) or else C = Character'Val (10)
      or else C = Character'Val (12) or else C = Character'Val (13))
     with Global => null;

   function Before_Ok (Text : String; F : Positive; P : Positive) return Boolean is
     (P = F or else Is_Re_Space (Text (P - 1)))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then F <= P
                 and then P <= Text'Length + 1;

   function After_Ok (Text : String; L : Natural; E : Positive) return Boolean is
     (E > L or else Is_Re_Space (Text (E)))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length;

   function Chars_At (Text : String; P : Positive; L : Natural; W : String) return Boolean is
     (W'Length <= L - P + 1
      and then Equal_Ignoring_Case (Text (P .. P + W'Length - 1), W))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                 and then P <= L + 1 and then W'First = 1 and then W'Length >= 2 and then W'Length <= 4;

   function Skip_Re_Space (Text : String; I : Positive; L : Natural) return Positive is
     (if I > L then I
      elsif not Is_Re_Space (Text (I)) then I
      else Skip_Re_Space (Text, I + 1, L))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                  and then I <= L + 1,
          Post => Skip_Re_Space'Result >= I and then Skip_Re_Space'Result <= L + 1,
          Subprogram_Variant => (Decreases => L - I + 1);

   Dotted_I_Lead  : constant Character := Character'Val (16#C4#);
   Dotted_I_Trail : constant Character := Character'Val (16#B0#);

   function Dotted_I_At (Text : String; P : Positive; L : Natural) return Boolean is
     (P < L and then Text (P) = Dotted_I_Lead and then Text (P + 1) = Dotted_I_Trail)
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                 and then P <= L + 1;

   function Folded_I_At (Text : String; P : Positive; L : Natural; W : String) return Boolean is
     (W (1) = 'i'
      and then Dotted_I_At (Text, P, L)
      and then W'Length <= L - P
      and then (for all K in 1 .. W'Length - 1 => Lower (Text (P + 1 + K)) = W (1 + K)))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                 and then P <= L + 1 and then W'First = 1 and then W'Length >= 2 and then W'Length <= 4;

   function Word_Len (Text : String; P : Positive; L : Natural; W : String) return Natural is
     (if Chars_At (Text, P, L, W) then W'Length
      elsif Folded_I_At (Text, P, L, W) then W'Length + 1
      else 0)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                  and then P <= L + 1 and then W'First = 1 and then W'Length >= 2 and then W'Length <= 4,
          Post => Word_Len'Result <= 5;

   function Word_At (Text : String; F : Positive; L : Natural; P : Positive; W : String) return Boolean is
     (Before_Ok (Text, F, P)
      and then Word_Len (Text, P, L, W) > 0
      and then After_Ok (Text, L, P + Word_Len (Text, P, L, W)))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                 and then F <= P and then P <= L + 1
                 and then W'First = 1 and then W'Length >= 2 and then W'Length <= 4;

   function Second_At (Text : String; L : Natural; Q : Positive; W : String) return Boolean is
     (Chars_At (Text, Q, L, W) and then After_Ok (Text, L, Q + W'Length))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                 and then Q <= L + 1 and then W'First = 1 and then W'Length >= 2 and then W'Length <= 4;

   function Pair_At (Text : String; F : Positive; L : Natural; P : Positive; W1 : String; W2 : String) return Boolean is
     (Before_Ok (Text, F, P)
      and then Chars_At (Text, P, L, W1)
      and then W1'Length <= L - P
      and then Is_Re_Space (Text (P + W1'Length))
      and then Second_At (Text, L, Skip_Re_Space (Text, P + W1'Length, L), W2))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                 and then F <= P and then P <= L + 1
                 and then W1'First = 1 and then W1'Length >= 2 and then W1'Length <= 4
                 and then W2'First = 1 and then W2'Length >= 2 and then W2'Length <= 4;

   function Pattern_At (Text : String; F : Positive; L : Natural; P : Positive; B : Bad_Word) return Boolean is
     (if B = Bad_If then Word_At (Text, F, L, P, If_Kw)
      elsif B = Bad_Not then Word_At (Text, F, L, P, Not_Kw)
      elsif B = Bad_Or_Else then Pair_At (Text, F, L, P, Or_Kw, Else_Kw)
      elsif B = Bad_For_All then Pair_At (Text, F, L, P, For_Kw, All_Kw)
      elsif B = Bad_For_Some then Pair_At (Text, F, L, P, For_Kw, Some_Kw)
      elsif B = Bad_In then Word_At (Text, F, L, P, In_Kw)
      else False)
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                 and then F <= P and then P <= L + 1;

   function Occurs_From (Text : String; F : Positive; L : Natural; P : Positive; B : Bad_Word) return Boolean is
     (P <= L and then (Pattern_At (Text, F, L, P, B) or else Occurs_From (Text, F, L, P + 1, B)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                  and then F <= P and then P <= L + 1,
          Subprogram_Variant => (Decreases => L - P + 1);

   function Occurs (Text : String; F : Positive; L : Natural; B : Bad_Word) return Boolean is
     (Occurs_From (Text, F, L, F, B))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                 and then F <= L + 1;

   function First_Bad (Text : String; F : Positive; L : Natural) return Bad_Word is
     (if Occurs (Text, F, L, Bad_If) then Bad_If
      elsif Occurs (Text, F, L, Bad_Not) then Bad_Not
      elsif Occurs (Text, F, L, Bad_Or_Else) then Bad_Or_Else
      elsif Occurs (Text, F, L, Bad_For_All) then Bad_For_All
      elsif Occurs (Text, F, L, Bad_For_Some) then Bad_For_Some
      elsif Occurs (Text, F, L, Bad_In) then Bad_In
      else No_Bad_Word)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then L <= Text'Length
                  and then F <= L + 1,
          Post => (if First_Bad'Result /= No_Bad_Word then Occurs (Text, F, L, First_Bad'Result))
                  and then (if First_Bad'Result = No_Bad_Word then
                              (for all B in Bad_If .. Bad_In => not Occurs (Text, F, L, B)));

end Lovelace_Claim_Screen_Pkg;
