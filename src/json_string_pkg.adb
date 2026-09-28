--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1a48b8934aa8ac611eaed567e676e95d9662ff75efc9ecdbbfe5cf161dfcaa2f
--
package body Json_String_Pkg with SPARK_Mode => On is

   procedure Decode (Raw : String; Output : out String; Output_Len : out Natural; Ok : out Boolean) is
      K  : Positive := 1;
      N  : Natural := 0;
      W  : Natural;
      V  : Natural;
      V2 : Natural;
      C  : Natural;
      L  : Positive;
   begin
      Output := (others => ' ');
      Output_Len := 0;
      Ok := False;

      while K <= Raw'Last loop
         pragma Loop_Invariant (N <= K - 1);
         pragma Loop_Invariant (for all J in 1 .. K - 1 => Raw (J) >= ' ');
         pragma Loop_Invariant (if (for all J in 1 .. K - 1 => Is_Plain (Raw (J)))
                                then N = K - 1 and then (for all J in 1 .. N => Output (J) = Raw (J)));
         pragma Loop_Invariant (if K >= 2 and then Raw (K - 1) = '\' then K >= 3 and then Raw (K - 2) = '\');
         pragma Loop_Invariant (if Raw'Length = 2 and then Raw (1) = '\' and then Is_Simple_Escape (Raw (2)) then K = 1);
         pragma Loop_Invariant (Dec_Ok (Raw, 1) = Dec_Ok (Raw, K));
         pragma Loop_Invariant (Dec_Len (Raw, 1) = N + Dec_Len (Raw, K));
         pragma Loop_Invariant (for all I in 1 .. N => Output (I) = Dec_Nth (Raw, 1, I));
         pragma Loop_Invariant (for all J in 1 .. Raw'Last - K + 1 => Dec_Nth (Raw, 1, N + J) = Dec_Nth (Raw, K, J));
         pragma Loop_Variant (Increases => K);

         if Raw (K) < ' ' or else Raw (K) = '"' then
            --  A raw control character or a raw quote: refused.
            pragma Assert (Dec_Step (Raw, K) = 0);
            return;
         elsif Character'Pos (Raw (K)) >= 16#80# then
            --  A multi-byte UTF-8 sequence: copied unchanged when well-formed, refused if not.
            W := Utf8_Width (Raw, K);
            if W = 0 then
               pragma Assert (Dec_Step (Raw, K) = 0);
               return;
            end if;
            pragma Assert (W >= 2);
            pragma Assert (Dec_Step (Raw, K) = W);
            pragma Assert (Dec_Width (Raw, K) = W);
            pragma Assert (for all I in 1 .. W => Dec_Nth (Raw, K, I) = Raw (K + I - 1));
            pragma Assert (for all J in 1 .. Raw'Last - K - W + 1 => Dec_Nth (Raw, K, J + W) = Dec_Nth (Raw, K + W, J));
            pragma Assert (for all I in 0 .. W - 1 => Character'Pos (Raw (K + I)) >= 16#80#);
            pragma Assert (for all I in 0 .. W - 1 => Raw (K + I) >= ' ');
            Output (N + 1 .. N + W) := Raw (K .. K + W - 1);
            pragma Assert (for all I in 1 .. W => Output (N + I) = Raw (K + I - 1));
            pragma Assert (Output (N + 1) = Dec_Nth (Raw, 1, N + 1));
            pragma Assert (Output (N + 2) = Dec_Nth (Raw, 1, N + 2));
            pragma Assert (if W >= 3 then Output (N + 3) = Dec_Nth (Raw, 1, N + 3));
            pragma Assert (if W = 4 then Output (N + 4) = Dec_Nth (Raw, 1, N + 4));
            pragma Assert (for all I in 1 .. N => Output (I) = Dec_Nth (Raw, 1, I));
            pragma Assert (for all I in N + 1 .. N + W => Output (I) = Dec_Nth (Raw, 1, I));
            pragma Assert (for all I in 1 .. N + W => Output (I) = Dec_Nth (Raw, 1, I));
            pragma Assert (for all J in 1 .. Raw'Last - K - W + 1 => Dec_Nth (Raw, 1, N + W + J) = Dec_Nth (Raw, K + W, J));
            pragma Assert (for all J in 1 .. K + W - 1 => Raw (J) >= ' ');
            N := N + W;
            K := K + W;
            pragma Assert (for all J in 1 .. Raw'Last - K + 1 => Dec_Nth (Raw, 1, N + J) = Dec_Nth (Raw, K, J));
         elsif Raw (K) /= '\' then
            --  One byte 32 .. 127 (not '"', not '\'): itself.
            pragma Assert (Dec_Step (Raw, K) = 1);
            pragma Assert (Dec_Width (Raw, K) = 1);
            pragma Assert (Dec_Nth (Raw, K, 1) = Raw (K));
            pragma Assert (for all J in 1 .. Raw'Last - K => Dec_Nth (Raw, K, J + 1) = Dec_Nth (Raw, K + 1, J));
            pragma Assert (for all J in 1 .. K => Raw (J) >= ' ');
            N := N + 1;
            Output (N) := Raw (K);
            K := K + 1;
            pragma Assert (for all J in 1 .. Raw'Last - K + 1 => Dec_Nth (Raw, 1, N + J) = Dec_Nth (Raw, K, J));
         elsif K = Raw'Last then
            --  A backslash with nothing after it.
            pragma Assert (Dec_Step (Raw, K) = 0);
            return;
         elsif Is_Simple_Escape (Raw (K + 1)) then
            pragma Assert (Dec_Step (Raw, K) = 2);
            pragma Assert (Dec_Width (Raw, K) = 1);
            pragma Assert (Dec_Nth (Raw, K, 1) = Simple_Value (Raw (K + 1)));
            pragma Assert (for all J in 1 .. Raw'Last - K - 1 => Dec_Nth (Raw, K, J + 1) = Dec_Nth (Raw, K + 2, J));
            pragma Assert (Raw (K + 1) >= ' ');
            pragma Assert (for all J in 1 .. K + 1 => Raw (J) >= ' ');
            N := N + 1;
            Output (N) := Simple_Value (Raw (K + 1));
            K := K + 2;
            pragma Assert (for all J in 1 .. Raw'Last - K + 1 => Dec_Nth (Raw, 1, N + J) = Dec_Nth (Raw, K, J));
         elsif Is_U_Esc (Raw, K) then
            V := 4096 * Hex_Value (Raw (K + 2)) + 256 * Hex_Value (Raw (K + 3))
                 + 16 * Hex_Value (Raw (K + 4)) + Hex_Value (Raw (K + 5));
            pragma Assert (V = Dec_Code (Raw, K));
            if V in 16#DC00# .. 16#DFFF# then
               --  A low surrogate with no high surrogate before it: refused.
               pragma Assert (Dec_Step (Raw, K) = 0);
               return;
            elsif V in 16#D800# .. 16#DBFF# then
               --  A high surrogate: the very next token must be a low surrogate escape.
               if not (K + 6 <= Raw'Last and then Is_U_Esc (Raw, K + 6)) then
                  pragma Assert (Dec_Step (Raw, K) = 0);
                  return;
               end if;
               V2 := 4096 * Hex_Value (Raw (K + 8)) + 256 * Hex_Value (Raw (K + 9))
                     + 16 * Hex_Value (Raw (K + 10)) + Hex_Value (Raw (K + 11));
               pragma Assert (V2 = Dec_Code (Raw, K + 6));
               if V2 not in 16#DC00# .. 16#DFFF# then
                  pragma Assert (Dec_Step (Raw, K) = 0);
                  return;
               end if;
               pragma Assert (for all J in K .. K + 11 => Raw (J) >= ' ');
               pragma Assert (for all J in 1 .. K + 11 => Raw (J) >= ' ');
               C := 16#10000# + 1024 * (V - 16#D800#) + (V2 - 16#DC00#);
               pragma Assert (Dec_Step (Raw, K) = 12);
               pragma Assert (Dec_Point (Raw, K) = C);
               pragma Assert (C in 16#10000# .. 16#10FFFF#);
               pragma Assert (U8_Len (C) = 4);
               pragma Assert (Dec_Width (Raw, K) = 4);
               pragma Assert (Dec_Nth (Raw, K, 1) = Character'Val (U8_Byte (C, 1)));
               pragma Assert (Dec_Nth (Raw, K, 2) = Character'Val (U8_Byte (C, 2)));
               pragma Assert (Dec_Nth (Raw, K, 3) = Character'Val (U8_Byte (C, 3)));
               pragma Assert (Dec_Nth (Raw, K, 4) = Character'Val (U8_Byte (C, 4)));
               pragma Assert (for all J in 1 .. Raw'Last - K - 11 => Dec_Nth (Raw, K, J + 4) = Dec_Nth (Raw, K + 12, J));
               Output (N + 1) := Character'Val (U8_Byte (C, 1));
               Output (N + 2) := Character'Val (U8_Byte (C, 2));
               Output (N + 3) := Character'Val (U8_Byte (C, 3));
               Output (N + 4) := Character'Val (U8_Byte (C, 4));
               pragma Assert (Output (N + 1) = Dec_Nth (Raw, 1, N + 1));
               pragma Assert (Output (N + 2) = Dec_Nth (Raw, 1, N + 2));
               pragma Assert (Output (N + 3) = Dec_Nth (Raw, 1, N + 3));
               pragma Assert (Output (N + 4) = Dec_Nth (Raw, 1, N + 4));
               pragma Assert (for all I in 1 .. N => Output (I) = Dec_Nth (Raw, 1, I));
               pragma Assert (for all I in N + 1 .. N + 4 => Output (I) = Dec_Nth (Raw, 1, I));
               pragma Assert (for all I in 1 .. N + 4 => Output (I) = Dec_Nth (Raw, 1, I));
               pragma Assert (for all J in 1 .. Raw'Last - K - 11 => Dec_Nth (Raw, 1, N + 4 + J) = Dec_Nth (Raw, K + 12, J));
               N := N + 4;
               K := K + 12;
               pragma Assert (for all J in 1 .. Raw'Last - K + 1 => Dec_Nth (Raw, 1, N + J) = Dec_Nth (Raw, K, J));
            else
               --  Any other code point: its UTF-8 bytes (1 to 3 of them).
               C := V;
               L := U8_Len (C);
               pragma Assert (L <= 3);
               pragma Assert (Dec_Step (Raw, K) = 6);
               pragma Assert (Dec_Point (Raw, K) = C);
               pragma Assert (Dec_Width (Raw, K) = L);
               pragma Assert (Dec_Nth (Raw, K, 1) = Character'Val (U8_Byte (C, 1)));
               pragma Assert (if L >= 2 then Dec_Nth (Raw, K, 2) = Character'Val (U8_Byte (C, 2)));
               pragma Assert (if L = 3 then Dec_Nth (Raw, K, 3) = Character'Val (U8_Byte (C, 3)));
               pragma Assert (for all J in 1 .. Raw'Last - K - 5 => Dec_Nth (Raw, K, J + L) = Dec_Nth (Raw, K + 6, J));
               Output (N + 1) := Character'Val (U8_Byte (C, 1));
               if L >= 2 then
                  Output (N + 2) := Character'Val (U8_Byte (C, 2));
               end if;
               if L = 3 then
                  Output (N + 3) := Character'Val (U8_Byte (C, 3));
               end if;
               pragma Assert (Output (N + 1) = Dec_Nth (Raw, 1, N + 1));
               pragma Assert (if L >= 2 then Output (N + 2) = Dec_Nth (Raw, 1, N + 2));
               pragma Assert (if L = 3 then Output (N + 3) = Dec_Nth (Raw, 1, N + 3));
               pragma Assert (for all I in 1 .. N => Output (I) = Dec_Nth (Raw, 1, I));
               pragma Assert (for all I in N + 1 .. N + L => Output (I) = Dec_Nth (Raw, 1, I));
               pragma Assert (for all I in 1 .. N + L => Output (I) = Dec_Nth (Raw, 1, I));
               pragma Assert (for all J in 1 .. Raw'Last - K - 5 => Dec_Nth (Raw, 1, N + L + J) = Dec_Nth (Raw, K + 6, J));
               pragma Assert (for all I in 0 .. 5 => Raw (K + I) >= ' ');
               pragma Assert (for all J in 1 .. K + 5 => Raw (J) >= ' ');
               N := N + L;
               K := K + 6;
               pragma Assert (for all J in 1 .. Raw'Last - K + 1 => Dec_Nth (Raw, 1, N + J) = Dec_Nth (Raw, K, J));
            end if;
         else
            --  An unknown escape letter, or a truncated or malformed backslash-u escape.
            pragma Assert (Dec_Step (Raw, K) = 0);
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
            pragma Assert (Output (N + 1) = '\');
            pragma Assert (Output (N + 2) >= ' ');
            pragma Assert (for all J in 1 .. N => Output (J) >= ' ');
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