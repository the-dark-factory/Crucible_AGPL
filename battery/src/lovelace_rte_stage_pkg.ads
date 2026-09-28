--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: a601134db4e2b99535860607fee1a28b94fdb84f87fbbba70a551828eeffd644
--
with Lovelace_Message_Rules_Pkg;
use Lovelace_Message_Rules_Pkg;

package Lovelace_Rte_Stage_Pkg with SPARK_Mode, Pure is

   type Line_Span is record
      From : Natural := 0;
      To   : Natural := 0;
   end record;

   function Span_From (Decl_Line : Natural; Body_Line : Natural) return Natural is
     (if Body_Line > 0 and then Body_Line < Decl_Line then Body_Line else Decl_Line)
     with Post => Span_From'Result <= Decl_Line
                  and then (if Body_Line > 0 then Span_From'Result <= Body_Line);

   function Span_To (Decl_End : Natural; Body_End : Natural) return Natural is
     (if Body_End > Decl_End then Body_End else Decl_End)
     with Post => Span_To'Result >= Decl_End and then Span_To'Result >= Body_End;

   function Function_Span (Decl_Line : Natural; Decl_End : Natural;
                           Body_Line : Natural; Body_End : Natural) return Line_Span is
     ((From => Span_From (Decl_Line, Body_Line), To => Span_To (Decl_End, Body_End)))
     with Post => Function_Span'Result.From <= Decl_Line
                  and then Function_Span'Result.To >= Decl_End
                  and then Function_Span'Result.To >= Body_End
                  and then (if Body_Line > 0 then Function_Span'Result.From <= Body_Line);

   function RTE_Of (Base_Reached : Boolean; Msgs : Message_Array; Count : Natural; S : Line_Span) return Outcome is
     (Runtime_Outcome (Base_Reached, Msgs, Count, S.From, S.To))
     with Pre  => Msgs'First = 1 and then Count <= Msgs'Last,
          Post => ((RTE_Of'Result = Unreached) = (not Base_Reached))
                  and then RTE_Of'Result /= Inapplicable
                  and then (if Base_Reached and then Count = 0 then RTE_Of'Result = Proved);

end Lovelace_Rte_Stage_Pkg;
