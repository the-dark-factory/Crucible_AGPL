--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Json_Scan_Pkg, THIRD forge (2026-09-12): the accepted round-D specification re-emitted
--  unchanged in its contracts (BRIEF_json_scan_semantic_obligation_2026-09-11: found means
--  found), forged again ONLY for the body stage -- the 2026-09-11 body gave five locals
--  initial values that were never read, and the -gnatwa -gnatwe gate that crucible-proves-clean
--  demands refused the unit for it. Spec: ANVIL lane, wu-crucible-json-scan-3 round A, 12:05,
--  planner Rosie qwen3.8-27b-ada:v0.3, proof_gate accepted (38 checks, 0 unproved, 0 compile
--  errors, 0 cheat markers). Body: the lane's body-fill (opus, candidate 3), job verified 12:05.
--  Re-proved as built on bill: level 2, -gnatwa -gnatwe, 183 checks, 0 unproved, 0 WARNINGS.
--  Supersedes the round-D carry of 2026-09-11; that lineage (wu-crucible-json-scan-2) is the
--  record. Comment-stripped sha of this spec equals the forged round-A spec.
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
     with Pre  => (Line'First = 1 and then Line'Length <= 65536 and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64
                   and then I <= Line'Last),
          Post => ((if Is_Key_At'Result then I in Line'Range)
                   and then (if Is_Key_At'Result then Line (I) = '"'));

   function Has_Key (Line : String; Key : String) return Boolean
     is (for some I in Line'Range => Is_Key_At (Line, Key, I))
     with Pre  => (Line'First = 1 and then Line'Length <= 65536 and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64),
          Post => ((Has_Key'Result = True) = (for some I in Line'Range => Is_Key_At (Line, Key, I)));

   function No_Key_Before (Line : String; Key : String; N : Positive) return Boolean
     is (for all J in Line'First .. N - 1 => not Is_Key_At (Line, Key, J))
     with Pre  => (Line'First = 1 and then Line'Length <= 65536 and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64
                   and then N - 1 <= Line'Last),
          Post => ((No_Key_Before'Result = True) = (for all J in Line'First .. N - 1 => not Is_Key_At (Line, Key, J)));

   function Key_Position (Line : String; Key : String) return Natural
     with Pre  => (Line'First = 1 and then Line'Length <= 65536 and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64),
          Post => ((Key_Position'Result = 0 or else Key_Position'Result in Line'Range)
                   and then ((Key_Position'Result /= 0) = Has_Key (Line, Key))
                   and then (if Key_Position'Result /= 0 then Is_Key_At (Line, Key, Key_Position'Result))
                   and then (if Key_Position'Result /= 0 then No_Key_Before (Line, Key, Key_Position'Result)));

   function Value_Span (Line : String; Key : String) return Span_Type
     with Pre  => (Line'First = 1 and then Line'Length <= 65536 and then Key'First = 1
                   and then Key'Length >= 1 and then Key'Length <= 64),
          Post => ((Value_Span'Result.found = Has_Key (Line, Key))
                   and then (if not Value_Span'Result.found then Value_Span'Result.first = 0 and then Value_Span'Result.last = 0 and then Value_Span'Result.kind = K_None)
                   and then (if Value_Span'Result.found then Value_Span'Result.first in Line'Range and then Value_Span'Result.last in Line'Range and then Value_Span'Result.first <= Value_Span'Result.last and then Value_Span'Result.kind /= K_None)
                   and then (if Value_Span'Result.found then Value_Span'Result.first > Key_Position (Line, Key) and then Line (Value_Span'Result.first) /= ' ')
                   and then (if Value_Span'Result.found and then Value_Span'Result.kind = K_String then Line (Value_Span'Result.first) = '"' and then Line (Value_Span'Result.last) = '"' and then Value_Span'Result.first < Value_Span'Result.last)
                   and then (if Value_Span'Result.found and then Value_Span'Result.kind = K_Composite then (Line (Value_Span'Result.first) = '{' or else Line (Value_Span'Result.first) = '['))
                   and then (if Value_Span'Result.found and then Value_Span'Result.kind = K_Bare then Line (Value_Span'Result.first) /= '"' and then Line (Value_Span'Result.first) /= '{' and then Line (Value_Span'Result.first) /= '['));

   function String_Contents (Line : String; S : Span_Type) return Span_Type
     with Pre  => (Line'First = 1 and then Line'Length <= 65536 and then S.found
                   and then S.kind = K_String and then S.first in Line'Range
                   and then S.last in Line'Range and then S.first < S.last),
          Post => ((String_Contents'Result.found and then String_Contents'Result.kind = K_String)
                   and then (String_Contents'Result.first = S.first + 1)
                   and then (String_Contents'Result.last = S.last - 1));

   function Equals_Literal (Line : String; S : Span_Type; Literal : String) return Boolean
     with Pre  => (Line'First = 1 and then Line'Length <= 65536 and then S.found
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

end Json_Scan_Pkg;
