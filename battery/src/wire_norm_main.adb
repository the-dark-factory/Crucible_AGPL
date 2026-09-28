--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: d5df38b5222d187c4dbd39c248fab3c2064ff4a0e322089ed43d61bc61c5368c
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Utf8_Decode_Pkg;
with Lovelace_Lex_Rules_Pkg;
with Lovelace_Text_Rules_Pkg;
with Lovelace_Claim_Screen_Pkg;

--  Wire_Norm_Main: T5's first half [check.go:323-333, normalise.go:405-427, 478-492]: the claim
--  (claim_former_main), its outer parentheses and forbidden words (claim-screen), its top-level
--  conjuncts (text-rules), each stripped (claim-screen); written to W/tmp-norm for
--  wire_norm_poly_main, which it then runs. Built-not-proved.
procedure Wire_Norm_Main is
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
   package LR renames Lovelace_Lex_Rules_Pkg;
   package TR renames Lovelace_Text_Rules_Pkg;
   package CS renames Lovelace_Claim_Screen_Pkg;
   use type CS.Bad_Word;

   NUL     : constant Character := Character'Val (0);
   W       : constant String := (if Ada.Command_Line.Argument_Count >= 1 then Ada.Command_Line.Argument (1) else "");
   Subject : constant Natural := (if Ada.Command_Line.Argument_Count >= 2 then Number (Ada.Command_Line.Argument (2)) else 0);
   Kit     : constant String := Value_Of (Slurp (W & "/run"), "kit");
   Table   : constant String := Slurp (W & "/table");

   --  Field Key of function Subject in W/table ("" when absent): a "name" field opens a function.
   function Func_Field (Key : String) return String is
      Pos : Positive := Table'First;
      KF, KL, VF, VL : Natural;
      Ok : Boolean;
      N  : Natural := 0;
   begin
      while Pos <= Table'Last loop
         Next_Field (Table, Pos, KF, KL, VF, VL, Ok);
         exit when not Ok;
         if Table (KF .. KL) = "name" then
            N := N + 1;
         end if;
         if N = Subject and then Table (KF .. KL) = Key then
            return Table (VF .. VL);
         end if;
      end loop;
      return "";
   end Func_Field;

   --  The lexical mask of T (indexed from 1), scanned from its first byte (lex-rules' walk).
   procedure Fill_Mask (T : String; M : out LR.Mask_Array) is
      Wd : LR.Width_Array (1 .. T'Length);
      S  : LR.Walk_State := LR.Initial_State;
   begin
      for I in 1 .. T'Length loop
         Wd (I) := Lovelace_Utf8_Decode_Pkg.Width_At (T, I);
      end loop;
      for K in 1 .. T'Length loop
         M (K) := LR.Class_In (T, Wd, K, S);
         S := LR.Next_State (T, Wd, K, S);
      end loop;
   end Fill_Mask;

   --  Go's TrimSpace then the outer-parenthesis strip loop, as claim-screen's Screened, over T.
   function Screened (T : String) return String is
      C : constant String (1 .. T'Length) := T;
      M : LR.Mask_Array (1 .. C'Length);
   begin
      Fill_Mask (C, M);
      declare
         R : constant CS.Claim_Range := CS.Screened (C, M);
      begin
         return C (R.First .. R.Last);
      end;
   end Screened;

   --  The conjunct fields of a normalisable claim C (indexed from 1), or the one field
   --  "screen failed" when claim-screen finds a forbidden word in the stripped claim.
   function Conjuncts (C : String) return String is
      M : LR.Mask_Array (1 .. C'Length);
      R : CS.Claim_Range;
      Out_Text : U.Unbounded_String;
   begin
      Fill_Mask (C, M);
      R := CS.Screened (C, M);
      if CS.First_Bad (C, R.First, R.Last) /= CS.No_Bad_Word then
         return Field ("screen", "failed");
      end if;
      declare
         S  : constant String (1 .. R.Last - R.First + 1) := C (R.First .. R.Last);
         P0 : constant TR.Piece := TR.Trim (S, 1, S'Length);
         T  : constant String (1 .. P0.Last - P0.First + 1) := S (P0.First .. P0.Last);
         MT : LR.Mask_Array (1 .. T'Length);
      begin
         Fill_Mask (T, MT);
         for N in 1 .. TR.Conjunct_Count (T, MT) loop
            declare
               P : constant TR.Piece := TR.Conjunct_Bounds (T, MT, N);
            begin
               U.Append (Out_Text, Field ("conj", Screened (T (P.First .. P.Last))));
            end;
         end loop;
      end;
      return U.To_String (Out_Text);
   end Conjuncts;

   Output : U.Unbounded_String;
   Code   : Integer;
begin
   --  A definition has no T5 (check.go:226-240 continues before it).
   if Value_Of (Slurp (W & "/f" & Decimal (Subject)), "definition") = "true" then
      Ada.Command_Line.Set_Exit_Status (0);
      return;
   end if;
   --  claimOf through claim_former_main: "settled" (no claim) or "claim <n>" LF <n bytes> LF.
   Put_File (W & "/req", Func_Field ("name") & NUL & Func_Field ("boolean") & NUL & Func_Field ("post")
             & NUL & Func_Field ("body"), False);
   Run (Kit & "/claim_former_main", (1 => +(W & "/req")), "", Output, Code);
   if Code /= 0 then
      Ada.Command_Line.Set_Exit_Status (3);
      return;
   end if;
   declare
      R  : constant String := U.To_String (Output);
      Nl : Natural := 0;
   begin
      for I in R'Range loop
         if R (I) = LF then
            Nl := I;
            exit;
         end if;
      end loop;
      if Nl > R'First + 6 and then R (R'First .. R'First + 5) = "claim " then
         declare
            N : constant Natural := Number (R (R'First + 6 .. Nl - 1));
         begin
            declare
               --  Run's output has lost its trailing line ends: a claim that ends in LF is restored.
               Got : constant String := R (Nl + 1 .. Natural'Min (R'Last, Nl + N));
               C   : constant String (1 .. N) := Got & (1 .. N - Got'Length => LF);
            begin
               Put_File (W & "/tmp-norm", Conjuncts (C), False);
            end;
         end;
      else
         Put_File (W & "/tmp-norm", Field ("screen", "failed"), False);
      end if;
   end;
   Put_File (W & "/events", "norm" & HT & "claim" & HT & Decimal (Subject) & HT & "screened" & LF, True);
   --  The residuals and T5 itself: wire_norm_poly_main (it writes t5 to W/f<i>).
   Run (Kit & "/wire_norm_poly_main", (+W, +Decimal (Subject)), "", Output, Code);
   Ada.Command_Line.Set_Exit_Status (if Code = 0 then 0 else 3);
end Wire_Norm_Main;
