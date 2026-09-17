--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 84fae408f3319abba98e016c4d9a6f271dca777c1a9801e14c0e2e4eaf9c3c8f
--
package Gate_Word_Pkg with SPARK_Mode is

   type Gate_Facts is record
      unit_compiled       : Boolean := False;
      checks_generated    : Natural := 0;
      checks_unproved     : Natural := 0;
      subprograms_skipped : Natural := 0;
      cheat_markers       : Natural := 0;
   end record;

   function Is_Clean (F : Gate_Facts) return Boolean is
     (F.unit_compiled and then F.cheat_markers = 0 and then F.checks_generated >= 1 and then F.checks_unproved = 0)
     with Post => (Is_Clean'Result = (F.unit_compiled and then F.cheat_markers = 0 and then F.checks_generated >= 1 and then F.checks_unproved = 0));

   function Is_Accepted (F : Gate_Facts) return Boolean is
     (Is_Clean (F) and then F.subprograms_skipped = 0)
     with Post => (Is_Accepted'Result = (F.unit_compiled and then F.cheat_markers = 0 and then F.checks_generated >= 1 and then F.checks_unproved = 0 and then F.subprograms_skipped = 0));

   function Word_Of (F : Gate_Facts) return String is
     ((if not F.unit_compiled then "refused-compile"
       elsif F.cheat_markers >= 1 then "refused-cheat"
       elsif F.checks_generated = 0 then "refused-no-checks"
       elsif F.checks_unproved >= 1 then "refused-unproved"
       elsif F.subprograms_skipped >= 1 then "refused-assumed-body"
       else "accepted"))
     with Post =>
       ((Word_Of'Result = "accepted") = (Is_Accepted (F))) and
       ((Word_Of'Result = "refused-assumed-body") = (Is_Clean (F) and then F.subprograms_skipped >= 1)) and
       (if not F.unit_compiled then Word_Of'Result = "refused-compile") and
       (if F.unit_compiled and then F.cheat_markers >= 1 then Word_Of'Result = "refused-cheat") and
       (if F.unit_compiled and then F.cheat_markers = 0 and then F.checks_generated = 0 then Word_Of'Result = "refused-no-checks") and
       (if F.unit_compiled and then F.cheat_markers = 0 and then F.checks_generated >= 1 and then F.checks_unproved >= 1 then Word_Of'Result = "refused-unproved") and
       (Word_Of'Result'First = 1) and
       (Word_Of'Result'Length >= 8);

   function Compile_Errors_Of (F : Gate_Facts) return Natural is
     ((if F.unit_compiled then 0 else 1))
     with Post => ((Compile_Errors_Of'Result = 0) = (F.unit_compiled));

end Gate_Word_Pkg;
