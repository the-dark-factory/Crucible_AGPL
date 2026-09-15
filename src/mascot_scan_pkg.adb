--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: a5d71133fbdeab0d3fcc36dd46a2c87860fce301aade9b20b8d06e713ecfccdc
--
--  mascot_scan_pkg.adb
--
--  Purpose: body of Mascot_Scan_Pkg.  Only two operations require bodies --
--  Slice_Of (the spec declares it without an expression) and Scan.  Every
--  other visible operation of the spec is an expression function completed
--  in the specification itself.
--
--  Usage: Scan (S) classifies the line set exactly as Fault_Of does, and on a
--  well-formed set fills Table.Nodes (I) with Node_Of (S, I) for every
--  I in 1 .. S.Count, which is what the postcondition quantifier demands.
--
--  Conventions honoured here: no box notation in any aggregate; all
--  Loop_Invariant pragmas of a loop form ONE contiguous run of pragmas at the
--  top level of that loop's statement list; enumeration literals of the
--  withed packages are fully qualified (the spec's `use type` clauses do not
--  make literals directly visible).

package body Mascot_Scan_Pkg with SPARK_Mode => On is

   function Slice_Of (A : Line_Rec; SA : Json_Scan_Pkg.Span_Type) return String is
      Len : constant Positive := SA.Last - SA.First + 1;
      Out_S : String (1 .. Len) := (others => ' ');
   begin
      for K in 1 .. Len loop
         Out_S (K) := A.Text (SA.First + K - 1);
         pragma Loop_Invariant
           (for all M in 1 .. K => Out_S (M) = A.Text (SA.First + M - 1));
      end loop;
      return Out_S;
   end Slice_Of;

   function Scan (S : Line_Set) return Scan_Result is

      Blank_Node : constant Mascot_Measure_Pkg.Node :=
        (Kind              => Mascot_Measure_Pkg.Activity,
         Rank              => 0,
         Has_Element       => False,
         Has_Buffer        => False,
         Producer_Count    => 0,
         Consumer_Count    => 0,
         Producer          => 0,
         Consumer          => 0,
         Is_Reporting      => False,
         Data_Reads        => 0,
         Data_Writes       => 0,
         Has_Reporting     => False,
         Accessor_Count    => 0,
         Discharge_Present => False,
         Child_Count       => 0);

      Empty_Table : constant Mascot_Measure_Pkg.Node_Table :=
        (Nodes => (others => Blank_Node), Last => 0);

      Result  : Scan_Result :=
        (Ok => False, Fault => No_Fault, Table => Empty_Table);
      Missing : Boolean := False;
      Unknown : Boolean := False;

   begin
      if S.Count = 0 then
         Result.Ok    := False;
         Result.Fault := No_Lines;
         return Result;
      end if;

      for I in 1 .. S.Count loop
         if not Present (S.Lines (I), Key_Id) then
            Missing := True;
         end if;
         pragma Loop_Invariant
           (Missing = (for some J in 1 .. I => not Present (S.Lines (J), Key_Id)));
      end loop;

      if Missing then
         Result.Ok    := False;
         Result.Fault := Missing_Id;
         return Result;
      end if;

      pragma Assert
        (for all J in 1 .. S.Count => Present (S.Lines (J), Key_Id));

      for I in 1 .. S.Count loop
         if not Kind_Known (S.Lines (I)) then
            Unknown := True;
         end if;
         pragma Loop_Invariant
           (Unknown = (for some J in 1 .. I => not Kind_Known (S.Lines (J))));
      end loop;

      if Unknown then
         Result.Ok    := False;
         Result.Fault := Unknown_Kind;
         return Result;
      end if;

      pragma Assert
        (for all J in 1 .. S.Count => Kind_Known (S.Lines (J)));
      pragma Assert (Fault_Of (S) = No_Fault);

      Result.Table.Last := S.Count;

      for I in 1 .. S.Count loop
         Result.Table.Nodes (I) := Node_Of (S, I);
         pragma Loop_Invariant (Result.Table.Last = S.Count);
         pragma Loop_Invariant
           (for all J in 1 .. I => Result.Table.Nodes (J) = Node_Of (S, J));
      end loop;

      Result.Ok    := True;
      Result.Fault := No_Fault;

      return Result;
   end Scan;

end Mascot_Scan_Pkg;