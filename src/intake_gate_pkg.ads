--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 578f16e1f084b0207bd4152d26d77c4d8b3fd00bc995d36743e80869636185d0
--
package Intake_Gate_Pkg with SPARK_Mode, Pure is

   Max_Brief : constant := 65536;

   Lit_Deliverable     : constant String := "deliverable";
   Lit_Deliverable_Cap : constant String := "Deliverable";

   type Fault_Kind is (No_Fault, Empty_Brief, No_Deliverable, Is_A_Question);

   function Is_Empty (Brief : String) return Boolean
   is (Brief'Length = 0)
   with Global => null,
        Pre => Brief'First = 1 and then Brief'Length <= Max_Brief;

   function Contains (Brief : String; Needle : String) return Boolean
   is ((for some I in 1 .. Brief'Length - Needle'Length + 1 => Brief (I .. I + Needle'Length - 1) = Needle))
   with Global => null,
        Pre => Brief'First = 1 and then Brief'Length <= Max_Brief
              and then Needle'First = 1 and then Needle'Length >= 1 and then Needle'Length <= 64;

   function Names_Deliverable (Brief : String) return Boolean
   is (Contains (Brief, Lit_Deliverable) or else Contains (Brief, Lit_Deliverable_Cap))
   with Global => null,
        Pre => Brief'First = 1 and then Brief'Length <= Max_Brief;

   function Last_Non_Blank (Brief : String; Upto : Natural) return Natural
   is (if Upto = 0 then 0
       elsif Brief (Upto) /= ' ' then Upto
       else Last_Non_Blank (Brief, Upto - 1))
   with Global => null,
        Pre => Brief'First = 1 and then Brief'Length <= Max_Brief
              and then Upto <= Brief'Length,
        Subprogram_Variant => (Decreases => Upto),
        Post => Last_Non_Blank'Result <= Upto;

   function Is_Question (Brief : String) return Boolean
   is (Last_Non_Blank (Brief, Brief'Length) >= 1 and then Brief (Last_Non_Blank (Brief, Brief'Length)) = '?')
   with Global => null,
        Pre => Brief'First = 1 and then Brief'Length <= Max_Brief;

   function Fault_Of (Brief : String) return Fault_Kind
   is ((if Is_Empty (Brief) then Empty_Brief
        elsif not Names_Deliverable (Brief) then No_Deliverable
        elsif Is_Question (Brief) then Is_A_Question
        else No_Fault))
   with Global => null,
        Pre => Brief'First = 1 and then Brief'Length <= Max_Brief;

   function Passed (Brief : String) return Boolean
   is (Fault_Of (Brief) = No_Fault)
   with Global => null,
        Pre => Brief'First = 1 and then Brief'Length <= Max_Brief,
        Post => Passed'Result = (not Is_Empty (Brief)
                                and then Names_Deliverable (Brief)
                                and then not Is_Question (Brief));

end Intake_Gate_Pkg;
