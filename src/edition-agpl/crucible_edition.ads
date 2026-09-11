--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--
--  CRUCIBLE's edition, COMPILED IN. The project file selects this directory on the
--  CRUCIBLE_EDITION scenario variable; the other edition is a same-named spec in its own
--  directory. Never read from an argument or the environment: mui:edition-is-compiled-not-argued.
--
--  ⚠ HAND-AUTHORED under Tony's waiver, 2026-09-11 17:54 ("waive the two edition specs,
--  hand-author them"). Not forged. Recorded in BRIEF_crucible_door_wu_2026-09-11.md.
--
with Edition_Licence_Pkg;
use type Edition_Licence_Pkg.Edition_Type;

package Crucible_Edition with SPARK_Mode is

   Current : constant Edition_Licence_Pkg.Edition_Type := Edition_Licence_Pkg.Agpl;

   function Is_Agpl return Boolean
     is (Current = Edition_Licence_Pkg.Agpl)
     with Post => ((Is_Agpl'Result = True) = (Current = Edition_Licence_Pkg.Agpl));

end Crucible_Edition;
