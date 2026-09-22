--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: c9ca8fec10ea3b7b68625a511023c8bdd011e6472ea14dbe64cbf7783a5441ba
--
package Reciprocity_Pkg with Pure, SPARK_Mode => On is

   type Verdict is (Pulls_Freely, Reciprocity_Met, Refused_Owes);

   function Owes (Parked_Held, Cases_Sent : Natural) return Boolean is
     (Parked_Held > 0 and then Cases_Sent = 0)
   with Global => null;

   function May_Pull (Parked_Held, Cases_Sent : Natural) return Boolean is
     (not Owes (Parked_Held, Cases_Sent))
   with Global => null,
        Post => (if Parked_Held = 0 then May_Pull'Result)
                and then (if Cases_Sent > 0 then May_Pull'Result)
                and then (if Owes (Parked_Held, Cases_Sent) then not May_Pull'Result);

   function Reason (Parked_Held, Cases_Sent : Natural) return Verdict is
     (if Parked_Held = 0 then Pulls_Freely
      elsif Cases_Sent > 0 then Reciprocity_Met
      else Refused_Owes)
   with Global => null,
        Post => (Reason'Result = Refused_Owes) = Owes (Parked_Held, Cases_Sent)
                and then (if Parked_Held = 0 then Reason'Result = Pulls_Freely)
                and then (May_Pull (Parked_Held, Cases_Sent) = (Reason'Result /= Refused_Owes));

end Reciprocity_Pkg;
