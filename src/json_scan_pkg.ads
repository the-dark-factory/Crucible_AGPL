--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 386ec4f253466a49099268a8426340b86b4dc7bebaf19c94a8a379e7cd4da79f
--
package Json_Scan_Pkg with SPARK_Mode is

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
     with Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64
                   and then I <= Line'Last),
          Post => ((if Is_Key_At'Result then I in Line'Range)
                   and then (if Is_Key_At'Result then Line (I) = '"'));

   function Has_Key (Line : String; Key : String) return Boolean
     is (for some I in Line'Range => Is_Key_At (Line, Key, I))
     with Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64),
          Post => ((Has_Key'Result = True) = (for some I in Line'Range => Is_Key_At (Line, Key, I)));

   function No_Key_Before (Line : String; Key : String; N : Positive) return Boolean
     is (for all J in Line'First .. N - 1 => not Is_Key_At (Line, Key, J))
     with Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64
                   and then N - 1 <= Line'Last),
          Post => ((No_Key_Before'Result = True) = (for all J in Line'First .. N - 1 => not Is_Key_At (Line, Key, J)));

   function Key_Position (Line : String; Key : String) return Natural
     with Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64),
          Post => ((Key_Position'Result = 0 or else Key_Position'Result in Line'Range)
                   and then ((Key_Position'Result /= 0) = Has_Key (Line, Key))
                   and then (if Key_Position'Result /= 0 then Is_Key_At (Line, Key, Key_Position'Result))
                   and then (if Key_Position'Result /= 0 then No_Key_Before (Line, Key, Key_Position'Result)));

   --  THE MODEL OF Value_Span (ghost: proof only, never compiled into the program).
   --  Each function below is the definition of one scan, one character at a time.
   --  Value_Span's Post says its result IS Span_Model, so no body can be hollow.

   --  Colon_From: the first ':' at or after J, or 0 if there is none.
   function Colon_From (Line : String; J : Positive) return Natural
     is (if J > Line'Last then 0
         elsif Line (J) = ':' then J
         else Colon_From (Line, J + 1))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then J - 1 <= Line'Last),
          Post => (Colon_From'Result = 0 or else Colon_From'Result in J .. Line'Last),
          Subprogram_Variant => (Decreases => Line'Last - J + 1);

   --  Nonblank_From: the first character that is not ' ' at or after J, or 0.
   function Nonblank_From (Line : String; J : Positive) return Natural
     is (if J > Line'Last then 0
         elsif Line (J) /= ' ' then J
         else Nonblank_From (Line, J + 1))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then J - 1 <= Line'Last),
          Post => (Nonblank_From'Result = 0 or else Nonblank_From'Result in J .. Line'Last),
          Subprogram_Variant => (Decreases => Line'Last - J + 1);

   --  String_End: scanning from J with the escape flag Esc, the first '"' that is
   --  not escaped, or 0. A '\' escapes exactly the one character after it.
   function String_End (Line : String; J : Positive; Esc : Boolean) return Natural
     is (if J > Line'Last then 0
         elsif Esc then String_End (Line, J + 1, False)
         elsif Line (J) = '\' then String_End (Line, J + 1, True)
         elsif Line (J) = '"' then J
         else String_End (Line, J + 1, False))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then J - 1 <= Line'Last),
          Post => ((String_End'Result = 0 or else String_End'Result in J .. Line'Last)
                   and then (if String_End'Result /= 0 then Line (String_End'Result) = '"')),
          Subprogram_Variant => (Decreases => Line'Last - J + 1);

   --  Close_From: scanning from J at bracket depth D, inside a string or not, with
   --  the escape flag Esc, the closer that brings the depth to zero; Line'Last if
   --  the brackets never close. Brackets inside a string are not counted.
   function Close_From (Line : String; J : Positive; D : Natural; In_Str : Boolean; Esc : Boolean) return Natural
     is (if J > Line'Last then Line'Last
         elsif In_Str then
           (if Esc then Close_From (Line, J + 1, D, True, False)
            elsif Line (J) = '\' then Close_From (Line, J + 1, D, True, True)
            elsif Line (J) = '"' then Close_From (Line, J + 1, D, False, False)
            else Close_From (Line, J + 1, D, True, False))
         elsif Line (J) = '"' then Close_From (Line, J + 1, D, True, Esc)
         elsif Line (J) = '{' or else Line (J) = '[' then Close_From (Line, J + 1, D + 1, False, Esc)
         elsif Line (J) = '}' or else Line (J) = ']' then
           (if D <= 1 then J else Close_From (Line, J + 1, D - 1, False, Esc))
         else Close_From (Line, J + 1, D, False, Esc))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then J - 1 <= Line'Last
                   and then D <= J - 1),
          Post => (if J <= Line'Last then Close_From'Result in J .. Line'Last
                   else Close_From'Result = Line'Last),
          Subprogram_Variant => (Decreases => Line'Last - J + 1);

   --  Bare_End: scanning from J, L the last non-blank seen so far, the last
   --  non-blank before the first ',', '}' or ']' (or before the end of the line).
   function Bare_End (Line : String; J : Positive; L : Positive) return Natural
     is (if J > Line'Last then L
         elsif Line (J) = ',' or else Line (J) = '}' or else Line (J) = ']' then L
         elsif Line (J) /= ' ' then Bare_End (Line, J + 1, J)
         else Bare_End (Line, J + 1, L))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then J - 1 <= Line'Last
                   and then L in Line'Range and then L < J),
          Post => (Bare_End'Result in L .. Line'Last),
          Subprogram_Variant => (Decreases => Line'Last - J + 1);

   --  Model_From_Value: the span, given the colon C (0: none) and the first
   --  non-blank F after it (0: none).
   function Model_From_Value (Line : String; C : Natural; F : Natural) return Span_Type
     is (if C = 0 then (found => False, kind => K_None, first => 0, last => 0)
         elsif F = 0 then (found => True, kind => K_Bare, first => C, last => C)
         elsif Line (F) = '"' then
           (if String_End (Line, F + 1, False) = 0
            then (found => True, kind => K_Bare, first => C, last => C)
            else (found => True, kind => K_String, first => F, last => String_End (Line, F + 1, False)))
         elsif Line (F) = '{' or else Line (F) = '[' then
           (found => True, kind => K_Composite, first => F, last => Close_From (Line, F, 0, False, False))
         else (found => True, kind => K_Bare, first => F, last => Bare_End (Line, F + 1, F)))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= 1048576
                   and then (C = 0 or else C in Line'Range)
                   and then (F = 0 or else F in Line'Range));

   --  Span_Model: the whole of Value_Span, as a definition.
   function Span_Model (Line : String; Key : String) return Span_Type
     is (if Key_Position (Line, Key) = 0
         then (found => False, kind => K_None, first => 0, last => 0)
         else Model_From_Value
                (Line,
                 Colon_From (Line, Key_Position (Line, Key) + Key'Length + 2),
                 Nonblank_From (Line, Colon_From (Line, Key_Position (Line, Key) + Key'Length + 2) + 1)))
     with Ghost,
          Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64);

   function Value_Span (Line : String; Key : String) return Span_Type
     with Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64),
          Post => ((Value_Span'Result.found = Has_Key (Line, Key))
                   and then (if not Value_Span'Result.found then Value_Span'Result.first = 0 and then Value_Span'Result.last = 0 and then Value_Span'Result.kind = K_None)
                   and then (if Value_Span'Result.found then Value_Span'Result.first in Line'Range and then Value_Span'Result.last in Line'Range and then Value_Span'Result.first <= Value_Span'Result.last and then Value_Span'Result.kind /= K_None)
                   and then (if Value_Span'Result.found then Value_Span'Result.first > Key_Position (Line, Key) and then Line (Value_Span'Result.first) /= ' ')
                   and then (if Value_Span'Result.found and then Value_Span'Result.kind = K_String then Line (Value_Span'Result.first) = '"' and then Line (Value_Span'Result.last) = '"' and then Value_Span'Result.first < Value_Span'Result.last)
                   and then (if Value_Span'Result.found and then Value_Span'Result.kind = K_Composite then (Line (Value_Span'Result.first) = '{' or else Line (Value_Span'Result.first) = '['))
                   and then (if Value_Span'Result.found and then Value_Span'Result.kind = K_Bare then Line (Value_Span'Result.first) /= '"' and then Line (Value_Span'Result.first) /= '{' and then Line (Value_Span'Result.first) /= '[')
                   and then (Value_Span'Result = Span_Model (Line, Key)));

   function String_Contents (Line : String; S : Span_Type) return Span_Type
     with Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then S.found
                   and then S.kind = K_String and then S.first in Line'Range
                   and then S.last in Line'Range and then S.first < S.last),
          Post => ((String_Contents'Result.found and then String_Contents'Result.kind = K_String)
                   and then (String_Contents'Result.first = S.first + 1)
                   and then (String_Contents'Result.last = S.last - 1));

   function Equals_Literal (Line : String; S : Span_Type; Literal : String) return Boolean
     with Pre  => (Line'First = 1 and then Line'Length <= 1048576 and then S.found
                   and then S.first in Line'Range and then S.last in Line'Range
                   and then S.first - 1 <= S.last and then Literal'First = 1
                   and then Literal'Length <= 64),
          Post => ((Equals_Literal'Result = True) = ((Literal'Length = S.last - S.first + 1) and then (Line (S.first .. S.last) = Literal)));

   --  BODY: the scanning loops are FOR loops over Line'Range (never while loops, so
   --  BODY: termination is by construction); the loop that finds the first key
   --  BODY: occurrence carries pragma Loop_Invariant (No_Key_Before (Line, Key, I));
   --  BODY: and every expression function in the body is enclosed in parentheses.
   --  BODY: a local variable that is assigned before it is first read is
   --  BODY: declared WITHOUT an initial value; only a local that is read before any
   --  BODY: assignment carries an initializer. (The body filled on 2026-09-11 gave
   --  BODY: Q, L, Depth, Esc and In_Str initial values that were never read, and
   --  BODY: the compiler's warnings-as-errors gate refuses the unit for it.)
   --  BODY: each scanning loop in Value_Span carries, as a Loop_Invariant, the
   --  BODY: equality of its model function at the loop's start with the same
   --  BODY: function at J + 1 and the loop's current state, e.g.
   --  BODY: String_End (Line, F + 1, False) = String_End (Line, J + 1, Esc).

end Json_Scan_Pkg;
