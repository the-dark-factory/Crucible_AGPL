--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 57440c6010c025e2742c354deeed0d02ab6dc9d44408951fe04b722d9ff9f5ef
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

   function Is_Encodable (C : Character) return Boolean is
     ((if Is_Plain (C) or C = '"' or C = '\' or C = LF or C = HT or C = CR then True else False))
   with Post => (if Is_Encodable'Result then Is_Output_Char (C));

   function Is_Hex (C : Character) return Boolean is
     ((if C in '0' .. '9' or C in 'a' .. 'f' or C in 'A' .. 'F' then True else False))
   with Post => (if Is_Hex'Result then C in ' ' .. '~');

   function Hex_Value (C : Character) return Natural is
     ((if C in '0' .. '9' then Character'Pos (C) - Character'Pos ('0')
       elsif C in 'a' .. 'f' then Character'Pos (C) - Character'Pos ('a') + 10
       else Character'Pos (C) - Character'Pos ('A') + 10))
   with Pre => Is_Hex (C),
        Post => Hex_Value'Result <= 15;

   --  THE MODEL OF Decode AND Encode (ghost: proof only, never compiled into the program).
   --  Decode's and Encode's Posts say their outputs ARE these definitions, so no body
   --  can be hollow: every output character, the length and Ok are all pinned.

   --  Dec_Code: the value of the four hex digits of a \uHHHH escape starting at K.
   function Dec_Code (Raw : String; K : Positive) return Natural is
     (4096 * Hex_Value (Raw (K + 2)) + 256 * Hex_Value (Raw (K + 3))
      + 16 * Hex_Value (Raw (K + 4)) + Hex_Value (Raw (K + 5)))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K in Raw'Range
               and then K <= Raw'Last - 5
               and then Is_Hex (Raw (K + 2)) and then Is_Hex (Raw (K + 3))
               and then Is_Hex (Raw (K + 4)) and then Is_Hex (Raw (K + 5)),
        Post => Dec_Code'Result <= 65535;

   --  Dec_Step: how many characters of Raw the token at K takes (1, 2 or 6); 0 means
   --  the token at K is invalid and Decode refuses.
   function Dec_Step (Raw : String; K : Positive) return Natural is
     ((if Raw (K) not in ' ' .. '~' or else Raw (K) = '"' then 0
       elsif Raw (K) /= '\' then 1
       elsif K = Raw'Last then 0
       elsif Is_Simple_Escape (Raw (K + 1)) then 2
       elsif Raw (K + 1) = 'u' and then K <= Raw'Last - 5
         and then Is_Hex (Raw (K + 2)) and then Is_Hex (Raw (K + 3))
         and then Is_Hex (Raw (K + 4)) and then Is_Hex (Raw (K + 5))
         and then Dec_Code (Raw, K) in 16#20# .. 16#7E#
       then 6
       else 0))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K in Raw'Range,
        Post => (Dec_Step'Result = 0 or else Dec_Step'Result = 1 or else Dec_Step'Result = 2 or else Dec_Step'Result = 6)
                and then Dec_Step'Result <= Raw'Last - K + 1;

   --  Dec_Char: the character the (valid) token at K decodes to.
   function Dec_Char (Raw : String; K : Positive) return Character is
     ((if Raw (K) /= '\' then Raw (K)
       elsif Is_Simple_Escape (Raw (K + 1)) then Simple_Value (Raw (K + 1))
       else Character'Val (Dec_Code (Raw, K))))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K in Raw'Range
               and then Dec_Step (Raw, K) /= 0;

   --  Dec_Ok: every token from K to the end is valid.
   function Dec_Ok (Raw : String; K : Positive) return Boolean is
     ((if K > Raw'Last then True
       elsif Dec_Step (Raw, K) = 0 then False
       else Dec_Ok (Raw, K + Dec_Step (Raw, K))))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K - 1 <= Raw'Last,
        Subprogram_Variant => (Decreases => Raw'Last - K + 1);

   --  Dec_Len: how many characters the tokens from K decode to (up to the first invalid one).
   function Dec_Len (Raw : String; K : Positive) return Natural is
     ((if K > Raw'Last then 0
       elsif Dec_Step (Raw, K) = 0 then 0
       else 1 + Dec_Len (Raw, K + Dec_Step (Raw, K))))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K - 1 <= Raw'Last,
        Post => Dec_Len'Result <= Raw'Last - K + 1,
        Subprogram_Variant => (Decreases => Raw'Last - K + 1);

   --  Dec_Nth: the I-th character decoded from the tokens starting at K (' ' past the end).
   function Dec_Nth (Raw : String; K : Positive; I : Positive) return Character is
     ((if K > Raw'Last then ' '
       elsif Dec_Step (Raw, K) = 0 then ' '
       elsif I = 1 then Dec_Char (Raw, K)
       else Dec_Nth (Raw, K + Dec_Step (Raw, K), I - 1)))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K - 1 <= Raw'Last,
        Subprogram_Variant => (Decreases => I);

   --  THE ENCODE MODEL (lineage 3). Encode reads Input as UTF-8, one TOKEN at a time:
   --  an ASCII byte, or one whole well-formed multi-byte sequence. Utf8_Width says how
   --  many bytes the token at K takes (0: not well-formed UTF-8 there, and Encode
   --  refuses). A multi-byte token is copied unchanged; an ASCII byte is copied, or
   --  escaped as two characters, or escaped as six (backslash, u, 0, 0, two hex digits).

   DEL : constant Character := Character'Val (127);

   --  Is_Cont: a UTF-8 continuation byte, 16#80# .. 16#BF#.
   function Is_Cont (C : Character) return Boolean is
     (Character'Pos (C) in 16#80# .. 16#BF#);

   --  Cont_Low / Cont_High: the range of the byte after lead byte L. It is 16#80# .. 16#BF#
   --  except after E0 (A0 .. BF: no overlong), ED (80 .. 9F: no surrogate), F0 (90 .. BF:
   --  no overlong) and F4 (80 .. 8F: nothing above 16#10FFFF#).
   function Cont_Low (L : Character) return Natural is
     ((if Character'Pos (L) = 16#E0# then 16#A0#
       elsif Character'Pos (L) = 16#F0# then 16#90#
       else 16#80#));

   function Cont_High (L : Character) return Natural is
     ((if Character'Pos (L) = 16#ED# then 16#9F#
       elsif Character'Pos (L) = 16#F4# then 16#8F#
       else 16#BF#));

   --  Utf8_Width: bytes in the token at K: 1 for an ASCII byte, 2 .. 4 for a well-formed
   --  multi-byte sequence (RFC 3629), 0 for anything else (a stray continuation byte, C0,
   --  C1, F5 .. FF, an overlong, a surrogate, above 16#10FFFF#, or a truncated sequence).
   function Utf8_Width (Input : String; K : Positive) return Natural is
     ((if Character'Pos (Input (K)) < 16#80# then 1
       elsif Character'Pos (Input (K)) in 16#C2# .. 16#DF#
         and then K <= Input'Last - 1
         and then Is_Cont (Input (K + 1))
       then 2
       elsif Character'Pos (Input (K)) in 16#E0# .. 16#EF#
         and then K <= Input'Last - 2
         and then Character'Pos (Input (K + 1)) in Cont_Low (Input (K)) .. Cont_High (Input (K))
         and then Is_Cont (Input (K + 2))
       then 3
       elsif Character'Pos (Input (K)) in 16#F0# .. 16#F4#
         and then K <= Input'Last - 3
         and then Character'Pos (Input (K + 1)) in Cont_Low (Input (K)) .. Cont_High (Input (K))
         and then Is_Cont (Input (K + 2))
         and then Is_Cont (Input (K + 3))
       then 4
       else 0))
   with Pre => Input'First = 1 and then Input'Last in 0 .. Max_Raw and then K in Input'Range,
        Post => Utf8_Width'Result <= 4
                and then Utf8_Width'Result <= Input'Last - K + 1
                and then (Utf8_Width'Result = 1) = (Character'Pos (Input (K)) < 16#80#);

   --  Hex_Digit: the lower-case hex digit for V (encoding/json writes lower case).
   function Hex_Digit (V : Natural) return Character is
     ((if V < 10 then Character'Val (Character'Pos ('0') + V)
       else Character'Val (Character'Pos ('a') + V - 10)))
   with Pre => V <= 15,
        Post => Hex_Digit'Result in '0' .. '9' or else Hex_Digit'Result in 'a' .. 'f';

   --  Esc_Letter: the letter after the backslash when Encode escapes C in two characters.
   function Esc_Letter (C : Character) return Character is
     ((if C = LF then 'n' elsif C = HT then 't' elsif C = CR then 'r'
       elsif C = BS then 'b' elsif C = FF then 'f' else C))
   with Ghost;

   --  Enc_Width: how many characters Encode writes for the (well-formed) token at K.
   function Enc_Width (Input : String; K : Positive) return Positive is
     ((if Utf8_Width (Input, K) >= 2 then Utf8_Width (Input, K)
       elsif Is_Plain (Input (K)) or else Input (K) = DEL then 1
       elsif Input (K) = '"' or else Input (K) = '\' or else Input (K) = LF or else Input (K) = HT
         or else Input (K) = CR or else Input (K) = BS or else Input (K) = FF
       then 2
       else 6))
   with Ghost,
        Pre => Input'First = 1 and then Input'Last in 0 .. Max_Raw and then K in Input'Range
               and then Utf8_Width (Input, K) /= 0,
        Post => Enc_Width'Result <= 6 * Utf8_Width (Input, K);

   --  Enc_Char: the I-th character Encode writes for the (well-formed) token at K.
   function Enc_Char (Input : String; K : Positive; I : Positive) return Character is
     ((if Utf8_Width (Input, K) >= 2 then Input (K + I - 1)
       elsif Enc_Width (Input, K) = 1 then Input (K)
       elsif Enc_Width (Input, K) = 2 then (if I = 1 then '\' else Esc_Letter (Input (K)))
       elsif I = 1 then '\'
       elsif I = 2 then 'u'
       elsif I <= 4 then '0'
       elsif I = 5 then Hex_Digit (Character'Pos (Input (K)) / 16)
       else Hex_Digit (Character'Pos (Input (K)) mod 16)))
   with Ghost,
        Pre => Input'First = 1 and then Input'Last in 0 .. Max_Raw and then K in Input'Range
               and then Utf8_Width (Input, K) /= 0 and then I <= Enc_Width (Input, K);

   --  Utf8_Valid_From: Input (K .. Input'Last) is well-formed UTF-8.
   function Utf8_Valid_From (Input : String; K : Positive) return Boolean is
     ((if K > Input'Last then True
       elsif Utf8_Width (Input, K) = 0 then False
       else Utf8_Valid_From (Input, K + Utf8_Width (Input, K))))
   with Ghost,
        Pre => Input'First = 1 and then Input'Last in 0 .. Max_Raw and then K - 1 <= Input'Last,
        Subprogram_Variant => (Decreases => Input'Last - K + 1);

   --  Enc_Len: how many characters Encode writes for the tokens from K (up to the first
   --  ill-formed one).
   function Enc_Len (Input : String; K : Positive) return Natural is
     ((if K > Input'Last then 0
       elsif Utf8_Width (Input, K) = 0 then 0
       else Enc_Width (Input, K) + Enc_Len (Input, K + Utf8_Width (Input, K))))
   with Ghost,
        Pre => Input'First = 1 and then Input'Last in 0 .. Max_Raw and then K - 1 <= Input'Last,
        Post => Enc_Len'Result <= 6 * (Input'Last - K + 1),
        Subprogram_Variant => (Decreases => Input'Last - K + 1);

   --  Enc_Nth: the I-th character Encode writes for the tokens from K (' ' past the end).
   function Enc_Nth (Input : String; K : Positive; I : Positive) return Character is
     ((if K > Input'Last then ' '
       elsif Utf8_Width (Input, K) = 0 then ' '
       elsif I <= Enc_Width (Input, K) then Enc_Char (Input, K, I)
       else Enc_Nth (Input, K + Utf8_Width (Input, K), I - Enc_Width (Input, K))))
   with Ghost,
        Pre => Input'First = 1 and then Input'Last in 0 .. Max_Raw and then K - 1 <= Input'Last,
        Subprogram_Variant => (Decreases => I);

   procedure Decode (Raw : String; Output : out String; Output_Len : out Natural; Ok : out Boolean)
   with Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then Output'First = 1 and then Output'Length >= Raw'Length,
        Post => (if Ok then Output_Len <= Raw'Length and then (for all K in 1 .. Output_Len => Is_Output_Char (Output (K)))) and then (if (for all K in Raw'Range => Is_Plain (Raw (K))) then Ok and then Output_Len = Raw'Length and then (for all K in Raw'Range => Output (K) = Raw (K))) and then (if (for some K in Raw'Range => Raw (K) not in ' ' .. '~') then not Ok) and then (if Raw'Length >= 1 and then Raw (Raw'Last) = '\' and then (Raw'Length = 1 or else Raw (Raw'Last - 1) /= '\') then not Ok) and then (if Raw'Length = 2 and then Raw (1) = '\' and then Is_Simple_Escape (Raw (2)) then Ok and then Output_Len = 1 and then Output (1) = Simple_Value (Raw (2)))
                and then (Ok = Dec_Ok (Raw, 1))
                and then (if not Ok then Output_Len = 0)
                and then (if Ok then Output_Len = Dec_Len (Raw, 1))
                and then (if Ok then (for all I in 1 .. Output_Len => Output (I) = Dec_Nth (Raw, 1, I)));

   procedure Encode (Input : String; Output : out String; Output_Len : out Natural; Ok : out Boolean)
   with Pre => Input'First = 1 and then Input'Last in 0 .. Max_Raw and then Output'First = 1
               and then Output'Length >= 6 * Input'Length,
        Post => (if Ok then Output_Len <= 6 * Input'Length and then (for all K in 1 .. Output_Len => Output (K) >= ' '))
                and then (if (for all K in Input'Range => Is_Plain (Input (K))) then Ok and then Output_Len = Input'Length and then (for all K in Input'Range => Output (K) = Input (K)))
                and then (if (for all K in Input'Range => Is_Encodable (Input (K))) then Ok)
                and then (if Input'Length = 1 and then Input (1) = LF then Ok and then Output_Len = 2 and then Output (1) = '\' and then Output (2) = 'n')
                and then (Ok = Utf8_Valid_From (Input, 1))
                and then (if not Ok then Output_Len = 0)
                and then (if Ok then Output_Len = Enc_Len (Input, 1))
                and then (if Ok then (for all I in 1 .. Output_Len => Output (I) = Enc_Nth (Input, 1, I)));

   --  BODY: Decode's loop carries, besides its bound invariants,
   --  BODY:   Dec_Ok (Raw, 1) = Dec_Ok (Raw, K)  and  Dec_Len (Raw, 1) = N + Dec_Len (Raw, K),
   --  BODY:   (for all I in 1 .. N => Output (I) = Dec_Nth (Raw, 1, I)),
   --  BODY:   (for all J in 1 .. Raw'Last - K + 1 => Dec_Nth (Raw, 1, N + J) = Dec_Nth (Raw, K, J));
   --  BODY: Encode is a WHILE loop over tokens (W := Utf8_Width (Input, K); W = 0 refuses).
   --  BODY: It carries Utf8_Valid_From (Input, 1) = Utf8_Valid_From (Input, K),
   --  BODY: Enc_Len (Input, 1) = N + Enc_Len (Input, K) and the same two Nth invariants
   --  BODY: over Enc_Nth, with 6 * (Input'Last - K + 1) as the J bound. Each branch asserts
   --  BODY: Enc_Nth (Input, K, I) for every I it writes, and the shift
   --  BODY: Enc_Nth (K, J + width) = Enc_Nth (K + W, J) for every J, before it writes.

end Json_String_Pkg;
