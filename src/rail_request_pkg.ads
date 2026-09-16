--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 99794eab803ef779fd56cf54f834aee17976696d9b75c8dd4a65ac4c090e493c
--
with Hex_Text_Pkg;

package Rail_Request_Pkg with SPARK_Mode is

   Max_Request : constant := 4_194_432;

   Prefix_Unit : constant String := "{""unit"":""";
   Sep_Level   : constant String := """,""level"":""";
   Sep_Digest  : constant String := """,""digest"":""";
   Sep_Spec    : constant String := """,""spec_hex"":""";
   Sep_Body    : constant String := """,""body_hex"":""";
   Suffix      : constant String := """}";

   function Is_Name_Char (C : Character) return Boolean is
     ((C in 'A' .. 'Z') or else (C in 'a' .. 'z') or else (C in '0' .. '9') or else C = '_');

   function First_Quote_After (Line : String; From : Positive) return Natural with
     Pre  => Line'First = 1 and then Line'Length <= Max_Request and then From <= Line'Last + 1,
     Post => (if First_Quote_After'Result = 0 then
               (for all K in From .. Line'Last => Line (K) /= '"')
             else
               (First_Quote_After'Result in From .. Line'Last
                and then Line (First_Quote_After'Result) = '"'
                and then (for all K in From .. First_Quote_After'Result - 1 => Line (K) /= '"')));

   function Unit_Last (Line : String) return Natural is
     ((if Line'Length < 10 or else First_Quote_After (Line, 10) = 0 then 0 else First_Quote_After (Line, 10) - 1)) with
       Pre  => Line'First = 1 and then Line'Length <= Max_Request;

   function Spec_Last (Line : String; U_Last : Natural) return Natural is
     ((if U_Last + 103 > Line'Last + 1 or else First_Quote_After (Line, U_Last + 103) = 0 then 0 else First_Quote_After (Line, U_Last + 103) - 1)) with
       Pre  => Line'First = 1 and then Line'Length <= Max_Request and then U_Last <= Line'Last;

   function Is_Valid (Line : String) return Boolean is
     ((Line'Length >= 9 and then Line (1 .. 9) = Prefix_Unit
       and then Unit_Last (Line) >= 10 and then Unit_Last (Line) <= 73
       and then (Line (10) in 'A' .. 'Z' or else Line (10) in 'a' .. 'z')
       and then (for all K in 10 .. Unit_Last (Line) => Is_Name_Char (Line (K)))
       and then Unit_Last (Line) + 102 <= Line'Last
       and then Line (Unit_Last (Line) + 1 .. Unit_Last (Line) + 11) = Sep_Level
       and then Line (Unit_Last (Line) + 12) in '2' | '3' | '4'
       and then Line (Unit_Last (Line) + 13 .. Unit_Last (Line) + 24) = Sep_Digest
       and then (for all K in Unit_Last (Line) + 25 .. Unit_Last (Line) + 88 => Hex_Text_Pkg.Is_Hex_Digit (Line (K)))
       and then Line (Unit_Last (Line) + 89 .. Unit_Last (Line) + 102) = Sep_Spec
       and then Spec_Last (Line, Unit_Last (Line)) >= Unit_Last (Line) + 103
       and then Spec_Last (Line, Unit_Last (Line)) + 16 <= Line'Last
       and then Hex_Text_Pkg.Is_Hex_Text (Line (Unit_Last (Line) + 103 .. Spec_Last (Line, Unit_Last (Line))))
       and then Line (Spec_Last (Line, Unit_Last (Line)) + 1 .. Spec_Last (Line, Unit_Last (Line)) + 14) = Sep_Body
       and then Hex_Text_Pkg.Is_Hex_Text (Line (Spec_Last (Line, Unit_Last (Line)) + 15 .. Line'Last - 2))
       and then Line (Line'Last - 1 .. Line'Last) = Suffix)) with
       Pre  => Line'First = 1 and then Line'Length <= Max_Request,
       Post => (if Is_Valid'Result then
                 (for all K in 10 .. Unit_Last (Line) => Line (K) /= '.' and then Line (K) /= '/' and then Line (K) /= '\'));

   function Level_Of (Line : String) return Natural is
     (Character'Pos (Line (Unit_Last (Line) + 12)) - Character'Pos ('0')) with
       Pre  => Line'First = 1 and then Line'Length <= Max_Request and then Is_Valid (Line),
       Post => Level_Of'Result in 2 | 3 | 4;

end Rail_Request_Pkg;
