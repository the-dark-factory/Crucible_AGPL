--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Spec forged by ANVIL through the lane, ab-20260911-1954 round B (round A: last + 1 overflow, fixed in
--  prose). The lane cannot pass a declarations-only spec to body-fill (it exits on the gate word), so the
--  body was filled by body-fill-bench driven by the seat: claude-cli haiku -> opus, candidate 2, proof
--  tier level 2. Spec + body re-proved as built, level 2: 66 checks, zero unproved. ONE WARNING stands:
--  json_scan_pkg.adb:61 "initialization of K has no effect" — body-fill compiled without -gnatwa, so
--  crucible-proves-clean (warnings as errors) will refuse this tree until the body is re-filled with the
--  project switches. Recorded, not hand-patched. Theorem is bounds-safety only. Carried unchanged.
--
package Json_Scan_Pkg with SPARK_Mode is

   type Kind_Type is (K_None, K_String, K_Bare, K_Composite);

   type Span_Type is record
      found : Boolean := False;
      kind  : Kind_Type := K_None;
      first : Natural := 0;
      last  : Natural := 0;
   end record;

   function Key_Position (Line : String; Key : String) return Natural
     with Pre  => Key'Length >= 1 and then Line'Length <= 65536,
          Post => (Key_Position'Result = 0 or else Key_Position'Result in Line'Range) and then
                  ((if Key_Position'Result /= 0 then Line (Key_Position'Result) = '''));

   function Value_Span (Line : String; Key : String) return Span_Type
     with Pre  => Key'Length >= 1 and then Line'Length <= 65536,
          Post => ((if not Value_Span'Result.found then Value_Span'Result.first = 0 and then Value_Span'Result.last = 0 and then Value_Span'Result.kind = K_None)) and then
                  ((if Value_Span'Result.found then Value_Span'Result.first in Line'Range and then Value_Span'Result.last in Line'Range and then Value_Span'Result.first <= Value_Span'Result.last and then Value_Span'Result.kind /= K_None)) and then
                  ((if Key_Position (Line, Key) = 0 then not Value_Span'Result.found));

   function String_Contents (Line : String; S : Span_Type) return Span_Type
     with Pre  => S.found and then S.kind = K_String and then S.first in Line'Range and then S.last in Line'Range and then S.first <= S.last,
          Post => String_Contents'Result.found and then String_Contents'Result.kind = K_String and then
                  (String_Contents'Result.first >= S.first and then String_Contents'Result.last <= S.last and then String_Contents'Result.first - 1 <= String_Contents'Result.last);

   function Equals_Literal (Line : String; S : Span_Type; Literal : String) return Boolean
     with Pre  => S.found and then S.first in Line'Range and then S.last in Line'Range and then S.first - 1 <= S.last and then Literal'Length <= 64,
          Post => ((Equals_Literal'Result = True) = (S.last - S.first + 1 = Literal'Length and then Line (S.first .. S.last) = Literal));

end Json_Scan_Pkg;
