--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: eae633cf59beb38b0188b3038ff2a7a8a463b6b484b7b68e306fd13fc4644e55
--
with Vacuity_Facts_Pkg;

package Vacuity_Rail_Pkg with SPARK_Mode is

   type Request_Facts is record
      rail_is_vacuity  : Boolean := False;
      endpoint_on_estate : Boolean := False;
      unit_bytes       : Natural := 0;
      max_unit_bytes   : Natural := 0;
   end record;

   type Reply_Facts is record
      connected        : Boolean := False;
      timed_out        : Boolean := False;
      reply_complete   : Boolean := False;
      reply_well_formed : Boolean := False;
      digest_matches   : Boolean := False;
      battery_identified : Boolean := False;
      facts            : Vacuity_Facts_Pkg.Facts_Type;
   end record;

   type Outcome_Kind is
     (Outcome_Not_Sent,
      Outcome_Vacuity_Unreachable,
      Outcome_Unmeasured,
      Outcome_Reply_Refused,
      Outcome_Hollow,
      Outcome_Meaningful);

   function May_Send (R : Request_Facts) return Boolean is
     (R.rail_is_vacuity and R.endpoint_on_estate and R.unit_bytes >= 1 and R.unit_bytes <= R.max_unit_bytes)
   with Post =>
     (May_Send'Result = (R.rail_is_vacuity and R.endpoint_on_estate and R.unit_bytes >= 1 and R.unit_bytes <= R.max_unit_bytes)) and
     ((if not R.endpoint_on_estate then not May_Send'Result));

   function Reply_Trustworthy (P : Reply_Facts) return Boolean is
     (P.connected and not P.timed_out and P.reply_complete and P.reply_well_formed and P.digest_matches and P.battery_identified)
   with Post =>
     (Reply_Trustworthy'Result = (P.connected and not P.timed_out and P.reply_complete and P.reply_well_formed and P.digest_matches and P.battery_identified));

   function Contract_Meaningful (P : Reply_Facts) return Boolean is
     (Vacuity_Facts_Pkg.Is_Meaningful (P.facts))
   with Post =>
     (Contract_Meaningful'Result = Vacuity_Facts_Pkg.Is_Meaningful (P.facts));

   function Decide (R : Request_Facts; P : Reply_Facts) return Outcome_Kind is
     ((if not May_Send (R) then Outcome_Not_Sent elsif not P.connected then Outcome_Vacuity_Unreachable elsif P.timed_out then Outcome_Unmeasured elsif not Reply_Trustworthy (P) then Outcome_Reply_Refused elsif Contract_Meaningful (P) then Outcome_Meaningful else Outcome_Hollow))
   with Post =>
     (((Decide'Result = Outcome_Meaningful) = (May_Send (R) and Reply_Trustworthy (P) and Contract_Meaningful (P)))) and
     ((if not May_Send (R) then Decide'Result = Outcome_Not_Sent)) and
     ((if May_Send (R) and not P.connected then Decide'Result = Outcome_Vacuity_Unreachable)) and
     ((if May_Send (R) and P.connected and P.timed_out then Decide'Result = Outcome_Unmeasured)) and
     ((if Decide'Result = Outcome_Meaningful then P.connected and not P.timed_out and P.digest_matches)) and
     ((if Decide'Result = Outcome_Hollow then May_Send (R) and Reply_Trustworthy (P) and not Contract_Meaningful (P))) and
     ((if not Contract_Meaningful (P) then Decide'Result /= Outcome_Meaningful));

   function Is_Pass (O : Outcome_Kind) return Boolean is
     (O = Outcome_Meaningful)
   with Post =>
     ((Is_Pass'Result = (O = Outcome_Meaningful))) and
     ((if O = Outcome_Not_Sent then not Is_Pass'Result)) and
     ((if O = Outcome_Vacuity_Unreachable then not Is_Pass'Result)) and
     ((if O = Outcome_Unmeasured then not Is_Pass'Result)) and
     ((if O = Outcome_Reply_Refused then not Is_Pass'Result)) and
     ((if O = Outcome_Hollow then not Is_Pass'Result));

end Vacuity_Rail_Pkg;
