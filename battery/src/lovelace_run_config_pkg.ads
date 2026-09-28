--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 0b5f28b2555e488b048d35e1124a8e44046a2944ac9b9c765f43d3e2162fc287
--
package Lovelace_Run_Config_Pkg with SPARK_Mode, Pure is

   Steps       : constant := 20_000;
   Level       : constant := 2;
   Max_Mutants : constant := 12;

   type Config_Phase is (Unset, Set);

   type Run_Config is record
      Phase      : Config_Phase := Unset;
      Deps_Given : Boolean      := False;
   end record;

   function Empty_Config return Run_Config is
     ((Phase => Unset, Deps_Given => False))
     with Post => Empty_Config'Result.Phase = Unset;

   function Is_Wire_Call (Arg_Count : Natural; First_Is_Wire : Boolean) return Boolean is
     (Arg_Count > 2 and then First_Is_Wire);

   function Deps_Named (Arg_Count : Natural) return Boolean is
     (Arg_Count > 3);

   function Set_Config (C : Run_Config; Arg_Count : Natural) return Run_Config is
     ((Phase => Set, Deps_Given => Deps_Named (Arg_Count)))
     with Pre  => C.Phase = Unset,
          Post => Set_Config'Result.Phase = Set
                  and then ((Set_Config'Result.Deps_Given) = (Arg_Count > 3));

   function May_Read (C : Run_Config) return Boolean is
     (C.Phase = Set);

end Lovelace_Run_Config_Pkg;
