--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 08aaf24dc2dc98979201a9766e37a550e388baa754019ac7d71677c36bc62974
--
package Build_Stamp_Pkg with SPARK_Mode is

   function Is_Hex_Commit (S : String) return Boolean is
     (S'Length = 40 and then (for all I in S'Range => S (I) in '0' .. '9' | 'a' .. 'f'))
   with Post => Is_Hex_Commit'Result = (S'Length = 40 and then (for all I in S'Range => S (I) in '0' .. '9' | 'a' .. 'f'));

   function Is_Clean (Porcelain : String) return Boolean is
     ((for all I in Porcelain'Range => Porcelain (I) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR))
   with Post => Is_Clean'Result = (for all I in Porcelain'Range => Porcelain (I) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR);

   function Recorded_Commit (S : String) return String is
     ((if Is_Hex_Commit (S) then S else ""))
   with Post => (if Is_Hex_Commit (S) then Recorded_Commit'Result = S else Recorded_Commit'Result'Length = 0);

   function Clean_Word (Clean : Boolean) return String is
     ((if Clean then "True" else "False"))
   with Post => (if Clean then Clean_Word'Result = "True" else Clean_Word'Result = "False");

   function Is_Time_Text (S : String) return Boolean is
     (S'Length = 10 and then (for all I in S'Range => S (I) in '0' .. '9') and then S (S'First) /= '0')
   with Post => Is_Time_Text'Result = (S'Length = 10 and then (for all I in S'Range => S (I) in '0' .. '9') and then S (S'First) /= '0');

   function Recorded_Time (S : String) return String is
     ((if Is_Time_Text (S) then S else ""))
   with Post => (if Is_Time_Text (S) then Recorded_Time'Result = S else Recorded_Time'Result'Length = 0);

end Build_Stamp_Pkg;
