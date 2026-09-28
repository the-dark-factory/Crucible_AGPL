--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: e89a1d66026038f8815922b47d66cf5fa46d83bcb121233f2d31965542821ae4
--
package Lovelace_Utf8_Decode_Pkg with SPARK_Mode, Pure is

   Max_Text : constant := 1_048_576;

   subtype Rune_Width is Natural range 0 .. 4;
   subtype Rune is Natural range 0 .. 16#10FFFF#;

   function Byte (C : Character) return Natural is
     (Character'Pos (C))
     with Post => Byte'Result <= 255;

   function Is_Cont (C : Character) return Boolean is
     (Byte (C) >= 16#80# and then Byte (C) <= 16#BF#);

   function Lead_Width (C : Character) return Rune_Width is
     (if Byte (C) < 16#80# then 1
      elsif Byte (C) < 16#C2# then 0
      elsif Byte (C) < 16#E0# then 2
      elsif Byte (C) < 16#F0# then 3
      elsif Byte (C) < 16#F5# then 4
      else 0)
     with Post => ((Lead_Width'Result = 1) = (Byte (C) < 16#80#));

   function Second_Ok (Lead : Character; C : Character) return Boolean is
     (if Byte (Lead) = 16#E0# then (Byte (C) >= 16#A0# and then Byte (C) <= 16#BF#)
      elsif Byte (Lead) = 16#ED# then (Byte (C) >= 16#80# and then Byte (C) <= 16#9F#)
      elsif Byte (Lead) = 16#F0# then (Byte (C) >= 16#90# and then Byte (C) <= 16#BF#)
      elsif Byte (Lead) = 16#F4# then (Byte (C) >= 16#80# and then Byte (C) <= 16#8F#)
      else Is_Cont (C));

   function Width_At (Text : String; I : Positive) return Rune_Width is
     (if Lead_Width (Text (I)) <= 1 then Lead_Width (Text (I))
      elsif Lead_Width (Text (I)) > Text'Length - I + 1 then 0
      elsif not Second_Ok (Text (I), Text (I + 1)) then 0
      elsif Lead_Width (Text (I)) >= 3 and then not Is_Cont (Text (I + 2)) then 0
      elsif Lead_Width (Text (I)) = 4 and then not Is_Cont (Text (I + 3)) then 0
      else Lead_Width (Text (I)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length,
          Post => Width_At'Result <= Text'Length - I + 1
                  and then ((Width_At'Result = 1) = (Byte (Text (I)) < 16#80#));

   function Payload (C : Character) return Natural is
     (Byte (C) mod 64)
     with Post => Payload'Result <= 63;

   function Rune_At (Text : String; I : Positive) return Rune is
     (if Width_At (Text, I) <= 1 then Byte (Text (I)) mod 128
      elsif Width_At (Text, I) = 2 then (Byte (Text (I)) mod 32) * 64 + Payload (Text (I + 1))
      elsif Width_At (Text, I) = 3 then
        (Byte (Text (I)) mod 16) * 4096 + Payload (Text (I + 1)) * 64 + Payload (Text (I + 2))
      else Natural'Min ((Byte (Text (I)) mod 8) * 262144 + Payload (Text (I + 1)) * 4096
                        + Payload (Text (I + 2)) * 64 + Payload (Text (I + 3)), 16#10FFFF#))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length
                  and then Width_At (Text, I) >= 1,
          Post => (if Width_At (Text, I) = 1 then Rune_At'Result = Byte (Text (I)));

end Lovelace_Utf8_Decode_Pkg;
