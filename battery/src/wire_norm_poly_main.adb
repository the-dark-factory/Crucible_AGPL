--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: c4937c247551a9cd059fd4e2c6cc58d9a418a4f79774e743d8e00d6aae8e6e01
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Poly_Arith_Pkg;
with Lovelace_Relation_Splitter_Pkg;
with Lovelace_Residual_Classifier_Pkg;

--  Wire_Norm_Poly_Main: T5's second half [check.go:323-353, normalise.go:398-442]: each conjunct
--  of W/tmp-norm split at its relation (relation-splitter), both sides normalised by
--  poly_parser_main over the package's function table, each residual read back into a
--  poly-arith Poly and classified (residual-classifier), which also decides T5. Built-not-proved.
procedure Wire_Norm_Poly_Main is
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

   --  ---- unit helpers ----
   package PA renames Lovelace_Poly_Arith_Pkg;
   package RS renames Lovelace_Relation_Splitter_Pkg;
   package RC renames Lovelace_Residual_Classifier_Pkg;
   use type RS.Rel_Op;

   NUL     : constant Character := Character'Val (0);
   W       : constant String := (if Ada.Command_Line.Argument_Count >= 1 then Ada.Command_Line.Argument (1) else "");
   Subject : constant Natural := (if Ada.Command_Line.Argument_Count >= 2 then Number (Ada.Command_Line.Argument (2)) else 0);
   Kit     : constant String := Value_Of (Slurp (W & "/run"), "kit");
   Table   : constant String := Slurp (W & "/table");

   --  poly_parser_main's function table from W/table: the count, then per function name,
   --  boolean, body, the parameter count and the parameter names, every field after a NUL.
   function Func_Table return String is
      Pos : Positive := Table'First;
      KF, KL, VF, VL : Natural;
      Ok : Boolean;
      N  : Natural := 0;
      P  : Natural := 0;
      Out_Text, Name, Bool, Body_T, Names : U.Unbounded_String;
      procedure Flush is
      begin
         if N > 0 then
            U.Append (Out_Text, NUL & U.To_String (Name) & NUL & U.To_String (Bool) & NUL & U.To_String (Body_T)
                    & NUL & Decimal (P) & U.To_String (Names));
         end if;
      end Flush;
   begin
      while Pos <= Table'Last loop
         Next_Field (Table, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         declare
            K : constant String := Table (KF .. KL);
            V : constant String := Table (VF .. VL);
         begin
            if K = "name" then
               Flush;
               N := N + 1;
               P := 0;
               Name := +V;
               Bool := U.Null_Unbounded_String;
               Body_T := U.Null_Unbounded_String;
               Names := U.Null_Unbounded_String;
            elsif K = "boolean" then
               Bool := +V;
            elsif K = "body" then
               Body_T := +V;
            elsif K = "pname" then
               P := P + 1;
               U.Append (Names, NUL & V);
            end if;
         end;
      end loop;
      Flush;
      return Decimal (N) & U.To_String (Out_Text);
   end Func_Table;

   function Op_Text (Op : RS.Rel_Op) return String is
     (case Op is
         when RS.Op_Ne => RS.Ne_Text, when RS.Op_Le => RS.Le_Text, when RS.Op_Ge => RS.Ge_Text,
         when RS.Op_Eq => RS.Eq_Text, when RS.Op_Lt => RS.Lt_Text, when RS.Op_Gt => RS.Gt_Text,
         when RS.No_Op => "");

   --  One term of Go's poly text ("-3*X*F(Y + 1)", "7", "A'Last") into a poly-arith Term: its
   --  atoms are the '*'-separated pieces at parenthesis depth 0, less a leading decimal
   --  coefficient. The coefficient itself is never read by the classifier; 1 stands for it.
   procedure Add_Term (R : in out PA.Poly; T : String) is
      K : PA.Key := PA.Empty_Key;
      A : PA.Atom;
      D : Integer := 0;
      F : Positive := T'First;
   begin
      while F <= T'Last and then T (F) = '-' loop
         F := F + 1;
      end loop;
      for J in F .. T'Last + 1 loop
         if J > T'Last or else (D = 0 and then T (J) = '*') then
            declare
               Piece  : constant String := T (F .. J - 1);
               Digits_Only : Boolean := True;
            begin
               for C of Piece loop
                  if C not in '0' .. '9' then
                     Digits_Only := False;
                  end if;
               end loop;
               if not Digits_Only and then Piece'Length <= PA.Max_Atom_Length and then K.Count < PA.Max_Degree then
                  A := PA.Empty_Atom;
                  A.Length := Piece'Length;
                  A.Text (1 .. Piece'Length) := Piece;
                  K := PA.Insert_Atom (K, A);
               end if;
            end;
            F := J + 1;
         elsif T (J) = '(' then
            D := D + 1;
         elsif T (J) = ')' then
            D := D - 1;
         end if;
      end loop;
      if R.Count < PA.Max_Terms then
         R := PA.Append_Term (R, (K => K, Coefficient => 1));
      end if;
   end Add_Term;

   --  Go's poly text back into a Poly: terms are split at " + " / " - " at parenthesis depth 0
   --  (an opaque atom's own text is always parenthesised). "0" is the empty poly's text and
   --  reads back as one constant term: both are constant to the classifier.
   function To_Poly (P : String) return PA.Poly is
      R : PA.Poly := PA.Empty_Poly;
      D : Integer := 0;
      S : Positive := P'First;
      I : Positive := P'First;
   begin
      while I <= P'Last loop
         if P (I) = '(' then
            D := D + 1;
         elsif P (I) = ')' then
            D := D - 1;
         elsif D = 0 and then I + 2 <= P'Last and then P (I) = ' ' and then P (I + 2) = ' '
           and then (P (I + 1) = '+' or else P (I + 1) = '-')
         then
            Add_Term (R, P (S .. I - 1));
            S := I + 3;
            I := I + 2;
         end if;
         I := I + 1;
      end loop;
      Add_Term (R, P (S .. P'Last));
      return R;
   end To_Poly;

   --  The poly text of a "residual <poly> <op> 0" line.
   function Residual_Poly (L : String) return String is
      E : Natural := L'Last - 2;
   begin
      while E > L'First + 8 and then L (E) /= ' ' loop
         E := E - 1;
      end loop;
      return L (L'First + 9 .. E - 1);
   end Residual_Poly;

   Output : U.Unbounded_String;
   Code   : Integer;
begin
   if Value_Of (Slurp (W & "/f" & Decimal (Subject)), "definition") = "true" then
      Ada.Command_Line.Set_Exit_Status (0);
      return;
   end if;
   declare
      Tmp        : constant String := Slurp (W & "/tmp-norm");
      Normalised : Boolean := Tmp'Length > 0 and then Value_Of (Tmp, "screen") /= "failed";
      Conj       : U.Unbounded_String;
      NC         : Natural := 0;
      Pos        : Positive := Tmp'First;
      KF, KL, VF, VL : Natural;
      Ok         : Boolean;
      Rs_Count   : Natural := 0;
   begin
      --  splitRelation per conjunct: none is "no single relational operator" (not normalisable).
      while Normalised and then Pos <= Tmp'Last loop
         Next_Field (Tmp, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         if Tmp (KF .. KL) = "conj" then
            declare
               C   : constant String (1 .. VL - VF + 1) := Tmp (VF .. VL);
               Rel : constant RS.Relation := RS.Split_Relation (C, 1, C'Length);
            begin
               if Rel.Op = RS.No_Op then
                  Normalised := False;
               else
                  NC := NC + 1;
                  U.Append (Conj, NUL & Op_Text (Rel.Op) & NUL & C (Rel.Lhs_First .. Rel.Lhs_Last)
                            & NUL & C (Rel.Rhs_First .. Rel.Rhs_Last));
               end if;
            end;
         end if;
      end loop;
      --  Both sides of every relation through poly_parser_main: "settled ..." is not normalisable.
      if Normalised then
         Put_File (W & "/req", Func_Table & NUL & Decimal (NC) & U.To_String (Conj), False);
         Run (Kit & "/poly_parser_main", (1 => +(W & "/req")), "", Output, Code);
         if Code /= 0 then
            Ada.Command_Line.Set_Exit_Status (3);
            return;
         end if;
         declare
            R : constant String := U.To_String (Output);
         begin
            for I in R'Range loop
               if (I = R'First or else R (I - 1) = LF) and then I + 8 <= R'Last and then R (I .. I + 8) = "residual " then
                  Rs_Count := Rs_Count + 1;
               end if;
            end loop;
            Normalised := Rs_Count > 0;
         end;
      end if;
      declare
         R       : constant String := U.To_String (Output);
         Classes : RC.Class_Array (1 .. (if Normalised then Rs_Count else 0)) := (others => RC.Genuine_Residual);
         K       : Natural := 0;
         I       : Positive := R'First;
      begin
         while Normalised and then I <= R'Last loop
            declare
               E : Natural := I;
            begin
               while E <= R'Last and then R (E) /= LF loop
                  E := E + 1;
               end loop;
               if E - I > 9 and then R (I .. I + 8) = "residual " and then K < Classes'Last then
                  K := K + 1;
                  Classes (K) := RC.Classify (To_Poly (Residual_Poly (R (I .. E - 1))));
               end if;
               I := E + 1;
            end;
         end loop;
         Put_File (W & "/f" & Decimal (Subject), Field ("t5", Decimal (RC.T5_Of (Normalised, Classes))), True);
         Put_File (W & "/events", "norm" & HT & "t5" & HT & Decimal (Subject) & HT
                   & Decimal (Rs_Count) & " residuals" & LF, True);
      end;
   end;
   Ada.Command_Line.Set_Exit_Status (0);
end Wire_Norm_Poly_Main;
