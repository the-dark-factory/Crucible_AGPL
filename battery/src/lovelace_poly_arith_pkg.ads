--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 7fab01d65cbad190a763e2d307eeb704e150c79a0f62a46b52ae8c59a02831c1
--
with Interfaces;
use type Interfaces.Unsigned_64;
use type Interfaces.Integer_64;

package Lovelace_Poly_Arith_Pkg with SPARK_Mode, Pure is

   Max_Atom_Length : constant := 256;
   Max_Degree      : constant := 8;
   Max_Terms       : constant := 32;
   Two_To_63       : constant Interfaces.Unsigned_64 := 2 ** 63;

   subtype Atom_Length is Natural range 0 .. Max_Atom_Length;

   type Atom is record
      Length : Atom_Length := 0;
      Text   : String (1 .. Max_Atom_Length) := (others => ' ');
   end record;

   subtype Degree is Natural range 0 .. Max_Degree;

   type Atom_List is array (1 .. Max_Degree) of Atom;

   type Key is record
      Count : Degree := 0;
      Atoms : Atom_List;
   end record;

   type Term is record
      K           : Key;
      Coefficient : Interfaces.Unsigned_64 := 0;
   end record;

   subtype Term_Count is Natural range 0 .. Max_Terms;

   type Term_List is array (1 .. Max_Terms) of Term;

   type Poly is record
      Count : Term_Count := 0;
      Terms : Term_List;
   end record;

   function Empty_Atom return Atom is
     ((Length => 0, Text => (others => ' ')));

   function Empty_Key return Key is
     ((Count => 0, Atoms => (others => Empty_Atom)));

   function Empty_Term return Term is
     ((K => Empty_Key, Coefficient => 0));

   function Atom_Equal (A : Atom; B : Atom) return Boolean is
     (A.Length = B.Length and then A.Text (1 .. A.Length) = B.Text (1 .. B.Length));

   function Same_Prefix (A : Atom; B : Atom; N : Natural) return Boolean is
     (A.Text (1 .. N) = B.Text (1 .. N))
     with Pre => N <= Max_Atom_Length;

   function Differs_Less_At (A : Atom; B : Atom; I : Positive) return Boolean is
     (Same_Prefix (A, B, I - 1) and then A.Text (I) < B.Text (I))
     with Pre => I <= Max_Atom_Length;

   function Proper_Prefix (A : Atom; B : Atom) return Boolean is
     (A.Length < B.Length and then Same_Prefix (A, B, A.Length));

   function Atom_Less (A : Atom; B : Atom) return Boolean is
     ((for some I in 1 .. Natural'Min (A.Length, B.Length) => Differs_Less_At (A, B, I))
      or else Proper_Prefix (A, B));

   function Is_Sorted (K : Key) return Boolean is
     ((for all I in 1 .. K.Count - 1 => not Atom_Less (K.Atoms (I + 1), K.Atoms (I))));

   function Key_Equal (A : Key; B : Key) return Boolean is
     (A.Count = B.Count and then
      (for all I in 1 .. A.Count => Atom_Equal (A.Atoms (I), B.Atoms (I))));

   function Key_Unique_After (P : Poly; I : Positive) return Boolean is
     ((for all J in I + 1 .. P.Count => not Key_Equal (P.Terms (I).K, P.Terms (J).K)))
     with Pre => I <= P.Count;

   function Holds_Atom (K : Key; A : Atom) return Boolean is
     ((for some J in 1 .. K.Count => Atom_Equal (K.Atoms (J), A)));

   function Well_Formed (P : Poly) return Boolean is
     ((for all I in 1 .. P.Count => Is_Sorted (P.Terms (I).K))
      and then (for all I in 1 .. P.Count => Key_Unique_After (P, I)));

   function No_Zero_Term (P : Poly) return Boolean is
     ((for all I in 1 .. P.Count => P.Terms (I).Coefficient /= 0));

   function Wrap (C : Interfaces.Integer_64) return Interfaces.Unsigned_64 is
     (if C >= 0 then Interfaces.Unsigned_64 (C)
      else Interfaces.Unsigned_64'Last - Interfaces.Unsigned_64 (-(C + 1)))
     with Post => (if C >= 0 then Wrap'Result < Two_To_63 else Wrap'Result >= Two_To_63);

   function Signed_Value (U : Interfaces.Unsigned_64) return Interfaces.Integer_64 is
     (if U < Two_To_63 then Interfaces.Integer_64 (U)
      else Interfaces.Integer_64'First + Interfaces.Integer_64 (U - Two_To_63))
     with Post => ((Signed_Value'Result >= 0) = (U < Two_To_63));

   function Constant_Poly (C : Interfaces.Integer_64) return Poly is
     (Count => 1, Terms => (1 => (K => Empty_Key, Coefficient => Wrap (C)), others => Empty_Term))
     with Post =>
       (Constant_Poly'Result.Count = 1
        and then Constant_Poly'Result.Terms (1).K.Count = 0
        and then Constant_Poly'Result.Terms (1).Coefficient = Wrap (C)
        and then Well_Formed (Constant_Poly'Result));

   function Atom_Poly (A : Atom) return Poly is
     (Count => 1,
      Terms => (1 => (K => (Count => 1, Atoms => (1 => A, others => Empty_Atom)), Coefficient => 1),
                others => Empty_Term))
     with Post =>
       (Atom_Poly'Result.Count = 1
        and then Atom_Poly'Result.Terms (1).K.Count = 1
        and then Atom_Equal (Atom_Poly'Result.Terms (1).K.Atoms (1), A)
        and then Atom_Poly'Result.Terms (1).Coefficient = 1
        and then Well_Formed (Atom_Poly'Result));

   function Find_From (P : Poly; K : Key; I : Positive) return Term_Count is
     (if I > P.Count then 0
      elsif Key_Equal (P.Terms (I).K, K) then I
      else Find_From (P, K, I + 1))
     with Pre  => I <= P.Count + 1,
          Post => (if Find_From'Result > 0 then
                     (Find_From'Result >= I and then Find_From'Result <= P.Count
                      and then Key_Equal (P.Terms (Find_From'Result).K, K)))
                  and then (if Find_From'Result = 0 then
                              (for all J in I .. P.Count => not Key_Equal (P.Terms (J).K, K))),
          Subprogram_Variant => (Decreases => P.Count - I + 1);

   function Find (P : Poly; K : Key) return Term_Count is
     (Find_From (P, K, 1))
     with Post => (if Find'Result > 0 then (Find'Result <= P.Count and then Key_Equal (P.Terms (Find'Result).K, K)))
                  and then (if Find'Result = 0 then (for all I in 1 .. P.Count => not Key_Equal (P.Terms (I).K, K)));

   function Coefficient_Of (P : Poly; K : Key) return Interfaces.Unsigned_64 is
     (if Find (P, K) = 0 then 0 else P.Terms (Find (P, K)).Coefficient)
     with Post => (if Find (P, K) = 0 then Coefficient_Of'Result = 0);

   function Sum_Of (P : Poly; Q : Poly; Negate : Boolean; K : Key) return Interfaces.Unsigned_64 is
     (Coefficient_Of (P, K) + (if Negate then 0 - Coefficient_Of (Q, K) else Coefficient_Of (Q, K)));

   function Insert_Pos_From (K : Key; X : Atom; I : Positive) return Positive is
     (if I > K.Count then K.Count + 1
      elsif Atom_Less (X, K.Atoms (I)) then I
      else Insert_Pos_From (K, X, I + 1))
     with Pre  => I <= K.Count + 1,
          Post => Insert_Pos_From'Result >= I and then Insert_Pos_From'Result <= K.Count + 1,
          Subprogram_Variant => (Decreases => K.Count - I + 1);

   function Atom_After_Insert (K : Key; X : Atom; Pos : Positive; I : Positive) return Atom is
     (if I < Pos then K.Atoms (I)
      elsif I = Pos then X
      elsif I <= K.Count + 1 then K.Atoms (I - 1)
      else Empty_Atom)
     with Pre => K.Count < Max_Degree and then Pos <= K.Count + 1 and then I <= Max_Degree;

   function Insert_Atom (K : Key; X : Atom) return Key is
     ((Count => K.Count + 1,
       Atoms => (for I in 1 .. Max_Degree => Atom_After_Insert (K, X, Insert_Pos_From (K, X, 1), I))))
     with Pre  => K.Count < Max_Degree,
          Post => Insert_Atom'Result.Count = K.Count + 1;

   function Insert_All (A : Key; B : Key; J : Positive) return Key is
     (if J > B.Count then A else Insert_All (Insert_Atom (A, B.Atoms (J)), B, J + 1))
     with Pre  => J <= B.Count + 1 and then A.Count + (B.Count - J + 1) <= Max_Degree,
          Post => Insert_All'Result.Count = A.Count + (B.Count - J + 1),
          Subprogram_Variant => (Decreases => B.Count - J + 1);

   function Merge_Keys (A : Key; B : Key) return Key is
     (Insert_All (Insert_All (Empty_Key, A, 1), B, 1))
     with Pre  => A.Count + B.Count <= Max_Degree,
          Post => Merge_Keys'Result.Count = A.Count + B.Count;

   function Empty_Poly return Poly is
     ((Count => 0, Terms => (others => Empty_Term)))
     with Post => Empty_Poly'Result.Count = 0;

   function Append_Term (R : Poly; T : Term) return Poly is
     ((R with delta Count => R.Count + 1, Terms => (R.Terms with delta R.Count + 1 => T)))
     with Pre  => R.Count < Max_Terms,
          Post => Append_Term'Result.Count = R.Count + 1;

   function Add_Key (P : Poly; Q : Poly; I : Positive) return Key is
     (if I <= P.Count then P.Terms (I).K else Q.Terms (I - P.Count).K)
     with Pre => I <= P.Count + Q.Count and then P.Count + Q.Count <= Max_Terms;

   function Add_Takes (P : Poly; Q : Poly; Negate : Boolean; I : Positive) return Boolean is
     ((I <= P.Count or else Find (P, Add_Key (P, Q, I)) = 0)
      and then Sum_Of (P, Q, Negate, Add_Key (P, Q, I)) /= 0)
     with Pre => I <= P.Count + Q.Count and then P.Count + Q.Count <= Max_Terms;

   function Add_From (P : Poly; Q : Poly; Negate : Boolean; I : Positive; Acc : Poly) return Poly is
     (if I > P.Count + Q.Count then Acc
      elsif Add_Takes (P, Q, Negate, I)
      then Add_From (P, Q, Negate, I + 1,
                     Append_Term (Acc, (K => Add_Key (P, Q, I), Coefficient => Sum_Of (P, Q, Negate, Add_Key (P, Q, I)))))
      else Add_From (P, Q, Negate, I + 1, Acc))
     with Pre  => P.Count + Q.Count <= Max_Terms and then I <= P.Count + Q.Count + 1
                  and then Acc.Count <= I - 1,
          Post => Add_From'Result.Count <= Acc.Count + (P.Count + Q.Count - I + 1),
          Subprogram_Variant => (Decreases => P.Count + Q.Count - I + 1);

   function Add (P : Poly; Q : Poly; Negate : Boolean) return Poly is
     (Add_From (P, Q, Negate, 1, Empty_Poly))
     with Pre  => P.Count + Q.Count <= Max_Terms,
          Post => Add'Result.Count <= P.Count + Q.Count;

   function Row_Fits (P : Poly; I : Positive; Q : Poly) return Boolean is
     ((for all J in 1 .. Q.Count => P.Terms (I).K.Count + Q.Terms (J).K.Count <= Max_Degree))
     with Pre => I <= P.Count;

   function Can_Multiply (P : Poly; Q : Poly) return Boolean is
     (P.Count * Q.Count <= Max_Terms and then (for all I in 1 .. P.Count => Row_Fits (P, I, Q)));


   function Acc_Add (R : Poly; K : Key; C : Interfaces.Unsigned_64) return Poly is
     (if Find (R, K) > 0
      then (R with delta Terms => (R.Terms with delta Find (R, K) =>
                                    (K => R.Terms (Find (R, K)).K, Coefficient => R.Terms (Find (R, K)).Coefficient + C)))
      else Append_Term (R, (K => K, Coefficient => C)))
     with Pre  => R.Count < Max_Terms,
          Post => Acc_Add'Result.Count <= R.Count + 1;

   function Pair_Row (Q : Poly; I : Positive) return Positive is
     ((I - 1) / Q.Count + 1)
     with Pre => Q.Count >= 1;

   function Pair_Col (Q : Poly; I : Positive) return Positive is
     ((I - 1) mod Q.Count + 1)
     with Pre => Q.Count >= 1, Post => Pair_Col'Result <= Q.Count;

   function Mul_From (P : Poly; Q : Poly; I : Positive; Acc : Poly) return Poly is
     (if I > P.Count * Q.Count then Acc
      else Mul_From (P, Q, I + 1,
                     Acc_Add (Acc,
                              Merge_Keys (P.Terms (Pair_Row (Q, I)).K, Q.Terms (Pair_Col (Q, I)).K),
                              P.Terms (Pair_Row (Q, I)).Coefficient * Q.Terms (Pair_Col (Q, I)).Coefficient)))
     with Pre  => Q.Count >= 1 and then Can_Multiply (P, Q) and then I <= P.Count * Q.Count + 1
                  and then Acc.Count <= I - 1,
          Post => Mul_From'Result.Count <= Acc.Count + (P.Count * Q.Count - I + 1),
          Subprogram_Variant => (Decreases => P.Count * Q.Count - I + 1);

   function Drop_Zeros (R : Poly; I : Positive; Acc : Poly) return Poly is
     (if I > R.Count then Acc
      elsif R.Terms (I).Coefficient = 0 then Drop_Zeros (R, I + 1, Acc)
      else Drop_Zeros (R, I + 1, Append_Term (Acc, R.Terms (I))))
     with Pre  => I <= R.Count + 1 and then Acc.Count <= I - 1,
          Post => Drop_Zeros'Result.Count <= Acc.Count + (R.Count - I + 1),
          Subprogram_Variant => (Decreases => R.Count - I + 1);

   function Multiply (P : Poly; Q : Poly) return Poly is
     (if P.Count = 0 or else Q.Count = 0 then Empty_Poly
      else Drop_Zeros (Mul_From (P, Q, 1, Empty_Poly), 1, Empty_Poly))
     with Pre  => Can_Multiply (P, Q),
          Post => Multiply'Result.Count <= P.Count * Q.Count
                  and then (if P.Count = 0 or else Q.Count = 0 then Multiply'Result.Count = 0);

end Lovelace_Poly_Arith_Pkg;
