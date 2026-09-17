--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 07057d9aa720f55dedec259519dd1877f6145ec39f679c6902bca977c83d749c
--
package body Json_String_Pkg with SPARK_Mode is

   procedure Decode (Raw : String; Output : out String; Output_Len : out Natural; Ok : out Boolean) is
      K : Positive := 1;
      N : Natural := 0;
   begin
      Output := (others => ' ');
      Output_Len := 0;
      Ok := False;

      while K <= Raw'Last loop
         pragma Loop_Invariant (N <= K - 1);
         pragma Loop_Invariant (for all J in 1 .. N => Is_Output_Char (Output (J)));
         pragma Loop_Invariant (for all J in 1 .. K - 1 => Raw (J) in ' ' .. '~');
         pragma Loop_Invariant (if (for all J in 1 .. K - 1 => Is_Plain (Raw (J)))
                                then N = K - 1 and then (for all J in 1 .. N => Output (J) = Raw (J)));
         pragma Loop_Invariant (if K >= 2 and then Raw (K - 1) = '\' then K >= 3 and then Raw (K - 2) = '\');
         pragma Loop_Invariant (if Raw'Length = 2 and then Raw (1) = '\' and then Is_Simple_Escape (Raw (2)) then K = 1);
         pragma Loop_Variant (Increases => K);

         if Raw (K) not in ' ' .. '~' or else Raw (K) = '"' then
            return;
         elsif Raw (K) /= '\' then
            pragma Assert (Is_Output_Char (Raw (K)));
            N := N + 1;
            Output (N) := Raw (K);
            K := K + 1;
         elsif K = Raw'Last then
            return;
         elsif Is_Simple_Escape (Raw (K + 1)) then
            pragma Assert (Is_Output_Char (Simple_Value (Raw (K + 1))));
            N := N + 1;
            Output (N) := Simple_Value (Raw (K + 1));
            K := K + 2;
         elsif Raw (K + 1) = 'u' and then K <= Raw'Last - 5
           and then Is_Hex (Raw (K + 2)) and then Is_Hex (Raw (K + 3))
           and then Is_Hex (Raw (K + 4)) and then Is_Hex (Raw (K + 5))
         then
            declare
               V : constant Natural := 4096 * Hex_Value (Raw (K + 2)) + 256 * Hex_Value (Raw (K + 3))
                                     + 16 * Hex_Value (Raw (K + 4)) + Hex_Value (Raw (K + 5));
            begin
               if V in 16#20# .. 16#7E# then
                  pragma Assert (Is_Output_Char (Character'Val (V)));
                  N := N + 1;
                  Output (N) := Character'Val (V);
                  K := K + 6;
               else
                  return;
               end if;
            end;
         else
            return;
         end if;
      end loop;

      Output_Len := N;
      Ok := True;
   end Decode;

end Json_String_Pkg;