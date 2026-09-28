--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 5ba5160715bdfa9ee30452e3bf600779aacf7be98d3ae39e3f87165f5fd8476d
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Utf8_Decode_Pkg;
with Lovelace_Lex_Rules_Pkg;
with Lovelace_Comment_Stripper_Pkg;
with Lovelace_Clean_Spec_Pkg;

--  Wire_Strip_Main: the first part of Go's ParseSpec [parse.go:11-35, 57-67] as a unit of the
--  Ada wire kit. W/raw -> W/clean (stripComments), W/head (package, text), W/counts (pres,
--  posts). Called `wire_strip_main <W>`; exit 0 = go on, 1 = a `failure` was logged, 3 = fault.
procedure Wire_Strip_Main is
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

   package Lex renames Lovelace_Lex_Rules_Pkg;
   package Cut renames Lovelace_Comment_Stripper_Pkg;
   package Cln renames Lovelace_Clean_Spec_Pkg;

   W : constant String := (if Ada.Command_Line.Argument_Count = 1 then Ada.Command_Line.Argument (1) else "");

   procedure Log (Key : String; Value : String) is
   begin
      Put_File (W & "/log", Field (Key, Value), True);
   end Log;

   procedure Event (Name : String; Subject : String; Detail : String) is
   begin
      Put_File (W & "/events", "wire-strip" & HT & Name & HT & Subject & HT & Detail & LF, True);
   end Event;

   --  One line of the raw text with its comment cut off (Go's stripComments on that line): the
   --  rune widths are utf8-decode's, the lex mask is lex-rules' walk from the line's first byte
   --  (Go starts each line outside any string), the cut is comment-stripper's Kept_Last.
   function Kept (Line : String) return String is
      L      : constant String (1 .. Line'Length) := Line;
      Widths : Lex.Width_Array (1 .. L'Length);
      Mask   : Lex.Mask_Array (1 .. L'Length);
      S      : Lex.Walk_State := Lex.Initial_State;
   begin
      for K in L'Range loop
         Widths (K) := Lovelace_Utf8_Decode_Pkg.Width_At (L, K);
      end loop;
      for K in L'Range loop
         Mask (K) := Lex.Class_In (L, Widths, K, S);
         S := Lex.Next_State (L, Widths, K, S);
      end loop;
      return L (1 .. Cut.Kept_Last (L, Mask));
   end Kept;

   Raw    : constant String := Slurp (W & "/raw");
   Kit    : constant String := Value_Of (Slurp (W & "/run"), "kit");
   Clean  : U.Unbounded_String;
   From   : Positive := 1;
   E      : Natural;
   Pool   : Cln.Clean_Pool;
   Output : U.Unbounded_String;
   Code   : Integer;
begin
   if W = "" then
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   if Raw'Length > Lex.Max_Text then
      Event ("fault", "raw", "over the lane bound");
      Ada.Command_Line.Set_Exit_Status (3);
      return;
   end if;
   --  1. stripComments: every line (split at LF, as Go's strings.Split) keeps its part before
   --     the first comment; the lines are joined again with LF, so line numbers still match.
   loop
      E := Cut.Line_End (Raw, From);
      U.Append (Clean, Kept (Raw (From .. E)));
      exit when E = Raw'Length;
      U.Append (Clean, LF);
      From := E + 2;
   end loop;
   declare
      C : constant String := U.To_String (Clean);
   begin
      Pool := Cln.Pool_For (Raw);
      if not Cln.Keeps_Lines (Pool, C) then
         Event ("fault", "clean", "line count changed");
         Ada.Command_Line.Set_Exit_Status (3);
         return;
      end if;
      Pool := Cln.Write_Clean (Pool, C);
      if not Cln.May_Send_Ready (Pool) then
         Ada.Command_Line.Set_Exit_Status (3);
         return;
      end if;
      Put_File (W & "/clean", C, False);
      --  2. The header (parse.go:61-65): header-finder prints "package X", or the sentence (exit 1).
      Run (Kit & "/header_finder_main", (1 => +(W & "/clean")), "", Output, Code);
      declare
         T : constant String := U.To_String (Output);
         S : constant String := (if T'Length > 0 and then T (T'Last) = LF then T (T'First .. T'Last - 1) else T);
      begin
         if Code = 1 then
            Log ("failure", "parse: " & S);
            Event ("parse_failed", "header", S);
            Ada.Command_Line.Set_Exit_Status (1);
            return;
         elsif Code /= 0 or else Value_Of_Line (T, "package") = "" then
            Event ("fault", "header_finder_main", Decimal (Code));
            Ada.Command_Line.Set_Exit_Status (3);
            return;
         end if;
         Put_File (W & "/head", Field ("package", Value_Of_Line (T, "package")) & Field ("text", C), False);
      end;
      --  3. The declared counts (parse.go:66-67): aspect-counter prints "<pres> <posts>" (the
      --     final line end may be gone: Get_Command_Output drops it).
      Run (Kit & "/aspect_counter_main", (1 => +(W & "/clean")), "", Output, Code);
      declare
         T  : constant String := U.To_String (Output);
         Sp : Natural := 0;
         Nl : Natural := T'Last + 1;
      begin
         for I in T'Range loop
            if T (I) = ' ' and then Sp = 0 then
               Sp := I;
            elsif T (I) = LF and then Nl > T'Last then
               Nl := I;
            end if;
         end loop;
         if Code /= 0 or else Sp = 0 or else Nl < Sp then
            Event ("fault", "aspect_counter_main", Decimal (Code));
            Ada.Command_Line.Set_Exit_Status (3);
            return;
         end if;
         Put_File (W & "/counts", Field ("pres", T (T'First .. Sp - 1)) & Field ("posts", T (Sp + 1 .. Nl - 1)), False);
         Event ("stripped", Value_Of (Slurp (W & "/head"), "package"), T (T'First .. Nl - 1));
      end;
   end;
   Ada.Command_Line.Set_Exit_Status (0);
end Wire_Strip_Main;
