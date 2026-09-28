--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 079d426fd77cb37460741da13940e9d87b37267dc69084dc09506b0bba1f73b9
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

   --  THE DECODE MODEL (lineage 4). Decode reads Raw (the text between a JSON string's
   --  quotes) one TOKEN at a time and writes the UTF-8 bytes the token stands for:
   --    a byte 32 .. 127 other than '"' and '\'            -> itself (1 byte);
   --    a well-formed multi-byte UTF-8 sequence (Utf8_Width) -> itself (2 .. 4 bytes);
   --    a backslash and a simple escape letter               -> Simple_Value (1 byte);
   --    backslash, u, four hex digits, not a surrogate       -> that code point in UTF-8 (1 .. 3 bytes);
   --    a high surrogate escape (D800 .. DBFF) followed at once by a low surrogate escape
   --    (DC00 .. DFFF)                                        -> the pair's code point in UTF-8 (4 bytes).
   --  Anything else is REFUSED: a raw control character (below 32), a raw '"', ill-formed
   --  UTF-8, a lone, unpaired or misordered surrogate, an unknown or truncated escape.
   --  A token never writes more bytes than it reads, so the output fits in Raw'Length.

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

   --  Is_U_Esc: a backslash, 'u' and four hex digits start at K.
   function Is_U_Esc (Raw : String; K : Positive) return Boolean is
     (K <= Raw'Last - 5
      and then Raw (K) = '\' and then Raw (K + 1) = 'u'
      and then Is_Hex (Raw (K + 2)) and then Is_Hex (Raw (K + 3))
      and then Is_Hex (Raw (K + 4)) and then Is_Hex (Raw (K + 5)))
   with Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K in Raw'Range;

   --  U8_Len: how many bytes code point C takes in UTF-8.
   function U8_Len (C : Natural) return Positive is
     ((if C < 16#80# then 1 elsif C < 16#800# then 2 elsif C < 16#10000# then 3 else 4))
   with Pre => C <= 16#10FFFF#,
        Post => U8_Len'Result <= 4;

   --  U8_Byte: the I-th byte of code point C in UTF-8 (RFC 3629).
   function U8_Byte (C : Natural; I : Positive) return Natural is
     ((if C < 16#80# then C
       elsif C < 16#800# then
         (if I = 1 then 16#C0# + C / 64 else 16#80# + C mod 64)
       elsif C < 16#10000# then
         (if I = 1 then 16#E0# + C / 4096
          elsif I = 2 then 16#80# + (C / 64) mod 64
          else 16#80# + C mod 64)
       else
         (if I = 1 then 16#F0# + C / 262144
          elsif I = 2 then 16#80# + (C / 4096) mod 64
          elsif I = 3 then 16#80# + (C / 64) mod 64
          else 16#80# + C mod 64)))
   with Pre => C <= 16#10FFFF# and then I <= U8_Len (C),
        Post => U8_Byte'Result <= 255;

   --  U8_Sound: U8_Byte IS the UTF-8 encoding of C, checked independently of how it is
   --  computed. The lead byte has the form U8_Len (C) needs (never overlong), every
   --  other byte is a continuation byte, and the bytes decode back to C. Its Post says
   --  this holds for every C, so a wrong byte in U8_Byte leaves this Post unproved.
   function U8_Sound (C : Natural) return Boolean is
     ((if C < 16#80# then U8_Byte (C, 1) = C
       elsif C < 16#800# then
         U8_Byte (C, 1) in 16#C2# .. 16#DF# and then U8_Byte (C, 2) in 16#80# .. 16#BF#
         and then 64 * (U8_Byte (C, 1) - 16#C0#) + (U8_Byte (C, 2) - 16#80#) = C
       elsif C < 16#10000# then
         U8_Byte (C, 1) in 16#E0# .. 16#EF# and then U8_Byte (C, 2) in 16#80# .. 16#BF#
         and then U8_Byte (C, 3) in 16#80# .. 16#BF#
         and then 4096 * (U8_Byte (C, 1) - 16#E0#) + 64 * (U8_Byte (C, 2) - 16#80#)
                  + (U8_Byte (C, 3) - 16#80#) = C
       else
         U8_Byte (C, 1) in 16#F0# .. 16#F4# and then U8_Byte (C, 2) in 16#80# .. 16#BF#
         and then U8_Byte (C, 3) in 16#80# .. 16#BF# and then U8_Byte (C, 4) in 16#80# .. 16#BF#
         and then 262144 * (U8_Byte (C, 1) - 16#F0#) + 4096 * (U8_Byte (C, 2) - 16#80#)
                  + 64 * (U8_Byte (C, 3) - 16#80#) + (U8_Byte (C, 4) - 16#80#) = C))
   with Ghost,
        Pre => C <= 16#10FFFF#,
        Post => U8_Sound'Result;

   --  Dec_Step: how many characters of Raw the token at K takes (1 .. 4, 6 or 12); 0 means
   --  the token at K is invalid and Decode refuses.
   function Dec_Step (Raw : String; K : Positive) return Natural is
     ((if Raw (K) < ' ' or else Raw (K) = '"' then 0
       elsif Character'Pos (Raw (K)) >= 16#80# then Utf8_Width (Raw, K)
       elsif Raw (K) /= '\' then 1
       elsif K = Raw'Last then 0
       elsif Is_Simple_Escape (Raw (K + 1)) then 2
       elsif not Is_U_Esc (Raw, K) then 0
       elsif Dec_Code (Raw, K) in 16#DC00# .. 16#DFFF# then 0
       elsif Dec_Code (Raw, K) not in 16#D800# .. 16#DBFF# then 6
       elsif K + 6 <= Raw'Last and then Is_U_Esc (Raw, K + 6)
         and then Dec_Code (Raw, K + 6) in 16#DC00# .. 16#DFFF#
       then 12
       else 0))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K in Raw'Range,
        Post => Dec_Step'Result <= 12
                and then Dec_Step'Result <= Raw'Last - K + 1;

   --  Dec_Point: the code point of the escape token (6 or 12 characters) at K.
   function Dec_Point (Raw : String; K : Positive) return Natural is
     ((if Dec_Step (Raw, K) = 12
       then 16#10000# + 1024 * (Dec_Code (Raw, K) - 16#D800#) + (Dec_Code (Raw, K + 6) - 16#DC00#)
       else Dec_Code (Raw, K)))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K in Raw'Range
               and then Raw (K) = '\' and then Dec_Step (Raw, K) >= 6,
        Post => Dec_Point'Result <= 16#10FFFF#
                and then Dec_Point'Result not in 16#D800# .. 16#DFFF#
                and then (Dec_Point'Result >= 16#10000#) = (Dec_Step (Raw, K) = 12);

   --  Dec_Width: how many bytes Decode writes for the (valid) token at K.
   function Dec_Width (Raw : String; K : Positive) return Positive is
     ((if Raw (K) /= '\' then Dec_Step (Raw, K)
       elsif Dec_Step (Raw, K) = 2 then 1
       else U8_Len (Dec_Point (Raw, K))))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K in Raw'Range
               and then Dec_Step (Raw, K) /= 0,
        Post => Dec_Width'Result <= 4 and then Dec_Width'Result <= Dec_Step (Raw, K);

   --  Dec_Byte: the I-th byte Decode writes for the (valid) token at K.
   function Dec_Byte (Raw : String; K : Positive; I : Positive) return Character is
     ((if Raw (K) /= '\' then Raw (K + I - 1)
       elsif Dec_Step (Raw, K) = 2 then Simple_Value (Raw (K + 1))
       else Character'Val (U8_Byte (Dec_Point (Raw, K), I))))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K in Raw'Range
               and then Dec_Step (Raw, K) /= 0 and then I <= Dec_Width (Raw, K);

   --  Dec_Ok: every token from K to the end is valid.
   function Dec_Ok (Raw : String; K : Positive) return Boolean is
     ((if K > Raw'Last then True
       elsif Dec_Step (Raw, K) = 0 then False
       else Dec_Ok (Raw, K + Dec_Step (Raw, K))))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K - 1 <= Raw'Last,
        Subprogram_Variant => (Decreases => Raw'Last - K + 1);

   --  Dec_Len: how many bytes the tokens from K decode to (up to the first invalid one).
   function Dec_Len (Raw : String; K : Positive) return Natural is
     ((if K > Raw'Last then 0
       elsif Dec_Step (Raw, K) = 0 then 0
       else Dec_Width (Raw, K) + Dec_Len (Raw, K + Dec_Step (Raw, K))))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K - 1 <= Raw'Last,
        Post => Dec_Len'Result <= Raw'Last - K + 1,
        Subprogram_Variant => (Decreases => Raw'Last - K + 1);

   --  Dec_Nth: the I-th byte decoded from the tokens starting at K (' ' past the end).
   function Dec_Nth (Raw : String; K : Positive; I : Positive) return Character is
     ((if K > Raw'Last then ' '
       elsif Dec_Step (Raw, K) = 0 then ' '
       elsif I <= Dec_Width (Raw, K) then Dec_Byte (Raw, K, I)
       else Dec_Nth (Raw, K + Dec_Step (Raw, K), I - Dec_Width (Raw, K))))
   with Ghost,
        Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then K - 1 <= Raw'Last,
        Subprogram_Variant => (Decreases => I);

   procedure Decode (Raw : String; Output : out String; Output_Len : out Natural; Ok : out Boolean)
   with Pre => Raw'First = 1 and then Raw'Last in 0 .. Max_Raw and then Output'First = 1 and then Output'Length >= Raw'Length,
        Post => (if Ok then Output_Len <= Raw'Length)
                and then (if (for all K in Raw'Range => Is_Plain (Raw (K))) then Ok and then Output_Len = Raw'Length and then (for all K in Raw'Range => Output (K) = Raw (K)))
                and then (if (for some K in Raw'Range => Raw (K) < ' ') then not Ok)
                and then (if Raw'Length >= 1 and then Raw (Raw'Last) = '\' and then (Raw'Length = 1 or else Raw (Raw'Last - 1) /= '\') then not Ok)
                and then (if Raw'Length = 2 and then Raw (1) = '\' and then Is_Simple_Escape (Raw (2)) then Ok and then Output_Len = 1 and then Output (1) = Simple_Value (Raw (2)))
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

   --  BODY: Decode is a WHILE loop over tokens. Its loop carries, besides its bound invariants,
   --  BODY:   Dec_Ok (Raw, 1) = Dec_Ok (Raw, K)  and  Dec_Len (Raw, 1) = N + Dec_Len (Raw, K),
   --  BODY:   (for all I in 1 .. N => Output (I) = Dec_Nth (Raw, 1, I)),
   --  BODY:   (for all J in 1 .. Raw'Last - K + 1 => Dec_Nth (Raw, 1, N + J) = Dec_Nth (Raw, K, J));
   --  BODY: Each branch asserts Dec_Step and Dec_Width of the token, Dec_Nth (Raw, K, I) for
   --  BODY: every I it writes, and the shift Dec_Nth (K, J + width) = Dec_Nth (K + step, J).
   --  BODY: Encode is a WHILE loop over tokens (W := Utf8_Width (Input, K); W = 0 refuses).
   --  BODY: It carries Utf8_Valid_From (Input, 1) = Utf8_Valid_From (Input, K),
   --  BODY: Enc_Len (Input, 1) = N + Enc_Len (Input, K) and the same two Nth invariants
   --  BODY: over Enc_Nth, with 6 * (Input'Last - K + 1) as the J bound. Each branch asserts
   --  BODY: Enc_Nth (Input, K, I) for every I it writes, and the shift
   --  BODY: Enc_Nth (K, J + width) = Enc_Nth (K + W, J) for every J, before it writes.

end Json_String_Pkg;
