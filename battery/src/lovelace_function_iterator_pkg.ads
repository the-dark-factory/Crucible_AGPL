--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 99a53b36a000f2d97c9d15ce69e4da21907a26b5b9a867c13bd42877602a5ad3
--
package Lovelace_Function_Iterator_Pkg with SPARK_Mode, Pure is

   Max_Functions : constant := 10_000;

   type Step_Kind is (Function_Step, End_Of_Functions);

   type Step is record
      Kind  : Step_Kind := End_Of_Functions;
      Index : Natural   := 0;
   end record;

   function Step_Count (N : Natural) return Positive is
     (N + 1)
     with Pre => N <= Max_Functions;

   function Step_At (N : Natural; K : Positive) return Step is
     (if K <= N then (Kind => Function_Step, Index => K)
      else (Kind => End_Of_Functions, Index => 0))
     with Pre  => N <= Max_Functions and then K <= N + 1,
          Post => ((Step_At'Result.Kind = End_Of_Functions) = (K = N + 1))
                  and then (if K <= N then Step_At'Result.Index = K);

end Lovelace_Function_Iterator_Pkg;
