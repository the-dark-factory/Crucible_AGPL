--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: e4cbbbb2b1528d3bb755032178ef41382f1efd476240611f518b6452c7365e28
--
package Tower_Select_Pkg with SPARK_Mode is

   subtype Digest_Text is String (1 .. 64);

   function Is_Digest (S : Digest_Text) return Boolean is
     (for all I in S'Range => S (I) in '0' .. '9' | 'a' .. 'f')
   with Post => Is_Digest'Result = (for all I in S'Range => S (I) in '0' .. '9' | 'a' .. 'f');

   type Stage_Kind is (Stage_Decompose, Stage_Emit_Contract, Stage_Fill_Body);

   type Tier_Kind is (Tier_Always, Tier_Repair);

   type Class_Kind is (Class_Omission, Class_Inductive_Strength, Class_Hard_Frame, Class_Idiom, Class_Logic, Class_Unclassified);

   type Gate_Kind is (Gate_Refused_Compile, Gate_Refused_Unproved, Gate_Refused_Other);

   type Entry_Facts is record
      Entry_Id             : Digest_Text;
      Model_Digest         : Digest_Text;
      Stage                : Stage_Kind;
      Tier                 : Tier_Kind;
      Class                : Class_Kind;
      Gate                 : Gate_Kind;
      Evidence             : Natural;
      From_Accepted_Bundle : Boolean;
   end record;

   type Query is record
      Has_Digest   : Boolean;
      Model_Digest : Digest_Text;
      Stage        : Stage_Kind;
      Repair       : Boolean;
      Last_Class   : Class_Kind;
      Last_Gate    : Gate_Kind;
   end record;

   Max_Consulted : constant Positive := 8;

   function Include (E : Entry_Facts; Q : Query) return Boolean is
     (Q.Has_Digest and then Is_Digest (Q.Model_Digest) and then E.From_Accepted_Bundle and then E.Model_Digest = Q.Model_Digest and then E.Stage = Q.Stage and then (E.Tier = Tier_Always or else (Q.Repair and then E.Tier = Tier_Repair and then E.Class = Q.Last_Class and then E.Gate = Q.Last_Gate)))
   with Post => Include'Result = (Q.Has_Digest and then Is_Digest (Q.Model_Digest) and then E.From_Accepted_Bundle and then E.Model_Digest = Q.Model_Digest and then E.Stage = Q.Stage and then (E.Tier = Tier_Always or else (Q.Repair and then E.Tier = Tier_Repair and then E.Class = Q.Last_Class and then E.Gate = Q.Last_Gate)));

   function Before (A, B : Entry_Facts) return Boolean is
     (A.Evidence > B.Evidence or else (A.Evidence = B.Evidence and then A.Entry_Id < B.Entry_Id))
   with Post => Before'Result = (A.Evidence > B.Evidence or else (A.Evidence = B.Evidence and then A.Entry_Id < B.Entry_Id));

   function Within_Cap (Count : Natural) return Boolean is
     (Count <= Max_Consulted)
   with Post => Within_Cap'Result = (Count <= Max_Consulted);

end Tower_Select_Pkg;
