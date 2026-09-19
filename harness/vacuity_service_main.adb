--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 323c226f3b9933891c5bda9d9cb1f7d14a77609406a781f7119006da3ab7b52a
--
--  Vacuity_Service_Main — the VACUITY SERVICE of CRUCIBLE's vacuity rail (step 5a-5b), sibling of the prover service.
--  HAND-AUTHORED BOUNDARY: socket, file and process I/O. Every judgement is a call into a proven package: the request's
--  shape and the unit name's safety (Rail_Request_Pkg). The reply carries FACTS ONLY (the battery's counts and its
--  per-function grades); CRUCIBLE re-judges them through Vacuity_Facts_Pkg. Listens on 127.0.0.1 ONLY. One request
--  at a time. An invalid request, an over-budget run, or any failure gets NO reply: the client records unmeasured.
--  Configuration: config/vacuity-service.conf, one JSON line:
--    {"port":"<digits>","staging_root":"<absolute dir>","battery":"<absolute path to check-cores-mcp>",
--     "deps_root":"<absolute dir of carried .ads/.adb, or absent>","timeout_seconds":"<digits>"}
--  The battery is spawned as  check-cores-mcp wire <spec.ads> [<deps_root>]  and prints the wire: one JSON line of
--  string-valued facts, then grade_lines raw lines "<name> <grade> <word>". The service prepends the digest and relays.
with Ada.Text_IO;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Directories;
with Ada.Calendar;
with Ada.Characters.Handling;
with GNAT.Sockets;
with GNAT.SHA256;
with GNAT.OS_Lib;
with Json_Scan_Pkg;
with Hex_Text_Pkg;
with Rail_Request_Pkg;
procedure Vacuity_Service_Main is
   use type Json_Scan_Pkg.Kind_Type;
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.OS_Lib.Process_Id;
   use type Ada.Calendar.Time;
   Max_Conf : constant := 65_536;
   function Value_Text (Line : String; Key : String) return String is
      S : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Line, Key);
   begin
      if S.found and then S.kind = Json_Scan_Pkg.K_String then
         declare
            C : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.String_Contents (Line, S);
         begin
            if C.first <= C.last then
               return Line (C.first .. C.last);
            end if;
         end;
      end if;
      return "";
   end Value_Text;
   procedure Read_Natural (Line : String; Key : String; Value : out Natural; Valid : out Boolean) is
   begin
      Value := 0;
      Valid := False;
      if Value_Text (Line, Key)'Length > 0 then
         begin
            Value := Natural'Value (Value_Text (Line, Key));
            Valid := True;
         exception
            when Constraint_Error =>
               Value := 0;
               Valid := False;
         end;
      end if;
   end Read_Natural;
   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;
   function Bool_Text (B : Boolean) return String is
   begin
      if B then
         return "true";
      else
         return "false";
      end if;
   end Bool_Text;
   procedure Send_Text (Socket : GNAT.Sockets.Socket_Type; Text : String) is
      First : Natural := Text'First;
   begin
      while First <= Text'Last loop
         declare
            Last_Char : constant Natural := Natural'Min (Text'Last, First + 4095);
            Data      : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Last_Char - First + 1));
            Sent_To   : Ada.Streams.Stream_Element_Offset := 0;
            Last      : Ada.Streams.Stream_Element_Offset;
         begin
            for I in Data'Range loop
               Data (I) := Ada.Streams.Stream_Element
                 (Character'Pos (Text (First + Natural (I) - 1)));
            end loop;
            while Sent_To < Data'Last loop
               GNAT.Sockets.Send_Socket (Socket, Data (Sent_To + 1 .. Data'Last), Last);
               exit when Last <= Sent_To;
               Sent_To := Last;
            end loop;
            First := Last_Char + 1;
         end;
      end loop;
   end Send_Text;
   procedure Write_Raw (Path : String; Text : String) is
      F : Ada.Streams.Stream_IO.File_Type;
   begin
      Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Path);
      String'Write (Ada.Streams.Stream_IO.Stream (F), Text);
      Ada.Streams.Stream_IO.Close (F);
   end Write_Raw;
   function First_Line (Path : String) return String is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      if Ada.Text_IO.End_Of_File (F) then
         Ada.Text_IO.Close (F);
         return "";
      end if;
      declare
         L : constant String := Ada.Text_IO.Get_Line (F);
      begin
         Ada.Text_IO.Close (F);
         return L;
      end;
   exception
      when others =>
         return "";
   end First_Line;
   procedure Handle
     (Line    : String;
      Root    : String;
      Battery : String;
      Deps    : String;
      Budget  : Natural;
      Serial  : Natural;
      Client  : GNAT.Sockets.Socket_Type)
   is
      U_Last    : constant Natural := Rail_Request_Pkg.Unit_Last (Line);
      S_Last    : constant Natural := Rail_Request_Pkg.Spec_Last (Line, U_Last);
      Unit      : constant String := Ada.Characters.Handling.To_Lower (Line (10 .. U_Last));
      Spec_Text : constant String := Hex_Text_Pkg.Decode (Line (U_Last + 103 .. S_Last));
      Dir       : constant String :=
        Root & "/" & Img (Serial) & "-" & Img (Natural (Ada.Calendar.Seconds (Ada.Calendar.Clock))) & "-" &
        Img (Natural (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id)));
      Digest       : GNAT.SHA256.Message_Digest := (others => '0');
      Spawned      : Boolean := False;
      Exit_Success : Boolean := False;
      Over_Budget  : Boolean := False;
      Wire_Path    : constant String := Dir & "/wire.txt";
   begin
      if Ada.Directories.Exists (Dir) then
         return;   --  a staging directory is never reused
      end if;
      Ada.Directories.Create_Path (Dir);
      declare
         Ctx : GNAT.SHA256.Context := GNAT.SHA256.Initial_Context;
      begin
         GNAT.SHA256.Update (Ctx, Spec_Text);
         Digest := GNAT.SHA256.Digest (Ctx);
      end;
      Write_Raw (Dir & "/" & Unit & ".ads", Spec_Text);
      declare
         Args : GNAT.OS_Lib.Argument_List (1 .. (if Deps'Length > 0 then 3 else 2));
         Pid      : GNAT.OS_Lib.Process_Id;
         Done_Pid : GNAT.OS_Lib.Process_Id;
         Started  : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      begin
         Args (1) := new String'("wire");
         Args (2) := new String'(Dir & "/" & Unit & ".ads");
         if Deps'Length > 0 then
            Args (3) := new String'(Deps);
         end if;
         Pid := GNAT.OS_Lib.Non_Blocking_Spawn
           (Program_Name => Battery, Args => Args, Output_File => Wire_Path, Err_To_Out => False);
         for A of Args loop
            GNAT.OS_Lib.Free (A);
         end loop;
         if Pid /= GNAT.OS_Lib.Invalid_Pid then
            Spawned := True;
            loop
               GNAT.OS_Lib.Non_Blocking_Wait_Process (Done_Pid, Exit_Success);
               exit when Done_Pid /= GNAT.OS_Lib.Invalid_Pid;
               if Ada.Calendar.Clock - Started > Duration (Budget) then
                  --  The battery is killed; its own gnatprove children end on their step bound.
                  declare
                     Kargs : GNAT.OS_Lib.Argument_List :=
                       (new String'("-KILL"), new String'(Img (Natural (GNAT.OS_Lib.Pid_To_Integer (Pid)))));
                     Ok   : Boolean;
                     Code : Integer;
                  begin
                     GNAT.OS_Lib.Spawn ("/bin/kill", Kargs, Dir & "/kill.txt", Ok, Code, Err_To_Out => True);
                     for A of Kargs loop
                        GNAT.OS_Lib.Free (A);
                     end loop;
                  end;
                  for Tries in 1 .. 50 loop
                     GNAT.OS_Lib.Non_Blocking_Wait_Process (Done_Pid, Exit_Success);
                     exit when Done_Pid /= GNAT.OS_Lib.Invalid_Pid;
                     delay 0.1;
                  end loop;
                  Over_Budget := True;
                  exit;
               end if;
               delay 0.2;
            end loop;
         end if;
      end;
      if Over_Budget or else not Spawned or else not Ada.Directories.Exists (Wire_Path) then
         Ada.Directories.Delete_Tree (Dir);
         return;   --  no reply: the client records unmeasured
      end if;
      declare
         F     : Ada.Text_IO.File_Type;
         First : constant String := First_Line (Wire_Path);
      begin
         if First'Length < 2 or else First (First'First) /= '{' then
            Ada.Directories.Delete_Tree (Dir);
            return;   --  not the wire: no reply
         end if;
         --  SLOT BEGIN (reply)
Send_Text (Client, "{""digest"":""" & Digest & """," & First (First'First + 1 .. First'Last) & ASCII.LF);
         --  SLOT END (reply)
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Wire_Path);
         Ada.Text_IO.Skip_Line (F);
         while not Ada.Text_IO.End_Of_File (F) loop
            Send_Text (Client, Ada.Text_IO.Get_Line (F) & ASCII.LF);
         end loop;
         Ada.Text_IO.Close (F);
      end;
      Ada.Directories.Delete_Tree (Dir);
   exception
      when others =>
         if Ada.Directories.Exists (Dir) then
            Ada.Directories.Delete_Tree (Dir);
         end if;
   end Handle;
   Conf_Buf    : String (1 .. Max_Conf);
   Conf_Len    : Natural := 0;
   Request_Buf : constant GNAT.OS_Lib.String_Access := new String (1 .. Rail_Request_Pkg.Max_Request);
   Serial      : Natural := 0;
begin
   declare
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "config/vacuity-service.conf");
      if not Ada.Text_IO.End_Of_File (F) then
         declare
            L : constant String := Ada.Text_IO.Get_Line (F);
         begin
            if L'Length <= Conf_Buf'Length then
               Conf_Buf (1 .. L'Length) := L;
               Conf_Len := L'Length;
            end if;
         end;
      end if;
      Ada.Text_IO.Close (F);
   exception
      when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error =>
         Conf_Len := 0;
   end;
   declare
      Conf         : constant String (1 .. Conf_Len) := Conf_Buf (1 .. Conf_Len);
      Root         : constant String := Value_Text (Conf, "staging_root");
      Battery      : constant String := Value_Text (Conf, "battery");
      Deps         : constant String := Value_Text (Conf, "deps_root");
      Port, Budget : Natural := 0;
      Port_Ok, Budget_Ok : Boolean := False;
      Server       : GNAT.Sockets.Socket_Type;
   begin
      Read_Natural (Conf, "port", Port, Port_Ok);
      Read_Natural (Conf, "timeout_seconds", Budget, Budget_Ok);
      if not Port_Ok or else Port = 0 or else Port > 65_535 or else not Budget_Ok or else Budget = 0
        or else Root'Length = 0 or else Battery'Length = 0
      then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "vacuity-service: config/vacuity-service.conf missing or invalid; not serving");
         return;
      end if;
      Ada.Directories.Create_Path (Root);
      declare
      begin
         declare
            Version : constant String := "check-cores-mcp";
         begin
            if not Ada.Directories.Exists (Battery) then
               Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                                     "vacuity-service: battery not found at " & Battery & "; not serving");
               return;
            end if;
            GNAT.Sockets.Create_Socket (Server);
            GNAT.Sockets.Set_Socket_Option
              (Server, GNAT.Sockets.Socket_Level, (GNAT.Sockets.Reuse_Address, True));
            GNAT.Sockets.Bind_Socket
              (Server,
               (Family => GNAT.Sockets.Family_Inet,
                Addr   => GNAT.Sockets.Loopback_Inet_Addr,
                Port   => GNAT.Sockets.Port_Type (Port)));
            GNAT.Sockets.Listen_Socket (Server);
            Ada.Text_IO.Put_Line ("vacuity-service: listening on 127.0.0.1:" & Img (Port) & " (" & Version & ")");
            loop
               declare
                  Client   : GNAT.Sockets.Socket_Type;
                  Peer     : GNAT.Sockets.Sock_Addr_Type;
                  Len      : Natural := 0;
                  Complete : Boolean := False;
               begin
                  GNAT.Sockets.Accept_Socket (Server, Client, Peer);
                  begin
                     GNAT.Sockets.Set_Socket_Option
                       (Client, GNAT.Sockets.Socket_Level, (GNAT.Sockets.Receive_Timeout, 30.0));
                     declare
                        Chunk : Ada.Streams.Stream_Element_Array (1 .. 65_536);
                        Last  : Ada.Streams.Stream_Element_Offset;
                        Done  : Boolean := False;
                     begin
                        while not Done loop
                           GNAT.Sockets.Receive_Socket (Client, Chunk, Last);
                           exit when Last < Chunk'First;
                           for I in Chunk'First .. Last loop
                              if Character'Val (Chunk (I)) = ASCII.LF then
                                 Complete := True;
                                 Done := True;
                                 exit;
                              elsif Len = Request_Buf'Last then
                                 Done := True;
                                 exit;
                              else
                                 Len := Len + 1;
                                 Request_Buf (Len) := Character'Val (Chunk (I));
                              end if;
                           end loop;
                        end loop;
                     end;
                     if Complete and then Rail_Request_Pkg.Is_Valid (Request_Buf (1 .. Len)) then
                        Serial := Serial + 1;
                        Handle (Line    => Request_Buf (1 .. Len),
                                Root    => Root,
                                Battery => Battery,
                                Deps    => Deps,
                                Budget  => Budget,
                                Serial  => Serial,
                                Client  => Client);
                     end if;
                  exception
                     when others =>
                        null;   --  no reply; the service keeps serving the next request
                  end;
                  GNAT.Sockets.Close_Socket (Client);
               exception
                  when others =>
                     null;
               end;
            end loop;
         end;
      end;
   end;
end Vacuity_Service_Main;
