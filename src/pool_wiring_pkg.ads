--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Pool_Wiring_Pkg: a MASCOT pool as a PLACE — a Jorvik protected type Store over the carried value pool
--  (Pool_Pkg.Pool, a formal package): Read; Write whose Accepted is the proved May_Write decision (a refused
--  set-once write is a returned fact, never a blocked caller); Write_Count. Every body statement is one call to
--  a proved value function. Unit 2 of BRIEF_jorvik_channel_wiring_2026-09-13. Lane wu-crucible-pool-wiring
--  rounds A (use type), B accepted; the reference instance lives in the body. Never hand-edited.
--  Comment-stripped sha equals round B.
pragma Profile (Jorvik);
pragma Partition_Elaboration_Policy (Sequential);
with Pool_Pkg;

package Pool_Wiring_Pkg with SPARK_Mode is

   generic
      with package P is new Pool_Pkg.Pool (<>);
      Initial : P.State_Type;
   package Wiring is

      use type P.State_Type;

      protected type Store is
         function Read return P.State_Type;
         procedure Write (V : P.State_Type; Accepted : out Boolean)
           with Post => Write_Count = Write_Count'Old + (if Accepted then 1 else 0)
             and (if Accepted then Read = V);
         function Write_Count return Natural;
      private
         Value : P.Pool_Type := (Value => Initial, Writes => 0);
      end Store;

   end Wiring;

end Pool_Wiring_Pkg;
