--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: cd695eb39737fb216637adbf9b7902156ef33da07f7799257fa51931b587d004
--
with Lovelace_Poly_Arith_Pkg;
use Lovelace_Poly_Arith_Pkg;

package Lovelace_Residual_Classifier_Pkg with SPARK_Mode, Pure is

   subtype Outcome is Natural range 0 .. 3;
   Unreached    : constant Outcome := 0;
   Failed       : constant Outcome := 1;
   Proved       : constant Outcome := 2;
   Inapplicable : constant Outcome := 3;

   type Residual_Class is (Constant_Residual, Univariate_Residual, Genuine_Residual);

   type Class_Array is array (Positive range <>) of Residual_Class;

   function Is_Constant (P : Poly) return Boolean is
     (P.Count = 0 or else (P.Count = 1 and then P.Terms (1).K.Count = 0));

   function On_Atom (P : Poly; I : Positive; A : Atom) return Boolean is
     (P.Terms (I).K.Count = 0
      or else (P.Terms (I).K.Count = 1 and then Atom_Equal (P.Terms (I).K.Atoms (1), A)))
     with Pre => I <= P.Count;

   function All_On_Atom (P : Poly; A : Atom) return Boolean is
     ((for all I in 1 .. P.Count => On_Atom (P, I, A)));

   function Linear_In_Term (P : Poly; J : Positive) return Boolean is
     (P.Terms (J).K.Count = 1 and then All_On_Atom (P, P.Terms (J).K.Atoms (1)))
     with Pre => J <= P.Count;

   function Is_Univariate (P : Poly) return Boolean is
     ((for some J in 1 .. P.Count => Linear_In_Term (P, J)));

   function Classify (P : Poly) return Residual_Class is
     (if Is_Constant (P) then Constant_Residual
      elsif Is_Univariate (P) then Univariate_Residual
      else Genuine_Residual)
     with Post => ((Classify'Result = Constant_Residual) = Is_Constant (P))
                  and then ((Classify'Result = Univariate_Residual) = (Is_Univariate (P) and then not Is_Constant (P)));

   function Has_Constant (Classes : Class_Array) return Boolean is
     ((for some I in Classes'Range => Classes (I) = Constant_Residual));

   function T5_Of (Normalised : Boolean; Classes : Class_Array) return Outcome is
     (if Normalised and then Has_Constant (Classes) then Proved else Failed)
     with Post => ((T5_Of'Result = Proved) = (Normalised and then Has_Constant (Classes)))
                  and then ((T5_Of'Result = Failed) = (not Normalised or else not Has_Constant (Classes)));

end Lovelace_Residual_Classifier_Pkg;
