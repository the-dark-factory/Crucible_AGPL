--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Channel_Wiring_Pkg: a MASCOT channel as a PLACE — a Jorvik protected type Wire over the carried value queue
--  (Bounded_Channel_Pkg.Channel, a formal package): Put blocks only while full-and-open and is refused at once
--  when closed; Take blocks only while empty-and-open and reports Done when closed and drained; Close; Fill;
--  Is_Closed. Barriers read components and the Cap discriminant (Pure_Barriers); every body statement is one
--  call to a proved value function. Unit 1 of BRIEF_jorvik_channel_wiring_2026-09-13. Lane
--  wu-crucible-channel-wiring rounds A (Old placement, instance-before-body), B, C (discriminant) — round C
--  accepted; the reference instance lives in the body. Never hand-edited. Comment-stripped sha equals round C.
pragma Profile (Jorvik);
pragma Partition_Elaboration_Policy (Sequential);
with Bounded_Channel_Pkg;

package Channel_Wiring_Pkg with SPARK_Mode is

   generic
      with package Q is new Bounded_Channel_Pkg.Channel (<>);
      Initial : Q.Element_Type;
   package Wiring is

      protected type Wire (Cap : Q.Count) is
         entry Put (E : Q.Element_Type; Accepted : out Boolean)
           with Post => Fill = Fill'Old + (if Accepted then 1 else 0)
             and (if Accepted then not Is_Closed else Is_Closed);
         entry Take (E : out Q.Element_Type; Done : out Boolean)
           with Post => Fill = Fill'Old - (if Done then 0 else 1)
             and (if Done then Is_Closed and Fill = 0);
         procedure Close
           with Post => Is_Closed and Fill = Fill'Old;
         function Fill return Q.Count;
         function Is_Closed return Boolean;
      private
         Value : Q.Queue := (Items => (others => Initial), Length => 0, Closed => False);
      end Wire;

   end Wiring;

end Channel_Wiring_Pkg;
