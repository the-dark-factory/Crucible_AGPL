--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 4bc194471f6061038596b5bfcbf56f9da692a1779d53216baf0b8c7261fe9542
--
with Lovelace_Lex_Rules_Pkg;
use Lovelace_Lex_Rules_Pkg;
with Lovelace_Text_Rules_Pkg;
use Lovelace_Text_Rules_Pkg;

package Lovelace_Lexical_Guard_Pkg with SPARK_Mode, Pure is

   type Fault_Kind is (No_Fault, Unterminated_String, Attribute_Names_Nothing,
                       Ill_Formed_Char_Literal, Base_Out_Of_Range, Digit_Not_Below_Base);

   type Fault is record
      Kind     : Fault_Kind := No_Fault;
      At_Index : Positive   := 1;
   end record;

   subtype Capped is Natural range 0 .. 17;

   function No_Fault_Found return Fault is
     ((Kind => No_Fault, At_Index => 1));

   function Fault_At (K : Fault_Kind; I : Positive) return Fault is
     ((Kind => K, At_Index => I));

   function Is_Letter (C : Character) return Boolean is
     (C in 'A' .. 'Z' or else C in 'a' .. 'z');

   function Is_Digit (C : Character) return Boolean is
     (C in '0' .. '9');

   function Is_Run_Char (C : Character) return Boolean is
     (C in '0' .. '9' or else C = '_');

   function Is_Class_Char (C : Character) return Boolean is
     (Is_Ident_Char (C) or else C = '.');

   function No_Special (Text : String; I : Positive) return Boolean is
     ((for all K in I .. Text'Length => Text (K) /= '"' and then Text (K) /= '''))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text;

   function No_Hash (Text : String; I : Positive) return Boolean is
     ((for all K in I .. Text'Length => Text (K) /= '#'))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text;

   function String_End (Text : String; J : Positive) return Positive is
     (if J > Text'Length then J
      elsif Text (J) = '"' or else Text (J) = LF then J
      else String_End (Text, J + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then J <= Text'Length + 1,
          Post => String_End'Result >= J and then String_End'Result <= Text'Length + 1,
          Subprogram_Variant => (Decreases => Text'Length - J + 1);

   function Closes_String (Text : String; I : Positive) return Boolean is
     (String_End (Text, I + 1) <= Text'Length and then Text (String_End (Text, I + 1)) = '"')
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length;

   function Attr_Start (Text : String; I : Positive) return Positive is
     (Skip_WS (Text, I + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length,
          Post => Attr_Start'Result > I and then Attr_Start'Result <= Text'Length + 1;

   function Names_Attribute (Text : String; I : Positive) return Boolean is
     (Attr_Start (Text, I) <= Text'Length
      and then (Text (Attr_Start (Text, I)) = '(' or else Is_Letter (Text (Attr_Start (Text, I)))))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length;

   function First_Pass (Text : String; Widths : Width_Array; I : Positive) return Fault is
     (if I > Text'Length then No_Fault_Found
      elsif Text (I) = '"' and then not Closes_String (Text, I) then Fault_At (Unterminated_String, I)
      elsif Text (I) = '"' then First_Pass (Text, Widths, String_End (Text, I + 1) + 1)
      elsif Text (I) = ''' and then Tick_Is_Attribute (Text, I) and then not Names_Attribute (Text, I)
      then Fault_At (Attribute_Names_Nothing, I)
      elsif Text (I) = ''' and then Tick_Is_Attribute (Text, I) then First_Pass (Text, Widths, I + 1)
      elsif Text (I) = ''' and then Char_Literal_Length (Text, Widths, I) = 0
      then Fault_At (Ill_Formed_Char_Literal, I)
      elsif Text (I) = ''' then First_Pass (Text, Widths, I + Char_Literal_Length (Text, Widths, I))
      else First_Pass (Text, Widths, I + 1))
     with Pre  => Facts_Consistent (Text, Widths) and then I <= Text'Length + 1,
          Post => (First_Pass'Result.Kind = No_Fault
                   or else (First_Pass'Result.At_Index >= I and then First_Pass'Result.At_Index <= Text'Length))
                  and then First_Pass'Result.Kind /= Base_Out_Of_Range
                  and then First_Pass'Result.Kind /= Digit_Not_Below_Base
                  and then (if No_Special (Text, I) then First_Pass'Result.Kind = No_Fault),
          Subprogram_Variant => (Decreases => Text'Length - I + 1);

   function Run_End (Text : String; J : Positive) return Positive is
     (if J > Text'Length then J
      elsif not Is_Run_Char (Text (J)) then J
      else Run_End (Text, J + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then J <= Text'Length + 1,
          Post => Run_End'Result >= J and then Run_End'Result <= Text'Length + 1,
          Subprogram_Variant => (Decreases => Text'Length - J + 1);

   function Class_End (Text : String; J : Positive) return Positive is
     (if J > Text'Length then J
      elsif not Is_Class_Char (Text (J)) then J
      else Class_End (Text, J + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then J <= Text'Length + 1,
          Post => Class_End'Result >= J and then Class_End'Result <= Text'Length + 1,
          Subprogram_Variant => (Decreases => Text'Length - J + 1);

   function Boundary_Before (Text : String; P : Positive) return Boolean is
     (P = 1 or else not Is_Ident_Char (Text (P - 1)))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then P <= Text'Length;

   function First_Hash (Text : String; P : Positive) return Positive is
     (Run_End (Text, P))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then P <= Text'Length,
          Post => First_Hash'Result >= P and then First_Hash'Result <= Text'Length + 1;

   function Second_Hash (Text : String; P : Positive) return Positive is
     (Class_End (Text, First_Hash (Text, P) + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then P <= Text'Length
                  and then First_Hash (Text, P) <= Text'Length,
          Post => Second_Hash'Result > First_Hash (Text, P) and then Second_Hash'Result <= Text'Length + 1;

   function Match_At (Text : String; P : Positive) return Boolean is
     (Boundary_Before (Text, P)
      and then Is_Digit (Text (P))
      and then First_Hash (Text, P) <= Text'Length
      and then Text (First_Hash (Text, P)) = '#'
      and then Second_Hash (Text, P) <= Text'Length
      and then Text (Second_Hash (Text, P)) = '#')
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then P <= Text'Length;

   function Digit_Of (C : Character) return Natural is
     (if C in '0' .. '9' then Character'Pos (C) - Character'Pos ('0')
      elsif C in 'a' .. 'z' then Character'Pos (C) - Character'Pos ('a') + 10
      elsif C in 'A' .. 'Z' then Character'Pos (C) - Character'Pos ('A') + 10
      else 36)
     with Post => Digit_Of'Result <= 36;

   function Base_Value (Text : String; J : Positive; E : Natural; Acc : Capped) return Capped is
     (if J > E then Acc
      elsif Text (J) = '_' then Base_Value (Text, J + 1, E, Acc)
      else Base_Value (Text, J + 1, E, Natural'Min (Acc * 10 + Digit_Of (Text (J)), 17)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then E <= Text'Length
                  and then J <= E + 1,
          Subprogram_Variant => (Decreases => E - J + 1);

   function Bad_Digit_From (Text : String; J : Positive; E : Natural; Base : Natural) return Natural is
     (if J > E then 0
      elsif Text (J) /= '_' and then Text (J) /= '.' and then Digit_Of (Text (J)) >= Base then J
      else Bad_Digit_From (Text, J + 1, E, Base))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then E <= Text'Length
                  and then J <= E + 1,
          Post => Bad_Digit_From'Result = 0
                  or else (Bad_Digit_From'Result >= J and then Bad_Digit_From'Result <= E),
          Subprogram_Variant => (Decreases => E - J + 1);

   function Any_Overlap (Spans : Span_Array; Count : Natural; From : Positive; Past : Positive) return Boolean is
     ((for some K in 1 .. Count => Overlaps (Spans (K), From, Past)))
     with Pre => Spans'First = 1 and then Count <= Spans'Last;

   function Based_Pass (Text : String; Spans : Span_Array; Count : Natural; P : Positive) return Fault is
     (if P > Text'Length then No_Fault_Found
      elsif not Match_At (Text, P) then Based_Pass (Text, Spans, Count, P + 1)
      elsif Any_Overlap (Spans, Count, P, Second_Hash (Text, P) + 1)
      then Based_Pass (Text, Spans, Count, Second_Hash (Text, P) + 1)
      elsif Base_Value (Text, P, First_Hash (Text, P) - 1, 0) not in 2 .. 16
      then Fault_At (Base_Out_Of_Range, P)
      elsif Bad_Digit_From (Text, First_Hash (Text, P) + 1, Second_Hash (Text, P) - 1,
                            Base_Value (Text, P, First_Hash (Text, P) - 1, 0)) /= 0
      then Fault_At (Digit_Not_Below_Base, P)
      else Based_Pass (Text, Spans, Count, Second_Hash (Text, P) + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text
                  and then Spans'First = 1 and then Count <= Spans'Last and then P <= Text'Length + 1,
          Post => (Based_Pass'Result.Kind = No_Fault
                   or else (Based_Pass'Result.At_Index >= P and then Based_Pass'Result.At_Index <= Text'Length
                            and then Match_At (Text, Based_Pass'Result.At_Index)))
                  and then (Based_Pass'Result.Kind = No_Fault
                            or else Based_Pass'Result.Kind = Base_Out_Of_Range
                            or else Based_Pass'Result.Kind = Digit_Not_Below_Base)
                  and then (if No_Hash (Text, P) then Based_Pass'Result.Kind = No_Fault),
          Subprogram_Variant => (Decreases => Text'Length - P + 1);

   function Guard (Text : String; Widths : Width_Array; Spans : Span_Array; Count : Natural) return Fault is
     (if First_Pass (Text, Widths, 1).Kind /= No_Fault then First_Pass (Text, Widths, 1)
      else Based_Pass (Text, Spans, Count, 1))
     with Pre  => Facts_Consistent (Text, Widths) and then Spans'First = 1 and then Count <= Spans'Last,
          Post => (if No_Special (Text, 1) and then No_Hash (Text, 1) then Guard'Result.Kind = No_Fault)
                  and then (Guard'Result.Kind = No_Fault or else Guard'Result.At_Index <= Text'Length);

   function Well_Formed (Text : String; Widths : Width_Array; Spans : Span_Array; Count : Natural) return Boolean is
     (Guard (Text, Widths, Spans, Count).Kind = No_Fault)
     with Pre => Facts_Consistent (Text, Widths) and then Spans'First = 1 and then Count <= Spans'Last;

end Lovelace_Lexical_Guard_Pkg;
