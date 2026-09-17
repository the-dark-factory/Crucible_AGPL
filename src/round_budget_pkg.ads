--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 9746bcd07f9bacc71a88dfee668dd81e3b77eacc8042883d6d1c6bee70f22b82
--
package Round_Budget_Pkg with SPARK_Mode is

   Max_Rounds : constant := 8;

   subtype Round_Count is Integer range 0 .. Max_Rounds;

   type Round_Result is (Result_Fit, Result_Refused, Result_No_Unit);

   type Budget_State is record
      rounds_used : Round_Count := 0;
      last        : Round_Result := Result_No_Unit;
      fit         : Boolean := False;
   end record;

   function Fresh return Budget_State
     is ((rounds_used => 0, last => Result_No_Unit, fit => False))
     with Post => (Fresh'Result.rounds_used = 0
                   and then Fresh'Result.fit = False);

   function May_Start (S : Budget_State) return Boolean
     is (not S.fit and then S.rounds_used < Max_Rounds);

   function Repair_Base_Available (S : Budget_State) return Boolean
     is (S.rounds_used >= 1 and then S.last = Result_Refused);

   function Budget_Spent (S : Budget_State) return Boolean
     is (not S.fit and then S.rounds_used = Max_Rounds);

   function Round_Letter (S : Budget_State) return Character
     is (Character'Val (Character'Pos ('A') + S.rounds_used))
     with Pre  => S.rounds_used < Max_Rounds,
          Post => Round_Letter'Result in 'A' .. 'H';

   function Record_Round (S : Budget_State; R : Round_Result) return Budget_State
     is ((rounds_used => S.rounds_used + 1, last => R, fit => (R = Result_Fit)))
     with Pre  => May_Start (S),
          Post => (Record_Round'Result.rounds_used = S.rounds_used + 1
                   and then Record_Round'Result.last = R
                   and then (Record_Round'Result.fit = (R = Result_Fit))
                   and then (if R = Result_Fit then not May_Start (Record_Round'Result))
                   and then (Repair_Base_Available (Record_Round'Result) = (R = Result_Refused))
                   and then (if R = Result_No_Unit then not Repair_Base_Available (Record_Round'Result))
                   and then (if S.rounds_used = Max_Rounds - 1 and then R /= Result_Fit then Budget_Spent (Record_Round'Result)));

end Round_Budget_Pkg;
