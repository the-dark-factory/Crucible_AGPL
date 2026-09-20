--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 05d5631cec8ceee77697b04963f3044eec28d7d4246f349b7e4de90b0d9773e5
--
package Tower_Admission_Pkg with SPARK_Mode is

   type Version_Number is range 0 .. 2_147_483_647;

   type Entry_Facts is record
      well_formed      : Boolean := False;
      signature_valid  : Boolean := False;
      key_known        : Boolean := False;
      receipt_verifies : Boolean := False;
      digest_matches   : Boolean := False;
      in_date          : Boolean := False;
      candidate        : Version_Number := 0;
      running          : Version_Number := 0;
   end record;

   type Owner_Policy is record
      accept_deliveries : Boolean := False;
      floor             : Version_Number := 0;
   end record;

   type Verdict_Kind is (Accepted, Declined_By_Policy, Refused_Receipt, Refused_Integrity);

   function Is_Forward (Candidate : Version_Number; Running : Version_Number) return Boolean
     is (Candidate > Running)
     with Post =>
       (Is_Forward'Result = (Candidate > Running))
       and then (if Candidate = Running then not Is_Forward'Result);

   function Integrity_Holds (F : Entry_Facts) return Boolean
     is (F.well_formed and then F.signature_valid and then F.key_known and then Is_Forward (F.candidate, F.running))
     with Post =>
       (if not F.well_formed then not Integrity_Holds'Result)
       and then (if not F.signature_valid then not Integrity_Holds'Result)
       and then (if not F.key_known then not Integrity_Holds'Result)
       and then (if not Is_Forward (F.candidate, F.running) then not Integrity_Holds'Result);

   function Receipt_Holds (F : Entry_Facts) return Boolean
     is (F.receipt_verifies and then F.digest_matches)
     with Post =>
       (Receipt_Holds'Result = (F.receipt_verifies and then F.digest_matches));

   function Policy_Permits (F : Entry_Facts; P : Owner_Policy) return Boolean
     is (P.accept_deliveries and then F.candidate >= P.floor and then F.in_date)
     with Post =>
       (Policy_Permits'Result = (P.accept_deliveries and then F.candidate >= P.floor and then F.in_date))
       and then (if not F.in_date then not Policy_Permits'Result);

   function Decide (F : Entry_Facts; P : Owner_Policy) return Verdict_Kind
     is ((if not Integrity_Holds (F) then Refused_Integrity
          elsif not Receipt_Holds (F) then Refused_Receipt
          elsif not Policy_Permits (F, P) then Declined_By_Policy
          else Accepted))
     with Post =>
       (((Decide'Result = Accepted) = (Integrity_Holds (F) and then Receipt_Holds (F) and then Policy_Permits (F, P))))
       and then (if not Integrity_Holds (F) then Decide'Result = Refused_Integrity)
       and then (if Integrity_Holds (F) and then not Receipt_Holds (F) then Decide'Result = Refused_Receipt)
       and then (if Decide'Result = Declined_By_Policy then Integrity_Holds (F) and then Receipt_Holds (F))
       and then (if not P.accept_deliveries then Decide'Result /= Accepted)
       and then (if F.candidate < P.floor then Decide'Result /= Accepted)
       and then (if Decide'Result = Accepted then F.receipt_verifies and then F.digest_matches and then F.key_known and then F.in_date)
       and then (if not F.in_date then Decide'Result /= Accepted)
       and then (if Integrity_Holds (F) and then Receipt_Holds (F) and then not F.in_date then Decide'Result = Declined_By_Policy);

   function Leaves_Tower_Unchanged (V : Verdict_Kind) return Boolean
     is (V /= Accepted)
     with Post =>
       (Leaves_Tower_Unchanged'Result = (V /= Accepted));

   function Is_Recorded (V : Verdict_Kind) return Boolean
     is (V = Accepted or else V = Declined_By_Policy or else V = Refused_Receipt or else V = Refused_Integrity)
     with Post =>
       (Is_Recorded'Result);

end Tower_Admission_Pkg;
