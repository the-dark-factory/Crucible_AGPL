--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 0ac231e957c952ef1e5760a82e9693d9108228c7a2b8a6d33cfd440eb8b6867d
--
--  Rail_Socket_Edge body -- template (seat-written plumbing) with ONE slot (reply_byte), filled by a Wu edge
--  round; brief BRIEF_crucible_step4_wiring_2026-09-17 (4b unit 2). No Bind_Socket, Listen_Socket or
--  Accept_Socket anywhere.
with Ada.Streams;
with GNAT.Sockets;

package body Rail_Socket_Edge with SPARK_Mode => Off is

   procedure Exchange
     (Host            : String;
      Port            : Positive;
      Request         : String;
      Timeout_Seconds : Positive;
      Max_Reply       : Positive;
      Until_Line_Feed : Boolean;
      Reply           : out String;
      Reply_Len       : out Natural;
      Reached         : out Boolean;
      Timed_Out       : out Boolean;
      Over_Bound      : out Boolean;
      Complete        : out Boolean)
   is
      use GNAT.Sockets;
      use type Ada.Streams.Stream_Element_Offset;

      LF      : constant Character := Character'Val (10);
      Socket  : Socket_Type;
      Created : Boolean := False;
      Got_LF  : Boolean := False;
      Closed  : Boolean := False;
      Status  : Selector_Status;
      Chunk   : Ada.Streams.Stream_Element_Array (1 .. 65_536);
      Last    : Ada.Streams.Stream_Element_Offset;
   begin
      Reply_Len  := 0;
      Reached    := False;
      Timed_Out  := False;
      Over_Bound := False;
      Complete   := False;

      if Port > 65_535 then
         return;
      end if;

      begin
         Create_Socket (Socket);
         Created := True;
         Connect_Socket
           (Socket   => Socket,
            Server   => (Family => Family_Inet, Addr => Inet_Addr (Host), Port => Port_Type (Port)),
            Timeout  => Duration (Timeout_Seconds),
            Selector => null,
            Status   => Status);
         if Status /= Completed then
            Close_Socket (Socket);
            return;
         end if;
         Reached := True;
         Set_Socket_Option (Socket, Socket_Level, (Receive_Timeout, Duration (Timeout_Seconds)));
         Set_Socket_Option (Socket, Socket_Level, (Send_Timeout, Duration (Timeout_Seconds)));

         --  Send the whole request.
         declare
            Data  : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Request'Length));
            First : Ada.Streams.Stream_Element_Offset := 1;
            Sent  : Ada.Streams.Stream_Element_Offset;
         begin
            for I in Request'Range loop
               Data (Ada.Streams.Stream_Element_Offset (I - Request'First + 1)) :=
                 Ada.Streams.Stream_Element (Character'Pos (Request (I)));
            end loop;
            while First <= Data'Last loop
               Send_Socket (Socket, Data (First .. Data'Last), Sent);
               exit when Sent < First;
               First := Sent + 1;
            end loop;
         end;

         --  Receive until the reply ends as asked, the bound is reached, or the peer closes.
         Receiving :
         loop
            Receive_Socket (Socket, Chunk, Last);
            if Last < Chunk'First then
               Closed := True;
               exit Receiving;
            end if;
            for K in Chunk'First .. Last loop
               declare
                  C : constant Character := Character'Val (Natural (Chunk (K)));
               begin
                  null;  --  keeps the block legal with the slot empty
                  --  SLOT BEGIN (reply_byte)
         if Until_Line_Feed and then C = LF then
            Got_LF := True;
         elsif Reply_Len = Max_Reply then
            Over_Bound := True;
         else
            Reply_Len := Reply_Len + 1;
            Reply (Reply_Len) := C;
         end if;
                  --  SLOT END (reply_byte)
               end;
               exit when Got_LF or else Over_Bound;
            end loop;
            exit Receiving when Got_LF or else Over_Bound;
         end loop Receiving;
      exception
         when Socket_Error =>
            if Reached then
               Timed_Out := True;
            end if;
      end;

      if Created then
         begin
            Close_Socket (Socket);
         exception
            when Socket_Error =>
               null;
         end;
      end if;

      Complete := Reached and then not Timed_Out and then not Over_Bound
        and then (if Until_Line_Feed then Got_LF else Closed);
   end Exchange;

end Rail_Socket_Edge;
