--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 9e6f6986fbd1f1bbe064ed1872a85db74aaca7041aedeab52f48e274ba1636d3
--
package Promotion_Pkg with SPARK_Mode is

   Max_Rounds : constant := 64;

   subtype Count is Natural range 0 .. 100_000;

   type Case_Facts is record
      sealed               : Boolean := False;
      round_reached        : Count := 0;
      cap_round            : Count := 0;
      plateau_run          : Count := 0;
      operator_plateau     : Count := 0;
      plateau_floor        : Count := 0;
      later_accepted_round : Boolean := False;
      advice_heard         : Boolean := False;
      advice_rail_answered : Boolean := False;
      advice_wait_elapsed  : Boolean := False;
      cases_this_period    : Count := 0;
      cases_ceiling        : Count := 0;
   end record;

   function Effective_Plateau (F : Case_Facts) return Count is
     ((if F.operator_plateau > F.plateau_floor then F.operator_plateau else F.plateau_floor))
   with Post =>
     (Effective_Plateau'Result >= F.operator_plateau and
      Effective_Plateau'Result >= F.plateau_floor and
      (Effective_Plateau'Result = F.operator_plateau or
       Effective_Plateau'Result = F.plateau_floor));

   function Exhausted (F : Case_Facts) return Boolean is
     ((if F.cap_round >= 1 then F.round_reached >= F.cap_round else False) or
      ((if F.operator_plateau > F.plateau_floor then F.operator_plateau else F.plateau_floor) >= 1 and
       F.plateau_run >= (if F.operator_plateau > F.plateau_floor then F.operator_plateau else F.plateau_floor)))
   with Post =>
     (Exhausted'Result =
        ((if F.cap_round >= 1 then F.round_reached >= F.cap_round else False) or
         ((if F.operator_plateau > F.plateau_floor then F.operator_plateau else F.plateau_floor) >= 1 and
          F.plateau_run >= (if F.operator_plateau > F.plateau_floor then F.operator_plateau else F.plateau_floor))) and
      (if F.cap_round = 0 and (if F.operator_plateau > F.plateau_floor then F.operator_plateau else F.plateau_floor) = 0
       then not Exhausted'Result));

   function Advice_Settled (F : Case_Facts) return Boolean is
     (F.advice_heard or (not F.advice_rail_answered and F.advice_wait_elapsed))
   with Post =>
     (Advice_Settled'Result = (F.advice_heard or (not F.advice_rail_answered and F.advice_wait_elapsed)) and
      (if F.advice_rail_answered and not F.advice_heard then not Advice_Settled'Result));

   function Under_Ceiling (F : Case_Facts) return Boolean is
     (F.cases_this_period < F.cases_ceiling)
   with Post =>
     (Under_Ceiling'Result = (F.cases_this_period < F.cases_ceiling) and
      (if F.cases_ceiling = 0 then not Under_Ceiling'Result));

   function May_Promote (F : Case_Facts) return Boolean is
     (F.sealed and
      Exhausted (F) and
      not F.later_accepted_round and
      Advice_Settled (F) and
      Under_Ceiling (F))
   with Post =>
     (May_Promote'Result = (F.sealed and
                            Exhausted (F) and
                            not F.later_accepted_round and
                            Advice_Settled (F) and
                            Under_Ceiling (F)) and
      (if F.later_accepted_round then not May_Promote'Result) and
      (if not F.sealed then not May_Promote'Result) and
      (if May_Promote'Result then Exhausted (F) and Advice_Settled (F) and Under_Ceiling (F)) and
      (if F.cases_this_period >= F.cases_ceiling then not May_Promote'Result) and
      (if May_Promote'Result then not F.later_accepted_round and F.sealed));

end Promotion_Pkg;
