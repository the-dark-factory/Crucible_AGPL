--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged by ANVIL through the lane, ab-20260911-1758, on Tony's command (lane enabled 17:57, disabled after).
--  Proved: zero unproved, zero justified, zero cheat markers. Carried here unchanged — a header may be
--  added, a contract may not drift.
--
package Edition_Licence_Pkg with SPARK_Mode is

   type Edition_Type is (Agpl, Commercial);

   type Requested_Licence_Type is
     (Agpl_Licence, Mit_Licence, Proprietary_Licence, Other_Licence);

   type Reason_Type is (Permitted, Edition_Is_Agpl_Only);

   type Verdict_Type is record
      edition   : Edition_Type := Agpl;
      requested : Requested_Licence_Type := Agpl_Licence;
      refused   : Boolean := False;
      reason    : Reason_Type := Permitted;
   end record;

   function Permits (edition : Edition_Type; requested : Requested_Licence_Type) return Boolean
     is ((edition = Commercial) or (requested = Agpl_Licence))
     with Post =>
       ((Permits'Result = True) = ((edition = Commercial) or (requested = Agpl_Licence))) and then
       (if edition = Agpl and then requested /= Agpl_Licence then Permits'Result = False) and then
       (if requested = Agpl_Licence then Permits'Result = True);

   function Refusal_Reason (edition : Edition_Type; requested : Requested_Licence_Type) return Reason_Type
     is (if Permits (edition, requested) then Permitted else Edition_Is_Agpl_Only)
     with Post =>
       ((Refusal_Reason'Result = Permitted) = Permits (edition, requested));

   function Decide (edition : Edition_Type; requested : Requested_Licence_Type) return Verdict_Type
     is ((edition => edition, requested => requested, refused => not Permits (edition, requested), reason => Refusal_Reason (edition, requested)))
     with Post =>
       (Decide'Result.edition = edition) and then
       (Decide'Result.requested = requested) and then
       ((Decide'Result.refused = True) = (Permits (edition, requested) = False)) and then
       (Decide'Result.reason = Refusal_Reason (edition, requested)) and then
       (if edition = Commercial then Decide'Result.refused = False);

   function Is_Refused (v : Verdict_Type) return Boolean
     is (v.refused)
     with Post =>
       (Is_Refused'Result = v.refused);

end Edition_Licence_Pkg;
