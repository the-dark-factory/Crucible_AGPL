--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 8f61c03dbe3ce21c46d7dfdc7cd16f6d5447967cd1625efeaf89e773515b2266
--
package Lovelace_Base_Run_Pkg with SPARK_Mode, Pure is

   type Base_Phase is (Empty, Written);

   type Base_Pool is record
      Phase    : Base_Phase := Empty;
      Reached  : Boolean    := False;
      Faulted  : Boolean    := False;
      Messages : Natural    := 0;
   end record;

   function Empty_Pool return Base_Pool is
     ((Phase => Empty, Reached => False, Faulted => False, Messages => 0))
     with Post => Empty_Pool'Result.Phase = Empty and then not Empty_Pool'Result.Reached;

   function Write_Base (P : Base_Pool; Reached : Boolean; Faulted : Boolean; Messages : Natural) return Base_Pool is
     ((Phase => Written, Reached => Reached, Faulted => Faulted, Messages => Messages))
     with Pre  => P.Phase = Empty and then not (Reached and then Faulted),
          Post => Write_Base'Result.Phase = Written
                  and then Write_Base'Result.Reached = Reached
                  and then Write_Base'Result.Faulted = Faulted
                  and then Write_Base'Result.Messages = Messages
                  and then not (Write_Base'Result.Reached and then Write_Base'Result.Faulted);

   function May_Send_Done (P : Base_Pool) return Boolean is
     (P.Phase = Written);

   function May_Read (P : Base_Pool) return Boolean is
     (P.Phase = Written);

end Lovelace_Base_Run_Pkg;
