--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 2f04e41af624c0ed334a4e06193e466be4eaf1e2f04190d55c53c5b72082fc05
--
with Lovelace_Go_Quote_Pkg;
use Lovelace_Go_Quote_Pkg;

package Lovelace_Wire_Line_Builder_Pkg with SPARK_Mode, Pure is

   Max_Count  : constant := 100_000;
   Max_Quoted : constant := 4 * Max_Input + 2;

   subtype Count is Natural range 0 .. Max_Count;

   Failure_Head : constant String := "{""battery"":""check-cores-mcp"",""battery_ran"":""false"",""refusal_present"":""true"",""refusal"":";
   Failure_Tail : constant String := ",""error_count"":""0"",""functions_read"":""0"",""functions_graded"":""0"",""definitions_only"":""0"",""postconditions_declared"":""0"",""postconditions_read"":""0"",""theorem_count"":""0"",""runtime_only_count"":""0"",""unexercised_count"":""0"",""refused_count"":""0"",""grade_lines"":""0""}";
   Ran_Head       : constant String := "{""battery"":""check-cores-mcp"",""battery_ran"":""true"",""refusal_present"":";
   Refusal_Key    : constant String := ",""refusal"":";
   Error_Key      : constant String := ",""error_count"":";
   Read_Key       : constant String := ",""functions_read"":";
   Graded_Key     : constant String := ",""functions_graded"":";
   Defs_Key       : constant String := ",""definitions_only"":";
   Declared_Key   : constant String := ",""postconditions_declared"":";
   Posts_Read_Key : constant String := ",""postconditions_read"":";
   Theorem_Key    : constant String := ",""theorem_count"":";
   Runtime_Key    : constant String := ",""runtime_only_count"":";
   Unexercised_Key : constant String := ",""unexercised_count"":";
   Refused_Key    : constant String := ",""refused_count"":";
   Lines_Key      : constant String := ",""grade_lines"":";
   True_Value     : constant String := """true""";
   False_Value    : constant String := """false""";

   type Wire_Counts is record
      Refusal_Present    : Boolean := False;
      Error_Count        : Count   := 0;
      Functions_Read     : Count   := 0;
      Functions_Graded   : Count   := 0;
      Definitions_Only   : Count   := 0;
      Posts_Declared     : Count   := 0;
      Posts_Read         : Count   := 0;
      Theorem_Count      : Count   := 0;
      Runtime_Only_Count : Count   := 0;
      Unexercised_Count  : Count   := 0;
      Refused_Count      : Count   := 0;
      Grade_Lines        : Count   := 0;
   end record;

   function Digit_Image (D : Natural) return String is
     (String'(1 => Character'Val (48 + D)))
     with Pre  => D <= 9,
          Post => Digit_Image'Result'First = 1 and then Digit_Image'Result'Length = 1;

   function Width (N : Count) return Positive is
     (if N < 10 then 1
      elsif N < 100 then 2
      elsif N < 1_000 then 3
      elsif N < 10_000 then 4
      elsif N < 100_000 then 5
      else 6);

   function Decimal (N : Count) return String is
     (if N < 10 then Digit_Image (N) else Decimal (N / 10) & Digit_Image (N mod 10))
     with Post => Decimal'Result'First = 1 and then Decimal'Result'Length = Width (N),
          Subprogram_Variant => (Decreases => N);

   function Num (N : Count) return String is
     ('"' & Decimal (N) & '"')
     with Post => Num'Result'Length = Decimal (N)'Length + 2;

   function Bool (B : Boolean) return String is
     (if B then True_Value else False_Value)
     with Post => Bool'Result'Length >= 6 and then Bool'Result'Length <= 7;

   function Quotable (S : String) return Boolean is
     (S'First = 1 and then S'Length <= Max_Input and then All_Ascii (S));

   function Failure_Line (Quoted_Error : String) return String is
     (Failure_Head & Quoted_Error & Failure_Tail)
     with Pre  => Quoted_Error'Length <= Max_Quoted,
          Post => Failure_Line'Result'Length = Failure_Head'Length + Quoted_Error'Length + Failure_Tail'Length
                  and then Failure_Line'Result'First = 1
                  and then Failure_Line'Result (1) = '{'
                  and then Failure_Line'Result (Failure_Line'Result'Last) = '}';

   function Plain_Failure_Line (Error_Text : String) return String is
     (Failure_Line (Quote (Error_Text)))
     with Pre => Quotable (Error_Text);

   function Counts_Part (C : Wire_Counts) return String is
     (Error_Key & Num (C.Error_Count)
      & Read_Key & Num (C.Functions_Read)
      & Graded_Key & Num (C.Functions_Graded)
      & Defs_Key & Num (C.Definitions_Only)
      & Declared_Key & Num (C.Posts_Declared)
      & Posts_Read_Key & Num (C.Posts_Read)
      & Theorem_Key & Num (C.Theorem_Count)
      & Runtime_Key & Num (C.Runtime_Only_Count)
      & Unexercised_Key & Num (C.Unexercised_Count)
      & Refused_Key & Num (C.Refused_Count)
      & Lines_Key & Num (C.Grade_Lines))
     with Post => Counts_Part'Result'Length >= 248 and then Counts_Part'Result'Length <= 303;

   function Ran_Line (C : Wire_Counts; Quoted_Refusal : String) return String is
     (Ran_Head & Bool (C.Refusal_Present) & Refusal_Key & Quoted_Refusal & Counts_Part (C) & "}")
     with Pre  => Quoted_Refusal'Length <= Max_Quoted,
          Post => Ran_Line'Result'First = 1
                  and then Ran_Line'Result (1) = '{'
                  and then Ran_Line'Result (Ran_Line'Result'Last) = '}'
                  and then Ran_Line'Result'Length
                           = Ran_Head'Length + Bool (C.Refusal_Present)'Length + Refusal_Key'Length
                             + Quoted_Refusal'Length + Counts_Part (C)'Length + 1;

   function Plain_Ran_Line (C : Wire_Counts; Refusal : String) return String is
     (Ran_Line (C, Quote (Refusal)))
     with Pre => Quotable (Refusal);

end Lovelace_Wire_Line_Builder_Pkg;
