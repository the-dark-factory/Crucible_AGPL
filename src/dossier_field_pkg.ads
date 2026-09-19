--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 2a9177fc86028b7efe8a8321432545907744d16a83707ef2c3e09c6837fdb727
--
package Dossier_Field_Pkg with SPARK_Mode is

   type Field_Kind is (Kind_Estate_Naming, Kind_Typed, Kind_Measured, Kind_Emitted);

   type Withhold_Kind is (Withhold_None, Withhold_Estate_Naming, Withhold_Typed_No_Attach, Withhold_Typed_No_Consent);

   type Field_Facts is record
      kind             : Field_Kind := Kind_Estate_Naming;
      attach_declared  : Boolean    := False;
      consent_recorded : Boolean    := False;
   end record;

   function Names_Estate (F : Field_Facts) return Boolean is
     (F.kind = Kind_Estate_Naming)
     with Post =>
       ((Names_Estate'Result = (F.kind = Kind_Estate_Naming))
        and then (if Names_Estate'Result then F.kind /= Kind_Measured)
        and then (if Names_Estate'Result then F.kind /= Kind_Emitted));

   function Is_Factory_Origin (F : Field_Facts) return Boolean is
     (F.kind = Kind_Measured or F.kind = Kind_Emitted)
     with Post =>
       ((Is_Factory_Origin'Result = (F.kind = Kind_Measured or F.kind = Kind_Emitted))
        and then (if Is_Factory_Origin'Result then not Names_Estate (F)));

   function Typed_Release_Authorised (F : Field_Facts) return Boolean is
     (F.kind = Kind_Typed and F.attach_declared and F.consent_recorded)
     with Post =>
       ((Typed_Release_Authorised'Result = (F.kind = Kind_Typed and F.attach_declared and F.consent_recorded))
        and then (if not F.attach_declared then not Typed_Release_Authorised'Result)
        and then (if not F.consent_recorded then not Typed_Release_Authorised'Result));

   function Travels (F : Field_Facts) return Boolean is
     (Is_Factory_Origin (F) or Typed_Release_Authorised (F))
     with Post =>
       ((Travels'Result = (Is_Factory_Origin (F) or Typed_Release_Authorised (F)))
        and then (if Names_Estate (F) then not Travels'Result)
        and then (if F.kind = Kind_Typed and not F.attach_declared then not Travels'Result)
        and then (if F.kind = Kind_Typed and not F.consent_recorded then not Travels'Result)
        and then (if Travels'Result then not Names_Estate (F)));

   function Withhold_Reason (F : Field_Facts) return Withhold_Kind is
     (if Names_Estate (F) then Withhold_Estate_Naming
      elsif F.kind = Kind_Typed and not F.attach_declared then Withhold_Typed_No_Attach
      elsif F.kind = Kind_Typed and not F.consent_recorded then Withhold_Typed_No_Consent
      else Withhold_None)
     with Post =>
       (((Withhold_Reason'Result = Withhold_None) = Travels (F))
        and then (if Names_Estate (F) then Withhold_Reason'Result = Withhold_Estate_Naming)
        and then (if Withhold_Reason'Result = Withhold_Typed_No_Attach then F.kind = Kind_Typed and not F.attach_declared)
        and then (if Withhold_Reason'Result = Withhold_Typed_No_Consent then F.kind = Kind_Typed and not F.consent_recorded)
        and then (if Travels (F) then Withhold_Reason'Result = Withhold_None));

end Dossier_Field_Pkg;
