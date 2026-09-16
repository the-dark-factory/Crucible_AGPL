--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Crucible_Main v4 -- the door's edge: a read loop, one declare block, one call into the frame
--  decider, one case over the action calling the proved cores. It holds no decision.
--  v4 withdraws self_judge: no Self_Facts, no Sole_Interface_Pkg, one tool-call branch; a caller
--  naming self_judge reaches the unknown-tool branch and is refused (-32602).
--  Body: ANVIL lane, wu-crucible-main-4 round B, 2026-09-16, planner Rosie qwen3.8-27b-ada:v0.3,
--  gate built-not-proved (an edge is compiled, never proved). Measured on the built binary:
--  tools/list = [licence_gate]; self_judge -> -32602; licence_gate agpl/mit/proprietary unchanged.
--
with Ada.Text_IO;
with Json_Scan_Pkg;
with Frame_Facts_Pkg;
with Json_Rpc_Frame_Pkg;
with Edition_Licence_Pkg;
with Crucible_Edition;
with Tool_Run_Pkg;
with Reply_Text_Pkg;

procedure Crucible_Main is
   Null_Id       : constant String := "null";
   Server_Agpl   : constant String := "crucible-agpl";
   Server_Comm   : constant String := "crucible-commercial";
   Bad_Tool_Msg  : constant String := "unknown tool";
   Frame_Msg     : constant String := "request refused by the frame decider";
   Server_Name   : constant String :=
     (if Crucible_Edition.Is_Agpl then Server_Agpl else Server_Comm);
   Buffer        : String (1 .. 65536);
   Last          : Natural;

   use type Json_Rpc_Frame_Pkg.Reply_Type;
   use type Json_Rpc_Frame_Pkg.Action_Type;
   use type Frame_Facts_Pkg.Tool_Type;
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
