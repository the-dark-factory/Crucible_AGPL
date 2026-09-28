--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 05473281e2b2627a849741f265a83d0ca36006a03cbb6d49cc9a9880b0ae4e19
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Vectors;
with GNAT.OS_Lib;
with Lovelace_Word_Rules_Pkg;

procedure Lemma_Builder_Main is
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

   type Lemma is record
      Key    : U.Unbounded_String;
      Name   : U.Unbounded_String;
      Params : Param_Vectors.Vector;
      Pre    : U.Unbounded_String;
      Post   : U.Unbounded_String;
   end record;

   package Lemma_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Lemma);

   --  endIndex [derive.go:19-27]: the first (?i)\bend\s+<Package>\s*; in T, 0 when none. "end" and
   --  the package are whole names in any case (word-rules' Name_At); \s is RE2's (no VT).
   function End_Index (T : String; Pkg : String) return Natural is
      From : Positive := 1;
      P    : Natural;
      J    : Positive;
   begin
      loop
         exit when From > T'Length;
         P := Lovelace_Word_Rules_Pkg.Next_Name_At_Or_After (T, "end", False, From);
         exit when P = 0;
         J := P + 3;
         if J <= T'Length and then Lovelace_Word_Rules_Pkg.Is_Collapse_Space (T (J)) then
            while J <= T'Length and then Lovelace_Word_Rules_Pkg.Is_Collapse_Space (T (J)) loop
               J := J + 1;
            end loop;
            if J <= T'Length and then Lovelace_Word_Rules_Pkg.Name_At (T, J, Pkg, False) then
               J := J + Pkg'Length;
               while J <= T'Length and then Lovelace_Word_Rules_Pkg.Is_Collapse_Space (T (J)) loop
                  J := J + 1;
               end loop;
               if J <= T'Length and then T (J) = ';' then
                  return P;
               end if;
            end if;
         end if;
         From := P + 1;
      end loop;
      return 0;
   end End_Index;

   function Count_LF (S : U.Unbounded_String) return Natural is
      N : Natural := 0;
   begin
      for I in 1 .. U.Length (S) loop
         if U.Element (S, I) = LF then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Count_LF;

   --  withLemmas [derive.go:29-64]: the lemmas appended before `end <Package>;`, each lemma's Post
   --  line recorded. The request's fields after the lemmas (tc's "witnessed") are not read.
   procedure Run_Stage is
      Lemmas : Lemma_Vectors.Vector;
      N      : Natural;
   begin
      declare
         Pkg  : constant String := Next ("package");
         Raw  : constant String := Next ("text");
         T    : constant String (1 .. Raw'Length) := Raw;
         Tag  : constant String := Next ("tag");
      begin
         N := Next_Count ("lemmas");
         for I in 1 .. N loop
            exit when Bad;
            declare
               L  : Lemma;
               NP : Natural;
            begin
               L.Key := U.To_Unbounded_String (Next ("key"));
               L.Name := U.To_Unbounded_String (Next ("lname"));
               NP := Next_Count ("params");
               for K in 1 .. NP loop
                  exit when Bad;
                  declare
                     P : Param;
                  begin
                     P.Name := U.To_Unbounded_String (Next ("pname"));
                     P.Kind := U.To_Unbounded_String (Next ("ptype"));
                     L.Params.Append (P);
                  end;
               end loop;
               L.Pre := U.To_Unbounded_String (Next ("pre"));
               L.Post := U.To_Unbounded_String (Next ("lpost"));
               declare
                  Note : constant String := Next ("note");
               begin
                  null;
               end;
               Lemmas.Append (L);
            end;
         end loop;
         if Bad or else Tag = "" or else Pkg'Length > Lovelace_Word_Rules_Pkg.Max_Word then
            Bad := True;
            return;
         end if;
         declare
            Ei    : constant Natural := End_Index (T, Pkg);
            Sb    : U.Unbounded_String;
            Marks : U.Unbounded_String;
         begin
            if Ei = 0 then
               Field ("failure", "no `end " & Pkg & ";` found");
               return;
            end if;
            Sb := U.To_Unbounded_String (T (1 .. Ei - 1));
            for L of Lemmas loop
               declare
                  Plist : constant String := Param_List (L.Params);
               begin
                  U.Append (Sb, LF & "   procedure " & U.To_String (L.Name) & Plist & LF & "     with Ghost");
                  if U.Length (L.Pre) > 0 then
                     U.Append (Sb, "," & LF & "          Pre  => " & U.To_String (L.Pre));
                  end if;
                  U.Append (Sb, "," & LF & "          Post => ");
                  U.Append (Marks, "mark " & Decimal (U.Length (L.Key) + 1 + Decimal (Count_LF (Sb) + 1)'Length)
                            & LF & U.To_String (L.Key) & " " & Decimal (Count_LF (Sb) + 1) & LF);
                  U.Append (Sb, U.To_String (L.Post) & ";" & LF & "   procedure " & U.To_String (L.Name) & Plist
                            & " is null;" & LF);
               end;
            end loop;
            U.Append (Sb, LF & T (Ei .. T'Length));
            Field ("text", U.To_String (Sb));
            U.Append (Output, Marks);
         end;
      end;
   end Run_Stage;

begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "lemma-builder: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      Ok : Boolean;
   begin
      Load (Ada.Command_Line.Argument (1), Ok);
      if not Ok then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "lemma-builder: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
   end;
   Run_Stage;
   if Bad then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "lemma-builder: malformed request");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   Emit;
   Ada.Command_Line.Set_Exit_Status (0);
end Lemma_Builder_Main;
