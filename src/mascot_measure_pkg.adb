--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 58bc2c63afb0991b28ea148be7e5825b48d28fc58ced3b60fc742ba02af72b22
--
-- Body for Mascot_Measure_Pkg.
--
-- The Count_* / Events_Consumers functions in the spec are Ghost entities, so
-- they may only appear in assertion contexts (pragma Loop_Invariant, contracts).
-- Each Tally_* function therefore performs a real iterative computation and
-- carries a Loop_Invariant tying the accumulator to the corresponding ghost
-- recursive specification, which is what discharges the postcondition.

package body Mascot_Measure_Pkg with SPARK_Mode => On is

   function Tally_Leaves (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind in Activity | Pool then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Leaves (Table, I));
      end loop;
      return Acc;
   end Tally_Leaves;

   function Tally_Activities (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Activity then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Activities (Table, I));
      end loop;
      return Acc;
   end Tally_Activities;

   function Tally_Pools (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Pool then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Pools (Table, I));
      end loop;
      return Acc;
   end Tally_Pools;

   function Tally_Channels (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Channel then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Channels (Table, I));
      end loop;
      return Acc;
   end Tally_Channels;

   function Tally_Channels_With_Element (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Channel and then Table.Nodes (I).Has_Element then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Channels_With_Element (Table, I));
      end loop;
      return Acc;
   end Tally_Channels_With_Element;

   function Tally_Channels_With_Buffer (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Channel and then Table.Nodes (I).Has_Buffer then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Channels_With_Buffer (Table, I));
      end loop;
      return Acc;
   end Tally_Channels_With_Buffer;

   function Tally_Channels_With_Producer (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Channel
           and then Table.Nodes (I).Producer_Count >= 1
         then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Channels_With_Producer (Table, I));
      end loop;
      return Acc;
   end Tally_Channels_With_Producer;

   function Tally_Channels_With_One_Consumer (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Channel
           and then Table.Nodes (I).Consumer_Count = 1
         then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Channels_With_One_Consumer (Table, I));
      end loop;
      return Acc;
   end Tally_Channels_With_One_Consumer;

   function Tally_Orphan_Activities (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Activity
           and then Table.Nodes (I).Data_Reads + Table.Nodes (I).Data_Writes = 0
         then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Orphan_Activities (Table, I));
      end loop;
      return Acc;
   end Tally_Orphan_Activities;

   function Tally_Orphan_Pools (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Pool
           and then Table.Nodes (I).Accessor_Count = 0
         then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Orphan_Pools (Table, I));
      end loop;
      return Acc;
   end Tally_Orphan_Pools;

   function Tally_Activities_Without_Reporting (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Activity
           and then not Table.Nodes (I).Has_Reporting
         then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Activities_Without_Reporting (Table, I));
      end loop;
      return Acc;
   end Tally_Activities_Without_Reporting;

   function Tally_Reporting_Channels (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Channel
           and then Table.Nodes (I).Is_Reporting
         then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Reporting_Channels (Table, I));
      end loop;
      return Acc;
   end Tally_Reporting_Channels;

   function Tally_Empty_Discharges (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind in Activity | Pool
           and then not Table.Nodes (I).Discharge_Present
         then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Empty_Discharges (Table, I));
      end loop;
      return Acc;
   end Tally_Empty_Discharges;

   function Tally_Composites (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Composite then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Composites (Table, I));
      end loop;
      return Acc;
   end Tally_Composites;

   function Tally_Empty_Composites (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Composite
           and then Table.Nodes (I).Child_Count = 0
         then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Empty_Composites (Table, I));
      end loop;
      return Acc;
   end Tally_Empty_Composites;

   function Tally_Back_Edges (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         --  Producer / Consumer are Node_Ref (0 means "absent"); the /= 0
         --  guards make the subsequent indexing range-safe by construction.
         if Table.Nodes (I).Kind = Channel
           and then not Table.Nodes (I).Is_Reporting
           and then Table.Nodes (I).Producer /= 0
           and then Table.Nodes (I).Consumer /= 0
           and then Table.Nodes (Table.Nodes (I).Producer).Rank >=
                    Table.Nodes (Table.Nodes (I).Consumer).Rank
         then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Back_Edges (Table, I));
      end loop;
      return Acc;
   end Tally_Back_Edges;

   function Tally_Duplicate_Hops (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Channel
           and then Table.Nodes (I).Producer /= 0
           and then Table.Nodes (I).Consumer /= 0
           and then (for some J in 1 .. I - 1 =>
                       Table.Nodes (J).Kind = Channel
                       and then Table.Nodes (J).Producer = Table.Nodes (I).Producer
                       and then Table.Nodes (J).Consumer = Table.Nodes (I).Consumer)
         then
            Acc := Acc + 1;
         end if;
         pragma Loop_Invariant (Acc <= I);
         pragma Loop_Invariant (Acc = Count_Duplicate_Hops (Table, I));
      end loop;
      return Acc;
   end Tally_Duplicate_Hops;

   function Tally_Events_Consumers (Table : Node_Table) return Node_Count is
      Acc : Node_Count := 0;
   begin
      --  Mirrors the ghost definition: the highest-indexed reporting channel
      --  wins, so a later match simply overwrites the accumulator.
      for I in 1 .. Table.Last loop
         if Table.Nodes (I).Kind = Channel
           and then Table.Nodes (I).Is_Reporting
         then
            Acc := Table.Nodes (I).Consumer_Count;
         end if;
         pragma Loop_Invariant (Acc = Events_Consumers (Table, I));
      end loop;
      return Acc;
   end Tally_Events_Consumers;

end Mascot_Measure_Pkg;