--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: fd7dc337f82843f6f1f6954e1708c53ce3ec04e77e1b806c73c5de9bc41d449d
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Vectors;
with GNAT.OS_Lib;
with Lovelace_Utf8_Decode_Pkg;
with Lovelace_Lex_Rules_Pkg;
with Lovelace_Text_Rules_Pkg;

procedure T6_Pre_Main is
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

   procedure Fill_Mask (Text : String; Widths : Lovelace_Lex_Rules_Pkg.Width_Array;
                        From : Positive; Mask : out Lovelace_Lex_Rules_Pkg.Mask_Array) is
      S : Lovelace_Lex_Rules_Pkg.Walk_State := Lovelace_Lex_Rules_Pkg.Initial_State;
   begin
      for K in Text'Range loop
         if K < From then
            Mask (K) := Lovelace_Lex_Rules_Pkg.Outside;
         else
            Mask (K) := Lovelace_Lex_Rules_Pkg.Class_In (Text, Widths, K, S);
            S := Lovelace_Lex_Rules_Pkg.Next_State (Text, Widths, K, S);
         end if;
      end loop;
   end Fill_Mask;

   --  Go's strings.TrimSpace, ASCII part (text-rules' Trim), as a String indexed from 1.
   function Trimmed (S : String) return String is
      T : constant String (1 .. S'Length) := S;
      P : constant Lovelace_Text_Rules_Pkg.Piece := Lovelace_Text_Rules_Pkg.Trim (T, 1, T'Length);
      R : constant String (1 .. P.Last - P.First + 1) := T (P.First .. P.Last);
   begin
      return R;
   end Trimmed;

   --  topConjuncts [parse.go:621-666] of an already trimmed T: its top-level conjuncts, trimmed,
   --  through text-rules' Conjunct_Count and Conjunct_Bounds over a mask scanned from 1.
   procedure Top_Conjuncts (T : String; Pieces : out Text_Vectors.Vector) is
      W : Lovelace_Lex_Rules_Pkg.Width_Array (1 .. T'Length);
      M : Lovelace_Lex_Rules_Pkg.Mask_Array (1 .. T'Length);
   begin
      Pieces := Text_Vectors.Empty_Vector;
      for I in 1 .. T'Length loop
         W (I) := Lovelace_Utf8_Decode_Pkg.Width_At (T, I);
      end loop;
      Fill_Mask (T, W, 1, M);
      for N in 1 .. Lovelace_Text_Rules_Pkg.Conjunct_Count (T, M) loop
         declare
            P : constant Lovelace_Text_Rules_Pkg.Piece := Lovelace_Text_Rules_Pkg.Conjunct_Bounds (T, M, N);
         begin
            Pieces.Append (T (P.First .. P.Last));
         end;
      end loop;
   end Top_Conjuncts;

   --  The pieces joined by " and then ", piece I replaced by "True" (none when I = 0).
   function Join_With_True (Pieces : Text_Vectors.Vector; I : Natural) return String is
      R : U.Unbounded_String;
   begin
      for K in 1 .. Natural (Pieces.Length) loop
         if K > 1 then
            U.Append (R, " and then ");
         end if;
         U.Append (R, (if K = I then "True" else Pieces (K)));
      end loop;
      return U.To_String (R);
   end Join_With_True;
   --  withAspect [parse.go:438-453]: the aspect keyed "pre" (the text before its first "=>",
   --  trimmed, any case: lex-rules' Equal_Ignoring_Case) replaced by "Pre => Repl", or dropped
   --  when Repl is ""; the others kept in order. Written as an "aspects" block.
   procedure Write_With_Pre (Aspects : Text_Vectors.Vector; Repl : String) is
      Kept : Text_Vectors.Vector;
   begin
      for A of Aspects loop
         declare
            Arrow : Natural := 0;
         begin
            for K in A'First .. A'Last - 1 loop
               if A (K .. K + 1) = "=>" then
                  Arrow := K;
                  exit;
               end if;
            end loop;
            declare
               Key : constant String := Trimmed (if Arrow = 0 then A else A (A'First .. Arrow - 1));
            begin
               if Lovelace_Lex_Rules_Pkg.Equal_Ignoring_Case (Key, "pre") then
                  if Repl /= "" then
                     Kept.Append ("Pre => " & Repl);
                  end if;
               else
                  Kept.Append (A);
               end if;
            end;
         end;
      end loop;
      Field ("aspects", Decimal (Natural (Kept.Length)));
      for A of Kept loop
         Field ("aspect", A);
      end loop;
   end Write_With_Pre;

   --  preNecessityVariants [necessity.go:36-67], its aspect lists only: with a Pre, each top-level
   --  conjunct (text-rules) replaced by True in turn -- or, with fewer than two, the whole Pre
   --  dropped -- and the aspects rewritten. t6-sub renders them.
   procedure Run_Stage is
      Pkg     : U.Unbounded_String;
      Text    : U.Unbounded_String;
      Extra   : U.Unbounded_String;
      Subject : Natural;
      Funcs   : Func_Vectors.Vector;
      Pieces  : Text_Vectors.Vector;
   begin
      Read_Spec (Pkg, Text, Subject, Extra, Funcs);
      if Bad then
         return;
      end if;
      declare
         F : constant Func := Funcs (Subject);
      begin
         if U.Length (F.Pre) = 0 then
            Field ("pres", "0");
            return;
         end if;
         declare
            T : constant String := Trimmed (U.To_String (F.Pre));
         begin
            Top_Conjuncts (T, Pieces);
            if Natural (Pieces.Length) < 2 then
               Pieces := Text_Vectors.Empty_Vector;
               Pieces.Append (T);
            end if;
            Field ("pres", Decimal (Natural (Pieces.Length)));
            for I in 1 .. Natural (Pieces.Length) loop
               Write_With_Pre (F.Aspects,
                               (if Natural (Pieces.Length) = 1 then "" else Join_With_True (Pieces, I)));
            end loop;
         end;
      end;
   end Run_Stage;

begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t6-pre: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      Ok : Boolean;
   begin
      Load (Ada.Command_Line.Argument (1), Ok);
      if not Ok then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t6-pre: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
   end;
   Run_Stage;
   if Bad then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t6-pre: malformed request");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   Emit;
   Ada.Command_Line.Set_Exit_Status (0);
end T6_Pre_Main;
