--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: e93a7210c5d81025a80ec48730bd7013ae5fca217a12cf4ddec1070ba0049c01
--
with Ada.Text_IO;
with Ada.Streams;
with GNAT.Sockets;
with Reply_Text_Pkg;
with Json_String_Pkg;
with Model_Request_Pkg;
with Model_Reply_Pkg;
procedure Model_Caller_Main is
   use type Ada.Streams.Stream_Element_Offset;
   Request_Line    : constant String := "POST /api/chat HTTP/1.0";
   Host_Header     : constant String := "Host: ";
   Type_Header     : constant String := "Content-Type: application/json";
   Length_Header   : constant String := "Content-Length: ";
   Close_Header    : constant String := "Connection: close";
   CRLF            : constant String := ASCII.CR & ASCII.LF;
   Quote           : constant String := (1 => '"');
   Content_Open    : constant String := "{" & Reply_Text_Pkg.Q (Model_Reply_Pkg.Content_Key) & ":" & Quote;
   Content_Close   : constant String := Quote & "}";
   Over_Bound_Word : constant String := "prompt_over_bound";
   Not_Utf8_Word   : constant String := "prompt_not_utf8";
   Prompt_Bound    : constant := Model_Request_Pkg.Max_Prompt;
   Encoded_Bound   : constant := 2 * Model_Request_Pkg.Max_Prompt;
   Max_Reply       : constant := Model_Request_Pkg.Max_Reply;
   Max_Tokens      : constant := 8192;
   Num_Ctx         : constant := 32768;
   Timeout_Seconds : constant Duration := 600.0;
   H_Buf : String (1 .. 4096);
   P_Buf : String (1 .. 4096);
   M_Buf : String (1 .. 4096);
   R_Buf : String (1 .. Prompt_Bound + 1);
   H_Last : Natural;
   P_Last : Natural;
   M_Last : Natural;
   R_Last : Natural;
   Reached     : Boolean := False;
   Timed_Out   : Boolean := False;
   Body_Length : Natural := 0;
   Body_Start  : Natural := 0;
begin
   Ada.Text_IO.Get_Line (H_Buf, H_Last);
   Ada.Text_IO.Get_Line (P_Buf, P_Last);
   Ada.Text_IO.Get_Line (M_Buf, M_Last);
   Ada.Text_IO.Get_Line (R_Buf, R_Last);
   if R_Last > Prompt_Bound then
      Ada.Text_IO.Put_Line (Over_Bound_Word);
      Ada.Text_IO.Flush;
      return;
   end if;
   declare
      Host      : constant String := H_Buf (1 .. H_Last);
      Port_Text : constant String := P_Buf (1 .. P_Last);
      Model     : constant String := M_Buf (1 .. M_Last);
      Prompt    : constant String := R_Buf (1 .. R_Last);
      Enc_Buf   : String (1 .. 6 * Prompt'Length);
      Enc_Len   : Natural := 0;
      Enc_Ok    : Boolean := False;
   begin
      Json_String_Pkg.Encode (Prompt, Enc_Buf, Enc_Len, Enc_Ok);
      if not Enc_Ok then
         Ada.Text_IO.Put_Line (Not_Utf8_Word);
         Ada.Text_IO.Flush;
         return;
      end if;
      if Enc_Len > Encoded_Bound then
         Ada.Text_IO.Put_Line (Over_Bound_Word);
         Ada.Text_IO.Flush;
         return;
      end if;
      declare
         Encoded   : constant String (1 .. Enc_Len) := Enc_Buf (1 .. Enc_Len);
         Body_Text : constant String := Model_Request_Pkg.Request_Text (Model, Encoded, Max_Tokens, Num_Ctx);
         Port      : GNAT.Sockets.Port_Type;
         Request   : constant String := Request_Line & CRLF & Host_Header & Host & CRLF & Type_Header & CRLF & Length_Header & Reply_Text_Pkg.Image_Of (Body_Text'Length) & CRLF & Close_Header & CRLF & CRLF & Body_Text;
         Out_Bytes : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Request'Length));
         Socket    : GNAT.Sockets.Socket_Type;
         Sent_Last : Ada.Streams.Stream_Element_Offset;
         Got_Last  : Ada.Streams.Stream_Element_Offset;
         Chunk     : Ada.Streams.Stream_Element_Array (1 .. 4096);
         Reply     : String (1 .. Max_Reply + 4096);
         Reply_Last : Natural := 0;
      begin
         Port := GNAT.Sockets.Port_Type (Natural'Value (Port_Text));
         GNAT.Sockets.Create_Socket (Socket);
         GNAT.Sockets.Set_Socket_Option (Socket, GNAT.Sockets.Socket_Level, (GNAT.Sockets.Receive_Timeout, Timeout_Seconds));
         begin
            GNAT.Sockets.Connect_Socket (Socket, (Family => GNAT.Sockets.Family_Inet, Addr => GNAT.Sockets.Inet_Addr (Host), Port => Port));
            Reached := True;
         exception
            when GNAT.Sockets.Socket_Error =>
               null;
         end;
         if Reached then
            for I in Request'Range loop
               Out_Bytes (Ada.Streams.Stream_Element_Offset (I)) := Ada.Streams.Stream_Element (Character'Pos (Request (I)));
            end loop;
            GNAT.Sockets.Send_Socket (Socket, Out_Bytes, Sent_Last);
            begin
               loop
                  GNAT.Sockets.Receive_Socket (Socket, Chunk, Got_Last);
                  exit when Got_Last < Chunk'First;
                  exit when Reply_Last + Natural (Got_Last - Chunk'First + 1) > Reply'Length;
                  for J in Chunk'First .. Got_Last loop
                     Reply_Last := Reply_Last + 1;
                     Reply (Reply_Last) := Character'Val (Chunk (J));
                  end loop;
               end loop;
            exception
               when GNAT.Sockets.Socket_Error =>
                  Timed_Out := True;
            end;
            for I in Reply'First .. Reply_Last - 3 loop
               if Reply (I) = ASCII.CR and then Reply (I + 1) = ASCII.LF and then Reply (I + 2) = ASCII.CR and then Reply (I + 3) = ASCII.LF then
                  Body_Start := I + 4;
                  Body_Length := Reply_Last - Body_Start + 1;
                  exit;
               end if;
            end loop;
            GNAT.Sockets.Close_Socket (Socket);
         end if;
         Ada.Text_IO.Put_Line (Reply_Text_Pkg.Image_Of (Model_Request_Pkg.Fault_Kind'Pos (Model_Request_Pkg.Reply_Fault (Reached, Timed_Out, Body_Length))));
         if Model_Request_Pkg.Reply_Accepted (Reached, Timed_Out, Body_Length) and then Body_Length > 0 then
            declare
               Payload : constant String (1 .. Body_Length) := Reply (Body_Start .. Reply_Last);
            begin
               if Model_Reply_Pkg.Has_Content (Payload) then
                  declare
                     First : constant Natural := Model_Reply_Pkg.String_Field (Payload, Model_Reply_Pkg.Content_Key).first;
                     Last  : constant Natural := Model_Reply_Pkg.String_Field (Payload, Model_Reply_Pkg.Content_Key).last;
                  begin
                     Ada.Text_IO.Put (Content_Open);
                     Ada.Text_IO.Put (Payload (First .. Last));
                     Ada.Text_IO.Put_Line (Content_Close);
                  end;
               end if;
            end;
         end if;
         Ada.Text_IO.Flush;
      end;
   end;
end Model_Caller_Main;
