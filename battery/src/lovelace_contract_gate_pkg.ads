--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: fadf1b117f645ba454d7b894caecc40f867348167b04075379752a4c1aed4895
--
with Lovelace_Refusal_Texts_Pkg;
use Lovelace_Refusal_Texts_Pkg;

package Lovelace_Contract_Gate_Pkg with SPARK_Mode, Pure is

   Max_Functions : constant := 10_000;

   type Contract_Flags is record
      Has_Pre  : Boolean := False;
      Has_Post : Boolean := False;
   end record;

   type Flags_Array is array (Positive range <>) of Contract_Flags;

   type Gate_Word is (Gate_Open, Posts_Unread, Pres_Unread);

   type Gate_Record is record
      Functions_Read : Count     := 0;
      Posts_Declared : Count     := 0;
      Posts_Read     : Count     := 0;
      Word           : Gate_Word := Gate_Open;
   end record;

   function Count_Posts (F : Flags_Array; N : Natural) return Natural is
     (if N = 0 then 0
      elsif F (N).Has_Post then Count_Posts (F, N - 1) + 1
      else Count_Posts (F, N - 1))
     with Pre  => F'First = 1 and then F'Length <= Max_Functions and then N <= F'Length,
          Post => Count_Posts'Result <= N,
          Subprogram_Variant => (Decreases => N);

   function Count_Pres (F : Flags_Array; N : Natural) return Natural is
     (if N = 0 then 0
      elsif F (N).Has_Pre then Count_Pres (F, N - 1) + 1
      else Count_Pres (F, N - 1))
     with Pre  => F'First = 1 and then F'Length <= Max_Functions and then N <= F'Length,
          Post => Count_Pres'Result <= N,
          Subprogram_Variant => (Decreases => N);

   function Gate_Of (Post_Count : Count; Post_Declared : Count;
                     Pre_Count : Count; Pre_Declared : Count) return Gate_Word is
     (if Post_Count < Post_Declared then Posts_Unread
      elsif Pre_Count < Pre_Declared then Pres_Unread
      else Gate_Open)
     with Post => ((Gate_Of'Result = Gate_Open) = (Post_Count >= Post_Declared and then Pre_Count >= Pre_Declared))
                  and then ((Gate_Of'Result = Posts_Unread) = (Post_Count < Post_Declared));

   function Gate_Refusal (Post_Count : Count; Post_Declared : Count;
                          Pre_Count : Count; Pre_Declared : Count) return String is
     (if Post_Count < Post_Declared then Postconditions_Unread (Post_Count, Post_Declared)
      elsif Pre_Count < Pre_Declared then Preconditions_Unread (Pre_Count, Pre_Declared)
      else "")
     with Post => ((Gate_Refusal'Result'Length = 0)
                   = (Gate_Of (Post_Count, Post_Declared, Pre_Count, Pre_Declared) = Gate_Open))
                  and then (if Post_Count < Post_Declared then
                              Gate_Refusal'Result = Postconditions_Unread (Post_Count, Post_Declared));

   function Gate_Record_Of (F : Flags_Array; Posts_Declared : Count; Pres_Declared : Count) return Gate_Record is
     ((Functions_Read => F'Length,
       Posts_Declared => Posts_Declared,
       Posts_Read     => Count_Posts (F, F'Length),
       Word           => Gate_Of (Count_Posts (F, F'Length), Posts_Declared,
                                  Count_Pres (F, F'Length), Pres_Declared)))
     with Pre  => F'First = 1 and then F'Length <= Max_Functions,
          Post => Gate_Record_Of'Result.Functions_Read = F'Length
                  and then Gate_Record_Of'Result.Posts_Read <= F'Length
                  and then ((Gate_Record_Of'Result.Word = Gate_Open)
                            = (Count_Posts (F, F'Length) >= Posts_Declared
                               and then Count_Pres (F, F'Length) >= Pres_Declared));

end Lovelace_Contract_Gate_Pkg;
