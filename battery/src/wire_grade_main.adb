--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 8d21f69a05e292ce073858d536580a59da6c28ca2d8970829f615b5d455288a3
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Message_Rules_Pkg;
with Lovelace_Grade_Stage_Pkg;
with Lovelace_Clean_Regrade_Stage_Pkg;
with Lovelace_Package_Folder_Pkg;

--  Wire_Grade_Main: one function's grade and its fold into the package [check.go:115-131 rollIn,
--  229-240 the definition branch, 355-392]: the grade asked of the verdict edge (grade-stage),
--  the clean regrade when a tool fault may have cost it (clean-regrade-stage), and the package
--  fold (package-folder), kept in W/fold. Built-not-proved.
procedure Wire_Grade_Main is
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

   --  ---- unit helpers ----
   package GS renames Lovelace_Grade_Stage_Pkg;
   package CR renames Lovelace_Clean_Regrade_Stage_Pkg;
   package PF renames Lovelace_Package_Folder_Pkg;
   use type PF.Refusal_Kind;

   Fold_Text : constant String := Slurp (W & "/fold");
   Is_Def    : constant Boolean := Value_Of (Slurp (W & "/f" & Decimal (Subject)), "definition") = "true";

   --  Field Key of function Subject in W/table ("" when absent): a "name" field opens a function.
   function Func_Field (Key : String) return String is
      Pos : Positive := Table_Text'First;
      KF, KL, VF, VL : Natural;
      Ok : Boolean;
      N  : Natural := 0;
   begin
      while Pos <= Table_Text'Last loop
         Next_Field (Table_Text, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         if Table_Text (KF .. KL) = "name" then
            N := N + 1;
         end if;
         if N = Subject and then Table_Text (KF .. KL) = Key then
            return Table_Text (VF .. VL);
         end if;
      end loop;
      return "";
   end Func_Field;

   function Grade_Digit (S : String) return Integer is
     (if S = "0" then 0 elsif S = "1" then 1 elsif S = "2" then 2 else -1);

   --  W/fold as the folder's state; absent, the initial state (grade unset, nothing counted).
   function Fold_Of return PF.Fold_State is
      S  : PF.Fold_State := PF.Initial_State;
      Rf : constant String := Value_Of (Fold_Text, "refusal");
   begin
      S.Grade := Grade_Digit (Value_Of (Fold_Text, "grade"));
      S.Graded := Number (Value_Of (Fold_Text, "graded"));
      S.Definitions := Number (Value_Of (Fold_Text, "definitions"));
      S.Refusal := (if Rf = "fold" then PF.Fold_Refused elsif Rf = "function" then PF.Function_Refused
                    else PF.No_Refusal);
      return S;
   end Fold_Of;

   procedure Put_Fold (S : PF.Fold_State) is
   begin
      Put_File (W & "/fold", Field ("grade", Decimal (S.Grade)) & Field ("graded", Decimal (S.Graded))
                & Field ("definitions", Decimal (S.Definitions))
                & Field ("refusal", (if S.Refusal = PF.Fold_Refused then "fold"
                                     elsif S.Refusal = PF.Function_Refused then "function" else "none")), False);
   end Put_Fold;

   --  The roll ask the folder needs; none while the accumulator is unset (the first grade sets it).
   function Roll_Of (S : PF.Fold_State; G : Natural) return PF.Roll_Answer is
      A : Integer;
   begin
      if not PF.Needs_Roll (S) then
         return (Answered => False, Digit => 0);
      end if;
      A := Ask ("roll", (+Decimal (S.Grade), +Decimal (G)));
      if A < 0 or else A > 2 then
         return (Answered => False, Digit => 0);
      end if;
      return (Answered => True, Digit => A);
   end Roll_Of;

   function Ask_Grade (Q : GS.Question) return GS.Edge_Answer is
      L : Text_Array (1 .. 8);
      A : Integer;
   begin
      for K in GS.Slot loop
         L (K) := +Decimal (Q (K));
      end loop;
      A := Ask ("grade", L);
      if A < 0 or else A > 2 then
         return (Answered => False, Digit => 0);
      end if;
      return (Answered => True, Digit => A);
   end Ask_Grade;

   Name : constant String := Func_Field ("name");
   S0   : constant PF.Fold_State := Fold_Of;
   S1   : PF.Fold_State;
   G    : GS.Grade_Value;
begin
   if Is_Def then
      --  A definition claims nothing: grade -1, counted, and rolled in as 0 (check.go:226-240).
      G := GS.Stage_Grade (True, (Answered => False, Digit => 0));
      S1 := PF.On_Definition (S0, Roll_Of (S0, 0));
   else
      declare
         C : constant GS.Checks :=
           (T0 => Outcome_Of ("t0"), RTE => Outcome_Of ("rte"), TB => Outcome_Of ("tb"), TC => Outcome_Of ("tc"),
            T1 => Outcome_Of ("t1"), T3 => Outcome_Of ("t3"), T4 => Outcome_Of ("t4"), T5 => Outcome_Of ("t5"));
         Q : constant GS.Question := GS.Grade_Question (C);
         A : constant GS.Edge_Answer := Ask_Grade (Q);
      begin
         G := GS.Stage_Grade (False, A);
         if GS.Errors_From (A) = 1 then
            Log_Error (Name & ": edge grade: no answer");
         end if;
         --  Did a tool fault cost the grade? The same question with T3 clean (check.go:365-383).
         if CR.Should_Reask (G, C.T3, Outcome_Of ("faults")) then
            if CR.Regrade_Of (G, Ask_Grade (CR.Clean_Question (Q))).Errors = 1 then
               Log_Error (Name & ": edge grade (clean): no answer");
            end if;
         end if;
         S1 := PF.On_Function (S0, G, (if G >= 0 then Roll_Of (S0, G) else (Answered => False, Digit => 0)));
      end;
   end if;
   if S1.Errors > S0.Errors then
      Log_Error ("edge roll: no answer");
   end if;
   Put_Fold (S1);
   Put_File (W & "/log", Field ("record", Name & " " & (if Is_Def then "1" else "0") & " " & Decimal (G)), True);
   Put_Outcome ("grade", Decimal (G));
   Ada.Command_Line.Set_Exit_Status (0);
end Wire_Grade_Main;
