--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 9a35b1f6d0d15e722f39924a638a5a4ce7e615dfb726abfabac26afec4f71d4e
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Known_Answer_Prober_Pkg;
with Lovelace_Known_Answer_Vectors_Pkg;
with Lovelace_Raw_Spec_Pkg;
with Lovelace_Function_Iterator_Pkg;

--  Wire_Main: the vacuity battery's `wire` verb [main.go:221-231, check.go:30-44, wire.go], as
--  the thin main of the Ada kit. It reads the call, makes the work dir, reads the spec, proves
--  who the verdict edge is, then runs the kit's assembly units in Go's order and lets
--  wire_close_main write the one flat JSON line and the grade lines. Built-not-proved.
procedure Wire_Main is
   use type GNAT.OS_Lib.File_Descriptor;
   package U renames Ada.Strings.Unbounded;
   LF : constant Character := Character'Val (10);
   HT : constant Character := Character'Val (9);
   Max_File : constant := 4_194_304;
   type Text_Array is array (Positive range <>) of U.Unbounded_String;

   function Decimal (N : Integer) return String is
      S : constant String := Integer'Image (N);
   begin
      if S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Decimal;

   function "+" (S : String) return U.Unbounded_String renames U.To_Unbounded_String;

   --  The whole file; "" when it is absent, unreadable or over Max_File bytes.
   function Slurp (Path : String) return String is
      FD : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
   begin
      if FD = GNAT.OS_Lib.Invalid_FD then
         return "";
      end if;
      declare
         Len : constant Long_Integer := GNAT.OS_Lib.File_Length (FD);
      begin
         if Len <= 0 or else Len > Max_File then
            GNAT.OS_Lib.Close (FD);
            return "";
         end if;
         declare
            Buf : String (1 .. Natural (Len));
            N   : constant Integer := GNAT.OS_Lib.Read (FD, Buf (1)'Address, Buf'Length);
         begin
            GNAT.OS_Lib.Close (FD);
            if N /= Buf'Length then
               return "";
            end if;
            return Buf;
         end;
      end;
   end Slurp;

   procedure Put_File (Path : String; Text : String; Append : Boolean) is
      FD : GNAT.OS_Lib.File_Descriptor;
      N  : Integer;
   begin
      if Append then
         FD := GNAT.OS_Lib.Open_Append (Path, GNAT.OS_Lib.Binary);
      else
         FD := GNAT.OS_Lib.Create_File (Path, GNAT.OS_Lib.Binary);
      end if;
      if FD = GNAT.OS_Lib.Invalid_FD then
         return;
      end if;
      if Text'Length > 0 then
         N := GNAT.OS_Lib.Write (FD, Text (Text'First)'Address, Text'Length);
      end if;
      GNAT.OS_Lib.Close (FD);
   end Put_File;

   --  One field of the work-dir form: "<key> <byte length>" LF <bytes> LF.
   function Field (Key : String; Value : String) return String is
     (Key & " " & Decimal (Value'Length) & LF & Value & LF);

   --  Read the field at Pos: its key is T (KF .. KL), its value T (VF .. VL); Pos moves past it.
   --  Ok is False (and Pos unchanged) when the text at Pos is not a well-formed field.
   procedure Next_Field (T : String; Pos : in out Positive; KF, KL, VF, VL : out Natural; Ok : out Boolean) is
      Sp  : Natural := 0;
      Nl  : Natural := 0;
      Len : Natural := 0;
   begin
      KF := Pos; KL := 0; VF := 0; VL := 0; Ok := False;
      for I in Pos .. T'Last loop
         if T (I) = LF then
            Nl := I;
            exit;
         elsif T (I) = ' ' and then Sp = 0 then
            Sp := I;
         end if;
      end loop;
      if Nl = 0 or else Sp = 0 or else Sp + 1 > Nl - 1 or else Nl - Sp > 10 then
         return;
      end if;
      for I in Sp + 1 .. Nl - 1 loop
         if T (I) not in '0' .. '9' then
            return;
         end if;
         Len := Len * 10 + (Character'Pos (T (I)) - 48);
      end loop;
      if Len > T'Last - Nl or else Nl + Len + 1 > T'Last or else T (Nl + Len + 1) /= LF then
         return;
      end if;
      KL := Sp - 1;
      VF := Nl + 1;
      VL := Nl + Len;
      Pos := Nl + Len + 2;
      Ok := True;
   end Next_Field;

   --  The value of the LAST field named Key in the field-form text T; "" when there is none.
   function Value_Of (T : String; Key : String) return String is
      Pos : Positive := T'First;
      KF, KL, VF, VL : Natural;
      Ok : Boolean;
      RF : Natural := 1;
      RL : Natural := 0;
   begin
      while Pos <= T'Last loop
         Next_Field (T, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         if T (KF .. KL) = Key then
            RF := VF;
            RL := VL;
         end if;
      end loop;
      return T (RF .. RL);
   end Value_Of;

   --  Natural value of a decimal text; 0 when it is not one.
   function Number (S : String) return Natural is
      N : Natural := 0;
   begin
      if S'Length = 0 or else S'Length > 9 then
         return 0;
      end if;
      for C of S loop
         if C not in '0' .. '9' then
            return 0;
         end if;
         N := N * 10 + (Character'Pos (C) - 48);
      end loop;
      return N;
   end Number;

   --  Start Program with Args and Input on its standard input; its standard output is Output,
   --  its exit status Code (-1 when it cannot be started). Standard error is never ours.
   procedure Run (Program : String; Args : Text_Array; Input : String;
                  Output : out U.Unbounded_String; Code : out Integer) is
      L      : GNAT.OS_Lib.Argument_List (1 .. Args'Length);
      Status : aliased Integer := 0;
   begin
      Output := U.Null_Unbounded_String;
      Code := -1;
      if not GNAT.OS_Lib.Is_Executable_File (Program) then
         return;
      end if;
      for K in L'Range loop
         L (K) := new String'(U.To_String (Args (Args'First + K - 1)));
      end loop;
      declare
         Text : constant String := GNAT.Expect.Get_Command_Output
           (Command => Program, Arguments => L, Input => Input,
            Status => Status'Access, Err_To_Out => False);
      begin
         Output := U.To_Unbounded_String (Text);
      end;
      Code := Status;
      for K in L'Range loop
         GNAT.OS_Lib.Free (L (K));
      end loop;
   end Run;

   --  The rest of the first line of T that starts with Key and a blank; "" when none.
   function Value_Of_Line (T : String; Key : String) return String is
      I : Positive := T'First;
   begin
      while I <= T'Last loop
         declare
            E : Natural := I;
         begin
            while E <= T'Last and then T (E) /= LF loop
               E := E + 1;
            end loop;
            if E - I >= Key'Length + 1 and then T (I .. I + Key'Length) = Key & " " then
               return T (I + Key'Length + 1 .. E - 1);
            end if;
            I := E + 1;
         end;
      end loop;
      return "";
   end Value_Of_Line;

   --  The kit: every executable of the battery sits in the directory of this one (resolved as
   --  argv-reader resolves the verdict edge's default: Command_Name, else its PATH hit).
   function Search (List : String; Exe : String) return String is
      Colon : Natural := 0;
   begin
      for I in List'Range loop
         if List (I) = ':' then
            Colon := I;
            exit;
         end if;
      end loop;
      if Colon > 0 then
         declare
            Head : constant String := List (List'First .. Colon - 1);
         begin
            if Head /= "" and then GNAT.OS_Lib.Is_Executable_File (Head & "/" & Exe) then
               return Head & "/" & Exe;
            end if;
            return Search (List (Colon + 1 .. List'Last), Exe);
         end;
      elsif List /= "" and then GNAT.OS_Lib.Is_Executable_File (List & "/" & Exe) then
         return List & "/" & Exe;
      end if;
      return "";
   end Search;

   function Started (Exe : String) return String is
   begin
      for C of Exe loop
         if C = '/' then
            return Exe;
         end if;
      end loop;
      if not Ada.Environment_Variables.Exists ("PATH")
        or else Search (Ada.Environment_Variables.Value ("PATH"), Exe) = ""
      then
         return Exe;
      end if;
      return Search (Ada.Environment_Variables.Value ("PATH"), Exe);
   end Started;

   function Kit_Dir return String is
      P : constant String := Started (Ada.Command_Line.Command_Name);
      A : constant String := (if P'Length > 0 and then P (P'First) = '/' then P
                              else Ada.Directories.Current_Directory & "/" & P);
      Slash : Natural := 0;
   begin
      for I in A'Range loop
         if A (I) = '/' then
            Slash := I;
         end if;
      end loop;
      if Slash <= A'First then
         return "/";
      end if;
      return GNAT.OS_Lib.Normalize_Pathname (A (A'First .. Slash - 1), Resolve_Links => False);
   end Kit_Dir;

   Kit : constant String := Kit_Dir;

   function Tmp_Root return String is
     (if Ada.Environment_Variables.Exists ("TMPDIR") and then Ada.Environment_Variables.Value ("TMPDIR") /= ""
      then Ada.Environment_Variables.Value ("TMPDIR") else "/tmp");

   W : constant String := Tmp_Root & "/lovelace-wire-"
     & Decimal (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id));

   procedure Event (Name : String; Subject : String; Detail : String) is
   begin
      Put_File (W & "/events", "wire-main" & HT & Name & HT & Subject & HT & Detail & LF, True);
   end Event;

   procedure Log (Key : String; Value : String) is
   begin
      Put_File (W & "/log", Field (Key, Value), True);
   end Log;

   --  Run one assembly unit of the kit over the work dir; True when the run goes on.
   function Phase (Name : String; Subject : Natural) return Boolean is
      Output : U.Unbounded_String;
      Code   : Integer;
   begin
      if Subject = 0 then
         Run (Kit & "/" & Name, (1 => +W), "", Output, Code);
      else
         Run (Kit & "/" & Name, (+W, +Decimal (Subject)), "", Output, Code);
      end if;
      Event ("phase", Name, Decimal (Code));
      return Code = 0;
   end Phase;

   --  The text after "<Key> " on the line that starts with it in a verdict-spawn reply; the
   --  word runs up to the error line, which runs to the end (either may hold a line end).
   function Reply_Part (R : String; Key : String) return String is
      Err_At : Natural := 0;
      K_At   : Natural := 0;
      Stop   : Natural;
   begin
      for I in R'First .. R'Last - 6 loop
         if R (I) = LF and then R (I + 1 .. I + 6) = "error " then
            Err_At := I + 1;
         end if;
      end loop;
      if Key = "error" then
         if Err_At = 0 then
            return "";
         end if;
         Stop := (if R (R'Last) = LF then R'Last - 1 else R'Last);
         return R (Err_At + 6 .. Stop);
      end if;
      for I in R'First .. R'Last - Key'Length loop
         if (I = R'First or else R (I - 1) = LF) and then R (I .. I + Key'Length) = Key & " " then
            K_At := I + Key'Length + 1;
            exit;
         end if;
      end loop;
      if K_At = 0 then
         return "";
      end if;
      Stop := K_At;
      while Stop <= R'Last and then (if Key = "word" then Stop + 1 /= Err_At else R (Stop) /= LF) loop
         Stop := Stop + 1;
      end loop;
      return R (K_At .. Stop - 1);
   end Reply_Part;

   --  Go's %q of a word, by the kit's go-quote-wide (strconv.Quote, byte for byte).
   function Quoted (Word : String) return String is
      Output : U.Unbounded_String;
      Code   : Integer;
   begin
      Put_File (W & "/word", Word, False);
      Run (Kit & "/go_quote_wide_main", (1 => +(W & "/word")), "", Output, Code);
      return U.To_String (Output);
   end Quoted;

   --  Ask the verdict edge every known answer (edge.go:130-142); "" when it is trusted, else
   --  the refusal naming the first disagreement.
   function Edge_Refusal (Edge : String) return String is
      package KA renames Lovelace_Known_Answer_Prober_Pkg;
      package KV renames Lovelace_Known_Answer_Vectors_Pkg;
      Replies : KA.Reply_Array;
   begin
      for V in KV.Vector_Index loop
         declare
            Args   : Text_Array (1 .. 2 + KV.Vectors (V).Count);
            Output : U.Unbounded_String;
            Code   : Integer;
         begin
            Args (1) := +Edge;
            Args (2) := +KV.Mode_Word (KV.Vectors (V).Mode);
            for K in 1 .. KV.Vectors (V).Count loop
               Args (2 + K) := +Decimal (KV.Vectors (V).Operands (K));
            end loop;
            Run (Kit & "/verdict_spawn_main", Args, "", Output, Code);
            declare
               R    : constant String := U.To_String (Output);
               Kind : constant String := Reply_Part (R, "kind");
               Word : constant String := Reply_Part (R, "word");
               Err  : constant String := Reply_Part (R, "error");
            begin
               if Kind = "number" then
                  Replies (V) := (Kind => KA.Number, Got => Long_Long_Integer'Value (Reply_Part (R, "value")));
               elsif Kind = "unreadable" then
                  Replies (V) := (Kind => KA.Not_A_Digit, Got => 0);
               else
                  Replies (V) := (Kind => KA.Ask_Failed, Got => 0);
               end if;
               Event ("known_answer", KV.Mode_Word (KV.Vectors (V).Mode), Kind);
               if not KA.Passes (V, Replies (V)) then
                  return KA.Refusal_Of (V, Replies (V),
                                        (if Code = 0 and then Kind /= "" then Err else "edge spawn failed"),
                                        (if Kind = "unreadable" then Quoted (Word) else ""));
               end if;
            end;
         end;
      end loop;
      return "";
   end Edge_Refusal;

   Output : U.Unbounded_String;
   Code   : Integer;
   Args   : Text_Array (1 .. Ada.Command_Line.Argument_Count);
   Go_On  : Boolean := True;
begin
   for K in Args'Range loop
      Args (K) := +Ada.Command_Line.Argument (K);
   end loop;
   Run (Kit & "/argv_reader_main", Args, "", Output, Code);
   if Code /= 0 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "wire: usage: wire <spec.ads> [<deps-dir>]");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      Call : constant String := U.To_String (Output);
      Ads  : constant String := Reply_Part (Call, "ads");
      Deps : constant String := Reply_Part (Call, "deps");
      Edge : constant String := Reply_Part (Call, "edge");
      Raw  : Lovelace_Raw_Spec_Pkg.Raw_Pool := Lovelace_Raw_Spec_Pkg.Empty_Pool;
   begin
      if Ada.Directories.Exists (W) then
         Ada.Directories.Delete_Tree (W);
      end if;
      Ada.Directories.Create_Path (W);
      Put_File (W & "/run", Field ("ads", Ads) & Field ("deps", Deps) & Field ("edge", Edge) & Field ("kit", Kit), False);
      Event ("call_read", Ads, Deps);
      --  1. Read the spec (check.go:31-34): a failure is the run failure, before the edge is asked.
      --  The bytes go straight to a file: a captured output would lose its trailing line ends.
      declare
         L  : GNAT.OS_Lib.Argument_List (1 .. 1) := (1 => new String'(Ads));
         Ok : Boolean;
      begin
         Code := -1;
         GNAT.OS_Lib.Spawn (Kit & "/spec_file_reader_main", L, W & "/read", Ok, Code, Err_To_Out => False);
         GNAT.OS_Lib.Free (L (1));
         if not Ok then
            Code := -1;
         end if;
      end;
      Output := +Slurp (W & "/read");
      if Code /= 0 then
         declare
            T : constant String := U.To_String (Output);
         begin
            Log ("failure", (if T'Length > 0 and then T (T'Last) = LF then T (T'First .. T'Last - 1) else T));
         end;
         Go_On := False;
      else
         Raw := Lovelace_Raw_Spec_Pkg.Write_Raw (Raw, U.Length (Output));
         if Lovelace_Raw_Spec_Pkg.May_Send_Ready (Raw) then
            Put_File (W & "/raw", U.To_String (Output), False);
         end if;
         --  2. Prove WHO is asked before anything is asked of it (check.go:37-44).
         declare
            Refusal : constant String := Edge_Refusal (Edge);
         begin
            if Refusal /= "" then
               Log ("refusal", Refusal);
               Go_On := False;
            end if;
         end;
      end if;
      --  3. Parse, carried units, contract gate and base run: each unit says whether the run goes on.
      Go_On := Go_On and then Phase ("wire_strip_main", 0);
      Go_On := Go_On and then Phase ("wire_parse_main", 0);
      Go_On := Go_On and then Phase ("wire_gate_main", 0);
      --  4. Every function in source order (function-iterator), each through the per-function units.
      if Go_On then
         declare
            N : constant Natural := Number (Value_Of (Slurp (W & "/table"), "count"));
            S : Lovelace_Function_Iterator_Pkg.Step;
         begin
            for K in 1 .. Lovelace_Function_Iterator_Pkg.Step_Count (N) loop
               S := Lovelace_Function_Iterator_Pkg.Step_At (N, K);
               exit when S.Index = 0;
               if Phase ("wire_domain_main", S.Index) and then Phase ("wire_claim_main", S.Index)
                 and then Phase ("wire_mutants_main", S.Index) and then Phase ("wire_norm_main", S.Index)
               then
                  null;
               end if;
               if not Phase ("wire_grade_main", S.Index) then
                  exit;
               end if;
            end loop;
         end;
      end if;
      --  5. Close and emit: the one unit that writes standard output.
      Event ("close", "", "");
      declare
         L : GNAT.OS_Lib.Argument_List (1 .. 1) := (1 => new String'(W));
      begin
         Code := GNAT.OS_Lib.Spawn (Kit & "/wire_close_main", L);
         GNAT.OS_Lib.Free (L (1));
      end;
      --  6. The events, kept out of both streams by the sink; then the work dir goes.
      --  GNAT.Expect ends the input it sends with a line end of its own, so the last one is left off here.
      declare
         Ev : constant String := Slurp (W & "/events");
      begin
         Run (Kit & "/event_sink_main", (1 .. 0 => U.Null_Unbounded_String),
              (if Ev'Length > 0 then Ev (Ev'First .. Ev'Last - 1) else ""), Output, Code);
      end;
      Ada.Directories.Delete_Tree (W);
      Ada.Command_Line.Set_Exit_Status (0);
   end;
end Wire_Main;
