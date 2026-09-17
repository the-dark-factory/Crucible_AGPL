--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 00e4ff92628fd8c5064cdf139e45f03cbc6583507b3caad3688f6de9492b7d02
--
package body Unit_Extract_Pkg with SPARK_Mode => On is

   function After_Think (Text : String) return Positive is
      Result : Positive := 1;
   begin
      if Text'Length >= 8 then
         for I in reverse 1 .. Text'Length - 7 loop
            pragma Loop_Invariant (for all J in I + 1 .. Text'Length - 7 => Text (J .. J + 7) /= Think_End);
            if Text (I .. I + 7) = Think_End then
               Result := I + 8;
               exit;
            end if;
         end loop;
      end if;
      return Result;
   end After_Think;

   function First_Content (Text : String; From : Positive) return Positive is
      Result : Positive := Text'Length + 1;
   begin
      for I in From .. Text'Length loop
         pragma Loop_Invariant (for all J in From .. I - 1 => Is_Space (Text (J)));
         pragma Loop_Invariant (Result = Text'Length + 1);
         if not Is_Space (Text (I)) then
            Result := I;
            exit;
         end if;
      end loop;
      return Result;
   end First_Content;

   function Last_Content (Text : String) return Natural is
      Result : Natural := 0;
   begin
      for I in reverse 1 .. Text'Length loop
         pragma Loop_Invariant (for all J in I + 1 .. Text'Length => Is_Space (Text (J)));
         pragma Loop_Invariant (Result = 0);
         if not Is_Space (Text (I)) then
            Result := I;
            exit;
         end if;
      end loop;
      return Result;
   end Last_Content;

   procedure Blank_Fences (T : in out String) is
      T_Entry : constant String := T;
   begin
      for I in 1 .. T'Length loop
         pragma Loop_Invariant (for all J in 1 .. I - 1 => T (J) = (if In_Fence_Line (T_Entry, J) then ' ' else T_Entry (J)));
         pragma Loop_Invariant (for all J in I .. T'Length => T (J) = T_Entry (J));
         if In_Fence_Line (T_Entry, I) then
            T (I) := ' ';
         end if;
      end loop;
   end Blank_Fences;

end Unit_Extract_Pkg;