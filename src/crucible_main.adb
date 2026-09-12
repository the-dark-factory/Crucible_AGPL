--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Crucible_Main -- the door's edge: a read loop, one declare block, one call into the frame
--  decider, one case over the action calling the three proved cores, two prints. It holds no
--  decision (BRIEF_crucible_door_split_2026-09-11 §4, unit 4 of the door split).
--  Body: ANVIL lane, wu-crucible-main-3 round C, 2026-09-12 11:43, planner Rosie
--  qwen3.8-27b-ada:v0.3, gate built-not-proved (an edge is compiled, never proved), 0 compile
--  errors; the LANE'S OWN PROBE (probe.bb, unchanged since 2026-09-11): exit=0, replies=2,
--  serverInfo.name="crucible-agpl", tools=2 -- PASS. Round A (11:06) was the first edge ever
--  built and probed in-lane; round C is round A plus one change: the two tool replies are
--  wrapped in Reply_Text_Pkg.Tool_Call_Result so a tools/call result carries content +
--  structuredContent (round B was identical but sat beside a malformed v2 core -- the probe
--  caught it). Replaces the hand-driven edge of 2026-09-11 (eleven rounds, never converged).
--  Edition compiled in via Crucible_Edition; no Ada.Command_Line, no Ada.Environment_Variables,
--  no sockets. Self_Facts are the binary's SELF-ASSERTED facts for self_judge (door brief:
--  `facts_are_self_asserted` owed to a later Reply_Text round). Comment-stripped sha equals the
--  lane-built round-C body.
with Ada.Text_IO;
with Json_Scan_Pkg;
with Frame_Facts_Pkg;
with Json_Rpc_Frame_Pkg;
with Sole_Interface_Pkg;
with Edition_Licence_Pkg;
with Crucible_Edition;
with Tool_Run_Pkg;
with Reply_Text_Pkg;

procedure Crucible_Main is
   use type Json_Rpc_Frame_Pkg.Reply_Type;
   use type Json_Rpc_Frame_Pkg.Action_Type;
   use type Frame_Facts_Pkg.Tool_Type;

   Null_Id       : constant String := "null";
   Server_Agpl   : constant String := "crucible-agpl";
   Server_Comm   : constant String := "crucible-commercial";
   Bad_Tool_Msg  : constant String := "unknown tool";
   Frame_Msg     : constant String := "request refused by the frame decider";
   Server_Name   : constant String :=
     (if Crucible_Edition.Is_Agpl then Server_Agpl else Server_Comm);
   Self_Facts    : constant Sole_Interface_Pkg.Facts_Type :=
     (entry_points_enumerated => True, mcp_endpoint_present => True,
      prose_door_retired => True, non_mcp_entry_points => 0,
      tools_declared => 2, tools_with_schema => 2, unauthenticated_entries => 0);
   Buffer        : String (1 .. 65536);
   Last          : Natural;
begin
   while not Ada.Text_IO.End_Of_File loop
      Ada.Text_IO.Get_Line (Buffer, Last);
      declare
         Line  : constant String := Buffer (1 .. Last);
         Facts : constant Json_Rpc_Frame_Pkg.Facts_Type := Frame_Facts_Pkg.Facts_Of (Line);
         V     : constant Json_Rpc_Frame_Pkg.Verdict_Type := Json_Rpc_Frame_Pkg.Assemble (Facts);
         Span  : constant Json_Scan_Pkg.Span_Type := Frame_Facts_Pkg.Id_Span (Line);
         Id    : constant String (1 .. (if Span.found then Span.last - Span.first + 1 else Null_Id'Length)) :=
           (if Span.found then Line (Span.first .. Span.last) else Null_Id);
      begin
         if V.reply = Json_Rpc_Frame_Pkg.Reply_Error then
            Ada.Text_IO.Put_Line (Reply_Text_Pkg.Error_Reply (Id, V.error_code, Frame_Msg));
         elsif V.reply = Json_Rpc_Frame_Pkg.Reply_Result then
            case V.action is
               when Json_Rpc_Frame_Pkg.Do_Initialize =>
                  Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Initialize_Result (Server_Name)));
               when Json_Rpc_Frame_Pkg.Do_List_Tools =>
                  Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tools_List_Result));
               when Json_Rpc_Frame_Pkg.Do_Call_Tool =>
                  if Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Licence_Gate then
                     Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Tool_Run_Pkg.Licence_Gate (Crucible_Edition.Current, Line))));
                  elsif Frame_Facts_Pkg.Tool_Of (Line) = Frame_Facts_Pkg.T_Self_Judge then
                     Ada.Text_IO.Put_Line (Reply_Text_Pkg.Result_Reply (Id, Reply_Text_Pkg.Tool_Call_Result (Tool_Run_Pkg.Self_Judge (Self_Facts))));
                  else
                     Ada.Text_IO.Put_Line (Reply_Text_Pkg.Error_Reply (Id, -32602, Bad_Tool_Msg));
                  end if;
               when Json_Rpc_Frame_Pkg.Do_Nothing =>
                  null;
            end case;
         end if;
         Ada.Text_IO.Flush;
      end;
   end loop;
end Crucible_Main;
