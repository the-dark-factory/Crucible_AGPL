--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 6406e560b4f094156336b8a6b40dc5f51ac1ad4d4dc11813db9929f13b98af7b
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Message_Rules_Pkg;
with Lovelace_Outcome_Rules_Pkg;
with Lovelace_Rte_Stage_Pkg;
with Lovelace_T4_Stage_Pkg;

--  Wire_Domain_Main: RTE, T0, T4, TB and TC of one function of the vacuity battery
--  [check.go:135-225], as one assembly unit of the Ada kit. `wire_domain_main <W> <i>`.
--  Built-not-proved: every decision is a proven core's; this unit reads, spawns and writes.
procedure Wire_Domain_Main is
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

   --  ---- the domain unit ----
   package OR_Rules renames Lovelace_Outcome_Rules_Pkg;
   package RS renames Lovelace_Rte_Stage_Pkg;
   package T4S renames Lovelace_T4_Stage_Pkg;
   use type OR_Rules.TC_Case;

   Text     : constant String := Value_Of (Head_Text, "text");
   Internal : Boolean := False;

   --  The value of Key in the subject's own entry of the function table; "" when none.
   function Func_Field (Key : String) return String is
      Pos : Positive := Table_Text'First;
      KF, KL, VF, VL : Natural;
      Ok  : Boolean;
      K   : Natural := 0;
   begin
      while Pos <= Table_Text'Last loop
         Next_Field (Table_Text, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         if Table_Text (KF .. KL) = "name" then
            K := K + 1;
         end if;
         if K = Subject and then Table_Text (KF .. KL) = Key then
            return Table_Text (VF .. VL);
         end if;
      end loop;
      return "";
   end Func_Field;

   --  Every function's Pre and Post, each ended by LF: the texts neverAsserted searches (derive.go:352-364).
   function Contracts return String is
      Pos : Positive := Table_Text'First;
      KF, KL, VF, VL : Natural;
      Ok  : Boolean;
      R   : U.Unbounded_String;
   begin
      while Pos <= Table_Text'Last loop
         Next_Field (Table_Text, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         if Table_Text (KF .. KL) = "pre" or else Table_Text (KF .. KL) = "post" then
            U.Append (R, Table_Text (VF .. VL) & LF);
         end if;
      end loop;
      return U.To_String (R);
   end Contracts;

   --  Get_Command_Output keeps none of the child's trailing line ends, and a field-form output
   --  ends in one or more (an empty or LF-ended last value): add them back until every field
   --  is whole; the byte lengths make the answer unique.
   function Whole (T : String) return String is
   begin
      if T'Length = 0 then
         return T;
      end if;
      for N in 1 .. 3 loop
         declare
            C   : constant String := T & (1 .. N => LF);
            Pos : Positive := C'First;
            KF, KL, VF, VL : Natural;
            Ok  : Boolean := True;
         begin
            while Ok and then Pos <= C'Last loop
               Next_Field (C, Pos, KF, KL, VF, VL, Ok);
            end loop;
            if Ok then
               return C;
            end if;
         end;
      end loop;
      return T & LF;
   end Whole;

   --  A stage edge over this function's request; an edge that exits non-zero is an internal fault.
   function Stage (Exe : String; Extra : String) return String is
      Code : Integer;
      R    : constant String := Whole (Edge_Output (Exe, Stage_Request (Extra), Code));
   begin
      if Code /= 0 then
         Internal := True;
      end if;
      return R;
   end Stage;

   --  lemma-builder over a lemma stage's output: the variant text and its marks, or a failure field.
   function Build (Stage_Out : String) return String is
      Code : Integer;
      R    : constant String := Whole (Edge_Output ("lemma_builder_main", Field ("package", Pkg) & Field ("text", Text) & Stage_Out, Code));
   begin
      if Code /= 0 then
         Internal := True;
      end if;
      return R;
   end Build;

   --  The line of a mark value "<key> <line>".
   function Mark_Line (V : String) return Natural is
   begin
      for I in reverse V'Range loop
         if V (I) = ' ' then
            return Number (V (I + 1 .. V'Last));
         end if;
      end loop;
      return 0;
   end Mark_Line;

   --  Fold the Post outcome at every mark of Built through the edge's worst, from Start.
   function Fold_Marks (Built : String; R : String; Start : Natural) return Natural is
      Pos : Positive := Built'First;
      KF, KL, VF, VL : Natural;
      Ok  : Boolean;
      Acc : Natural := Start;
   begin
      while Pos <= Built'Last loop
         Next_Field (Built, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         if Built (KF .. KL) = "mark" then
            declare
               L : constant Natural := Mark_Line (Built (VF .. VL));
            begin
               Acc := Worst (Acc, Post_In (R, L, L));
            end;
         end if;
      end loop;
      return Acc;
   end Fold_Marks;

   N_Funcs : constant Natural := Number (Value_Of (Table_Text, "count"));
   Nums    : array (1 .. 4) of Natural := (others => 0);
   T0      : Natural := OR_Rules.Unreached;
   TB      : Natural := OR_Rules.Failed;
   TC      : Natural;
   Witness : U.Unbounded_String;
begin
   if W = "" or else Kit = "" or else Subject = 0 or else Subject > N_Funcs then
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      L : constant String := Func_Field ("lines");
      K : Positive := 1;
      F : Positive := L'First;
   begin
      for I in L'Range loop
         if L (I) = ' ' or else I = L'Last then
            if K <= 4 then
               Nums (K) := Number (L (F .. (if L (I) = ' ' then I - 1 else I)));
            end if;
            K := K + 1;
            F := I + 1;
         end if;
      end loop;
   end;
   declare
      Name     : constant String := Func_Field ("name");
      Pre      : constant String := Func_Field ("pre");
      Post     : constant String := Func_Field ("post");
      S        : constant RS.Line_Span := RS.Function_Span (Nums (1), Nums (2), Nums (3), Nums (4));
      Base     : constant String := Slurp (W & "/base");
      M0       : constant MR.Message_Array := Msgs_In (Base);
      M        : constant MR.Message_Array (1 .. M0'Length) := M0;
      Reached  : constant Boolean := Reached_In (Base);
      All_Pp   : constant String := Contracts;
      Cs       : constant String (1 .. All_Pp'Length) := All_Pp;
      Never    : constant Boolean := T4S.Never_Asserted (Func_Field ("boolean") = "true", Post /= "", Name, Cs);
      Derive_Failed : Boolean := False;
      Lemmas_Formed : Boolean := False;
      Witnessed     : Boolean := False;
      C_Built       : U.Unbounded_String;
      C_Tag         : U.Unbounded_String;
   begin
      --  RTE from the base run (rte-stage).
      Put_Outcome ("rte", Decimal (RS.RTE_Of (Reached, M, M'Length, S)));
      --  T0: t0-stage, lemma-builder (a failure is Go's derive error), prover, the Post at the mark.
      declare
         Out0  : constant String := Stage ("t0_stage_main", "");
         Built : constant String := (if Internal then "" else Build (Out0));
         Found : Boolean;
      begin
         if Internal then
            Ada.Command_Line.Set_Exit_Status (2);
            return;
         end if;
         if Value_Of (Built, "failure") /= "" then
            Log_Error (Value_Of (Built, "failure"));
         else
            declare
               R  : constant String := Prove (Value_Of (Built, "text"), Value_Of (Out0, "tag"));
               Ln : constant Natural := Mark_Line (Value_Of (Built, "mark"));
               Eg : constant String := Example_At (R, Ln, Found);
            begin
               T0 := Post_In (R, Ln, Ln);
               if Found then
                  Witness := +Eg;
               end if;
            end;
         end if;
      end;
      Put_Outcome ("t0", Decimal (T0));
      Put_Outcome ("witness", U.To_String (Witness));
      --  T4 from the base run and neverAsserted (t4-stage).
      Put_Outcome ("t4", Decimal (T4S.T4_For (Reached, M, M'Length, S, Never)));
      --  TB: start Failed; with guards, lemma-builder, prover, every mark folded through worst.
      declare
         OutB : constant String := Stage ("tb_stage_main", "");
      begin
         if Internal then
            Ada.Command_Line.Set_Exit_Status (2);
            return;
         end if;
         if Number (Value_Of (OutB, "lemmas")) > 0 then
            declare
               Built : constant String := Build (OutB);
            begin
               if Internal then
                  Ada.Command_Line.Set_Exit_Status (2);
                  return;
               end if;
               if Value_Of (Built, "failure") /= "" then
                  Log_Error (Value_Of (Built, "failure"));
                  TB := OR_Rules.Unreached;
               else
                  TB := Fold_Marks (Built, Prove (Value_Of (Built, "text"), Value_Of (OutB, "tag")), TB);
               end if;
            end;
         end if;
      end;
      Put_Outcome ("tb", Decimal (TB));
      --  TC: derived only when there is a Pre and T0 failed; outcome-rules names the case.
      if Pre /= "" and then T0 = OR_Rules.Failed then
         declare
            OutC : constant String := Stage ("tc_stage_main", U.To_String (Witness));
         begin
            if Internal then
               Ada.Command_Line.Set_Exit_Status (2);
               return;
            end if;
            Lemmas_Formed := Number (Value_Of (OutC, "lemmas")) > 0;
            Witnessed := Number (Value_Of (OutC, "witnessed")) > 0;
            C_Tag := +Value_Of (OutC, "tag");
            if Lemmas_Formed then
               C_Built := +Build (OutC);
               if Internal then
                  Ada.Command_Line.Set_Exit_Status (2);
                  return;
               end if;
               if Value_Of (U.To_String (C_Built), "failure") /= "" then
                  Derive_Failed := True;
                  Log_Error (Value_Of (U.To_String (C_Built), "failure"));
               end if;
            end if;
         end;
      end if;
      declare
         Case_Of : constant OR_Rules.TC_Case := OR_Rules.TC_Case_Of
           ((Has_Pre => Pre /= "", T0 => T0, Derive_Failed => Derive_Failed, Lemmas_Formed => Lemmas_Formed,
             Witness_Present => Witnessed, Has_Body => Func_Field ("body") /= ""));
         Built : constant String := U.To_String (C_Built);
      begin
         TC := OR_Rules.TC_Initial (Case_Of);
         if Case_Of = OR_Rules.Posed then
            TC := Fold_Marks (Built, Prove (Value_Of (Built, "text"), U.To_String (C_Tag)), TC);
         end if;
         Event ("domain", Name, OR_Rules.TC_Case'Image (Case_Of));
      end;
      Put_Outcome ("tc", Decimal (TC));
   end;
   Ada.Command_Line.Set_Exit_Status (0);
end Wire_Domain_Main;
