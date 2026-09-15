--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 879bd9ea405fd067099e011994da6656492bb6ce87f39c2b66cf3b27607fe460
--
package Mascot_Judge_Pkg with SPARK_Mode, Pure is

   Max_Count : constant := 4096;

   subtype Count is Natural range 0 .. Max_Count;

   type Fact_Set is record
      Leaves : Count;
      Leaves_One_Activity : Count;
      Leaves_One_Pool : Count;
      Leaves_Neither_Or_Both : Count;
      Channels : Count;
      Channels_With_Element : Count;
      Channels_With_Buffer : Count;
      Channels_With_Producer : Count;
      Channels_With_One_Consumer : Count;
      Orphan_Activities : Count;
      Orphan_Pools : Count;
      Activities_Without_Reporting : Count;
      Reporting_Channels : Count;
      Events_Channel_Consumers : Count;
      Data_Graph_Has_Cycle : Boolean;
      Empty_Discharge_Answers : Count;
      Duplicate_Hops : Count;
      Composites : Count;
      Empty_Composites : Count;
      Activities_Total : Count;
      Channels_Total : Count;
   end record;

   type Fact_Name is (
      Every_Leaf_Is_One_Activity_Or_One_Pool,
      Every_Channel_Typed_Buffered_Produced_Consumed,
      No_Orphan_Activity,
      No_Orphan_Pool,
      Every_Activity_Reports,
      One_Events_Channel_One_Sink,
      Data_Graph_Acyclic,
      Every_Leaf_Discharges,
      No_Duplicate_Hop,
      No_Empty_Composite,
      Not_Vacuous
   );

   function Every_Leaf_Is_One_Activity_Or_One_Pool (F : Fact_Set) return Boolean is
     (F.Leaves_Neither_Or_Both = 0 and then F.Leaves_One_Activity + F.Leaves_One_Pool = F.Leaves);

   function Every_Channel_Typed_Buffered_Produced_Consumed (F : Fact_Set) return Boolean is
     (F.Channels_With_Element = F.Channels and then F.Channels_With_Buffer = F.Channels and then F.Channels_With_Producer = F.Channels and then F.Channels_With_One_Consumer = F.Channels);

   function No_Orphan_Activity (F : Fact_Set) return Boolean is
     (F.Orphan_Activities = 0);

   function No_Orphan_Pool (F : Fact_Set) return Boolean is
     (F.Orphan_Pools = 0);

   function Every_Activity_Reports (F : Fact_Set) return Boolean is
     (F.Activities_Without_Reporting = 0);

   function One_Events_Channel_One_Sink (F : Fact_Set) return Boolean is
     (F.Reporting_Channels = 1 and then F.Events_Channel_Consumers = 1);

   function Data_Graph_Acyclic (F : Fact_Set) return Boolean is
     (not F.Data_Graph_Has_Cycle);

   function Every_Leaf_Discharges (F : Fact_Set) return Boolean is
     (F.Empty_Discharge_Answers = 0);

   function No_Duplicate_Hop (F : Fact_Set) return Boolean is
     (F.Duplicate_Hops = 0);

   function No_Empty_Composite (F : Fact_Set) return Boolean is
     (F.Empty_Composites = 0);

   function Not_Vacuous (F : Fact_Set) return Boolean is
     (F.Activities_Total >= 1 and then F.Channels_Total >= 1);

   function Holds (N : Fact_Name; F : Fact_Set) return Boolean is
     (case N is
        when Every_Leaf_Is_One_Activity_Or_One_Pool => Every_Leaf_Is_One_Activity_Or_One_Pool (F),
        when Every_Channel_Typed_Buffered_Produced_Consumed => Every_Channel_Typed_Buffered_Produced_Consumed (F),
        when No_Orphan_Activity => No_Orphan_Activity (F),
        when No_Orphan_Pool => No_Orphan_Pool (F),
        when Every_Activity_Reports => Every_Activity_Reports (F),
        when One_Events_Channel_One_Sink => One_Events_Channel_One_Sink (F),
        when Data_Graph_Acyclic => Data_Graph_Acyclic (F),
        when Every_Leaf_Discharges => Every_Leaf_Discharges (F),
        when No_Duplicate_Hop => No_Duplicate_Hop (F),
        when No_Empty_Composite => No_Empty_Composite (F),
        when Not_Vacuous => Not_Vacuous (F));

   type Failed_Set is array (Fact_Name) of Boolean;

   function Failed (F : Fact_Set) return Failed_Set is
     ([for N in Fact_Name => not Holds (N, F)])
   with Post => (for all N in Fact_Name => Failed'Result (N) = not Holds (N, F));

   function Accepted (F : Fact_Set) return Boolean is
     ((for all N in Fact_Name => Holds (N, F)))
   with Post => (Accepted'Result = (for all N in Fact_Name => Holds (N, F)));

end Mascot_Judge_Pkg;
