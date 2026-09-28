--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 5edfdb80d7c7bcb27ae59db8038ea3d4939d2d239fa8269870bc2d10d9bf129c
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Report_Ledger_Pkg;
with Lovelace_Wire_Tallier_Pkg;
with Lovelace_Wire_Line_Builder_Pkg;
with Lovelace_Grade_Line_Builder_Pkg;
with Lovelace_Package_Folder_Pkg;

--  Wire_Close_Main: the close and the emit of the wire [check.go:394-417, wire.go:15-59]. It
--  folds the work dir's log into the report ledger, then writes Go's one flat JSON line and the
--  grade lines on standard output -- the only unit of the kit that does. Built-not-proved.
procedure Wire_Close_Main is
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

   package RL renames Lovelace_Report_Ledger_Pkg;
   package WT renames Lovelace_Wire_Tallier_Pkg;
   package WL renames Lovelace_Wire_Line_Builder_Pkg;
   package GL renames Lovelace_Grade_Line_Builder_Pkg;
   package PF renames Lovelace_Package_Folder_Pkg;

   W : constant String := (if Ada.Command_Line.Argument_Count >= 1 then Ada.Command_Line.Argument (1) else "");

   --  Go's strconv.Quote of a text that is not go-quote's (non-ASCII or over 8192 bytes: the em dash
   --  refusal, a non-ASCII path), by the kit's go-quote-wide edge.
   function Wide_Quoted (Text : String) return String is
      Output : U.Unbounded_String;
      Code   : Integer;
   begin
      Put_File (W & "/word", Text, False);
      Run (Value_Of (Slurp (W & "/run"), "kit") & "/go_quote_wide_main", (1 => +(W & "/word")), "", Output, Code);
      return U.To_String (Output);
   end Wide_Quoted;

   procedure Emit (Text : String) is
      Line : constant String := Text & LF;
      N    : Integer;
   begin
      N := GNAT.OS_Lib.Write (GNAT.OS_Lib.Standout, Line (Line'First)'Address, Line'Length);
   end Emit;

   --  Integer value of a decimal text that may start with '-'.
   function Signed (S : String) return Integer is
     (if S'Length > 1 and then S (S'First) = '-' then -Number (S (S'First + 1 .. S'Last)) else Number (S));

   Log     : constant String := Slurp (W & "/log");
   Fold    : constant String := Slurp (W & "/fold");
   L       : RL.Ledger := RL.Empty_Ledger;
   Names   : Text_Array (1 .. WT.Max_Functions);
   Failure : U.Unbounded_String;
   Early   : U.Unbounded_String;
   Failed  : Boolean := False;
   Refused : Boolean := False;
   Errors  : Natural := 0;
   Read    : Natural := 0;
   Pos     : Positive := 1;
   KF, KL, VF, VL : Natural;
   Ok      : Boolean;
begin
   while Pos <= Log'Last loop
      Next_Field (Log, Pos, KF, KL, VF, VL, Ok);
      exit when not Ok;
      declare
         Key : constant String := Log (KF .. KL);
         V   : constant String := Log (VF .. VL);
         S1  : Natural := 0;
         S2  : Natural := 0;
      begin
         for I in V'Range loop
            if V (I) = ' ' then
               if S1 = 0 then
                  S1 := I;
               elsif S2 = 0 then
                  S2 := I;
               end if;
            end if;
         end loop;
         if Key = "failure" and then not Failed then
            Failed := True;
            Failure := +V;
         elsif Key = "refusal" then
            Refused := True;
            Early := +V;
         elsif Key = "error" then
            Errors := Errors + 1;
         elsif Key = "header" and then S2 > 0 then
            Read := Number (V (V'First .. S1 - 1));
            L := RL.Set_Header (L, Read, Number (V (S1 + 1 .. S2 - 1)), Number (V (S2 + 1 .. V'Last)));
         elsif Key = "record" and then S2 > 0 and then L.Kept < WT.Max_Functions then
            Names (L.Kept + 1) := +V (V'First .. S1 - 1);
            L := RL.Add_Record (L, (Definition => V (S1 + 1 .. S2 - 1) = "1",
                                    Grade      => Signed (V (S2 + 1 .. V'Last))));
         end if;
      end;
   end loop;

   if Failed then
      --  The run failed (runErr): the battery_ran false line alone, every count "0" (wire.go:24-28).
      declare
         F : constant String := U.To_String (Failure);
         T : constant String (1 .. F'Length) := F;
      begin
         if WL.Quotable (T) then
            Emit (WL.Plain_Failure_Line (T));
         else
            Emit (WL.Failure_Line (Wide_Quoted (T)));
         end if;
      end;
      Ada.Command_Line.Set_Exit_Status (0);
      return;
   end if;

   declare
      Kind : constant String := Value_Of (Fold, "refusal");
      S    : constant PF.Fold_State :=
        (Grade       => (if Fold = "" then PF.Unset else Signed (Value_Of (Fold, "grade"))),
         Graded      => Number (Value_Of (Fold, "graded")),
         Definitions => Number (Value_Of (Fold, "definitions")),
         Errors      => 0,
         Refusal     => (if Kind = "fold" then PF.Fold_Refused
                         elsif Kind = "function" then PF.Function_Refused else PF.No_Refusal));
   begin
      L := RL.Add_Errors (L, Errors);
      if Refused then
         --  An early refusal (edge verification, contract gate) returned before any function ran.
         L := RL.Set_Refusal (L, U.To_String (Early));
      else
         L := RL.Set_Totals (L, S.Graded, S.Definitions);
         L := RL.Set_Refusal (L, PF.Refusal_Text (S, Read));
      end if;
   end;

   declare
      T : constant WT.Tallies := RL.Wire_Tallies (L);
      C : constant WL.Wire_Counts :=
        (Refusal_Present    => RL.Has_Refusal (L),
         Error_Count        => L.Error_Count,
         Functions_Read     => L.Functions_Read,
         Functions_Graded   => L.Functions_Graded,
         Definitions_Only   => L.Definitions_Only,
         Posts_Declared     => L.Posts_Declared,
         Posts_Read         => L.Posts_Read,
         Theorem_Count      => T.Theorem_Count,
         Runtime_Only_Count => T.Runtime_Only_Count,
         Unexercised_Count  => T.Unexercised_Count,
         Refused_Count      => T.Refused_Count,
         Grade_Lines        => T.Grade_Lines);
      Rs : constant WT.Record_Array := RL.Kept_Records (L);
   begin
      if WL.Quotable (RL.Refusal_Of (L)) then
         Emit (WL.Plain_Ran_Line (C, RL.Refusal_Of (L)));
      else
         Emit (WL.Ran_Line (C, Wide_Quoted (RL.Refusal_Of (L))));
      end if;
      for N in 1 .. T.Grade_Lines loop
         declare
            K    : constant Natural := WT.Line_Order (Rs, N);
            Name : constant String := U.To_String (Names (K));
         begin
            Emit (GL.Grade_Line (Name, Rs (K).Grade));
         end;
      end loop;
   end;
   Ada.Command_Line.Set_Exit_Status (0);
end Wire_Close_Main;
