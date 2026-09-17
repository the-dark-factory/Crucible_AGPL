--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1b5f7315b1beb56011bd8aa4ff4873b79b9192f0d404f5540ae2a4f0c3d79efc
--
with Json_Scan_Pkg;
with Rail_Config_Pkg;

package Model_Rail_Fields_Pkg with SPARK_Mode is

   Model_Key      : constant String := "model";
   Protocol_Key   : constant String := "protocol";
   Max_Tokens_Key : constant String := "max_tokens";
   Ollama_Word    : constant String := "ollama";
   Openai_Word    : constant String := "openai";

   type Protocol_Kind is (Protocol_Ollama, Protocol_Openai, Protocol_Unknown);

   function Is_Model_Char (C : Character) return Boolean
     with Post => (if Is_Model_Char'Result then C /= '"');

   function Model_Ok (Line : String) return Boolean
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line,
          Post => (if Model_Ok'Result then Rail_Config_Pkg.Contents (Line, Model_Key).found);

   function Protocol_Of (Line : String) return Protocol_Kind
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line,
          Post => (if not Rail_Config_Pkg.Contents (Line, Protocol_Key).found then Protocol_Of'Result = Protocol_Unknown);

   function Max_Tokens_Ok (Line : String) return Boolean
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line,
          Post => (if Max_Tokens_Ok'Result then Rail_Config_Pkg.Contents (Line, Max_Tokens_Key).found);

   function Is_Valid_Model_Line (Line : String) return Boolean
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line,
          Post => (if Is_Valid_Model_Line'Result then Protocol_Of (Line) /= Protocol_Unknown);

   function Model_Span (Line : String) return Json_Scan_Pkg.Span_Type
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line and then Is_Valid_Model_Line (Line),
          Post => Model_Span'Result.last - Model_Span'Result.first + 1 in 1 .. 64;

   function Max_Tokens_Of (Line : String) return Positive
     with Pre  => Line'First = 1 and then Line'Length <= Rail_Config_Pkg.Max_Line and then Is_Valid_Model_Line (Line),
          Post => Max_Tokens_Of'Result in 1 .. 32_768;

   function Is_Model_Char (C : Character) return Boolean is
     ((C in 'A' .. 'Z' or C in 'a' .. 'z' or C in '0' .. '9') or C = '.' or C = '_' or C = ':' or C = '-' or C = '/');

   function Model_Ok (Line : String) return Boolean is
     (Rail_Config_Pkg.Contents (Line, Model_Key).found
      and then Rail_Config_Pkg.Contents (Line, Model_Key).first <= Rail_Config_Pkg.Contents (Line, Model_Key).last
      and then Rail_Config_Pkg.Contents (Line, Model_Key).last - Rail_Config_Pkg.Contents (Line, Model_Key).first + 1 <= 64
      and then (for all K in Rail_Config_Pkg.Contents (Line, Model_Key).first .. Rail_Config_Pkg.Contents (Line, Model_Key).last => Is_Model_Char (Line (K))));

   function Protocol_Of (Line : String) return Protocol_Kind is
     ((if not Rail_Config_Pkg.Contents (Line, Protocol_Key).found then Protocol_Unknown
       elsif Json_Scan_Pkg.Equals_Literal (Line, Rail_Config_Pkg.Contents (Line, Protocol_Key), Ollama_Word) then Protocol_Ollama
       elsif Json_Scan_Pkg.Equals_Literal (Line, Rail_Config_Pkg.Contents (Line, Protocol_Key), Openai_Word) then Protocol_Openai
       else Protocol_Unknown));

   function Max_Tokens_Ok (Line : String) return Boolean is
     (Rail_Config_Pkg.Is_Number (Line, Rail_Config_Pkg.Contents (Line, Max_Tokens_Key), 1, 32_768));

   function Is_Valid_Model_Line (Line : String) return Boolean is
     (Model_Ok (Line) and then Protocol_Of (Line) /= Protocol_Unknown and then Max_Tokens_Ok (Line));

   function Model_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Rail_Config_Pkg.Contents (Line, Model_Key));

   function Max_Tokens_Of (Line : String) return Positive is
     (Rail_Config_Pkg.Number_Value (Line, Rail_Config_Pkg.Contents (Line, Max_Tokens_Key).first, Rail_Config_Pkg.Contents (Line, Max_Tokens_Key).last));

end Model_Rail_Fields_Pkg;
