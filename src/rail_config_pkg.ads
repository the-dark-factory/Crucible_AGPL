--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: d57d4e03a44f89d02153e395051fba3c4c67b5b86d0be30c370cff0a2eba07e3
--
with Json_Scan_Pkg;

package Rail_Config_Pkg with SPARK_Mode is

   use type Json_Scan_Pkg.Kind_Type;

   Rail_Key      : constant String := "rail";
   Host_Key      : constant String := "host";
   Port_Key      : constant String := "port";
   Timeout_Key   : constant String := "timeout_seconds";
   Max_Reply_Key : constant String := "max_reply_bytes";
   Sovereign_Key : constant String := "sovereign";
   Prover_Word   : constant String := "prover";
   Model_Word    : constant String := "model";
   Vacuity_Word  : constant String := "vacuity";
   Palais_Word   : constant String := "palais";
   Reef_Word     : constant String := "reef";
   True_Word     : constant String := "true";
   False_Word    : constant String := "false";
   Max_Line      : constant := 1_048_576;

   type Rail_Kind is (Rail_Prover, Rail_Model, Rail_Vacuity, Rail_Palais, Rail_Reef, Rail_Unknown);

   No_Span : constant Json_Scan_Pkg.Span_Type := (found => False, kind => Json_Scan_Pkg.K_None, first => 0, last => 0);

   function Is_Digit (C : Character) return Boolean
     is (C in '0' .. '9')
     with Post => ((if Is_Digit'Result then C /= ' '));

   function Digit_Value (C : Character) return Natural
     is (Character'Pos (C) - Character'Pos ('0'))
     with Pre  => Is_Digit (C),
          Post => Digit_Value'Result <= 9;

   function Max_For (N : Positive) return Natural
     is (if N = 1 then 9 elsif N = 2 then 99 elsif N = 3 then 999 elsif N = 4 then 9_999 elsif N = 5 then 99_999 elsif N = 6 then 999_999 else 9_999_999)
     with Pre  => N <= 7,
          Post => Max_For'Result <= 9_999_999;

   function Number_Value (Line : String; First, Last : Positive) return Natural
     is (if Last = First then Digit_Value (Line (First)) else 10 * Number_Value (Line, First, Last - 1) + Digit_Value (Line (Last)))
     with Pre  => (First in Line'Range and then Last in Line'Range and then First <= Last and then Last - First <= 6 and then (for all K in First .. Last => Is_Digit (Line (K)))),
          Post => Number_Value'Result <= Max_For (Last - First + 1),
          Subprogram_Variant => (Decreases => Last);

   function Contents (Line : String; Key : String) return Json_Scan_Pkg.Span_Type
     is ((if Json_Scan_Pkg.Value_Span (Line, Key).found and then Json_Scan_Pkg.Value_Span (Line, Key).kind = Json_Scan_Pkg.K_String and then Json_Scan_Pkg.Value_Span (Line, Key).first < Json_Scan_Pkg.Value_Span (Line, Key).last then Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Key)) else No_Span))
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then Key'First = 1 and then Key'Length in 1 .. 64),
          Post => ((if Contents'Result.found then Contents'Result.first in Line'Range and then Contents'Result.last in Line'Range and then Contents'Result.first - 1 <= Contents'Result.last));

   function Is_Number (Line : String; S : Json_Scan_Pkg.Span_Type; Low, High : Natural) return Boolean
     is (S.found and then S.first <= S.last and then S.last - S.first <= 6 and then (for all K in S.first .. S.last => Is_Digit (Line (K))) and then Number_Value (Line, S.first, S.last) in Low .. High)
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then (if S.found then S.first in Line'Range and then S.last in Line'Range)),
          Post => ((if Is_Number'Result then S.found and then S.first <= S.last));

   function Dot_After (Line : String; From : Positive; Last : Natural) return Natural
     with Global => null,
          Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then From >= 1 and then Last <= Line'Last and then From <= Last + 1),
          Post => ((if Dot_After'Result = 0 then (for all K in From .. Last => Line (K) /= '.'))
                   and then (if Dot_After'Result /= 0 then Dot_After'Result in From .. Last and then Line (Dot_After'Result) = '.' and then (for all K in From .. Dot_After'Result - 1 => Line (K) /= '.')));

   function Is_Octet (Line : String; First : Positive; Last : Natural) return Boolean
     is (First <= Last and then Last - First <= 2 and then (for all K in First .. Last => Is_Digit (Line (K))) and then Number_Value (Line, First, Last) <= 255)
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then First in Line'Range and then Last <= Line'Last),
          Post => ((if Is_Octet'Result then Last - First <= 2));

   function Dot1 (Line : String; S : Json_Scan_Pkg.Span_Type) return Natural
     is (Dot_After (Line, S.first, S.last))
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then S.found and then S.first in Line'Range and then S.last in Line'Range and then S.first <= S.last),
          Post => ((if Dot1'Result > 0 then Dot1'Result in S.first .. S.last));

   function Dot2 (Line : String; S : Json_Scan_Pkg.Span_Type) return Natural
     is (Dot_After (Line, Dot1 (Line, S) + 1, S.last))
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then S.found and then S.first in Line'Range and then S.last in Line'Range and then S.first <= S.last and then Dot1 (Line, S) > 0),
          Post => ((if Dot2'Result > 0 then Dot2'Result in Dot1 (Line, S) + 1 .. S.last));

   function Dot3 (Line : String; S : Json_Scan_Pkg.Span_Type) return Natural
     is (Dot_After (Line, Dot2 (Line, S) + 1, S.last))
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then S.found and then S.first in Line'Range and then S.last in Line'Range and then S.first <= S.last and then Dot1 (Line, S) > 0 and then Dot2 (Line, S) > 0),
          Post => ((if Dot3'Result > 0 then Dot3'Result in Dot2 (Line, S) + 1 .. S.last));

   function Is_IPv4 (Line : String; S : Json_Scan_Pkg.Span_Type) return Boolean
     is (S.found and then S.first <= S.last and then S.last - S.first + 1 in 7 .. 15 and then Dot1 (Line, S) > 0 and then Dot2 (Line, S) > 0 and then Dot3 (Line, S) > 0 and then Dot3 (Line, S) < S.last and then Dot_After (Line, Dot3 (Line, S) + 1, S.last) = 0 and then Is_Octet (Line, S.first, Dot1 (Line, S) - 1) and then Is_Octet (Line, Dot1 (Line, S) + 1, Dot2 (Line, S) - 1) and then Is_Octet (Line, Dot2 (Line, S) + 1, Dot3 (Line, S) - 1) and then Is_Octet (Line, Dot3 (Line, S) + 1, S.last))
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then (if S.found then S.first in Line'Range and then S.last in Line'Range)),
          Post => ((if Is_IPv4'Result then S.last - S.first + 1 <= 15));

   function Rail_Of (Line : String) return Rail_Kind
     is ((if not Contents (Line, Rail_Key).found then Rail_Unknown elsif Json_Scan_Pkg.Equals_Literal (Line, Contents (Line, Rail_Key), Prover_Word) then Rail_Prover elsif Json_Scan_Pkg.Equals_Literal (Line, Contents (Line, Rail_Key), Model_Word) then Rail_Model elsif Json_Scan_Pkg.Equals_Literal (Line, Contents (Line, Rail_Key), Vacuity_Word) then Rail_Vacuity elsif Json_Scan_Pkg.Equals_Literal (Line, Contents (Line, Rail_Key), Palais_Word) then Rail_Palais elsif Json_Scan_Pkg.Equals_Literal (Line, Contents (Line, Rail_Key), Reef_Word) then Rail_Reef else Rail_Unknown))
     with Pre  => Line'First = 1 and then Line'Length <= Max_Line,
          Post => ((if not Contents (Line, Rail_Key).found then Rail_Of'Result = Rail_Unknown));

   function Host_Ok (Line : String) return Boolean
     is (Is_IPv4 (Line, Contents (Line, Host_Key)))
     with Pre  => Line'First = 1 and then Line'Length <= Max_Line,
          Post => ((if Host_Ok'Result then Contents (Line, Host_Key).found));

   function Port_Ok (Line : String) return Boolean
     is (Is_Number (Line, Contents (Line, Port_Key), 1, 65_535))
     with Pre  => Line'First = 1 and then Line'Length <= Max_Line,
          Post => ((if Port_Ok'Result then Contents (Line, Port_Key).found));

   function Timeout_Ok (Line : String) return Boolean
     is (Is_Number (Line, Contents (Line, Timeout_Key), 1, 3_600))
     with Pre  => Line'First = 1 and then Line'Length <= Max_Line,
          Post => ((if Timeout_Ok'Result then Contents (Line, Timeout_Key).found));

   function Max_Reply_Ok (Line : String) return Boolean
     is (Is_Number (Line, Contents (Line, Max_Reply_Key), 1, 1_048_576))
     with Pre  => Line'First = 1 and then Line'Length <= Max_Line,
          Post => ((if Max_Reply_Ok'Result then Contents (Line, Max_Reply_Key).found));

   function Sovereign_Ok (Line : String) return Boolean
     is (Contents (Line, Sovereign_Key).found and then (Json_Scan_Pkg.Equals_Literal (Line, Contents (Line, Sovereign_Key), True_Word) or else Json_Scan_Pkg.Equals_Literal (Line, Contents (Line, Sovereign_Key), False_Word)))
     with Pre  => Line'First = 1 and then Line'Length <= Max_Line,
          Post => ((if Sovereign_Ok'Result then Contents (Line, Sovereign_Key).found));

   function Is_Valid (Line : String) return Boolean
     is (Rail_Of (Line) /= Rail_Unknown and then Host_Ok (Line) and then Port_Ok (Line) and then Timeout_Ok (Line) and then Max_Reply_Ok (Line) and then Sovereign_Ok (Line))
     with Pre  => Line'First = 1 and then Line'Length <= Max_Line,
          Post => ((if Is_Valid'Result then Rail_Of (Line) /= Rail_Unknown));

   function Port_Of (Line : String) return Positive
     is (Number_Value (Line, Contents (Line, Port_Key).first, Contents (Line, Port_Key).last))
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then Is_Valid (Line)),
          Post => Port_Of'Result in 1 .. 65_535;

   function Timeout_Of (Line : String) return Positive
     is (Number_Value (Line, Contents (Line, Timeout_Key).first, Contents (Line, Timeout_Key).last))
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then Is_Valid (Line)),
          Post => Timeout_Of'Result in 1 .. 3_600;

   function Max_Reply_Of (Line : String) return Positive
     is (Number_Value (Line, Contents (Line, Max_Reply_Key).first, Contents (Line, Max_Reply_Key).last))
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then Is_Valid (Line)),
          Post => Max_Reply_Of'Result in 1 .. 1_048_576;

   function Sovereign_Of (Line : String) return Boolean
     is (Json_Scan_Pkg.Equals_Literal (Line, Contents (Line, Sovereign_Key), True_Word))
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then Is_Valid (Line)),
          Post => ((if Sovereign_Of'Result then Contents (Line, Sovereign_Key).found));

   function Host_Span (Line : String) return Json_Scan_Pkg.Span_Type
     is (Contents (Line, Host_Key))
     with Pre  => (Line'First = 1 and then Line'Length <= Max_Line and then Is_Valid (Line)),
          Post => Host_Span'Result.last - Host_Span'Result.first + 1 in 7 .. 15;

end Rail_Config_Pkg;
