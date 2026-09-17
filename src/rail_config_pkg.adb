--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 2cf8a46fb22d4d40ff5795a8069f1f3d3c5f46e6520032c0bc2939858d913920
--
package body Rail_Config_Pkg with SPARK_Mode => On is

   function Dot_After (Line : String; From : Positive; Last : Natural) return Natural is
   begin
      for K in From .. Last loop
         pragma Loop_Invariant (for all J in From .. K - 1 => Line (J) /= '.');
         if Line (K) = '.' then
            return K;
         end if;
      end loop;
      return 0;
   end Dot_After;

end Rail_Config_Pkg;