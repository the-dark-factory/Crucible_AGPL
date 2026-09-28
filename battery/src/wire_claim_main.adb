--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 05db8df1b4d85966c617e441609299317ad50f0644a334c8c3b1cf2f14213a2b
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Message_Rules_Pkg;
with Lovelace_Outcome_Rules_Pkg;
with Lovelace_Definition_Stage_Pkg;

--  Wire_Claim_Main: one function's claim checks [check.go:226-262] as an assembly unit of the
--  Ada kit: `wire_claim_main <W> <i>`. A function with no Post is a definition (the
--  definition-stage core): definition true and T1, T2, T3 Unreached, nothing run. Otherwise
--  T1 (t1-stage, lemma-builder, the prover, Post_In at the lemma's mark; a derive error is
--  one error and T1 stays Unreached) and T2 (t2-stage: no variant is Failed; else the
--  prover and Post_In at the mark). Writes definition, t1, t2 to W/f<i>. Built-not-proved.
procedure Wire_Claim_Main is
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

   --  ---- per-function helpers (shared verbatim by the per-function units) ----
   package MR renames Lovelace_Message_Rules_Pkg;

   W       : constant String := (if Ada.Command_Line.Argument_Count >= 1 then Ada.Command_Line.Argument (1) else "");
   Subject : constant Natural := (if Ada.Command_Line.Argument_Count >= 2 then Number (Ada.Command_Line.Argument (2)) else 0);
   Run_Text   : constant String := Slurp (W & "/run");
   Head_Text  : constant String := Slurp (W & "/head");
   Table_Text : constant String := Slurp (W & "/table");
   Kit        : constant String := Value_Of (Run_Text, "kit");
   Pkg        : constant String := Value_Of (Head_Text, "package");

   procedure Event (Activity : String; Name : String; Detail : String) is
   begin
      Put_File (W & "/events", Activity & HT & Name & HT & Decimal (Subject) & HT & Detail & LF, True);
   end Event;

   --  One entry of the run's error list (rep.Errors): the count is what reaches the wire.
   procedure Log_Error (Text : String) is
   begin
      Put_File (W & "/log", Field ("error", Text), True);
   end Log_Error;

   --  The function's outcome file: fields appended, the last one of a key wins.
   procedure Put_Outcome (Key : String; Value : String) is
   begin
      Put_File (W & "/f" & Decimal (Subject), Field (Key, Value), True);
   end Put_Outcome;

   function Outcome_Of (Key : String) return Natural is
     (Number (Value_Of (Slurp (W & "/f" & Decimal (Subject)), Key)));

   --  The stage request for this function (the stage edges' shared input).
   function Stage_Request (Extra : String) return String is
     (Head_Text & Field ("subject", Decimal (Subject)) & Field ("extra", Extra) & Table_Text);

   --  Run a kit edge over one request file; its standard output, and its exit status in Code.
   function Edge_Output (Name : String; Request : String; Code : out Integer) return String is
      Output : U.Unbounded_String;
   begin
      Put_File (W & "/req", Request, False);
      Run (Kit & "/" & Name, (1 => +(W & "/req")), "", Output, Code);
      return U.To_String (Output);
   end Edge_Output;

   --  Prove one variant through the kit's prover exactly as check.go's prove closure does: a
   --  fault appends one error (tag: fault). The prover's printed result is returned.
   function Prove (Text : String; Tag : String) return String is
      Deps   : constant String := Value_Of (Run_Text, "deps");
      Names  : constant String := (if Deps = "" then "" else Slurp (W & "/deps"));
      N      : Natural := 0;
      Output : U.Unbounded_String;
      Code   : Integer;
   begin
      for C of Names loop
         if C = LF then
            N := N + 1;
         end if;
      end loop;
      Put_File (W & "/variant", Text, False);
      declare
         Args : Text_Array (1 .. (if Deps = "" then 3 else 4 + N));
         K    : Positive := 5;
         F    : Positive := Names'First;
      begin
         Args (1) := +(W & "/variant");
         Args (2) := +Pkg;
         Args (3) := +Tag;
         if Deps /= "" then
            Args (4) := +Deps;
            for I in Names'Range loop
               if Names (I) = LF then
                  Args (K) := +Names (F .. I - 1);
                  K := K + 1;
                  F := I + 1;
               end if;
            end loop;
         end if;
         Run (Kit & "/prover_main", Args, "", Output, Code);
      end;
      declare
         R     : constant String := U.To_String (Output);
         Fault : constant String := Value_Of_Line (R, "fault");
      begin
         if Code /= 0 then
            Log_Error (Tag & ": prover edge exit " & Decimal (Code));
            Event ("prover", Tag, "edge-fault");
            return "reached false" & LF & "fault prover edge" & LF;
         end if;
         if Fault /= "" then
            Log_Error (Tag & ": " & Fault);
         end if;
         Event ("prover", Tag, (if Fault = "" then "ran" else "fault"));
         return R;
      end;
   end Prove;

   function Reached_In (R : String) return Boolean is (Value_Of_Line (R, "reached") = "true");
   function Fault_In (R : String) return String is (Value_Of_Line (R, "fault"));

   function Msg_Count (R : String) return Natural is
      N : Natural := 0;
   begin
      for I in R'Range loop
         if (I = R'First or else R (I - 1) = LF) and then I + 3 <= R'Last and then R (I .. I + 3) = "msg " then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Msg_Count;

   --  The kept messages of a prover result as message-rules facts ("msg <line> <level> <text>").
   function Msgs_In (R : String) return MR.Message_Array is
      Msgs : MR.Message_Array (1 .. Msg_Count (R));
      K    : Natural := 0;
      I    : Positive := R'First;
   begin
      while I <= R'Last loop
         declare
            E : Natural := I;
         begin
            while E <= R'Last and then R (E) /= LF loop
               E := E + 1;
            end loop;
            if E - I > 4 and then R (I .. I + 3) = "msg " then
               declare
                  L    : constant String := R (I + 4 .. E - 1);
                  S1   : Natural := 0;
                  S2   : Natural := 0;
               begin
                  for J in L'Range loop
                     if L (J) = ' ' then
                        if S1 = 0 then
                           S1 := J;
                        elsif S2 = 0 then
                           S2 := J;
                        end if;
                     end if;
                  end loop;
                  if S2 > 0 then
                     declare
                        Lv   : constant String := L (S1 + 1 .. S2 - 1);
                        Txt  : constant String (1 .. L'Last - S2) := L (S2 + 1 .. L'Last);
                        Level : constant MR.Level_Kind :=
                          (if Lv = "info" then MR.Info_Level elsif Lv = "medium" then MR.Medium_Level
                           elsif Lv = "high" then MR.High_Level elsif Lv = "low" then MR.Low_Level
                           elsif Lv = "warning" then MR.Warning_Level else MR.Error_Level);
                     begin
                        K := K + 1;
                        Msgs (K) := MR.Facts_Of (Number (L (L'First .. S1 - 1)), Level, Txt);
                     end;
                  end if;
               end;
            end if;
            I := E + 1;
         end;
      end loop;
      return Msgs (1 .. K);
   end Msgs_In;

   --  Go's postIn over a line range of one prover result.
   function Post_In (R : String; From : Natural; To : Natural) return Natural is
      M : constant MR.Message_Array := Msgs_In (R);
      A : constant MR.Message_Array (1 .. M'Length) := M;
   begin
      return MR.Post_Outcome (Reached_In (R), A, A'Length, From, To);
   end Post_In;

   --  The example text gnatprove gave at Line ("eg <line> <text>"); Found False when none.
   function Example_At (R : String; Line : Natural; Found : out Boolean) return String is
      P : constant String := "eg " & Decimal (Line) & " ";
      I : Positive := R'First;
   begin
      Found := False;
      while I <= R'Last loop
         declare
            E : Natural := I;
         begin
            while E <= R'Last and then R (E) /= LF loop
               E := E + 1;
            end loop;
            if E - I >= P'Length and then R (I .. I + P'Length - 1) = P then
               Found := True;
               return R (I + P'Length .. E - 1);
            end if;
            I := E + 1;
         end;
      end loop;
      return "";
   end Example_At;

   --  Ask the verdict edge (worst|roll|grade): the answered digit, or -1 when the ask failed
   --  or the reply is not a digit 0..2 (the caller appends Go's error then).
   function Ask (Mode : String; Digits_List : Text_Array) return Integer is
      Args   : Text_Array (1 .. 2 + Digits_List'Length);
      Output : U.Unbounded_String;
      Code   : Integer;
   begin
      Args (1) := +Value_Of (Run_Text, "edge");
      Args (2) := +Mode;
      for K in Digits_List'Range loop
         Args (2 + K - Digits_List'First + 1) := Digits_List (K);
      end loop;
      Run (Kit & "/verdict_spawn_main", Args, "", Output, Code);
      declare
         A : constant String := Value_Of_Line (U.To_String (Output), "answer");
      begin
         Event ("verdict", Mode, A);
         if Code /= 0 or else A = "" or else A = "none" then
            return -1;
         end if;
         return Number (A);
      end;
   end Ask;

   --  worstOrErr (check.go:420-428): fold through the edge; a failed ask is an error and Unreached.
   function Worst (A : Natural; B : Natural) return Natural is
      O : constant Integer := Ask ("worst", (+Decimal (A), +Decimal (B)));
   begin
      if O < 0 then
         Log_Error ("edge worst: no answer");
         return 0;
      end if;
      return O;
   end Worst;

   --  ---- this unit ----
   --  Edge_Output with the field form made whole: GNAT.Expect.Get_Command_Output (Run) loses the
   --  line ends after the last visible character, so as many are put back as make the whole text
   --  well-formed fields again (no line end is ever put back into a text that is well formed).
   function Edge_Fields (Name : String; Request : String; Code : out Integer) return String is
      S : constant String := Edge_Output (Name, Request, Code);
   begin
      for N in 0 .. 8 loop
         declare
            T   : constant String := S & (1 .. N => LF);
            Pos : Positive := T'First;
            KF, KL, VF, VL : Natural;
            Ok  : Boolean := True;
         begin
            while Ok and then Pos <= T'Last loop
               Next_Field (T, Pos, KF, KL, VF, VL, Ok);
            end loop;
            if Ok then
               return T;
            end if;
         end;
      end loop;
      return S;
   end Edge_Fields;

   package OC renames Lovelace_Outcome_Rules_Pkg;
   package DS renames Lovelace_Definition_Stage_Pkg;

   --  The value of field Key in this function's record of the function table; "" when none.
   function Func_Value (Key : String) return String is
      T   : constant String := Table_Text;
      Pos : Positive := T'First;
      KF, KL, VF, VL : Natural;
      Ok  : Boolean;
      N   : Natural := 0;
   begin
      while Pos <= T'Last loop
         Next_Field (T, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         if T (KF .. KL) = "name" then
            N := N + 1;
         end if;
         if N = Subject and then T (KF .. KL) = Key then
            return T (VF .. VL);
         end if;
      end loop;
      return "";
   end Func_Value;

   --  A mark's line: the number after its last blank (Last) or after the blank before that.
   function Mark_Line (M : String; Last : Boolean) return Natural is
      S1 : Natural := 0;
      S2 : Natural := 0;
   begin
      for I in M'Range loop
         if M (I) = ' ' then
            S2 := S1;
            S1 := I;
         end if;
      end loop;
      if S1 = 0 then
         return 0;
      elsif Last then
         return Number (M (S1 + 1 .. M'Last));
      elsif S2 = 0 then
         return 0;
      end if;
      return Number (M (S2 + 1 .. S1 - 1));
   end Mark_Line;

   Name  : constant String := Func_Value ("name");
   Start : DS.Stage_Record;
   R     : DS.Stage_Record;
   T1    : Natural := OC.Unreached;
   T2    : Natural := OC.Unreached;
   Code  : Integer;
begin
   if W = "" or else Subject = 0 or else Name = "" then
      Ada.Command_Line.Set_Exit_Status (3);
      return;
   end if;
   --  definition-stage: no Post, nothing claimed; the fold of it is wire-grade's.
   R := DS.Definition_Step (Start, Func_Value ("post") /= "");
   if not DS.Later_Stage_Runs (R) then
      Put_Outcome ("definition", "true");
      Put_Outcome ("t1", Decimal (R.T1));
      Put_Outcome ("t2", Decimal (R.T2));
      Put_Outcome ("t3", Decimal (R.T3));
      Event ("claim", Name, "definition");
      Ada.Command_Line.Set_Exit_Status (0);
      return;
   end if;
   Put_Outcome ("definition", "false");

   --  T1: arbitrary result (deriveT1 = t1-stage + lemma-builder).
   declare
      Stage : constant String := Edge_Fields ("t1_stage_main", Stage_Request (""), Code);
   begin
      if Code /= 0 then
         Log_Error ("t1-" & Name & ": t1-stage edge exit " & Decimal (Code));
      else
         declare
            Built : constant String := Edge_Fields ("lemma_builder_main", Head_Text & Stage, Code);
            Fail  : constant String := Value_Of (Built, "failure");
            Line  : constant Natural := Mark_Line (Value_Of (Built, "mark"), True);
         begin
            if Code /= 0 then
               Log_Error ("t1-" & Name & ": lemma-builder edge exit " & Decimal (Code));
            elsif Fail /= "" then
               Log_Error (Fail);
            else
               T1 := Post_In (Prove (Value_Of (Built, "text"), Value_Of (Stage, "tag")), Line, Line);
            end if;
         end;
      end if;
   end;
   Put_Outcome ("t1", Decimal (T1));
   Event ("claim", "t1", Decimal (T1));

   --  T2: opaque callees; no callee is Failed, a derive error is an error and Unreached.
   declare
      Stage : constant String := Edge_Fields ("t2_stage_main", Stage_Request (""), Code);
      Mark  : constant String := Value_Of (Stage, "mark");
   begin
      if Code /= 0 then
         Log_Error ("t2-" & Name & ": t2-stage edge exit " & Decimal (Code));
         T2 := OC.Unreached;
      elsif Value_Of (Stage, "variants") = "0" then
         T2 := OC.Failed;
      else
         T2 := Post_In (Prove (Value_Of (Stage, "text"), Value_Of (Stage, "tag")),
                        Mark_Line (Mark, False), Mark_Line (Mark, True));
      end if;
   end;
   Put_Outcome ("t2", Decimal (T2));
   Event ("claim", "t2", Decimal (T2));
   Ada.Command_Line.Set_Exit_Status (0);
end Wire_Claim_Main;
