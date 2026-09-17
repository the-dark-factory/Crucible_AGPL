--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: da9e0aafa805684b136389e86bc31872b99c3582ecdb98c5e91cff76a5d43dee
--
package body Body_Hygiene_Pkg with SPARK_Mode is

   procedure Blank_Aspects (T : in out String)
     is
      Old : String := T;
   begin
      for I in 1 .. T'Length loop
         if In_Aspect_Region (Old, I) and then Old (I) /= LF then
            T (I) := ' ';
         end if;
         pragma Loop_Invariant (for all J in 1 .. I =>
                                 T (J) = (if In_Aspect_Region (Old, J) and then Old (J) /= LF then ' ' else Old (J)));
      end loop;
   end Blank_Aspects;

   function First_Head_Is (Text : String) return Natural
     is
      Result : Natural := 0;
   begin
      for E in 1 .. Text'Length loop
         if Head_Is_At (Text, E) then
            Result := E;
            exit;
         end if;
         pragma Loop_Invariant (for all K in 1 .. E => not Head_Is_At (Text, K));
         pragma Loop_Invariant (if Result >= 1 then Head_Is_At (Text, Result));
      end loop;
      return Result;
   end First_Head_Is;

end Body_Hygiene_Pkg;