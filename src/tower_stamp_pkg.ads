--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: f9523f21822f8c10feda40ab322a2d3b444f8395042f3cf7b0c9cf90fef8613f
--
package Tower_Stamp_Pkg with SPARK_Mode is

   function Is_Hex_Digest (S : String) return Boolean is
     (S'Length = 64 and then (for all I in S'Range => S (I) in '0' .. '9' | 'a' .. 'f'))
   with Post => (Is_Hex_Digest'Result = (S'Length = 64 and then (for all I in S'Range => S (I) in '0' .. '9' | 'a' .. 'f')));

   function Recorded_Digest (S : String) return String is
     (if Is_Hex_Digest (S) then S else "")
   with Post => ((if Is_Hex_Digest (S) then Recorded_Digest'Result = S else Recorded_Digest'Result'Length = 0));

   function Is_Version_Text (S : String) return Boolean is
     (S'Length >= 1 and then S'Length <= 9 and then (for all I in S'Range => S (I) in '0' .. '9') and then (S'Length = 1 or else S (S'First) /= '0'))
   with Post => (Is_Version_Text'Result = (S'Length >= 1 and then S'Length <= 9 and then (for all I in S'Range => S (I) in '0' .. '9') and then (S'Length = 1 or else S (S'First) /= '0')));

   function Recorded_Version (S : String) return String is
     (if Is_Version_Text (S) then S else "2147483647")
   with Post => ((if Is_Version_Text (S) then Recorded_Version'Result = S else Recorded_Version'Result = "2147483647"));

end Tower_Stamp_Pkg;
