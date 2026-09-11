--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged by ANVIL, wu-run.sh EDGE mode, round I, 2026-09-11 20:4x, planner Rosie v0.3, on Tony's command.
--  The lane refused the edge directory (material decider: ambiguous — repair proposed, parlour case
--  9c598bc9), so the driver was run by the seat; rounds A-H were prose fixes (quotes, declare blocks,
--  use type, unconstrained String, procedures vs functions, if-expressions). Compile-gated, NOT proved:
--  an edge carries no proof; every decision it reports is a proven package's. Carried unchanged.
--
--  This unit is the irreducible input and output boundary of CRUCIBLE: line
--  reading, the scan for known keys, the assembly of literal reply text and
--  the flush are the remainder that cannot be forged into the proof, and
--  every decision it reports is a proven package's. The edition is compiled
--  in through Crucible_Edition and the door is standard input alone.

with Ada.Text_IO;
with Ada.Strings;
with Ada.Strings.Fixed;
with Json_Scan_Pkg;
with Json_Rpc_Frame_Pkg;
with Tool_Dispatch_Pkg;
with Edition_Licence_Pkg;
with Crucible_Edition;
with Sole_Interface_Pkg;

use type Json_Scan_Pkg.Kind_Type;
use type Json_Rpc_Frame_Pkg.Method_Type;
use type Json_Rpc_Frame_Pkg.Reply_Type;
use type Json_Rpc_Frame_Pkg.Action_Type;
use type Tool_Dispatch_Pkg.Tool_Type;
use type Edition_Licence_Pkg.Edition_Type;
use type Edition_Licence_Pkg.Requested_Licence_Type;
use type Edition_Licence_Pkg.Reason_Type;

