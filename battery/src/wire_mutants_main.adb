--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 178c066411a7415b3cc2ed4398285f499da7a2368a4445deb84334ecde9a6edf
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Message_Rules_Pkg;
with Lovelace_Outcome_Rules_Pkg;
with Lovelace_Rte_Stage_Pkg;
with Lovelace_Run_Config_Pkg;

--  Wire_Mutants_Main: one function's T3 and T6 [check.go:264-321] as an assembly unit of the
--  Ada kit: `wire_mutants_main <W> <i>` (a definition exits 0 at once). T3: the mutant bodies
--  of t3-mutant-conjuncts and t3-mutant-edits rendered by t3-mutant-render (for a predicate,
--  the one variant of t3-callee-stage instead); each withheld mutant is a tool fault, an error
--  and Unreached folded; each variant is proved, read at its mark, judged by outcome-rules'
--  Mutant_Outcome with message-rules' Any_Fail_In over the function's line span, and folded
--  through the verdict edge's worst from Failed. T6: t6-pre then t6-sub, each variant proved
--  (only prover faults count). Writes t3 and faults to W/f<i>. Built-not-proved.
procedure Wire_Mutants_Main is
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
   package RS renames Lovelace_Rte_Stage_Pkg;
   Cap : constant String := Decimal (Lovelace_Run_Config_Pkg.Max_Mutants);

   --  Where this function's record of the function table starts and ends (0 .. 0 when absent).
   procedure Func_Record (First : out Natural; Last : out Natural) is
      T   : String renames Table_Text;
      Pos : Positive := T'First;
      At_Start : Positive;
      KF, KL, VF, VL : Natural;
      Ok  : Boolean;
      N   : Natural := 0;
   begin
      First := 0;
      Last := 0;
      while Pos <= T'Last loop
         At_Start := Pos;
         Next_Field (T, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         if T (KF .. KL) = "name" then
            N := N + 1;
            if N = Subject then
               First := At_Start;
            elsif N = Subject + 1 then
               exit;
            end if;
         end if;
         if N = Subject then
            Last := Pos - 1;
         end if;
      end loop;
   end Func_Record;

   --  The fields of T from the one named Key to the end (Key's own field included when Keep).
   function From_Field (T : String; Key : String; Keep : Boolean) return String is
      Pos : Positive := T'First;
      At_Start : Positive;
      KF, KL, VF, VL : Natural;
      Ok  : Boolean;
   begin
      while Pos <= T'Last loop
         At_Start := Pos;
         Next_Field (T, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         if T (KF .. KL) = Key then
            return T ((if Keep then At_Start else Pos) .. T'Last);
         end if;
      end loop;
      return "";
   end From_Field;

   --  The value of the K-th field named Key in T; "" when there are fewer.
   function Nth_Value (T : String; Key : String; K : Positive) return String is
      Pos : Positive := T'First;
      KF, KL, VF, VL : Natural;
      Ok  : Boolean;
      N   : Natural := 0;
   begin
      while Pos <= T'Last loop
         Next_Field (T, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         if T (KF .. KL) = Key then
            N := N + 1;
            if N = K then
               return T (VF .. VL);
            end if;
         end if;
      end loop;
      return "";
   end Nth_Value;

   --  The K-th blank-separated number of S (a mark's or a lines field's); 0 when none.
   function Nth_Number (S : String; K : Positive) return Natural is
      N : Natural := 1;
      F : Positive := S'First;
   begin
      for I in S'First .. S'Last + 1 loop
         if I > S'Last or else S (I) = ' ' then
            if N = K then
               return Number (S (F .. I - 1));
            end if;
            N := N + 1;
            F := I + 1;
         end if;
      end loop;
      return 0;
   end Nth_Number;

   RF, RL : Natural;
   T3     : Natural := OC.Failed;
   Faults : Natural := 0;
   Code   : Integer;
begin
   if W = "" or else Subject = 0 then
      Ada.Command_Line.Set_Exit_Status (3);
      return;
   end if;
   if Value_Of (Slurp (W & "/f" & Decimal (Subject)), "definition") = "true" then
      Ada.Command_Line.Set_Exit_Status (0);
      return;
   end if;
   Func_Record (RF, RL);
   if RF = 0 then
      Ada.Command_Line.Set_Exit_Status (3);
      return;
   end if;
   declare
      Rec   : constant String := Table_Text (RF .. RL);
      Name  : constant String := Value_Of (Rec, "name");
      Lines : constant String := Value_Of (Rec, "lines");
      Span  : constant RS.Line_Span := RS.Function_Span
        (Nth_Number (Lines, 1), Nth_Number (Lines, 2), Nth_Number (Lines, 3), Nth_Number (Lines, 4));
      Conj  : constant String := Edge_Fields ("t3_mutant_conjuncts_main", Stage_Request (Cap), Code);
      C1    : constant Integer := Code;
      Edits : constant String := Edge_Fields ("t3_mutant_edits_main", Stage_Request (Cap), Code);
      C2    : constant Integer := Code;
      Pred  : constant Boolean := Value_Of (Edits, "predicate") = "true";
      Render : constant String :=
        Field ("text", Value_Of (Head_Text, "text")) & Field ("name", Name) & Field ("ret", Value_Of (Rec, "ret"))
        & Field ("combined", Value_Of (Rec, "combined")) & Field ("lines", Lines) & From_Field (Rec, "params", True)
        & Field ("cap", Cap)
        & Field ("mutants", Decimal (Number (Value_Of (Conj, "mutants")) + Number (Value_Of (Edits, "mutants"))))
        & From_Field (Conj, "mutants", False) & From_Field (Edits, "mutants", False);
      Got   : constant String :=
        (if C1 /= 0 or else C2 /= 0 then ""
         elsif Pred then Edge_Fields ("t3_callee_stage_main", Stage_Request (Cap), Code)
         else Edge_Fields ("t3_mutant_render_main", Render, Code));
      Kept  : constant Natural := Number (Value_Of (Got, "variants"));
      Held  : constant Natural := Number (Value_Of (Got, "withheld"));
   begin
      --  T3: a stage edge that fails is this battery's fault, folded as a withheld mutant is.
      if C1 /= 0 or else C2 /= 0 or else Code /= 0 then
         Faults := Faults + 1;
         Log_Error ("t3-" & Name & ": a T3 stage edge failed");
         T3 := Worst (T3, OC.Unreached);
      end if;
      for K in 1 .. Held loop
         Faults := Faults + 1;
         Log_Error (Nth_Value (Got, "tag", Kept + K) & " was not run: the mutator wrote an ill-formed literal");
         T3 := Worst (T3, OC.Unreached);
      end loop;
      for K in 1 .. Kept loop
         declare
            Mark : constant String := Nth_Value (Got, "mark", K);
            Res  : constant String := Prove (Nth_Value (Got, "text", K), Nth_Value (Got, "tag", K));
            M    : constant MR.Message_Array := Msgs_In (Res);
            A    : constant MR.Message_Array (1 .. M'Length) := M;
         begin
            if Fault_In (Res) /= "" then
               Faults := Faults + 1;
            end if;
            T3 := Worst (T3, OC.Mutant_Outcome
              (Post_In (Res, Nth_Number (Mark, 2), Nth_Number (Mark, 3)),
               MR.Any_Fail_In (A, A'Length, Span.From, Span.To)));
         end;
      end loop;
      Put_Outcome ("t3", Decimal (T3));
      Put_Outcome ("faults", Decimal (Faults));
      Event ("mutants", Name, Decimal (T3));
   end;

   --  T6: precondition necessity and subtype widening; proved, never graded.
   declare
      Pre : constant String := Edge_Fields ("t6_pre_main", Stage_Request (""), Code);
      C1  : constant Integer := Code;
      Sub : constant String := (if C1 /= 0 then "" else Edge_Fields ("t6_sub_main", Stage_Request ("") & Pre, Code));
   begin
      if C1 /= 0 or else Code /= 0 then
         Log_Error ("t6: a T6 stage edge failed");
      else
         for K in 1 .. Number (Value_Of (Sub, "variants")) loop
            declare
               Res : constant String := Prove (Nth_Value (Sub, "text", K), Nth_Value (Sub, "tag", K));
            begin
               null;
            end;
         end loop;
      end if;
      Event ("necessity", "t6", Value_Of (Sub, "variants"));
   end;
   Ada.Command_Line.Set_Exit_Status (0);
end Wire_Mutants_Main;
