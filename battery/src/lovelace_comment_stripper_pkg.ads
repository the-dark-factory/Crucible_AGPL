--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: ac927c1537c2a5e2bb9c8a5f4959598cae9f8d71a1dad40203981b091212b7e1
--
with Lovelace_Lex_Rules_Pkg;
use Lovelace_Lex_Rules_Pkg;

package Lovelace_Comment_Stripper_Pkg with SPARK_Mode, Pure is

   function Comment_At (Line : String; Mask : Mask_Array; K : Positive) return Boolean is
     (K < Line'Length
      and then Mask (K) = Code
      and then Line (K) = '-'
      and then Line (K + 1) = '-')
     with Pre => Line'First = 1 and then Line'Length <= Max_Text
                 and then Mask'First = 1 and then Mask'Last = Line'Last;

   function No_Comment_Between (Line : String; Mask : Mask_Array; From : Positive; To : Natural) return Boolean is
     ((for all J in From .. To => not Comment_At (Line, Mask, J)))
     with Pre => Line'First = 1 and then Line'Length <= Max_Text
                 and then Mask'First = 1 and then Mask'Last = Line'Last and then To <= Line'Length;

   function Cut_From (Line : String; Mask : Mask_Array; K : Positive) return Natural is
     (if K >= Line'Length then 0
      elsif Comment_At (Line, Mask, K) then K
      else Cut_From (Line, Mask, K + 1))
     with Pre  => Line'First = 1 and then Line'Length <= Max_Text
                  and then Mask'First = 1 and then Mask'Last = Line'Last
                  and then K <= Line'Length + 1,
          Post => (if Cut_From'Result = 0 then No_Comment_Between (Line, Mask, K, Line'Length)
                   else (Cut_From'Result >= K and then Comment_At (Line, Mask, Cut_From'Result)
                         and then No_Comment_Between (Line, Mask, K, Cut_From'Result - 1))),
          Subprogram_Variant => (Decreases => Line'Length - K + 1);

   function Kept_Last (Line : String; Mask : Mask_Array) return Natural is
     (if Cut_From (Line, Mask, 1) = 0 then Line'Length else Cut_From (Line, Mask, 1) - 1)
     with Pre  => Line'First = 1 and then Line'Length <= Max_Text
                  and then Mask'First = 1 and then Mask'Last = Line'Last,
          Post => Kept_Last'Result <= Line'Length
                  and then No_Comment_Between (Line, Mask, 1, Kept_Last'Result)
                  and then (if Kept_Last'Result < Line'Length then Comment_At (Line, Mask, Kept_Last'Result + 1));

   function No_LF_Between (Text : String; From : Positive; To : Natural) return Boolean is
     ((for all K in From .. To => Text (K) /= LF))
     with Pre => Text'First = 1 and then To <= Text'Length;

   function Line_End (Text : String; From : Positive) return Natural is
     (if From > Text'Length then Text'Length
      elsif Text (From) = LF then From - 1
      else Line_End (Text, From + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then From <= Text'Length + 1,
          Post => Line_End'Result >= From - 1 and then Line_End'Result <= Text'Length
                  and then No_LF_Between (Text, From, Line_End'Result)
                  and then (Line_End'Result = Text'Length or else Text (Line_End'Result + 1) = LF),
          Subprogram_Variant => (Decreases => Text'Length - From + 1);

   function Line_Count_From (Text : String; From : Positive) return Positive is
     (if Line_End (Text, From) = Text'Length then 1
      else 1 + Line_Count_From (Text, Line_End (Text, From) + 2))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then From <= Text'Length + 1,
          Post => Line_Count_From'Result <= Text'Length - From + 2,
          Subprogram_Variant => (Decreases => Text'Length - From + 1);

   function Line_Count (Text : String) return Positive is
     (Line_Count_From (Text, 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text,
          Post => Line_Count'Result <= Text'Length + 1;

end Lovelace_Comment_Stripper_Pkg;
