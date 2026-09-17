--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: e426bf3dcb66fe139df341baa19c49572ed960ddd700713e81a1525475426db1
--
package body Duplicate_Completion_Pkg with SPARK_Mode is

   function Name_First_Of (T : String; Line_First : Positive; Line_Last : Positive) return Positive is
   begin
      for P in Line_First .. Line_Last loop
         pragma Loop_Invariant
           (for all Q in Line_First .. P - 1 =>
              not (for some E in Q .. Line_Last => Function_Name_Span (T, Line_First, Line_Last, Q, E)));
         if (for some E in P .. Line_Last => Function_Name_Span (T, Line_First, Line_Last, P, E)) then
            return P;
         end if;
      end loop;
      return Line_First;
   end Name_First_Of;

   function Ident_End (T : String; P : Positive; Line_Last : Positive) return Positive is
      E : Positive := P;
   begin
      while E < Line_Last and then Is_Ident_Char (T (E + 1)) loop
         pragma Loop_Invariant (E in P .. Line_Last - 1);
         pragma Loop_Invariant (for all K in P .. E => Is_Ident_Char (T (K)));
         pragma Loop_Variant (Increases => E);
         E := E + 1;
      end loop;
      return E;
   end Ident_End;

end Duplicate_Completion_Pkg;