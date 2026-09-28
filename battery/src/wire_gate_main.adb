--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 90d3148feef0613fc066da9b712dc80f8d812ed2e1737bfafaab519c3a498e98
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Contract_Gate_Pkg;
with Lovelace_Base_Runner_Pkg;
with Lovelace_Base_Run_Pkg;

--  Wire_Gate_Main: the carried units, the contract gate and the base run of the vacuity
--  battery [check.go:51-104], as one assembly unit of the Ada kit. `wire_gate_main <W>`.
--  Built-not-proved: every decision is a proven core's; this unit reads, spawns and writes.
procedure Wire_Gate_Main is
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
   --  ---- the gate unit ----
   package CG renames Lovelace_Contract_Gate_Pkg;
   package BR renames Lovelace_Base_Runner_Pkg;
   package BP renames Lovelace_Base_Run_Pkg;
   use type CG.Gate_Word;
   use type BR.Run_State;

   W           : constant String := (if Ada.Command_Line.Argument_Count >= 1 then Ada.Command_Line.Argument (1) else "");
   Run_Text    : constant String := Slurp (W & "/run");
   Head_Text   : constant String := Slurp (W & "/head");
   Table_Text  : constant String := Slurp (W & "/table");
   Counts_Text : constant String := Slurp (W & "/counts");
   Kit         : constant String := Value_Of (Run_Text, "kit");
   Deps        : constant String := Value_Of (Run_Text, "deps");
   Pkg         : constant String := Value_Of (Head_Text, "package");

   procedure Log (Key : String; Value : String) is
   begin
      Put_File (W & "/log", Field (Key, Value), True);
   end Log;

   procedure Event (Name : String; Detail : String) is
   begin
      Put_File (W & "/events", "wire-gate" & HT & Name & HT & Pkg & HT & Detail & LF, True);
   end Event;

   function Chomp (T : String) return String is
     (if T'Length > 0 and then T (T'Last) = LF then T (T'First .. T'Last - 1) else T);

   --  Get_Command_Output drops the child's last line end: every edge here ends its output with one.
   function Lined (T : String) return String is
     (if T'Length > 0 and then T (T'Last) /= LF then T & LF else T);

   function Starts (T : String; P : String) return Boolean is
     (T'Length >= P'Length and then T (T'First .. T'First + P'Length - 1) = P);

   --  Has_Pre / Has_Post of every function of the table, in table order (Go: Pre /= "", Post /= "").
   procedure Read_Flags (F : in out CG.Flags_Array) is
      Pos : Positive := Table_Text'First;
      KF, KL, VF, VL : Natural;
      Ok  : Boolean;
      K   : Natural := 0;
   begin
      while Pos <= Table_Text'Last loop
         Next_Field (Table_Text, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         declare
            Key : constant String := Table_Text (KF .. KL);
         begin
            if Key = "name" then
               K := K + 1;
            elsif K in F'Range and then Key = "pre" then
               F (K).Has_Pre := VL >= VF;
            elsif K in F'Range and then Key = "post" then
               F (K).Has_Post := VL >= VF;
            end if;
         end;
      end loop;
   end Read_Flags;

   Names  : U.Unbounded_String;
   Output : U.Unbounded_String;
   Code   : Integer;
   State  : BR.Run_State := BR.Not_Run;
   Pool   : BP.Base_Pool := BP.Empty_Pool;
begin
   if W = "" or else Kit = "" or else Pkg = "" then
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   --  1. Carried units (check.go:51-59): the listing is deps-lister's (carried-unit-rule inside it).
   if Deps /= "" then
      Run (Kit & "/deps_lister_main", (+Deps, +Pkg), "", Output, Code);
      if Code /= 0 then
         Log ("failure", "deps dir: " & Chomp (U.To_String (Output)));
         Event ("deps", "failure");
         Ada.Command_Line.Set_Exit_Status (1);
         return;
      end if;
      Names := +Lined (U.To_String (Output));
      Put_File (W & "/deps", U.To_String (Names), False);
      Event ("deps", "listed");
   end if;
   --  2. The counts and the contract gate (check.go:60-90): contract-gate decides, refusal-texts words it.
   declare
      N         : constant Natural := Number (Value_Of (Table_Text, "count"));
      Flags     : CG.Flags_Array (1 .. N);
      Posts_Dec : constant Natural := Number (Value_Of (Counts_Text, "posts"));
      Pres_Dec  : constant Natural := Number (Value_Of (Counts_Text, "pres"));
   begin
      Read_Flags (Flags);
      declare
         Rec : constant CG.Gate_Record := CG.Gate_Record_Of (Flags, Posts_Dec, Pres_Dec);
      begin
         Log ("header", Decimal (Rec.Functions_Read) & " " & Decimal (Rec.Posts_Declared) & " "
              & Decimal (Rec.Posts_Read));
         if Rec.Word /= CG.Gate_Open then
            Log ("refusal", CG.Gate_Refusal (Rec.Posts_Read, Posts_Dec, CG.Count_Pres (Flags, N), Pres_Dec));
            Event ("gate", "refusal");
            Ada.Command_Line.Set_Exit_Status (1);
            return;
         end if;
      end;
   end;
   --  3. The base run (check.go:92-104): prover over the clean text, tag base, the carried names;
   --  base-runner says what the result was and whether it is one error; base-run holds it once.
   if State = BR.Not_Run then
      State := BR.Run_Base (State);
      Put_File (W & "/variant", Value_Of (Head_Text, "text"), False);
      declare
         L     : constant String := U.To_String (Names);
         Count : Natural := 0;
      begin
         for C of L loop
            if C = LF then
               Count := Count + 1;
            end if;
         end loop;
         declare
            Args : Text_Array (1 .. (if Deps = "" then 3 else 4 + Count));
            K    : Positive := 5;
            F    : Positive := L'First;
         begin
            Args (1) := +(W & "/variant");
            Args (2) := +Pkg;
            Args (3) := +"base";
            if Deps /= "" then
               Args (4) := +Deps;
               for I in L'Range loop
                  if L (I) = LF then
                     Args (K) := +L (F .. I - 1);
                     K := K + 1;
                     F := I + 1;
                  end if;
               end loop;
            end if;
            Run (Kit & "/prover_main", Args, "", Output, Code);
         end;
      end;
      declare
         R     : constant String :=
           (if Code /= 0 then "reached false" & LF & "fault prover edge" & LF else Lined (U.To_String (Output)));
         Fault : constant String := Value_Of_Line (R, "fault");
         Error_Seen : constant Boolean := Starts (Fault, "gnatprove reported an error");
         Exit_Failed : constant Boolean := not Error_Seen and then Starts (Fault, "gnatprove: ");
         Setup_Failed : constant Boolean := Code /= 0 or else (Fault /= "" and then not Error_Seen and then not Exit_Failed);
         B     : constant BR.Base_Result :=
           BR.Base_Result_Of (Setup_Failed, Error_Seen, Exit_Failed, Value_Of_Line (R, "reached") = "true");
         Msgs  : Natural := 0;
      begin
         for I in R'Range loop
            if (I = R'First or else R (I - 1) = LF) and then I + 3 <= R'Last and then R (I .. I + 3) = "msg " then
               Msgs := Msgs + 1;
            end if;
         end loop;
         for K in 1 .. B.Errors loop
            Log ("error", "base: " & (if Fault = "" then "prover edge" else Fault));
         end loop;
         Pool := BP.Write_Base (Pool, B.Reached, B.Faulted, Msgs);
         if BP.May_Send_Done (Pool) then
            Put_File (W & "/base", R, False);
         end if;
         Event ("base", (if B.Faulted then "fault" elsif B.Reached then "reached" else "unreached"));
      end;
   end if;
   Ada.Command_Line.Set_Exit_Status (0);
end Wire_Gate_Main;
