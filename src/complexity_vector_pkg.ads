--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: bb227d426403f1165ff2fb62f572810942531bc5339c6d0be34e1125555714ca
--
with Bounty_Pkg;
with Bawbee_Ledger_Pkg;
with Proof_Receipt_Pkg;

package Complexity_Vector_Pkg with SPARK_Mode is
   --  PURPOSE: the three priced axes of a case -- rounds burned, unproved at
   --  parking, carried packages -- as the lane measured them: in range, written
   --  as a vector field that says exactly those numbers, copied without change
   --  into the receipt, and priced by Bounty_Pkg's own formula.
   --  USAGE: the sender's edge reads the lane's records and hands numbers,
   --  text and facts; the vector is a dossier line, frozen by the case id.

   function In_Range (R, U, D : Natural) return Boolean
   is (R <= Bawbee_Ledger_Pkg.Max_Axis and then U <= Bawbee_Ledger_Pkg.Max_Axis and then D <= Bawbee_Ledger_Pkg.Max_Axis)
   with Global => null,
        Post => In_Range'Result = (R <= Bawbee_Ledger_Pkg.Max_Axis and then U <= Bawbee_Ledger_Pkg.Max_Axis and then D <= Bawbee_Ledger_Pkg.Max_Axis)
               and then (if R > Bawbee_Ledger_Pkg.Max_Axis then not In_Range'Result);

   function Field_Says (S : String; R, U, D : Bounty_Pkg.Axis) return Boolean
   is ((Proof_Receipt_Pkg.Is_Vector_Field (S)
        and then S /= Proof_Receipt_Pkg.Absent_Vector
        and then Bawbee_Ledger_Pkg.Four_Digits
                   (S (S'First), S (S'First + 1), S (S'First + 2), S (S'First + 3)) = R
        and then Bawbee_Ledger_Pkg.Four_Digits
                   (S (S'First + 5), S (S'First + 6), S (S'First + 7), S (S'First + 8)) = U
        and then Bawbee_Ledger_Pkg.Four_Digits
                   (S (S'First + 10), S (S'First + 11), S (S'First + 12), S (S'First + 13)) = D))
   with Global => null,
        Post => Field_Says'Result = ((Proof_Receipt_Pkg.Is_Vector_Field (S)
                                      and then S /= Proof_Receipt_Pkg.Absent_Vector
                                      and then Bawbee_Ledger_Pkg.Four_Digits
                                                (S (S'First), S (S'First + 1), S (S'First + 2), S (S'First + 3)) = R
                                      and then Bawbee_Ledger_Pkg.Four_Digits
                                                (S (S'First + 5), S (S'First + 6), S (S'First + 7), S (S'First + 8)) = U
                                      and then Bawbee_Ledger_Pkg.Four_Digits
                                                (S (S'First + 10), S (S'First + 11), S (S'First + 12), S (S'First + 13)) = D))
               and then (if Field_Says'Result then Proof_Receipt_Pkg.Is_Vector_Field (S))
               and then (if Field_Says'Result then S /= Proof_Receipt_Pkg.Absent_Vector);

   function Field_Matches (Receipt_Field : String; Dossier_Field : String) return Boolean
   is (Receipt_Field = Dossier_Field)
   with Global => null,
        Pre => Proof_Receipt_Pkg.Is_Vector_Field (Receipt_Field)
              and then Proof_Receipt_Pkg.Is_Vector_Field (Dossier_Field),
        Post => Field_Matches'Result = (Receipt_Field = Dossier_Field);

   function Priced (R, U, D : Bounty_Pkg.Axis) return Bounty_Pkg.Bawbee
   is (R + 2 * U + 3 * D)
   with Global => null,
        Post => Priced'Result = (R + 2 * U + 3 * D);

   function Agrees_With_Bounty (P : Bounty_Pkg.Pay_Facts) return Boolean
   is (Priced (P.vector_rounds, P.vector_unproved, P.vector_carried_deps) = Bounty_Pkg.Amount (P))
   with Global => null,
        Post => Agrees_With_Bounty'Result = (Priced (P.vector_rounds, P.vector_unproved, P.vector_carried_deps) = Bounty_Pkg.Amount (P))
               and then Agrees_With_Bounty'Result;

   type Measure_Facts is record
      have_case              : Boolean := False;
      rounds_from_lane       : Boolean := False;
      unproved_from_prover   : Boolean := False;
      carried_from_provenance : Boolean := False;
      in_range               : Boolean := False;
      field_ok               : Boolean := False;
      in_dossier_before_hash : Boolean := False;
   end record;

   type Outcome_Kind is
     (Out_Measured, Out_Refused_No_Case, Out_Refused_Rounds_Unmeasured,
      Out_Refused_Unproved_Unmeasured, Out_Refused_Carried_Unmeasured,
      Out_Refused_Axis_Out_Of_Range, Out_Refused_Field_Malformed,
      Out_Refused_Not_Frozen);

   function Outcome (F : Measure_Facts) return Outcome_Kind
   is ((if not F.have_case then Out_Refused_No_Case
        elsif not F.rounds_from_lane then Out_Refused_Rounds_Unmeasured
        elsif not F.unproved_from_prover then Out_Refused_Unproved_Unmeasured
        elsif not F.carried_from_provenance then Out_Refused_Carried_Unmeasured
        elsif not F.in_range then Out_Refused_Axis_Out_Of_Range
        elsif not F.field_ok then Out_Refused_Field_Malformed
        elsif not F.in_dossier_before_hash then Out_Refused_Not_Frozen
        else Out_Measured))
   with Global => null,
        Post => ((Outcome'Result = Out_Measured) =
                  (F.have_case and then F.rounds_from_lane and then F.unproved_from_prover
                   and then F.carried_from_provenance and then F.in_range
                   and then F.field_ok and then F.in_dossier_before_hash))
               and then (if not F.have_case then Outcome'Result = Out_Refused_No_Case)
               and then (if not F.rounds_from_lane then Outcome'Result /= Out_Measured)
               and then (if not F.in_range then Outcome'Result /= Out_Measured)
               and then (if not F.in_dossier_before_hash then Outcome'Result /= Out_Measured);

end Complexity_Vector_Pkg;
