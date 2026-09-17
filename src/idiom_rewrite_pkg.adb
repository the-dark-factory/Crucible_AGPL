--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 8deb8442b629932beea7ef18244068aaecd2ae071f2786d0a727b3166dfef2c0
--
package body Idiom_Rewrite_Pkg with SPARK_Mode => On is

   function First_Old_In_Invariant (Text : String) return Natural is
      Result : Natural := 0;
   begin
      for I in Text'Range loop
         if Old_In_Invariant_At (Text, I) then
            Result := I;
            exit;
         end if;
         pragma Loop_Invariant (Result = 0);
         pragma Loop_Invariant (for all J in 1 .. I => not Old_In_Invariant_At (Text, J));
      end loop;
      return Result;
   end First_Old_In_Invariant;

   function First_Exists (Text : String) return Natural is
      Result : Natural := 0;
   begin
      for I in Text'Range loop
         if Exists_At (Text, I) then
            Result := I;
            exit;
         end if;
         pragma Loop_Invariant (Result = 0);
         pragma Loop_Invariant (for all J in 1 .. I => not Exists_At (Text, J));
      end loop;
      return Result;
   end First_Exists;

   function Bar_After (Text : String; E : Positive) return Positive is
      Result : Positive := Text'Last;
   begin
      for K in E + 7 .. Text'Length loop
         if Text (K) = '|' then
            Result := K;
            exit;
         end if;
         pragma Loop_Invariant (Result = Text'Last);
         pragma Loop_Invariant (for all J in E + 7 .. K => Text (J) /= '|');
      end loop;
      return Result;
   end Bar_After;

end Idiom_Rewrite_Pkg;