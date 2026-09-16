--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 2f3022e019a5c42a9681c2aa5f4085b0237e36900ed13ed7fb14713f957a4f75
--
package body Hex_Text_Pkg with SPARK_Mode is

   function Encode (S : String) return String is
      Result : String (1 .. 2 * S'Length) := (others => '0');
   begin
      for I in S'Range loop
         Result (2 * (I - S'First) + 1) := Digit_Of (Nibble (Character'Pos (S (I)) / 16));
         Result (2 * (I - S'First) + 2) := Digit_Of (Nibble (Character'Pos (S (I)) mod 16));
         pragma Loop_Invariant
           (for all K in S'First .. I =>
              (Result (2 * (K - S'First) + 1) = Digit_Of (Nibble (Character'Pos (S (K)) / 16))
               and then Result (2 * (K - S'First) + 2) = Digit_Of (Nibble (Character'Pos (S (K)) mod 16))));
         pragma Loop_Invariant
           (for all J in Result'Range => Is_Hex_Digit (Result (J)));
      end loop;
      return Result;
   end Encode;

   function Decode (H : String) return String is
      Result : String (1 .. H'Length / 2) := (others => Character'Val (0));
   begin
      for J in Result'Range loop
         Result (J) := Character'Val
           (16 * Value_Of (H (H'First + 2 * (J - 1))) + Value_Of (H (H'First + 2 * (J - 1) + 1)));
         pragma Loop_Invariant
           (for all K in Result'First .. J =>
              Character'Pos (Result (K)) =
                16 * Value_Of (H (H'First + 2 * (K - 1))) + Value_Of (H (H'First + 2 * (K - 1) + 1)));
      end loop;
      return Result;
   end Decode;

end Hex_Text_Pkg;