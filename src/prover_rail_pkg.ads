--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 9ea831dd78c4f5c51613ac2b79dc1f3326fa6c2b30dd6dfc3f489042d52d99ee
--
with Prover_Verdict_Pkg;

package Prover_Rail_Pkg with SPARK_Mode is

   type Request_Facts is record
      rail_is_prover  : Boolean := False;
      endpoint_on_estate : Boolean := False;
      unit_bytes      : Natural := 0;
      max_unit_bytes  : Natural := 0;
      level_demanded  : Natural := 0;
   end record;

   type Reply_Facts is record
      connected        : Boolean := False;
      timed_out        : Boolean := False;
      reply_complete   : Boolean := False;
      reply_well_formed : Boolean := False;
      digest_matches   : Boolean := False;
      prover_identified : Boolean := False;
      run              : Prover_Verdict_Pkg.Facts_Type;
   end record;

   type Outcome_Kind is
     (Outcome_Not_Sent,
      Outcome_Prover_Unreachable,
      Outcome_Unmeasured,
      Outcome_Reply_Refused,
      Outcome_Not_Proved,
      Outcome_Proved);

   function May_Send (R : Request_Facts) return Boolean is
     (R.rail_is_prover and then R.endpoint_on_estate and then
      R.unit_bytes >= 1 and then R.unit_bytes <= R.max_unit_bytes and then
      R.level_demanded >= 2)
   with Post =>
     (May_Send'Result =
        (R.rail_is_prover and then R.endpoint_on_estate and then
         R.unit_bytes >= 1 and then R.unit_bytes <= R.max_unit_bytes and then
         R.level_demanded >= 2))
     and then
     ((if not R.endpoint_on_estate then May_Send'Result = False));

   function Reply_Trustworthy (P : Reply_Facts) return Boolean is
     (P.connected and then not P.timed_out and then
      P.reply_complete and then P.reply_well_formed and then
      P.digest_matches and then P.prover_identified)
   with Post =>
     (Reply_Trustworthy'Result =
        (P.connected and then not P.timed_out and then
         P.reply_complete and then P.reply_well_formed and then
         P.digest_matches and then P.prover_identified));

   function Run_Proved (P : Reply_Facts) return Boolean is
     (Prover_Verdict_Pkg.Assemble (P.run).unit_is_proved)
   with Post =>
     (Run_Proved'Result = Prover_Verdict_Pkg.Assemble (P.run).unit_is_proved);

   function Decide (R : Request_Facts; P : Reply_Facts) return Outcome_Kind is
     ((if not May_Send (R) then Outcome_Not_Sent
       elsif not P.connected then Outcome_Prover_Unreachable
       elsif P.timed_out then Outcome_Unmeasured
       elsif not Reply_Trustworthy (P) then Outcome_Reply_Refused
       elsif Run_Proved (P) then Outcome_Proved
       else Outcome_Not_Proved))
   with Post =>
     (((Decide'Result = Outcome_Proved) =
        (May_Send (R) and then Reply_Trustworthy (P) and then Run_Proved (P))))
     and then
     ((if not May_Send (R) then Decide'Result = Outcome_Not_Sent))
     and then
     ((if May_Send (R) and then not P.connected then
        Decide'Result = Outcome_Prover_Unreachable))
     and then
     ((if May_Send (R) and then P.connected and then P.timed_out then
        Decide'Result = Outcome_Unmeasured))
     and then
     ((if Decide'Result = Outcome_Proved then
        P.connected and then not P.timed_out and then P.digest_matches));

   function Is_Pass (O : Outcome_Kind) return Boolean is
     (O = Outcome_Proved)
   with Post =>
     (Is_Pass'Result = (O = Outcome_Proved))
     and then
     ((if O = Outcome_Not_Sent then not Is_Pass'Result))
     and then
     ((if O = Outcome_Prover_Unreachable then not Is_Pass'Result))
     and then
     ((if O = Outcome_Unmeasured then not Is_Pass'Result))
     and then
     ((if O = Outcome_Reply_Refused then not Is_Pass'Result));

end Prover_Rail_Pkg;
