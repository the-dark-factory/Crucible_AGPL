--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: dbfff4de6bcc80b4ce38b5f1282e7bcbbabc6acbf50e7f3d4d290e934c1d7ca3
--
package Body_Requirement_Pkg with SPARK_Mode is
   --  PURPOSE: has this unit earned emission when no separate body was filled?
   --  A unit whose operations are ALL completed in its specification needs no
   --  body; it earns emission only when its specification's own proof stands --
   --  checks generated, none unproved, no cheat marker, vacuity meaningful.
   --  USAGE: the prove_body edge measures and hands the facts. A unit that HAS
   --  a body is not this package's business: the answer is Not_Applicable.

   subtype Count is Natural range 0 .. 1_000_000;

   type Body_Facts is record
      body_present                 : Boolean := False;
      operation_count              : Count := 0;
      operations_completed_in_spec : Count := 0;
      spec_checks_generated        : Count := 0;
      spec_checks_unproved         : Count := 0;
      cheat_markers                : Count := 0;
      vacuity_meaningful           : Boolean := False;
   end record;

   type Verdict_Kind is
     (Earned_Without_Body, Body_Required, Refused_Empty_Unit, Refused_No_Checks,
      Refused_Unproved, Refused_Cheat, Refused_Vacuous, Not_Applicable);

   function Facts_Consistent (F : Body_Facts) return Boolean
   is (F.operations_completed_in_spec <= F.operation_count
       and then F.spec_checks_unproved <= F.spec_checks_generated)
   with Global => null,
        Post => Facts_Consistent'Result =
                  (F.operations_completed_in_spec <= F.operation_count
                   and then F.spec_checks_unproved <= F.spec_checks_generated);

   function Decide (F : Body_Facts) return Verdict_Kind
   is ((if F.body_present then Not_Applicable
        elsif F.operation_count = 0 then Refused_Empty_Unit
        elsif F.operations_completed_in_spec < F.operation_count then Body_Required
        elsif F.spec_checks_generated = 0 then Refused_No_Checks
        elsif F.spec_checks_unproved > 0 then Refused_Unproved
        elsif F.cheat_markers > 0 then Refused_Cheat
        elsif not F.vacuity_meaningful then Refused_Vacuous
        else Earned_Without_Body))
   with Global => null,
        Pre => Facts_Consistent (F),
        Post => (((Decide'Result = Earned_Without_Body) =
                   (not F.body_present and then F.operation_count > 0
                    and then F.operations_completed_in_spec = F.operation_count
                    and then F.spec_checks_generated > 0 and then F.spec_checks_unproved = 0
                    and then F.cheat_markers = 0 and then F.vacuity_meaningful))
                 and then (if Decide'Result = Earned_Without_Body then F.spec_checks_generated > 0)
                 and then (if Decide'Result = Earned_Without_Body then F.spec_checks_unproved = 0)
                 and then (if Decide'Result = Earned_Without_Body then F.cheat_markers = 0)
                 and then (if Decide'Result = Earned_Without_Body then F.vacuity_meaningful)
                 and then (if Decide'Result = Earned_Without_Body then
                             F.operations_completed_in_spec = F.operation_count and then F.operation_count > 0)
                 and then (if F.body_present then Decide'Result = Not_Applicable)
                 and then (if Decide'Result = Not_Applicable then F.body_present)
                 and then (if not F.body_present and then F.operation_count > 0
                             and then F.operations_completed_in_spec < F.operation_count then Decide'Result = Body_Required)
                 and then (if F.operation_count = 0 then Decide'Result /= Earned_Without_Body));

end Body_Requirement_Pkg;
