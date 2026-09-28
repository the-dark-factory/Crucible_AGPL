--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1722462d759b6907eb9c1e28abcfe6000f40e2340b77ae0b5ec6cc04fee96b36
--
package Lovelace_Go_Quote_Pkg with SPARK_Mode, Pure is

   Max_Input : constant := 8_192;
   BEL : constant Character := Character'Val (7);
   BS  : constant Character := Character'Val (8);
   HT  : constant Character := Character'Val (9);
   LF  : constant Character := Character'Val (10);
   VT  : constant Character := Character'Val (11);
   FF  : constant Character := Character'Val (12);
   CR  : constant Character := Character'Val (13);
   subtype Hex_Value is Natural range 0 .. 15;
   subtype Escape_Length_Type is Positive range 1 .. 4;

   function Is_Ascii (C : Character) return Boolean is
     (Character'Pos (C) <= 127)
     with Post => ((Is_Ascii'Result = True) = (Character'Pos (C) <= 127));

   function Is_Plain (C : Character) return Boolean is
     (C in ' ' .. '~' and then C /= '"' and then C /= '\')
     with Post => (if Is_Plain'Result then C in ' ' .. '~');

   function Has_Named_Escape (C : Character) return Boolean is
     (C = BEL or else C = BS or else C = HT or else C = LF or else C = VT or else C = FF or else C = CR)
     with Post => ((Has_Named_Escape'Result = True) = (C = BEL or else C = BS or else C = HT or else C = LF or else C = VT or else C = FF or else C = CR));

   function Named_Escape_Letter (C : Character) return Character is
     (if C = BEL then 'a'
      elsif C = BS then 'b'
      elsif C = HT then 't'
      elsif C = LF then 'n'
      elsif C = VT then 'v'
      elsif C = FF then 'f'
      else 'r')
     with Pre => Has_Named_Escape (C),
          Post => Named_Escape_Letter'Result in 'a' .. 'v';

   function Hex_Digit (N : Hex_Value) return Character is
     (if N <= 9 then Character'Val (Character'Pos ('0') + N)
      else Character'Val (Character'Pos ('a') + N - 10))
     with Post => (Hex_Digit'Result in '0' .. '9' or else Hex_Digit'Result in 'a' .. 'f');

   function Escape_Length (C : Character) return Escape_Length_Type is
     (if Is_Plain (C) then 1
      elsif C = '"' or else C = '\' or else Has_Named_Escape (C) then 2
      else 4)
     with Pre => Is_Ascii (C),
          Post => ((Escape_Length'Result = 1) = Is_Plain (C));

   function Escape_Char (C : Character; K : Positive) return Character is
     (if Is_Plain (C) then C
      elsif K = 1 then '\'
      elsif C = '"' or else C = '\' then C
      elsif Has_Named_Escape (C) then Named_Escape_Letter (C)
      elsif K = 2 then 'x'
      elsif K = 3 then Hex_Digit (Character'Pos (C) / 16)
      else Hex_Digit (Character'Pos (C) mod 16))
     with Pre => Is_Ascii (C) and then K <= Escape_Length (C),
          Post => Escape_Char'Result in ' ' .. '~'
                  and then (if not Is_Plain (C) and then K = 1 then Escape_Char'Result = '\')
                  and then (if Is_Plain (C) then Escape_Char'Result = C);

   function All_Ascii (Input : String) return Boolean is
     ((for all K in Input'Range => Is_Ascii (Input (K))))
     with Pre => Input'First = 1 and then Input'Length <= Max_Input;

   function Escape_Of (C : Character) return String is
     (if Escape_Length (C) = 1 then String'(1 => Escape_Char (C, 1))
      elsif Escape_Length (C) = 2 then String'(1 => Escape_Char (C, 1), 2 => Escape_Char (C, 2))
      else String'(1 => Escape_Char (C, 1), 2 => Escape_Char (C, 2),
                   3 => Escape_Char (C, 3), 4 => Escape_Char (C, 4)))
     with Pre  => Is_Ascii (C),
          Post => Escape_Of'Result'First = 1
                  and then Escape_Of'Result'Length = Escape_Length (C)
                  and then (for all J in 1 .. Escape_Length (C) => Escape_Of'Result (J) = Escape_Char (C, J));

   function Escaped (Input : String; K : Positive) return String is
     (if K > Input'Length then ""
      else Escape_Of (Input (K)) & Escaped (Input, K + 1))
     with Pre  => Input'First = 1 and then Input'Length <= Max_Input
                  and then All_Ascii (Input) and then K <= Input'Length + 1,
          Post => Escaped'Result'Length >= Input'Length - K + 1
                  and then Escaped'Result'Length <= 4 * (Input'Length - K + 1),
          Subprogram_Variant => (Decreases => Input'Length - K + 1);

   function Quote (Input : String) return String is
     ('"' & Escaped (Input, 1) & '"')
     with Pre  => Input'First = 1 and then Input'Length <= Max_Input and then All_Ascii (Input),
          Post => Quote'Result'Length = Escaped (Input, 1)'Length + 2
                  and then Quote'Result'Length >= Input'Length + 2
                  and then Quote'Result'Length <= 4 * Input'Length + 2
                  and then Quote'Result (Quote'Result'First) = '"'
                  and then Quote'Result (Quote'Result'Last) = '"';

end Lovelace_Go_Quote_Pkg;
