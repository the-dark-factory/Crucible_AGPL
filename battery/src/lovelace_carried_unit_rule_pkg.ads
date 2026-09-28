--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 85e56678c2b9d74c373842a5801a2e6e0ddb0cad0c8509ae64f0df4cf6387d92
--
package Lovelace_Carried_Unit_Rule_Pkg with SPARK_Mode, Pure is

   Max_Name : constant := 4_096;

   Ads_Ext : constant String := ".ads";
   Adb_Ext : constant String := ".adb";

   function Lower (C : Character) return Character is
     ((if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C))
     with Post => (if C not in 'A' .. 'Z' then Lower'Result = C);

   function Same_Fold (A : String; B : String) return Boolean is
     (A'Length = B'Length
      and then (for all K in 1 .. A'Length => Lower (A (K)) = Lower (B (K))))
     with Pre => A'First = 1 and then B'First = 1
                 and then A'Length <= Max_Name and then B'Length <= Max_Name;

   function Ends_With (Name : String; Ext : String) return Boolean is
     (Name'Length >= 4 and then Name (Name'Last - 3 .. Name'Last) = Ext)
     with Pre => Name'First = 1 and then Name'Length <= Max_Name
                 and then Ext'First = 1 and then Ext'Length = 4;

   function Is_Ada_Source (Name : String) return Boolean is
     (Ends_With (Name, Ads_Ext) or else Ends_With (Name, Adb_Ext))
     with Pre => Name'First = 1 and then Name'Length <= Max_Name;

   function Stem_Is_Unit (Name : String; Unit : String) return Boolean is
     (Name'Length >= 4 and then Same_Fold (Name (Name'First .. Name'Last - 4), Unit))
     with Pre => Name'First = 1 and then Name'Length <= Max_Name
                 and then Unit'First = 1 and then Unit'Length <= Max_Name;

   function Stages (Name : String; Is_Dir : Boolean; Unit : String) return Boolean is
     (not Is_Dir and then Is_Ada_Source (Name) and then not Stem_Is_Unit (Name, Unit))
     with Pre  => Name'First = 1 and then Name'Length <= Max_Name
                  and then Unit'First = 1 and then Unit'Length <= Max_Name,
          Post => (if Is_Dir then not Stages'Result)
                  and then (if not Is_Ada_Source (Name) then not Stages'Result)
                  and then (if Stem_Is_Unit (Name, Unit) then not Stages'Result)
                  and then (if not Is_Dir and then Is_Ada_Source (Name)
                              and then not Stem_Is_Unit (Name, Unit) then Stages'Result);

end Lovelace_Carried_Unit_Rule_Pkg;