procedure Crucible_Main with SPARK_Mode => Off is

   Quote     : constant Character := '"';
   Backslash : constant Character := '\';

   Protocol_Version : constant String := "2025-06-18";
   Server_Version   : constant String := "0.1.0-dev";
   Max_Line         : constant := 65536;

   function Q (S : String) return String is (Quote & S & Quote);

   function Server_Name return String is
      (if Crucible_Edition.Current = Edition_Licence_Pkg.Agpl
          then "crucible-agpl"
          else "crucible-commercial");

   function Image_Of (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Both));

   function Json_Bool (B : Boolean) return String is
      (if B then "true" else "false");

   function Escape_Quotes (S : String) return String is
   begin
      declare
         Result : String (1 .. S'Length * 2);
         Index  : Natural := 0;
      begin
         for I in S'Range loop
            if S (I) = Quote then
               Index := Index + 1;
               Result (Index) := Backslash;
               Index := Index + 1;
               Result (Index) := Quote;
            else
               Index := Index + 1;
               Result (Index) := S (I);
            end if;
         end loop;
         return Result (1 .. Index);
      end;
   end Escape_Quotes;

   function Error_Message_For (Code : Integer) return String is
      (case Code is
          when -32700 => "parse error",
          when -32600 => "invalid request",
          when -32601 => "method not found",
          when -32602 => "invalid params",
          when others => "internal error");

   function Parse_Failed (Line : String) return Boolean is
      (Json_Scan_Pkg.Key_Position (Line, "jsonrpc") = 0
       and then Json_Scan_Pkg.Key_Position (Line, "method") = 0);

   function Jsonrpc_Is_2_0 (Line : String) return Boolean is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "jsonrpc");
   begin
      return S.found
        and then S.kind = Json_Scan_Pkg.K_String
        and then Json_Scan_Pkg.Equals_Literal (Line, Json_Scan_Pkg.String_Contents (Line, S), "2.0");
   end Jsonrpc_Is_2_0;

   function Has_Id (Line : String) return Boolean is
      (Json_Scan_Pkg.Value_Span (Line, "id").found);

   function Method_Of (Line : String) return Json_Rpc_Frame_Pkg.Method_Type is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "method");
   begin
      if not S.found or else S.kind /= Json_Scan_Pkg.K_String then
         return Json_Rpc_Frame_Pkg.M_Unknown;
      end if;
      declare
         C : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, S);
      begin
         if Json_Scan_Pkg.Equals_Literal (Line, C, "initialize") then
            return Json_Rpc_Frame_Pkg.M_Initialize;
         elsif Json_Scan_Pkg.Equals_Literal (Line, C, "notifications/initialized") then
            return Json_Rpc_Frame_Pkg.M_Initialized;
         elsif Json_Scan_Pkg.Equals_Literal (Line, C, "tools/list") then
            return Json_Rpc_Frame_Pkg.M_Tools_List;
         elsif Json_Scan_Pkg.Equals_Literal (Line, C, "tools/call") then
            return Json_Rpc_Frame_Pkg.M_Tools_Call;
         else
            return Json_Rpc_Frame_Pkg.M_Unknown;
         end if;
      end;
   end Method_Of;

   function Has_Params (Line : String) return Boolean is
      (Json_Scan_Pkg.Value_Span (Line, "params").found);

   function Id_Text (Line : String) return String is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "id");
   begin
      if S.found and then (S.kind = Json_Scan_Pkg.K_String or else S.kind = Json_Scan_Pkg.K_Bare) then
         return Line (S.first .. S.last);
      else
         return "null";
      end if;
   end Id_Text;

   function Tool_Of (Line : String) return Tool_Dispatch_Pkg.Tool_Type is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "name");
   begin
      if not S.found or else S.kind /= Json_Scan_Pkg.K_String then
         return Tool_Dispatch_Pkg.T_Unknown;
      end if;
      declare
         C : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, S);
      begin
         if Json_Scan_Pkg.Equals_Literal (Line, C, "licence_gate") then
            return Tool_Dispatch_Pkg.T_Licence_Gate;
         elsif Json_Scan_Pkg.Equals_Literal (Line, C, "self_judge") then
            return Tool_Dispatch_Pkg.T_Self_Judge;
         else
            return Tool_Dispatch_Pkg.T_Unknown;
         end if;
      end;
   end Tool_Of;

   function Requested_Present (Line : String) return Boolean is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "requested");
   begin
      return S.found and then S.kind = Json_Scan_Pkg.K_String;
   end Requested_Present;

   function Judge_Present (Line : String) return Boolean is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "judge");
   begin
      return S.found and then S.kind = Json_Scan_Pkg.K_String;
   end Judge_Present;

   function Requested_Contents (Line : String) return String is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "requested");
   begin
      if not S.found or else S.kind /= Json_Scan_Pkg.K_String then
         return "";
      end if;
      declare
         C : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, S);
      begin
         return Line (C.first .. C.last);
      end;
   end Requested_Contents;

   function Judge_Contents (Line : String) return String is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "judge");
   begin
      if not S.found or else S.kind /= Json_Scan_Pkg.K_String then
         return "";
      end if;
      declare
         C : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, S);
      begin
         return Line (C.first .. C.last);
      end;
   end Judge_Contents;

   function Requested_Decoded (Line : String) return Edition_Licence_Pkg.Requested_Licence_Type is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "requested");
   begin
      if not S.found or else S.kind /= Json_Scan_Pkg.K_String then
         return Edition_Licence_Pkg.Other_Licence;
      end if;
      declare
         C : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, S);
      begin
         if Json_Scan_Pkg.Equals_Literal (Line, C, "agpl") then
            return Edition_Licence_Pkg.Agpl_Licence;
         elsif Json_Scan_Pkg.Equals_Literal (Line, C, "mit") then
            return Edition_Licence_Pkg.Mit_Licence;
         elsif Json_Scan_Pkg.Equals_Literal (Line, C, "proprietary") then
            return Edition_Licence_Pkg.Proprietary_Licence;
         else
            return Edition_Licence_Pkg.Other_Licence;
         end if;
      end;
   end Requested_Decoded;

   function Judge_Is_Sole_Interface (Line : String) return Boolean is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, "judge");
   begin
      if not S.found or else S.kind /= Json_Scan_Pkg.K_String then
         return False;
      end if;
      declare
         C : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, S);
      begin
         return Json_Scan_Pkg.Equals_Literal (Line, C, "sole_interface");
      end;
   end Judge_Is_Sole_Interface;

   function Initialize_Result return String is
      Name : constant String := Server_Name;
   begin
      return "{"
        & Q ("protocolVersion") & ":" & Q (Protocol_Version)
        & "," & Q ("capabilities") & ":{" & Q ("tools") & ":{}}"
        & "," & Q ("serverInfo") & ":{"
        & Q ("name") & ":" & Q (Name)
        & "," & Q ("version") & ":" & Q (Server_Version)
        & "}}";
   end Initialize_Result;

   Tools_List_Json : constant String :=
     "{"
       & Q ("tools") & ":["
       & "{"
         & Q ("name") & ":" & Q ("licence_gate")
         & "," & Q ("description") & ":" & Q ("May this edition emit under the requested licence. The AGPL edition permits agpl only.")
         & "," & Q ("inputSchema") & ":{"
           & Q ("type") & ":" & Q ("object")
           & "," & Q ("properties") & ":{"
             & Q ("requested") & ":{"
               & Q ("type") & ":" & Q ("string")
               & "," & Q ("enum") & ":[" & Q ("agpl") & "," & Q ("mit") & "," & Q ("proprietary") & "," & Q ("other") & "]"
             & "}"
           & "},"
           & Q ("required") & ":[" & Q ("requested") & "]"
         & "}"
       & "},"
       & "{"
         & Q ("name") & ":" & Q ("self_judge")
         & "," & Q ("description") & ":" & Q ("Run one of CRUCIBLE's proven judges over facts the binary asserts about itself.")
         & "," & Q ("inputSchema") & ":{"
           & Q ("type") & ":" & Q ("object")
           & "," & Q ("properties") & ":{"
             & Q ("judge") & ":{"
               & Q ("type") & ":" & Q ("string")
               & "," & Q ("enum") & ":[" & Q ("sole_interface") & "]"
             & "}"
           & "},"
           & Q ("required") & ":[" & Q ("judge") & "]"
         & "}"
       & "}"
     & "]}}";

   procedure Print_Error (Id : String; Code : Integer; Message : String) is
      Body_Text : constant String :=
        "{"
          & Q ("jsonrpc") & ":" & Q ("2.0")
          & "," & Q ("id") & ":" & Id
          & "," & Q ("error") & ":{"
            & Q ("code") & ":" & Image_Of (Code)
            & "," & Q ("message") & ":" & Q (Message)
          & "}}";
   begin
      Ada.Text_IO.Put_Line (Body_Text);
      Ada.Text_IO.Flush;
   end Print_Error;

   procedure Print_Result (Id : String; Result : String) is
      Body_Text : constant String :=
        "{"
          & Q ("jsonrpc") & ":" & Q ("2.0")
          & "," & Q ("id") & ":" & Id
          & "," & Q ("result") & ":" & Result
          & "}";
   begin
      Ada.Text_IO.Put_Line (Body_Text);
      Ada.Text_IO.Flush;
   end Print_Result;

