--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: d94351eeea59d623d3d33c3acacb7db563eef3fe2eb23233097a6d6a9d05cf9d
--
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
with Prove_Tally_Pkg;
with Prove_Diagnostics_Pkg;

procedure Prover_Service_Main is
   --  The PROVER SERVICE of CRUCIBLE's prover rail (piece 3c).
   --  HAND-AUTHORED BOUNDARY: socket, file and process I/O. Every judgement is a call into a proven
   --  package: the request's shape and the unit name's safety (Rail_Request_Pkg), what each line gnatprove
   --  printed means (Prove_Tally_Pkg). The reply carries FACTS ONLY; CRUCIBLE re-judges them.
   --  Listens on 127.0.0.1 ONLY (fixed text, not configuration). One request at a time, sequentially.
   --  An invalid request, an over-budget proof, or any failure gets NO reply: the client then records
   --  reply_refused or unmeasured, never a pass. Each request gets a fresh staging directory, deleted after.
   --  Configuration: config/prover-service.conf, one JSON line:
   --    {"port":"<digits>","staging_root":"<absolute dir>","gnatprove":"<absolute path>","timeout_seconds":"<digits>"}

   use type Json_Scan_Pkg.Kind_Type;
   use type Ada.Streams.Stream_Element_Offset;
   use type GNAT.OS_Lib.Process_Id;
   use type Ada.Calendar.Time;
   use type Prove_Tally_Pkg.Line_Kind;

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

   --  Writes the bytes of Text exactly: no line terminator is added or changed.
   procedure Write_Raw (Path : String; Text : String) is
      F : Ada.Streams.Stream_IO.File_Type;
   begin
      Ada.Streams.Stream_IO.Create (F, Ada.Streams.Stream_IO.Out_File, Path);
      String'Write (Ada.Streams.Stream_IO.Stream (F), Text);
      Ada.Streams.Stream_IO.Close (F);
   end Write_Raw;

   --  First line of a text file, or "" if it cannot be read.
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

   --  Feeds every line of a file to the proven classifier. Only_Skipped: count a line only when it is
   --  a skipped-subprogram line (used for gnatprove.out, whose other lines are not check messages).
   --  A line longer than the classifier accepts is counted as an error: fail closed.
   --  5a-1b: in the same pass, every line is also offered to the proven bounded collector
   --  Prove_Diagnostics_Pkg (which keeps only unproved / error / warning lines, at most Max_Lines of at
   --  most Max_Line_Bytes each, and COUNTS what it drops) — unless Only_Skipped, since gnatprove.out's
   --  lines are not check messages. A line the classifier cannot accept is never offered to it.
   procedure Tally_File
     (Path         : String;
      T            : in out Prove_Tally_Pkg.Tally;
      D            : in out Prove_Diagnostics_Pkg.Diagnostics;
      Only_Skipped : Boolean) is
      F : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (F) loop
         declare
            L  : constant String := Ada.Text_IO.Get_Line (F);
            L1 : constant String (1 .. L'Length) := L;
            K  : Prove_Tally_Pkg.Line_Kind;
         begin
            if L1'Length > Prove_Tally_Pkg.Max_Line then
               K := Prove_Tally_Pkg.Kind_Error;
            else
               K := Prove_Tally_Pkg.Classify (L1);
               if not Only_Skipped then
                  Prove_Diagnostics_Pkg.Add (D, L1);
               end if;
            end if;
            if not Only_Skipped or else K = Prove_Tally_Pkg.Kind_Skipped then
               T := Prove_Tally_Pkg.Add (T, K);
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (F);
   end Tally_File;

   --  One valid request: stage, prove within budget, reply with facts, delete the staging directory.
   --  Line has first index 1 and Rail_Request_Pkg.Is_Valid (Line) holds.
   procedure Handle
     (Line    : String;
      Root    : String;
      Prover  : String;
      Version : String;
      Budget  : Natural;
      VC_Budget : Natural;   --  5a-1b: gnatprove's per-check --timeout, from the conf (default 30)
      Serial  : Natural;
      Client  : GNAT.Sockets.Socket_Type)
   is
      U_Last    : constant Natural := Rail_Request_Pkg.Unit_Last (Line);
      S_Last    : constant Natural := Rail_Request_Pkg.Spec_Last (Line, U_Last);
      Unit      : constant String := Ada.Characters.Handling.To_Lower (Line (10 .. U_Last));
      Level     : constant Natural := Rail_Request_Pkg.Level_Of (Line);
      Spec_Text : constant String := Hex_Text_Pkg.Decode (Line (U_Last + 103 .. S_Last));
      Body_Text : constant String := Hex_Text_Pkg.Decode (Line (S_Last + 15 .. Line'Last - 2));
      Dir       : constant String :=
        Root & "/" & Img (Serial) & "-" & Img (Natural (Ada.Calendar.Seconds (Ada.Calendar.Clock))) & "-" &
        Img (Natural (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id)));
      Digest    : GNAT.SHA256.Message_Digest := (others => '0');
      Spawned      : Boolean := False;
      Exit_Success : Boolean := False;
      Over_Budget  : Boolean := False;
      T            : Prove_Tally_Pkg.Tally;
      Diag         : Prove_Diagnostics_Pkg.Diagnostics;
   begin
      if Ada.Directories.Exists (Dir) then
         return;   --  a staging directory is never reused
      end if;
      Ada.Directories.Create_Path (Dir);

      declare
         Ctx : GNAT.SHA256.Context := GNAT.SHA256.Initial_Context;
      begin
         GNAT.SHA256.Update (Ctx, Spec_Text);
         GNAT.SHA256.Update (Ctx, Body_Text);
         Digest := GNAT.SHA256.Digest (Ctx);
      end;

      Write_Raw (Dir & "/" & Unit & ".ads", Spec_Text);
      if Body_Text'Length > 0 then
         Write_Raw (Dir & "/" & Unit & ".adb", Body_Text);
      end if;
      Write_Raw (Dir & "/proof.gpr",
                 "project Proof is" & ASCII.LF &
                 "   for Source_Dirs use ("".""); " & ASCII.LF &
                 "   for Object_Dir use ""obj"";" & ASCII.LF &
                 "end Proof;" & ASCII.LF);

      declare
         --  (b) Every VC is bounded by gnatprove itself, so a proof cannot run forever on its own.
         --  5a-1b: the per-check bound comes from the conf's prover_timeout_seconds (default 30): a failing
         --  check costs up to that long per prover, so a unit with many failing checks is priced by it.
         Args : GNAT.OS_Lib.Argument_List :=
           (new String'("-P"),
            new String'(Dir & "/proof.gpr"),
            new String'("--level=" & Img (Level)),
            new String'("-j0"),
            new String'("--timeout=" & Img (VC_Budget)),
            new String'("--report=all"));
         Pid      : GNAT.OS_Lib.Process_Id;
         Done_Pid : GNAT.OS_Lib.Process_Id;
         Started  : constant Ada.Calendar.Time := Ada.Calendar.Clock;

         --  (c) Kill a process AND every descendant, children first. GNAT's Kill_Process_Tree walks /proc, which
         --  macOS does not have: on Bill it left why3server orphaned (3d probe, 2026-09-16). pgrep -P lists the
         --  direct children of a pid; kill -KILL ends one. Both exit non-zero harmlessly when there is nothing.
         procedure Kill_Tree (Pid_Text : String) is
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
                           Kill_Tree (Child);
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
      begin
         Pid := GNAT.OS_Lib.Non_Blocking_Spawn
           (Program_Name => Prover,
            Args         => Args,
            Output_File  => Dir & "/prove.txt",
            Err_To_Out   => True);
         for A of Args loop
            GNAT.OS_Lib.Free (A);
         end loop;
         if Pid /= GNAT.OS_Lib.Invalid_Pid then
            Spawned := True;
            loop
               GNAT.OS_Lib.Non_Blocking_Wait_Process (Done_Pid, Exit_Success);
               exit when Done_Pid /= GNAT.OS_Lib.Invalid_Pid;
               if Ada.Calendar.Clock - Started > Duration (Budget) then
                  Kill_Tree (Img (Natural (GNAT.OS_Lib.Pid_To_Integer (Pid))));
                  for Tries in 1 .. 50 loop     --  bounded reap: at most 5 s, never blocks forever
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

      if Over_Budget then
         Ada.Directories.Delete_Tree (Dir);
         return;   --  no reply: the client records unmeasured
      end if;

      Tally_File (Dir & "/prove.txt", T, Diag, Only_Skipped => False);
      Tally_File (Dir & "/obj/gnatprove/gnatprove.out", T, Diag, Only_Skipped => True);

      declare
         Ran_Fact      : Boolean := False;
         Clean_Fact    : Boolean := False;
         Compiled_Fact : Boolean := False;
         Gen_Fact      : Natural := 0;
         Unp_Fact      : Natural := 0;
         Jus_Fact      : Natural := 0;
         Skp_Fact      : Natural := 0;
      begin
         --  SLOT BEGIN (facts)
Ran_Fact := Spawned;
Clean_Fact := Spawned and then Exit_Success and then not T.saturated;
Compiled_Fact := Spawned and then T.errors = 0;
Gen_Fact := Prove_Tally_Pkg.Checks_Generated (T);
Unp_Fact := T.unproved;
Jus_Fact := T.justified;
Skp_Fact := T.skipped;
         --  SLOT END (facts)

         Send_Text (Client,
           "{""digest"":""" & Digest &
           """,""prover"":""gnatprove"",""prover_version"":""" & Version &
           """,""prover_ran"":""" & Bool_Text (Ran_Fact) &
           """,""prover_exited_cleanly"":""" & Bool_Text (Clean_Fact) &
           """,""unit_compiled"":""" & Bool_Text (Compiled_Fact) &
           """,""level_run_at"":""" & Img (Level) &
           """,""checks_generated"":""" & Img (Gen_Fact) &
           """,""checks_unproved"":""" & Img (Unp_Fact) &
           """,""checks_justified"":""" & Img (Jus_Fact) &
           """,""subprograms_skipped"":""" & Img (Skp_Fact) &
           """,""diagnostics_lines"":""" & Img (Natural (Diag.Count)) &
           """,""diagnostics_dropped"":""" & Img (Natural (Diag.Dropped)) &
           """}" & ASCII.LF);
         --  5a-1b (Tony 15:06, option c): after the JSON line, exactly diagnostics_lines RAW text lines,
         --  each a severity line gnatprove printed, in file order, bounded by the proven collector. No
         --  escaping and no hex: a line never contains LF, and the count above tells the client how many
         --  to read. The verdict is decided by the facts on the JSON line alone.
         for I in 1 .. Diag.Count loop
            Send_Text (Client, Prove_Diagnostics_Pkg.Line_Text (Diag, I) & ASCII.LF);
         end loop;
      end;

      Ada.Directories.Delete_Tree (Dir);
   exception
      when others =>
         if Ada.Directories.Exists (Dir) then
            Ada.Directories.Delete_Tree (Dir);
         end if;
         raise;
   end Handle;

   Conf_Buf    : String (1 .. Max_Conf);
   Conf_Len    : Natural := 0;
   Request_Buf : constant GNAT.OS_Lib.String_Access := new String (1 .. Rail_Request_Pkg.Max_Request);
   Serial      : Natural := 0;

begin
   declare
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "config/prover-service.conf");
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
      Prover       : constant String := Value_Text (Conf, "gnatprove");
      Port, Budget : Natural := 0;
      Port_Ok, Budget_Ok : Boolean := False;
      VC_Budget    : Natural := 30;
      VC_Ok        : Boolean := False;
      Server       : GNAT.Sockets.Socket_Type;
   begin
      Read_Natural (Conf, "port", Port, Port_Ok);
      Read_Natural (Conf, "timeout_seconds", Budget, Budget_Ok);
      --  5a-1b: optional per-check prover timeout; absent, unreadable or zero means the default of 30 s.
      Read_Natural (Conf, "prover_timeout_seconds", VC_Budget, VC_Ok);
      if not VC_Ok or else VC_Budget = 0 then
         VC_Budget := 30;
      end if;
      if not Port_Ok or else Port = 0 or else Port > 65_535 or else not Budget_Ok or else Budget = 0
        or else Root'Length = 0 or else Prover'Length = 0
      then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "prover-service: config/prover-service.conf missing or invalid; not serving");
         return;
      end if;

      Ada.Directories.Create_Path (Root);

      --  The prover's version is MEASURED at start-up, not configured.
      declare
         Args    : GNAT.OS_Lib.Argument_List := (1 => new String'("--version"));
         Ok      : Boolean;
         Code    : Integer;
         Version_File : constant String := Root & "/prover-version.txt";
      begin
         GNAT.OS_Lib.Spawn (Prover, Args, Version_File, Ok, Code, Err_To_Out => True);
         GNAT.OS_Lib.Free (Args (1));
         declare
            Version : constant String := First_Line (Version_File);
         begin
            if Version'Length = 0 then
               Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                                     "prover-service: could not run " & Prover & " --version; not serving");
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
            Ada.Text_IO.Put_Line ("prover-service: listening on 127.0.0.1:" & Img (Port) & " (" & Version & ")");

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
                                Prover  => Prover,
                                Version => Version,
                                Budget  => Budget,
                                VC_Budget => VC_Budget,
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
end Prover_Service_Main;
