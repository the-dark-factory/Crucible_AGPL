--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 924c2bd9e88d746b9b54d351cb6f18ec349982167798b321cb876bc09c73a368
--
package Bounty_Pkg with SPARK_Mode is

   subtype Axis is Natural range 0 .. 1_000;
   subtype Bawbee is Natural range 0 .. 6_000;
   subtype Count is Natural range 0 .. 100_000;

   type Receipt_Kind is (Receipt_None, Receipt_Admission, Receipt_Palais_Proof, Receipt_In_Situ, Receipt_Build);

   type Payee_Kind is (Payee_Contributor, Payee_Solver);

   type Pay_Facts is record
      receipt                    : Receipt_Kind := Receipt_None;
      payee                      : Payee_Kind := Payee_Contributor;
      already_paid_for_receipt   : Boolean := True;
      solver_is_contributor      : Boolean := True;
      paid_this_period           : Count := 0;
      period_ceiling             : Count := 0;
      fix_is_harness_class       : Boolean := False;
      vector_frozen_at_admission : Boolean := False;
      vector_rounds              : Axis := 0;
      vector_unproved            : Axis := 0;
      vector_carried_deps        : Axis := 0;
   end record;

   function Amount (F : Pay_Facts) return Bawbee is
     (F.vector_rounds + 2 * F.vector_unproved + 3 * F.vector_carried_deps) with
     Post => Amount'Result = F.vector_rounds + 2 * F.vector_unproved + 3 * F.vector_carried_deps and then
            Amount'Result >= F.vector_rounds and then
            Amount'Result >= F.vector_unproved and then
            Amount'Result >= F.vector_carried_deps and then
            (if F.vector_rounds = 0 and then F.vector_unproved = 0 and then F.vector_carried_deps = 0 then Amount'Result = 0);

   function Vector_Usable (F : Pay_Facts) return Boolean is
     (F.vector_frozen_at_admission) with
     Post => Vector_Usable'Result = F.vector_frozen_at_admission and then
            (if not F.vector_frozen_at_admission then not Vector_Usable'Result);

   function Receipt_Present (F : Pay_Facts) return Boolean is
     (F.receipt /= Receipt_None) with
     Post => Receipt_Present'Result = (F.receipt /= Receipt_None) and then
            (if F.receipt = Receipt_None then not Receipt_Present'Result);

   function Harness_Payable (F : Pay_Facts) return Boolean is
     ((not F.fix_is_harness_class) or else F.receipt = Receipt_Build) with
     Post => Harness_Payable'Result = ((not F.fix_is_harness_class) or else F.receipt = Receipt_Build) and then
            (if F.fix_is_harness_class and then F.receipt /= Receipt_Build then not Harness_Payable'Result);

   function Incentive_Permitted (F : Pay_Facts) return Boolean is
     (not (F.payee = Payee_Contributor and then F.solver_is_contributor)) with
     Post => Incentive_Permitted'Result = (not (F.payee = Payee_Contributor and then F.solver_is_contributor)) and then
            (if F.payee = Payee_Contributor and then F.solver_is_contributor then not Incentive_Permitted'Result);

   function May_Pay (F : Pay_Facts) return Boolean is
     (Receipt_Present (F) and then not F.already_paid_for_receipt and then Vector_Usable (F) and then Harness_Payable (F) and then Incentive_Permitted (F) and then F.paid_this_period < F.period_ceiling) with
     Post => May_Pay'Result = (Receipt_Present (F) and then not F.already_paid_for_receipt and then Vector_Usable (F) and then Harness_Payable (F) and then Incentive_Permitted (F) and then F.paid_this_period < F.period_ceiling) and then
            (if F.already_paid_for_receipt then not May_Pay'Result) and then
            (if F.receipt = Receipt_None then not May_Pay'Result) and then
            (if F.fix_is_harness_class and then F.receipt /= Receipt_Build then not May_Pay'Result) and then
            (if F.payee = Payee_Contributor and then F.solver_is_contributor then not May_Pay'Result) and then
            (if not F.vector_frozen_at_admission then not May_Pay'Result) and then
            (if F.paid_this_period >= F.period_ceiling then not May_Pay'Result) and then
            (if May_Pay'Result then not F.already_paid_for_receipt and then F.vector_frozen_at_admission);

end Bounty_Pkg;
