--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: a57b0059324ade33f4d45a46707585edd2d1436cdf34a7f55356c87f3c56adf5
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
   Arguments_Key    : constant String := "arguments";
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
   Rail_Show_Lit      : constant String := "rail.show";
   Rail_Set_Lit       : constant String := "rail.set";

   type Tool_Type is (T_Licence_Gate, T_Self_Judge, T_Intake_Check, T_Prove_Unit, T_Forge, T_Tower_Import, T_Palais_Shelf, T_Palais_Claim, T_Palais_Fetch, T_Palais_Attempt, T_Palais_Submit, T_Palais_Enrol, T_Rail_Show, T_Rail_Set, T_Unknown);

   --  Lineage 8 (2026-09-28): a JSON-RPC tools/call carries the tool's name at params.name
   --  and its arguments at params.arguments.<key>. Json_Scan_Pkg lineage 5 looks keys up at
   --  one level only, so the path is walked explicitly: a key anywhere else is not an argument.
   function Tool_Name_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Member_Of (Line, Json_Scan_Pkg.Value_Span (Line, Params_Key), Name_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576;

   function Arg_Span (Line : String; Key : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Member_Of (Line, Json_Scan_Pkg.Member_Of (Line, Json_Scan_Pkg.Value_Span (Line, Params_Key), Arguments_Key), Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576 and then Key'First = 1
                  and then Key'Length >= 1 and then Key'Length <= 64;

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
     ((if not (Tool_Name_Span (Line).found and then Tool_Name_Span (Line).kind = Json_Scan_Pkg.K_String) then T_Unknown elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Licence_Gate_Lit) then T_Licence_Gate elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Self_Judge_Lit) then T_Self_Judge elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Intake_Check_Lit) then T_Intake_Check elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Prove_Unit_Lit) then T_Prove_Unit elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Forge_Lit) then T_Forge elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Tower_Import_Lit) then T_Tower_Import elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Palais_Shelf_Lit) then T_Palais_Shelf elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Palais_Claim_Lit) then T_Palais_Claim elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Palais_Fetch_Lit) then T_Palais_Fetch elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Palais_Attempt_Lit) then T_Palais_Attempt elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Palais_Submit_Lit) then T_Palais_Submit elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Palais_Enrol_Lit) then T_Palais_Enrol elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Rail_Show_Lit) then T_Rail_Show elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Tool_Name_Span (Line)), Rail_Set_Lit) then T_Rail_Set else T_Unknown))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => ((if not Tool_Name_Span (Line).found then Tool_Of'Result = T_Unknown));

   function Requested_Present (Line : String) return Boolean is
     (Arg_Span (Line, Requested_Key).found)
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Requested_Present'Result = Arg_Span (Line, Requested_Key).found);

   function Judge_Present (Line : String) return Boolean is
     (Arg_Span (Line, Judge_Key).found)
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Judge_Present'Result = Arg_Span (Line, Judge_Key).found);

   function Sheet_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Arg_Span (Line, Sheet_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Sheet_Span'Result.found = Arg_Span (Line, Sheet_Key).found);

   function Unit_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Arg_Span (Line, Unit_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Unit_Span'Result.found = Arg_Span (Line, Unit_Key).found);

   function Spec_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Arg_Span (Line, Spec_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Spec_Span'Result.found = Arg_Span (Line, Spec_Key).found);

   function Body_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Arg_Span (Line, Body_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Body_Span'Result.found = Arg_Span (Line, Body_Key).found);

   function Level_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Arg_Span (Line, Level_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Level_Span'Result.found = Arg_Span (Line, Level_Key).found);

   function Path_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Arg_Span (Line, Path_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Path_Span'Result.found = Arg_Span (Line, Path_Key).found);

   function Digest_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Arg_Span (Line, Digest_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Digest_Span'Result.found = Arg_Span (Line, Digest_Key).found);

   function Key_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Arg_Span (Line, Key_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Key_Span'Result.found = Arg_Span (Line, Key_Key).found);

   function Codename_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Arg_Span (Line, Codename_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Codename_Span'Result.found = Arg_Span (Line, Codename_Key).found);

   --  Lineage 9 (2026-09-28, the A11 refusal messages): Json_Scan_Pkg lineage 5 answers "not found"
   --  for a key given twice, so the door could not tell a duplicated key from a missing one. With
   --  Json_Scan_Pkg lineage 6 it can: a key is DUPLICATED when its object is well-formed and two or
   --  more of its members carry that name. Duplicate_Key names the duplicates a tools/call is refused
   --  for: params.name, params.arguments, and each argument the named tool reads (rail.set keeps its
   --  own ruled reading, "an argument given twice counts as not given", so it is not listed).
   function Tool_Name_Duplicated (Line : String) return Boolean is
     (Json_Scan_Pkg.Duplicated_Of (Line, Json_Scan_Pkg.Value_Span (Line, Params_Key), Name_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Tool_Name_Duplicated'Result = Json_Scan_Pkg.Duplicated_Of (Line, Json_Scan_Pkg.Value_Span (Line, Params_Key), Name_Key));

   function Arguments_Duplicated (Line : String) return Boolean is
     (Json_Scan_Pkg.Duplicated_Of (Line, Json_Scan_Pkg.Value_Span (Line, Params_Key), Arguments_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (Arguments_Duplicated'Result = Json_Scan_Pkg.Duplicated_Of (Line, Json_Scan_Pkg.Value_Span (Line, Params_Key), Arguments_Key));

   function Arg_Duplicated (Line : String; Key : String) return Boolean is
     (Json_Scan_Pkg.Duplicated_Of (Line, Json_Scan_Pkg.Member_Of (Line, Json_Scan_Pkg.Value_Span (Line, Params_Key), Arguments_Key), Key))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576 and then Key'First = 1
                  and then Key'Length >= 1 and then Key'Length <= 64,
          Post => (Arg_Duplicated'Result = Json_Scan_Pkg.Duplicated_Of (Line, Json_Scan_Pkg.Member_Of (Line, Json_Scan_Pkg.Value_Span (Line, Params_Key), Arguments_Key), Key));

   function Duplicate_Key (Line : String) return Boolean is
     (Tool_Name_Duplicated (Line) or else Arguments_Duplicated (Line)
      or else (case Tool_Of (Line) is
                 when T_Licence_Gate => Arg_Duplicated (Line, Requested_Key),
                 when T_Intake_Check | T_Forge => Arg_Duplicated (Line, Sheet_Key),
                 when T_Prove_Unit => Arg_Duplicated (Line, Unit_Key) or else Arg_Duplicated (Line, Spec_Key)
                                      or else Arg_Duplicated (Line, Body_Key) or else Arg_Duplicated (Line, Level_Key),
                 when T_Palais_Enrol => Arg_Duplicated (Line, Codename_Key),
                 when others => False))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => ((if Tool_Name_Duplicated (Line) or else Arguments_Duplicated (Line) then Duplicate_Key'Result)
                   and then (if Tool_Of (Line) = T_Licence_Gate then
                               Duplicate_Key'Result = (Tool_Name_Duplicated (Line) or else Arguments_Duplicated (Line)
                                                       or else Arg_Duplicated (Line, Requested_Key)))
                   and then (if Tool_Of (Line) = T_Rail_Set or else Tool_Of (Line) = T_Unknown then
                               Duplicate_Key'Result = (Tool_Name_Duplicated (Line) or else Arguments_Duplicated (Line))));

   --  Brackets_Unclosed: the line opens a JSON object or array whose closer is never reached --
   --  a mismatched bracket ({ closed by ] or [ by }), a bracket left open, a string left open, or
   --  nesting deeper than Json_Scan_Pkg.Max_Depth. The door names this class in its -32700 reply.
   function Brackets_Unclosed (Line : String) return Boolean is
     (Line'Length > 0 and then Json_Scan_Pkg.Skip_WS (Line, 1) /= 0
      and then (Line (Json_Scan_Pkg.Skip_WS (Line, 1)) = '{' or else Line (Json_Scan_Pkg.Skip_WS (Line, 1)) = '[')
      and then Json_Scan_Pkg.Comp_End (Line, Json_Scan_Pkg.Skip_WS (Line, 1)) = 0)
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (if Brackets_Unclosed'Result then Parse_Failed (Line));

   --  Unit_Name_Valid: params.arguments.unit is a string whose raw text is an Ada unit name the
   --  prover rail accepts (Rail_Request_Pkg.Is_Valid's rule): 1 to 64 characters, a letter first,
   --  then letters, digits and underscores only. No dot, slash, backslash or escape can pass.
   function Is_Unit_Name_Char (C : Character) return Boolean is
     ((C in 'A' .. 'Z') or else (C in 'a' .. 'z') or else (C in '0' .. '9') or else C = '_');

   function Unit_Name_Valid (Line : String) return Boolean is
     (Unit_Span (Line).found and then Unit_Span (Line).kind = Json_Scan_Pkg.K_String
      and then Unit_Span (Line).last - Unit_Span (Line).first - 1 in 1 .. 64
      and then (Line (Unit_Span (Line).first + 1) in 'A' .. 'Z' or else Line (Unit_Span (Line).first + 1) in 'a' .. 'z')
      and then (for all K in Unit_Span (Line).first + 1 .. Unit_Span (Line).last - 1 => Is_Unit_Name_Char (Line (K))))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => (if Unit_Name_Valid'Result then
                     Unit_Span (Line).found and then Unit_Span (Line).kind = Json_Scan_Pkg.K_String
                     and then (for all K in Unit_Span (Line).first + 1 .. Unit_Span (Line).last - 1 =>
                                 Line (K) /= '.' and then Line (K) /= '/' and then Line (K) /= '\' and then Line (K) /= '"'));

   function Facts_Of (Line : String) return Json_Rpc_Frame_Pkg.Facts_Type is
     ((parse_failed => Parse_Failed (Line), jsonrpc_is_2_0 => Jsonrpc_Is_2_0 (Line), has_id => Has_Id (Line), method => Method_Of (Line), has_params => Has_Params (Line)))
     with Pre  => Line'First = 1 and then Line'Length <= 1048576,
          Post => ((Facts_Of'Result.parse_failed = Parse_Failed (Line)) and then (Facts_Of'Result.jsonrpc_is_2_0 = Jsonrpc_Is_2_0 (Line)) and then (Facts_Of'Result.has_id = Has_Id (Line)) and then (Facts_Of'Result.method = Method_Of (Line)) and then (Facts_Of'Result.has_params = Has_Params (Line)));

end Frame_Facts_Pkg;
