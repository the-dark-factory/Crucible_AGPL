--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 521be9d30d00ec1df356e5e4e112e8b42532b6bc56aeb4f15adb4274eaa4dcf6
--
package Vacuity_Verdict_Pkg with SPARK_Mode is

   subtype Outcome is Integer range 0 .. 3;

   subtype Grade is Integer range 0 .. 2;

   function Counts_As_Clear (X : Outcome) return Boolean is
     ((X = 1) or else (X = 3))
   with Post =>
     ((Counts_As_Clear'Result = ((X = 1) or else (X = 3)))) and then
     ((if X = 0 then not Counts_As_Clear'Result)) and then
     ((if X = 2 then not Counts_As_Clear'Result));

   function Grade_Of (T0 : Outcome; RTE : Outcome; TB : Outcome; TC : Outcome; T1 : Outcome; T5 : Outcome; T3 : Outcome; T4 : Outcome) return Grade is
     (if (T0 /= 1) or else (RTE /= 2) then 0 else (if Counts_As_Clear (TB) and then Counts_As_Clear (TC) and then Counts_As_Clear (T1) and then Counts_As_Clear (T5) and then Counts_As_Clear (T3) and then Counts_As_Clear (T4) then 2 else 1))
   with Post =>
     ((Grade_Of'Result = 2) = ((T0 = 1) and then (RTE = 2) and then Counts_As_Clear (TB) and then Counts_As_Clear (TC) and then Counts_As_Clear (T1) and then Counts_As_Clear (T5) and then Counts_As_Clear (T3) and then Counts_As_Clear (T4))) and then
     ((Grade_Of'Result = 0) = ((T0 /= 1) or else (RTE /= 2)));

   function Unreached_Never_Theorem (T0 : Outcome; RTE : Outcome; TB : Outcome; TC : Outcome; T1 : Outcome; T5 : Outcome; T3 : Outcome; T4 : Outcome) return Boolean is
     ((Grade_Of (T0, RTE, TB, TC, T1, T5, T3, T4) < 2))
   with Pre =>
     ((T0 = 0) or else (RTE = 0) or else (TB = 0) or else (TC = 0) or else (T1 = 0) or else (T5 = 0) or else (T3 = 0) or else (T4 = 0)),
        Post =>
     Unreached_Never_Theorem'Result;

   function Applicable_Tests_Decide (T0 : Outcome; RTE : Outcome; TB : Outcome; TC : Outcome; T1 : Outcome; T5 : Outcome; T3 : Outcome; T4 : Outcome) return Boolean is
     ((Grade_Of (T0, RTE, TB, TC, T1, T5, T3, T4) < 2))
   with Pre =>
     (((TB = 0) or else (TB = 2)) or else ((TC = 0) or else (TC = 2)) or else ((T1 = 0) or else (T1 = 2)) or else ((T5 = 0) or else (T5 = 2)) or else ((T3 = 0) or else (T3 = 2)) or else ((T4 = 0) or else (T4 = 2))),
        Post =>
     Applicable_Tests_Decide'Result;

   function Inapplicable_Alone_Never_Theorem (T0 : Outcome; RTE : Outcome; TB : Outcome; TC : Outcome; T1 : Outcome; T5 : Outcome; T3 : Outcome; T4 : Outcome) return Boolean is
     ((Grade_Of (T0, RTE, TB, TC, T1, T5, T3, T4) < 2))
   with Pre =>
     ((T0 = 3) or else (RTE = 3)),
        Post =>
     Inapplicable_Alone_Never_Theorem'Result;

   function Vacuity_Never_Theorem (T0 : Outcome; RTE : Outcome; TB : Outcome; TC : Outcome; T1 : Outcome; T5 : Outcome; T3 : Outcome; T4 : Outcome) return Boolean is
     ((Grade_Of (T0, RTE, TB, TC, T1, T5, T3, T4) < 2))
   with Pre =>
     ((TB = 2) or else (TC = 2) or else (T1 = 2) or else (T5 = 2) or else (T3 = 2) or else (T4 = 2)),
        Post =>
     Vacuity_Never_Theorem'Result;

   function Empty_Domain_Is_Unexercised (RTE : Outcome; TB : Outcome; TC : Outcome; T1 : Outcome; T5 : Outcome; T3 : Outcome; T4 : Outcome) return Boolean is
     ((Grade_Of (2, RTE, TB, TC, T1, T5, T3, T4) = 0))
   with Post =>
     Empty_Domain_Is_Unexercised'Result;

   function Roll_Up (G1 : Grade; G2 : Grade) return Grade is
     (if (G1 <= G2) then G1 else G2)
   with Post =>
     ((Roll_Up'Result <= G1)) and then
     ((Roll_Up'Result <= G2)) and then
     ((Roll_Up'Result = 2) = ((G1 = 2) and then (G2 = 2)));

   function Claim_Admissible (Claimed : Grade; Established : Grade) return Boolean is
     ((Claimed <= Established))
   with Post =>
     ((Claim_Admissible'Result = (Claimed <= Established))) and then
     ((if Claim_Admissible'Result then (if Claimed = 2 then Established = 2)));

   function Worst (A : Outcome; B : Outcome) return Outcome is
     (if A = 3 and then B = 3 then 3 else (if A = 3 then B else (if B = 3 then A else (if A = 0 or else B = 0 then 0 else (if A = 2 or else B = 2 then 2 else 1)))))
   with Post =>
     ((if A = 3 and then B = 3 then Worst'Result = 3)) and then
     ((if A = 0 and then B /= 3 then Worst'Result = 0)) and then
     ((if B = 0 and then A /= 3 then Worst'Result = 0)) and then
     ((if A = 3 then Worst'Result = B)) and then
     ((if B = 3 then Worst'Result = A));

   function Worst_Is_Symmetric (A : Outcome; B : Outcome) return Boolean is
     ((Worst (A, B) = Worst (B, A)))
   with Post =>
     Worst_Is_Symmetric'Result;

end Vacuity_Verdict_Pkg;
