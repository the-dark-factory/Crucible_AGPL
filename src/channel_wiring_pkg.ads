--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Channel_Wiring_Pkg lineage 2 (2026-09-13): the COUNTED CLOSE — a MASCOT channel with several producers is closed
--  only when every producer has finished with it. Wire takes the producer count as a second discriminant (Cap;
--  Producers), keeps a count of producers finished, and Close means "this producer is finished": the value queue
--  underneath is closed under the last one. Put/Take/Fill/Is_Closed unchanged; Finished_Count added. The bound
--  Finished <= Producers is a property of the body, not posted (a protected type carries no type invariant; a
--  discriminant may not constrain a scalar). Methodology: PROPOSAL_MASCOT_amendment_run_termination_2026-09-13;
--  writer MASCOT r3 F.1. Lane wu-crucible-channel-wiring-2 round C (A: unbounded count unprovable; B: illegal
--  scalar constraint), planner qwen3.8-27b-ada:v0.3, accepted, 0 unproved. Body-filled (qwen3-coder:30b, candidate 1,
--  proved through the Reference instance behind wire_gate.bb). Never hand-edited. Comment-stripped sha equals the round-C spec.
pragma Profile (Jorvik);
pragma Partition_Elaboration_Policy (Sequential);
with Bounded_Channel_Pkg;

package Channel_Wiring_Pkg with SPARK_Mode is

   generic
      with package Q is new Bounded_Channel_Pkg.Channel (<>);
      Initial : Q.Element_Type;
   package Wiring is

      protected type Wire (Cap : Q.Count; Producers : Positive) is
         entry Put (E : Q.Element_Type; Accepted : out Boolean)
           with Post => Fill = Fill'Old + (if Accepted then 1 else 0)
             and (if Accepted then not Is_Closed else Is_Closed);
         entry Take (E : out Q.Element_Type; Done : out Boolean)
           with Post => Fill = Fill'Old - (if Done then 0 else 1)
             and (if Done then Is_Closed and Fill = 0);
         procedure Close
           with Post => Fill = Fill'Old
             and Finished_Count - Finished_Count'Old = (if Finished_Count'Old < Producers then 1 else 0)
             and (if Finished_Count = Producers then Is_Closed);
         function Fill return Q.Count;
         function Is_Closed return Boolean;
         function Finished_Count return Natural;
      private
         Value : Q.Queue := (Items => (others => Initial), Length => 0, Closed => False);
         Finished : Natural := 0;
      end Wire;

   end Wiring;

end Channel_Wiring_Pkg;