begin
   while not Ada.Text_IO.End_Of_File loop
      declare
         Buffer : String (1 .. Max_Line);
         Len    : Natural;
      begin
         Ada.Text_IO.Get_Line (Buffer, Len);
         if Len = Max_Line then
            Ada.Text_IO.Skip_Line;
            Print_Error ("null", -32700, "parse error");
         else
            declare
               Line  : constant String := Buffer (1 .. Len);
               Facts : constant Json_Rpc_Frame_Pkg.Facts_Type :=
                 (parse_failed   => Parse_Failed (Line),
                  jsonrpc_is_2_0 => Jsonrpc_Is_2_0 (Line),
                  has_id         => Has_Id (Line),
                  method         => Method_Of (Line),
                  has_params     => Has_Params (Line));
               V     : constant Json_Rpc_Frame_Pkg.Verdict_Type :=
                 Json_Rpc_Frame_Pkg.Assemble (Facts);
               Id    : constant String := Id_Text (Line);
            begin
               if Json_Rpc_Frame_Pkg.Must_Answer (V) then
                  if V.reply = Json_Rpc_Frame_Pkg.Reply_Error then
                     Print_Error (Id, V.error_code, Error_Message_For (V.error_code));
                  elsif V.reply = Json_Rpc_Frame_Pkg.Reply_Result then
                     if V.action = Json_Rpc_Frame_Pkg.Do_Initialize then
                        Print_Result (Id, Initialize_Result);
                     elsif V.action = Json_Rpc_Frame_Pkg.Do_List_Tools then
                        Print_Result (Id, Tools_List_Json);
                     elsif V.action = Json_Rpc_Frame_Pkg.Do_Call_Tool then
                        declare
                           Tool_Facts : constant Tool_Dispatch_Pkg.Facts_Type :=
                             (tool            => Tool_Of (Line),
                              requested_present => Requested_Present (Line),
                              judge_present   => Judge_Present (Line));
                           T : constant Tool_Dispatch_Pkg.Verdict_Type :=
                             Tool_Dispatch_Pkg.Assemble (Tool_Facts);
                        begin
                           if T.fault_unknown_tool then
                              Print_Error (Id, -32602, "unknown tool");
                           elsif T.fault_missing_argument then
                              declare
                                 Missing_Arg_Result : constant String :=
                                   "{"
                                     & Q ("content") & ":["
                                       & "{"
                                         & Q ("type") & ":" & Q ("text")
                                         & "," & Q ("text") & ":" & Q ("missing argument")
                                       & "}"
                                     & "]"
                                     & "," & Q ("isError") & ":" & Json_Bool (True)
                                     & "," & Q ("structuredContent") & ":{"
                                       & Q ("refused") & ":" & Json_Bool (True)
                                       & "," & Q ("reason") & ":" & Q ("missing_argument")
                                     & "}}";
                              begin
                                 Print_Result (Id, Missing_Arg_Result);
                              end;
                           else
                              if T.facts.tool = Tool_Dispatch_Pkg.T_Licence_Gate then
                                 declare
                                    Req : constant Edition_Licence_Pkg.Requested_Licence_Type :=
                                      Requested_Decoded (Line);
                                    D   : constant Edition_Licence_Pkg.Verdict_Type :=
                                      Edition_Licence_Pkg.Decide (Crucible_Edition.Current, Req);
                                    Edition_Word : constant String :=
                                      (if D.edition = Edition_Licence_Pkg.Agpl
                                          then "agpl" else "commercial");
                                    Requested_Word : constant String :=
                                      Requested_Contents (Line);
                                    Reason_Word : constant String :=
                                      (if D.reason = Edition_Licence_Pkg.Permitted
                                          then "permitted"
                                          else "edition_is_agpl_only");
                                    Text : constant String :=
                                      "{"
                                        & Q ("edition") & ":" & Q (Edition_Word)
                                        & "," & Q ("requested") & ":" & Q (Requested_Word)
                                        & "," & Q ("refused") & ":" & Json_Bool (D.refused)
                                        & "," & Q ("reason") & ":" & Q (Reason_Word)
                                        & "}";
                                    Escaped : constant String := Escape_Quotes (Text);
                                    Licence_Result : constant String :=
                                      "{"
                                        & Q ("content") & ":["
                                          & "{"
                                            & Q ("type") & ":" & Q ("text")
                                            & "," & Q ("text") & ":" & Q (Escaped)
                                          & "}"
                                        & "]"
                                        & "," & Q ("isError") & ":" & Json_Bool (False)
                                        & "," & Q ("structuredContent") & ":" & Text
                                        & "}";
                                 begin
                                    Print_Result (Id, Licence_Result);
                                 end;
                              elsif T.facts.tool = Tool_Dispatch_Pkg.T_Self_Judge then
                                 if Judge_Is_Sole_Interface (Line) then
                                    declare
                                       SI_Facts : constant Sole_Interface_Pkg.Facts_Type :=
                                         (entry_points_enumerated => True,
                                          mcp_endpoint_present   => True,
                                          prose_door_retired     => True,
                                          non_mcp_entry_points   => 0,
                                          tools_declared         => Tool_Dispatch_Pkg.Tools_Declared,
                                          tools_with_schema      => Tool_Dispatch_Pkg.Tools_With_Schema,
                                          unauthenticated_entries => 0);
                                       S : constant Sole_Interface_Pkg.Verdict_Type :=
                                         Sole_Interface_Pkg.Assemble (SI_Facts);
                                       Text : constant String :=
                                         "{"
                                           & Q ("judge") & ":" & Q ("sole_interface")
                                           & "," & Q ("facts_are_self_asserted") & ":true"
                                           & "," & Q ("interface_is_sole") & ":" & Json_Bool (S.interface_is_sole)
                                           & "," & Q ("fault_count") & ":" & Image_Of (S.fault_count)
                                           & "," & Q ("fault_not_enumerated") & ":" & Json_Bool (S.fault_not_enumerated)
                                           & "," & Q ("fault_no_mcp_endpoint") & ":" & Json_Bool (S.fault_no_mcp_endpoint)
                                           & "," & Q ("fault_another_door_open") & ":" & Json_Bool (S.fault_another_door_open)
                                           & "," & Q ("fault_tool_without_schema") & ":" & Json_Bool (S.fault_tool_without_schema)
                                           & "," & Q ("fault_unauthenticated_entry") & ":" & Json_Bool (S.fault_unauthenticated_entry)
                                           & "}";
                                       Escaped : constant String := Escape_Quotes (Text);
                                       Judge_Result : constant String :=
                                         "{"
                                           & Q ("content") & ":["
                                             & "{"
                                               & Q ("type") & ":" & Q ("text")
                                               & "," & Q ("text") & ":" & Q (Escaped)
                                             & "}"
                                           & "]"
                                           & "," & Q ("isError") & ":" & Json_Bool (False)
                                           & "," & Q ("structuredContent") & ":" & Text
                                           & "}";
                                    begin
                                       Print_Result (Id, Judge_Result);
                                    end;
                                 else
                                    declare
                                       Unknown_Judge_Result : constant String :=
                                         "{"
                                           & Q ("content") & ":["
                                             & "{"
                                               & Q ("type") & ":" & Q ("text")
                                               & "," & Q ("text") & ":" & Q ("unknown judge")
                                             & "}"
                                           & "]"
                                           & "," & Q ("isError") & ":" & Json_Bool (True)
                                           & "," & Q ("structuredContent") & ":{"
                                             & Q ("refused") & ":" & Json_Bool (True)
                                             & "," & Q ("reason") & ":" & Q ("unknown_judge")
                                           & "}}";
                                    begin
                                       Print_Result (Id, Unknown_Judge_Result);
                                    end;
                                 end if;
                              end if;
                           end if;
                        end;
                     elsif V.action = Json_Rpc_Frame_Pkg.Do_Nothing then
                        Print_Error (Id, -32603, "internal error");
                     end if;
                  end if;
               end if;
            end;
         end if;
      exception
         when others =>
            Print_Error ("null", -32603, "internal error");
      end;
   end loop;
end Crucible_Main;
