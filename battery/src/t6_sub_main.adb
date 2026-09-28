--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 2a761eaedf00f7cb5e34c8d8cb7d86345205c9d577a8a6abe77d36529bb1888e
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Vectors;
with GNAT.OS_Lib;
with Lovelace_Word_Rules_Pkg;
with Lovelace_Splice_Fit_Pkg;

procedure T6_Sub_Main is
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
      if Subject < 1 or else Subject > Natural (Funcs.Length) then
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
   package Aspect_Lists is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Text_Vectors.Vector, "=" => Text_Vectors."=");

   --  Go's strings.TrimSpace, ASCII part (word-rules' trims), indexed from 1.
   function Trimmed (S : String) return String is
      T : constant String (1 .. S'Length) := S;
      F : constant Positive := Lovelace_Word_Rules_Pkg.First_Non_Trim (T, 1, T'Length);
      L : constant Natural := Lovelace_Word_Rules_Pkg.Last_Non_Trim (T, F, T'Length);
      R : constant String (1 .. L - F + 1) := T (F .. L);
   begin
      return R;
   end Trimmed;

   function Has_Name (Names : Text_Vectors.Vector; N : String) return Boolean is
   begin
      for M of Names loop
         if M = N then
            return True;
         end if;
      end loop;
      return False;
   end Has_Name;

   function Lower (S : String) return String is
      R : String (1 .. S'Length) := S;
   begin
      for I in R'Range loop
         if R (I) in 'A' .. 'Z' then
            R (I) := Character'Val (Character'Pos (R (I)) + 32);
         end if;
      end loop;
      return R;
   end Lower;

   function Is_Space (C : Character) return Boolean renames Lovelace_Word_Rules_Pkg.Is_Collapse_Space;

   --  subtypeRanges [parse.go:397-405], names only, lower case: every leftmost non-overlapping
   --  (?i)\bsubtype\s+(Ident)\s+is\s+Integer\s+range\s+([^.\s]+)\s*\.\.\s*([^;\s]+)\s*;
   procedure Subtype_Names (T : String; Names : out Text_Vectors.Vector) is
      From : Positive := 1;
      P    : Natural;

      --  The match at P, or 0; Last is the ';' of a match.
      function Match_At (P : Positive; Name_First : out Positive; Name_Last : out Natural) return Natural is
         J : Positive := P + 7;

         function Spaces (Min : Natural) return Boolean is
            K : Natural := 0;
         begin
            while J <= T'Length and then Is_Space (T (J)) loop
               J := J + 1;
               K := K + 1;
            end loop;
            return K >= Min;
         end Spaces;

         function Word (W : String) return Boolean is
         begin
            if W'Length <= T'Length - J + 1 and then Lovelace_Word_Rules_Pkg.Equal_CI (T (J .. J + W'Length - 1), W) then
               J := J + W'Length;
               return True;
            end if;
            return False;
         end Word;

         function Run (Stop : Character) return Boolean is
            K : Natural := 0;
         begin
            while J <= T'Length and then T (J) /= Stop and then not Is_Space (T (J)) loop
               J := J + 1;
               K := K + 1;
            end loop;
            return K >= 1;
         end Run;
      begin
         Name_First := 1;
         Name_Last := 0;
         if not Spaces (1) then
            return 0;
         end if;
         if J > T'Length or else T (J) not in 'A' .. 'Z' | 'a' .. 'z' then
            return 0;
         end if;
         Name_First := J;
         while J <= T'Length and then Lovelace_Word_Rules_Pkg.Is_Word_Char (T (J)) loop
            J := J + 1;
         end loop;
         Name_Last := J - 1;
         if not Spaces (1) or else not Word ("is") or else not Spaces (1) or else not Word ("integer")
           or else not Spaces (1) or else not Word ("range") or else not Spaces (1) or else not Run ('.')
         then
            return 0;
         end if;
         if not Spaces (0) or else not Word ("..") or else not Spaces (0) or else not Run (';')
           or else not Spaces (0)
         then
            return 0;
         end if;
         if J <= T'Length and then T (J) = ';' then
            return J;
         end if;
         return 0;
      end Match_At;
   begin
      Names := Text_Vectors.Empty_Vector;
      loop
         exit when From > T'Length;
         P := Lovelace_Word_Rules_Pkg.Next_Name_At_Or_After (T, "subtype", False, From);
         exit when P = 0;
         declare
            NF : Positive;
            NL : Natural;
            E  : constant Natural := Match_At (P, NF, NL);
         begin
            if E > 0 then
               Names.Append (Lower (T (NF .. NL)));
               From := E + 1;
            else
               From := P + 1;
            end if;
         end;
      end loop;
   end Subtype_Names;

   --  T6 [necessity.go:36-109]: the Pre-drop variants from t6-pre's aspect lists (rendered and
   --  fitted here), then the subtype-widening variants. The request is the stage request, then
   --  t6-pre's output: pres (count), and per variant aspects (count) and aspect.
   procedure Run_Stage is
      Pkg     : U.Unbounded_String;
      Text    : U.Unbounded_String;
      Extra   : U.Unbounded_String;
      Subject : Natural;
      Funcs   : Func_Vectors.Vector;
      Result  : U.Unbounded_String;
      Count   : Natural := 0;
      NP      : Natural;
      Pres    : Aspect_Lists.Vector;
   begin
      Read_Spec (Pkg, Text, Subject, Extra, Funcs);
      NP := Next_Count ("pres");
      for I in 1 .. NP loop
         exit when Bad;
         declare
            As : Text_Vectors.Vector;
            NA : constant Natural := Next_Count ("aspects");
         begin
            for K in 1 .. NA loop
               exit when Bad;
               As.Append (Next ("aspect"));
            end loop;
            Pres.Append (As);
         end;
      end loop;
      if Bad or else Pos /= U.Length (Req) + 1 then
         Bad := True;
         return;
      end if;
      declare
         F       : constant Func := Funcs (Subject);
         Name    : constant String := U.To_String (F.Name);
         Body_T  : constant String := U.To_String (F.Body_Text);
         Held    : constant U.Unbounded_String := Output;
         Ranges  : Text_Vectors.Vector;
         Variant : U.Unbounded_String;
         Lines   : Text_Vectors.Vector;
      begin
         Output := U.Null_Unbounded_String;
         for I in 1 .. Natural (Pres.Length) loop
            Split_Lines (U.To_String (Text), Lines);
            Fit (Lines, F.Decl_Line, F.Decl_End, Render_Function (F, F.Params, Body_T, Pres (I)));
            Write_Variant ("t6pre-" & Name & "-" & Decimal (I - 1), Join_Lines (Lines), Name,
                           F.Decl_Line, F.Decl_End);
            Count := Count + 1;
         end loop;
         Subtype_Names (U.To_String (Text), Ranges);
         for A of F.Aspects loop
            declare
               Arrow : Natural := 0;
            begin
               for K in A'First .. A'Last - 1 loop
                  if A (K .. K + 1) = "=>" then
                     Arrow := K;
                     exit;
                  end if;
               end loop;
               if Arrow > 0 and then Lovelace_Word_Rules_Pkg.Equal_CI (Trimmed (A (A'First .. Arrow - 1)), "Subprogram_Variant") then
                  Variant := U.To_Unbounded_String (A (Arrow + 2 .. A'Last));
               end if;
            end;
         end loop;
         for I in 1 .. Natural (F.Params.Length) loop
            declare
               P_Name : constant String := U.To_String (F.Params (I).Name);
               V      : constant String := U.To_String (Variant);
               VT     : constant String (1 .. V'Length) := V;
               Skip   : Boolean := False;
            begin
               if Has_Name (Ranges, Lower (U.To_String (F.Params (I).Kind))) then
                  if VT'Length > 0 and then P_Name'Length >= 1 and then P_Name'Length <= Lovelace_Word_Rules_Pkg.Max_Word
                    and then Lovelace_Word_Rules_Pkg.Keyword_At_Or_After (VT, P_Name, 1) /= 0
                  then
                     Skip := True;
                  end if;
                  if not Skip then
                     declare
                        Ps : Param_Vectors.Vector := F.Params;
                     begin
                        Ps.Replace_Element (I, Param'(Name => F.Params (I).Name,
                                                      Kind => U.To_Unbounded_String ("Integer")));
                        Split_Lines (U.To_String (Text), Lines);
                        Fit (Lines, F.Decl_Line, F.Decl_End, Render_Function (F, Ps, Body_T, F.Aspects));
                        if F.Body_Line > 0 and then F.Body_Line /= F.Decl_Line then
                           Fit (Lines, F.Body_Line, F.Body_End,
                                "function " & Name & Param_List (Ps) & " return " & U.To_String (F.Ret)
                                & " is (" & Body_T & ");");
                        end if;
                        Write_Variant ("t6sub-" & Name & "-" & P_Name, Join_Lines (Lines), Name,
                                       F.Decl_Line, F.Decl_End);
                        Count := Count + 1;
                     end;
                  end if;
               end if;
            end;
         end loop;
         Result := Output;
         Output := Held;
         Field ("variants", Decimal (Count));
         U.Append (Output, Result);
      end;
   end Run_Stage;

begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t6-sub: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      Ok : Boolean;
   begin
      Load (Ada.Command_Line.Argument (1), Ok);
      if not Ok then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t6-sub: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
   end;
   Run_Stage;
   if Bad then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t6-sub: malformed request");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   Emit;
   Ada.Command_Line.Set_Exit_Status (0);
end T6_Sub_Main;
