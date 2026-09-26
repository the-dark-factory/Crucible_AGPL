--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 93675d5fb4ba989c47812276525dbd8bc991c65a03d2196bd6cf1aa02bd6b6ea
--
package Report_Mode_Pkg with SPARK_Mode is
   --  PURPOSE: whether Crucible's report-everything mode is on, decided from
   --  the one line of config/report.conf and never from the environment. The
   --  line must be EXACTLY one of four fixed forms; anything else is off and
   --  named, so a malformed or ambiguous file can never turn report mode on.
   --  USAGE: the edge reads config/report.conf, calls Line_Fact on its one
   --  line, then Decide with whether it exists and its count of non-blank lines.

   On_Form    : constant String (1 .. 15) := "{""report"":""on""}";
   On_Spaced  : constant String (1 .. 16) := "{""report"": ""on""}";
   Off_Form   : constant String (1 .. 16) := "{""report"":""off""}";
   Off_Spaced : constant String (1 .. 17) := "{""report"": ""off""}";

   type Mode_Kind is (Mode_Off, Mode_On);

   type Fact_Kind is
     (Fact_Absent, Fact_On, Fact_Off, Fact_Not_Exact, Fact_Not_One_Line);

   function Is_Malformed (F : Fact_Kind) return Boolean
   is (F in Fact_Not_Exact .. Fact_Not_One_Line)
   with Global => null,
        Post => Is_Malformed'Result = (F in Fact_Not_Exact .. Fact_Not_One_Line);

   function Mode_Of (F : Fact_Kind) return Mode_Kind
   is ((if F = Fact_On then Mode_On else Mode_Off))
   with Global => null,
        Post => Mode_Of'Result = (if F = Fact_On then Mode_On else Mode_Off)
                and then ((Mode_Of'Result = Mode_On) = (F = Fact_On))
                and then (if Is_Malformed (F) then Mode_Of'Result = Mode_Off);

   function Word_Of (F : Fact_Kind) return String
   is ((case F is
          when Fact_Absent => "absent",
          when Fact_On => "on",
          when Fact_Off => "off",
          when Fact_Not_Exact => "not_exact",
          when Fact_Not_One_Line => "not_one_line"))
   with Global => null,
        Post => Word_Of'Result = (case F is
                                   when Fact_Absent => "absent",
                                   when Fact_On => "on",
                                   when Fact_Off => "off",
                                   when Fact_Not_Exact => "not_exact",
                                   when Fact_Not_One_Line => "not_one_line")
                and then (Word_Of'Result'Length in 2 .. 12);

   function Line_Fact (Line : String) return Fact_Kind
   is ((if Line = On_Form or else Line = On_Spaced then Fact_On
        elsif Line = Off_Form or else Line = Off_Spaced then Fact_Off
        else Fact_Not_Exact))
   with Global => null,
        Post => Line_Fact'Result = (if Line = On_Form or else Line = On_Spaced then Fact_On
                                   elsif Line = Off_Form or else Line = Off_Spaced then Fact_Off
                                   else Fact_Not_Exact)
                and then ((Line_Fact'Result = Fact_On) = (Line = On_Form or else Line = On_Spaced))
                and then ((Line_Fact'Result = Fact_Off) = (Line = Off_Form or else Line = Off_Spaced))
                and then (Line_Fact'Result in Fact_On .. Fact_Not_Exact);

   function Decide (Present : Boolean; Lines : Natural; Found : Fact_Kind) return Fact_Kind
   is ((if not Present then Fact_Absent
        elsif Lines /= 1 then Fact_Not_One_Line
        else Found))
   with Global => null,
        Pre => Found in Fact_On .. Fact_Not_Exact,
        Post => Decide'Result = (if not Present then Fact_Absent
                                elsif Lines /= 1 then Fact_Not_One_Line
                                else Found)
                and then (if not Present then Decide'Result = Fact_Absent)
                and then (if Present and then Lines /= 1 then Decide'Result = Fact_Not_One_Line)
                and then ((Decide'Result = Fact_On) = (Present and then Lines = 1 and then Found = Fact_On))
                and then (if Is_Malformed (Decide'Result) then Mode_Of (Decide'Result) = Mode_Off);

end Report_Mode_Pkg;
