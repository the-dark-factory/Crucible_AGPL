--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Reply_Text_Pkg — the text of every reply the door sends, as pure functions of scalars and
--  short strings (BRIEF_crucible_door_split_2026-09-11 §1, unit 1 of the door split).
--  Spec: ANVIL lane, wu-crucible-reply-text round G, 2026-09-12 09:36, planner Rosie
--  qwen3.8-27b-ada:v0.3, proof_gate accepted (0 unproved, 0 compile errors, 0 cheat markers,
--  9 postconditions proved). Rounds A–F parked by the lane and advised (cases ccb1feb8,
--  4e01b20f, 7efb8383, 9c285e10, f41908a2, 91d5449f): backslash escape, 445-char line + bare
--  keys, 'Image lower bound + 12-operand ends, nested key, declaration order, regression under a
--  14 KB accreted prompt -> prose consolidated for G. Body: the lane's body-fill, candidate 2,
--  job verified 09:36. Re-proved as built on bill: level 2, -gnatwa -gnatwe, 237 checks, 0
--  unproved, 0 warnings. Comment-stripped sha of this spec equals the forged round-G spec.
--  OWED (obligation 6, weak contract): Escape_Quotes's Post bounds only the LENGTH; the
--  filled body escapes the quote but NOT the backslash the prose asked for, and the contract
--  cannot see it. Strengthen the Post (every quote and backslash in S is preceded by a
--  backslash in the result) in a later round before the door relies on it.
package Reply_Text_Pkg with SPARK_Mode is

   function Q (S : String) return String
     is ('"' & S & '"')
     with Pre  => (S'First = 1 and then S'Length <= 512),
          Post => (Q'Result'Length = S'Length + 2);

   function Json_Bool (B : Boolean) return String
     is ((if B then "true" else "false"))
     with Post => (if B then Json_Bool'Result'Length = 4 else Json_Bool'Result'Length = 5);

   function Image_Of (N : Integer) return String
     is ((if N < 0 then Integer'Image (N) else Integer'Image (N) (2 .. Integer'Image (N)'Last)))
     with Post => (Image_Of'Result'Length <= 12);

   function Escape_Quotes (S : String) return String
     with Pre  => (S'First = 1 and then S'Length <= 512),
          Post => (Escape_Quotes'Result'Length >= S'Length and then Escape_Quotes'Result'Length <= 2 * S'Length);

   Jsonrpc_Key           : constant String := Q ("jsonrpc") & ":";
   Id_Key                : constant String := Q ("id") & ":";
   Error_Key             : constant String := Q ("error") & ":";
   Code_Key              : constant String := Q ("code") & ":";
   Message_Key           : constant String := Q ("message") & ":";
   Result_Key            : constant String := Q ("result") & ":";
   Protocolversion_Key   : constant String := Q ("protocolVersion") & ":";
   Capabilities_Key      : constant String := Q ("capabilities") & ":";
   Serverinfo_Key        : constant String := Q ("serverInfo") & ":";
   Name_Key              : constant String := Q ("name") & ":";
   Version_Key           : constant String := Q ("version") & ":";
   Tools_Key             : constant String := Q ("tools") & ":";
   Description_Key       : constant String := Q ("description") & ":";
   Input_Schema_Key      : constant String := Q ("inputSchema") & ":";
   Type_Key              : constant String := Q ("type") & ":";
   Properties_Key        : constant String := Q ("properties") & ":";
   Requested_Key         : constant String := Q ("requested") & ":";
   Judge_Key             : constant String := Q ("judge") & ":";
   Edition_Key           : constant String := Q ("edition") & ":";
   Refused_Key           : constant String := Q ("refused") & ":";
   Reason_Key            : constant String := Q ("reason") & ":";
   Is_accepted_Key       : constant String := Q ("is_accepted") & ":";
   Fault_count_Key       : constant String := Q ("fault_count") & ":";
   First_fault_Key       : constant String := Q ("first_fault") & ":";

   Object_Word           : constant String := Q ("object");
   String_Word           : constant String := Q ("string");
   Version_Word          : constant String := Q ("2.0");
   Protocol_Word         : constant String := Q ("2025-06-18");
   Server_Version_Word   : constant String := Q ("0.1.0");
   Agpl_Word             : constant String := Q ("agpl");
   Commercial_Word       : constant String := Q ("commercial");

   Licence_Gate_Schema   : constant String :=
     "{" & Type_Key & Object_Word & "," & Properties_Key & "{" &
     Requested_Key & "{" & Type_Key & String_Word & "}" & "}" & "}";

   Self_Judge_Schema     : constant String :=
     "{" & Type_Key & Object_Word & "," & Properties_Key & "{" &
     Judge_Key & "{" & Type_Key & String_Word & "}" & "}" & "}";

   Licence_Gate_Tool     : constant String :=
     "{" & Name_Key & Q ("licence_gate") & "," & Description_Key &
     Q ("refuse or permit a requested emission licence for this edition") &
     "," & Input_Schema_Key & Licence_Gate_Schema & "}";

   Self_Judge_Tool       : constant String :=
     "{" & Name_Key & Q ("self_judge") & "," & Description_Key &
     Q ("judge a decomposition by this factory's own judge") &
     "," & Input_Schema_Key & Self_Judge_Schema & "}";

   Tools_Inner           : constant String :=
     Tools_Key & "[" & Licence_Gate_Tool & "," & Self_Judge_Tool & "]";

   function Error_Reply (Id_Text : String; Code : Integer; Message : String) return String
     is ("{" & Jsonrpc_Key & Version_Word & "," & Id_Key & Id_Text & "," & Error_Key & "{" & Code_Key & Image_Of (Code) & "," & Message_Key & Q (Message) & "}" & "}")
     with Pre  => (Id_Text'First = 1 and then Id_Text'Length <= 512 and then Message'First = 1 and then Message'Length <= 512),
          Post => (Error_Reply'Result'Length >= 2 and then Error_Reply'Result (Error_Reply'Result'First) = '{' and then Error_Reply'Result (Error_Reply'Result'Last) = '}' and then Error_Reply'Result'Length <= 4096);

   function Result_Reply (Id_Text : String; Result_Text : String) return String
     is ("{" & Jsonrpc_Key & Version_Word & "," & Id_Key & Id_Text & "," & Result_Key & Result_Text & "}")
     with Pre  => (Id_Text'First = 1 and then Id_Text'Length <= 512 and then Result_Text'First = 1 and then Result_Text'Length <= 512),
          Post => (Result_Reply'Result'Length >= 2 and then Result_Reply'Result (Result_Reply'Result'First) = '{' and then Result_Reply'Result (Result_Reply'Result'Last) = '}' and then Result_Reply'Result'Length <= 4096);

   function Initialize_Result (Server_Name : String) return String
     is ("{" & Protocolversion_Key & Protocol_Word & "," & Capabilities_Key & "{" & Tools_Key & "{" & "}" & "}" & "," & Serverinfo_Key & "{" & Name_Key & Q (Server_Name) & "," & Version_Key & Server_Version_Word & "}" & "}")
     with Pre  => (Server_Name'First = 1 and then Server_Name'Length <= 512),
          Post => (Initialize_Result'Result'Length >= 2 and then Initialize_Result'Result (Initialize_Result'Result'First) = '{' and then Initialize_Result'Result (Initialize_Result'Result'Last) = '}' and then Initialize_Result'Result'Length <= 4096);

   function Tools_List_Result return String
     is ("{" & Tools_Inner & "}")
     with Post => (Tools_List_Result'Result'Length >= 2 and then Tools_List_Result'Result (Tools_List_Result'Result'First) = '{' and then Tools_List_Result'Result (Tools_List_Result'Result'Last) = '}' and then Tools_List_Result'Result'Length <= 4096);

   function Licence_Gate_Text (Edition_Is_Agpl : Boolean; Requested_Word : String; Refused : Boolean; Reason : String) return String
     is ("{" & Edition_Key & (if Edition_Is_Agpl then Agpl_Word else Commercial_Word) & "," & Requested_Key & Q (Requested_Word) & "," & Refused_Key & Json_Bool (Refused) & "," & Reason_Key & Q (Reason) & "}")
     with Pre  => (Requested_Word'First = 1 and then Requested_Word'Length <= 512 and then Reason'First = 1 and then Reason'Length <= 512),
          Post => (Licence_Gate_Text'Result'Length >= 2 and then Licence_Gate_Text'Result (Licence_Gate_Text'Result'First) = '{' and then Licence_Gate_Text'Result (Licence_Gate_Text'Result'Last) = '}' and then Licence_Gate_Text'Result'Length <= 4096);

   function Self_Judge_Text (Is_Accepted : Boolean; Fault_Count : Natural; First_Fault : String) return String
     is ("{" & Is_accepted_Key & Json_Bool (Is_Accepted) & "," & Fault_count_Key & Image_Of (Fault_Count) & "," & First_fault_Key & Q (First_Fault) & "}")
     with Pre  => (First_Fault'First = 1 and then First_Fault'Length <= 512),
          Post => (Self_Judge_Text'Result'Length >= 2 and then Self_Judge_Text'Result (Self_Judge_Text'Result'First) = '{' and then Self_Judge_Text'Result (Self_Judge_Text'Result'Last) = '}' and then Self_Judge_Text'Result'Length <= 4096);

end Reply_Text_Pkg;
