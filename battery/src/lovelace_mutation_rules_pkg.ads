--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: b8d4332af29f4c88939984d1f5e21ab92782caf933f71c6a5518a9807ffd402b
--
with Interfaces;
use type Interfaces.Unsigned_64;
with Lovelace_Lex_Rules_Pkg;
use Lovelace_Lex_Rules_Pkg;

package Lovelace_Mutation_Rules_Pkg with SPARK_Mode, Pure is

   Max_Replacement : constant := 20;
   Int64_Max : constant Interfaces.Unsigned_64 := 9_223_372_036_854_775_807;

   subtype Replacement_Length_Type is Natural range 0 .. Max_Replacement;

   subtype Swap_Index is Positive range 1 .. 10;

   subtype Text_Index is Positive range 1 .. Max_Text + 1;

   type Edit is record
      First              : Text_Index := 1;
      Past               : Text_Index := 1;
      Replacement        : String (1 .. Max_Replacement) := (others => ' ');
      Replacement_Length : Replacement_Length_Type := 0;
   end record;

   type Edit_Array is array (Positive range <>) of Edit;

   type Operator_Edit is record
      First : Text_Index := 1;
      Swap  : Swap_Index := 1;
   end record;

   type Operator_Edit_Array is array (Positive range <>) of Operator_Edit;

   function Swap_From (I : Swap_Index) return String is
     (case I is
        when 1 => " + ",
        when 2 => " - ",
        when 3 => " * ",
        when 4 => " / ",
        when 5 => " <= ",
        when 6 => " >= ",
        when 7 => " < ",
        when 8 => " > ",
        when 9 => " = ",
        when 10 => " /= ")
     with Post => Swap_From'Result'First = 1
       and then (Swap_From'Result'Length = 3 or else Swap_From'Result'Length = 4)
       and then Swap_From'Result (1) = ' '
       and then Swap_From'Result (Swap_From'Result'Length) = ' ';

   function Swap_To (I : Swap_Index) return String is
     (case I is
        when 1 => " - ",
        when 2 => " + ",
        when 3 => " + ",
        when 4 => " * ",
        when 5 => " < ",
        when 6 => " > ",
        when 7 => " <= ",
        when 8 => " >= ",
        when 9 => " /= ",
        when 10 => " = ")
     with Post => Swap_To'Result'First = 1
       and then (Swap_To'Result'Length = 3 or else Swap_To'Result'Length = 4);

   function Is_Digit (C : Character) return Boolean is
     (C in '0' .. '9');

   function Char_Is_Mutable (Lit : String) return Boolean is
     (Lit'Length = 3 and then Lit (Lit'First) = ''' and then Lit (Lit'First + 2) = '''
      and then Lit (Lit'First + 1) in ' ' .. '~');

   function Next_Char (C : Character) return Character is
     (if C = '~' then '}' else Character'Val (Character'Pos (C) + 1))
     with Pre => C in ' ' .. '~',
          Post => Next_Char'Result in ' ' .. '~'
            and then Next_Char'Result /= C
            and then (if C /= '~' then Character'Pos (Next_Char'Result) = Character'Pos (C) + 1);

   function Run_End (Text : String; P : Positive) return Positive is
     (if P = Text'Length then P
      elsif not Is_Digit (Text (P + 1)) and then Text (P + 1) /= '_' then P
      else Run_End (Text, P + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then P <= Text'Length
                  and then (Is_Digit (Text (P)) or else Text (P) = '_'),
          Post => Run_End'Result >= P and then Run_End'Result <= Text'Length
            and then (for all K in P .. Run_End'Result => (Is_Digit (Text (K)) or else Text (K) = '_'))
            and then (Run_End'Result = Text'Length or else
                        (not Is_Digit (Text (Run_End'Result + 1)) and then Text (Run_End'Result + 1) /= '_')),
          Subprogram_Variant => (Decreases => Text'Length - P);

   function Int_Literal_Past (Text : String; P : Positive) return Natural is
     (if P <= Text'Length and then Is_Digit (Text (P))
            and then (P = 1 or else not Is_Ident_Char (Text (P - 1)))
            and then (Run_End (Text, P) = Text'Length or else not Is_Ident_Char (Text (Run_End (Text, P) + 1)))
         then Run_End (Text, P) + 1
         else 0)
     with Pre => Text'First = 1 and then Text'Length <= Max_Text,
          Post => (Int_Literal_Past'Result = 0 or else
                    (Int_Literal_Past'Result > P and then Int_Literal_Past'Result <= Text'Length + 1));

   function Touches_Hash (Text : String; First : Positive; Past : Positive) return Boolean is
     ((First > 1 and then Text (First - 1) = '#') or else
      (Past <= Text'Length and then Text (Past) = '#'))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then First <= Text'Length + 1
                  and then Past <= Text'Length + 1;

   function In_Char_Literal (Spans : Span_Array; Span_Count : Natural; First : Positive; Past : Positive) return Boolean is
     ((for some I in 1 .. Span_Count => Spans (I).Is_Char and then Overlaps (Spans (I), First, Past)))
     with Pre => Spans'First = 1 and then Span_Count <= Spans'Last;

   function Increment_Image (V : Interfaces.Unsigned_64) return String is
     (if V = Int64_Max then "-9223372036854775808"
      else Interfaces.Unsigned_64'Image (V + 1) (2 .. Interfaces.Unsigned_64'Image (V + 1)'Last))
     with Pre => V <= Int64_Max,
          Post => Increment_Image'Result'Length <= 20;

   function Is_Char_Edit (Text : String; E : Edit) return Boolean is
     (E.Past = E.First + 3 and then E.Past <= Text'Length + 1
      and then E.Replacement_Length = 3
      and then E.Replacement (1) = ''' and then E.Replacement (3) = '''
      and then Text (E.First + 1) in ' ' .. '~'
      and then E.Replacement (2) = Next_Char (Text (E.First + 1)))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then E.First <= Text'Length;

   function Is_Int_Edit (Text : String; Spans : Span_Array; Span_Count : Natural; E : Edit) return Boolean is
     (Is_Digit (Text (E.First))
      and then Int_Literal_Past (Text, E.First) = E.Past
      and then not In_Char_Literal (Spans, Span_Count, E.First, E.Past)
      and then not Touches_Hash (Text, E.First, E.Past))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then E.First <= Text'Length
                  and then E.Past <= Text'Length + 1 and then Spans'First = 1 and then Span_Count <= Spans'Last;

   function Edit_Is_Faithful (Text : String; Spans : Span_Array; Span_Count : Natural; E : Edit) return Boolean is
     (if Text (E.First) = ''' then Is_Char_Edit (Text, E) else Is_Int_Edit (Text, Spans, Span_Count, E))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then E.First <= Text'Length
                  and then E.Past <= Text'Length + 1 and then Spans'First = 1 and then Span_Count <= Spans'Last;

   function Operator_At (Text : String; E : Operator_Edit) return Boolean is
     (Swap_From (E.Swap)'Length <= Text'Length
      and then E.First <= Text'Length - Swap_From (E.Swap)'Length + 1
      and then Text (E.First .. E.First + Swap_From (E.Swap)'Length - 1) = Swap_From (E.Swap))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text;

   function Clear_Of_Literals (Spans : Span_Array; Span_Count : Natural; From : Positive; Past : Positive) return Boolean is
     ((for all S in 1 .. Span_Count => not Overlaps (Spans (S), From, Past)))
     with Pre => Spans'First = 1 and then Span_Count <= Spans'Last;

   Int_Too_Big : constant Interfaces.Unsigned_64 := Int64_Max + 1;

   function Digit_Of (C : Character) return Interfaces.Unsigned_64 is
     (Interfaces.Unsigned_64 (Character'Pos (C) - Character'Pos ('0')))
     with Pre => Is_Digit (C), Post => Digit_Of'Result <= 9;

   function Fold_Digit (Acc : Interfaces.Unsigned_64; D : Interfaces.Unsigned_64) return Interfaces.Unsigned_64 is
     (if Acc > Int64_Max then Int_Too_Big
      elsif Acc > (Int64_Max - D) / 10 then Int_Too_Big
      else Acc * 10 + D)
     with Pre  => D <= 9 and then Acc <= Int_Too_Big,
          Post => Fold_Digit'Result <= Int_Too_Big;

   function Int_Value (Text : String; P : Positive; Past : Positive; Acc : Interfaces.Unsigned_64)
     return Interfaces.Unsigned_64 is
     (if P >= Past then Acc
      elsif Text (P) = '_' then Int_Value (Text, P + 1, Past, Acc)
      elsif Is_Digit (Text (P)) then Int_Value (Text, P + 1, Past, Fold_Digit (Acc, Digit_Of (Text (P))))
      else Int_Too_Big)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Past <= Text'Length + 1
                  and then P <= Past and then Acc <= Int_Too_Big,
          Post => Int_Value'Result <= Int_Too_Big,
          Subprogram_Variant => (Decreases => Past - P);

   function Pad (Repl : String) return String is
     ((for K in 1 .. Max_Replacement => (if K <= Repl'Length then Repl (Repl'First + (K - 1)) else ' ')))
     with Pre  => Repl'Length <= Max_Replacement,
          Post => Pad'Result'First = 1 and then Pad'Result'Length = Max_Replacement;

   function Make_Edit (First : Text_Index; Past : Text_Index; Repl : String) return Edit is
     ((First => First, Past => Past, Replacement => Pad (Repl), Replacement_Length => Repl'Length))
     with Pre => Repl'Length <= Max_Replacement;

   function Char_Span_At (Text : String; Spans : Span_Array; Span_Count : Natural; P : Positive) return Boolean is
     ((for some I in 1 .. Span_Count =>
         Spans (I).Is_Char and then Spans (I).First = P and then Spans (I).Past = P + 3))
     with Pre => Spans'First = 1 and then Span_Count <= Spans'Last and then P <= Max_Text;

   function Char_Edit_At (Text : String; Spans : Span_Array; Span_Count : Natural; P : Positive) return Boolean is
     (P + 2 <= Text'Length
      and then Char_Span_At (Text, Spans, Span_Count, P)
      and then Char_Is_Mutable (Text (P .. P + 2)))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                 and then Span_Count <= Spans'Last and then P <= Text'Length;

   function Int_Edit_At (Text : String; Spans : Span_Array; Span_Count : Natural; P : Positive) return Boolean is
     (Int_Literal_Past (Text, P) > 0
      and then not In_Char_Literal (Spans, Span_Count, P, Int_Literal_Past (Text, P))
      and then not Touches_Hash (Text, P, Int_Literal_Past (Text, P))
      and then Int_Value (Text, P, Int_Literal_Past (Text, P), 0) <= Int64_Max)
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                 and then Span_Count <= Spans'Last and then P <= Text'Length;

   function Lit_Edit_At (Text : String; Spans : Span_Array; Span_Count : Natural; P : Positive) return Boolean is
     (Char_Edit_At (Text, Spans, Span_Count, P) or else Int_Edit_At (Text, Spans, Span_Count, P))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                 and then Span_Count <= Spans'Last and then P <= Text'Length;

   function Lit_Edit_Here (Text : String; Spans : Span_Array; Span_Count : Natural; P : Positive) return Edit is
     (if Char_Edit_At (Text, Spans, Span_Count, P)
      then Make_Edit (P, P + 3, "'" & Next_Char (Text (P + 1)) & "'")
      else Make_Edit (P, Int_Literal_Past (Text, P),
                      Increment_Image (Int_Value (Text, P, Int_Literal_Past (Text, P), 0))))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                  and then Span_Count <= Spans'Last and then P <= Text'Length
                  and then Lit_Edit_At (Text, Spans, Span_Count, P),
          Post => Lit_Edit_Here'Result.First = P and then Lit_Edit_Here'Result.Past > P
                  and then Lit_Edit_Here'Result.Past <= Text'Length + 1;

   function Lit_Count_From (Text : String; Spans : Span_Array; Span_Count : Natural; P : Positive) return Natural is
     (if P > Text'Length then 0
      elsif Lit_Edit_At (Text, Spans, Span_Count, P)
      then 1 + Lit_Count_From (Text, Spans, Span_Count, Lit_Edit_Here (Text, Spans, Span_Count, P).Past)
      else Lit_Count_From (Text, Spans, Span_Count, P + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                  and then Span_Count <= Spans'Last and then P <= Text'Length + 1,
          Post => Lit_Count_From'Result <= Text'Length - P + 1,
          Subprogram_Variant => (Decreases => Text'Length - P + 1);

   function No_Edit return Edit is
     ((First => 1, Past => 1, Replacement => (others => ' '), Replacement_Length => 0));

   function Nth_Lit_From (Text : String; Spans : Span_Array; Span_Count : Natural; P : Positive; N : Positive)
     return Edit is
     (if P > Text'Length then No_Edit
      elsif not Lit_Edit_At (Text, Spans, Span_Count, P) then Nth_Lit_From (Text, Spans, Span_Count, P + 1, N)
      elsif N = 1 then Lit_Edit_Here (Text, Spans, Span_Count, P)
      else Nth_Lit_From (Text, Spans, Span_Count, Lit_Edit_Here (Text, Spans, Span_Count, P).Past, N - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                  and then Span_Count <= Spans'Last and then P <= Text'Length + 1,
          Post => Nth_Lit_From'Result.Past <= Text'Length + 1,
          Subprogram_Variant => (Decreases => Text'Length - P + 1);

   function Lit_Edit_Count (Text : String; Spans : Span_Array; Span_Count : Natural) return Natural is
     (Lit_Count_From (Text, Spans, Span_Count, 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                  and then Span_Count <= Spans'Last,
          Post => Lit_Edit_Count'Result <= Text'Length;

   function Nth_Lit_Edit (Text : String; Spans : Span_Array; Span_Count : Natural; N : Positive) return Edit is
     (Nth_Lit_From (Text, Spans, Span_Count, 1, N))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                  and then Span_Count <= Spans'Last,
          Post => Nth_Lit_Edit'Result.Past <= Text'Length + 1;

   function Op_Clear (Text : String; Spans : Span_Array; Span_Count : Natural; Sw : Swap_Index; P : Positive)
     return Boolean is
     (Clear_Of_Literals (Spans, Span_Count, P + 1, P + Swap_From (Sw)'Length - 1))
     with Pre => Spans'First = 1 and then Span_Count <= Spans'Last and then P <= Max_Text;

   function Arrow_After (Text : String; Sw : Swap_Index; P : Positive) return Boolean is
     (Sw = 9 and then P + 3 <= Text'Length and then Text (P + 3) = '>')
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then P <= Text'Length;

   function Find_Op (Text : String; Sw : Swap_Index; P : Positive) return Natural is
     (if P > Text'Length then 0
      elsif Operator_At (Text, (First => P, Swap => Sw)) then P
      else Find_Op (Text, Sw, P + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then P <= Text'Length + 1,
          Post => Find_Op'Result = 0
                  or else (Find_Op'Result >= P and then Find_Op'Result <= Text'Length
                           and then Operator_At (Text, (First => Find_Op'Result, Swap => Sw))),
          Subprogram_Variant => (Decreases => Text'Length - P + 1);

   function Op_Hit (Text : String; Spans : Span_Array; Span_Count : Natural; Sw : Swap_Index; A : Positive)
     return Boolean is
     (not Arrow_After (Text, Sw, A) and then Op_Clear (Text, Spans, Span_Count, Sw, A))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                 and then Span_Count <= Spans'Last and then A <= Text'Length;

   function Op_Resume (Text : String; Spans : Span_Array; Span_Count : Natural; Sw : Swap_Index; A : Positive)
     return Positive is
     (if Arrow_After (Text, Sw, A) then A + Swap_From (Sw)'Length
      elsif not Op_Clear (Text, Spans, Span_Count, Sw, A) then A + 1
      else A + Swap_From (Sw)'Length)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                  and then Span_Count <= Spans'Last and then A <= Text'Length,
          Post => Op_Resume'Result > A and then Op_Resume'Result <= A + 4;

   function Sw_Count_From (Text : String; Spans : Span_Array; Span_Count : Natural; Sw : Swap_Index; P : Positive)
     return Natural is
     (if P > Text'Length or else Find_Op (Text, Sw, P) = 0 then 0
      elsif Op_Hit (Text, Spans, Span_Count, Sw, Find_Op (Text, Sw, P))
      then 1 + Sw_Count_From (Text, Spans, Span_Count, Sw,
                              Positive'Min (Op_Resume (Text, Spans, Span_Count, Sw, Find_Op (Text, Sw, P)), Text'Length + 1))
      else Sw_Count_From (Text, Spans, Span_Count, Sw,
                          Positive'Min (Op_Resume (Text, Spans, Span_Count, Sw, Find_Op (Text, Sw, P)), Text'Length + 1)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                  and then Span_Count <= Spans'Last and then P <= Text'Length + 1,
          Post => Sw_Count_From'Result <= Text'Length - P + 1,
          Subprogram_Variant => (Decreases => Text'Length - P + 1);

   function No_Op return Operator_Edit is
     ((First => 1, Swap => 1));

   function Sw_Nth_From (Text : String; Spans : Span_Array; Span_Count : Natural; Sw : Swap_Index; P : Positive;
                         N : Positive) return Operator_Edit is
     (if P > Text'Length or else Find_Op (Text, Sw, P) = 0 then No_Op
      elsif Op_Hit (Text, Spans, Span_Count, Sw, Find_Op (Text, Sw, P)) and then N = 1
      then (First => Find_Op (Text, Sw, P), Swap => Sw)
      elsif Op_Hit (Text, Spans, Span_Count, Sw, Find_Op (Text, Sw, P))
      then Sw_Nth_From (Text, Spans, Span_Count, Sw,
                        Positive'Min (Op_Resume (Text, Spans, Span_Count, Sw, Find_Op (Text, Sw, P)), Text'Length + 1),
                        N - 1)
      else Sw_Nth_From (Text, Spans, Span_Count, Sw,
                        Positive'Min (Op_Resume (Text, Spans, Span_Count, Sw, Find_Op (Text, Sw, P)), Text'Length + 1),
                        N))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                  and then Span_Count <= Spans'Last and then P <= Text'Length + 1,
          Subprogram_Variant => (Decreases => Text'Length - P + 1);

   function Ops_Upto (Text : String; Spans : Span_Array; Span_Count : Natural; Sw : Natural) return Natural is
     (if Sw = 0 then 0
      else Ops_Upto (Text, Spans, Span_Count, Sw - 1) + Sw_Count_From (Text, Spans, Span_Count, Sw, 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                  and then Span_Count <= Spans'Last and then Sw <= 10,
          Post => Ops_Upto'Result <= Sw * Text'Length,
          Subprogram_Variant => (Decreases => Sw);

   function Op_Edit_Count (Text : String; Spans : Span_Array; Span_Count : Natural) return Natural is
     (Ops_Upto (Text, Spans, Span_Count, 10))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                  and then Span_Count <= Spans'Last,
          Post => Op_Edit_Count'Result <= 10 * Text'Length;

   function Nth_Op_In (Text : String; Spans : Span_Array; Span_Count : Natural; Sw : Swap_Index; N : Positive)
     return Operator_Edit is
     (if N <= Ops_Upto (Text, Spans, Span_Count, Sw)
      then Sw_Nth_From (Text, Spans, Span_Count, Sw, 1, N - Ops_Upto (Text, Spans, Span_Count, Sw - 1))
      elsif Sw = 10 then No_Op
      else Nth_Op_In (Text, Spans, Span_Count, Sw + 1, N))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                  and then Span_Count <= Spans'Last and then N > Ops_Upto (Text, Spans, Span_Count, Sw - 1),
          Subprogram_Variant => (Decreases => 10 - Sw);

   function Nth_Op_Edit (Text : String; Spans : Span_Array; Span_Count : Natural; N : Positive) return Operator_Edit is
     (Nth_Op_In (Text, Spans, Span_Count, 1, N))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Spans'First = 1
                 and then Span_Count <= Spans'Last;


   function Apply (Text : String; First : Positive; Past : Positive; Replacement : String) return String is
     (Text (1 .. First - 1) & Replacement & Text (Past .. Text'Last))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text
                  and then First <= Past and then Past <= Text'Length + 1
                  and then Replacement'First = 1 and then Replacement'Length <= Max_Replacement,
          Post => Apply'Result'Length = Text'Length - (Past - First) + Replacement'Length;

end Lovelace_Mutation_Rules_Pkg;
