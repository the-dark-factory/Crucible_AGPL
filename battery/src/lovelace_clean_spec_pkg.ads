--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 3622e93f6d83b79cc6fba4baa4e01ff487729d8c86ac0faa7c08ec8a23ddad72
--
with Lovelace_Lex_Rules_Pkg;
use Lovelace_Lex_Rules_Pkg;
with Lovelace_Comment_Stripper_Pkg;
use Lovelace_Comment_Stripper_Pkg;

package Lovelace_Clean_Spec_Pkg with SPARK_Mode, Pure is

   type Clean_Phase is (Empty, Written);

   type Clean_Pool is record
      Phase     : Clean_Phase := Empty;
      Raw_Lines : Positive    := 1;
      Lines     : Natural     := 0;
   end record;

   function Pool_For (Raw : String) return Clean_Pool is
     ((Phase => Empty, Raw_Lines => Line_Count (Raw), Lines => 0))
     with Pre  => Raw'First = 1 and then Raw'Length <= Max_Text,
          Post => Pool_For'Result.Phase = Empty and then Pool_For'Result.Raw_Lines = Line_Count (Raw);

   function Keeps_Lines (P : Clean_Pool; Clean : String) return Boolean is
     (Line_Count (Clean) = P.Raw_Lines)
     with Pre => Clean'First = 1 and then Clean'Length <= Max_Text;

   function Write_Clean (P : Clean_Pool; Clean : String) return Clean_Pool is
     ((Phase => Written, Raw_Lines => P.Raw_Lines, Lines => Line_Count (Clean)))
     with Pre  => P.Phase = Empty and then Clean'First = 1 and then Clean'Length <= Max_Text
                  and then Keeps_Lines (P, Clean),
          Post => Write_Clean'Result.Phase = Written
                  and then Write_Clean'Result.Lines = Write_Clean'Result.Raw_Lines
                  and then Write_Clean'Result.Raw_Lines = P.Raw_Lines;

   function May_Send_Ready (P : Clean_Pool) return Boolean is
     (P.Phase = Written);

   function May_Read (P : Clean_Pool) return Boolean is
     (P.Phase = Written);

end Lovelace_Clean_Spec_Pkg;
