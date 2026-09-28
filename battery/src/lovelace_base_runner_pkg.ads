--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 69f8e421dff64d8c849fc0d3dd58e1d6f9b0f7ffd796b2f8e496e19e2ddf118f
--
with Lovelace_Message_Rules_Pkg;
use Lovelace_Message_Rules_Pkg;

package Lovelace_Base_Runner_Pkg with SPARK_Mode, Pure is

   type Run_State is (Not_Run, Ran);

   type Base_Result is record
      Reached : Boolean := False;
      Faulted : Boolean := False;
      Errors  : Natural := 0;
   end record;

   function Run_Base (S : Run_State) return Run_State is
     (Ran)
     with Pre  => S = Not_Run,
          Post => Run_Base'Result = Ran;

   function Faulted_Of (Setup_Failed : Boolean; Error_Seen : Boolean;
                        Exit_Failed : Boolean; Summary_Seen : Boolean) return Boolean is
     (Setup_Failed or else Fault_Of (Error_Seen, Exit_Failed, Summary_Seen) /= No_Fault);

   function Error_Count_Of (Faulted : Boolean) return Natural is
     (if Faulted then 1 else 0)
     with Post => Error_Count_Of'Result <= 1 and then ((Error_Count_Of'Result = 1) = Faulted);

   function Base_Result_Of (Setup_Failed : Boolean; Error_Seen : Boolean;
                            Exit_Failed : Boolean; Summary_Seen : Boolean) return Base_Result is
     ((Reached => not Setup_Failed and then Reached_Of (Summary_Seen, Error_Seen),
       Faulted => Faulted_Of (Setup_Failed, Error_Seen, Exit_Failed, Summary_Seen),
       Errors  => Error_Count_Of (Faulted_Of (Setup_Failed, Error_Seen, Exit_Failed, Summary_Seen))))
     with Post => not (Base_Result_Of'Result.Reached and then Base_Result_Of'Result.Faulted)
                  and then ((Base_Result_Of'Result.Errors = 1) = Base_Result_Of'Result.Faulted)
                  and then Base_Result_Of'Result.Errors <= 1
                  and then (if Setup_Failed or else Error_Seen then not Base_Result_Of'Result.Reached)
                  and then (if Error_Seen then Base_Result_Of'Result.Faulted);

end Lovelace_Base_Runner_Pkg;
