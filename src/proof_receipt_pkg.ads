--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 3e46c917a9687db3ec84a272b10e7c493278769658cacd1bfa79fd96dde232e5
--
with Bawbee_Ledger_Pkg;

package Proof_Receipt_Pkg with SPARK_Mode is
   --  PURPOSE: what the Palais judges before it issues a proof receipt for one
   --  submission -- proved, on an isolated bench, against the case's frozen
   --  contract -- and what one receipt line is. A refused submission gets no
   --  receipt: the only verdict the line can carry is proved-isolated.
   --  USAGE: the edge measures and hands text and facts, signs the line with
   --  the df-palais key, and the Bawbee edge reads the same line to mint.

   Kind_Last      : constant := 15;
   Case_First     : constant := 17;
   Case_Last      : constant := 80;
   Sub_First      : constant := 82;
   Sub_Last       : constant := 145;
   Contract_First : constant := 147;
   Contract_Last  : constant := 210;
   Cert_First     : constant := 212;
   Cert_Last      : constant := 275;
   Verdict_First  : constant := 277;
   Verdict_Last   : constant := 291;
   Vector_First   : constant := 293;
   Vector_Last    : constant := 306;
   Stamp_First    : constant := 308;
   Stamp_Last     : constant := 327;
   Solver_First   : constant := 329;
   Receipt_Max    : constant := 456;

   Palais_Kind   : constant String (1 .. 15) := "palais-proof-v1";
   Insitu_Kind   : constant String (1 .. 15) := "insitu-proof-v1";
   Verdict_Text  : constant String (1 .. 15) := "proved-isolated";
   Absent_Vector : constant String (1 .. 14) :=
     "----" & Bawbee_Ledger_Pkg.Tab & "----" & Bawbee_Ledger_Pkg.Tab & "----";

   function Is_Axis_At (S : String; I : Integer) return Boolean
   is ((for all J in I .. I + 3 => S (J) in '0' .. '9')
       and then Bawbee_Ledger_Pkg.Four_Digits (S (I), S (I + 1), S (I + 2), S (I + 3)) <= Bawbee_Ledger_Pkg.Max_Axis)
   with Global => null,
        Pre => S'Length >= 4 and then I >= S'First and then I <= S'Last - 3,
        Post => Is_Axis_At'Result = ((for all J in I .. I + 3 => S (J) in '0' .. '9')
                                    and then Bawbee_Ledger_Pkg.Four_Digits (S (I), S (I + 1), S (I + 2), S (I + 3)) <= Bawbee_Ledger_Pkg.Max_Axis);

   function Is_Vector_Field (S : String) return Boolean
   is ((S'Length = 14
        and then (S = Absent_Vector
                  or else (Is_Axis_At (S, S'First)
                           and then S (S'First + 4) = Bawbee_Ledger_Pkg.Tab
                           and then Is_Axis_At (S, S'First + 5)
                           and then S (S'First + 9) = Bawbee_Ledger_Pkg.Tab
                           and then Is_Axis_At (S, S'First + 10)))))
   with Global => null,
        Post => Is_Vector_Field'Result = ((S'Length = 14
                                           and then (S = Absent_Vector
                                                     or else (Is_Axis_At (S, S'First)
                                                              and then S (S'First + 4) = Bawbee_Ledger_Pkg.Tab
                                                              and then Is_Axis_At (S, S'First + 5)
                                                              and then S (S'First + 9) = Bawbee_Ledger_Pkg.Tab
                                                              and then Is_Axis_At (S, S'First + 10)))))
               and then (if Is_Vector_Field'Result then S'Length = 14);

   function Is_Stamp (S : String) return Boolean
   is ((S'Length = 20
        and then (for all K in 0 .. 19 =>
                    (if K = 4 or else K = 7 then S (S'First + K) = '-'
                     elsif K = 10 then S (S'First + K) = 'T'
                     elsif K = 13 or else K = 16 then S (S'First + K) = ':'
                     elsif K = 19 then S (S'First + K) = 'Z'
                     else S (S'First + K) in '0' .. '9'))))
   with Global => null,
        Post => Is_Stamp'Result = ((S'Length = 20
                                   and then (for all K in 0 .. 19 =>
                                               (if K = 4 or else K = 7 then S (S'First + K) = '-'
                                                elsif K = 10 then S (S'First + K) = 'T'
                                                elsif K = 13 or else K = 16 then S (S'First + K) = ':'
                                                elsif K = 19 then S (S'First + K) = 'Z'
                                                else S (S'First + K) in '0' .. '9'))))
               and then (if Is_Stamp'Result then S'Length = 20);

   function Is_Receipt (S : String) return Boolean
   is ((S'Length >= Solver_First
        and then S'Length <= Receipt_Max
        and then (S (1 .. Kind_Last) = Palais_Kind or else S (1 .. Kind_Last) = Insitu_Kind)
        and then S (Kind_Last + 1) = Bawbee_Ledger_Pkg.Tab
        and then Bawbee_Ledger_Pkg.Is_Hex64 (S (Case_First .. Case_Last))
        and then S (Case_Last + 1) = Bawbee_Ledger_Pkg.Tab
        and then Bawbee_Ledger_Pkg.Is_Hex64 (S (Sub_First .. Sub_Last))
        and then S (Sub_Last + 1) = Bawbee_Ledger_Pkg.Tab
        and then Bawbee_Ledger_Pkg.Is_Hex64 (S (Contract_First .. Contract_Last))
        and then S (Contract_Last + 1) = Bawbee_Ledger_Pkg.Tab
        and then Bawbee_Ledger_Pkg.Is_Hex64 (S (Cert_First .. Cert_Last))
        and then S (Cert_Last + 1) = Bawbee_Ledger_Pkg.Tab
        and then S (Verdict_First .. Verdict_Last) = Verdict_Text
        and then S (Verdict_Last + 1) = Bawbee_Ledger_Pkg.Tab
        and then Is_Vector_Field (S (Vector_First .. Vector_Last))
        and then S (Vector_Last + 1) = Bawbee_Ledger_Pkg.Tab
        and then Is_Stamp (S (Stamp_First .. Stamp_Last))
        and then S (Stamp_Last + 1) = Bawbee_Ledger_Pkg.Tab
        and then Bawbee_Ledger_Pkg.Is_Principal (S (Solver_First .. S'Last))))
   with Global => null,
        Pre => S'First = 1,
        Post => Is_Receipt'Result = ((S'Length >= Solver_First
                                     and then S'Length <= Receipt_Max
                                     and then (S (1 .. Kind_Last) = Palais_Kind or else S (1 .. Kind_Last) = Insitu_Kind)
                                     and then S (Kind_Last + 1) = Bawbee_Ledger_Pkg.Tab
                                     and then Bawbee_Ledger_Pkg.Is_Hex64 (S (Case_First .. Case_Last))
                                     and then S (Case_Last + 1) = Bawbee_Ledger_Pkg.Tab
                                     and then Bawbee_Ledger_Pkg.Is_Hex64 (S (Sub_First .. Sub_Last))
                                     and then S (Sub_Last + 1) = Bawbee_Ledger_Pkg.Tab
                                     and then Bawbee_Ledger_Pkg.Is_Hex64 (S (Contract_First .. Contract_Last))
                                     and then S (Contract_Last + 1) = Bawbee_Ledger_Pkg.Tab
                                     and then Bawbee_Ledger_Pkg.Is_Hex64 (S (Cert_First .. Cert_Last))
                                     and then S (Cert_Last + 1) = Bawbee_Ledger_Pkg.Tab
                                     and then S (Verdict_First .. Verdict_Last) = Verdict_Text
                                     and then S (Verdict_Last + 1) = Bawbee_Ledger_Pkg.Tab
                                     and then Is_Vector_Field (S (Vector_First .. Vector_Last))
                                     and then S (Vector_Last + 1) = Bawbee_Ledger_Pkg.Tab
                                     and then Is_Stamp (S (Stamp_First .. Stamp_Last))
                                     and then S (Stamp_Last + 1) = Bawbee_Ledger_Pkg.Tab
                                     and then Bawbee_Ledger_Pkg.Is_Principal (S (Solver_First .. S'Last))))
               and then (if Is_Receipt'Result then S'Length in Solver_First .. Receipt_Max)
               and then (if Is_Receipt'Result then S (Verdict_First .. Verdict_Last) = Verdict_Text);

   function Is_Palais_Receipt (S : String) return Boolean
   is (S (1 .. Kind_Last) = Palais_Kind)
   with Global => null,
        Pre => S'First = 1 and then Is_Receipt (S),
        Post => Is_Palais_Receipt'Result = (S (1 .. Kind_Last) = Palais_Kind);

   function Has_Vector (S : String) return Boolean
   is (S (Vector_First .. Vector_Last) /= Absent_Vector)
   with Global => null,
        Pre => S'First = 1 and then Is_Receipt (S),
        Post => Has_Vector'Result = (S (Vector_First .. Vector_Last) /= Absent_Vector)
               and then (if Has_Vector'Result then Is_Axis_At (S, Vector_First));

   type Issue_Facts is record
      have_submission  : Boolean := False;
      lease_live       : Boolean := False;
      submitter_signed : Boolean := False;
      solver_named     : Boolean := False;
      contract_matches : Boolean := False;
      bench_isolated   : Boolean := False;
      compiled         : Boolean := False;
      proved           : Boolean := False;
      no_cheat         : Boolean := False;
      receipt_ok       : Boolean := False;
      signed           : Boolean := False;
      written          : Boolean := False;
   end record;

   type Outcome_Kind is
     (Out_Issued, Out_Refused_No_Submission, Out_Refused_No_Lease,
      Out_Refused_Unsigned_Submission, Out_Refused_No_Solver,
      Out_Refused_Contract_Changed, Out_Refused_Bench_Not_Isolated,
      Out_Refused_Compile, Out_Refused_Unproved, Out_Refused_Cheat,
      Out_Refused_Receipt_Malformed, Out_Refused_Sign_Failed,
      Out_Refused_Write_Failed);

   function Outcome (F : Issue_Facts) return Outcome_Kind
   is ((if not F.have_submission then Out_Refused_No_Submission
        elsif not F.lease_live then Out_Refused_No_Lease
        elsif not F.submitter_signed then Out_Refused_Unsigned_Submission
        elsif not F.solver_named then Out_Refused_No_Solver
        elsif not F.contract_matches then Out_Refused_Contract_Changed
        elsif not F.bench_isolated then Out_Refused_Bench_Not_Isolated
        elsif not F.compiled then Out_Refused_Compile
        elsif not F.proved then Out_Refused_Unproved
        elsif not F.no_cheat then Out_Refused_Cheat
        elsif not F.receipt_ok then Out_Refused_Receipt_Malformed
        elsif not F.signed then Out_Refused_Sign_Failed
        elsif not F.written then Out_Refused_Write_Failed
        else Out_Issued))
   with Global => null,
        Post => ((Outcome'Result = Out_Issued) =
                  (F.have_submission and then F.lease_live and then F.submitter_signed
                   and then F.solver_named and then F.contract_matches and then F.bench_isolated
                   and then F.compiled and then F.proved and then F.no_cheat
                   and then F.receipt_ok and then F.signed and then F.written))
               and then (if not F.have_submission then Outcome'Result = Out_Refused_No_Submission)
               and then (if not F.contract_matches then Outcome'Result /= Out_Issued)
               and then (if not F.bench_isolated then Outcome'Result /= Out_Issued)
               and then (if not F.proved then Outcome'Result /= Out_Issued)
               and then (if not F.no_cheat then Outcome'Result /= Out_Issued)
               and then (if not F.signed then Outcome'Result /= Out_Issued);

end Proof_Receipt_Pkg;
