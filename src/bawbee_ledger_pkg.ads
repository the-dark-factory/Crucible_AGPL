--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 8e82083cd99bd74293c3cec414ee89e194e49d58b167c778c9ef3f814c59f3c9
--
with Bounty_Pkg;

package Bawbee_Ledger_Pkg with SPARK_Mode is
   --  PURPOSE: what the Reef judges before it mints Bawbees for one receipt:
   --  that every ledger row is one well-formed row, that a receipt counts as
   --  minted only by the row's FIRST field, that the chain and the monthly
   --  ceiling hold, and the word for the run -- minted exactly when all hold.
   --  USAGE: the edge reads files, hashes and verifies signatures, and hands
   --  text and facts; the amount is Bounty_Pkg.Amount, never a caller's word.

   Receipt_Last     : constant := 64;
   Month_First      : constant := 66;
   Month_Last       : constant := 72;
   Amount_First     : constant := 74;
   Amount_Last      : constant := 77;
   Rounds_First     : constant := 79;
   Rounds_Last      : constant := 82;
   Unproved_First   : constant := 84;
   Unproved_Last    : constant := 87;
   Deps_First       : constant := 89;
   Deps_Last        : constant := 92;
   Prev_First       : constant := 94;
   Prev_Last        : constant := 157;
   Disclosure_First : constant := 159;
   Disclosure_Last  : constant := 258;
   Payee_First      : constant := 260;
   Max_Principal    : constant := 128;
   Row_Max          : constant := 387;
   Max_Bawbee       : constant := 6_000;
   Max_Axis         : constant := 1_000;
   Ceiling          : constant := 100;

   Tab        : constant Character := Character'Val (9);
   Genesis    : constant String (1 .. 64) := (others => '0');
   Disclosure : constant String (1 .. 100) :=
     "best-effort; 1 Bawbee = 1:1 money, stated not wired; issuer: none yet; priced_by Bounty_Pkg 924c2bd9";

   function Is_Hex64 (S : String) return Boolean
   is (S'Length = 64 and then (for all I in S'Range => S (I) in '0' .. '9' | 'a' .. 'f'))
   with Global => null,
        Post => Is_Hex64'Result = not (S'Length /= 64 or else (for some I in S'Range => S (I) not in '0' .. '9' | 'a' .. 'f')) and then
               (if Is_Hex64'Result then S'Length = 64);

   function Is_Month (S : String) return Boolean
   is (S'Length = 7 and then S (S'First) in '0' .. '9' and then S (S'First + 1) in '0' .. '9' and then S (S'First + 2) in '0' .. '9' and then S (S'First + 3) in '0' .. '9' and then S (S'First + 4) = '-' and then ((S (S'First + 5) = '0' and then S (S'Last) in '1' .. '9') or else (S (S'First + 5) = '1' and then S (S'Last) in '0' .. '2')))
   with Global => null,
        Post => Is_Month'Result = (S'Length = 7 and then S (S'First) in '0' .. '9' and then S (S'First + 1) in '0' .. '9' and then S (S'First + 2) in '0' .. '9' and then S (S'First + 3) in '0' .. '9' and then S (S'First + 4) = '-' and then ((S (S'First + 5) = '0' and then S (S'Last) in '1' .. '9') or else (S (S'First + 5) = '1' and then S (S'Last) in '0' .. '2'))) and then
               (if Is_Month'Result then S'Length = 7);

   function Digit (C : Character) return Natural
   is (Character'Pos (C) - Character'Pos ('0'))
   with Global => null,
        Pre => C in '0' .. '9',
        Post => Digit'Result = (Character'Pos (C) - Character'Pos ('0')) and then
               Digit'Result <= 9;

   function Four_Digits (A, B, C, D : Character) return Natural
   is (1_000 * Digit (A) + 100 * Digit (B) + 10 * Digit (C) + Digit (D))
   with Global => null,
        Pre => A in '0' .. '9' and then B in '0' .. '9' and then C in '0' .. '9' and then D in '0' .. '9',
        Post => Four_Digits'Result = (1_000 * Digit (A) + 100 * Digit (B) + 10 * Digit (C) + Digit (D)) and then
               Four_Digits'Result <= 9_999;

   function Is_Principal (S : String) return Boolean
   is ((S'Length >= 1 and then S'Length <= Max_Principal) and then (for all I in S'Range => S (I) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '@' | '.' | '_' | '-'))
   with Global => null,
        Post => Is_Principal'Result = not (S'Length < 1 or else S'Length > Max_Principal or else (for some I in S'Range => S (I) not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '@' | '.' | '_' | '-')) and then
               (if Is_Principal'Result then S'Length in 1 .. Max_Principal);

   function Is_Row (S : String) return Boolean
   is (S'Length >= Payee_First and then
       S'Length <= Row_Max and then
       Is_Hex64 (S (1 .. Receipt_Last)) and then
       S (Receipt_Last + 1) = Tab and then
       Is_Month (S (Month_First .. Month_Last)) and then
       S (Month_Last + 1) = Tab and then
       S (Amount_First) in '0' .. '9' and then
       S (Amount_First + 1) in '0' .. '9' and then
       S (Amount_First + 2) in '0' .. '9' and then
       S (Amount_Last) in '0' .. '9' and then
       Four_Digits (S (Amount_First), S (Amount_First + 1), S (Amount_First + 2), S (Amount_Last)) <= Max_Bawbee and then
       S (Amount_Last + 1) = Tab and then
       S (Rounds_First) in '0' .. '9' and then
       S (Rounds_First + 1) in '0' .. '9' and then
       S (Rounds_First + 2) in '0' .. '9' and then
       S (Rounds_Last) in '0' .. '9' and then
       Four_Digits (S (Rounds_First), S (Rounds_First + 1), S (Rounds_First + 2), S (Rounds_Last)) <= Max_Axis and then
       S (Rounds_Last + 1) = Tab and then
       S (Unproved_First) in '0' .. '9' and then
       S (Unproved_First + 1) in '0' .. '9' and then
       S (Unproved_First + 2) in '0' .. '9' and then
       S (Unproved_Last) in '0' .. '9' and then
       Four_Digits (S (Unproved_First), S (Unproved_First + 1), S (Unproved_First + 2), S (Unproved_Last)) <= Max_Axis and then
       S (Unproved_Last + 1) = Tab and then
       S (Deps_First) in '0' .. '9' and then
       S (Deps_First + 1) in '0' .. '9' and then
       S (Deps_First + 2) in '0' .. '9' and then
       S (Deps_Last) in '0' .. '9' and then
       Four_Digits (S (Deps_First), S (Deps_First + 1), S (Deps_First + 2), S (Deps_Last)) <= Max_Axis and then
       S (Deps_Last + 1) = Tab and then
       Four_Digits (S (Amount_First), S (Amount_First + 1), S (Amount_First + 2), S (Amount_Last)) =
         Four_Digits (S (Rounds_First), S (Rounds_First + 1), S (Rounds_First + 2), S (Rounds_Last)) +
           2 * Four_Digits (S (Unproved_First), S (Unproved_First + 1), S (Unproved_First + 2), S (Unproved_Last)) +
           3 * Four_Digits (S (Deps_First), S (Deps_First + 1), S (Deps_First + 2), S (Deps_Last)) and then
       Is_Hex64 (S (Prev_First .. Prev_Last)) and then
       S (Prev_Last + 1) = Tab and then
       S (Disclosure_First .. Disclosure_Last) = Disclosure and then
       S (Disclosure_Last + 1) = Tab and then
       Is_Principal (S (Payee_First .. S'Last)))
   with Global => null,
        Pre => S'First = 1,
        Post => Is_Row'Result = (S'Length >= Payee_First and then
                               S'Length <= Row_Max and then
                               Is_Hex64 (S (1 .. Receipt_Last)) and then
                               S (Receipt_Last + 1) = Tab and then
                               Is_Month (S (Month_First .. Month_Last)) and then
                               S (Month_Last + 1) = Tab and then
                               S (Amount_First) in '0' .. '9' and then
                               S (Amount_First + 1) in '0' .. '9' and then
                               S (Amount_First + 2) in '0' .. '9' and then
                               S (Amount_Last) in '0' .. '9' and then
                               Four_Digits (S (Amount_First), S (Amount_First + 1), S (Amount_First + 2), S (Amount_Last)) <= Max_Bawbee and then
                               S (Amount_Last + 1) = Tab and then
                               S (Rounds_First) in '0' .. '9' and then
                               S (Rounds_First + 1) in '0' .. '9' and then
                               S (Rounds_First + 2) in '0' .. '9' and then
                               S (Rounds_Last) in '0' .. '9' and then
                               Four_Digits (S (Rounds_First), S (Rounds_First + 1), S (Rounds_First + 2), S (Rounds_Last)) <= Max_Axis and then
                               S (Rounds_Last + 1) = Tab and then
                               S (Unproved_First) in '0' .. '9' and then
                               S (Unproved_First + 1) in '0' .. '9' and then
                               S (Unproved_First + 2) in '0' .. '9' and then
                               S (Unproved_Last) in '0' .. '9' and then
                               Four_Digits (S (Unproved_First), S (Unproved_First + 1), S (Unproved_First + 2), S (Unproved_Last)) <= Max_Axis and then
                               S (Unproved_Last + 1) = Tab and then
                               S (Deps_First) in '0' .. '9' and then
                               S (Deps_First + 1) in '0' .. '9' and then
                               S (Deps_First + 2) in '0' .. '9' and then
                               S (Deps_Last) in '0' .. '9' and then
                               Four_Digits (S (Deps_First), S (Deps_First + 1), S (Deps_First + 2), S (Deps_Last)) <= Max_Axis and then
                               S (Deps_Last + 1) = Tab and then
                               Four_Digits (S (Amount_First), S (Amount_First + 1), S (Amount_First + 2), S (Amount_Last)) =
                                 Four_Digits (S (Rounds_First), S (Rounds_First + 1), S (Rounds_First + 2), S (Rounds_Last)) +
                                   2 * Four_Digits (S (Unproved_First), S (Unproved_First + 1), S (Unproved_First + 2), S (Unproved_Last)) +
                                   3 * Four_Digits (S (Deps_First), S (Deps_First + 1), S (Deps_First + 2), S (Deps_Last)) and then
                               Is_Hex64 (S (Prev_First .. Prev_Last)) and then
                               S (Prev_Last + 1) = Tab and then
                               S (Disclosure_First .. Disclosure_Last) = Disclosure and then
                               S (Disclosure_Last + 1) = Tab and then
                               Is_Principal (S (Payee_First .. S'Last))) and then
               (if Is_Row'Result then S'Length in Payee_First .. Row_Max);

   function Row_Receipt_Is (Row : String; Digest : String) return Boolean
   is (Row (1 .. Receipt_Last) = Digest)
   with Global => null,
        Pre => Row'First = 1 and then Is_Row (Row) and then Is_Hex64 (Digest),
        Post => Row_Receipt_Is'Result = (Row (1 .. Receipt_Last) = Digest) and then
               (if Row (1 .. Receipt_Last) /= Digest then not Row_Receipt_Is'Result);

   function Row_Prev_Is (Row : String; Sha : String) return Boolean
   is (Row (Prev_First .. Prev_Last) = Sha)
   with Global => null,
        Pre => Row'First = 1 and then Is_Row (Row) and then Is_Hex64 (Sha),
        Post => Row_Prev_Is'Result = (Row (Prev_First .. Prev_Last) = Sha);

   function Row_Counts_For (Row : String; Payee : String; Month : String) return Boolean
   is (Row (Month_First .. Month_Last) = Month and then Row (Payee_First .. Row'Last) = Payee)
   with Global => null,
        Pre => Row'First = 1 and then Is_Row (Row) and then Is_Principal (Payee) and then Is_Month (Month),
        Post => Row_Counts_For'Result = (Row (Month_First .. Month_Last) = Month and then Row (Payee_First .. Row'Last) = Payee);

   function Under_Ceiling (Paid : Bounty_Pkg.Count) return Boolean
   is (Paid < Ceiling)
   with Global => null,
        Post => Under_Ceiling'Result = (Paid < Ceiling) and then
               (if Paid >= Ceiling then not Under_Ceiling'Result);

   type Mint_Facts is record
      have_receipt      : Boolean := False;
      receipt_signed    : Boolean := False;
      verdict_proved    : Boolean := False;
      vector_in_receipt : Boolean := False;
      ledger_is_rows    : Boolean := False;
      chain_holds       : Boolean := False;
      not_already_minted : Boolean := False;
      under_ceiling     : Boolean := False;
      row_ok            : Boolean := False;
      written           : Boolean := False;
   end record;

   type Outcome_Kind is
     (Out_Minted, Out_Refused_No_Receipt, Out_Refused_Unsigned, Out_Refused_Not_Proved,
      Out_Refused_No_Vector, Out_Refused_Ledger_Malformed, Out_Refused_Chain_Broken,
      Out_Refused_Already_Minted, Out_Refused_Over_Ceiling, Out_Refused_May_Pay,
      Out_Refused_Row_Malformed, Out_Refused_Write_Failed);

   function Facts_Agree (F : Mint_Facts; P : Bounty_Pkg.Pay_Facts) return Boolean
   is ((P.already_paid_for_receipt = (not F.not_already_minted)) and then
       (P.vector_frozen_at_admission = F.vector_in_receipt) and then
       (P.period_ceiling = Ceiling) and then
       ((P.paid_this_period < Ceiling) = F.under_ceiling) and then
       (Bounty_Pkg.Receipt_Present (P) = F.have_receipt))
   with Global => null,
        Post => Facts_Agree'Result = ((P.already_paid_for_receipt = (not F.not_already_minted)) and then
                                    (P.vector_frozen_at_admission = F.vector_in_receipt) and then
                                    (P.period_ceiling = Ceiling) and then
                                    ((P.paid_this_period < Ceiling) = F.under_ceiling) and then
                                    (Bounty_Pkg.Receipt_Present (P) = F.have_receipt));

   function Outcome (F : Mint_Facts; P : Bounty_Pkg.Pay_Facts) return Outcome_Kind
   is (if not F.have_receipt then Out_Refused_No_Receipt
        elsif not F.receipt_signed then Out_Refused_Unsigned
        elsif not F.verdict_proved then Out_Refused_Not_Proved
        elsif not F.vector_in_receipt then Out_Refused_No_Vector
        elsif not F.ledger_is_rows then Out_Refused_Ledger_Malformed
        elsif not F.chain_holds then Out_Refused_Chain_Broken
        elsif not F.not_already_minted then Out_Refused_Already_Minted
        elsif not F.under_ceiling then Out_Refused_Over_Ceiling
        elsif not Bounty_Pkg.May_Pay (P) then Out_Refused_May_Pay
        elsif not F.row_ok then Out_Refused_Row_Malformed
        elsif not F.written then Out_Refused_Write_Failed
        else Out_Minted)
   with Global => null,
        Pre => Facts_Agree (F, P),
        Post => ((Outcome'Result = Out_Minted) =
                  (F.have_receipt and then F.receipt_signed and then F.verdict_proved
                   and then F.vector_in_receipt and then F.ledger_is_rows and then F.chain_holds
                   and then F.not_already_minted and then F.under_ceiling
                   and then Bounty_Pkg.May_Pay (P) and then F.row_ok and then F.written)) and then
               (if not F.have_receipt then Outcome'Result = Out_Refused_No_Receipt) and then
               (if not F.receipt_signed then Outcome'Result /= Out_Minted) and then
               (if not F.chain_holds then Outcome'Result /= Out_Minted) and then
               (if not F.not_already_minted then Outcome'Result /= Out_Minted) and then
               (if P.already_paid_for_receipt then Outcome'Result /= Out_Minted) and then
               (if not F.under_ceiling then Outcome'Result /= Out_Minted) and then
               (if Outcome'Result = Out_Minted then Bounty_Pkg.May_Pay (P));

end Bawbee_Ledger_Pkg;
