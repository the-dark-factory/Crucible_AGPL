--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 199edd06c5727a85828570555a7422101667f3a22f70fdc124d1b9fdf36d998e
--
package body Intake_Measure_Pkg with SPARK_Mode => On is

   function Operation_Count (S : Sheet) return Line_Count is
      Result : Line_Count := 0;
   begin
      for I in 1 .. S.Count loop
         if Is_Operation (S, I) then
            Result := Result + 1;
         end if;
         pragma Loop_Invariant (Result <= I);
         pragma Loop_Invariant ((Result = 0) = (for all J in 1 .. I => not Is_Operation (S, J)));
      end loop;
      return Result;
   end Operation_Count;

   function Undefined_Count (S : Sheet) return Natural is
      Result : Natural := 0;
   begin
      for I in 1 .. S.Count loop
         for P in 1 .. S.Lines (I).Len loop
            if Is_Undefined_At (S, I, P) then
               Result := Result + 1;
            end if;
            pragma Loop_Invariant (Result <= (I - 1) * Intake_Line_Pkg.Max_Line + P);
            pragma Loop_Invariant ((Result = 0) =
              ((for all J in 1 .. I - 1 => (for all Q in 1 .. S.Lines (J).Len => not Is_Undefined_At (S, J, Q)))
               and then (for all Q in 1 .. P => not Is_Undefined_At (S, I, Q))));
         end loop;
         pragma Loop_Invariant (Result <= I * Intake_Line_Pkg.Max_Line);
         pragma Loop_Invariant ((Result = 0) =
           (for all J in 1 .. I => (for all Q in 1 .. S.Lines (J).Len => not Is_Undefined_At (S, J, Q))));
      end loop;
      return Result;
   end Undefined_Count;

   function First_Undefined (S : Sheet) return Name_Place is
   begin
      for I in 1 .. S.Count loop
         for P in 1 .. S.Lines (I).Len loop
            if Is_Undefined_At (S, I, P) then
               return (Line => I, Pos => P);
            end if;
            pragma Loop_Invariant ((for all J in 1 .. I - 1 => (for all Q in 1 .. S.Lines (J).Len => not Is_Undefined_At (S, J, Q)))
              and then (for all Q in 1 .. P => not Is_Undefined_At (S, I, Q)));
         end loop;
         pragma Loop_Invariant (for all J in 1 .. I => (for all Q in 1 .. S.Lines (J).Len => not Is_Undefined_At (S, J, Q)));
      end loop;
      return (Line => 0, Pos => 0);
   end First_Undefined;

end Intake_Measure_Pkg;