--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: af293abd34944ccda121719a4b84c130ef10f0bd9e413bf394e61892f2351d9a
--
with Mascot_Judge_Pkg;

package Mascot_Measure_Pkg with SPARK_Mode is

   type Node_Kind is (Activity, Pool, Channel, Composite);

   Max_Nodes : constant := 512;

   subtype Node_Index is Positive range 1 .. Max_Nodes;
   subtype Node_Count is Natural range 0 .. Max_Nodes;
   subtype Node_Ref is Natural range 0 .. Max_Nodes;

   type Node is record
      Kind : Node_Kind;
      Rank : Node_Count;
      Has_Element : Boolean;
      Has_Buffer : Boolean;
      Producer_Count : Node_Count;
      Consumer_Count : Node_Count;
      Producer : Node_Ref;
      Consumer : Node_Ref;
      Is_Reporting : Boolean;
      Data_Reads : Node_Count;
      Data_Writes : Node_Count;
      Has_Reporting : Boolean;
      Accessor_Count : Node_Count;
      Discharge_Present : Boolean;
      Child_Count : Node_Count;
   end record;

   type Node_Array is array (Node_Index) of Node;

   type Node_Table is record
      Nodes : Node_Array;
      Last : Node_Count;
   end record;

   function Count_Leaves
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Leaves (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind in Activity | Pool then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Leaves'Result <= Upto;

   function Count_Activities
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Activities (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Activity then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Activities'Result <= Upto;

   function Count_Pools
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Pools (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Pool then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Pools'Result <= Upto;

   function Count_Channels
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Channels (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Channel then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Channels'Result <= Upto;

   function Count_Channels_With_Element
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Channels_With_Element (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Channel and then Table.Nodes (Upto).Has_Element then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Channels_With_Element'Result <= Upto;

   function Count_Channels_With_Buffer
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Channels_With_Buffer (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Channel and then Table.Nodes (Upto).Has_Buffer then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Channels_With_Buffer'Result <= Upto;

   function Count_Channels_With_Producer
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Channels_With_Producer (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Channel and then Table.Nodes (Upto).Producer_Count >= 1 then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Channels_With_Producer'Result <= Upto;

   function Count_Channels_With_One_Consumer
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Channels_With_One_Consumer (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Channel and then Table.Nodes (Upto).Consumer_Count = 1 then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Channels_With_One_Consumer'Result <= Upto;

   function Count_Orphan_Activities
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Orphan_Activities (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Activity and then Table.Nodes (Upto).Data_Reads + Table.Nodes (Upto).Data_Writes = 0 then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Orphan_Activities'Result <= Upto;

   function Count_Orphan_Pools
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Orphan_Pools (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Pool and then Table.Nodes (Upto).Accessor_Count = 0 then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Orphan_Pools'Result <= Upto;

   function Count_Activities_Without_Reporting
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Activities_Without_Reporting (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Activity and then not Table.Nodes (Upto).Has_Reporting then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Activities_Without_Reporting'Result <= Upto;

   function Count_Reporting_Channels
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Reporting_Channels (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Channel and then Table.Nodes (Upto).Is_Reporting then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Reporting_Channels'Result <= Upto;

   function Count_Empty_Discharges
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Empty_Discharges (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind in Activity | Pool and then not Table.Nodes (Upto).Discharge_Present then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Empty_Discharges'Result <= Upto;

   function Count_Composites
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Composites (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Composite then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Composites'Result <= Upto;

   function Count_Empty_Composites
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Empty_Composites (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Composite and then Table.Nodes (Upto).Child_Count = 0 then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Empty_Composites'Result <= Upto;

   function Count_Back_Edges
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Back_Edges (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Channel and then not Table.Nodes (Upto).Is_Reporting and then
             Table.Nodes (Upto).Producer /= 0 and then Table.Nodes (Upto).Consumer /= 0 and then
             Table.Nodes (Table.Nodes (Upto).Producer).Rank >= Table.Nodes (Table.Nodes (Upto).Consumer).Rank then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Back_Edges'Result <= Upto;

   function Count_Duplicate_Hops
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      else Count_Duplicate_Hops (Table, Upto - 1) +
           (if Table.Nodes (Upto).Kind = Channel and then
             Table.Nodes (Upto).Producer /= 0 and then Table.Nodes (Upto).Consumer /= 0 and then
             (for some J in 1 .. Upto - 1 =>
               Table.Nodes (J).Kind = Channel and then
               Table.Nodes (J).Producer = Table.Nodes (Upto).Producer and then
               Table.Nodes (J).Consumer = Table.Nodes (Upto).Consumer) then 1 else 0))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto),
        Post => Count_Duplicate_Hops'Result <= Upto;

   function Events_Consumers
     (Table : Node_Table; Upto : Node_Count) return Node_Count is
     (if Upto = 0 then 0
      elsif Table.Nodes (Upto).Kind = Channel and then Table.Nodes (Upto).Is_Reporting then Table.Nodes (Upto).Consumer_Count
      else Events_Consumers (Table, Upto - 1))
   with Ghost, Global => null,
        Pre => Upto <= Table.Last,
        Subprogram_Variant => (Decreases => Upto);

   function Tally_Leaves
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Leaves'Result = Count_Leaves (Table, Table.Last);

   function Tally_Activities
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Activities'Result = Count_Activities (Table, Table.Last);

   function Tally_Pools
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Pools'Result = Count_Pools (Table, Table.Last);

   function Tally_Channels
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Channels'Result = Count_Channels (Table, Table.Last);

   function Tally_Channels_With_Element
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Channels_With_Element'Result = Count_Channels_With_Element (Table, Table.Last);

   function Tally_Channels_With_Buffer
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Channels_With_Buffer'Result = Count_Channels_With_Buffer (Table, Table.Last);

   function Tally_Channels_With_Producer
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Channels_With_Producer'Result = Count_Channels_With_Producer (Table, Table.Last);

   function Tally_Channels_With_One_Consumer
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Channels_With_One_Consumer'Result = Count_Channels_With_One_Consumer (Table, Table.Last);

   function Tally_Orphan_Activities
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Orphan_Activities'Result = Count_Orphan_Activities (Table, Table.Last);

   function Tally_Orphan_Pools
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Orphan_Pools'Result = Count_Orphan_Pools (Table, Table.Last);

   function Tally_Activities_Without_Reporting
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Activities_Without_Reporting'Result = Count_Activities_Without_Reporting (Table, Table.Last);

   function Tally_Reporting_Channels
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Reporting_Channels'Result = Count_Reporting_Channels (Table, Table.Last);

   function Tally_Empty_Discharges
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Empty_Discharges'Result = Count_Empty_Discharges (Table, Table.Last);

   function Tally_Composites
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Composites'Result = Count_Composites (Table, Table.Last);

   function Tally_Empty_Composites
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Empty_Composites'Result = Count_Empty_Composites (Table, Table.Last);

   function Tally_Back_Edges
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Back_Edges'Result = Count_Back_Edges (Table, Table.Last);

   function Tally_Duplicate_Hops
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Duplicate_Hops'Result = Count_Duplicate_Hops (Table, Table.Last);

   function Tally_Events_Consumers
     (Table : Node_Table) return Node_Count
   with Global => null,
        Post => Tally_Events_Consumers'Result = Events_Consumers (Table, Table.Last);

   function Measure
     (Table : Node_Table) return Mascot_Judge_Pkg.Fact_Set is
     ((Leaves => Tally_Leaves (Table),
       Leaves_One_Activity => Tally_Activities (Table),
       Leaves_One_Pool => Tally_Pools (Table),
       Leaves_Neither_Or_Both => 0,
       Channels => Tally_Channels (Table),
       Channels_With_Element => Tally_Channels_With_Element (Table),
       Channels_With_Buffer => Tally_Channels_With_Buffer (Table),
       Channels_With_Producer => Tally_Channels_With_Producer (Table),
       Channels_With_One_Consumer => Tally_Channels_With_One_Consumer (Table),
       Orphan_Activities => Tally_Orphan_Activities (Table),
       Orphan_Pools => Tally_Orphan_Pools (Table),
       Activities_Without_Reporting => Tally_Activities_Without_Reporting (Table),
       Reporting_Channels => Tally_Reporting_Channels (Table),
       Empty_Discharge_Answers => Tally_Empty_Discharges (Table),
       Composites => Tally_Composites (Table),
       Empty_Composites => Tally_Empty_Composites (Table),
       Events_Channel_Consumers => Tally_Events_Consumers (Table),
       Data_Graph_Has_Cycle => Tally_Back_Edges (Table) > 0,
       Duplicate_Hops => Tally_Duplicate_Hops (Table),
       Activities_Total => Tally_Activities (Table),
       Channels_Total => Tally_Channels (Table)))
   with Global => null,
        Post =>
          Measure'Result.Leaves = Count_Leaves (Table, Table.Last) and
          Measure'Result.Leaves_One_Activity = Count_Activities (Table, Table.Last) and
          Measure'Result.Leaves_One_Pool = Count_Pools (Table, Table.Last) and
          Measure'Result.Leaves_Neither_Or_Both = 0 and
          Measure'Result.Channels = Count_Channels (Table, Table.Last) and
          Measure'Result.Channels_With_Element = Count_Channels_With_Element (Table, Table.Last) and
          Measure'Result.Channels_With_Buffer = Count_Channels_With_Buffer (Table, Table.Last) and
          Measure'Result.Channels_With_Producer = Count_Channels_With_Producer (Table, Table.Last) and
          Measure'Result.Channels_With_One_Consumer = Count_Channels_With_One_Consumer (Table, Table.Last) and
          Measure'Result.Orphan_Activities = Count_Orphan_Activities (Table, Table.Last) and
          Measure'Result.Orphan_Pools = Count_Orphan_Pools (Table, Table.Last) and
          Measure'Result.Activities_Without_Reporting = Count_Activities_Without_Reporting (Table, Table.Last) and
          Measure'Result.Reporting_Channels = Count_Reporting_Channels (Table, Table.Last) and
          Measure'Result.Empty_Discharge_Answers = Count_Empty_Discharges (Table, Table.Last) and
          Measure'Result.Composites = Count_Composites (Table, Table.Last) and
          Measure'Result.Empty_Composites = Count_Empty_Composites (Table, Table.Last) and
          Measure'Result.Events_Channel_Consumers = Events_Consumers (Table, Table.Last) and
          Measure'Result.Data_Graph_Has_Cycle = (Count_Back_Edges (Table, Table.Last) > 0) and
          Measure'Result.Duplicate_Hops = Count_Duplicate_Hops (Table, Table.Last) and
          Measure'Result.Activities_Total = Count_Activities (Table, Table.Last) and
          Measure'Result.Channels_Total = Count_Channels (Table, Table.Last);

end Mascot_Measure_Pkg;
