--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 39035c2d95b66ffb611efdf8a7c056d7d61f3c4c4c84f64353358d19f51a21c0
--
with Reply_Text_Pkg;

package Model_Request_Pkg with SPARK_Mode is

   Max_Model : constant := 64;
   Max_Prompt : constant := 262_144;
   Max_Reply : constant := 1_048_576;

   Model_Key : constant String := Reply_Text_Pkg.Q ("model") & ":";
   Messages_Key : constant String := Reply_Text_Pkg.Q ("messages") & ":";
   Role_Key : constant String := Reply_Text_Pkg.Q ("role") & ":";
   Content_Key : constant String := Reply_Text_Pkg.Q ("content") & ":";
   Stream_Key : constant String := Reply_Text_Pkg.Q ("stream") & ":";
   Max_Tokens_Key : constant String := Reply_Text_Pkg.Q ("max_tokens") & ":";
   User_Role : constant String := Reply_Text_Pkg.Q ("user");
   Brace_Open : constant String := "{";
   Brace_Close : constant String := "}";
   Bracket_Open : constant String := "[";
   Bracket_Close : constant String := "]";
   Comma : constant String := ",";
   Quote : constant String := """";

   function Message_Part (Encoded : String) return String is
     (Brace_Open & Role_Key & User_Role & Comma & Content_Key & Quote & Encoded & Quote & Brace_Close)
   with Global => null,
        Pre  => Encoded'First = 1 and then Encoded'Length <= 2 * Max_Prompt
                and then (for all K in Encoded'Range => Encoded (K) in ' ' .. '~'),
        Post => Message_Part'Result'Length <= Encoded'Length + 64;

   function Request_Text (Model : String; Encoded : String) return String is
     (Brace_Open & Model_Key & Reply_Text_Pkg.Q (Model) & Comma & Messages_Key
      & Bracket_Open & Message_Part (Encoded) & Bracket_Close & Comma
      & Stream_Key & Reply_Text_Pkg.Json_Bool (False) & Brace_Close)
   with Global => null,
        Pre  => Model'First = 1 and then Model'Length >= 1 and then Model'Length <= Max_Model
                and then Encoded'First = 1 and then Encoded'Length <= 2 * Max_Prompt
                and then (for all K in Encoded'Range => Encoded (K) in ' ' .. '~'),
        Post => Request_Text'Result'Length >= 2
                and then Request_Text'Result (Request_Text'Result'First) = '{'
                and then Request_Text'Result (Request_Text'Result'Last) = '}'
                and then Request_Text'Result'Length <= Encoded'Length + Model'Length + 160;

   function Request_Text_Openai (Model : String; Encoded : String; Max_Tokens : Positive) return String is
     (Brace_Open & Model_Key & Reply_Text_Pkg.Q (Model) & Comma & Messages_Key
      & Bracket_Open & Message_Part (Encoded) & Bracket_Close & Comma
      & Max_Tokens_Key & Reply_Text_Pkg.Image_Of (Max_Tokens) & Comma
      & Stream_Key & Reply_Text_Pkg.Json_Bool (False) & Brace_Close)
   with Global => null,
        Pre  => Model'First = 1 and then Model'Length >= 1 and then Model'Length <= Max_Model
                and then Encoded'First = 1 and then Encoded'Length <= 2 * Max_Prompt
                and then (for all K in Encoded'Range => Encoded (K) in ' ' .. '~')
                and then Max_Tokens <= 32_768,
        Post => Request_Text_Openai'Result'Length >= 2
                and then Request_Text_Openai'Result (Request_Text_Openai'Result'First) = '{'
                and then Request_Text_Openai'Result (Request_Text_Openai'Result'Last) = '}'
                and then Request_Text_Openai'Result'Length <= Encoded'Length + Model'Length + 192;

   type Fault_Kind is (No_Fault, Model_Unreachable, Model_Timeout, Reply_Over_Bound);

   function Reply_Fault (Reached : Boolean; Timed_Out : Boolean; Reply_Length : Natural) return Fault_Kind is
     (if not Reached then Model_Unreachable elsif Timed_Out then Model_Timeout elsif Reply_Length > Max_Reply then Reply_Over_Bound else No_Fault)
   with Global => null;

   function Reply_Accepted (Reached : Boolean; Timed_Out : Boolean; Reply_Length : Natural) return Boolean is
     (Reply_Fault (Reached, Timed_Out, Reply_Length) = No_Fault)
   with Global => null,
        Post => Reply_Accepted'Result = (Reached and then not Timed_Out and then Reply_Length <= Max_Reply);

end Model_Request_Pkg;
