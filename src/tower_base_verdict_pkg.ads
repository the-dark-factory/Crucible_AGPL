--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 0e90ff7a41a00113e5a863931978e5bf82fe4f53d499c6f8df2910ffb2e13422
--
package Tower_Base_Verdict_Pkg with SPARK_Mode is

   type Base_Facts is record
      pin_measured : Boolean := False;
      file_read    : Boolean := False;
      digest_matches : Boolean := False;
   end record;

   type Verdict_Kind is (Base_Holds, Refused_No_Pin, Refused_Missing, Refused_Tampered);

   function Decide (F : Base_Facts) return Verdict_Kind
     is ((if not F.pin_measured then Refused_No_Pin
          elsif not F.file_read then Refused_Missing
          elsif not F.digest_matches then Refused_Tampered
          else Base_Holds))
     with Post =>
       (((Decide'Result = Base_Holds) = (F.pin_measured and then F.file_read and then F.digest_matches)) and then
        (if not F.pin_measured then Decide'Result = Refused_No_Pin) and then
        (if F.pin_measured and then not F.file_read then Decide'Result = Refused_Missing) and then
        (if F.pin_measured and then F.file_read and then not F.digest_matches then Decide'Result = Refused_Tampered));

   function May_Forge (V : Verdict_Kind) return Boolean
     is ((V = Base_Holds))
     with Post => (May_Forge'Result = (V = Base_Holds));

   function Forge_Permitted (F : Base_Facts) return Boolean
     is ((May_Forge (Decide (F))))
     with Post =>
       ((Forge_Permitted'Result = May_Forge (Decide (F))) and then
        (Forge_Permitted'Result = (F.pin_measured and then F.file_read and then F.digest_matches)) and then
        (if not F.digest_matches then not Forge_Permitted'Result) and then
        (if not F.file_read then not Forge_Permitted'Result) and then
        (if not F.pin_measured then not Forge_Permitted'Result));

   function Reason_Word (V : Verdict_Kind) return String
     is ((if V = Base_Holds then "tower_base_holds"
          elsif V = Refused_No_Pin then "tower_no_pin"
          elsif V = Refused_Missing then "tower_base_missing"
          else "tower_base_tampered"))
     with Post =>
       ((if V = Base_Holds then Reason_Word'Result = "tower_base_holds") and then
        (if V = Refused_No_Pin then Reason_Word'Result = "tower_no_pin") and then
        (if V = Refused_Missing then Reason_Word'Result = "tower_base_missing") and then
        (if V = Refused_Tampered then Reason_Word'Result = "tower_base_tampered"));

end Tower_Base_Verdict_Pkg;
