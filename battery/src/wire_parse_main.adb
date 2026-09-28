--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: eb3355c73a37cafa9815830d12302ecd3053add2a5f38a5903b2d5acc15bb75c
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with GNAT.Expect;
with Lovelace_Utf8_Decode_Pkg;
with Lovelace_Lex_Rules_Pkg;
with Lovelace_Param_Parser_Pkg;
with Lovelace_Aspect_Reader_Pkg;
with Lovelace_Declaration_Merger_Pkg;
with Lovelace_Function_Table_Pkg;

--  Wire_Parse_Main: the function walk of Go's ParseSpec [parse.go:69-126, 273-395, 460-518] as
--  a unit of the Ada wire kit. W/clean + W/head -> W/table. Called `wire_parse_main <W>`;
--  exit 0 = go on, 1 = a `failure` was logged, 3 = fault.
procedure Wire_Parse_Main is
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
   package Par renames Lovelace_Param_Parser_Pkg;
   package Asp renames Lovelace_Aspect_Reader_Pkg;
   package Mrg renames Lovelace_Declaration_Merger_Pkg;
   package Tbl renames Lovelace_Function_Table_Pkg;

   W : constant String := (if Ada.Command_Line.Argument_Count = 1 then Ada.Command_Line.Argument (1) else "");

   procedure Log (Key : String; Value : String) is
   begin
      Put_File (W & "/log", Field (Key, Value), True);
   end Log;

   procedure Event (Name : String; Subject : String; Detail : String) is
   begin
      Put_File (W & "/events", "wire-parse" & HT & Name & HT & Subject & HT & Detail & LF, True);
   end Event;

   --  One construct as function-scanner printed it, and what aspect-reader read of its aspects.
   type Construct_Text is record
      Name, Formal, Ret, Bod, Aspects, Target : U.Unbounded_String;
      Line, Last    : Natural := 0;
      Pre, Post     : U.Unbounded_String;
      Aspect_Fields : U.Unbounded_String;
      Aspect_Count  : Natural := 0;
   end record;

   type Construct_Texts is array (Positive range <>) of Construct_Text;

   --  The Nth blank-separated word of a line; "" when there is none.
   function Word (Line : String; N : Positive) return String is
      K : Natural := 0;
      I : Positive := Line'First;
      S : Positive;
   begin
      while I <= Line'Last loop
         if Line (I) = ' ' then
            I := I + 1;
         else
            S := I;
            while I <= Line'Last and then Line (I) /= ' ' loop
               I := I + 1;
            end loop;
            K := K + 1;
            if K = N then
               return Line (S .. I - 1);
            end if;
         end if;
      end loop;
      return "";
   end Word;

   --  Go's readAspects over one aspect text, by aspect-reader: every usable piece in order, and
   --  the Pre and Post values (the last piece so keyed wins, as in Go). The lex mask is walked
   --  from the text's first byte, as Go's splitTopLevel starts outside any string there.
   procedure Read_Aspects (Text : String; C : in out Construct_Text) is
      A      : constant String (1 .. Text'Length) := Text;
      Widths : Lex.Width_Array (1 .. A'Length);
      Mask   : Lex.Mask_Array (1 .. A'Length);
      S      : Lex.Walk_State := Lex.Initial_State;
      J      : Natural;
   begin
      for K in A'Range loop
         Widths (K) := Lovelace_Utf8_Decode_Pkg.Width_At (A, K);
      end loop;
      for K in A'Range loop
         Mask (K) := Lex.Class_In (A, Widths, K, S);
         S := Lex.Next_State (A, Widths, K, S);
      end loop;
      C.Aspect_Count := Asp.Aspect_Count (A, Mask);
      for N in 1 .. C.Aspect_Count loop
         J := Asp.Nth_Aspect (A, Mask, N);
         U.Append (C.Aspect_Fields,
                   Field ("aspect", A (Asp.Aspect_Piece (A, Mask, J).First .. Asp.Aspect_Piece (A, Mask, J).Last)));
      end loop;
      J := Asp.Pre_Index (A, Mask);
      if J > 0 then
         C.Pre := +A (Asp.Value_Of (A, Asp.Aspect_Piece (A, Mask, J)).First
                      .. Asp.Value_Of (A, Asp.Aspect_Piece (A, Mask, J)).Last);
      end if;
      J := Asp.Post_Index (A, Mask);
      if J > 0 then
         C.Post := +A (Asp.Value_Of (A, Asp.Aspect_Piece (A, Mask, J)).First
                       .. Asp.Value_Of (A, Asp.Aspect_Piece (A, Mask, J)).Last);
      end if;
   end Read_Aspects;

   --  Go's parseParams over a formal part, by param-parser: "params" then pname/ptype pairs.
   function Param_Fields (Formal : String) return String is
      Fm : constant String (1 .. Formal'Length) := Formal;
      N  : constant Natural := Par.Param_Count (Fm);
      R  : U.Unbounded_String := +Field ("params", Decimal (N));
      B  : Par.Param_Bounds;
   begin
      for K in 1 .. N loop
         B := Par.Nth_Param (Fm, K);
         U.Append (R, Field ("pname", Fm (B.Name_First .. B.Name_Last))
                      & Field ("ptype", Fm (B.Type_First .. B.Type_Last)));
      end loop;
      return U.To_String (R);
   end Param_Fields;

   function Text_Of (V : U.Unbounded_String) return String renames U.To_String;

   Clean  : constant String := Slurp (W & "/clean");
   Pkg    : constant String := Value_Of (Slurp (W & "/head"), "package");
   Kit    : constant String := Value_Of (Slurp (W & "/run"), "kit");
   Output : U.Unbounded_String;
   Code   : Integer;
begin
   if W = "" then
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   --  1. The walk (parse.go:69-82, 295-395): function-scanner reads every construct, or fails
   --     with "failure <length>" and the sentence.
   Run (Kit & "/function_scanner_main", (1 => +(W & "/clean")), "", Output, Code);
   if Code /= 0 then
      Event ("fault", "function_scanner_main", Decimal (Code));
      Ada.Command_Line.Set_Exit_Status (3);
      return;
   end if;
   declare
      T      : constant String := U.To_String (Output);
      Upper  : Natural := 0;
      Pos    : Positive := T'First;
      E      : Natural;
      KF, KL, VF, VL : Natural;
      Ok     : Boolean;
      Cur    : Natural := 0;
   begin
      if T'Length > 8 and then T (T'First .. T'First + 7) = "failure " then
         E := T'First;
         while E <= T'Last and then T (E) /= LF loop
            E := E + 1;
         end loop;
         declare
            Len : constant Natural := Number (T (T'First + 8 .. E - 1));
            S   : constant String := T (E + 1 .. Natural'Min (T'Last, E + Len));
         begin
            Log ("failure", "parse: " & S);
            Event ("parse_failed", "function", S);
            Ada.Command_Line.Set_Exit_Status (1);
            return;
         end;
      end if;
      --  At most as many constructs as lines that start with "construct ".
      for I in T'Range loop
         if (I = T'First or else T (I - 1) = LF) and then I + 9 <= T'Last and then T (I .. I + 9) = "construct " then
            Upper := Upper + 1;
         end if;
      end loop;
      declare
         Cs    : Construct_Texts (1 .. Upper);
         Names : U.Unbounded_String;
      begin
         while Pos <= T'Last loop
            Next_Field (T, Pos, KF, KL, VF, VL, Ok);
            if Ok then
               if Cur > 0 then
                  declare
                     Key : constant String := T (KF .. KL);
                     Val : constant U.Unbounded_String := +T (VF .. VL);
                  begin
                     if Key = "name" then
                        Cs (Cur).Name := Val;
                     elsif Key = "formal" then
                        Cs (Cur).Formal := Val;
                     elsif Key = "ret" then
                        Cs (Cur).Ret := Val;
                     elsif Key = "body" then
                        Cs (Cur).Bod := Val;
                     elsif Key = "aspects" then
                        Cs (Cur).Aspects := Val;
                     elsif Key = "renames" then
                        Cs (Cur).Target := Val;
                     end if;
                  end;
               end if;
            else
               E := Pos;
               while E <= T'Last and then T (E) /= LF loop
                  E := E + 1;
               end loop;
               if Word (T (Pos .. E - 1), 1) = "construct" and then Cur < Upper then
                  Cur := Cur + 1;
                  Cs (Cur).Line := Number (Word (T (Pos .. E - 1), 4));
                  Cs (Cur).Last := Number (Word (T (Pos .. E - 1), 5));
               end if;
               Pos := E + 1;
            end if;
         end loop;
         --  2. Per construct: the aspects (readAspects), then the merge facts.
         declare
            Ms : Mrg.Construct_Array (1 .. Cur);
         begin
            for K in 1 .. Cur loop
               Read_Aspects (Text_Of (Cs (K).Aspects), Cs (K));
               Ms (K) := (Name_First    => U.Length (Names) + 1,
                          Name_Last     => U.Length (Names) + U.Length (Cs (K).Name),
                          Is_Completion => U.Length (Cs (K).Bod) > 0,
                          Has_Pre       => U.Length (Cs (K).Pre) > 0,
                          Has_Post      => U.Length (Cs (K).Post) > 0,
                          Has_Aspects   => Cs (K).Aspect_Count > 0);
               U.Append (Names, Cs (K).Name);
            end loop;
            --  3. The merge (parse.go:83-126): declaration-merger picks, per entry, the construct
            --     each field comes from; function-table admits the entries' lines.
            declare
               Nm    : constant String := U.To_String (Names);
               Count : constant Natural := Mrg.Entry_Count (Nm, Ms);
               Es    : Tbl.Entry_Array (1 .. Count);
               Tab   : Tbl.Table_State := Tbl.Empty_Table;
               Rows  : U.Unbounded_String := +Field ("count", Decimal (Count));
               Total : Positive := 1;
               F, PS, QS, AS, BS, DS : Natural;
            begin
               if Count = 0 then
                  Log ("failure", "parse: " & Mrg.No_Functions_Text (Pkg));
                  Event ("parse_failed", Pkg, "no functions");
                  Ada.Command_Line.Set_Exit_Status (1);
                  return;
               end if;
               for C of Clean loop
                  if C = LF then
                     Total := Total + 1;
                  end if;
               end loop;
               for N in 1 .. Count loop
                  F  := Mrg.Entry_Construct (Nm, Ms, N);
                  PS := Mrg.Pre_Source (Nm, Ms, F);
                  QS := Mrg.Post_Source (Nm, Ms, F);
                  AS := Mrg.Aspects_Source (Nm, Ms, F);
                  BS := Mrg.Body_Source (Nm, Ms, F);
                  DS := Mrg.Decl_Source (Nm, Ms, F);
                  Tab := Tbl.Add_Entry (Tab);
                  Es (N) := (Decl_Line => Cs (DS).Line, Decl_End => Cs (DS).Last,
                             Body_Line => (if BS > 0 then Cs (BS).Line else 0),
                             Body_End  => (if BS > 0 then Cs (BS).Last else 0));
                  U.Append (Rows, Field ("name", Text_Of (Cs (F).Name)) & Field ("ret", Text_Of (Cs (F).Ret))
                    & Field ("pre", (if PS > 0 then Text_Of (Cs (PS).Pre) else ""))
                    & Field ("post", (if QS > 0 then Text_Of (Cs (QS).Post) else ""))
                    & Field ("body", (if BS > 0 then Text_Of (Cs (BS).Bod) else ""))
                    & Field ("renames", Text_Of (Cs (F).Target))
                    & Field ("combined", (if Mrg.Is_Combined (Ms, F) then "true" else "false"))
                    & Field ("boolean", (if Lex.Equal_Ignoring_Case (Text_Of (Cs (F).Ret), "boolean") then "true" else "false"))
                    & Field ("lines", Decimal (Es (N).Decl_Line) & " " & Decimal (Es (N).Decl_End) & " "
                                      & Decimal (Es (N).Body_Line) & " " & Decimal (Es (N).Body_End))
                    & Param_Fields (Text_Of (Cs (F).Formal))
                    & Field ("aspects", Decimal (Cs (AS).Aspect_Count)) & Text_Of (Cs (AS).Aspect_Fields));
               end loop;
               if not Tbl.All_Within (Es, Total) then
                  Event ("fault", "function_table", "lines outside the text");
                  Ada.Command_Line.Set_Exit_Status (3);
                  return;
               end if;
               Tab := Tbl.Seal (Tab, Es, Total);
               if not Tbl.May_Send_Parsed (Tab) then
                  Ada.Command_Line.Set_Exit_Status (3);
                  return;
               end if;
               Put_File (W & "/table", U.To_String (Rows), False);
               Event ("parsed", Pkg, Decimal (Count));
            end;
         end;
      end;
   end;
   Ada.Command_Line.Set_Exit_Status (0);
end Wire_Parse_Main;
