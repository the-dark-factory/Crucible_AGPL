--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1dcaab2c59606cbe21d54a99f231b0a9fa2e04e992a390a2b369edf972e2b9b4
--
package Lovelace_Raw_Spec_Pkg with SPARK_Mode, Pure is

   Max_Text : constant := 1_048_576;

   type Raw_Phase is (Empty, Written);

   type Raw_Pool is record
      Phase  : Raw_Phase := Empty;
      Length : Natural   := 0;
   end record;

   function Empty_Pool return Raw_Pool is
     ((Phase => Empty, Length => 0))
     with Post => Empty_Pool'Result.Phase = Empty;

   function Write_Raw (P : Raw_Pool; Length : Natural) return Raw_Pool is
     ((Phase => Written, Length => Length))
     with Pre  => P.Phase = Empty and then Length <= Max_Text,
          Post => Write_Raw'Result.Phase = Written and then Write_Raw'Result.Length = Length;

   function May_Send_Ready (P : Raw_Pool) return Boolean is
     (P.Phase = Written);

   function May_Read (P : Raw_Pool) return Boolean is
     (P.Phase = Written);

   function May_Write (P : Raw_Pool) return Boolean is
     (P.Phase = Empty);

end Lovelace_Raw_Spec_Pkg;
