--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 83d1b1a05686d414f2d76ac99541f8cfb36827f5d8e3502d89b6f1227051ffca
--
package body Intake_Line_Pkg with SPARK_Mode => On is

   function Skip_Spaces (Line : String; From : Positive) return Positive is
      Result : Positive := From;
   begin
      while Result <= Line'Last and then Is_Space (Line (Result)) loop
         Result := Result + 1;
         pragma Loop_Variant (Increases => Result);
         pragma Loop_Invariant (Result >= From);
         pragma Loop_Invariant (Result <= Line'Last + 1);
         pragma Loop_Invariant ((for all I in From .. Result - 1 => Is_Space (Line (I))));
      end loop;
      return Result;
   end Skip_Spaces;

   function Word_Last (Line : String; From : Positive) return Positive is
      Result : Positive := From;
   begin
      while Result < Line'Last and then not Is_Space (Line (Result + 1)) loop
         Result := Result + 1;
         pragma Loop_Variant (Increases => Result);
         pragma Loop_Invariant (Result >= From);
         pragma Loop_Invariant (Result <= Line'Last);
         pragma Loop_Invariant ((for all I in From .. Result => not Is_Space (Line (I))));
      end loop;
      return Result;
   end Word_Last;

   function Name_Last (Line : String; From : Positive) return Positive is
      Result : Positive := From;
   begin
      while Result < Line'Last and then Is_Name_Char (Line (Result + 1)) loop
         Result := Result + 1;
         pragma Loop_Variant (Increases => Result);
         pragma Loop_Invariant (Result >= From);
         pragma Loop_Invariant (Result <= Line'Last);
         pragma Loop_Invariant ((for all I in From .. Result => Is_Name_Char (Line (I))));
      end loop;
      return Result;
   end Name_Last;

   function Second_Word_First (Line : String) return Positive is
      First_End : constant Positive := Word_Last (Line, Skip_Spaces (Line, 1));
      Result    : Positive := First_End + 1;
   begin
      while Result <= Line'Last and then Is_Space (Line (Result)) loop
         Result := Result + 1;
         pragma Loop_Variant (Increases => Result);
         pragma Loop_Invariant (Result >= First_End + 1);
         pragma Loop_Invariant (Result <= Line'Last + 1);
         pragma Loop_Invariant ((for all I in First_End + 1 .. Result - 1 => Is_Space (Line (I))));
      end loop;
      return Result;
   end Second_Word_First;

end Intake_Line_Pkg;