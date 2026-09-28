--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: cf9edec64a3a56fb0e176ccebfd3ffcca460d591743b496b8498b78ab7f53013
--
with Json_Scan_Pkg;
with Rail_Config_Pkg;

package Model_Rail_Fields_Pkg with SPARK_Mode is

   Model_Key      : constant String := "model";
   Protocol_Key   : constant String := "protocol";
   Max_Tokens_Key : constant String := "max_tokens";
   Ollama_Word    : constant String := "ollama";
   Openai_Word    : constant String := "openai";
   Tier_Key       : constant String := "tier";
   Standard_Word  : constant String := "standard";
   Elevated_Word  : constant String := "elevated";
   Num_Ctx_Key    : constant String := "num_ctx";
   Default_Num_Ctx : constant := 32_768;

   type Protocol_Kind is (Protocol_Ollama, Protocol_Openai, Protocol_Unknown);
   type Tier_Kind is (Tier_Standard, Tier_Elevated, Tier_Unknown);

   function Is_Model_Char (C : Character) return Boolean
     is ((C in 'A' .. 'Z') or else (C in 'a' .. 'z') or else (C in '0' .. '9') or else C = '.' or else C = '_' or else C = ':' or else C = '-' or else C = '/')
     with Post => (if Is_Model_Char'Result then C /= '"');

   function Model_Ok (Line : String) return Boolean
     is (Rail_Config_Pkg.Contents (Line, Model_Key).found
         and then Rail_Config_Pkg.Contents (Line, Model_Key).first <= Rail_Config_Pkg.Contents (Line, Model_Key).last
         and then Rail_Config_Pkg.Contents (Line, Model_Key).last - Rail_Config_Pkg.Contents (Line, Model_Key).first + 1 <= 64
         and then (for all K in Rail_Config_Pkg.Contents (Line, Model_Key).first .. Rail_Config_Pkg.Contents (Line, Model_Key).last
                   => Is_Model_Char (Line (K))))
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line,
          Post => (if Model_Ok'Result then Rail_Config_Pkg.Contents (Line, Model_Key).found);

   function Protocol_Of (Line : String) return Protocol_Kind
     is ((if not Rail_Config_Pkg.Contents (Line, Protocol_Key).found then Protocol_Unknown
          elsif Json_Scan_Pkg.Equals_Literal (Line, Rail_Config_Pkg.Contents (Line, Protocol_Key), Ollama_Word) then Protocol_Ollama
          elsif Json_Scan_Pkg.Equals_Literal (Line, Rail_Config_Pkg.Contents (Line, Protocol_Key), Openai_Word) then Protocol_Openai
          else Protocol_Unknown))
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line,
          Post => (if not Rail_Config_Pkg.Contents (Line, Protocol_Key).found then Protocol_Of'Result = Protocol_Unknown);

   function Max_Tokens_Ok (Line : String) return Boolean
     is (Rail_Config_Pkg.Is_Number (Line, Rail_Config_Pkg.Contents (Line, Max_Tokens_Key), 1, 32_768))
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line,
          Post => (if Max_Tokens_Ok'Result then Rail_Config_Pkg.Contents (Line, Max_Tokens_Key).found);

   function Num_Ctx_Ok (Line : String) return Boolean
     is (not Json_Scan_Pkg.Has_Key (Line, Num_Ctx_Key)
         or else Rail_Config_Pkg.Is_Number (Line, Rail_Config_Pkg.Contents (Line, Num_Ctx_Key), 2_048, 262_144))
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line,
          Post => ((if not Json_Scan_Pkg.Has_Key (Line, Num_Ctx_Key) then Num_Ctx_Ok'Result)
                   and then (if Num_Ctx_Ok'Result and then Json_Scan_Pkg.Has_Key (Line, Num_Ctx_Key) then Rail_Config_Pkg.Contents (Line, Num_Ctx_Key).found));

   function Is_Valid_Model_Line (Line : String) return Boolean
     is (Model_Ok (Line) and then Protocol_Of (Line) /= Protocol_Unknown and then Max_Tokens_Ok (Line) and then Num_Ctx_Ok (Line))
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line,
          Post => ((if Is_Valid_Model_Line'Result then Protocol_Of (Line) /= Protocol_Unknown)
                   and then (if Is_Valid_Model_Line'Result then Num_Ctx_Ok (Line)));

   function Model_Span (Line : String) return Json_Scan_Pkg.Span_Type
     is (Rail_Config_Pkg.Contents (Line, Model_Key))
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line and then Is_Valid_Model_Line (Line),
          Post => Model_Span'Result.last - Model_Span'Result.first + 1 in 1 .. 64;

   function Max_Tokens_Of (Line : String) return Positive
     is (Rail_Config_Pkg.Number_Value (Line, Rail_Config_Pkg.Contents (Line, Max_Tokens_Key).first, Rail_Config_Pkg.Contents (Line, Max_Tokens_Key).last))
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line and then Is_Valid_Model_Line (Line),
          Post => Max_Tokens_Of'Result in 1 .. 32_768;

   function Num_Ctx_Of (Line : String) return Positive
     is ((if Json_Scan_Pkg.Has_Key (Line, Num_Ctx_Key)
          then Rail_Config_Pkg.Number_Value (Line, Rail_Config_Pkg.Contents (Line, Num_Ctx_Key).first, Rail_Config_Pkg.Contents (Line, Num_Ctx_Key).last)
          else Default_Num_Ctx))
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line and then Is_Valid_Model_Line (Line),
          Post => Num_Ctx_Of'Result in 2_048 .. 262_144
                  and then (if not Json_Scan_Pkg.Has_Key (Line, Num_Ctx_Key) then Num_Ctx_Of'Result = Default_Num_Ctx);

   function Tier_Of (Line : String) return Tier_Kind
     is ((if not Json_Scan_Pkg.Has_Key (Line, Tier_Key) then Tier_Standard
          elsif not Rail_Config_Pkg.Contents (Line, Tier_Key).found then Tier_Unknown
          elsif Json_Scan_Pkg.Equals_Literal (Line, Rail_Config_Pkg.Contents (Line, Tier_Key), Standard_Word) then Tier_Standard
          elsif Json_Scan_Pkg.Equals_Literal (Line, Rail_Config_Pkg.Contents (Line, Tier_Key), Elevated_Word) then Tier_Elevated
          else Tier_Unknown))
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line,
          Post => ((if not Json_Scan_Pkg.Has_Key (Line, Tier_Key) then Tier_Of'Result = Tier_Standard)
                   and then (if Tier_Of'Result = Tier_Elevated then Rail_Config_Pkg.Contents (Line, Tier_Key).found and then Json_Scan_Pkg.Equals_Literal (Line, Rail_Config_Pkg.Contents (Line, Tier_Key), Elevated_Word))
                   and then (if Tier_Of'Result = Tier_Standard and then Json_Scan_Pkg.Has_Key (Line, Tier_Key) then Rail_Config_Pkg.Contents (Line, Tier_Key).found and then Json_Scan_Pkg.Equals_Literal (Line, Rail_Config_Pkg.Contents (Line, Tier_Key), Standard_Word)));

   function Is_Valid_Tiered_Model_Line (Line : String) return Boolean
     is (Is_Valid_Model_Line (Line) and then Tier_Of (Line) /= Tier_Unknown)
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line,
          Post => ((if Is_Valid_Tiered_Model_Line'Result then Is_Valid_Model_Line (Line))
                   and then (if Is_Valid_Tiered_Model_Line'Result then Tier_Of (Line) /= Tier_Unknown)
                   and then (if Is_Valid_Model_Line (Line) and then Tier_Of (Line) /= Tier_Unknown then Is_Valid_Tiered_Model_Line'Result));

end Model_Rail_Fields_Pkg;
