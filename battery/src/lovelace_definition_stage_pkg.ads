--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 0202b5a28b5c960b86355f49fedf2629c87c719db4117b588355c3a8786ee2fe
--
with Lovelace_Outcome_Rules_Pkg;
use Lovelace_Outcome_Rules_Pkg;

package Lovelace_Definition_Stage_Pkg with SPARK_Mode, Pure is

   subtype Grade_Value is Integer range -1 .. 2;

   Definition_Word : constant String := "definition";

   type Stage_Record is record
      Definition : Boolean     := False;
      T1         : Outcome     := Unreached;
      T2         : Outcome     := Unreached;
      T3         : Outcome     := Unreached;
      Grade      : Grade_Value := -1;
   end record;

   function Definition_Step (R : Stage_Record; Has_Post : Boolean) return Stage_Record is
     (if Is_Definition (Has_Post)
      then (R with delta Definition => True, T1 => Unreached, T2 => Unreached, T3 => Unreached, Grade => -1)
      else R)
     with Post => (if not Has_Post then
                     (Definition_Step'Result.Definition
                      and then Definition_Step'Result.T1 = Unreached
                      and then Definition_Step'Result.T2 = Unreached
                      and then Definition_Step'Result.T3 = Unreached
                      and then Definition_Step'Result.Grade = -1))
                  and then (if Has_Post then Definition_Step'Result = R);

   function Later_Stage_Runs (R : Stage_Record) return Boolean is
     (not R.Definition);

   function Pass_Through (R : Stage_Record; Updated : Stage_Record) return Stage_Record is
     (if R.Definition then R else Updated)
     with Post => (if R.Definition then Pass_Through'Result = R)
                  and then (if not R.Definition then Pass_Through'Result = Updated);

end Lovelace_Definition_Stage_Pkg;
