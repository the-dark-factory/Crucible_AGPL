--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 074ccf1a71e503820db03436711a35d13d3c3517baf3121d7128759d12313bae
--
package Lovelace_Go_Print_16_Pkg with SPARK_Mode, Pure is

   type Code_Table is array (Positive range <>) of Natural;

   Print_16 : constant Code_Table := (
     16#0020#, 16#007E#, 16#00A1#, 16#0377#, 16#037A#, 16#037F#, 16#0384#, 16#0556#,
     16#0559#, 16#058A#, 16#058D#, 16#05C7#, 16#05D0#, 16#05EA#, 16#05EF#, 16#05F4#,
     16#0606#, 16#070D#, 16#0710#, 16#074A#, 16#074D#, 16#07B1#, 16#07C0#, 16#07FA#,
     16#07FD#, 16#082D#, 16#0830#, 16#085B#, 16#085E#, 16#086A#, 16#0870#, 16#088E#,
     16#0898#, 16#098C#, 16#098F#, 16#0990#, 16#0993#, 16#09B2#, 16#09B6#, 16#09B9#,
     16#09BC#, 16#09C4#, 16#09C7#, 16#09C8#, 16#09CB#, 16#09CE#, 16#09D7#, 16#09D7#,
     16#09DC#, 16#09E3#, 16#09E6#, 16#09FE#, 16#0A01#, 16#0A0A#, 16#0A0F#, 16#0A10#,
     16#0A13#, 16#0A39#, 16#0A3C#, 16#0A42#, 16#0A47#, 16#0A48#, 16#0A4B#, 16#0A4D#,
     16#0A51#, 16#0A51#, 16#0A59#, 16#0A5E#, 16#0A66#, 16#0A76#, 16#0A81#, 16#0AB9#,
     16#0ABC#, 16#0ACD#, 16#0AD0#, 16#0AD0#, 16#0AE0#, 16#0AE3#, 16#0AE6#, 16#0AF1#,
     16#0AF9#, 16#0B0C#, 16#0B0F#, 16#0B10#, 16#0B13#, 16#0B39#, 16#0B3C#, 16#0B44#,
     16#0B47#, 16#0B48#, 16#0B4B#, 16#0B4D#, 16#0B55#, 16#0B57#, 16#0B5C#, 16#0B63#,
     16#0B66#, 16#0B77#, 16#0B82#, 16#0B8A#, 16#0B8E#, 16#0B95#, 16#0B99#, 16#0B9F#,
     16#0BA3#, 16#0BA4#, 16#0BA8#, 16#0BAA#, 16#0BAE#, 16#0BB9#, 16#0BBE#, 16#0BC2#,
     16#0BC6#, 16#0BCD#, 16#0BD0#, 16#0BD0#, 16#0BD7#, 16#0BD7#, 16#0BE6#, 16#0BFA#,
     16#0C00#, 16#0C39#, 16#0C3C#, 16#0C4D#, 16#0C55#, 16#0C5A#, 16#0C5D#, 16#0C5D#,
     16#0C60#, 16#0C63#, 16#0C66#, 16#0C6F#, 16#0C77#, 16#0CB9#, 16#0CBC#, 16#0CCD#,
     16#0CD5#, 16#0CD6#, 16#0CDD#, 16#0CE3#, 16#0CE6#, 16#0CF3#, 16#0D00#, 16#0D4F#,
     16#0D54#, 16#0D63#, 16#0D66#, 16#0D96#, 16#0D9A#, 16#0DBD#, 16#0DC0#, 16#0DC6#,
     16#0DCA#, 16#0DCA#, 16#0DCF#, 16#0DDF#, 16#0DE6#, 16#0DEF#, 16#0DF2#, 16#0DF4#,
     16#0E01#, 16#0E3A#, 16#0E3F#, 16#0E5B#, 16#0E81#, 16#0EBD#, 16#0EC0#, 16#0ED9#,
     16#0EDC#, 16#0EDF#, 16#0F00#, 16#0F6C#, 16#0F71#, 16#0FDA#, 16#1000#, 16#10C7#,
     16#10CD#, 16#10CD#, 16#10D0#, 16#124D#, 16#1250#, 16#125D#, 16#1260#, 16#128D#,
     16#1290#, 16#12B5#, 16#12B8#, 16#12C5#, 16#12C8#, 16#1315#, 16#1318#, 16#135A#,
     16#135D#, 16#137C#, 16#1380#, 16#1399#, 16#13A0#, 16#13F5#, 16#13F8#, 16#13FD#,
     16#1400#, 16#169C#, 16#16A0#, 16#16F8#, 16#1700#, 16#1715#, 16#171F#, 16#1736#,
     16#1740#, 16#1753#, 16#1760#, 16#1773#, 16#1780#, 16#17DD#, 16#17E0#, 16#17E9#,
     16#17F0#, 16#17F9#, 16#1800#, 16#1819#, 16#1820#, 16#1878#, 16#1880#, 16#18AA#,
     16#18B0#, 16#18F5#, 16#1900#, 16#192B#, 16#1930#, 16#193B#, 16#1940#, 16#1940#,
     16#1944#, 16#196D#, 16#1970#, 16#1974#, 16#1980#, 16#19AB#, 16#19B0#, 16#19C9#,
     16#19D0#, 16#19DA#, 16#19DE#, 16#1A1B#, 16#1A1E#, 16#1A7C#, 16#1A7F#, 16#1A89#,
     16#1A90#, 16#1A99#, 16#1AA0#, 16#1AAD#, 16#1AB0#, 16#1ACE#, 16#1B00#, 16#1B4C#,
     16#1B50#, 16#1BF3#, 16#1BFC#, 16#1C37#, 16#1C3B#, 16#1C49#, 16#1C4D#, 16#1C88#,
     16#1C90#, 16#1CBA#, 16#1CBD#, 16#1CC7#, 16#1CD0#, 16#1CFA#, 16#1D00#, 16#1F15#,
     16#1F18#, 16#1F1D#, 16#1F20#, 16#1F45#, 16#1F48#, 16#1F4D#, 16#1F50#, 16#1F7D#,
     16#1F80#, 16#1FD3#, 16#1FD6#, 16#1FEF#, 16#1FF2#, 16#1FFE#, 16#2010#, 16#2027#,
     16#2030#, 16#205E#, 16#2070#, 16#2071#, 16#2074#, 16#209C#, 16#20A0#, 16#20C0#,
     16#20D0#, 16#20F0#, 16#2100#, 16#218B#, 16#2190#, 16#2426#, 16#2440#, 16#244A#,
     16#2460#, 16#2B73#, 16#2B76#, 16#2CF3#, 16#2CF9#, 16#2D27#, 16#2D2D#, 16#2D2D#,
     16#2D30#, 16#2D67#, 16#2D6F#, 16#2D70#, 16#2D7F#, 16#2D96#, 16#2DA0#, 16#2E5D#,
     16#2E80#, 16#2EF3#, 16#2F00#, 16#2FD5#, 16#2FF0#, 16#2FFB#, 16#3001#, 16#3096#,
     16#3099#, 16#30FF#, 16#3105#, 16#31E3#, 16#31F0#, 16#A48C#, 16#A490#, 16#A4C6#,
     16#A4D0#, 16#A62B#, 16#A640#, 16#A6F7#, 16#A700#, 16#A7CA#, 16#A7D0#, 16#A7D9#,
     16#A7F2#, 16#A82C#, 16#A830#, 16#A839#, 16#A840#, 16#A877#, 16#A880#, 16#A8C5#,
     16#A8CE#, 16#A8D9#, 16#A8E0#, 16#A953#, 16#A95F#, 16#A97C#, 16#A980#, 16#A9D9#,
     16#A9DE#, 16#AA36#, 16#AA40#, 16#AA4D#, 16#AA50#, 16#AA59#, 16#AA5C#, 16#AAC2#,
     16#AADB#, 16#AAF6#, 16#AB01#, 16#AB06#, 16#AB09#, 16#AB0E#, 16#AB11#, 16#AB16#,
     16#AB20#, 16#AB6B#, 16#AB70#, 16#ABED#, 16#ABF0#, 16#ABF9#, 16#AC00#, 16#D7A3#,
     16#D7B0#, 16#D7C6#, 16#D7CB#, 16#D7FB#, 16#F900#, 16#FA6D#, 16#FA70#, 16#FAD9#,
     16#FB00#, 16#FB06#, 16#FB13#, 16#FB17#, 16#FB1D#, 16#FBC2#, 16#FBD3#, 16#FD8F#,
     16#FD92#, 16#FDC7#, 16#FDCF#, 16#FDCF#, 16#FDF0#, 16#FE19#, 16#FE20#, 16#FE6B#,
     16#FE70#, 16#FEFC#, 16#FF01#, 16#FFBE#, 16#FFC2#, 16#FFC7#, 16#FFCA#, 16#FFCF#,
     16#FFD2#, 16#FFD7#, 16#FFDA#, 16#FFDC#, 16#FFE0#, 16#FFEE#, 16#FFFC#, 16#FFFD#);

   Not_Print_16 : constant Code_Table := (
     16#00AD#, 16#038B#, 16#038D#, 16#03A2#, 16#0530#, 16#0590#, 16#061C#, 16#06DD#,
     16#083F#, 16#085F#, 16#08E2#, 16#0984#, 16#09A9#, 16#09B1#, 16#09DE#, 16#0A04#,
     16#0A29#, 16#0A31#, 16#0A34#, 16#0A37#, 16#0A3D#, 16#0A5D#, 16#0A84#, 16#0A8E#,
     16#0A92#, 16#0AA9#, 16#0AB1#, 16#0AB4#, 16#0AC6#, 16#0ACA#, 16#0B00#, 16#0B04#,
     16#0B29#, 16#0B31#, 16#0B34#, 16#0B5E#, 16#0B84#, 16#0B91#, 16#0B9B#, 16#0B9D#,
     16#0BC9#, 16#0C0D#, 16#0C11#, 16#0C29#, 16#0C45#, 16#0C49#, 16#0C57#, 16#0C8D#,
     16#0C91#, 16#0CA9#, 16#0CB4#, 16#0CC5#, 16#0CC9#, 16#0CDF#, 16#0CF0#, 16#0D0D#,
     16#0D11#, 16#0D45#, 16#0D49#, 16#0D80#, 16#0D84#, 16#0DB2#, 16#0DBC#, 16#0DD5#,
     16#0DD7#, 16#0E83#, 16#0E85#, 16#0E8B#, 16#0EA4#, 16#0EA6#, 16#0EC5#, 16#0EC7#,
     16#0ECF#, 16#0F48#, 16#0F98#, 16#0FBD#, 16#0FCD#, 16#10C6#, 16#1249#, 16#1257#,
     16#1259#, 16#1289#, 16#12B1#, 16#12BF#, 16#12C1#, 16#12D7#, 16#1311#, 16#1680#,
     16#176D#, 16#1771#, 16#180E#, 16#191F#, 16#1A5F#, 16#1B7F#, 16#1F58#, 16#1F5A#,
     16#1F5C#, 16#1F5E#, 16#1FB5#, 16#1FC5#, 16#1FDC#, 16#1FF5#, 16#208F#, 16#2B96#,
     16#2D26#, 16#2DA7#, 16#2DAF#, 16#2DB7#, 16#2DBF#, 16#2DC7#, 16#2DCF#, 16#2DD7#,
     16#2DDF#, 16#2E9A#, 16#3040#, 16#3130#, 16#318F#, 16#321F#, 16#A7D2#, 16#A7D4#,
     16#A9CE#, 16#A9FF#, 16#AB27#, 16#AB2F#, 16#FB37#, 16#FB3D#, 16#FB3F#, 16#FB42#,
     16#FB45#, 16#FE53#, 16#FE67#, 16#FE75#, 16#FFE7#);

   function First_At_Least (T : Code_Table; X : Natural; I : Positive) return Positive is
     (if I > T'Last then I
      elsif T (I) >= X then I
      else First_At_Least (T, X, I + 1))
     with Pre  => T'First = 1 and then T'Last < Positive'Last and then I <= T'Last + 1,
          Post => First_At_Least'Result >= I and then First_At_Least'Result <= T'Last + 1,
          Subprogram_Variant => (Decreases => T'Last - I + 1);

   function Pair_Start (I : Positive) return Positive is
     (if I mod 2 = 1 then I else I - 1)
     with Post => Pair_Start'Result <= I and then Pair_Start'Result mod 2 = 1;

   function In_Pairs (T : Code_Table; X : Natural) return Boolean is
     (First_At_Least (T, X, 1) <= T'Last
      and then Pair_Start (First_At_Least (T, X, 1)) + 1 <= T'Last
      and then T (Pair_Start (First_At_Least (T, X, 1))) <= X
      and then X <= T (Pair_Start (First_At_Least (T, X, 1)) + 1))
     with Pre => T'First = 1 and then T'Length >= 1 and then T'Last < Positive'Last;

   function In_List (T : Code_Table; X : Natural) return Boolean is
     ((for some K in T'Range => T (K) = X));

   function Is_Print_16 (R : Natural) return Boolean is
     (In_Pairs (Print_16, R) and then not In_List (Not_Print_16, R))
     with Pre => R <= 16#FFFF#;

end Lovelace_Go_Print_16_Pkg;
