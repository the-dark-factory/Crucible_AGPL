--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 18dd870cee8d94ed453c67b08e485914efc95f506c86391129ce1878bfaa898b
--
package Lovelace_Function_Table_Pkg with SPARK_Mode, Pure is

   Max_Entries : constant := 10_000;

   type Table_Phase is (Filling, Complete);

   type Entry_Lines is record
      Decl_Line : Natural := 0;
      Decl_End  : Natural := 0;
      Body_Line : Natural := 0;
      Body_End  : Natural := 0;
   end record;

   type Entry_Array is array (Positive range <>) of Entry_Lines;

   type Table_State is record
      Phase   : Table_Phase := Filling;
      Entries : Natural     := 0;
   end record;

   function Empty_Table return Table_State is
     ((Phase => Filling, Entries => 0))
     with Post => Empty_Table'Result.Phase = Filling and then Empty_Table'Result.Entries = 0;

   function Decl_Within (E : Entry_Lines; Total : Positive) return Boolean is
     (1 <= E.Decl_Line and then E.Decl_Line <= E.Decl_End and then E.Decl_End <= Total);

   function Body_Within (E : Entry_Lines; Total : Positive) return Boolean is
     ((E.Body_Line = 0 and then E.Body_End = 0)
      or else (1 <= E.Body_Line and then E.Body_Line <= E.Body_End and then E.Body_End <= Total));

   function Lines_Within (E : Entry_Lines; Total : Positive) return Boolean is
     (Decl_Within (E, Total) and then Body_Within (E, Total));

   function All_Within (Es : Entry_Array; Total : Positive) return Boolean is
     ((for all K in Es'Range => Lines_Within (Es (K), Total)));

   function Add_Entry (T : Table_State) return Table_State is
     ((Phase => Filling, Entries => T.Entries + 1))
     with Pre  => T.Phase = Filling and then T.Entries < Max_Entries,
          Post => Add_Entry'Result.Phase = Filling and then Add_Entry'Result.Entries = T.Entries + 1;

   function Seal (T : Table_State; Es : Entry_Array; Total : Positive) return Table_State is
     ((Phase => Complete, Entries => T.Entries))
     with Pre  => T.Phase = Filling and then Es'First = 1 and then Es'Length = T.Entries
                  and then T.Entries >= 1 and then All_Within (Es, Total),
          Post => Seal'Result.Phase = Complete and then Seal'Result.Entries = T.Entries;

   function May_Send_Parsed (T : Table_State) return Boolean is
     (T.Phase = Complete);

   function May_Read (T : Table_State) return Boolean is
     (T.Phase = Complete);

end Lovelace_Function_Table_Pkg;
