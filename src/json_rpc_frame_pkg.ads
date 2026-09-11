--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged by ANVIL through the lane, ab-20260911-1953 round C, on Tony's command. Round A: a lost
--  parenthesis in a nested iff (helper Earns_Result added to the prose); round B: the prose ordered
--  the version test before the notification test, so a notification could carry an error code —
--  a real design fault, fixed in prose. Proved: zero unproved, zero justified, zero cheat markers.
--  Carried here unchanged — a header may be added, a contract may not drift.
--
package Json_Rpc_Frame_Pkg with SPARK_Mode is

   type Method_Type is (M_Initialize, M_Initialized, M_Tools_List, M_Tools_Call, M_Unknown);

   type Reply_Type is (Reply_Result, Reply_Error, Reply_None);

   type Action_Type is (Do_Nothing, Do_Initialize, Do_List_Tools, Do_Call_Tool);

   type Facts_Type is record
      parse_failed    : Boolean := True;
      jsonrpc_is_2_0  : Boolean := False;
      has_id          : Boolean := False;
      method          : Method_Type := M_Unknown;
      has_params      : Boolean := False;
   end record;

   type Verdict_Type is record
      facts       : Facts_Type;
      reply       : Reply_Type := Reply_None;
      error_code  : Integer := 0;
      action      : Action_Type := Do_Nothing;
   end record;

   function Is_Notification (facts : Facts_Type) return Boolean
     is (not facts.parse_failed and then not facts.has_id)
     with Post => ((Is_Notification'Result = True) = (facts.parse_failed = False and then facts.has_id = False));

   function Method_Is_Known (facts : Facts_Type) return Boolean
     is (facts.method /= M_Unknown)
     with Post => ((Method_Is_Known'Result = True) = (facts.method /= M_Unknown));

   function Error_Code (facts : Facts_Type) return Integer
     is ((if facts.parse_failed then -32700
          elsif Is_Notification (facts) then 0
          elsif not facts.jsonrpc_is_2_0 then -32600
          elsif not Method_Is_Known (facts) then -32601
          elsif facts.method = M_Tools_Call and then not facts.has_params then -32602
          else 0))
     with Post => ((if facts.parse_failed then Error_Code'Result = -32700)
                   and then (if Is_Notification (facts) then Error_Code'Result = 0)
                   and then (if not facts.parse_failed and then not Is_Notification (facts) and then not facts.jsonrpc_is_2_0 then Error_Code'Result = -32600)
                   and then ((Error_Code'Result = 0) or else (Error_Code'Result = -32700) or else (Error_Code'Result = -32600) or else (Error_Code'Result = -32601) or else (Error_Code'Result = -32602)));

   function Earns_Result (facts : Facts_Type) return Boolean
     is (not facts.parse_failed and then not Is_Notification (facts) and then Error_Code (facts) = 0)
     with Post => ((Earns_Result'Result = True) = (facts.parse_failed = False and then Is_Notification (facts) = False and then Error_Code (facts) = 0));

   function Reply_Kind (facts : Facts_Type) return Reply_Type
     is ((if facts.parse_failed then Reply_Error
          elsif Is_Notification (facts) then Reply_None
          elsif Error_Code (facts) /= 0 then Reply_Error
          else Reply_Result))
     with Post => ((if Is_Notification (facts) then Reply_Kind'Result = Reply_None)
                   and then (if facts.parse_failed then Reply_Kind'Result = Reply_Error)
                   and then ((Reply_Kind'Result = Reply_Result) = Earns_Result (facts))
                   and then (if Reply_Kind'Result = Reply_Result then Method_Is_Known (facts)));

   function Action_For (facts : Facts_Type) return Action_Type
     is ((if Reply_Kind (facts) /= Reply_Result then Do_Nothing
          elsif facts.method = M_Initialize then Do_Initialize
          elsif facts.method = M_Tools_List then Do_List_Tools
          elsif facts.method = M_Tools_Call then Do_Call_Tool
          else Do_Nothing))
     with Post => ((if Reply_Kind (facts) /= Reply_Result then Action_For'Result = Do_Nothing)
                   and then (if Action_For'Result = Do_Call_Tool then facts.method = M_Tools_Call and then facts.has_params)
                   and then (if Action_For'Result = Do_Initialize then facts.method = M_Initialize));

   function Assemble (facts : Facts_Type) return Verdict_Type
     is ((facts => facts, reply => Reply_Kind (facts), error_code => Error_Code (facts), action => Action_For (facts)))
     with Post => ((Assemble'Result.facts = facts)
                   and then (Assemble'Result.reply = Reply_Kind (facts))
                   and then (Assemble'Result.error_code = Error_Code (facts))
                   and then (Assemble'Result.action = Action_For (facts))
                   and then ((Assemble'Result.error_code = 0) = (Assemble'Result.reply /= Reply_Error)));

   function Must_Answer (v : Verdict_Type) return Boolean
     is (v.reply /= Reply_None)
     with Post => ((Must_Answer'Result = True) = (v.reply /= Reply_None));

end Json_Rpc_Frame_Pkg;
