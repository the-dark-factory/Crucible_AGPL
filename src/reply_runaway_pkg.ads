--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 166edcf5f28075706ce4d4f83ed2789d071f397abfe8076265918552100bcd00
--
package Reply_Runaway_Pkg with SPARK_Mode is
   --  PURPOSE: did a model reply run away (blanks or one character repeated, on and on)?
   --  The model-rail edge measures the two run lengths over the reply; this decides.
   --  USAGE: Is_Runaway (Longest_Blank_Run, Longest_Same_Run); True refuses the reply by
   --  name (reply_runaway). Is_Blank names the four blank characters the edge counts.

   Max_Blank_Run : constant := 256;
   Max_Same_Run  : constant := 512;

   function Is_Blank (C : Character) return Boolean is
     (C = ' ' or else C = ASCII.HT or else C = ASCII.CR or else C = ASCII.LF)
     with Global => null,
          Post => Is_Blank'Result = (C = ' ' or else C = ASCII.HT or else C = ASCII.CR or else C = ASCII.LF);

   function Is_Runaway (Longest_Blank_Run : Natural; Longest_Same_Run : Natural) return Boolean is
     ((Longest_Blank_Run >= Max_Blank_Run) or else (Longest_Same_Run >= Max_Same_Run))
     with Global => null,
          Post => Is_Runaway'Result = ((Longest_Blank_Run >= Max_Blank_Run) or else (Longest_Same_Run >= Max_Same_Run))
                    and then (if Longest_Blank_Run < Max_Blank_Run and then Longest_Same_Run < Max_Same_Run then not Is_Runaway'Result)
                    and then (if Longest_Blank_Run >= Max_Blank_Run then Is_Runaway'Result);

end Reply_Runaway_Pkg;
