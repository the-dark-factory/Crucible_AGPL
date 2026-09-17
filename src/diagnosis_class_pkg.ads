--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1e13c1b95038353f16defe651bd362baf9af6c340dca7223c66924f6bcb7e254
--
package Diagnosis_Class_Pkg with SPARK_Mode is

   Max_Line  : constant := 65_536;
   Max_Count : constant := 100_000_000;

   subtype Count is Integer range 0 .. Max_Count;

   Pat_Init         : constant String := "might not be initialized";
   Pat_Nonterm      : constant String := "nonterminating";
   Pat_Terminates   : constant String := "always_terminates";
   Pat_Not_Pres     : constant String := "not preserved";
   Pat_Not_Be_Pres  : constant String := "not be preserved";
   Pat_Post_Fails   : constant String := "postcondition might fail";
   Pat_Inv_Fails    : constant String := "loop invariant might fail";
   Pat_Placement    : constant String := "must appear";
   Pat_Discriminant : constant String := "no single variant";
   Pat_Old          : constant String := "'old";
   Pat_In_Out       : constant String := " in out ";
   Pat_Loop         : constant String := " loop";
   Pat_Invariant    : constant String := "loop_invariant";
   Pat_Reverse      : constant String := " reverse ";
   Pat_While        : constant String := "while ";

   type Evidence is record
      init_lines            : Count           := 0;
      termination_lines     : Count           := 0;
      not_preserved_lines   : Count           := 0;
      post_fails_lines      : Count           := 0;
      invariant_fails_lines : Count           := 0;
      placement_lines       : Count           := 0;
      discriminant_lines    : Count           := 0;
      spec_uses_old         : Boolean         := False;
      spec_has_in_out       : Boolean         := False;
      body_has_loop         : Boolean         := False;
      body_has_invariant    : Boolean         := False;
      body_invariant_uses_old : Boolean       := False;
      body_has_reverse      : Boolean         := False;
      body_has_while        : Boolean         := False;
      saturated             : Boolean         := False;
   end record;

   type Hint_Class is (
     Placement,
     Discriminant,
     Initialization,
     Termination,
     Frame_In_Place,
     Non_Inductive_Invariant,
     Wrong_Extremum,
     Missing_Prefix_Invariant,
     No_Hint
   );

   type Catalogue_Class is (
     Omission,
     Inductive_Strength,
     Hard_Frame,
     Idiom,
     Logic,
     Unclassified
   );

   function Is_Upper (C : Character) return Boolean is
     (C in 'A' .. 'Z')
     with Pre => True;

   function Lower_Eq (A : Character; B : Character) return Boolean is
     (A = B or else (Is_Upper (A) and then Character'Pos (A) + 32 = Character'Pos (B)) or else (Is_Upper (B) and then Character'Pos (B) + 32 = Character'Pos (A)))
     with Pre => True;

   function Contains_CI (Line : String; Pattern : String) return Boolean is
     (Line'Length >= Pattern'Length and then
      (for some P in 1 .. Line'Length - Pattern'Length + 1 =>
         (for all K in 0 .. Pattern'Length - 1 => Lower_Eq (Line (P + K), Pattern (1 + K)))))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line and then Pattern'First = 1
                 and then Pattern'Length >= 1 and then Pattern'Length <= 32;

   function Bump (C : Count) return Count is
     ((if C < Max_Count then C + 1 else C))
     with Pre => True;

   function Add_Prover_Line (E : Evidence; Line : String) return Evidence is
     (E'Update
        (init_lines            => (if Contains_CI (Line, Pat_Init) then Bump (E.init_lines) else E.init_lines),
         termination_lines     => (if Contains_CI (Line, Pat_Nonterm) or else Contains_CI (Line, Pat_Terminates) then Bump (E.termination_lines) else E.termination_lines),
         not_preserved_lines   => (if Contains_CI (Line, Pat_Not_Pres) or else Contains_CI (Line, Pat_Not_Be_Pres) then Bump (E.not_preserved_lines) else E.not_preserved_lines),
         post_fails_lines      => (if Contains_CI (Line, Pat_Post_Fails) then Bump (E.post_fails_lines) else E.post_fails_lines),
         invariant_fails_lines => (if Contains_CI (Line, Pat_Inv_Fails) then Bump (E.invariant_fails_lines) else E.invariant_fails_lines),
         placement_lines       => (if Contains_CI (Line, Pat_Placement) then Bump (E.placement_lines) else E.placement_lines),
         discriminant_lines    => (if Contains_CI (Line, Pat_Discriminant) then Bump (E.discriminant_lines) else E.discriminant_lines),
         saturated             => E.saturated or else
                                  (if Contains_CI (Line, Pat_Init) and then E.init_lines = Max_Count - 1 then True else False) or else
                                  (if (Contains_CI (Line, Pat_Nonterm) or else Contains_CI (Line, Pat_Terminates)) and then E.termination_lines = Max_Count - 1 then True else False) or else
                                  (if (Contains_CI (Line, Pat_Not_Pres) or else Contains_CI (Line, Pat_Not_Be_Pres)) and then E.not_preserved_lines = Max_Count - 1 then True else False) or else
                                  (if Contains_CI (Line, Pat_Post_Fails) and then E.post_fails_lines = Max_Count - 1 then True else False) or else
                                  (if Contains_CI (Line, Pat_Inv_Fails) and then E.invariant_fails_lines = Max_Count - 1 then True else False) or else
                                  (if Contains_CI (Line, Pat_Placement) and then E.placement_lines = Max_Count - 1 then True else False) or else
                                  (if Contains_CI (Line, Pat_Discriminant) and then E.discriminant_lines = Max_Count - 1 then True else False)))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line,
          Post => (if Contains_CI (Line, Pat_Init) and then E.init_lines < Max_Count then Add_Prover_Line'Result.init_lines = E.init_lines + 1) and
                  (if not Contains_CI (Line, Pat_Init) then Add_Prover_Line'Result.init_lines = E.init_lines) and
                  (if Contains_CI (Line, Pat_Post_Fails) and then E.post_fails_lines < Max_Count then Add_Prover_Line'Result.post_fails_lines = E.post_fails_lines + 1) and
                  (if not Contains_CI (Line, Pat_Post_Fails) then Add_Prover_Line'Result.post_fails_lines = E.post_fails_lines) and
                  Add_Prover_Line'Result.spec_uses_old = E.spec_uses_old and
                  Add_Prover_Line'Result.body_has_loop = E.body_has_loop;

   function Add_Spec_Line (E : Evidence; Line : String) return Evidence is
     (E'Update
        (spec_uses_old   => E.spec_uses_old or else Contains_CI (Line, Pat_Old),
         spec_has_in_out => E.spec_has_in_out or else Contains_CI (Line, Pat_In_Out)))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line,
          Post => (if Contains_CI (Line, Pat_Old) then Add_Spec_Line'Result.spec_uses_old) and
                  (if E.spec_uses_old then Add_Spec_Line'Result.spec_uses_old) and
                  Add_Spec_Line'Result.post_fails_lines = E.post_fails_lines;

   function Add_Body_Line (E : Evidence; Line : String) return Evidence is
     (E'Update
        (body_has_loop           => E.body_has_loop or else Contains_CI (Line, Pat_Loop),
         body_has_invariant      => E.body_has_invariant or else Contains_CI (Line, Pat_Invariant),
         body_invariant_uses_old => E.body_invariant_uses_old or else (Contains_CI (Line, Pat_Invariant) and then Contains_CI (Line, Pat_Old)),
         body_has_reverse        => E.body_has_reverse or else Contains_CI (Line, Pat_Reverse),
         body_has_while          => E.body_has_while or else Contains_CI (Line, Pat_While)))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line;

   function Applies_Placement (E : Evidence) return Boolean is
     (E.placement_lines >= 1)
     with Pre => True;

   function Applies_Discriminant (E : Evidence) return Boolean is
     (E.discriminant_lines >= 1)
     with Pre => True;

   function Applies_Initialization (E : Evidence) return Boolean is
     (E.init_lines >= 1)
     with Pre => True;

   function Applies_Termination (E : Evidence) return Boolean is
     (E.termination_lines >= 1)
     with Pre => True;

   function Applies_Frame (E : Evidence) return Boolean is
     (E.not_preserved_lines >= 1 and then E.spec_uses_old)
     with Pre => True;

   function Applies_Non_Inductive (E : Evidence) return Boolean is
     (E.not_preserved_lines >= 1 and then not E.spec_uses_old)
     with Pre => True;

   function Applies_Wrong_Extremum (E : Evidence) return Boolean is
     (E.post_fails_lines >= 1 and then E.body_has_loop and then E.body_has_invariant and then E.invariant_fails_lines = 0 and then E.not_preserved_lines = 0)
     with Pre => True;

   function Applies_Missing_Prefix (E : Evidence) return Boolean is
     (E.post_fails_lines >= 1 and then not E.body_has_invariant)
     with Pre => True;

   function Applies (E : Evidence; H : Hint_Class) return Boolean is
     (case H is
        when Placement                => Applies_Placement (E),
        when Discriminant             => Applies_Discriminant (E),
        when Initialization           => Applies_Initialization (E),
        when Termination              => Applies_Termination (E),
        when Frame_In_Place           => Applies_Frame (E),
        when Non_Inductive_Invariant  => Applies_Non_Inductive (E),
        when Wrong_Extremum           => Applies_Wrong_Extremum (E),
        when Missing_Prefix_Invariant => Applies_Missing_Prefix (E),
        when No_Hint                  => False)
     with Pre => True;

   function Catalogue_Of (H : Hint_Class) return Catalogue_Class is
     (case H is
        when Missing_Prefix_Invariant => Omission,
        when Non_Inductive_Invariant  => Inductive_Strength,
        when Frame_In_Place           => Hard_Frame,
        when Placement | Discriminant | Termination | Initialization => Idiom,
        when Wrong_Extremum           => Logic,
        when No_Hint                  => Unclassified)
     with Post => ((Catalogue_Of'Result = Unclassified) = (H = No_Hint));

   function First_Hint (E : Evidence) return Hint_Class is
     ((if Applies_Placement (E) then Placement
       elsif Applies_Discriminant (E) then Discriminant
       elsif Applies_Initialization (E) then Initialization
       elsif Applies_Termination (E) then Termination
       elsif Applies_Frame (E) then Frame_In_Place
       elsif Applies_Non_Inductive (E) then Non_Inductive_Invariant
       elsif Applies_Wrong_Extremum (E) then Wrong_Extremum
       elsif Applies_Missing_Prefix (E) then Missing_Prefix_Invariant
       else No_Hint))
     with Post => (if First_Hint'Result /= No_Hint then Applies (E, First_Hint'Result)) and
                  ((First_Hint'Result = No_Hint) = (not Applies_Placement (E) and then not Applies_Discriminant (E) and then
                    not Applies_Initialization (E) and then not Applies_Termination (E) and then not Applies_Frame (E) and then
                    not Applies_Non_Inductive (E) and then not Applies_Wrong_Extremum (E) and then not Applies_Missing_Prefix (E))) and
                  (if Applies_Placement (E) then First_Hint'Result = Placement) and
                  (if E.init_lines >= 1 and then not Applies_Placement (E) and then not Applies_Discriminant (E) then First_Hint'Result = Initialization);

   function First_Hint_Except (E : Evidence; Avoid : Hint_Class) return Hint_Class is
     ((if Applies_Placement (E) and then Placement /= Avoid then Placement
       elsif Applies_Discriminant (E) and then Discriminant /= Avoid then Discriminant
       elsif Applies_Initialization (E) and then Initialization /= Avoid then Initialization
       elsif Applies_Termination (E) and then Termination /= Avoid then Termination
       elsif Applies_Frame (E) and then Frame_In_Place /= Avoid then Frame_In_Place
       elsif Applies_Non_Inductive (E) and then Non_Inductive_Invariant /= Avoid then Non_Inductive_Invariant
       elsif Applies_Wrong_Extremum (E) and then Wrong_Extremum /= Avoid then Wrong_Extremum
       elsif Applies_Missing_Prefix (E) and then Missing_Prefix_Invariant /= Avoid then Missing_Prefix_Invariant
       else No_Hint))
     with Post => (First_Hint_Except'Result /= Avoid or else First_Hint_Except'Result = No_Hint) and
                  (if First_Hint_Except'Result /= No_Hint then Applies (E, First_Hint_Except'Result)) and
                  (if Avoid = No_Hint then First_Hint_Except'Result = First_Hint (E));

end Diagnosis_Class_Pkg;
