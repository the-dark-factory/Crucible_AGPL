--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: b558833dee40f3e825070de74b517c5c593b88e0be8c76d33af21c45d1a76117
--
package Lovelace_Splice_Fit_Pkg with SPARK_Mode, Pure is

   Max_Text  : constant := 1_048_576;
   Max_Lines : constant := 1_048_577;

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);
   VT : constant Character := Character'Val (11);
   FF : constant Character := Character'Val (12);
   CR : constant Character := Character'Val (13);

   type Line_Source is (Kept_Line, Fitted_Line);

   function Is_Field_Space (C : Character) return Boolean is
     (C = HT or else C = LF or else C = VT or else C = FF or else C = CR or else C = ' ')
     with Global => null;

   function Gap_Bonus (Gap : Boolean) return Natural is
     (if Gap then 1 else 0);

   function Join_From (Text : String; K : Positive; Started : Boolean; Gap : Boolean) return String is
     (if K > Text'Length then ""
      elsif Is_Field_Space (Text (K)) then Join_From (Text, K + 1, Started, Started)
      elsif Gap then " " & Text (K) & Join_From (Text, K + 1, True, False)
      else Text (K) & Join_From (Text, K + 1, True, False))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then K <= Text'Length + 1,
          Post => Join_From'Result'Length <= Text'Length - K + 1 + Gap_Bonus (Gap)
                  and then (for all I in Join_From'Result'Range =>
                              (Join_From'Result (I) = ' ' or else not Is_Field_Space (Join_From'Result (I)))),
          Subprogram_Variant => (Decreases => Text'Length - K + 1);

   function Fields_Join (Text : String) return String is
     (Join_From (Text, 1, False, False))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text,
          Post => Fields_Join'Result'Length <= Text'Length
                  and then (for all I in Fields_Join'Result'Range => Fields_Join'Result (I) /= LF);

   function Fit_Line (Text : String; N : Natural; K : Positive) return String is
     (if K = 1 then Fields_Join (Text) else "")
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then K <= N,
          Post => (if K > 1 then Fit_Line'Result'Length = 0)
                  and then (for all I in Fit_Line'Result'Range => Fit_Line'Result (I) /= LF);

   function Source_Of (From : Positive; N : Natural; I : Positive) return Line_Source is
     (if I >= From and then I - From < N then Fitted_Line else Kept_Line)
     with Pre  => From <= Max_Lines and then N <= Max_Lines and then I <= Max_Lines,
          Post => ((Source_Of'Result = Fitted_Line) = (I >= From and then I - From < N));

   function Fit_Index (From : Positive; I : Positive) return Positive is
     (I - From + 1)
     with Pre => From <= I;

end Lovelace_Splice_Fit_Pkg;
