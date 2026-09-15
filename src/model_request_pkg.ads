--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 8102dfdb95d2f7d2fb909e0641775f7c98e5daedd0c174b6f429450853bc04fe
--
with Reply_Text_Pkg;

package Model_Request_Pkg with SPARK_Mode is

   Max_Model : constant := 64;
   Max_Prompt : constant := 4096;
   Max_Reply : constant := 65536;

   Model_Key : constant String := Reply_Text_Pkg.Q ("model") & ":";
   Messages_Key : constant String := Reply_Text_Pkg.Q ("messages") & ":";
   Role_Key : constant String := Reply_Text_Pkg.Q ("role") & ":";
   Content_Key : constant String := Reply_Text_Pkg.Q ("content") & ":";
   Stream_Key : constant String := Reply_Text_Pkg.Q ("stream") & ":";
   User_Role : constant String := Reply_Text_Pkg.Q ("user");
   Brace_Open : constant String := "{";
   Brace_Close : constant String := "}";
   Bracket_Open : constant String := "[";
   Bracket_Close : constant String := "]";
   Comma : constant String := ",";

   function Request_Text (Model : String; Prompt : String) return String is
     (Brace_Open
      & Model_Key & Reply_Text_Pkg.Q (Model) & Comma
      & Messages_Key & Bracket_Open & Brace_Open
      & Role_Key & User_Role & Comma
      & Content_Key & Reply_Text_Pkg.Q (Reply_Text_Pkg.Escape_Quotes (Prompt))
      & Brace_Close & Bracket_Close & Comma
      & Stream_Key & Reply_Text_Pkg.Json_Bool (False)
      & Brace_Close)
   with Global => null,
        Pre  => Model'First = 1 and then Model'Length >= 1 and then Model'Length <= Max_Model
               and then Prompt'First = 1 and then Prompt'Length <= Max_Prompt,
        Post => Request_Text'Result'Length >= 2
                and then Request_Text'Result (Request_Text'Result'First) = '{'
                and then Request_Text'Result (Request_Text'Result'Last) = '}'
                and then Request_Text'Result'Length <= 2 * Prompt'Length + Model'Length + 96;

   type Fault_Kind is (No_Fault, Model_Unreachable, Model_Timeout, Reply_Over_Bound);

   function Reply_Fault (Reached : Boolean; Timed_Out : Boolean; Reply_Length : Natural) return Fault_Kind is
     (if not Reached then Model_Unreachable elsif Timed_Out then Model_Timeout elsif Reply_Length > Max_Reply then Reply_Over_Bound else No_Fault)
   with Global => null;

   function Reply_Accepted (Reached : Boolean; Timed_Out : Boolean; Reply_Length : Natural) return Boolean is
     (Reply_Fault (Reached, Timed_Out, Reply_Length) = No_Fault)
   with Global => null,
        Post => Reply_Accepted'Result = (Reached and then not Timed_Out and then Reply_Length <= Max_Reply);

end Model_Request_Pkg;
