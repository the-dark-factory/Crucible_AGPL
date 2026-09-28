--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 0d0c92aadae1c2ae2c8ec9ccb0ba1b1fec018b902a85dc2c78bd1e1113a8d80c
--
package Lovelace_Relation_Splitter_Pkg with SPARK_Mode, Pure is

   Max_Text : constant := 1_048_576;

   subtype Depth_Type is Integer range -Max_Text .. Max_Text;

   type Rel_Op is (No_Op, Op_Ne, Op_Le, Op_Ge, Op_Eq, Op_Lt, Op_Gt);

   Ne_Text : constant String := " /= ";
   Le_Text : constant String := " <= ";
   Ge_Text : constant String := " >= ";
   Eq_Text : constant String := " = ";
   Lt_Text : constant String := " < ";
   Gt_Text : constant String := " > ";

   type Relation is record
      Op        : Rel_Op   := No_Op;
      At_Index  : Positive := 1;
      Lhs_First : Positive := 1;
      Lhs_Last  : Natural  := 0;
      Rhs_First : Positive := 1;
      Rhs_Last  : Natural  := 0;
   end record;

   function No_Relation return Relation is
     ((Op => No_Op, At_Index => 1, Lhs_First => 1, Lhs_Last => 0, Rhs_First => 1, Rhs_Last => 0));

   function Paren_Step (C : Character) return Integer is
     (if C = '(' then 1 elsif C = ')' then -1 else 0)
     with Post => Paren_Step'Result >= -1 and then Paren_Step'Result <= 1;

   function Raw_Depth (Text : String; First : Positive; K : Natural) return Depth_Type is
     (if K < First then 0 else Raw_Depth (Text, First, K - 1) + Paren_Step (Text (K)))
     with Ghost,
          Pre  => Text'First = 1 and then Text'Length <= Max_Text and then K <= Text'Length,
          Post => (if K < First then Raw_Depth'Result = 0)
                  and then Raw_Depth'Result >= -K and then Raw_Depth'Result <= K,
          Subprogram_Variant => (Decreases => K);

   function Has_At (Text : String; I : Positive; Last : Natural; Op : String) return Boolean is
     (Op'Length <= Last - I + 1
      and then Text (I .. I + Op'Length - 1) = Op)
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                 and then I <= Last + 1 and then Op'First = 1
                 and then Op'Length >= 3 and then Op'Length <= 4;

   function Op_At (Text : String; I : Positive; Last : Natural) return Rel_Op is
     (if Has_At (Text, I, Last, Ne_Text) then Op_Ne
      elsif Has_At (Text, I, Last, Le_Text) then Op_Le
      elsif Has_At (Text, I, Last, Ge_Text) then Op_Ge
      elsif Has_At (Text, I, Last, Eq_Text) then Op_Eq
      elsif Has_At (Text, I, Last, Lt_Text) then Op_Lt
      elsif Has_At (Text, I, Last, Gt_Text) then Op_Gt
      else No_Op)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then I <= Last + 1,
          Post => (if Op_At'Result /= No_Op then (I <= Last and then Text (I) = ' '));

   function Op_Length (Op : Rel_Op) return Natural is
     (if Op = No_Op then 0
      elsif Op = Op_Ne or else Op = Op_Le or else Op = Op_Ge then 4
      else 3)
     with Post => Op_Length'Result <= 4 and then ((Op_Length'Result = 0) = (Op = No_Op));

   function Split_Scan (Text : String; First : Positive; Last : Natural; I : Positive;
                        Depth : Depth_Type) return Natural is
     (if I > Last then 0
      elsif Depth + Paren_Step (Text (I)) = 0 and then Op_At (Text, I, Last) /= No_Op then I
      else Split_Scan (Text, First, Last, I + 1, Depth + Paren_Step (Text (I))))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then First <= I and then I <= Last + 1
                  and then Depth = Raw_Depth (Text, First, I - 1),
          Post => Split_Scan'Result = 0
                  or else (Split_Scan'Result >= I and then Split_Scan'Result <= Last
                           and then Op_At (Text, Split_Scan'Result, Last) /= No_Op
                           and then Raw_Depth (Text, First, Split_Scan'Result) = 0),
          Subprogram_Variant => (Decreases => Last - I + 1);

   function Split_Point (Text : String; First : Positive; Last : Natural) return Natural is
     (Split_Scan (Text, First, Last, First, 0))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then First <= Last + 1,
          Post => Split_Point'Result = 0
                  or else (Split_Point'Result >= First and then Split_Point'Result <= Last
                           and then Op_At (Text, Split_Point'Result, Last) /= No_Op
                           and then Raw_Depth (Text, First, Split_Point'Result) = 0);

   function Relation_At (Text : String; First : Positive; Last : Natural; I : Positive) return Relation is
     ((Op        => Op_At (Text, I, Last),
       At_Index  => I,
       Lhs_First => First,
       Lhs_Last  => I - 1,
       Rhs_First => I + Op_Length (Op_At (Text, I, Last)),
       Rhs_Last  => Last))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                 and then First <= I and then I <= Last;

   function Split_Relation (Text : String; First : Positive; Last : Natural) return Relation is
     (if Split_Point (Text, First, Last) = 0 then No_Relation
      else Relation_At (Text, First, Last, Split_Point (Text, First, Last)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then First <= Last + 1,
          Post => ((Split_Relation'Result.Op = No_Op) = (Split_Point (Text, First, Last) = 0))
                  and then Split_Relation'Result.Rhs_First
                           = Split_Relation'Result.At_Index + Op_Length (Split_Relation'Result.Op)
                  and then (if Split_Relation'Result.Op /= No_Op then
                              (Split_Relation'Result.At_Index = Split_Point (Text, First, Last)
                               and then Split_Relation'Result.Lhs_Last = Split_Relation'Result.At_Index - 1
                               and then Split_Relation'Result.Rhs_Last = Last));

end Lovelace_Relation_Splitter_Pkg;
