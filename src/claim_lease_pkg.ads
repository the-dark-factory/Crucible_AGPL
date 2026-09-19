--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 81f16dc7d013b716815348b6bf6c88e48efb8e586536d6dd6254f1a37e0d0ced
--
package Claim_Lease_Pkg with SPARK_Mode is

   subtype Count is Natural range 0 .. 100_000;

   type Lease_Facts is record
      enrolled              : Boolean := False;
      present               : Boolean := False;
      active_claims         : Count := 0;
      claim_cap             : Count := 0;
      lapses_this_period    : Count := 0;
      held_seconds          : Count := 0;
      minimum_window        : Count := 0;
      proof_run_since_claim : Boolean := False;
      claimed_by_other      : Boolean := True;
      in_offer_window       : Boolean := False;
      offer_rank_first      : Boolean := False;
   end record;

   function Effective_Cap (F : Lease_Facts) return Count is
     (if F.lapses_this_period >= F.claim_cap then 0 else F.claim_cap - F.lapses_this_period) with Post =>
       Effective_Cap'Result <= F.claim_cap and
       (if F.lapses_this_period >= F.claim_cap then Effective_Cap'Result = 0) and
       (if F.lapses_this_period = 0 then Effective_Cap'Result = F.claim_cap);

   function Has_Capacity (F : Lease_Facts) return Boolean is
     (F.enrolled and then F.present and then F.active_claims < Effective_Cap (F)) with Post =>
       (Has_Capacity'Result = (F.enrolled and then F.present and then F.active_claims < Effective_Cap (F))) and
       (if not F.enrolled then not Has_Capacity'Result) and
       (if not F.present then not Has_Capacity'Result) and
       (if Effective_Cap (F) = 0 then not Has_Capacity'Result);

   function Offer_Permits (F : Lease_Facts) return Boolean is
     (not F.in_offer_window or else F.offer_rank_first) with Post =>
       (Offer_Permits'Result = (not F.in_offer_window or else F.offer_rank_first)) and
       (if F.in_offer_window and then not F.offer_rank_first then not Offer_Permits'Result);

   function May_Claim (F : Lease_Facts) return Boolean is
     (Has_Capacity (F) and then not F.claimed_by_other and then Offer_Permits (F)) with Post =>
       (May_Claim'Result = (Has_Capacity (F) and then not F.claimed_by_other and then Offer_Permits (F))) and
       (if F.claimed_by_other then not May_Claim'Result) and
       (if not F.enrolled then not May_Claim'Result) and
       (if May_Claim'Result then Has_Capacity (F) and then Offer_Permits (F)) and
       (if F.claim_cap = 0 then not May_Claim'Result);

   function May_Extend (F : Lease_Facts) return Boolean is
     (F.proof_run_since_claim and then F.present and then F.enrolled) with Post =>
       (May_Extend'Result = (F.proof_run_since_claim and then F.present and then F.enrolled)) and
       (if not F.proof_run_since_claim then not May_Extend'Result) and
       (if May_Extend'Result then F.proof_run_since_claim) and
       (if not F.present then not May_Extend'Result);

   function Has_Lapsed (F : Lease_Facts) return Boolean is
     (F.held_seconds >= F.minimum_window and then not May_Extend (F)) with Post =>
       (Has_Lapsed'Result = (F.held_seconds >= F.minimum_window and then not May_Extend (F))) and
       (if F.held_seconds < F.minimum_window then not Has_Lapsed'Result) and
       (if May_Extend (F) then not Has_Lapsed'Result) and
       (if Has_Lapsed'Result then F.held_seconds >= F.minimum_window);

end Claim_Lease_Pkg;
