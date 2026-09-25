--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 31ba567c9a31c0218881808fa6617a88e10cd015784e4392a5df7a30c36426fb
--
with Model_Rail_Fields_Pkg;

package Model_Tier_Select_Pkg with SPARK_Mode is
   --  PURPOSE. A proven FOLD over the model rail lines of one CRUCIBLE rail.conf. The caller reads the file line
   --  by line; for every line whose rail is model it adds either that line's tier (a valid model line) or an
   --  invalid mark (a model line that is not valid). At the end, Verdict says whether the file names exactly one
   --  standard line, at most one elevated line, and nothing unreadable -- and if not, which fault comes first.
   --  USAGE. T := Empty; per model line: T := Add (T, Model_Rail_Fields_Pkg.Tier_Of (Line)) or
   --  T := Add_Invalid (T); then Verdict (T). Select_Ok is the ONLY verdict on which the model may be called.

   use type Model_Rail_Fields_Pkg.Tier_Kind;

   subtype Line_Count is Natural range 0 .. 2;

   type Tier_Tally is record
      standard_lines : Line_Count;
      elevated_lines : Line_Count;
      unknown_lines  : Line_Count;
      invalid_lines  : Line_Count;
   end record;

   Empty : constant Tier_Tally := (standard_lines => 0, elevated_lines => 0, unknown_lines => 0, invalid_lines => 0);

   type Select_Verdict is (Select_Ok, Invalid_Model_Line, Unknown_Tier, Duplicate_Tier, No_Standard_Line);

   function Bump (N : Line_Count) return Line_Count
     is (if N = 2 then 2 else N + 1)
     with Post => ((if N < 2 then Bump'Result = N + 1) and then (if N = 2 then Bump'Result = 2));

   function Add (T : Tier_Tally; K : Model_Rail_Fields_Pkg.Tier_Kind) return Tier_Tally
     is (case K is
            when Model_Rail_Fields_Pkg.Tier_Standard =>
              (standard_lines => Bump (T.standard_lines), elevated_lines => T.elevated_lines,
               unknown_lines => T.unknown_lines, invalid_lines => T.invalid_lines),
            when Model_Rail_Fields_Pkg.Tier_Elevated =>
              (standard_lines => T.standard_lines, elevated_lines => Bump (T.elevated_lines),
               unknown_lines => T.unknown_lines, invalid_lines => T.invalid_lines),
            when Model_Rail_Fields_Pkg.Tier_Unknown =>
              (standard_lines => T.standard_lines, elevated_lines => T.elevated_lines,
               unknown_lines => Bump (T.unknown_lines), invalid_lines => T.invalid_lines))
     with Post => ((if K = Model_Rail_Fields_Pkg.Tier_Standard then Add'Result = (standard_lines => Bump (T.standard_lines), elevated_lines => T.elevated_lines, unknown_lines => T.unknown_lines, invalid_lines => T.invalid_lines)) and then (if K = Model_Rail_Fields_Pkg.Tier_Elevated then Add'Result = (standard_lines => T.standard_lines, elevated_lines => Bump (T.elevated_lines), unknown_lines => T.unknown_lines, invalid_lines => T.invalid_lines)) and then (if K = Model_Rail_Fields_Pkg.Tier_Unknown then Add'Result = (standard_lines => T.standard_lines, elevated_lines => T.elevated_lines, unknown_lines => Bump (T.unknown_lines), invalid_lines => T.invalid_lines)));

   function Add_Invalid (T : Tier_Tally) return Tier_Tally
     is (standard_lines => T.standard_lines, elevated_lines => T.elevated_lines,
         unknown_lines => T.unknown_lines, invalid_lines => Bump (T.invalid_lines))
     with Post => (Add_Invalid'Result = (standard_lines => T.standard_lines, elevated_lines => T.elevated_lines, unknown_lines => T.unknown_lines, invalid_lines => Bump (T.invalid_lines)));

   function Verdict (T : Tier_Tally) return Select_Verdict
     is (if T.invalid_lines > 0 then Invalid_Model_Line
         elsif T.unknown_lines > 0 then Unknown_Tier
         elsif T.standard_lines > 1 or else T.elevated_lines > 1 then Duplicate_Tier
         elsif T.standard_lines = 0 then No_Standard_Line
         else Select_Ok)
     with Post => ((if T.invalid_lines > 0 then (Verdict'Result = Invalid_Model_Line)) and then (if T.invalid_lines = 0 and then T.unknown_lines > 0 then (Verdict'Result = Unknown_Tier)) and then (if T.invalid_lines = 0 and then T.unknown_lines = 0 and then (T.standard_lines > 1 or else T.elevated_lines > 1) then (Verdict'Result = Duplicate_Tier)) and then (if T.invalid_lines = 0 and then T.unknown_lines = 0 and then T.standard_lines = 0 and then T.elevated_lines <= 1 then (Verdict'Result = No_Standard_Line)) and then (if T.invalid_lines = 0 and then T.unknown_lines = 0 and then T.standard_lines = 1 and then T.elevated_lines <= 1 then (Verdict'Result = Select_Ok)) and then (if (Verdict'Result = Select_Ok) then T.standard_lines = 1 and then T.elevated_lines <= 1 and then T.unknown_lines = 0 and then T.invalid_lines = 0));

   function Elevated_Declared (T : Tier_Tally) return Boolean
     is ((Verdict (T) = Select_Ok) and then T.elevated_lines = 1)
     with Post => ((if Elevated_Declared'Result then (Verdict (T) = Select_Ok) and then T.elevated_lines = 1) and then (if (Verdict (T) = Select_Ok) and then T.elevated_lines = 1 then Elevated_Declared'Result));

end Model_Tier_Select_Pkg;
