--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 4addb87ef8c4e096eed411a7d1d750f8d9e1257bb536b6e7a8b8577ce5831481
--
with Json_Scan_Pkg;
with Json_Rpc_Frame_Pkg;

package Frame_Facts_Pkg with SPARK_Mode is

   use type Json_Scan_Pkg.Kind_Type;
   use type Json_Rpc_Frame_Pkg.Method_Type;

   Jsonrpc_Key      : constant String := "jsonrpc";
   Id_Key           : constant String := "id";
   Params_Key       : constant String := "params";
   Method_Key       : constant String := "method";
   Name_Key         : constant String := "name";
   Requested_Key    : constant String := "requested";
   Judge_Key        : constant String := "judge";
   Version_Lit      : constant String := "2.0";
   Initialize_Lit   : constant String := "initialize";
   Initialized_Lit  : constant String := "notifications/initialized";
   Tools_List_Lit   : constant String := "tools/list";
   Tools_Call_Lit   : constant String := "tools/call";
   Licence_Gate_Lit : constant String := "licence_gate";
   Self_Judge_Lit   : constant String := "self_judge";
   Intake_Check_Lit : constant String := "intake_check";
   Sheet_Key        : constant String := "sheet";
   Prove_Unit_Lit   : constant String := "prove_unit";
   Unit_Key         : constant String := "unit";
   Spec_Key         : constant String := "spec";
   Body_Key         : constant String := "body";
   Level_Key        : constant String := "level";
   Forge_Lit        : constant String := "forge";
   Tower_Import_Lit   : constant String := "tower_import";
   Path_Key           : constant String := "path";
   Palais_Shelf_Lit   : constant String := "palais.shelf";
   Palais_Claim_Lit   : constant String := "palais.claim";
   Palais_Fetch_Lit   : constant String := "palais.fetch";
   Palais_Attempt_Lit : constant String := "palais.attempt";
   Palais_Submit_Lit  : constant String := "palais.submit";
   Digest_Key         : constant String := "digest";
   Key_Key            : constant String := "key";
   Palais_Enrol_Lit   : constant String := "palais.enrol";
   Codename_Key       : constant String := "codename";

   type Tool_Type is (T_Licence_Gate, T_Self_Judge, T_Intake_Check, T_Prove_Unit, T_Forge, T_Tower_Import, T_Palais_Shelf, T_Palais_Claim, T_Palais_Fetch, T_Palais_Attempt, T_Palais_Submit, T_Palais_Enrol, T_Unknown);

   function Parse_Failed (Line : String) return Boolean is
     ((not (Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).found and then Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).kind = Json_Scan_Pkg.K_String)))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Parse_Failed'Result = not (Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).found and then Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).kind = Json_Scan_Pkg.K_String));

   function Jsonrpc_Is_2_0 (Line : String) return Boolean is
     ((Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).found and then Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).kind = Json_Scan_Pkg.K_String and then Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key)), Version_Lit)))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => ((if Jsonrpc_Is_2_0'Result then not Parse_Failed (Line)) and then (if Jsonrpc_Is_2_0'Result then Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).found));

   function Has_Id (Line : String) return Boolean is
     (Json_Scan_Pkg.Value_Span (Line, Id_Key).found)
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Has_Id'Result = Json_Scan_Pkg.Value_Span (Line, Id_Key).found);

   function Id_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Id_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Id_Span'Result.found = Has_Id (Line));

   function Has_Params (Line : String) return Boolean is
     (Json_Scan_Pkg.Value_Span (Line, Params_Key).found)
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Has_Params'Result = Json_Scan_Pkg.Value_Span (Line, Params_Key).found);

   function Method_Of (Line : String) return Json_Rpc_Frame_Pkg.Method_Type is
     ((if not (Json_Scan_Pkg.Value_Span (Line, Method_Key).found and then Json_Scan_Pkg.Value_Span (Line, Method_Key).kind = Json_Scan_Pkg.K_String) then Json_Rpc_Frame_Pkg.M_Unknown elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Method_Key)), Initialize_Lit) then Json_Rpc_Frame_Pkg.M_Initialize elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Method_Key)), Initialized_Lit) then Json_Rpc_Frame_Pkg.M_Initialized elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Method_Key)), Tools_List_Lit) then Json_Rpc_Frame_Pkg.M_Tools_List elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Method_Key)), Tools_Call_Lit) then Json_Rpc_Frame_Pkg.M_Tools_Call else Json_Rpc_Frame_Pkg.M_Unknown))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => ((if not Json_Scan_Pkg.Value_Span (Line, Method_Key).found then Method_Of'Result = Json_Rpc_Frame_Pkg.M_Unknown));

   function Tool_Of (Line : String) return Tool_Type is
     ((if not (Json_Scan_Pkg.Value_Span (Line, Name_Key).found and then Json_Scan_Pkg.Value_Span (Line, Name_Key).kind = Json_Scan_Pkg.K_String) then T_Unknown elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Licence_Gate_Lit) then T_Licence_Gate elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Self_Judge_Lit) then T_Self_Judge elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Intake_Check_Lit) then T_Intake_Check elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Prove_Unit_Lit) then T_Prove_Unit elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Forge_Lit) then T_Forge elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Tower_Import_Lit) then T_Tower_Import elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Palais_Shelf_Lit) then T_Palais_Shelf elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Palais_Claim_Lit) then T_Palais_Claim elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Palais_Fetch_Lit) then T_Palais_Fetch elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Palais_Attempt_Lit) then T_Palais_Attempt elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Palais_Submit_Lit) then T_Palais_Submit elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Palais_Enrol_Lit) then T_Palais_Enrol else T_Unknown))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => ((if not Json_Scan_Pkg.Value_Span (Line, Name_Key).found then Tool_Of'Result = T_Unknown));

   function Requested_Present (Line : String) return Boolean is
     (Json_Scan_Pkg.Value_Span (Line, Requested_Key).found)
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Requested_Present'Result = Json_Scan_Pkg.Value_Span (Line, Requested_Key).found);

   function Judge_Present (Line : String) return Boolean is
     (Json_Scan_Pkg.Value_Span (Line, Judge_Key).found)
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Judge_Present'Result = Json_Scan_Pkg.Value_Span (Line, Judge_Key).found);

   function Sheet_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Sheet_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Sheet_Span'Result.found = Json_Scan_Pkg.Value_Span (Line, Sheet_Key).found);

   function Unit_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Unit_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Unit_Span'Result.found = Json_Scan_Pkg.Value_Span (Line, Unit_Key).found);

   function Spec_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Spec_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Spec_Span'Result.found = Json_Scan_Pkg.Value_Span (Line, Spec_Key).found);

   function Body_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Body_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Body_Span'Result.found = Json_Scan_Pkg.Value_Span (Line, Body_Key).found);

   function Level_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Level_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Level_Span'Result.found = Json_Scan_Pkg.Value_Span (Line, Level_Key).found);

   function Path_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Path_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Path_Span'Result.found = Json_Scan_Pkg.Value_Span (Line, Path_Key).found);

   function Digest_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Digest_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Digest_Span'Result.found = Json_Scan_Pkg.Value_Span (Line, Digest_Key).found);

   function Key_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Key_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Key_Span'Result.found = Json_Scan_Pkg.Value_Span (Line, Key_Key).found);

   function Codename_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Codename_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Codename_Span'Result.found = Json_Scan_Pkg.Value_Span (Line, Codename_Key).found);

   function Facts_Of (Line : String) return Json_Rpc_Frame_Pkg.Facts_Type is
     ((parse_failed => Parse_Failed (Line), jsonrpc_is_2_0 => Jsonrpc_Is_2_0 (Line), has_id => Has_Id (Line), method => Method_Of (Line), has_params => Has_Params (Line)))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => ((Facts_Of'Result.parse_failed = Parse_Failed (Line)) and then (Facts_Of'Result.jsonrpc_is_2_0 = Jsonrpc_Is_2_0 (Line)) and then (Facts_Of'Result.has_id = Has_Id (Line)) and then (Facts_Of'Result.method = Method_Of (Line)) and then (Facts_Of'Result.has_params = Has_Params (Line)));

end Frame_Facts_Pkg;
