--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 235758d40933334d78b3b8a98b8a06e602b553ec65b539b6e92aaaa1ff3f16cf
--
with Lovelace_Lex_Rules_Pkg;
use Lovelace_Lex_Rules_Pkg;
with Lovelace_Text_Rules_Pkg;
use Lovelace_Text_Rules_Pkg;

package Lovelace_Aspect_Reader_Pkg with SPARK_Mode, Pure is

   Pre_Key  : constant String := "pre";
   Post_Key : constant String := "post";

   function Usable (Text : String; P : Piece) return Boolean is
     (P.First <= P.Last and then P.Last <= Text'Length)
     with Pre => Text'First = 1 and then Text'Length <= Max_Text;

   function Arrow_In (Text : String; First : Positive; Last : Natural) return Natural is
     (if First >= Last then 0
      elsif Text (First) = '=' and then Text (First + 1) = '>' then First
      else Arrow_In (Text, First + 1, Last))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then First <= Last + 1,
          Post => Arrow_In'Result = 0
                  or else (Arrow_In'Result >= First and then Arrow_In'Result < Last
                           and then Text (Arrow_In'Result) = '=' and then Text (Arrow_In'Result + 1) = '>'),
          Subprogram_Variant => (Decreases => Last - First + 1);

   function Key_First (Text : String; First : Positive; Arrow : Positive) return Positive is
     (First_Non_Trim (Text, First, Arrow - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Arrow <= Text'Length
                  and then First <= Arrow,
          Post => Key_First'Result >= First and then Key_First'Result <= Arrow;

   function Key_Last (Text : String; First : Positive; Arrow : Positive) return Natural is
     (Last_Non_Trim (Text, Key_First (Text, First, Arrow), Arrow - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Arrow <= Text'Length
                  and then First <= Arrow,
          Post => Key_Last'Result >= Key_First (Text, First, Arrow) - 1 and then Key_Last'Result <= Arrow - 1;

   function Key_Is (Text : String; First : Positive; Arrow : Positive; Key : String) return Boolean is
     (Equal_Ignoring_Case (Text (Key_First (Text, First, Arrow) .. Key_Last (Text, First, Arrow)), Key))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Arrow <= Text'Length
                 and then First <= Arrow and then Key'First = 1 and then Key'Length <= 64;

   function Piece_Arrow (Text : String; P : Piece) return Natural is
     (Arrow_In (Text, P.First, P.Last))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Usable (Text, P),
          Post => Piece_Arrow'Result = 0
                  or else (Piece_Arrow'Result >= P.First and then Piece_Arrow'Result < P.Last);

   function Piece_Keyed (Text : String; P : Piece; Key : String) return Boolean is
     (Usable (Text, P)
      and then Piece_Arrow (Text, P) > 0
      and then Key_Is (Text, P.First, Piece_Arrow (Text, P), Key))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text
                 and then Key'First = 1 and then Key'Length <= 64;

   function Aspect_Piece (Text : String; Mask : Mask_Array; N : Positive) return Piece is
     (Piece_Bounds (Text, Mask, ',', N))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last,
          Post => Aspect_Piece'Result.Raw_Last <= Text'Length;

   function Last_Keyed (Text : String; Mask : Mask_Array; Key : String; N : Natural) return Natural is
     (if N = 0 then 0
      elsif Piece_Keyed (Text, Aspect_Piece (Text, Mask, N), Key) then N
      else Last_Keyed (Text, Mask, Key, N - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then Key'First = 1 and then Key'Length <= 64,
          Post => Last_Keyed'Result <= N
                  and then (if Last_Keyed'Result > 0 then
                              Piece_Keyed (Text, Aspect_Piece (Text, Mask, Last_Keyed'Result), Key)),
          Subprogram_Variant => (Decreases => N);

   function Pre_Index (Text : String; Mask : Mask_Array) return Natural is
     (Last_Keyed (Text, Mask, Pre_Key, Piece_Count (Text, Mask, ',')))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last,
          Post => Pre_Index'Result <= Piece_Count (Text, Mask, ',')
                  and then (if Pre_Index'Result > 0 then
                              Piece_Keyed (Text, Aspect_Piece (Text, Mask, Pre_Index'Result), Pre_Key));

   function Post_Index (Text : String; Mask : Mask_Array) return Natural is
     (Last_Keyed (Text, Mask, Post_Key, Piece_Count (Text, Mask, ',')))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last,
          Post => Post_Index'Result <= Piece_Count (Text, Mask, ',')
                  and then (if Post_Index'Result > 0 then
                              Piece_Keyed (Text, Aspect_Piece (Text, Mask, Post_Index'Result), Post_Key));

   function Value_Of (Text : String; P : Piece) return Piece is
     (Trim (Text, Piece_Arrow (Text, P) + 2, P.Last))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Usable (Text, P)
                  and then Piece_Arrow (Text, P) > 0,
          Post => Value_Of'Result.Raw_Last = P.Last
                  and then Value_Of'Result.Raw_First = Piece_Arrow (Text, P) + 2;

   function Usable_Count (Text : String; Mask : Mask_Array; N : Natural) return Natural is
     (if N = 0 then 0
      elsif Usable (Text, Aspect_Piece (Text, Mask, N)) then Usable_Count (Text, Mask, N - 1) + 1
      else Usable_Count (Text, Mask, N - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then N <= Text'Length + 1,
          Post => Usable_Count'Result <= N,
          Subprogram_Variant => (Decreases => N);

   function Aspect_Count (Text : String; Mask : Mask_Array) return Natural is
     (Usable_Count (Text, Mask, Piece_Count (Text, Mask, ',')))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last,
          Post => Aspect_Count'Result <= Piece_Count (Text, Mask, ',');

   function Nth_Usable_From (Text : String; Mask : Mask_Array; J : Positive; Total : Natural; N : Positive) return Natural is
     (if J > Total then 0
      elsif not Usable (Text, Aspect_Piece (Text, Mask, J)) then Nth_Usable_From (Text, Mask, J + 1, Total, N)
      elsif N = 1 then J
      else Nth_Usable_From (Text, Mask, J + 1, Total, N - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then Total <= Text'Length + 1 and then J <= Total + 1,
          Post => Nth_Usable_From'Result = 0
                  or else (Nth_Usable_From'Result >= J and then Nth_Usable_From'Result <= Total
                           and then Usable (Text, Aspect_Piece (Text, Mask, Nth_Usable_From'Result))),
          Subprogram_Variant => (Decreases => Total - J + 1);

   function Nth_Aspect (Text : String; Mask : Mask_Array; N : Positive) return Natural is
     (Nth_Usable_From (Text, Mask, 1, Piece_Count (Text, Mask, ','), N))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last,
          Post => Nth_Aspect'Result = 0
                  or else Usable (Text, Aspect_Piece (Text, Mask, Nth_Aspect'Result));

end Lovelace_Aspect_Reader_Pkg;
