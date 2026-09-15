--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 15db69f4a2e4fe8b09655a6ac6f8e3aecf0ce0716c84d0ca88fdd3591968b7cd
--
with Provenance_Record_Pkg;

package Provenance_Stamp_Pkg with SPARK_Mode is

   type Stamp_Facts is record
      Model_Recorded              : Boolean := False;
      Endpoint_Recorded           : Boolean := False;
      Rail_Recorded               : Boolean := False;
      Methodology_Digest_Recorded : Boolean := False;
      Brief_Digest_Recorded       : Boolean := False;
      Verdict_Recorded            : Boolean := False;
      Build                       : Provenance_Record_Pkg.Facts_Type;
   end record;

   type Fault_Kind is
     (No_Fault,
      Model_Missing,
      Endpoint_Missing,
      Rail_Missing,
      Methodology_Missing,
      Brief_Digest_Missing,
      Verdict_Missing,
      Build_Not_Re_Derivable);

   function Expansion_Complete (S : Stamp_Facts) return Boolean is
     (S.Model_Recorded and then S.Endpoint_Recorded and then S.Rail_Recorded
      and then S.Methodology_Digest_Recorded and then S.Brief_Digest_Recorded
      and then S.Verdict_Recorded)
   with Global => null;

   function Build_Re_Derivable (S : Stamp_Facts) return Boolean is
     (Provenance_Record_Pkg.Replayable_By_A_Stranger
        (Provenance_Record_Pkg.Assemble (S.Build)))
   with Global => null;

   function Fault_Of (S : Stamp_Facts) return Fault_Kind is
     (if not S.Model_Recorded then Model_Missing
      elsif not S.Endpoint_Recorded then Endpoint_Missing
      elsif not S.Rail_Recorded then Rail_Missing
      elsif not S.Methodology_Digest_Recorded then Methodology_Missing
      elsif not S.Brief_Digest_Recorded then Brief_Digest_Missing
      elsif not S.Verdict_Recorded then Verdict_Missing
      elsif not Build_Re_Derivable (S) then Build_Not_Re_Derivable
      else No_Fault)
   with Global => null;

   function Accepted (S : Stamp_Facts) return Boolean is
     (Fault_Of (S) = No_Fault)
   with Global => null,
        Post   => Accepted'Result = (Expansion_Complete (S) and then Build_Re_Derivable (S));

end Provenance_Stamp_Pkg;
