--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: f83a57c1c9ce36f74593b9dde111b64838f14c931ae3dc5a18800be439262afc
--
package Json_String_Pkg with SPARK_Mode is

   Max_Raw : constant := 1_048_576;
   LF : constant Character := Character'Val (10);
   HT : constant Character := Character'Val (9);
   CR : constant Character := Character'Val (13);
   BS : constant Character := Character'Val (8);
   FF : constant Character := Character'Val (12);

   function Is_Plain (C : Character) return Boolean is
     ((if C in ' ' .. '~' and then C /= '"' and then C /= '\' then True else False))
   with Post => (if Is_Plain'Result then C in ' ' .. '~');

   function Is_Simple_Escape (C : Character) return Boolean is
     ((if C = '"' or C = '\' or C = '/' or C = 'n' or C = 't' or C = 'r' or C = 'b' or C = 'f' then True else False))
   with Post => (if Is_Simple_Escape'Result then C in ' ' .. '~');

   function Simple_Value (C : Character) return Character is
     ((if C = '"' then '"'
       elsif C = '\' then '\'
       elsif C = '/' then '/'
       elsif C = 'n' then LF
       elsif C = 't' then HT
       elsif C = 'r' then CR
       elsif C = 'b' then BS
       else FF))
   with Pre => Is_Simple_Escape (C),
        Post => (Simple_Value'Result in ' ' .. '~' or Simple_Value'Result = LF or Simple_Value'Result = HT or Simple_Value'Result = CR or Simple_Value'Result = BS or Simple_Value'Result = FF);

   function Is_Output_Char (C : Character) return Boolean is
     ((if C in ' ' .. '~' or C = LF or C = HT or C = CR or C = BS or C = FF then True else False))
   with Post => (if C = Character'Val (0) then not Is_Output_Char'Result);

   function Is_Hex (C : Character) return Boolean is
     ((if C in '0' .. '9' or C in 'a' .. 'f' or C in 'A' .. 'F' then True else False))
   with Post => (if Is_Hex'Result then C in ' ' .. '~');

   function Hex_Value (C : Character) return Natural is
     ((if C in '0' .. '9' then Character'Pos (C) - Character'Pos ('0')
       elsif C in 'a' .. 'f' then Character'Pos (C) - Character'Pos ('a') + 10
       else Character'Pos (C) - Character'Pos ('A') + 10))
   with Pre => Is_Hex (C),
        Post => Hex_Value'Result <= 15;

   procedure Decode (Raw : String; Output : out String; Output_Len : out Natural; Ok : out Boolean)
   with Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then Output'First = 1 and then Output'Length >= Raw'Length,
        Post => (if Ok then Output_Len <= Raw'Length and then (for all K in 1 .. Output_Len => Is_Output_Char (Output (K)))) and then (if (for all K in Raw'Range => Is_Plain (Raw (K))) then Ok and then Output_Len = Raw'Length and then (for all K in Raw'Range => Output (K) = Raw (K))) and then (if (for some K in Raw'Range => Raw (K) not in ' ' .. '~') then not Ok) and then (if Raw'Length >= 1 and then Raw (Raw'Last) = '\' and then (Raw'Length = 1 or else Raw (Raw'Last - 1) /= '\') then not Ok) and then (if Raw'Length = 2 and then Raw (1) = '\' and then Is_Simple_Escape (Raw (2)) then Ok and then Output_Len = 1 and then Output (1) = Simple_Value (Raw (2)));

end Json_String_Pkg;
