--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 7969392c7a4a8b2f126f76ff594c245882563359321a982496bbdaab166aeb1a
--
package Hex_Text_Pkg with SPARK_Mode is

   subtype Nibble is Integer range 0 .. 15;

   function Is_Hex_Digit (C : Character) return Boolean is
     ((C in '0' .. '9') or (C in 'a' .. 'f'))
     with Post => (Is_Hex_Digit'Result = ((C in '0' .. '9') or (C in 'a' .. 'f')));

   function Digit_Of (N : Nibble) return Character is
     (if N < 10 then Character'Val (Character'Pos ('0') + N) else Character'Val (Character'Pos ('a') + N - 10))
     with Post => Is_Hex_Digit (Digit_Of'Result);

   function Value_Of (C : Character) return Nibble is
     (if C in '0' .. '9' then Character'Pos (C) - Character'Pos ('0') else Character'Pos (C) - Character'Pos ('a') + 10)
     with Pre  => Is_Hex_Digit (C),
          Post => Digit_Of (Value_Of'Result) = C;

   function Is_Hex_Text (H : String) return Boolean is
     (H'Length mod 2 = 0 and then (for all I in H'Range => Is_Hex_Digit (H (I))))
     with Post => (Is_Hex_Text'Result = (H'Length mod 2 = 0 and then (for all I in H'Range => Is_Hex_Digit (H (I)))));

   function Encode (S : String) return String
     with Pre  => S'Length <= Natural'Last / 2,
          Post => (Encode'Result'First = 1
                  and then Encode'Result'Length = 2 * S'Length
                  and then (for all I in S'Range =>
                             (Encode'Result (2 * (I - S'First) + 1) = Digit_Of (Nibble (Character'Pos (S (I)) / 16))
                              and then Encode'Result (2 * (I - S'First) + 2) = Digit_Of (Nibble (Character'Pos (S (I)) mod 16))))
                  and then Is_Hex_Text (Encode'Result));

   function Decode (H : String) return String
     with Pre  => Is_Hex_Text (H),
          Post => (Decode'Result'First = 1
                  and then Decode'Result'Length = H'Length / 2
                  and then (for all J in Decode'Result'Range =>
                             Character'Pos (Decode'Result (J)) =
                               16 * Value_Of (H (H'First + 2 * (J - 1))) + Value_Of (H (H'First + 2 * (J - 1) + 1))));

end Hex_Text_Pkg;
