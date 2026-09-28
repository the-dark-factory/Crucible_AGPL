--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 323c2fe6869692f6004406b5f2a27159bbe883aeb53dcf667c906df6ec8e0179
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Vectors;
with GNAT.OS_Lib;
with Lovelace_Utf8_Decode_Pkg;
with Lovelace_Lex_Rules_Pkg;
with Lovelace_Splice_Fit_Pkg;
with Lovelace_Lexical_Guard_Pkg;

procedure T3_Mutant_Render_Main is
   use type GNAT.OS_Lib.File_Descriptor;

   package U renames Ada.Strings.Unbounded;

   type Param is record
      Name : U.Unbounded_String;
      Kind : U.Unbounded_String;
   end record;

   package Param_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Param);
   package Text_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);

   type Func is record
      Name      : U.Unbounded_String;
      Ret       : U.Unbounded_String;
      Pre       : U.Unbounded_String;
      Post      : U.Unbounded_String;
      Body_Text : U.Unbounded_String;
      Renamed   : U.Unbounded_String;
      Combined  : Boolean := False;
      Is_Bool   : Boolean := False;
      Decl_Line : Natural := 0;
      Decl_End  : Natural := 0;
      Body_Line : Natural := 0;
      Body_End  : Natural := 0;
      Params    : Param_Vectors.Vector;
      Aspects   : Text_Vectors.Vector;
   end record;

   package Func_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Func);

   LF          : constant Character := Character'Val (10);
   Max_Request : constant := 4_194_304;

   Req    : U.Unbounded_String;
   Pos    : Positive := 1;
   Bad    : Boolean := False;
   Output : U.Unbounded_String;

   function Decimal (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Decimal;

   --  Read the whole request file into Req. Ok is False when it cannot be read or is too long.
   procedure Load (Path : String; Ok : out Boolean) is
      FD : constant GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Open_Read (Path, GNAT.OS_Lib.Binary);
   begin
      Ok := False;
      if FD = GNAT.OS_Lib.Invalid_FD then
         return;
      end if;
      if GNAT.OS_Lib.File_Length (FD) > Max_Request then
         GNAT.OS_Lib.Close (FD);
         return;
      end if;
      declare
         Buf : String (1 .. Natural (GNAT.OS_Lib.File_Length (FD)));
         N   : Integer := 0;
      begin
         if Buf'Length > 0 then
            N := GNAT.OS_Lib.Read (FD, Buf (1)'Address, Buf'Length);
         end if;
         GNAT.OS_Lib.Close (FD);
         if N = Buf'Length then
            Req := U.To_Unbounded_String (Buf);
            Ok := True;
         end if;
      end;
   end Load;

   --  The next field "<Key> <length>" LF <bytes> LF. On any mismatch Bad is set and "" returned.
   function Next (Key : String) return String is
      Last : constant Natural := U.Length (Req);
      NL   : Natural := 0;
      N    : Natural := 0;
      Sp   : Natural := 0;
   begin
      if Bad then
         return "";
      end if;
      for I in Pos .. Last loop
         if U.Element (Req, I) = LF then
            NL := I;
            exit;
         end if;
      end loop;
      if NL = 0 then
         Bad := True;
         return "";
      end if;
      for I in Pos .. NL - 1 loop
         if U.Element (Req, I) = ' ' then
            Sp := I;
            exit;
         end if;
      end loop;
      if Sp = 0 or else U.Slice (Req, Pos, Sp - 1) /= Key or else NL - Sp - 1 < 1 or else NL - Sp - 1 > 9 then
         Bad := True;
         return "";
      end if;
      if NL - Sp - 1 > 1 and then U.Element (Req, Sp + 1) = '0' then
         Bad := True;
         return "";
      end if;
      for I in Sp + 1 .. NL - 1 loop
         if U.Element (Req, I) not in '0' .. '9' then
            Bad := True;
            return "";
         end if;
         N := N * 10 + (Character'Pos (U.Element (Req, I)) - Character'Pos ('0'));
      end loop;
      if N > Last - NL - 1 or else U.Element (Req, NL + N + 1) /= LF then
         Bad := True;
         return "";
      end if;
      Pos := NL + N + 2;
      declare
         V : constant String (1 .. N) := U.Slice (Req, NL + 1, NL + N);
      begin
         return V;
      end;
   end Next;

   --  A field whose value is a decimal count.
   function Next_Count (Key : String) return Natural is
      V : constant String := Next (Key);
      N : Natural := 0;
   begin
      if V'Length < 1 or else V'Length > 7 or else (V'Length > 1 and then V (V'First) = '0') then
         Bad := True;
         return 0;
      end if;
      for C of V loop
         if C not in '0' .. '9' then
            Bad := True;
            return 0;
         end if;
         N := N * 10 + (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      return N;
   end Next_Count;

   --  A field whose value is "true" or "false".
   function Next_Flag (Key : String) return Boolean is
      V : constant String := Next (Key);
   begin
      if V /= "true" and then V /= "false" then
         Bad := True;
      end if;
      return V = "true";
   end Next_Flag;

   --  Append one output field.
   procedure Field (Key : String; Value : String) is
   begin
      U.Append (Output, Key & " " & Decimal (Value'Length) & LF & Value & LF);
   end Field;

   --  The four decimals of a "lines" field.
   procedure Read_Lines (V : String; F : in out Func) is
      Nums : array (1 .. 4) of Natural := (others => 0);
      K    : Natural := 0;
      In_Num : Boolean := False;
   begin
      for C of V loop
         if C in '0' .. '9' then
            if not In_Num then
               K := K + 1;
               In_Num := True;
               if K > 4 then
                  Bad := True;
                  return;
               end if;
            end if;
            Nums (K) := Nums (K) * 10 + (Character'Pos (C) - Character'Pos ('0'));
         elsif C = ' ' then
            In_Num := False;
         else
            Bad := True;
            return;
         end if;
      end loop;
      if K /= 4 then
         Bad := True;
         return;
      end if;
      F.Decl_Line := Nums (1);
      F.Decl_End := Nums (2);
      F.Body_Line := Nums (3);
      F.Body_End := Nums (4);
   end Read_Lines;

   --  Go's paramList: "" or " (" & "N : T" joined by "; " & ")".
   function Param_List (Ps : Param_Vectors.Vector) return String is
      R : U.Unbounded_String;
   begin
      if Ps.Is_Empty then
         return "";
      end if;
      U.Append (R, " (");
      for K in 1 .. Natural (Ps.Length) loop
         if K > 1 then
            U.Append (R, "; ");
         end if;
         U.Append (R, U.To_String (Ps (K).Name) & " : " & U.To_String (Ps (K).Kind));
      end loop;
      U.Append (R, ")");
      return U.To_String (R);
   end Param_List;

   --  Print Output as it is, with no line end added.
   procedure Emit is
      S : constant String := U.To_String (Output);
      W : Integer;
   begin
      if S'Length > 0 then
         W := GNAT.OS_Lib.Write (GNAT.OS_Lib.Standout, S (S'First)'Address, S'Length);
      end if;
   end Emit;

   --  The spec's lines: Text split at every LF (k LFs give k + 1 lines, as Go's strings.Split).
   procedure Split_Lines (Text : String; Lines : out Text_Vectors.Vector) is
      Start : Positive := Text'First;
   begin
      Lines := Text_Vectors.Empty_Vector;
      for I in Text'First .. Text'Last loop
         if Text (I) = LF then
            Lines.Append (Text (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;
      Lines.Append (Text (Start .. Text'Last));
   end Split_Lines;

   --  The lines joined by LF.
   function Join_Lines (Lines : Text_Vectors.Vector) return String is
      R : U.Unbounded_String;
   begin
      for K in 1 .. Natural (Lines.Length) loop
         if K > 1 then
            U.Append (R, LF);
         end if;
         U.Append (R, Lines (K));
      end loop;
      return U.To_String (R);
   end Join_Lines;

   --  fitLines [derive.go:326-336] through the proven splice-fit core: Text on lines From .. To,
   --  collapsed onto the first, the rest empty; no other line moves.
   procedure Fit (Lines : in out Text_Vectors.Vector; From : Natural; To : Natural; Text : String) is
      T : constant String (1 .. Text'Length) := Text;
      N : constant Integer := To - From + 1;
   begin
      if From < 1 or else N < 1 or else To > Natural (Lines.Length) then
         return;
      end if;
      for K in 1 .. N loop
         Lines.Replace_Element (From + K - 1, Lovelace_Splice_Fit_Pkg.Fit_Line (T, N, K));
      end loop;
   end Fit;

   --  Lines From .. To made empty.
   procedure Blank (Lines : in out Text_Vectors.Vector; From : Natural; To : Natural) is
   begin
      for K in From .. To loop
         if K >= 1 and then K <= Natural (Lines.Length) then
            Lines.Replace_Element (K, "");
         end if;
      end loop;
   end Blank;

   --  " with " & the aspects joined by ", ", or "" when there is none.
   function Aspect_Part (Aspects : Text_Vectors.Vector) return String is
      R : U.Unbounded_String;
   begin
      if Aspects.Is_Empty then
         return "";
      end if;
      U.Append (R, " with ");
      for K in 1 .. Natural (Aspects.Length) loop
         if K > 1 then
            U.Append (R, ", ");
         end if;
         U.Append (R, Aspects (K));
      end loop;
      return U.To_String (R);
   end Aspect_Part;

   --  renderFunction [parse.go:427-436].
   function Render_Function (F : Func; Ps : Param_Vectors.Vector; Body_Text : String;
                             Aspects : Text_Vectors.Vector) return String is
     ("function " & U.To_String (F.Name) & Param_List (Ps) & " return " & U.To_String (F.Ret)
      & (if F.Combined then " is (" & Body_Text & ")" else "") & Aspect_Part (Aspects) & ";");

   --  One derived variant: its tag, its text, and its mark (key, first line, last line).
   procedure Write_Variant (Tag : String; Text : String; Key : String; From : Natural; To : Natural) is
   begin
      Field ("tag", Tag);
      Field ("text", Text);
      Field ("mark", Key & " " & Decimal (From) & " " & Decimal (To));
   end Write_Variant;

   --  Drop-in from wu-lovelace-mutation-rules-2/NOTES.txt, verbatim.
   procedure Fill_Spans (Text : String; Widths : Lovelace_Lex_Rules_Pkg.Width_Array;
                         Spans : out Lovelace_Lex_Rules_Pkg.Span_Array; Count : out Natural) is
   begin
      Count := Lovelace_Lex_Rules_Pkg.Span_Count (Text, Widths);
      for I in 1 .. Count loop
         Spans (Spans'First + I - 1) := Lovelace_Lex_Rules_Pkg.Nth_Span (Text, Widths, I);
      end loop;
   end Fill_Spans;

   package Lex renames Lovelace_Lex_Rules_Pkg;

   --  checkLexical [lex.go:169-226] through the proven lexical-guard core: True when well formed.
   function Well_Formed (Text : String) return Boolean is
      T     : constant String (1 .. Text'Length) := Text;
      W     : Lex.Width_Array (1 .. T'Length);
      Spans : Lex.Span_Array (1 .. Natural'Max (T'Length, 1));
      Count : Natural;
   begin
      for I in 1 .. T'Length loop
         W (I) := Lovelace_Utf8_Decode_Pkg.Width_At (T, I);
      end loop;
      Fill_Spans (T, W, Spans, Count);
      return Lovelace_Lexical_Guard_Pkg.Well_Formed (T, W, Spans, Count);
   end Well_Formed;

   --  deriveT3's rendering [derive.go:213, 238-272] of the given mutant bodies: the first Cap are
   --  written over the subject's lines (combined: its declaration lines; otherwise its completion
   --  lines) and withheld when the spec passes the lexical guard and the variant does not.
   --  The request: text, name, ret, combined, lines, params (pname, ptype), aspects (aspect),
   --  cap, mutants (body) -- the conjunct half's bodies then the edits half's, in that order.
   procedure Run_Stage is
      F        : Func;
      Text     : U.Unbounded_String;
      Bodies   : Text_Vectors.Vector;
      Cap      : Natural;
      N        : Natural;
      Result   : U.Unbounded_String;
      Withheld : U.Unbounded_String;
      Kept     : Natural := 0;
      Held_N   : Natural := 0;
      Lines    : Text_Vectors.Vector;
   begin
      Text := U.To_Unbounded_String (Next ("text"));
      F.Name := U.To_Unbounded_String (Next ("name"));
      F.Ret := U.To_Unbounded_String (Next ("ret"));
      F.Combined := Next_Flag ("combined");
      Read_Lines (Next ("lines"), F);
      N := Next_Count ("params");
      for K in 1 .. N loop
         exit when Bad;
         declare
            P : Param;
         begin
            P.Name := U.To_Unbounded_String (Next ("pname"));
            P.Kind := U.To_Unbounded_String (Next ("ptype"));
            F.Params.Append (P);
         end;
      end loop;
      N := Next_Count ("aspects");
      for K in 1 .. N loop
         exit when Bad;
         F.Aspects.Append (Next ("aspect"));
      end loop;
      Cap := Next_Count ("cap");
      N := Next_Count ("mutants");
      for K in 1 .. N loop
         exit when Bad;
         Bodies.Append (Next ("body"));
      end loop;
      if Bad or else Pos /= U.Length (Req) + 1 then
         Bad := True;
         return;
      end if;
      declare
         Name  : constant String := U.To_String (F.Name);
         Guard : constant Boolean := Well_Formed (U.To_String (Text));
      begin
         for I in 1 .. Natural'Min (Cap, Natural (Bodies.Length)) loop
            declare
               M   : constant String := Bodies (I);
               Tag : constant String := "t3-" & Name & "-" & Decimal (I - 1);
            begin
               Split_Lines (U.To_String (Text), Lines);
               if F.Combined then
                  Fit (Lines, F.Decl_Line, F.Decl_End, "   " & Render_Function (F, F.Params, M, F.Aspects));
               else
                  Fit (Lines, F.Body_Line, F.Body_End,
                       "   function " & Name & Param_List (F.Params) & " return " & U.To_String (F.Ret)
                       & " is (" & M & ");");
               end if;
               declare
                  V : constant String := Join_Lines (Lines);
               begin
                  if Guard and then not Well_Formed (V) then
                     U.Append (Withheld, "tag " & Decimal (Tag'Length) & LF & Tag & LF);
                     Held_N := Held_N + 1;
                  else
                     Write_Variant (Tag, V, Name & "#" & Decimal (I - 1), F.Decl_Line, F.Decl_End);
                     Kept := Kept + 1;
                  end if;
               end;
            end;
         end loop;
         Result := Output;
         Output := U.Null_Unbounded_String;
         Field ("variants", Decimal (Kept));
         U.Append (Output, Result);
         Field ("withheld", Decimal (Held_N));
         U.Append (Output, Withheld);
      end;
   end Run_Stage;

begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t3-mutant-render: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      Ok : Boolean;
   begin
      Load (Ada.Command_Line.Argument (1), Ok);
      if not Ok then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t3-mutant-render: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
   end;
   Run_Stage;
   if Bad then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t3-mutant-render: malformed request");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   Emit;
   Ada.Command_Line.Set_Exit_Status (0);
end T3_Mutant_Render_Main;
