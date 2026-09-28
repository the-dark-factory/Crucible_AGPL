--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 14def2917a83e1070564b789402c7168fe37bedcebaafbebbbfaf1b775b70108
--
package Lovelace_Grade_Line_Builder_Pkg with SPARK_Mode, Pure is

   Max_Name : constant := 4_096;

   subtype Grade_Value is Integer range -1 .. 2;

   Unexercised_Word  : constant String := "unexercised";
   Run_Time_Only_Word : constant String := "run-time-only";
   Theorem_Word      : constant String := "theorem";
   Refused_Word      : constant String := "refused";

   function No_Blank (S : String) return Boolean is
     ((for all K in S'Range => S (K) /= ' '));

   function Grade_Word (G : Integer) return String is
     (if G = 0 then Unexercised_Word
      elsif G = 1 then Run_Time_Only_Word
      elsif G = 2 then Theorem_Word
      else Refused_Word)
     with Post => Grade_Word'Result'Length >= 7
                  and then Grade_Word'Result'Length <= 13
                  and then No_Blank (Grade_Word'Result)
                  and then (if G < 0 or else G > 2 then Grade_Word'Result = Refused_Word);

   function Grade_Image (G : Grade_Value) return String is
     (if G = -1 then "-1" elsif G = 0 then "0" elsif G = 1 then "1" else "2")
     with Post => ((Grade_Image'Result'Length = 2) = (G = -1))
                  and then Grade_Image'Result'Length >= 1
                  and then No_Blank (Grade_Image'Result);

   function Grade_Line (Name : String; G : Grade_Value) return String is
     (Name & " " & Grade_Image (G) & " " & Grade_Word (G))
     with Pre  => Name'First = 1 and then Name'Length >= 1 and then Name'Length <= Max_Name,
          Post => Grade_Line'Result'First = 1
                  and then Grade_Line'Result'Length = Name'Length + 2 + Grade_Image (G)'Length + Grade_Word (G)'Length
                  and then Grade_Line'Result (1 .. Name'Length) = Name
                  and then Grade_Line'Result (Name'Length + 1) = ' ';

end Lovelace_Grade_Line_Builder_Pkg;
