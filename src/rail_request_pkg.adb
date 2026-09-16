--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: fbda62f2658b65f54929d4e6a69ab171786ac99190a96571ae2cae115856fae9
--
package body Rail_Request_Pkg with SPARK_Mode => On is

   function First_Quote_After (Line : String; From : Positive) return Natural is
      Result : Natural := 0;
   begin
      for K in From .. Line'Last loop
         if Line (K) = '"' then
            Result := K;
            exit;
         end if;
         pragma Loop_Invariant (if Result = 0 then (for all J in From .. K => Line (J) /= '"'));
      end loop;
      return Result;
   end First_Quote_After;

   

end Rail_Request_Pkg;