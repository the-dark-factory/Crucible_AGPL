--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 248b1c6fbbf7852c9ec872d92a9096abe596272150b59aef17cf049b6df547a3
--
package Report_Row_Pkg with SPARK_Mode is
   --  PURPOSE: one line of Crucible's report stream, state/report.jsonl: which
   --  run, which sink, when, and the sink's own line as lowercase hex, so no
   --  sink content can ever break the report line. Only the nine named sinks
   --  are sources; the report itself never is.
   --  USAGE: the door hex-encodes each appended sink line, checks each field
   --  with the predicates below, and writes Row_Line plus a line feed.

   Run_Id_Length : constant := 40;
   Stamp_Length  : constant := 20;
   Row_Max       : constant := 2_097_152;

   Src_Audit         : constant String (1 .. 5)  := "audit";
   Src_Rounds        : constant String (1 .. 6)  := "rounds";
   Src_Body_Rounds   : constant String (1 .. 11) := "body-rounds";
   Src_Vacuity       : constant String (1 .. 7)  := "vacuity";
   Src_Model_Rail    : constant String (1 .. 10) := "model-rail";
   Src_Tower         : constant String (1 .. 5)  := "tower";
   Src_Tower_Fetch   : constant String (1 .. 11) := "tower-fetch";
   Src_Tower_Pack    : constant String (1 .. 10) := "tower-pack";
   Src_Tower_Receipt : constant String (1 .. 13) := "tower-receipt";

   function Is_Digit (C : Character) return Boolean
   is (C in '0' .. '9')
   with Global => null,
        Post => Is_Digit'Result = (C in '0' .. '9');

   function Is_Lower_Hex (C : Character) return Boolean
   is (C in '0' .. '9' or else C in 'a' .. 'f')
   with Global => null,
        Post => Is_Lower_Hex'Result = (C in '0' .. '9' or else C in 'a' .. 'f');

   function Is_Source (S : String) return Boolean
   is ((S = Src_Audit or else S = Src_Rounds or else S = Src_Body_Rounds
        or else S = Src_Vacuity or else S = Src_Model_Rail or else S = Src_Tower
        or else S = Src_Tower_Fetch or else S = Src_Tower_Pack
        or else S = Src_Tower_Receipt))
   with Global => null,
        Post => Is_Source'Result = ((S = Src_Audit or else S = Src_Rounds or else S = Src_Body_Rounds
                                   or else S = Src_Vacuity or else S = Src_Model_Rail or else S = Src_Tower
                                   or else S = Src_Tower_Fetch or else S = Src_Tower_Pack
                                   or else S = Src_Tower_Receipt));

   function Is_Run_Id (S : String) return Boolean
   is ((S'Length = Run_Id_Length
        and then (for all K in 0 .. 39 =>
                    (if K = 0 then S (S'First + K) = 'r'
                     elsif K = 1 or else K = 18 or else K = 29 then S (S'First + K) = '-'
                     elsif K = 10 then S (S'First + K) = 'T'
                     elsif K = 17 then S (S'First + K) = 'Z'
                     else Is_Digit (S (S'First + K))))))
   with Global => null,
        Post => Is_Run_Id'Result = ((S'Length = Run_Id_Length
                                    and then (for all K in 0 .. 39 =>
                                                (if K = 0 then S (S'First + K) = 'r'
                                                 elsif K = 1 or else K = 18 or else K = 29 then S (S'First + K) = '-'
                                                 elsif K = 10 then S (S'First + K) = 'T'
                                                 elsif K = 17 then S (S'First + K) = 'Z'
                                                 else Is_Digit (S (S'First + K))))))
        and then (if Is_Run_Id'Result then S'Length = Run_Id_Length);

   function Is_Stamp (S : String) return Boolean
   is ((S'Length = Stamp_Length
        and then (for all K in 0 .. 19 =>
                    (if K = 4 or else K = 7 then S (S'First + K) = '-'
                     elsif K = 10 then S (S'First + K) = 'T'
                     elsif K = 13 or else K = 16 then S (S'First + K) = ':'
                     elsif K = 19 then S (S'First + K) = 'Z'
                     else Is_Digit (S (S'First + K))))))
   with Global => null,
        Post => Is_Stamp'Result = ((S'Length = Stamp_Length
                                   and then (for all K in 0 .. 19 =>
                                               (if K = 4 or else K = 7 then S (S'First + K) = '-'
                                                elsif K = 10 then S (S'First + K) = 'T'
                                                elsif K = 13 or else K = 16 then S (S'First + K) = ':'
                                                elsif K = 19 then S (S'First + K) = 'Z'
                                                else Is_Digit (S (S'First + K))))))
        and then (if Is_Stamp'Result then S'Length = Stamp_Length);

   function Is_Hex_Row (S : String) return Boolean
   is ((S'Length >= 2 and then S'Length <= Row_Max and then S'Length mod 2 = 0
        and then (for all K in S'Range => Is_Lower_Hex (S (K)))))
   with Global => null,
        Post => Is_Hex_Row'Result = ((S'Length >= 2 and then S'Length <= Row_Max and then S'Length mod 2 = 0
                                     and then (for all K in S'Range => Is_Lower_Hex (S (K)))))
        and then (if Is_Hex_Row'Result then S'Length in 2 .. Row_Max);

   function Row_Line (Run_Id, Source, At_Stamp, Row : String) return String
   is ("{""run_id"":""" & Run_Id & """,""source"":""" & Source &
       """,""at"":""" & At_Stamp & """,""row"":""" & Row & """}")
   with Global => null,
        Pre  => Is_Run_Id (Run_Id) and then Is_Source (Source) and then Is_Stamp (At_Stamp) and then Is_Hex_Row (Row),
        Post => Row_Line'Result = ("{""run_id"":""" & Run_Id & """,""source"":""" & Source &
                                  """,""at"":""" & At_Stamp & """,""row"":""" & Row & """}")
        and then Row_Line'Result'Length = 42 + Run_Id'Length + Source'Length + At_Stamp'Length + Row'Length;

end Report_Row_Pkg;
