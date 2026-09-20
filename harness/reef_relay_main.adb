--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 142d596f69567b0c2ee877794bf7320ebad15688a0faddda3cea53c566c9b168
--
with Ada.Text_IO;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Directories;
with Ada.Calendar;
with GNAT.Sockets;
with GNAT.OS_Lib;
with Json_Scan_Pkg;

procedure Reef_Relay_Main is
   --  The REEF RAIL TLS RELAY of CRUCIBLE (BRIEF_reef_rail_tls_relay_2026-09-19).
   --  HAND-AUTHORED BOUNDARY: socket, file and process I/O. It carries ONE line to thereef.ink over TLS and
   --  brings ONE line back. It decides NOTHING about the content: every key record is Reef-signed and
   --  nonce-bound, and Palais_Enrol_Pkg re-judges it through proven packages. The single judgement made here
   --  is whether curl's answer is a USABLE LINE at all; that is the slot.
   --  Listens on 127.0.0.1 ONLY (fixed text, not configuration). One connection at a time, sequentially,
   --  no tasking: nothing listens off-host.
   --  Any failure gets NO reply: the caller then records reef_unreachable, never a guessed answer.
   --  Configuration: config/reef-relay.conf, one JSON line:
   --    {"port":"<digits>","url":"https://host/path","staging_root":"<absolute dir>","timeout_seconds":"<digits>",
   --     "pinned_pubkey":"sha256//<base64>",   -- OPTIONAL; absent means system CA validation only
   --     "ca_file":"<absolute path>"}          -- OPTIONAL; for the probe's throwaway CA
   --  WHY curl: GNAT's library has no TLS, and binding OpenSSL or AWS would put a TLS library inside our code.
   --  curl is on every target host and is invoked exactly as the enrol edge invokes ssh-keygen: FIXED arguments,
   --  never a shell. The argument vector below is fixed text and is NOT a slot -- a planner slip there would be
   --  a security hole, not a wrong fact.
   --  WHY a file and not GNAT.Expect.Get_Command_Output: Get_Command_Output's Send appends a line feed to stdin
   --  (the enrol edge's 2026-09-19 15:19 wire fault), which would change the bytes of the request body. The line
   --  is written to a file and passed as --data-binary @<file>, and the call is spawned with the prover service's
   --  bounded wait + kill-tree so a hung TLS connection cannot wedge the relay.

   use type Json_Scan_Pkg.Kind_Type;
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.OS_Lib.Process_Id;
   use type Ada.Calendar.Time;

   Max_Conf : constant := 65_536;
   Max_Line : constant := 65_536;

   Request_Buf : String (1 .. Max_Line);
   Serial      : Natural := 0;

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

   function Starts_With (Text : String; Prefix : String) return Boolean is
   begin
      return Text'Length >= Prefix'Length
        and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   procedure Send_Text (Socket : GNAT.Sockets.Socket_Type; Text : String) is
      First : Natural := Text'First;
   begin
      while First <= Text'Last loop
         declare
            Last_Char : constant Natural := Natural'Min (Text'Last, First + 4095);
            Data      : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Last_Char - First + 1));
            Last      : Ada.Streams.Stream_Element_Offset;
         begin
            for I in Data'Range loop
               Data (I) := Ada.Streams.Stream_Element
                 (Character'Pos (Text (First + Natural (I - Data'First))));
            end loop;
            GNAT.Sockets.Send_Socket (Socket, Data, Last);
            exit when Last < Data'First;
            First := First + Natural (Last - Data'First + 1);
         end;
      end loop;
   end Send_Text;

   procedure Write_Raw (Path : String; Text : String) is
      F : Ada.Streams.Stream_IO.File_Type;
   begin
      Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Path);
      if Text'Length > 0 then
         declare
            Data : Ada.Streams.Stream_Element_Array
              (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
         begin
            for I in Data'Range loop
               Data (I) := Ada.Streams.Stream_Element
                 (Character'Pos (Text (Text'First + Natural (I - Data'First))));
            end loop;
            Ada.Streams.Stream_IO.Write (F, Data);
         end;
      end if;
      Ada.Streams.Stream_IO.Close (F);
   end Write_Raw;

   --  Read at most Max_Line + 1 bytes of a file. Over_Bound is True when the file holds more than Max_Line
   --  bytes, so the caller can refuse without ever holding an unbounded answer.
   procedure Read_Bounded (Path : String; Text : out String; Len : out Natural; Over_Bound : out Boolean) is
      F     : Ada.Streams.Stream_IO.File_Type;
      Chunk : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last  : Ada.Streams.Stream_Element_Offset;
   begin
      Len := 0;
      Over_Bound := False;
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.In_File, Path);
      while not Ada.Streams.Stream_IO.End_Of_File (F) loop
         Ada.Streams.Stream_IO.Read (F, Chunk, Last);
         exit when Last < Chunk'First;
         for I in Chunk'First .. Last loop
            if Len = Text'Length then
               Over_Bound := True;
               Ada.Streams.Stream_IO.Close (F);
               return;
            end if;
            Len := Len + 1;
            Text (Text'First + Len - 1) := Character'Val (Chunk (I));
         end loop;
      end loop;
      Ada.Streams.Stream_IO.Close (F);
   end Read_Bounded;

   --  Kill a process AND every descendant, children first. GNAT's Kill_Process_Tree walks /proc, which macOS
   --  does not have (prover service, 2026-09-16). pgrep -P lists direct children; kill -KILL ends one. Both
   --  exit non-zero harmlessly when there is nothing to do.
   procedure Kill_Tree (Dir : String; Pid_Text : String) is
      List_File : constant String := Dir & "/children-" & Pid_Text & ".txt";
      Ok   : Boolean;
      Code : Integer;
   begin
      declare
         Pargs : GNAT.OS_Lib.Argument_List := (new String'("-P"), new String'(Pid_Text));
      begin
         GNAT.OS_Lib.Spawn ("/usr/bin/pgrep", Pargs, List_File, Ok, Code, Err_To_Out => False);
         for A of Pargs loop
            GNAT.OS_Lib.Free (A);
         end loop;
      end;
      if Ada.Directories.Exists (List_File) then
         declare
            F : Ada.Text_IO.File_Type;
         begin
            Ada.Text_IO.Open (F, Ada.Text_IO.In_File, List_File);
            while not Ada.Text_IO.End_Of_File (F) loop
               declare
                  Child : constant String := Ada.Text_IO.Get_Line (F);
               begin
                  if Child'Length > 0 then
                     Kill_Tree (Dir, Child);
                  end if;
               end;
            end loop;
            Ada.Text_IO.Close (F);
         end;
      end if;
      declare
         Kargs : GNAT.OS_Lib.Argument_List := (new String'("-KILL"), new String'(Pid_Text));
      begin
         GNAT.OS_Lib.Spawn ("/bin/kill", Kargs, Dir & "/kill-" & Pid_Text & ".txt", Ok, Code, Err_To_Out => True);
         for A of Kargs loop
            GNAT.OS_Lib.Free (A);
         end loop;
      end;
   end Kill_Tree;

   --  Carry one line to the Reef and bring one back. No reply at all unless the slot says the answer is usable.
   procedure Handle
     (Line   : String;
      Root   : String;
      Url    : String;
      Pin    : String;
      Ca     : String;
      Budget : Natural;
      Serial : Natural;
      Client : GNAT.Sockets.Socket_Type)
   is
      Dir       : constant String := Root & "/call-" & Img (Serial);
      Body_File : constant String := Dir & "/request.json";
      Out_File  : constant String := Dir & "/reply.txt";

      Spawned      : Boolean := False;
      Exit_Success : Boolean := False;
      Timed_Out    : Boolean := False;

      Answer     : String (1 .. Max_Line);
      Out_Len    : Natural := 0;
      Over_Bound : Boolean := False;
      Line_Feeds : Natural := 0;
      Ends_LF    : Boolean := False;

      Reply_Fact : Boolean := False;
   begin
      if Ada.Directories.Exists (Dir) then
         return;   --  a staging directory is never reused
      end if;
      Ada.Directories.Create_Path (Dir);

      --  The request body is exactly the bytes of the line, without the line feed that terminated it.
      Write_Raw (Body_File, Line);

      declare
         --  FIXED ARGUMENTS. --proto =https forbids a downgrade even if a redirect tries one; --fail makes an
         --  HTTP error status a non-zero exit instead of a body; --max-time bounds the whole call. The optional
         --  --cacert and --pinnedpubkey are appended only when configured. NOTHING here is interpolated from
         --  the request line: the line travels as a file, never as an argument.
         Base : constant GNAT.OS_Lib.Argument_List :=
           (new String'("-sS"),
            new String'("--fail"),
            new String'("--proto"),
            new String'("=https"),
            new String'("--max-time"),
            new String'(Img (Budget)),
            new String'("-H"),
            new String'("Content-Type: application/json"),
            new String'("--data-binary"),
            new String'("@" & Body_File));
         Extra_Count : constant Natural :=
           (if Ca'Length > 0 then 2 else 0) + (if Pin'Length > 0 then 2 else 0);
         Args : GNAT.OS_Lib.Argument_List (1 .. Base'Length + Extra_Count + 1);
         Next : Natural := Args'First;

         Pid      : GNAT.OS_Lib.Process_Id;
         Done_Pid : GNAT.OS_Lib.Process_Id;
         Started  : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      begin
         for A of Base loop
            Args (Next) := A;
            Next := Next + 1;
         end loop;
         if Ca'Length > 0 then
            Args (Next) := new String'("--cacert");
            Args (Next + 1) := new String'(Ca);
            Next := Next + 2;
         end if;
         if Pin'Length > 0 then
            Args (Next) := new String'("--pinnedpubkey");
            Args (Next + 1) := new String'(Pin);
            Next := Next + 2;
         end if;
         Args (Next) := new String'(Url);

         Pid := GNAT.OS_Lib.Non_Blocking_Spawn
           (Program_Name => "/usr/bin/curl",
            Args         => Args,
            Output_File  => Out_File,
            Err_To_Out   => False);
         for A of Args loop
            GNAT.OS_Lib.Free (A);
         end loop;

         if Pid /= GNAT.OS_Lib.Invalid_Pid then
            Spawned := True;
            loop
               GNAT.OS_Lib.Non_Blocking_Wait_Process (Done_Pid, Exit_Success);
               exit when Done_Pid /= GNAT.OS_Lib.Invalid_Pid;
               --  curl's own --max-time should end it first; this is the belt for a curl that ignores it.
               if Ada.Calendar.Clock - Started > Duration (Budget + 5) then
                  Timed_Out := True;
                  Kill_Tree (Dir, Img (Natural (GNAT.OS_Lib.Pid_To_Integer (Pid))));
                  for Tries in 1 .. 50 loop   --  bounded reap: at most 5 s, never blocks forever
                     GNAT.OS_Lib.Non_Blocking_Wait_Process (Done_Pid, Exit_Success);
                     exit when Done_Pid /= GNAT.OS_Lib.Invalid_Pid;
                     delay 0.1;
                  end loop;
                  Exit_Success := False;
                  exit;
               end if;
               delay 0.05;
            end loop;
         end if;
      end;

      Read_Bounded (Out_File, Answer, Out_Len, Over_Bound);
      for I in 1 .. Out_Len loop
         if Answer (I) = ASCII.LF then
            Line_Feeds := Line_Feeds + 1;
         end if;
      end loop;
      Ends_LF := Out_Len > 0 and then Answer (Out_Len) = ASCII.LF;

      --  SLOT BEGIN (reply)
      Reply_Fact := Spawned and then Exit_Success and then not Timed_Out and then not Over_Bound and then Out_Len > 0 and then Line_Feeds = 1 and then Ends_LF;
      --  SLOT END (reply)

      if Reply_Fact then
         Send_Text (Client, Answer (1 .. Out_Len));
      end if;

      begin
         Ada.Directories.Delete_Tree (Dir);
      exception
         when others =>
            null;
      end;
   exception
      when others =>
         null;   --  no reply; the relay keeps serving the next caller
   end Handle;

   Server : GNAT.Sockets.Socket_Type;

begin
   declare
      Conf_Path : constant String := "config/reef-relay.conf";
      Conf_Buf  : String (1 .. Max_Conf);
      Conf_Len  : Natural := 0;
      Conf_Over : Boolean := False;
   begin
      Read_Bounded (Conf_Path, Conf_Buf, Conf_Len, Conf_Over);
      if Conf_Len = 0 or else Conf_Over then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "reef-relay: config/reef-relay.conf missing or invalid; not serving");
         return;
      end if;

      declare
         Conf      : constant String := Conf_Buf (1 .. Conf_Len);
         Url       : constant String := Value_Text (Conf, "url");
         Root      : constant String := Value_Text (Conf, "staging_root");
         Pin       : constant String := Value_Text (Conf, "pinned_pubkey");
         Ca        : constant String := Value_Text (Conf, "ca_file");
         Port      : Natural;
         Port_Ok   : Boolean;
         Budget    : Natural;
         Budget_Ok : Boolean;
      begin
         Read_Natural (Conf, "port", Port, Port_Ok);
         Read_Natural (Conf, "timeout_seconds", Budget, Budget_Ok);
         --  FAIL CLOSED at start-up. A url that is not https is refused here as well as by --proto =https:
         --  a relay that cannot be plaintext is easier to reason about than one that refuses per request.
         if not Port_Ok or else Port = 0 or else Port > 65_535
           or else not Budget_Ok or else Budget = 0
           or else Root'Length = 0
           or else not Starts_With (Url, "https://")
         then
            Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                                  "reef-relay: config/reef-relay.conf missing or invalid; not serving");
            return;
         end if;

         Ada.Directories.Create_Path (Root);

         GNAT.Sockets.Create_Socket (Server);
         GNAT.Sockets.Set_Socket_Option
           (Server, GNAT.Sockets.Socket_Level, (GNAT.Sockets.Reuse_Address, True));
         GNAT.Sockets.Bind_Socket
           (Server,
            (Family => GNAT.Sockets.Family_Inet,
             Addr   => GNAT.Sockets.Loopback_Inet_Addr,
             Port   => GNAT.Sockets.Port_Type (Port)));
         GNAT.Sockets.Listen_Socket (Server);
         Ada.Text_IO.Put_Line ("reef-relay: listening on 127.0.0.1:" & Img (Port) & " -> " & Url);

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
                     Chunk : Ada.Streams.Stream_Element_Array (1 .. 4096);
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
                              --  over the bound: close with no reply, and do not relay a truncated line
                              Done := True;
                              exit;
                           else
                              Len := Len + 1;
                              Request_Buf (Len) := Character'Val (Chunk (I));
                           end if;
                        end loop;
                     end loop;
                  end;

                  if Complete and then Len > 0 then
                     Serial := Serial + 1;
                     Handle (Line   => Request_Buf (1 .. Len),
                             Root   => Root,
                             Url    => Url,
                             Pin    => Pin,
                             Ca     => Ca,
                             Budget => Budget,
                             Serial => Serial,
                             Client => Client);
                  end if;
               exception
                  when others =>
                     null;   --  no reply; the relay keeps serving the next caller
               end;
               GNAT.Sockets.Close_Socket (Client);
            exception
               when others =>
                  null;
            end;
         end loop;
      end;
   end;
end Reef_Relay_Main;
