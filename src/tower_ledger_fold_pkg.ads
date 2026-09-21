--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 5f054935876fddf55560841c259f953fddf23a5b64b20eccb1b3f60cf43ba906
--
with Tower_Admission_Pkg;
with Tower_Ledger_Line_Pkg;
with Tower_Stamp_Pkg;

package Tower_Ledger_Fold_Pkg with SPARK_Mode is
   --  PURPOSE: the local tower ledger folded LINE BY LINE into what an importer
   --  needs: the highest accepted version, the last accepted digest, whether
   --  the fold reached the end, and whether an accepted row really landed.
   --  USAGE: start from Initial; Add every line in file order; Whole at the end;
   --  ask Usable first. Only a whole fold may be called unchanged.
   use type Tower_Admission_Pkg.Version_Number;
   use type Tower_Admission_Pkg.Verdict_Kind;

   subtype Digest_Text is String (1 .. 64);
   No_Digest : constant Digest_Text := (others => '0');
   type Fold_State is record
      have_row    : Boolean := False;
      highest     : Tower_Admission_Pkg.Version_Number := 0;
      last_digest : Digest_Text := No_Digest;
      whole       : Boolean := False;
   end record;
   Initial : constant Fold_State :=
     (have_row => False, highest => 0, last_digest => No_Digest, whole => False);
   type Outcome_Kind is
     (Out_Accepted, Out_Unrecorded, Out_Declined, Out_Refused_Receipt,
      Out_Refused_Integrity);

   function Digit_Of (C : Character) return Tower_Admission_Pkg.Version_Number is
     ((if C in '0' .. '9' then
          Tower_Admission_Pkg.Version_Number
            (Character'Pos (C) - Character'Pos ('0'))
        else 0))
   with Global => null,
        Post => (Digit_Of'Result <= 9)
                and then
                (if C in '0' .. '9' then
                   Character'Pos (C) = Character'Pos ('0') + Integer (Digit_Of'Result))
                and then
                (if C not in '0' .. '9' then Digit_Of'Result = 0);

   function Row_Version (Line : String) return Tower_Admission_Pkg.Version_Number is
     (Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First)) * 100_000_000
      + Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 1)) * 10_000_000
      + Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 2)) * 1_000_000
      + Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 3)) * 100_000
      + Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 4)) * 10_000
      + Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 5)) * 1_000
      + Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 6)) * 100
      + Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 7)) * 10
      + Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 8)))
   with Global => null,
        Pre => Line'First = 1 and then Tower_Ledger_Line_Pkg.Is_Accepted_Row (Line),
        Post => (Row_Version'Result <= 999_999_999)
                and then
                ((Row_Version'Result / 100_000_000) mod 10 = Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First)))
                and then
                ((Row_Version'Result / 10_000_000) mod 10 = Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 1)))
                and then
                ((Row_Version'Result / 1_000_000) mod 10 = Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 2)))
                and then
                ((Row_Version'Result / 100_000) mod 10 = Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 3)))
                and then
                ((Row_Version'Result / 10_000) mod 10 = Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 4)))
                and then
                ((Row_Version'Result / 1_000) mod 10 = Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 5)))
                and then
                ((Row_Version'Result / 100) mod 10 = Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 6)))
                and then
                ((Row_Version'Result / 10) mod 10 = Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 7)))
                and then
                (Row_Version'Result mod 10 = Digit_Of (Line (Tower_Ledger_Line_Pkg.Version_First + 8)));

   function Add (S : Fold_State; Line : String) return Fold_State is
     ((if Tower_Ledger_Line_Pkg.Is_Accepted_Row (Line) then
          (have_row => True,
           highest => (if Tower_Admission_Pkg.Is_Forward
                             (Row_Version (Line), S.highest)
                        then Row_Version (Line) else S.highest),
           last_digest => Digest_Text
             (Line (Tower_Ledger_Line_Pkg.Digest_First ..
                    Tower_Ledger_Line_Pkg.Digest_Last)),
           whole => False)
        else S))
   with Global => null,
        Pre => Line'First = 1 and then not S.whole,
        Post => (Add'Result.have_row =
                   (S.have_row or else Tower_Ledger_Line_Pkg.Is_Accepted_Row (Line)))
                and then
                (Add'Result.highest =
                   (if Tower_Ledger_Line_Pkg.Is_Accepted_Row (Line) and then
                       Row_Version (Line) > S.highest
                     then Row_Version (Line) else S.highest))
                and then
                (Add'Result.last_digest =
                   (if Tower_Ledger_Line_Pkg.Is_Accepted_Row (Line) then
                      Digest_Text (Line (Tower_Ledger_Line_Pkg.Digest_First ..
                                         Tower_Ledger_Line_Pkg.Digest_Last))
                    else S.last_digest))
                and then
                (not Add'Result.whole)
                and then
                (Add'Result.highest >= S.highest);

   function Whole (S : Fold_State; Read_To_End : Boolean) return Fold_State is
     ((have_row => S.have_row, highest => S.highest,
       last_digest => S.last_digest, whole => Read_To_End))
   with Global => null,
        Post => (Whole'Result.whole = Read_To_End)
                and then
                (Whole'Result.have_row = S.have_row)
                and then
                (Whole'Result.highest = S.highest)
                and then
                (Whole'Result.last_digest = S.last_digest);

   function Usable (S : Fold_State) return Boolean is
     (S.whole)
   with Global => null,
        Post => (Usable'Result = S.whole);

   function Running (S : Fold_State; Base : Tower_Admission_Pkg.Version_Number)
     return Tower_Admission_Pkg.Version_Number is
     ((if Tower_Admission_Pkg.Is_Forward (Base, S.highest) then Base
        else S.highest))
   with Global => null,
        Post => (Running'Result = (if Base > S.highest then Base else S.highest))
                and then
                (Running'Result >= S.highest)
                and then
                (Running'Result >= Base);

   function Unchanged (S : Fold_State; Digest : String) return Boolean is
     (S.whole and then S.have_row and then
      Tower_Stamp_Pkg.Is_Hex_Digest (Digest) and then S.last_digest = Digest)
   with Global => null,
        Post => (Unchanged'Result = (not (not S.whole or else not S.have_row or else
                   not Tower_Stamp_Pkg.Is_Hex_Digest (Digest) or else
                   S.last_digest /= Digest)))
                and then
                (if Unchanged'Result then S.whole);

   function Row_Landed (Last_Line : String; Digest : String; V : String) return Boolean is
     (Tower_Ledger_Line_Pkg.Row_Names (Last_Line, Digest) and then
      Tower_Ledger_Line_Pkg.Is_Padded_Version (V) and then
      Last_Line (Tower_Ledger_Line_Pkg.Version_First ..
                 Tower_Ledger_Line_Pkg.Version_Last) = V)
   with Global => null,
        Pre => Last_Line'First = 1,
        Post => (Row_Landed'Result = (not (
                   not Tower_Ledger_Line_Pkg.Row_Names (Last_Line, Digest)
                   or else not Tower_Ledger_Line_Pkg.Is_Padded_Version (V)
                   or else Last_Line (Tower_Ledger_Line_Pkg.Version_First ..
                                      Tower_Ledger_Line_Pkg.Version_Last) /= V)))
                and then
                (if Row_Landed'Result then
                   Tower_Ledger_Line_Pkg.Is_Accepted_Row (Last_Line));

   function Outcome (V : Tower_Admission_Pkg.Verdict_Kind; Landed : Boolean) return Outcome_Kind is
     ((case V is
          when Tower_Admission_Pkg.Accepted =>
            (if Landed then Out_Accepted else Out_Unrecorded),
          when Tower_Admission_Pkg.Declined_By_Policy => Out_Declined,
          when Tower_Admission_Pkg.Refused_Receipt => Out_Refused_Receipt,
          when Tower_Admission_Pkg.Refused_Integrity => Out_Refused_Integrity))
   with Global => null,
        Post => ((Outcome'Result = Out_Accepted) =
                   (V = Tower_Admission_Pkg.Accepted and then Landed))
                and then
                ((Outcome'Result = Out_Unrecorded) =
                   (V = Tower_Admission_Pkg.Accepted and then not Landed))
                and then
                ((Outcome'Result = Out_Declined) =
                   (V = Tower_Admission_Pkg.Declined_By_Policy))
                and then
                ((Outcome'Result = Out_Refused_Receipt) =
                   (V = Tower_Admission_Pkg.Refused_Receipt))
                and then
                ((Outcome'Result = Out_Refused_Integrity) =
                   (V = Tower_Admission_Pkg.Refused_Integrity));

end Tower_Ledger_Fold_Pkg;
