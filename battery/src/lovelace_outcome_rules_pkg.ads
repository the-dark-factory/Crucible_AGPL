--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 30c0d3b5933bbb7c4f7e6cc157ef76676d148babe2247d4ce341f9228ecc7712
--
package Lovelace_Outcome_Rules_Pkg with SPARK_Mode, Pure is

   subtype Outcome is Natural range 0 .. 3;

   Unreached    : constant Outcome := 0;
   Failed       : constant Outcome := 1;
   Proved       : constant Outcome := 2;
   Inapplicable : constant Outcome := 3;

   type TC_Case is (No_Precondition, Domain_Not_Shown, Derive_Error, No_Scalar_Witness, Declared_Only, No_Witness_Read, Posed);

   type TC_Facts is record
      Has_Pre         : Boolean;
      T0              : Outcome;
      Derive_Failed   : Boolean;
      Lemmas_Formed   : Boolean;
      Witness_Present : Boolean;
      Has_Body        : Boolean;
   end record;

   type T4_Facts is record
      Base_Reached    : Boolean;
      Unused_In_Range : Boolean;
      Never_Asserted  : Boolean;
   end record;

   type Mutant_Finding is (No_Finding, Guard, Unneeded);

   function TC_Case_Of (F : TC_Facts) return TC_Case is
     ((if not F.Has_Pre then No_Precondition
       elsif F.T0 /= Failed then Domain_Not_Shown
       elsif F.Derive_Failed then Derive_Error
       elsif not F.Lemmas_Formed and then F.Witness_Present then No_Scalar_Witness
       elsif not F.Lemmas_Formed and then not F.Has_Body then Declared_Only
       elsif not F.Lemmas_Formed then No_Witness_Read
       else Posed))
     with Post =>
       ((TC_Case_Of'Result = No_Precondition) = (not F.Has_Pre))
       and then
       (if F.Has_Pre and then F.T0 /= Failed then TC_Case_Of'Result = Domain_Not_Shown)
       and then
       (if TC_Case_Of'Result = Declared_Only then not F.Has_Body)
       and then
       ((TC_Case_Of'Result = Posed) = (F.Has_Pre and then F.T0 = Failed and then not F.Derive_Failed and then F.Lemmas_Formed));

   function TC_Initial (C : TC_Case) return Outcome is
     ((if C = No_Precondition then Failed
       elsif C = Domain_Not_Shown then Unreached
       elsif C = Derive_Error then Unreached
       elsif C = No_Scalar_Witness then Failed
       elsif C = Declared_Only then Inapplicable
       elsif C = No_Witness_Read then Unreached
       else Failed))
     with Post =>
       ((TC_Initial'Result = Inapplicable) = (C = Declared_Only))
       and then
       ((TC_Initial'Result = Unreached) = (C = Domain_Not_Shown or else C = Derive_Error or else C = No_Witness_Read));

   function T4_Of (F : T4_Facts) return Outcome is
     (if not F.Base_Reached then Unreached
      elsif F.Unused_In_Range or else F.Never_Asserted then Proved
      else Failed)
     with Post =>
       ((T4_Of'Result = Unreached) = (not F.Base_Reached))
       and then
       (if F.Base_Reached then ((T4_Of'Result = Proved) = (F.Unused_In_Range or else F.Never_Asserted)))
       and then
       T4_Of'Result /= Inapplicable;

   function Mutant_Outcome (Post_Outcome : Outcome; Any_Fail_In_Range : Boolean) return Outcome is
     (if Post_Outcome = Proved and then Any_Fail_In_Range then Failed else Post_Outcome)
     with Post =>
       (if Post_Outcome /= Proved then Mutant_Outcome'Result = Post_Outcome)
       and then
       (if Post_Outcome = Proved then ((Mutant_Outcome'Result = Failed) = Any_Fail_In_Range))
       and then
       (if Post_Outcome = Proved and then not Any_Fail_In_Range then Mutant_Outcome'Result = Proved);

   function Mutant_Finding_Of (Post_Outcome : Outcome; Any_Fail_In_Range : Boolean) return Mutant_Finding is
     ((if Post_Outcome /= Proved then No_Finding
       elsif Any_Fail_In_Range then Guard
       else Unneeded))
     with Post =>
       ((Mutant_Finding_Of'Result = No_Finding) = (Post_Outcome /= Proved))
       and then
       ((Mutant_Finding_Of'Result = Guard) = (Post_Outcome = Proved and then Any_Fail_In_Range));

   function Is_Definition (Has_Post : Boolean) return Boolean is
     (not Has_Post)
     with Post =>
       (Is_Definition'Result = (not Has_Post));

   function Claim_Check_Outcome (Has_Post : Boolean; Measured : Outcome) return Outcome is
     (if Has_Post then Measured else Unreached)
     with Post =>
       (if not Has_Post then Claim_Check_Outcome'Result = Unreached)
       and then
       (if Has_Post then Claim_Check_Outcome'Result = Measured);

   Definition_Roll_Grade : constant Natural := 0;

end Lovelace_Outcome_Rules_Pkg;
