--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 57b7d6a15c55895ef6f450d15dc2630b022d9e31412165bece9933086ecfd3cc
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Vectors;
with GNAT.OS_Lib;
with Lovelace_Utf8_Decode_Pkg;
with Lovelace_Lex_Rules_Pkg;
with Lovelace_Word_Rules_Pkg;
with Lovelace_Mutation_Rules_Pkg;

procedure T3_Mutant_Edits_Main is
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

   --  The stage request: package, text, subject, extra, then the function table.
   procedure Read_Spec (Pkg : out U.Unbounded_String; Text : out U.Unbounded_String;
                        Subject : out Natural; Extra : out U.Unbounded_String;
                        Funcs : out Func_Vectors.Vector) is
      N : Natural;
   begin
      Pkg := U.To_Unbounded_String (Next ("package"));
      Text := U.To_Unbounded_String (Next ("text"));
      Subject := Next_Count ("subject");
      Extra := U.To_Unbounded_String (Next ("extra"));
      N := Next_Count ("count");
      Funcs := Func_Vectors.Empty_Vector;
      for I in 1 .. N loop
         exit when Bad;
         declare
            F  : Func;
            NP : Natural;
            NA : Natural;
         begin
            F.Name := U.To_Unbounded_String (Next ("name"));
            F.Ret := U.To_Unbounded_String (Next ("ret"));
            F.Pre := U.To_Unbounded_String (Next ("pre"));
            F.Post := U.To_Unbounded_String (Next ("post"));
            F.Body_Text := U.To_Unbounded_String (Next ("body"));
            F.Renamed := U.To_Unbounded_String (Next ("renames"));
            F.Combined := Next_Flag ("combined");
            F.Is_Bool := Next_Flag ("boolean");
            Read_Lines (Next ("lines"), F);
            NP := Next_Count ("params");
            for K in 1 .. NP loop
               exit when Bad;
               declare
                  P : Param;
               begin
                  P.Name := U.To_Unbounded_String (Next ("pname"));
                  P.Kind := U.To_Unbounded_String (Next ("ptype"));
                  F.Params.Append (P);
               end;
            end loop;
            NA := Next_Count ("aspects");
            for K in 1 .. NA loop
               exit when Bad;
               F.Aspects.Append (Next ("aspect"));
            end loop;
            Funcs.Append (F);
         end;
      end loop;
      if Pos /= U.Length (Req) + 1 or else Subject < 1 or else Subject > Natural (Funcs.Length) then
         Bad := True;
      end if;
   end Read_Spec;

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

   --  isPredicate [derive.go:275-283]: a Boolean function whose trimmed Post is, whole,
   --  an optional '(' , RE2 spaces, <Name>'Result in any case, RE2 spaces, an optional ')'.
   function Is_Predicate (F : Func) return Boolean is
      Name : constant String := U.To_String (F.Name);
      Raw  : constant String := U.To_String (F.Post);
      R    : constant String (1 .. Raw'Length) := Raw;
      A    : constant Positive := Lovelace_Word_Rules_Pkg.First_Non_Trim (R, 1, R'Length);
      B    : constant Natural := Lovelace_Word_Rules_Pkg.Last_Non_Trim (R, A, R'Length);
      T    : constant String (1 .. B - A + 1) := R (A .. B);
      P    : Positive := 1;
   begin
      if not F.Is_Bool or else R'Length = 0 or else Name'Length < 1
        or else Name'Length > Lovelace_Word_Rules_Pkg.Max_Word
      then
         return False;
      end if;
      if P <= T'Length and then T (P) = '(' then
         P := P + 1;
      end if;
      while P <= T'Length and then Lovelace_Word_Rules_Pkg.Is_Collapse_Space (T (P)) loop
         P := P + 1;
      end loop;
      if P > T'Length or else not Lovelace_Word_Rules_Pkg.Name_At (T, P, Name, True) then
         return False;
      end if;
      P := P + Lovelace_Word_Rules_Pkg.Name_Length (Name, True);
      while P <= T'Length and then Lovelace_Word_Rules_Pkg.Is_Collapse_Space (T (P)) loop
         P := P + 1;
      end loop;
      if P <= T'Length and then T (P) = ')' then
         P := P + 1;
      end if;
      return P = T'Length + 1;
   end Is_Predicate;

   --  Drop-ins from wu-lovelace-mutation-rules-2/NOTES.txt, verbatim.
   procedure Fill_Spans (Text : String; Widths : Lovelace_Lex_Rules_Pkg.Width_Array;
                         Spans : out Lovelace_Lex_Rules_Pkg.Span_Array; Count : out Natural) is
   begin
      Count := Lovelace_Lex_Rules_Pkg.Span_Count (Text, Widths);
      for I in 1 .. Count loop
         Spans (Spans'First + I - 1) := Lovelace_Lex_Rules_Pkg.Nth_Span (Text, Widths, I);
      end loop;
   end Fill_Spans;

   procedure Fill_Literal_Edits (Text : String; Spans : Lovelace_Lex_Rules_Pkg.Span_Array; Span_Count : Natural;
                                 Edits : out Lovelace_Mutation_Rules_Pkg.Edit_Array; Count : out Natural) is
   begin
      Count := Lovelace_Mutation_Rules_Pkg.Lit_Edit_Count (Text, Spans, Span_Count);
      for N in 1 .. Count loop
         Edits (Edits'First + N - 1) := Lovelace_Mutation_Rules_Pkg.Nth_Lit_Edit (Text, Spans, Span_Count, N);
      end loop;
   end Fill_Literal_Edits;

   procedure Fill_Operator_Edits (Text : String; Spans : Lovelace_Lex_Rules_Pkg.Span_Array; Span_Count : Natural;
                                  Edits : out Lovelace_Mutation_Rules_Pkg.Operator_Edit_Array; Count : out Natural) is
   begin
      Count := Lovelace_Mutation_Rules_Pkg.Op_Edit_Count (Text, Spans, Span_Count);
      for N in 1 .. Count loop
         Edits (Edits'First + N - 1) := Lovelace_Mutation_Rules_Pkg.Nth_Op_Edit (Text, Spans, Span_Count, N);
      end loop;
   end Fill_Operator_Edits;

   package Lex renames Lovelace_Lex_Rules_Pkg;
   package Mut renames Lovelace_Mutation_Rules_Pkg;

   --  deriveT3's predicate test and its literal then operator mutants [derive.go:221-237;
   --  parse.go:703-794], through the mutation-rules core (the drop-ins above), in its order.
   procedure Run_Stage is
      Pkg     : U.Unbounded_String;
      Text    : U.Unbounded_String;
      Extra   : U.Unbounded_String;
      Subject : Natural;
      Funcs   : Func_Vectors.Vector;
   begin
      Read_Spec (Pkg, Text, Subject, Extra, Funcs);
      if Bad then
         return;
      end if;
      declare
         F   : constant Func := Funcs (Subject);
         Raw : constant String := U.To_String (F.Body_Text);
         B   : constant String (1 .. Raw'Length) := Raw;
         Out_Bodies : U.Unbounded_String;
         N   : Natural := 0;
      begin
         if Is_Predicate (F) then
            Field ("predicate", "true");
            Field ("mutants", "0");
            return;
         end if;
         Field ("predicate", "false");
         if B'Length > 0 then
            declare
               W     : Lex.Width_Array (1 .. B'Length);
               Spans : Lex.Span_Array (1 .. B'Length);
               SC    : Natural;
               Edits : Mut.Edit_Array (1 .. B'Length);
               EC    : Natural;
               Ops   : Mut.Operator_Edit_Array (1 .. B'Length);
               OC    : Natural;
               Held  : constant U.Unbounded_String := Output;
            begin
               for I in 1 .. B'Length loop
                  W (I) := Lovelace_Utf8_Decode_Pkg.Width_At (B, I);
               end loop;
               Fill_Spans (B, W, Spans, SC);
               Fill_Literal_Edits (B, Spans, SC, Edits, EC);
               Output := U.Null_Unbounded_String;
               for I in 1 .. EC loop
                  Field ("body", Mut.Apply (B, Edits (I).First, Edits (I).Past,
                                            Edits (I).Replacement (1 .. Edits (I).Replacement_Length)));
               end loop;
               Fill_Operator_Edits (B, Spans, SC, Ops, OC);
               for I in 1 .. OC loop
                  declare
                     To : constant String := Mut.Swap_To (Ops (I).Swap);
                     R  : constant String (1 .. To'Length) := To;
                  begin
                     Field ("body", Mut.Apply (B, Ops (I).First,
                                               Ops (I).First + Mut.Swap_From (Ops (I).Swap)'Length, R));
                  end;
               end loop;
               Out_Bodies := Output;
               N := EC + OC;
               Output := Held;
            end;
         end if;
         Field ("mutants", Decimal (N));
         U.Append (Output, Out_Bodies);
      end;
   end Run_Stage;

begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t3-mutant-edits: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      Ok : Boolean;
   begin
      Load (Ada.Command_Line.Argument (1), Ok);
      if not Ok then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t3-mutant-edits: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
   end;
   Run_Stage;
   if Bad then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t3-mutant-edits: malformed request");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   Emit;
   Ada.Command_Line.Set_Exit_Status (0);
end T3_Mutant_Edits_Main;
