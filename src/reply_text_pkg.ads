--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: d12455a8fc335b5f226bf882f342c14e39897e82d219f0c75dc575169d82aace
--
with Palais_Tools_Pkg;

package Reply_Text_Pkg with SPARK_Mode is

   function Q (S : String) return String
     is ('"' & S & '"')
     with Pre  => (S'First = 1 and then S'Length <= 8192),
          Post => (Q'Result'Length = S'Length + 2);

   function Json_Bool (B : Boolean) return String
     is (if B then "true" else "false")
     with Post => (if B then Json_Bool'Result'Length = 4 else Json_Bool'Result'Length = 5);

   function Image_Of (N : Integer) return String
     is (if N < 0 then Integer'Image (N) else Integer'Image (N) (2 .. Integer'Image (N)'Last))
     with Post => Image_Of'Result'Length <= 12;

   function Escape_Quotes (S : String) return String
     with Global => null,
          Pre  => (S'First = 1 and then S'Length <= 4096),
          Post => (Escape_Quotes'Result'First = 1
                   and then Escape_Quotes'Result'Length >= S'Length
                   and then Escape_Quotes'Result'Length <= 2 * S'Length);

   Jsonrpc_Key : constant String := Q ("jsonrpc") & ":";
   Id_Key : constant String := Q ("id") & ":";
   Error_Key : constant String := Q ("error") & ":";
   Code_Key : constant String := Q ("code") & ":";
   Message_Key : constant String := Q ("message") & ":";
   Result_Key : constant String := Q ("result") & ":";
   Protocolversion_Key : constant String := Q ("protocolVersion") & ":";
   Capabilities_Key : constant String := Q ("capabilities") & ":";
   Serverinfo_Key : constant String := Q ("serverInfo") & ":";
   Name_Key : constant String := Q ("name") & ":";
   Version_Key : constant String := Q ("version") & ":";
   Tools_Key : constant String := Q ("tools") & ":";
   Description_Key : constant String := Q ("description") & ":";
   Input_Schema_Key : constant String := Q ("inputSchema") & ":";
   Type_Key : constant String := Q ("type") & ":";
   Properties_Key : constant String := Q ("properties") & ":";
   Requested_Key : constant String := Q ("requested") & ":";
   Sheet_Key : constant String := Q ("sheet") & ":";
   Unit_Key  : constant String := Q ("unit") & ":";
   Spec_Key  : constant String := Q ("spec") & ":";
   Body_Key  : constant String := Q ("body") & ":";
   Level_Key : constant String := Q ("level") & ":";
   Judge_Key : constant String := Q ("judge") & ":";
   Edition_Key : constant String := Q ("edition") & ":";
   Refused_Key : constant String := Q ("refused") & ":";
   Reason_Key : constant String := Q ("reason") & ":";
   Is_accepted_Key : constant String := Q ("is_accepted") & ":";
   Fault_count_Key : constant String := Q ("fault_count") & ":";
   First_fault_Key : constant String := Q ("first_fault") & ":";
   Content_Key : constant String := Q ("content") & ":";
   Text_Key : constant String := Q ("text") & ":";
   Structuredcontent_Key : constant String := Q ("structuredContent") & ":";

   Object_Word : constant String := Q ("object");
   String_Word : constant String := Q ("string");
   Version_Word : constant String := Q ("2.0");
   Protocol_Word : constant String := Q ("2025-06-18");
   Server_Version_Word : constant String := Q ("0.1.0");
   Agpl_Word : constant String := Q ("agpl");
   Commercial_Word : constant String := Q ("commercial");
   Text_Word : constant String := Q ("text");
   Requested_Word : constant String := Q ("requested");

   Licence_Gate_Schema : constant String :=
     "{" & Type_Key & Object_Word & "," & Properties_Key &
     "{" & Q ("requested") & ":" & "{" & Type_Key & String_Word &
     "}" & "}" & "}";

   Licence_Gate_Tool : constant String :=
     "{" & Name_Key & Q ("licence_gate") & "," & Description_Key &
     Q ("refuse or permit a requested emission licence for this edition") &
     "," & Input_Schema_Key & Licence_Gate_Schema & "}";

   Intake_Check_Schema : constant String :=
     "{" & Type_Key & Object_Word & "," & Properties_Key &
     "{" & Sheet_Key & "{" & Type_Key & String_Word & "}" & "}" & "}";

   Intake_Check_Tool : constant String :=
     "{" & Name_Key & Q ("intake_check") & "," & Description_Key &
     Q ("measure a spec sheet and refuse it with named gaps, or permit it to be forged") &
     "," & Input_Schema_Key & Intake_Check_Schema & "}";

   Unit_Prop  : constant String := Unit_Key & "{" & Type_Key & String_Word & "}";
   Spec_Prop  : constant String := Spec_Key & "{" & Type_Key & String_Word & "}";
   Body_Prop  : constant String := Body_Key & "{" & Type_Key & String_Word & "}";
   Level_Prop  : constant String := Level_Key & "{" & Type_Key & String_Word & "}";
   Prove_Unit_Props  : constant String := Unit_Prop & "," & Spec_Prop & "," & Body_Prop & "," & Level_Prop;
   Prove_Unit_Schema : constant String :=
     "{" & Type_Key & Object_Word & "," & Properties_Key & "{" & Prove_Unit_Props & "}" & "}";
   Prove_Unit_Tool   : constant String :=
     "{" & Name_Key & Q ("prove_unit") & "," & Description_Key &
     Q ("prove one unit over the prover rail; the outcome is decided by the proven rail judge") &
     "," & Input_Schema_Key & Prove_Unit_Schema & "}";
   Forge_Prop   : constant String := Sheet_Key & "{" & Type_Key & String_Word & "}";
   Forge_Obj    : constant String := Type_Key & Object_Word & "," & Properties_Key;
   Forge_Schema : constant String := "{" & Forge_Obj & "{" & Forge_Prop & "}" & "}";
   Forge_Name   : constant String := Name_Key & Q ("forge");
   Forge_Desc   : constant String := Description_Key & Q ("carry one spec sheet through the pipeline; nothing emitted unless every gate passed");
   Forge_Tool   : constant String := "{" & Forge_Name & "," & Forge_Desc & "," & Input_Schema_Key & Forge_Schema & "}";
   First_Two_Tools   : constant String := Licence_Gate_Tool & "," & Intake_Check_Tool;
   Last_Two_Tools : constant String := Prove_Unit_Tool & "," & Forge_Tool;
   All_Tools    : constant String := First_Two_Tools & "," & Last_Two_Tools & "," & Palais_Tools_Pkg.Palais_Tools;
   subtype Reply_String is String with Dynamic_Predicate => Reply_String'Length <= 8192;
   Tools_Inner  : constant Reply_String := Tools_Key & "[" & All_Tools & "]";

   function Error_Reply (Id_Text : String; Code : Integer; Message : String) return String
     is ("{" & Jsonrpc_Key & Version_Word & "," & Id_Key & Id_Text & "," & Error_Key & "{" & Code_Key & Image_Of (Code) & "," & Message_Key & Q (Message) & "}" & "}")
     with Pre  => (Id_Text'First = 1 and then Id_Text'Length <= 4096 and then Message'First = 1 and then Message'Length <= 4096),
          Post => (Error_Reply'Result'Length >= 2 and then Error_Reply'Result (Error_Reply'Result'First) = '{' and then Error_Reply'Result (Error_Reply'Result'Last) = '}' and then Error_Reply'Result'Length <= 16384);

   function Result_Reply (Id_Text : String; Result_Text : String) return String
     is ("{" & Jsonrpc_Key & Version_Word & "," & Id_Key & Id_Text & "," & Result_Key & Result_Text & "}")
     with Pre  => (Id_Text'First = 1 and then Id_Text'Length <= 4096 and then Result_Text'First = 1 and then Result_Text'Length <= 4096),
          Post => (Result_Reply'Result'Length >= 2 and then Result_Reply'Result (Result_Reply'Result'First) = '{' and then Result_Reply'Result (Result_Reply'Result'Last) = '}' and then Result_Reply'Result'Length <= 16384);

   function Initialize_Result (Server_Name : String) return String
     is ("{" & Protocolversion_Key & Protocol_Word & "," & Capabilities_Key & "{" & Tools_Key & "{" & "}" & "}" & "," & Serverinfo_Key & "{" & Name_Key & Q (Server_Name) & "," & Version_Key & Server_Version_Word & "}" & "}")
     with Pre  => (Server_Name'First = 1 and then Server_Name'Length <= 4096),
          Post => (Initialize_Result'Result'Length >= 2 and then Initialize_Result'Result (Initialize_Result'Result'First) = '{' and then Initialize_Result'Result (Initialize_Result'Result'Last) = '}' and then Initialize_Result'Result'Length <= 16384);

   function Tools_List_Result return String
     is ("{" & Tools_Inner & "}")
     with Post => (Tools_List_Result'Result'Length >= 2 and then Tools_List_Result'Result (Tools_List_Result'Result'First) = '{' and then Tools_List_Result'Result (Tools_List_Result'Result'Last) = '}' and then Tools_List_Result'Result'Length = Tools_Inner'Length + 2);

   function Licence_Gate_Text (Edition_Is_Agpl : Boolean; Requested_Word : String; Refused : Boolean; Reason : String) return String
     is ("{" & Edition_Key & (if Edition_Is_Agpl then Agpl_Word else Commercial_Word) & "," & Requested_Key & Q (Requested_Word) & "," & Refused_Key & Json_Bool (Refused) & "," & Reason_Key & Q (Reason) & "}")
     with Pre  => (Requested_Word'First = 1 and then Requested_Word'Length <= 4096 and then Reason'First = 1 and then Reason'Length <= 4096),
          Post => (Licence_Gate_Text'Result'Length >= 2 and then Licence_Gate_Text'Result (Licence_Gate_Text'Result'First) = '{' and then Licence_Gate_Text'Result (Licence_Gate_Text'Result'Last) = '}' and then Licence_Gate_Text'Result'Length <= 16384);

   function Self_Judge_Text (Is_Accepted : Boolean; Fault_Count : Natural; First_Fault : String) return String
     is ("{" & Is_accepted_Key & Json_Bool (Is_Accepted) & "," & Fault_count_Key & Image_Of (Fault_Count) & "," & First_fault_Key & Q (First_Fault) & "}")
     with Pre  => (First_Fault'First = 1 and then First_Fault'Length <= 4096),
          Post => (Self_Judge_Text'Result'Length >= 2 and then Self_Judge_Text'Result (Self_Judge_Text'Result'First) = '{' and then Self_Judge_Text'Result (Self_Judge_Text'Result'Last) = '}' and then Self_Judge_Text'Result'Length <= 16384);

   function Tool_Call_Result (Inner : String) return String
     is ("{" & Content_Key & "[" & "{" & Type_Key & Text_Word & "," & Text_Key & Q (Escape_Quotes (Inner)) & "}" & "]" & "," & Structuredcontent_Key & Inner & "}")
     with Pre  => (Inner'First = 1 and then Inner'Length <= 4096),
          Post => (Tool_Call_Result'Result'Length >= 2 and then Tool_Call_Result'Result (Tool_Call_Result'Result'First) = '{' and then Tool_Call_Result'Result (Tool_Call_Result'Result'Last) = '}' and then Tool_Call_Result'Result'Length <= 16384);

end Reply_Text_Pkg;
