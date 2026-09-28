--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 198b8e243b76253dec2f2dbacc60bb45a74469c96763531c0767cba33186d12b
--
package Lovelace_Lex_Rules_Pkg with SPARK_Mode, Pure is

   Max_Text : constant := 1_048_576;
   LF : constant Character := Character'Val (10);
   HT : constant Character := Character'Val (9);
   CR : constant Character := Character'Val (13);

   subtype Rune_Width is Natural range 0 .. 4;

   type Width_Array is array (Positive range <>) of Rune_Width;

   type Mask_Class is (Outside, Code, Quote, In_String, Char_Literal);

   type Mask_Array is array (Positive range <>) of Mask_Class;

   type Span is record
      First   : Positive := 1;
      Past    : Positive := 1;
      Is_Char : Boolean  := False;
   end record;

   type Span_Array is array (Positive range <>) of Span;

   function Is_Ident_Char (C : Character) return Boolean is
     (C = '_' or else C in '0' .. '9' or else C in 'A' .. 'Z' or else C in 'a' .. 'z')
     with Global => null;

   function Is_Space (C : Character) return Boolean is
     (C = ' ' or else C = HT or else C = LF or else C = CR)
     with Global => null;

   function Lower (C : Character) return Character is
     ((if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C))
     with Post => (if C not in 'A' .. 'Z' then Lower'Result = C);

   function Equal_Ignoring_Case (Word : String; Lit : String) return Boolean is
     (Word'Length = Lit'Length
      and then (for all K in 0 .. Word'Length - 1 =>
                  Lower (Word (Word'First + K)) = Lit (Lit'First + K)))
     with Pre  => Word'Length <= Max_Text and then Lit'First = 1 and then Lit'Length <= 64,
          Post => (if Equal_Ignoring_Case'Result then Word'Length = Lit'Length);

   function Is_Reserved (Word : String) return Boolean is
     (Equal_Ignoring_Case (Word, "abort") or else Equal_Ignoring_Case (Word, "abs") or else Equal_Ignoring_Case (Word, "abstract") or else Equal_Ignoring_Case (Word, "accept") or else Equal_Ignoring_Case (Word, "access") or else Equal_Ignoring_Case (Word, "aliased") or else Equal_Ignoring_Case (Word, "all") or else Equal_Ignoring_Case (Word, "and") or else Equal_Ignoring_Case (Word, "array") or else Equal_Ignoring_Case (Word, "at") or else Equal_Ignoring_Case (Word, "begin") or else Equal_Ignoring_Case (Word, "body") or else Equal_Ignoring_Case (Word, "case") or else Equal_Ignoring_Case (Word, "constant") or else Equal_Ignoring_Case (Word, "declare") or else Equal_Ignoring_Case (Word, "delay") or else Equal_Ignoring_Case (Word, "delta") or else Equal_Ignoring_Case (Word, "digits") or else Equal_Ignoring_Case (Word, "do") or else Equal_Ignoring_Case (Word, "else") or else Equal_Ignoring_Case (Word, "elsif") or else Equal_Ignoring_Case (Word, "end") or else Equal_Ignoring_Case (Word, "entry") or else Equal_Ignoring_Case (Word, "exception") or else Equal_Ignoring_Case (Word, "exit") or else Equal_Ignoring_Case (Word, "for") or else Equal_Ignoring_Case (Word, "function") or else Equal_Ignoring_Case (Word, "generic") or else Equal_Ignoring_Case (Word, "goto") or else Equal_Ignoring_Case (Word, "if") or else Equal_Ignoring_Case (Word, "in") or else Equal_Ignoring_Case (Word, "interface") or else Equal_Ignoring_Case (Word, "is") or else Equal_Ignoring_Case (Word, "limited") or else Equal_Ignoring_Case (Word, "loop") or else Equal_Ignoring_Case (Word, "mod") or else Equal_Ignoring_Case (Word, "new") or else Equal_Ignoring_Case (Word, "not") or else Equal_Ignoring_Case (Word, "null") or else Equal_Ignoring_Case (Word, "of") or else Equal_Ignoring_Case (Word, "or") or else Equal_Ignoring_Case (Word, "others") or else Equal_Ignoring_Case (Word, "out") or else Equal_Ignoring_Case (Word, "overriding") or else Equal_Ignoring_Case (Word, "package") or else Equal_Ignoring_Case (Word, "parallel") or else Equal_Ignoring_Case (Word, "pragma") or else Equal_Ignoring_Case (Word, "private") or else Equal_Ignoring_Case (Word, "procedure") or else Equal_Ignoring_Case (Word, "protected") or else Equal_Ignoring_Case (Word, "raise") or else Equal_Ignoring_Case (Word, "range") or else Equal_Ignoring_Case (Word, "record") or else Equal_Ignoring_Case (Word, "rem") or else Equal_Ignoring_Case (Word, "renames") or else Equal_Ignoring_Case (Word, "requeue") or else Equal_Ignoring_Case (Word, "return") or else Equal_Ignoring_Case (Word, "reverse") or else Equal_Ignoring_Case (Word, "select") or else Equal_Ignoring_Case (Word, "separate") or else Equal_Ignoring_Case (Word, "some") or else Equal_Ignoring_Case (Word, "subtype") or else Equal_Ignoring_Case (Word, "synchronized") or else Equal_Ignoring_Case (Word, "tagged") or else Equal_Ignoring_Case (Word, "task") or else Equal_Ignoring_Case (Word, "terminate") or else Equal_Ignoring_Case (Word, "then") or else Equal_Ignoring_Case (Word, "type") or else Equal_Ignoring_Case (Word, "until") or else Equal_Ignoring_Case (Word, "use") or else Equal_Ignoring_Case (Word, "when") or else Equal_Ignoring_Case (Word, "while") or else Equal_Ignoring_Case (Word, "with") or else Equal_Ignoring_Case (Word, "xor"))
     with Pre  => Word'Length <= Max_Text,
          Post => (if Word'Length > 12 then not Is_Reserved'Result);

   function Facts_Consistent (Text : String; Widths : Width_Array) return Boolean is
     (Text'First = 1 and then Text'Length <= Max_Text
      and then Widths'First = 1 and then Widths'Last = Text'Last
      and then (for all K in 1 .. Text'Length => Widths (K) <= Text'Length - K + 1)
      and then (for all K in 1 .. Text'Length =>
                  (if Character'Pos (Text (K)) < 128 then Widths (K) = 1)))
     with Post => (if Facts_Consistent'Result then (Text'First = 1 and then Text'Length <= Max_Text));

   function Previous_Non_Space (Text : String; I : Positive) return Natural is
     (if I = 1 then 0
      elsif not Is_Space (Text (I - 1)) then I - 1
      else Previous_Non_Space (Text, I - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length + 1,
          Post => Previous_Non_Space'Result < I
           and then (for all K in Previous_Non_Space'Result + 1 .. I - 1 => Is_Space (Text (K)))
           and then (if Previous_Non_Space'Result > 0 then not Is_Space (Text (Previous_Non_Space'Result))),
          Subprogram_Variant => (Decreases => I);

   function Word_Start (Text : String; J : Positive) return Positive is
     (if J = 1 then 1
      elsif not Is_Ident_Char (Text (J - 1)) then J
      else Word_Start (Text, J - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then J <= Text'Length
           and then Is_Ident_Char (Text (J)),
          Post => Word_Start'Result <= J
           and then (for all K in Word_Start'Result .. J => Is_Ident_Char (Text (K)))
           and then (if Word_Start'Result > 1 then not Is_Ident_Char (Text (Word_Start'Result - 1))),
          Subprogram_Variant => (Decreases => J);

   function Attribute_After (Text : String; P : Positive) return Boolean is
     (Text (P) = ')' or else
      (Is_Ident_Char (Text (P)) and then
       (Equal_Ignoring_Case (Text (Word_Start (Text, P) .. P), "all")
        or else not Is_Reserved (Text (Word_Start (Text, P) .. P)))))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then P <= Text'Length,
          Post => (if Text (P) = ')' then Attribute_After'Result);

   function Tick_Is_Attribute (Text : String; I : Positive) return Boolean is
     (Previous_Non_Space (Text, I) > 0 and then Attribute_After (Text, Previous_Non_Space (Text, I)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length,
          Post => (if Previous_Non_Space (Text, I) = 0 then not Tick_Is_Attribute'Result);

   function Char_Literal_Length (Text : String; Widths : Width_Array; I : Positive) return Natural is
     (if Text (I) /= ''' or else Tick_Is_Attribute (Text, I) then 0
      elsif I = Text'Length then 0
      elsif Widths (I + 1) = 0 or else Text (I + 1) = LF then 0
      elsif I + 1 + Widths (I + 1) <= Text'Length
        and then Text (I + 1 + Widths (I + 1)) = ''' then Widths (I + 1) + 2
      else 0)
     with Pre  => Facts_Consistent (Text, Widths) and then I <= Text'Length,
          Post => (Char_Literal_Length'Result = 0 or else Char_Literal_Length'Result = Widths (I + 1) + 2)
           and then (if Char_Literal_Length'Result > 0 then
                       (Text (I) = ''' and then Char_Literal_Length'Result >= 3
                        and then I + Char_Literal_Length'Result - 1 <= Text'Length
                        and then Text (I + Char_Literal_Length'Result - 1) = '''))
           and then (if Text (I) /= ''' then Char_Literal_Length'Result = 0);

   subtype Literal_Rest is Natural range 0 .. 5;

   type Walk_State is record
      In_Str : Boolean      := False;
      Rest   : Literal_Rest := 0;
   end record;

   function Initial_State return Walk_State is
     ((In_Str => False, Rest => 0));

   function Opens_Literal (Text : String; Widths : Width_Array; K : Positive; S : Walk_State) return Boolean is
     (S.Rest = 0 and then not S.In_Str and then Char_Literal_Length (Text, Widths, K) > 0)
     with Pre => Facts_Consistent (Text, Widths) and then K <= Text'Length;

   function Class_In (Text : String; Widths : Width_Array; K : Positive; S : Walk_State) return Mask_Class is
     (if S.Rest > 0 then Char_Literal
      elsif Opens_Literal (Text, Widths, K, S) then Char_Literal
      elsif Text (K) = '"' then Quote
      elsif S.In_Str then In_String
      else Code)
     with Pre  => Facts_Consistent (Text, Widths) and then K <= Text'Length,
          Post => Class_In'Result /= Outside
                  and then (if Class_In'Result = Quote then Text (K) = '"')
                  and then (if Class_In'Result = Code then Text (K) /= '"');

   function Next_State (Text : String; Widths : Width_Array; K : Positive; S : Walk_State) return Walk_State is
     (if S.Rest > 0 then (In_Str => S.In_Str, Rest => S.Rest - 1)
      elsif Opens_Literal (Text, Widths, K, S)
      then (In_Str => False, Rest => Char_Literal_Length (Text, Widths, K) - 1)
      elsif Text (K) = '"' then (In_Str => not S.In_Str, Rest => 0)
      else S)
     with Pre => Facts_Consistent (Text, Widths) and then K <= Text'Length;

   function State_Before (Text : String; Widths : Width_Array; From : Positive; K : Positive) return Walk_State is
     (if K <= From then Initial_State
      else Next_State (Text, Widths, K - 1, State_Before (Text, Widths, From, K - 1)))
     with Pre  => Facts_Consistent (Text, Widths) and then K <= Text'Length + 1,
          Subprogram_Variant => (Decreases => K);

   function Mask_At (Text : String; Widths : Width_Array; From : Positive; K : Positive) return Mask_Class is
     (if K < From then Outside
      else Class_In (Text, Widths, K, State_Before (Text, Widths, From, K)))
     with Pre  => Facts_Consistent (Text, Widths) and then K <= Text'Length,
          Post => ((Mask_At'Result = Outside) = (K < From));

   function No_Span (Text : String) return Span is
     ((First => Text'Length + 1, Past => Text'Length + 1, Is_Char => False))
     with Pre => Text'Length <= Max_Text;

   function Stop_At (Text : String; J : Positive) return Positive is
     (if J > Text'Length then J
      elsif Text (J) = '"' or else Text (J) = LF then J
      else Stop_At (Text, J + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then J <= Text'Length + 1,
          Post => Stop_At'Result >= J and then Stop_At'Result <= Text'Length + 1,
          Subprogram_Variant => (Decreases => Text'Length - J + 1);

   function String_Past (Text : String; P : Positive) return Positive is
     (if Stop_At (Text, P + 1) <= Text'Length and then Text (Stop_At (Text, P + 1)) = '"'
      then Stop_At (Text, P + 1) + 1
      else Stop_At (Text, P + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then P <= Text'Length,
          Post => String_Past'Result > P and then String_Past'Result <= Text'Length + 1;

   function Next_Span (Text : String; Widths : Width_Array; P : Positive) return Span is
     (if P > Text'Length then No_Span (Text)
      elsif Text (P) = '"' then (First => P, Past => String_Past (Text, P), Is_Char => False)
      elsif Char_Literal_Length (Text, Widths, P) > 0
      then (First => P, Past => P + Char_Literal_Length (Text, Widths, P), Is_Char => True)
      else Next_Span (Text, Widths, P + 1))
     with Pre  => Facts_Consistent (Text, Widths) and then P <= Text'Length + 1,
          Post => Next_Span'Result.First >= P
                  and then Next_Span'Result.Past <= Text'Length + 1
                  and then (Next_Span'Result.First > Text'Length
                            or else (Next_Span'Result.First < Next_Span'Result.Past
                                     and then (if Next_Span'Result.Is_Char
                                               then Text (Next_Span'Result.First) = '''
                                               else Text (Next_Span'Result.First) = '"'))),
          Subprogram_Variant => (Decreases => Text'Length - P + 1);

   function Span_Count_From (Text : String; Widths : Width_Array; P : Positive) return Natural is
     (if Next_Span (Text, Widths, P).First > Text'Length then 0
      else 1 + Span_Count_From (Text, Widths, Next_Span (Text, Widths, P).Past))
     with Pre  => Facts_Consistent (Text, Widths) and then P <= Text'Length + 1,
          Post => Span_Count_From'Result <= Text'Length - P + 1,
          Subprogram_Variant => (Decreases => Text'Length - P + 1);

   function Span_Count (Text : String; Widths : Width_Array) return Natural is
     (Span_Count_From (Text, Widths, 1))
     with Pre  => Facts_Consistent (Text, Widths),
          Post => Span_Count'Result <= Text'Length;

   function Nth_Span_From (Text : String; Widths : Width_Array; P : Positive; N : Positive) return Span is
     (if Next_Span (Text, Widths, P).First > Text'Length then No_Span (Text)
      elsif N = 1 then Next_Span (Text, Widths, P)
      else Nth_Span_From (Text, Widths, Next_Span (Text, Widths, P).Past, N - 1))
     with Pre  => Facts_Consistent (Text, Widths) and then P <= Text'Length + 1,
          Post => Nth_Span_From'Result.Past <= Text'Length + 1,
          Subprogram_Variant => (Decreases => Text'Length - P + 1);

   function Nth_Span (Text : String; Widths : Width_Array; N : Positive) return Span is
     (Nth_Span_From (Text, Widths, 1, N))
     with Pre  => Facts_Consistent (Text, Widths),
          Post => Nth_Span'Result.Past <= Text'Length + 1;

   function Overlaps (S : Span; From : Positive; Past : Positive) return Boolean is
     (From < S.Past and then Past > S.First)
     with Global => null,
          Post => (if Overlaps'Result then ((From < S.Past) and then (Past > S.First)));

end Lovelace_Lex_Rules_Pkg;
