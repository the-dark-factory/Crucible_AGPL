--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 081ba9b8c55684c4b464f915439e2cdfaa0e4dbe9756aa7a159b29daf5038cff
--
package Lovelace_Refusal_Texts_Pkg with SPARK_Mode, Pure is

   Max_Count : constant := 100_000;
   Max_Detail : constant := 4_096;

   subtype Count is Natural range 0 .. Max_Count;

   Fold_Refused_Text : constant String := "the edge refused a package fold: no package grade is claimed";
   Function_Grade_Refused_Text : constant String := "the edge refused a function grade: no package grade is claimed";
   No_Package_Grade_Text : constant String := "no package grade was reached";

   function Decimal (N : Count) return String is
     (Count'Image (N) (2 .. Count'Image (N)'Last))
   with Post => Decimal'Result'Length <= 11;

   function Edge_Verification_Failed (Detail : String) return String is
     ("edge verification failed: " & Detail)
   with Pre => Detail'Length <= Max_Detail,
        Post => Edge_Verification_Failed'Result'First = 1
                and then Edge_Verification_Failed'Result'Length = 26 + Detail'Length
                and then Edge_Verification_Failed'Result (1 .. 26) = "edge verification failed: "
                and then Edge_Verification_Failed'Result (27 .. Edge_Verification_Failed'Result'Last) = Detail;

   function Postconditions_Unread (Read : Count; Declared : Count) return String is
     ("read " & Decimal (Read) & " postconditions but the source states " & Decimal (Declared) & ": " & Decimal (Declared - Read) & " contract(s) were not read, so no grade is claimed for this file")
   with Pre => Read < Declared,
        Post => Postconditions_Unread'Result'First = 1
                and then Postconditions_Unread'Result'Length = 5 + Decimal (Read)'Length + 38 + Decimal (Declared)'Length + 2 + Decimal (Declared - Read)'Length + 64
                and then Postconditions_Unread'Result (1 .. 5) = "read ";

   function Preconditions_Unread (Read : Count; Declared : Count) return String is
     ("read " & Decimal (Read) & " preconditions but the source states " & Decimal (Declared) & ": " & Decimal (Declared - Read) & " contract(s) were not read, so no grade is claimed for this file")
   with Pre => Read < Declared,
        Post => Preconditions_Unread'Result'First = 1
                and then Preconditions_Unread'Result'Length = 5 + Decimal (Read)'Length + 37 + Decimal (Declared)'Length + 2 + Decimal (Declared - Read)'Length + 64
                and then Preconditions_Unread'Result (1 .. 5) = "read ";

   function Nothing_Graded (Read : Count; Definitions : Count) return String is
     ("no function was graded: " & Decimal (Read) & " read, " & Decimal (Definitions) & " of them definition-only (no postcondition); no package grade is claimed")
   with Post => Nothing_Graded'Result'First = 1
                and then Nothing_Graded'Result'Length = 24 + Decimal (Read)'Length + 7 + Decimal (Definitions)'Length + 72
                and then Nothing_Graded'Result (1 .. 24) = "no function was graded: ";

end Lovelace_Refusal_Texts_Pkg;
