--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 0d029dc8800b4f96e0efc5579a60399750ec94d24ccb34c4933426c6073cded3
--
package body Prove_Diagnostics_Pkg with SPARK_Mode => On is

   procedure Add (D : in out Diagnostics; Line : String) is
      Old_Lines : constant Line_Array := D.Lines;
   begin
      if Keep (Line) then
         if Fits (Line) and then D.Count < Max_Lines then
            D.Count := D.Count + 1;
            D.Lines (D.Count).Len := Kept_Length (Line'Length);
            for I in Line'Range loop
               D.Lines (D.Count).Text (I) := Line (I);
               pragma Loop_Invariant
                 (for all J in Line'First .. I => D.Lines (D.Count).Text (J) = Line (J));
               pragma Loop_Invariant
                 (for all J in Line_Index range 1 .. D.Count - 1 => D.Lines (J) = Old_Lines (J));
            end loop;
         else
            if D.Dropped < Max_Dropped then
               D.Dropped := D.Dropped + 1;
            else
               D.Saturated := True;
            end if;
         end if;
      end if;
   end Add;

end Prove_Diagnostics_Pkg;