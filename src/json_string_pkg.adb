--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: ec067fec79b762ebe874198fcf7bed44d1dbd03bebb3deebfa3602760e2bc988
--
package body Json_String_Pkg with SPARK_Mode => On is

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
         pragma Loop_Invariant (Dec_Ok (Raw, 1) = Dec_Ok (Raw, K));
         pragma Loop_Invariant (Dec_Len (Raw, 1) = N + Dec_Len (Raw, K));
         pragma Loop_Invariant (for all I in 1 .. N => Output (I) = Dec_Nth (Raw, 1, I));
         pragma Loop_Invariant (for all J in 1 .. Raw'Last - K + 1 => Dec_Nth (Raw, 1, N + J) = Dec_Nth (Raw, K, J));
         pragma Loop_Variant (Increases => K);

         if Raw (K) not in ' ' .. '~' or else Raw (K) = '"' then
            return;
         elsif Raw (K) /= '\' then
            pragma Assert (Is_Output_Char (Raw (K)));
            pragma Assert (Dec_Step (Raw, K) = 1);
            pragma Assert (Dec_Nth (Raw, K, 1) = Raw (K));
            pragma Assert (for all J in 1 .. Raw'Last - K => Dec_Nth (Raw, K, J + 1) = Dec_Nth (Raw, K + 1, J));
            N := N + 1;
            Output (N) := Raw (K);
            K := K + 1;
         elsif K = Raw'Last then
            return;
         elsif Is_Simple_Escape (Raw (K + 1)) then
            pragma Assert (Is_Output_Char (Simple_Value (Raw (K + 1))));
            pragma Assert (Dec_Step (Raw, K) = 2);
            pragma Assert (Dec_Nth (Raw, K, 1) = Simple_Value (Raw (K + 1)));
            pragma Assert (for all J in 1 .. Raw'Last - K - 1 => Dec_Nth (Raw, K, J + 1) = Dec_Nth (Raw, K + 2, J));
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
                  pragma Assert (V = Dec_Code (Raw, K));
                  pragma Assert (Dec_Step (Raw, K) = 6);
                  pragma Assert (Dec_Nth (Raw, K, 1) = Character'Val (V));
                  pragma Assert (for all J in 1 .. Raw'Last - K - 5 => Dec_Nth (Raw, K, J + 1) = Dec_Nth (Raw, K + 6, J));
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

   procedure Encode (Input : String; Output : out String; Output_Len : out Natural; Ok : out Boolean) is
      K : Positive := 1;
      N : Natural := 0;
      W : Natural;
      P : Natural;
   begin
      Output := (others => ' ');
      Output_Len := 0;
      Ok := False;

      while K <= Input'Last loop
         pragma Loop_Invariant (N <= 6 * (K - 1));
         pragma Loop_Invariant (for all J in 1 .. N => Output (J) >= ' ');
         pragma Loop_Invariant (if (for all J in 1 .. K - 1 => Is_Plain (Input (J)))
                                then N = K - 1 and then (for all J in 1 .. N => Output (J) = Input (J)));
         pragma Loop_Invariant (if Input'Length = 1 and then Input (1) = LF then K = 1);
         pragma Loop_Invariant (Utf8_Valid_From (Input, 1) = Utf8_Valid_From (Input, K));
         pragma Loop_Invariant (Enc_Len (Input, 1) = N + Enc_Len (Input, K));
         pragma Loop_Invariant (for all I in 1 .. N => Output (I) = Enc_Nth (Input, 1, I));
         pragma Loop_Invariant (for all J in 1 .. 6 * (Input'Last - K + 1) => Enc_Nth (Input, 1, N + J) = Enc_Nth (Input, K, J));
         pragma Loop_Variant (Increases => K);

         W := Utf8_Width (Input, K);
         if W = 0 then
            return;
         elsif W >= 2 then
            --  A well-formed multi-byte sequence: copied unchanged.
            pragma Assert (Enc_Width (Input, K) = W);
            pragma Assert (for all I in 1 .. W => Enc_Nth (Input, K, I) = Input (K + I - 1));
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K - W + 1) => Enc_Nth (Input, K, J + W) = Enc_Nth (Input, K + W, J));
            pragma Assert (for all I in 0 .. W - 1 => Input (K + I) >= ' ');
            Output (N + 1 .. N + W) := Input (K .. K + W - 1);
            pragma Assert (for all I in 1 .. W => Output (N + I) = Input (K + I - 1));
            pragma Assert (for all I in 1 .. W => Output (N + I) >= ' ');
            pragma Assert (Output (N + 1) = Enc_Nth (Input, 1, N + 1));
            pragma Assert (Output (N + 2) = Enc_Nth (Input, 1, N + 2));
            pragma Assert (if W >= 3 then Output (N + 3) = Enc_Nth (Input, 1, N + 3));
            pragma Assert (if W = 4 then Output (N + 4) = Enc_Nth (Input, 1, N + 4));
            pragma Assert (for all J in 1 .. N + W => Output (J) >= ' ');
            pragma Assert (for all I in 1 .. N => Output (I) = Enc_Nth (Input, 1, I));
            pragma Assert (for all I in N + 1 .. N + W => Output (I) = Enc_Nth (Input, 1, I));
            pragma Assert (for all I in 1 .. N + W => Output (I) = Enc_Nth (Input, 1, I));
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K - W + 1) => Enc_Nth (Input, 1, N + W + J) = Enc_Nth (Input, K + W, J));
            N := N + W;
            K := K + W;
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K + 1) => Enc_Nth (Input, 1, N + J) = Enc_Nth (Input, K, J));
         elsif Is_Plain (Input (K)) or else Input (K) = DEL then
            pragma Assert (Enc_Width (Input, K) = 1);
            pragma Assert (Enc_Nth (Input, K, 1) = Input (K));
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K) => Enc_Nth (Input, K, J + 1) = Enc_Nth (Input, K + 1, J));
            N := N + 1;
            Output (N) := Input (K);
            pragma Assert (for all J in 1 .. N => Output (J) >= ' ');
            pragma Assert (for all I in 1 .. N => Output (I) = Enc_Nth (Input, 1, I));
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K - 1 + 1) => Enc_Nth (Input, 1, N + J) = Enc_Nth (Input, K + 1, J));
            K := K + 1;
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K + 1) => Enc_Nth (Input, 1, N + J) = Enc_Nth (Input, K, J));
         elsif Input (K) = '"' or else Input (K) = '\' or else Input (K) = LF or else Input (K) = HT
           or else Input (K) = CR or else Input (K) = BS or else Input (K) = FF
         then
            pragma Assert (Enc_Width (Input, K) = 2);
            pragma Assert (Enc_Nth (Input, K, 1) = '\');
            pragma Assert (Enc_Nth (Input, K, 2) = Esc_Letter (Input (K)));
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K) => Enc_Nth (Input, K, J + 2) = Enc_Nth (Input, K + 1, J));
            Output (N + 1) := '\';
            if Input (K) = LF then
               Output (N + 2) := 'n';
            elsif Input (K) = HT then
               Output (N + 2) := 't';
            elsif Input (K) = CR then
               Output (N + 2) := 'r';
            elsif Input (K) = BS then
               Output (N + 2) := 'b';
            elsif Input (K) = FF then
               Output (N + 2) := 'f';
            else
               Output (N + 2) := Input (K);
            end if;
            pragma Assert (for all J in 1 .. N + 2 => Output (J) >= ' ');
            pragma Assert (for all I in 1 .. N + 2 => Output (I) = Enc_Nth (Input, 1, I));
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K - 1 + 1) => Enc_Nth (Input, 1, N + 2 + J) = Enc_Nth (Input, K + 1, J));
            N := N + 2;
            K := K + 1;
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K + 1) => Enc_Nth (Input, 1, N + J) = Enc_Nth (Input, K, J));
         else
            --  Any other control character: backslash, u, 0, 0, two lower-case hex digits.
            P := Character'Pos (Input (K));
            pragma Assert (P < 32);
            pragma Assert (Enc_Width (Input, K) = 6);
            pragma Assert (Enc_Nth (Input, K, 1) = '\');
            pragma Assert (Enc_Nth (Input, K, 2) = 'u');
            pragma Assert (Enc_Nth (Input, K, 3) = '0');
            pragma Assert (Enc_Nth (Input, K, 4) = '0');
            pragma Assert (Enc_Nth (Input, K, 5) = Hex_Digit (P / 16));
            pragma Assert (Enc_Nth (Input, K, 6) = Hex_Digit (P mod 16));
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K) => Enc_Nth (Input, K, J + 6) = Enc_Nth (Input, K + 1, J));
            Output (N + 1) := '\';
            Output (N + 2) := 'u';
            Output (N + 3) := '0';
            Output (N + 4) := '0';
            Output (N + 5) := Hex_Digit (P / 16);
            Output (N + 6) := Hex_Digit (P mod 16);
            pragma Assert (Output (N + 5) in '0' .. '9' or else Output (N + 5) in 'a' .. 'f');
            pragma Assert (Output (N + 6) in '0' .. '9' or else Output (N + 6) in 'a' .. 'f');
            pragma Assert (for all J in 1 .. N => Output (J) >= ' ');
            pragma Assert (for all J in N + 1 .. N + 6 => Output (J) >= ' ');
            pragma Assert (for all J in 1 .. N + 6 => Output (J) >= ' ');
            pragma Assert (for all I in 1 .. N + 6 => Output (I) = Enc_Nth (Input, 1, I));
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K - 1 + 1) => Enc_Nth (Input, 1, N + 6 + J) = Enc_Nth (Input, K + 1, J));
            N := N + 6;
            K := K + 1;
            pragma Assert (for all J in 1 .. 6 * (Input'Last - K + 1) => Enc_Nth (Input, 1, N + J) = Enc_Nth (Input, K, J));
         end if;
      end loop;

      Output_Len := N;
      Ok := True;
   end Encode;

end Json_String_Pkg;