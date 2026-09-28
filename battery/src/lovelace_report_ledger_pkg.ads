--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 97058c69bc22246271006996436d48febe5c48e812bc35ee257485970bd3d278
--
with Lovelace_Wire_Tallier_Pkg;
use Lovelace_Wire_Tallier_Pkg;

package Lovelace_Report_Ledger_Pkg with SPARK_Mode, Pure is

   Max_Count   : constant := 100_000;
   Max_Refusal : constant := 8_192;

   subtype Count is Natural range 0 .. Max_Count;
   subtype Refusal_Length is Natural range 0 .. Max_Refusal;
   subtype Record_Count is Natural range 0 .. Max_Functions;

   type Ledger is record
      Error_Count      : Count          := 0;
      Functions_Read   : Count          := 0;
      Posts_Declared   : Count          := 0;
      Posts_Read       : Count          := 0;
      Functions_Graded : Count          := 0;
      Definitions_Only : Count          := 0;
      Kept             : Record_Count   := 0;
      Records          : Record_Array (1 .. Max_Functions);
      Refusal_Len      : Refusal_Length := 0;
      Refusal          : String (1 .. Max_Refusal);
   end record;

   function Empty_Ledger return Ledger is
     ((Error_Count      => 0,
       Functions_Read   => 0,
       Posts_Declared   => 0,
       Posts_Read       => 0,
       Functions_Graded => 0,
       Definitions_Only => 0,
       Kept             => 0,
       Records          => (others => (Definition => False, Grade => -1)),
       Refusal_Len      => 0,
       Refusal          => (others => ' ')))
     with Post => Empty_Ledger'Result.Error_Count = 0
                  and then Empty_Ledger'Result.Kept = 0
                  and then Empty_Ledger'Result.Refusal_Len = 0;

   function Same_Counts (A : Ledger; B : Ledger) return Boolean is
     (A.Functions_Read = B.Functions_Read
      and then A.Posts_Declared = B.Posts_Declared
      and then A.Posts_Read = B.Posts_Read
      and then A.Functions_Graded = B.Functions_Graded
      and then A.Definitions_Only = B.Definitions_Only);

   function Refusal_Of (L : Ledger) return String is
     (L.Refusal (1 .. L.Refusal_Len))
     with Post => Refusal_Of'Result'Length = L.Refusal_Len;

   function Has_Refusal (L : Ledger) return Boolean is
     (L.Refusal_Len > 0);

   function Add_Error (L : Ledger) return Ledger is
     ((L with delta Error_Count => L.Error_Count + 1))
     with Pre  => L.Error_Count < Max_Count,
          Post => Add_Error'Result.Error_Count = L.Error_Count + 1
                  and then Same_Counts (Add_Error'Result, L)
                  and then Add_Error'Result.Kept = L.Kept
                  and then Add_Error'Result.Refusal_Len = L.Refusal_Len;

   function Add_Errors (L : Ledger; N : Natural) return Ledger is
     ((L with delta Error_Count => L.Error_Count + N))
     with Pre  => N <= Max_Count - L.Error_Count,
          Post => Add_Errors'Result.Error_Count = L.Error_Count + N
                  and then Add_Errors'Result.Error_Count >= L.Error_Count
                  and then Same_Counts (Add_Errors'Result, L)
                  and then Add_Errors'Result.Kept = L.Kept;

   function Padded (Text : String) return String is
     (Text & (1 .. Max_Refusal - Text'Length => ' '))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Refusal,
          Post => Padded'Result'First = 1
                  and then Padded'Result'Length = Max_Refusal
                  and then Padded'Result (1 .. Text'Length) = Text;

   function Set_Refusal (L : Ledger; Text : String) return Ledger is
     ((L with delta Refusal_Len => Text'Length, Refusal => Padded (Text)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Refusal,
          Post => Set_Refusal'Result.Refusal_Len = Text'Length
                  and then Refusal_Of (Set_Refusal'Result) = Text
                  and then Set_Refusal'Result.Error_Count = L.Error_Count
                  and then Same_Counts (Set_Refusal'Result, L)
                  and then Set_Refusal'Result.Kept = L.Kept;

   function Set_Header (L : Ledger; Read : Count; Declared : Count; Posts : Count) return Ledger is
     ((L with delta Functions_Read => Read, Posts_Declared => Declared, Posts_Read => Posts))
     with Post => Set_Header'Result.Functions_Read = Read
                  and then Set_Header'Result.Posts_Declared = Declared
                  and then Set_Header'Result.Posts_Read = Posts
                  and then Set_Header'Result.Error_Count = L.Error_Count
                  and then Set_Header'Result.Kept = L.Kept;

   function Set_Totals (L : Ledger; Graded : Count; Definitions : Count) return Ledger is
     ((L with delta Functions_Graded => Graded, Definitions_Only => Definitions))
     with Post => Set_Totals'Result.Functions_Graded = Graded
                  and then Set_Totals'Result.Definitions_Only = Definitions
                  and then Set_Totals'Result.Error_Count = L.Error_Count
                  and then Set_Totals'Result.Kept = L.Kept;

   function Add_Record (L : Ledger; R : Function_Record) return Ledger is
     ((L with delta Kept => L.Kept + 1, Records => (L.Records with delta L.Kept + 1 => R)))
     with Pre  => L.Kept < Max_Functions,
          Post => Add_Record'Result.Kept = L.Kept + 1
                  and then Add_Record'Result.Records (L.Kept + 1) = R
                  and then (for all K in 1 .. L.Kept => Add_Record'Result.Records (K) = L.Records (K))
                  and then Add_Record'Result.Error_Count = L.Error_Count
                  and then Same_Counts (Add_Record'Result, L);

   function Kept_Records (L : Ledger) return Record_Array is
     (L.Records (1 .. L.Kept))
     with Post => Kept_Records'Result'First = 1 and then Kept_Records'Result'Length = L.Kept;

   function Wire_Tallies (L : Ledger) return Tallies is
     (Tally (Kept_Records (L)))
     with Post => Wire_Tallies'Result.Grade_Lines = Wire_Tallies'Result.Theorem_Count
                    + Wire_Tallies'Result.Runtime_Only_Count + Wire_Tallies'Result.Unexercised_Count
                    + Wire_Tallies'Result.Refused_Count
                  and then Wire_Tallies'Result.Grade_Lines <= L.Kept;

end Lovelace_Report_Ledger_Pkg;
