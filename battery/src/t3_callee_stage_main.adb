--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 165967e1995d4a71daac3efd987f3131797512fc7c13b0f7e9aee7955bd3a369
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Vectors;
with GNAT.OS_Lib;
with Lovelace_Word_Rules_Pkg;
with Lovelace_Splice_Fit_Pkg;

procedure T3_Callee_Stage_Main is
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

   --  renderDecl [parse.go:412-418].
   function Render_Decl (F : Func; Ps : Param_Vectors.Vector; Aspects : Text_Vectors.Vector) return String is
     ("function " & U.To_String (F.Name) & Param_List (Ps) & " return " & U.To_String (F.Ret)
      & Aspect_Part (Aspects) & ";");

   --  renderFunction [parse.go:427-436].
   function Render_Function (F : Func; Ps : Param_Vectors.Vector; Body_Text : String;
                             Aspects : Text_Vectors.Vector) return String is
     ("function " & U.To_String (F.Name) & Param_List (Ps) & " return " & U.To_String (F.Ret)
      & (if F.Combined then " is (" & Body_Text & ")" else "") & Aspect_Part (Aspects) & ";");

   --  callees [parse.go:560-573]: the names of the other functions (exact name /= Self) that
   --  occur in Expr as a whole name in any case (word-rules' Contains_Name), in table order.
   procedure Callees (Expr : String; Funcs : Func_Vectors.Vector; Self : String;
                      Names : out Text_Vectors.Vector) is
      E : constant String (1 .. Expr'Length) := Expr;
   begin
      Names := Text_Vectors.Empty_Vector;
      for G of Funcs loop
         declare
            N : constant String := U.To_String (G.Name);
         begin
            if N /= Self and then N'Length >= 1 and then N'Length <= Lovelace_Word_Rules_Pkg.Max_Word
              and then Lovelace_Word_Rules_Pkg.Contains_Name (E, N, False)
            then
               Names.Append (N);
            end if;
         end;
      end loop;
   end Callees;

   function Has_Name (Names : Text_Vectors.Vector; N : String) return Boolean is
   begin
      for M of Names loop
         if M = N then
            return True;
         end if;
      end loop;
      return False;
   end Has_Name;

   --  One derived variant: its tag, its text, and its mark (key, first line, last line).
   procedure Write_Variant (Tag : String; Text : String; Key : String; From : Natural; To : Natural) is
   begin
      Field ("tag", Tag);
      Field ("text", Text);
      Field ("mark", Key & " " & Decimal (From) & " " & Decimal (To));
   end Write_Variant;
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
   --  deriveT3Callees [derive.go:285-324], for a predicate only: ONE variant in which every
   --  function its body names (the last of that name) that has a completion keeps its
   --  declaration and contract, rendered with Import, Global => null first, and loses its body.
   procedure Run_Stage is
      Pkg     : U.Unbounded_String;
      Text    : U.Unbounded_String;
      Extra   : U.Unbounded_String;
      Subject : Natural;
      Funcs   : Func_Vectors.Vector;
      Targets : Text_Vectors.Vector;
      Lines   : Text_Vectors.Vector;
   begin
      Read_Spec (Pkg, Text, Subject, Extra, Funcs);
      if Bad then
         return;
      end if;
      declare
         F : constant Func := Funcs (Subject);
      begin
         if not Is_Predicate (F) then
            Field ("variants", "0");
            return;
         end if;
         Callees (U.To_String (F.Body_Text), Funcs, U.To_String (F.Name), Targets);
         if Targets.Is_Empty then
            Field ("variants", "0");
            return;
         end if;
         Split_Lines (U.To_String (Text), Lines);
         for T of Targets loop
            declare
               G_Index : Natural := 0;
            begin
               for K in 1 .. Natural (Funcs.Length) loop
                  if U.To_String (Funcs (K).Name) = T then
                     G_Index := K;
                  end if;
               end loop;
               if G_Index > 0 and then Funcs (G_Index).Body_Line /= 0 then
                  declare
                     G       : constant Func := Funcs (G_Index);
                     Aspects : Text_Vectors.Vector;
                  begin
                     Aspects.Append ("Import");
                     Aspects.Append ("Global => null");
                     Aspects.Append (G.Aspects);
                     Fit (Lines, G.Decl_Line, G.Decl_End, Render_Decl (G, G.Params, Aspects));
                     if G.Body_Line /= G.Decl_Line then
                        Blank (Lines, G.Body_Line, G.Body_End);
                     end if;
                  end;
               end if;
            end;
         end loop;
         Field ("variants", "1");
         Write_Variant ("t3c-" & U.To_String (F.Name), Join_Lines (Lines),
                        U.To_String (F.Name) & "#contracts-only", F.Decl_Line, F.Decl_End);
      end;
   end Run_Stage;

begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t3-callee-stage: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      Ok : Boolean;
   begin
      Load (Ada.Command_Line.Argument (1), Ok);
      if not Ok then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t3-callee-stage: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
   end;
   Run_Stage;
   if Bad then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "t3-callee-stage: malformed request");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   Emit;
   Ada.Command_Line.Set_Exit_Status (0);
end T3_Callee_Stage_Main;
