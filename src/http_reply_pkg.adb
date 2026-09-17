--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1243f38845b62ee413243692e5f05549b72b7ecffa367d5f161f36bd74371573
--
package body Http_Reply_Pkg with SPARK_Mode is

   function Header_End (Reply : String) return Natural is
   begin
      for I in 1 .. Reply'Last - 3 loop
         pragma Loop_Invariant (for all J in 1 .. I - 1 => not Is_Blank_Line_At (Reply, J));
         if Is_Blank_Line_At (Reply, I) then
            return I;
         end if;
      end loop;
      return 0;
   end Header_End;

end Http_Reply_Pkg;