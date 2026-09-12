--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Frame_Facts_Pkg -- the measurement between the scanner and the frame decider: from one
--  JSON-RPC line, the facts Json_Rpc_Frame_Pkg rules on, each defined as Json_Scan_Pkg's own
--  answer (BRIEF_crucible_door_split_2026-09-11 §2, unit 2 of the door split).
--  Spec: ANVIL lane, wu-crucible-frame-facts round E, 2026-09-12 10:39, planner Rosie
--  qwen3.8-27b-ada:v0.3, proof_gate accepted: 75 checks proved, 0 unproved, 0 compile errors,
--  0 cheat markers; bench: spec-only discharge (all expression functions, no body). THE FIRST
--  UNIT FORGED THROUGH THE LANE OVER CARRIED DEPENDENCIES (json_scan_pkg.ads + .adb,
--  json_rpc_frame_pkg.ads declared in carried.tsv by digest; wu-carried shape ruled by the
--  five-scalar Lane_Material_Pkg forged the same morning). Rounds A-D parked by the lane and
--  advised (cases 8ef8c5dc, 17173de3, db4adad5, a7eabec4): A 23 unproved; B/C the seat's
--  Hide_Info detour (C was a hollow green -- 0 checks for the unit -- caught, not carried);
--  D budget ruled out at 60 s; E the IR-55 cope -- every key and literal ONE named constant,
--  because repeated string literals are distinct objects to the prover and break call
--  congruence. Comment-stripped sha of this spec equals the forged round-E spec.
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

   type Tool_Type is (T_Licence_Gate, T_Self_Judge, T_Unknown);

   function Parse_Failed (Line : String) return Boolean is
     (not (Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).found and then Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).kind = Json_Scan_Pkg.K_String))
     with Pre  => Line'First = 1 and then Line'Length <= 65536,
          Post => (Parse_Failed'Result = not (Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).found and then Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).kind = Json_Scan_Pkg.K_String));

   function Jsonrpc_Is_2_0 (Line : String) return Boolean is
     ((Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).found and then Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).kind = Json_Scan_Pkg.K_String) and then Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key)), Version_Lit))
     with Pre  => Line'First = 1 and then Line'Length <= 65536,
          Post => ((if Jsonrpc_Is_2_0'Result then not Parse_Failed (Line)) and then (if Jsonrpc_Is_2_0'Result then Json_Scan_Pkg.Value_Span (Line, Jsonrpc_Key).found));

   function Has_Id (Line : String) return Boolean is
     (Json_Scan_Pkg.Value_Span (Line, Id_Key).found)
     with Pre  => Line'First = 1 and then Line'Length <= 65536,
          Post => (Has_Id'Result = Json_Scan_Pkg.Value_Span (Line, Id_Key).found);

   function Id_Span (Line : String) return Json_Scan_Pkg.Span_Type is
     (Json_Scan_Pkg.Value_Span (Line, Id_Key))
     with Pre  => Line'First = 1 and then Line'Length <= 65536,
          Post => (Id_Span'Result.found = Has_Id (Line));

   function Has_Params (Line : String) return Boolean is
     (Json_Scan_Pkg.Value_Span (Line, Params_Key).found)
     with Pre  => Line'First = 1 and then Line'Length <= 65536,
          Post => (Has_Params'Result = Json_Scan_Pkg.Value_Span (Line, Params_Key).found);

   function Method_Of (Line : String) return Json_Rpc_Frame_Pkg.Method_Type is
     (if not (Json_Scan_Pkg.Value_Span (Line, Method_Key).found and then Json_Scan_Pkg.Value_Span (Line, Method_Key).kind = Json_Scan_Pkg.K_String) then Json_Rpc_Frame_Pkg.M_Unknown elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Method_Key)), Initialize_Lit) then Json_Rpc_Frame_Pkg.M_Initialize elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Method_Key)), Initialized_Lit) then Json_Rpc_Frame_Pkg.M_Initialized elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Method_Key)), Tools_List_Lit) then Json_Rpc_Frame_Pkg.M_Tools_List elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Method_Key)), Tools_Call_Lit) then Json_Rpc_Frame_Pkg.M_Tools_Call else Json_Rpc_Frame_Pkg.M_Unknown)
     with Pre  => Line'First = 1 and then Line'Length <= 65536,
          Post => ((if not Json_Scan_Pkg.Value_Span (Line, Method_Key).found then Method_Of'Result = Json_Rpc_Frame_Pkg.M_Unknown));

   function Tool_Of (Line : String) return Tool_Type is
     (if not (Json_Scan_Pkg.Value_Span (Line, Name_Key).found and then Json_Scan_Pkg.Value_Span (Line, Name_Key).kind = Json_Scan_Pkg.K_String) then T_Unknown elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Licence_Gate_Lit) then T_Licence_Gate elsif Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, Json_Scan_Pkg.Value_Span (Line, Name_Key)), Self_Judge_Lit) then T_Self_Judge else T_Unknown)
     with Pre  => Line'First = 1 and then Line'Length <= 65536,
          Post => ((if not Json_Scan_Pkg.Value_Span (Line, Name_Key).found then Tool_Of'Result = T_Unknown));

   function Requested_Present (Line : String) return Boolean is
     (Json_Scan_Pkg.Value_Span (Line, Requested_Key).found)
     with Pre  => Line'First = 1 and then Line'Length <= 65536,
          Post => (Requested_Present'Result = Json_Scan_Pkg.Value_Span (Line, Requested_Key).found);

   function Judge_Present (Line : String) return Boolean is
     (Json_Scan_Pkg.Value_Span (Line, Judge_Key).found)
     with Pre  => Line'First = 1 and then Line'Length <= 65536,
          Post => (Judge_Present'Result = Json_Scan_Pkg.Value_Span (Line, Judge_Key).found);

   function Facts_Of (Line : String) return Json_Rpc_Frame_Pkg.Facts_Type is
     ((parse_failed => Parse_Failed (Line), jsonrpc_is_2_0 => Jsonrpc_Is_2_0 (Line), has_id => Has_Id (Line), method => Method_Of (Line), has_params => Has_Params (Line)))
     with Pre  => Line'First = 1 and then Line'Length <= 65536,
          Post => ((Facts_Of'Result.parse_failed = Parse_Failed (Line)) and then (Facts_Of'Result.jsonrpc_is_2_0 = Jsonrpc_Is_2_0 (Line)) and then (Facts_Of'Result.has_id = Has_Id (Line)) and then (Facts_Of'Result.method = Method_Of (Line)) and then (Facts_Of'Result.has_params = Has_Params (Line)));

end Frame_Facts_Pkg;
