--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: a39ba1ab4400f80c4b9b5c16347c7388c70df5ec36b2f0e4415609a2fd135fee
--
with Tower_Bounds_Pkg;
package Tower_Scan_Pkg with SPARK_Mode is

   type Kind_Type is (K_None, K_String, K_Bare, K_Composite);

   type Span_Type is record
      found : Boolean := False;
      kind  : Kind_Type := K_None;
      first : Natural := 0;
      last  : Natural := 0;
   end record;

   function Is_Key_At (Line : String; Key : String; I : Positive) return Boolean
     is ((I in Line'Range)
         and then (I + Key'Length + 1 <= Line'Last)
         and then (Line (I) = '"')
         and then (for all K in 1 .. Key'Length => Line (I + K) = Key (Key'First + K - 1))
         and then (Line (I + Key'Length + 1) = '"')
         and then (for some C in I + Key'Length + 2 .. Line'Last =>
                     (Line (C) = ':')
                     and then (for all S in I + Key'Length + 2 .. C - 1 => Line (S) = ' ')))
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64
                   and then I <= Line'Last),
          Post => ((if Is_Key_At'Result then I in Line'Range)
                   and then (if Is_Key_At'Result then Line (I) = '"'));

   function Has_Key (Line : String; Key : String) return Boolean
     is (for some I in Line'Range => Is_Key_At (Line, Key, I))
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64),
          Post => ((Has_Key'Result = True) = (for some I in Line'Range => Is_Key_At (Line, Key, I)));

   function No_Key_Before (Line : String; Key : String; N : Positive) return Boolean
     is (for all J in Line'First .. N - 1 => not Is_Key_At (Line, Key, J))
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64
                   and then N - 1 <= Line'Last),
          Post => ((No_Key_Before'Result = True) = (for all J in Line'First .. N - 1 => not Is_Key_At (Line, Key, J)));

   function Key_Position (Line : String; Key : String) return Natural
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64),
          Post => ((Key_Position'Result = 0 or else Key_Position'Result in Line'Range)
                   and then ((Key_Position'Result /= 0) = Has_Key (Line, Key))
                   and then (if Key_Position'Result /= 0 then Is_Key_At (Line, Key, Key_Position'Result))
                   and then (if Key_Position'Result /= 0 then No_Key_Before (Line, Key, Key_Position'Result)));

   --  ======================================================================
   --  LINEAGE 5: JSON LOOKUP. Is_Key_At, Has_Key, No_Key_Before and Key_Position above
   --  are TEXTUAL helpers (where a "key" pattern first appears in the text), kept for the
   --  callers that pin positions. The functions below are the JSON lookup:
   --    Value_Span (Line, Key)          -- a member of the line's top-level object only
   --    Member_Span (Line, Obj, Key)    -- a member of the object at span Obj
   --    Element_Span (Line, Arr, Index) -- the Index-th (from 1) element of the array at Arr
   --  JSON whitespace is space, tab, LF and CR. Keys compare after JSON unescaping. A key
   --  present twice at the searched level is NOT found (refused). Brackets must pair ({ with },
   --  [ with ]) and balance; strings must close (a raw control character inside a string is left to the
   --  caller's string decoder, as in lineage 4). Anything
   --  malformed on the way to the answer is NOT found -- never a wrong span.
   --  ======================================================================

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);
   CR : constant Character := Character'Val (13);

   Max_Depth : constant := 10_000;
   type Bracket_Stack is array (1 .. Max_Depth) of Character;

   function Empty_Stack return Bracket_Stack is
     ([others => ' ']);

   function Push (S : Bracket_Stack; D : Natural; C : Character) return Bracket_Stack is
     ((S with delta D + 1 => C))
     with Pre => D < Max_Depth;

   function No_Span return Span_Type is
     ((found => False, kind => K_None, first => 0, last => 0));

   function Is_WS (C : Character) return Boolean is
     (C = ' ' or else C = HT or else C = LF or else C = CR);

   function Kind_Of (C : Character) return Kind_Type is
     ((if C = '"' then K_String elsif C = '{' or else C = '[' then K_Composite else K_Bare));

   function Is_Bare_Char (C : Character) return Boolean is
     (C in 'a' .. 'z' or else C in 'A' .. 'Z' or else C in '0' .. '9' or else C = '+' or else C = '-' or else C = '.');

   function Is_Hex (C : Character) return Boolean is
     (C in '0' .. '9' or else C in 'a' .. 'f' or else C in 'A' .. 'F');

   function Hex_Val (C : Character) return Natural is
     ((if C in '0' .. '9' then Character'Pos (C) - Character'Pos ('0')
       elsif C in 'a' .. 'f' then Character'Pos (C) - Character'Pos ('a') + 10
       else Character'Pos (C) - Character'Pos ('A') + 10))
     with Pre  => Is_Hex (C),
          Post => Hex_Val'Result <= 15;

   --  Unescape: the character a one-letter JSON escape stands for; NUL when the letter is
   --  not a JSON escape (Key_From treats a NUL answer as "no match").
   function Unescape (C : Character) return Character is
     ((if C = '"' then '"' elsif C = '\' then '\' elsif C = '/' then '/'
       elsif C = 'b' then Character'Val (8) elsif C = 'f' then Character'Val (12)
       elsif C = 'n' then LF elsif C = 'r' then CR elsif C = 't' then HT
       else Character'Val (0)));

   --  WS_From: the first non-whitespace index at or after J, or 0.
   function WS_From (Line : String; J : Positive) return Natural
     is (if J > Line'Last then 0
         elsif not Is_WS (Line (J)) then J
         else WS_From (Line, J + 1))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then J - 1 <= Line'Last),
          Post => ((WS_From'Result = 0 or else WS_From'Result in J .. Line'Last)
                   and then (if WS_From'Result /= 0 then not Is_WS (Line (WS_From'Result)))),
          Subprogram_Variant => (Decreases => Line'Last - J + 1);

   function Skip_WS (Line : String; J : Positive) return Natural
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then J - 1 <= Line'Last),
          Post => (Skip_WS'Result = WS_From (Line, J));

   --  Str_From: scanning a string body from J with the escape flag Esc, the closing quote,
   --  or 0 (no closing quote).
   function Str_From (Line : String; J : Positive; Esc : Boolean) return Natural
     is (if J > Line'Last then 0
         elsif Esc then Str_From (Line, J + 1, False)
         elsif Line (J) = '\' then Str_From (Line, J + 1, True)
         elsif Line (J) = '"' then J
         else Str_From (Line, J + 1, False))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then J - 1 <= Line'Last),
          Post => ((Str_From'Result = 0 or else Str_From'Result in J .. Line'Last)
                   and then (if Str_From'Result /= 0 then Line (Str_From'Result) = '"')),
          Subprogram_Variant => (Decreases => Line'Last - J + 1);

   --  Str_End: the closing quote of the string whose opening quote is at Q, or 0.
   function Str_End (Line : String; Q : Positive) return Natural
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Q in Line'Range
                   and then Line (Q) = '"'),
          Post => (Str_End'Result = Str_From (Line, Q + 1, False));

   --  Comp_From: scanning from J with the bracket stack S (depth D), inside a string or not,
   --  with the escape flag Esc: the closer that empties the stack, or 0 (a mismatched or
   --  unbalanced bracket, deeper than Max_Depth, an unclosed string, or the end of the line).
   function Comp_From (Line : String; J : Positive; S : Bracket_Stack; D : Natural; In_Str : Boolean; Esc : Boolean) return Natural
     is (if J > Line'Last then 0
         elsif In_Str then
           (if Esc then Comp_From (Line, J + 1, S, D, True, False)
            elsif Line (J) = '\' then Comp_From (Line, J + 1, S, D, True, True)
            elsif Line (J) = '"' then Comp_From (Line, J + 1, S, D, False, False)
            else Comp_From (Line, J + 1, S, D, True, False))
         elsif Line (J) = '"' then Comp_From (Line, J + 1, S, D, True, False)
         elsif Line (J) = '{' or else Line (J) = '[' then
           (if D >= Max_Depth then 0 else Comp_From (Line, J + 1, Push (S, D, Line (J)), D + 1, False, False))
         elsif Line (J) = '}' or else Line (J) = ']' then
           (if D = 0 then 0
            elsif (S (D) = '{') /= (Line (J) = '}') then 0
            elsif D = 1 then J
            else Comp_From (Line, J + 1, S, D - 1, False, False))
         else Comp_From (Line, J + 1, S, D, False, False))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then J - 1 <= Line'Last
                   and then D <= Max_Depth),
          Post => ((Comp_From'Result = 0 or else Comp_From'Result in J .. Line'Last)
                   and then (if Comp_From'Result /= 0 then (Line (Comp_From'Result) = '}' or else Line (Comp_From'Result) = ']'))),
          Subprogram_Variant => (Decreases => Line'Last - J + 1);

   --  Comp_End: the closer matching the opener at F, or 0.
   function Comp_End (Line : String; F : Positive) return Natural
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then F in Line'Range
                   and then (Line (F) = '{' or else Line (F) = '[')),
          Post => (Comp_End'Result = Comp_From (Line, F, Empty_Stack, 0, False, False));

   --  Bare_From: the last index of the run of bare characters (letters, digits, + - .)
   --  that starts at J; J - 1 if the run is empty.
   function Bare_From (Line : String; J : Positive) return Natural
     is (if J > Line'Last then J - 1
         elsif Is_Bare_Char (Line (J)) then Bare_From (Line, J + 1)
         else J - 1)
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then J - 1 <= Line'Last),
          Post => (Bare_From'Result in J - 1 .. Line'Last),
          Subprogram_Variant => (Decreases => Line'Last - J + 1);

   --  Bare_End: the last character of the bare value (a number, true, false, null) at F, or 0.
   function Bare_End (Line : String; F : Positive) return Natural
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then F in Line'Range),
          Post => (Bare_End'Result = (if Is_Bare_Char (Line (F)) then Bare_From (Line, F) else 0));

   --  Value_End: the last character of the JSON value that starts at F, or 0 if malformed.
   function Value_End (Line : String; F : Positive) return Natural
     is (if Line (F) = '"' then Str_End (Line, F)
         elsif Line (F) = '{' or else Line (F) = '[' then Comp_End (Line, F)
         else Bare_End (Line, F))
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then F in Line'Range),
          Post => ((Value_End'Result = 0 or else Value_End'Result in F .. Line'Last)
                   and then (if Value_End'Result /= 0 and then Line (F) = '"' then Value_End'Result > F and then Line (Value_End'Result) = '"'));

   function Hex4 (Line : String; I : Positive) return Natural is
     (4096 * Hex_Val (Line (I)) + 256 * Hex_Val (Line (I + 1)) + 16 * Hex_Val (Line (I + 2)) + Hex_Val (Line (I + 3)))
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then I in Line'Range
                   and then I <= Line'Last - 3
                   and then Is_Hex (Line (I)) and then Is_Hex (Line (I + 1))
                   and then Is_Hex (Line (I + 2)) and then Is_Hex (Line (I + 3))),
          Post => Hex4'Result <= 65535;

   --  Key_From: the JSON-unescaped text of Line (I .. E - 1) equals Key (K .. Key'Last).
   function Key_From (Line : String; I : Positive; E : Positive; Key : String; K : Positive) return Boolean
     is (if I >= E then K > Key'Last
         elsif K > Key'Last then False
         elsif Line (I) /= '\' then (Line (I) = Key (K) and then Key_From (Line, I + 1, E, Key, K + 1))
         elsif I + 1 >= E then False
         elsif Line (I + 1) = 'u' then
           (I + 5 < E
            and then Is_Hex (Line (I + 2)) and then Is_Hex (Line (I + 3))
            and then Is_Hex (Line (I + 4)) and then Is_Hex (Line (I + 5))
            and then Hex4 (Line, I + 2) < 128
            and then Character'Val (Hex4 (Line, I + 2)) = Key (K)
            and then Key_From (Line, I + 6, E, Key, K + 1))
         else (Unescape (Line (I + 1)) /= Character'Val (0) and then Unescape (Line (I + 1)) = Key (K)
               and then Key_From (Line, I + 2, E, Key, K + 1)))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then E in Line'Range
                   and then I - 1 <= E and then I >= 1
                   and then Key'First = 1 and then Key'Length <= 64 and then K - 1 <= Key'Last),
          Subprogram_Variant => (Decreases => E - I);

   --  Key_Equals: the key string whose quotes are at Q and E, unescaped, equals Key.
   function Key_Equals (Line : String; Q : Positive; E : Positive; Key : String) return Boolean
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then E in Line'Range
                   and then Q < E and then Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64),
          Post => (Key_Equals'Result = Key_From (Line, Q + 1, E, Key, 1));

   --  Mem_From: walking the members of the object that closes at Last_Obj, from P (just after
   --  its '{' or after a ','), with Acc the value of the last member named Key so far and
   --  Count how many members named Key were seen (capped at 2): the answer.
   function Mem_From (Line : String; Last_Obj : Positive; P : Positive; Key : String; Acc : Span_Type; Count : Natural) return Span_Type
     is (declare
           S : constant Natural := Skip_WS (Line, P);
         begin
           (if S = 0 or else S >= Last_Obj or else Line (S) /= '"' then No_Span
            else
              (declare
                 KE : constant Natural := Str_End (Line, S);
               begin
                 (if KE = 0 or else KE >= Last_Obj then No_Span
                  else
                    (declare
                       C : constant Natural := Skip_WS (Line, KE + 1);
                     begin
                       (if C = 0 or else C >= Last_Obj or else Line (C) /= ':' then No_Span
                        else
                          (declare
                             V : constant Natural := Skip_WS (Line, C + 1);
                           begin
                             (if V = 0 or else V >= Last_Obj then No_Span
                              else
                                (declare
                                   VE : constant Natural := Value_End (Line, V);
                                 begin
                                   (if VE = 0 or else VE >= Last_Obj then No_Span
                                    else
                                      (declare
                                         Hit    : constant Boolean := Key_Equals (Line, S, KE, Key);
                                         N      : constant Natural := Skip_WS (Line, VE + 1);
                                         Acc2   : constant Span_Type :=
                                           (if Hit then (found => True, kind => Kind_Of (Line (V)), first => V, last => VE) else Acc);
                                         Count2 : constant Natural := (if Hit and then Count < 2 then Count + 1 else Count);
                                       begin
                                         (if N = 0 then No_Span
                                          elsif N = Last_Obj then (if Count2 = 1 then Acc2 else No_Span)
                                          elsif N < Last_Obj and then Line (N) = ',' then Mem_From (Line, Last_Obj, N + 1, Key, Acc2, Count2)
                                          else No_Span))))))))))))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Last_Obj in Line'Range
                   and then P <= Last_Obj and then Count <= 2
                   and then Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64),
          Subprogram_Variant => (Decreases => Last_Obj - P);

   --  Member_Span: the value of the member named Key of the object at Obj; not found if no
   --  member or more than one member has that name, or the object is malformed.
   function Member_Span (Line : String; Obj : Span_Type; Key : String) return Span_Type
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64
                   and then Obj.first in Line'Range and then Obj.last in Line'Range
                   and then Obj.first < Obj.last
                   and then Line (Obj.first) = '{' and then Line (Obj.last) = '}'),
          Post => ((Member_Span'Result =
                      (if Skip_WS (Line, Obj.first + 1) = Obj.last then No_Span
                       else Mem_From (Line, Obj.last, Obj.first + 1, Key, No_Span, 0)))
                   and then (if not Member_Span'Result.found then Member_Span'Result = No_Span)
                   and then (if Member_Span'Result.found then
                               Member_Span'Result.first in Obj.first + 1 .. Obj.last - 1
                               and then Member_Span'Result.last in Member_Span'Result.first .. Obj.last - 1
                               and then Member_Span'Result.kind = Kind_Of (Line (Member_Span'Result.first))
                               and then not Is_WS (Line (Member_Span'Result.first))
                               and then (if Member_Span'Result.kind = K_String then
                                           Line (Member_Span'Result.last) = '"'
                                           and then Member_Span'Result.first < Member_Span'Result.last)));

   --  LINEAGE 6 (2026-09-28, the A11 refusal messages): Member_Span answers "not found" both
   --  when a key is absent and when it is present twice, so a caller could not say which.
   --  Dup_From / Member_Duplicated answer the second question on its own: the object is
   --  well-formed to its closing brace AND at least two of its members are named Key.
   --  Dup_From: the same walk as Mem_From, counting members named Key (capped at 2), with no
   --  value kept: True exactly when the walk reaches the object's end with Count at 2.
   function Dup_From (Line : String; Last_Obj : Positive; P : Positive; Key : String; Count : Natural) return Boolean
     is (declare
           S : constant Natural := Skip_WS (Line, P);
         begin
           (if S = 0 or else S >= Last_Obj or else Line (S) /= '"' then False
            else
              (declare
                 KE : constant Natural := Str_End (Line, S);
               begin
                 (if KE = 0 or else KE >= Last_Obj then False
                  else
                    (declare
                       C : constant Natural := Skip_WS (Line, KE + 1);
                     begin
                       (if C = 0 or else C >= Last_Obj or else Line (C) /= ':' then False
                        else
                          (declare
                             V : constant Natural := Skip_WS (Line, C + 1);
                           begin
                             (if V = 0 or else V >= Last_Obj then False
                              else
                                (declare
                                   VE : constant Natural := Value_End (Line, V);
                                 begin
                                   (if VE = 0 or else VE >= Last_Obj then False
                                    else
                                      (declare
                                         Hit    : constant Boolean := Key_Equals (Line, S, KE, Key);
                                         N      : constant Natural := Skip_WS (Line, VE + 1);
                                         Count2 : constant Natural := (if Hit and then Count < 2 then Count + 1 else Count);
                                       begin
                                         (if N = 0 then False
                                          elsif N = Last_Obj then Count2 = 2
                                          elsif N < Last_Obj and then Line (N) = ',' then Dup_From (Line, Last_Obj, N + 1, Key, Count2)
                                          else False))))))))))))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Last_Obj in Line'Range
                   and then P <= Last_Obj and then Count <= 2
                   and then Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64),
          Subprogram_Variant => (Decreases => Last_Obj - P);

   --  Member_Duplicated: the object at Obj is well-formed and two or more of its members are
   --  named Key (compared after JSON unescaping, as Member_Span compares).
   function Member_Duplicated (Line : String; Obj : Span_Type; Key : String) return Boolean
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64
                   and then Obj.first in Line'Range and then Obj.last in Line'Range
                   and then Obj.first < Obj.last
                   and then Line (Obj.first) = '{' and then Line (Obj.last) = '}'),
          Post => (Member_Duplicated'Result =
                     (if Skip_WS (Line, Obj.first + 1) = Obj.last then False
                      else Dup_From (Line, Obj.last, Obj.first + 1, Key, 0)));

   --  El_From: walking the elements of the array that closes at Last_Arr, from P, the I-th
   --  element being next: the Index-th element.
   function El_From (Line : String; Last_Arr : Positive; P : Positive; Index : Positive; I : Positive) return Span_Type
     is (declare
           S : constant Natural := Skip_WS (Line, P);
         begin
           (if S = 0 or else S >= Last_Arr then No_Span
            else
              (declare
                 VE : constant Natural := Value_End (Line, S);
               begin
                 (if VE = 0 or else VE >= Last_Arr then No_Span
                  else
                    (declare
                       N : constant Natural := Skip_WS (Line, VE + 1);
                     begin
                       (if N = 0 or else (N /= Last_Arr and then (N > Last_Arr or else Line (N) /= ',')) then No_Span
                        elsif I = Index then (found => True, kind => Kind_Of (Line (S)), first => S, last => VE)
                        elsif N = Last_Arr then No_Span
                        else El_From (Line, Last_Arr, N + 1, Index, I + 1)))))))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Last_Arr in Line'Range
                   and then P <= Last_Arr and then I <= Index),
          Subprogram_Variant => (Decreases => Last_Arr - P);

   --  Element_Span: the Index-th element (from 1) of the array at Arr; not found if there is
   --  no such element or the array is malformed up to it.
   function Element_Span (Line : String; Arr : Span_Type; Index : Positive) return Span_Type
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line
                   and then Arr.first in Line'Range and then Arr.last in Line'Range
                   and then Arr.first < Arr.last
                   and then Line (Arr.first) = '[' and then Line (Arr.last) = ']'),
          Post => ((Element_Span'Result =
                      (if Skip_WS (Line, Arr.first + 1) = Arr.last then No_Span
                       else El_From (Line, Arr.last, Arr.first + 1, Index, 1)))
                   and then (if not Element_Span'Result.found then Element_Span'Result = No_Span)
                   and then (if Element_Span'Result.found then
                               Element_Span'Result.first in Arr.first + 1 .. Arr.last - 1
                               and then Element_Span'Result.last in Element_Span'Result.first .. Arr.last - 1
                               and then Element_Span'Result.kind = Kind_Of (Line (Element_Span'Result.first))
                               and then not Is_WS (Line (Element_Span'Result.first))
                               and then (if Element_Span'Result.kind = K_String then
                                           Line (Element_Span'Result.last) = '"'
                                           and then Element_Span'Result.first < Element_Span'Result.last)));

   --  Is_Object / Is_Array: S is a found composite span of Line that opens and closes with
   --  the given brackets. Member_Of / Element_Of are total: they answer No_Span unless S is
   --  such an object / array, so a path can be walked one step at a time without guards.
   function Is_Object (Line : String; S : Span_Type) return Boolean is
     (S.found and then S.kind = K_Composite and then S.first in Line'Range and then S.last in Line'Range
      and then S.first < S.last and then Line (S.first) = '{' and then Line (S.last) = '}');

   function Is_Array (Line : String; S : Span_Type) return Boolean is
     (S.found and then S.kind = K_Composite and then S.first in Line'Range and then S.last in Line'Range
      and then S.first < S.last and then Line (S.first) = '[' and then Line (S.last) = ']');

   function Member_Of (Line : String; Obj : Span_Type; Key : String) return Span_Type is
     ((if Is_Object (Line, Obj) then Member_Span (Line, Obj, Key) else No_Span))
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64),
          Post => ((if not Member_Of'Result.found then Member_Of'Result = No_Span)
                   and then (if Member_Of'Result.found then
                               Member_Of'Result.first in Line'Range
                               and then Member_Of'Result.last in Member_Of'Result.first .. Line'Last
                               and then Member_Of'Result.kind = Kind_Of (Line (Member_Of'Result.first))
                               and then (if Member_Of'Result.kind = K_String then
                                           Line (Member_Of'Result.last) = '"'
                                           and then Member_Of'Result.first < Member_Of'Result.last)));

   function Element_Of (Line : String; Arr : Span_Type; Index : Positive) return Span_Type is
     ((if Is_Array (Line, Arr) then Element_Span (Line, Arr, Index) else No_Span))
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line),
          Post => ((if not Element_Of'Result.found then Element_Of'Result = No_Span)
                   and then (if Element_Of'Result.found then
                               Element_Of'Result.first in Line'Range
                               and then Element_Of'Result.last in Element_Of'Result.first .. Line'Last
                               and then Element_Of'Result.kind = Kind_Of (Line (Element_Of'Result.first))
                               and then (if Element_Of'Result.kind = K_String then
                                           Line (Element_Of'Result.last) = '"'
                                           and then Element_Of'Result.first < Element_Of'Result.last)));

   --  Duplicated_Of: total form of Member_Duplicated (False unless S is an object).
   function Duplicated_Of (Line : String; Obj : Span_Type; Key : String) return Boolean is
     (Is_Object (Line, Obj) and then Member_Duplicated (Line, Obj, Key))
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64);

   --  Value_Span: the value of the member named Key of the line's TOP-LEVEL object. The line
   --  must be one JSON object (whitespace around it allowed); otherwise nothing is found.
   function Value_Span (Line : String; Key : String) return Span_Type
     is (if Line'Length = 0 then No_Span else (declare
           F : constant Natural := Skip_WS (Line, 1);
         begin
           (if F = 0 or else Line (F) /= '{' then No_Span
            else
              (declare
                 E : constant Natural := Comp_End (Line, F);
               begin
                 (if E = 0 or else Line (E) /= '}' then No_Span
                  elsif E < Line'Last and then Skip_WS (Line, E + 1) /= 0 then No_Span
                  else Member_Span (Line, (found => True, kind => K_Composite, first => F, last => E), Key))))))
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64),
          Post => ((if not Value_Span'Result.found then Value_Span'Result.first = 0 and then Value_Span'Result.last = 0 and then Value_Span'Result.kind = K_None)
                   and then (if Value_Span'Result.found then Value_Span'Result.first in Line'Range and then Value_Span'Result.last in Line'Range and then Value_Span'Result.first <= Value_Span'Result.last and then Value_Span'Result.kind /= K_None)
                   and then (if Value_Span'Result.found then Line (Value_Span'Result.first) /= ' ')
                   and then (if Value_Span'Result.found and then Value_Span'Result.kind = K_String then Line (Value_Span'Result.first) = '"' and then Line (Value_Span'Result.last) = '"' and then Value_Span'Result.first < Value_Span'Result.last)
                   and then (if Value_Span'Result.found and then Value_Span'Result.kind = K_Composite then (Line (Value_Span'Result.first) = '{' or else Line (Value_Span'Result.first) = '['))
                   and then (if Value_Span'Result.found and then Value_Span'Result.kind = K_Bare then Line (Value_Span'Result.first) /= '"' and then Line (Value_Span'Result.first) /= '{' and then Line (Value_Span'Result.first) /= '['));

   function String_Contents (Line : String; S : Span_Type) return Span_Type
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then S.found
                   and then S.kind = K_String and then S.first in Line'Range
                   and then S.last in Line'Range and then S.first < S.last),
          Post => ((String_Contents'Result.found and then String_Contents'Result.kind = K_String)
                   and then (String_Contents'Result.first = S.first + 1)
                   and then (String_Contents'Result.last = S.last - 1));

   function Equals_Literal (Line : String; S : Span_Type; Literal : String) return Boolean
     with Pre  => (Line'First = 1 and then Line'Length <= Tower_Bounds_Pkg.Max_Bundle_Line and then S.found
                   and then S.first in Line'Range and then S.last in Line'Range
                   and then S.first - 1 <= S.last and then Literal'First = 1
                   and then Literal'Length <= 64),
          Post => ((Equals_Literal'Result = True) = ((Literal'Length = S.last - S.first + 1) and then (Line (S.first .. S.last) = Literal)));

   --  BODY: lineage 5. Skip_WS, Str_End, Comp_End and Bare_End are each ONE loop that
   --  BODY: carries the equality of its model at the loop's start with the model at K + 1 in
   --  BODY: the loop's current state (Comp_End also carries D <= Max_Depth and
   --  BODY: (if not In_Str then not Esc)). Key_Equals, Member_Span and Element_Span are WHILE
   --  BODY: loops (or plain loops with a Loop_Variant) that carry the equality of Key_From,
   --  BODY: Mem_From or El_From at the start with the same function in the current state.
   --  BODY: Key_Position, String_Contents and Equals_Literal are lineage 4's bodies unchanged.
   --  BODY: lineage 6. Member_Duplicated is Member_Span's loop with no value kept: it carries
   --  BODY: the equality of Dup_From at the start with Dup_From in the current state.

end Tower_Scan_Pkg;
