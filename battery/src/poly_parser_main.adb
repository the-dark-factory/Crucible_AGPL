--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: db47984507250872d261b5c07d7bd446cff04c7e2f6f1863b24453e9970df015
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with Ada.Containers.Vectors;
with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Indefinite_Ordered_Maps;
with Interfaces;
with GNAT.OS_Lib;
with Lovelace_Poly_Arith_Pkg;
with Lovelace_Expr_Token_Pkg;
with Lovelace_Word_Rules_Pkg;

procedure Poly_Parser_Main is
   use type GNAT.OS_Lib.File_Descriptor;
   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_64;
   use type Lovelace_Expr_Token_Pkg.Token_Kind;

   --  CLI contract:
   --    poly_parser_main <request-file>
   --  The request is NUL-separated fields: F, then per function name, boolean, body, P and P
   --  parameter names; then C, then per conjunct op, lhs, rhs.
   --  success, exit 0: one line "residual <Go's poly text> <op> 0" per conjunct; or "settled"
   --  when any side does not normalise; or "settled bound" when a step passes poly-arith's bounds
   --  (32 terms, 8 atoms a term, 256-byte atoms) or the arena's 4096 polys (lane-own; Go has none).
   --  usage or a malformed request: one line on standard error, exit 2.

   package U renames Ada.Strings.Unbounded;
   package PA renames Lovelace_Poly_Arith_Pkg;
   package Tok renames Lovelace_Expr_Token_Pkg;

   Max_Request : constant := 1_048_576;
   Max_Arena   : constant := 4_096;
   Max_Depth   : constant := 8;
   Sep         : constant String := Character'Val (16#C2#) & Character'Val (16#B7#);

   --  THE ARENA. Every Poly (about 67 KB) lives here, on the heap; everything else holds indices.
   package Poly_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => PA.Poly, "=" => PA."=");
   Arena : Poly_Vectors.Vector;

   package Field_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);

   type Func is record
      Name    : U.Unbounded_String;
      Is_Bool : Boolean := False;
      Body_T  : U.Unbounded_String;
      Params  : Field_Vectors.Vector;
   end record;

   package Func_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Func);
   package Name_Maps is new Ada.Containers.Indefinite_Ordered_Maps (Key_Type => String, Element_Type => Positive);
   package Env_Maps is new Ada.Containers.Indefinite_Ordered_Maps (Key_Type => String, Element_Type => Positive);

   Funcs   : Func_Vectors.Vector;
   By_Name : Name_Maps.Map;
   Depth   : Natural := 0;
   Failed  : Boolean := False;
   At_Bound : Boolean := False;

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

   function Image (C : Interfaces.Integer_64) return String is
      S : constant String := Interfaces.Integer_64'Image (C);
   begin
      if S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Image;

   function Keep (P : PA.Poly) return Natural is
   begin
      if Natural (Arena.Length) >= Max_Arena then
         At_Bound := True;
         return 0;
      end if;
      Arena.Append (P);
      return Natural (Arena.Length);
   end Keep;

   function Const (C : Interfaces.Integer_64) return Natural is (Keep (PA.Constant_Poly (C)));

   function Atom (Name : String) return Natural is
      A : PA.Atom := PA.Empty_Atom;
   begin
      if Name'Length > PA.Max_Atom_Length then
         At_Bound := True;
         return 0;
      end if;
      A.Length := Name'Length;
      A.Text (1 .. Name'Length) := Name;
      return Keep (PA.Atom_Poly (A));
   end Atom;

   --  p.add(q, sign): Add, refused as a bound when the two hold more than 32 terms together.
   function Add (A : Positive; B : Positive; Negate : Boolean) return Natural is
      P : constant PA.Poly := Arena (A);
      Q : constant PA.Poly := Arena (B);
   begin
      if P.Count + Q.Count > PA.Max_Terms then
         At_Bound := True;
         return 0;
      end if;
      return Keep (PA.Add (P, Q, Negate));
   end Add;

   --  p.mul(q): Multiply, refused as a bound when Can_Multiply does not hold.
   function Mul (A : Positive; B : Positive) return Natural is
      P : constant PA.Poly := Arena (A);
      Q : constant PA.Poly := Arena (B);
   begin
      if not PA.Can_Multiply (P, Q) then
         At_Bound := True;
         return 0;
      end if;
      return Keep (PA.Multiply (P, Q));
   end Mul;

   --  A key as Go's map key: its atoms joined by U+00B7 ("" for the constant term).
   function Joined (K : PA.Key; With_Star : Boolean) return String is
      R : U.Unbounded_String;
   begin
      for I in 1 .. K.Count loop
         if I > 1 then
            U.Append (R, (if With_Star then "*" else Sep));
         end if;
         U.Append (R, K.Atoms (I).Text (1 .. K.Atoms (I).Length));
      end loop;
      return U.To_String (R);
   end Joined;

   --  poly.String [normalise.go:69-103]: terms by Go's byte order of the joined key.
   function Render (I : Positive) return String is
      P     : constant PA.Poly := Arena (I);
      Order : array (1 .. PA.Max_Terms) of Natural := (others => 0);
      R     : U.Unbounded_String;
   begin
      if P.Count = 0 then
         return "0";
      end if;
      for K in 1 .. P.Count loop
         Order (K) := K;
      end loop;
      for K in 2 .. P.Count loop
         declare
            J : Natural := K;
            T : Natural;
         begin
            while J > 1 and then Joined (P.Terms (Order (J)).K, False) < Joined (P.Terms (Order (J - 1)).K, False) loop
               T := Order (J);
               Order (J) := Order (J - 1);
               Order (J - 1) := T;
               J := J - 1;
            end loop;
         end;
      end loop;
      for K in 1 .. P.Count loop
         declare
            Term : constant PA.Term := P.Terms (Order (K));
            C    : Interfaces.Integer_64 := PA.Signed_Value (Term.Coefficient);
         begin
            if K > 1 then
               if C < 0 then
                  U.Append (R, " - ");
                  if C /= Interfaces.Integer_64'First then
                     C := -C;
                  end if;
               else
                  U.Append (R, " + ");
               end if;
            elsif C < 0 then
               U.Append (R, "-");
               if C /= Interfaces.Integer_64'First then
                  C := -C;
               end if;
            end if;
            if Term.K.Count = 0 then
               U.Append (R, Image (C));
            elsif C = 1 then
               U.Append (R, Joined (Term.K, True));
            else
               U.Append (R, Image (C) & "*" & Joined (Term.K, True));
            end if;
         end;
      end loop;
      return U.To_String (R);
   end Render;

   --  isRecursive [normalise.go:368-371]: the body names the function itself.
   function Is_Recursive (F : Func) return Boolean is
      Name : constant String := U.To_String (F.Name);
      B    : constant String := U.To_String (F.Body_T);
      T    : constant String (1 .. B'Length) := B;
   begin
      return Lovelace_Word_Rules_Pkg.Contains_Name (T, Name, False);
   end Is_Recursive;

   type Token is record
      Kind : Tok.Token_Kind := Tok.Bad_Kind;
      Text : U.Unbounded_String;
   end record;

   package Token_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Token);

   --  tokenize [normalise.go:145-188] through the expr-token core. Ok is False on a bad byte.
   procedure Tokenize (S : String; Toks : out Token_Vectors.Vector; Ok : out Boolean) is
      T : constant String (1 .. S'Length) := S;
      I : Positive := 1;
      L : Positive;
   begin
      Toks := Token_Vectors.Empty_Vector;
      Ok := True;
      while I <= T'Length loop
         L := Tok.Token_Last (T, I);
         case Tok.Kind_At (T, I) is
            when Tok.Bad_Kind =>
               Ok := False;
               return;
            when Tok.Space_Kind =>
               null;
            when Tok.Num_Kind =>
               declare
                  D : U.Unbounded_String;
               begin
                  for J in I .. L loop
                     if T (J) /= '_' then
                        U.Append (D, T (J));
                     end if;
                  end loop;
                  Toks.Append (Token'(Kind => Tok.Num_Kind, Text => D));
               end;
            when Tok.Id_Kind =>
               if Tok.Is_Word_Op (T, I, L) then
                  Toks.Append (Token'(Kind => Tok.Op_Kind, Text => U.To_Unbounded_String (Tok.Word_Op_Text (T, I, L))));
               else
                  Toks.Append (Token'(Kind => Tok.Id_Kind, Text => U.To_Unbounded_String (T (I .. L))));
               end if;
            when others =>
               Toks.Append (Token'(Kind => Tok.Kind_At (T, I), Text => U.To_Unbounded_String (T (I .. L))));
         end case;
         I := L + 1;
      end loop;
   end Tokenize;

   --  normaliseExpr [normalise.go:215-366]. 0 when it fails (Failed) or meets a bound (At_Bound).
   function Normalise (Expr : String; Env : Env_Maps.Map) return Natural is
      Toks : Token_Vectors.Vector;
      Ok   : Boolean;
      P    : Positive := 1;

      function Stopped return Boolean is (Failed or else At_Bound);

      function Peek_Kind return Tok.Token_Kind is
        (if P <= Natural (Toks.Length) then Toks (P).Kind else Tok.Space_Kind);

      function Peek_Is (Kind : Tok.Token_Kind; Text : String) return Boolean is
        (P <= Natural (Toks.Length) and then Toks (P).Kind = Kind and then U.To_String (Toks (P).Text) = Text);

      function At_End return Boolean is (P > Natural (Toks.Length));

      function Expr_P return Natural;

      function Factor return Natural is
      begin
         if At_End then
            Failed := True;
            return 0;
         end if;
         declare
            T    : constant Token := Toks (P);
            Text : constant String := U.To_String (T.Text);
         begin
            P := P + 1;
            case T.Kind is
               when Tok.Num_Kind =>
                  declare
                     V : Interfaces.Unsigned_64 := 0;
                  begin
                     if Text'Length > 19 then
                        Failed := True;
                        return 0;
                     end if;
                     for C of Text loop
                        V := V * 10 + Interfaces.Unsigned_64 (Character'Pos (C) - Character'Pos ('0'));
                     end loop;
                     if V > 9_223_372_036_854_775_807 then
                        Failed := True;
                        return 0;
                     end if;
                     return Const (Interfaces.Integer_64 (V));
                  end;
               when Tok.Op_Kind =>
                  if Text = "-" then
                     declare
                        F : constant Natural := Factor;
                        Z : Natural;
                     begin
                        if Stopped then
                           return 0;
                        end if;
                        Z := Const (0);
                        if Stopped then
                           return 0;
                        end if;
                        return Add (Z, F, True);
                     end;
                  elsif Text = "+" then
                     return Factor;
                  end if;
                  Failed := True;
                  return 0;
               when Tok.Lp_Kind =>
                  declare
                     E : constant Natural := Expr_P;
                  begin
                     if Stopped then
                        return 0;
                     end if;
                     if At_End or else Toks (P).Kind /= Tok.Rp_Kind then
                        Failed := True;
                        return 0;
                     end if;
                     P := P + 1;
                     if Peek_Is (Tok.Op_Kind, "**") then
                        Failed := True;
                        return 0;
                     end if;
                     return E;
                  end;
               when Tok.Id_Kind =>
                  if Peek_Is (Tok.Op_Kind, "**") then
                     Failed := True;
                     return 0;
                  end if;
                  if Env.Contains (Text) then
                     return Env.Element (Text);
                  end if;
                  declare
                     Has_Tick : Boolean := False;
                  begin
                     for C of Text loop
                        if C = ''' then
                           Has_Tick := True;
                        end if;
                     end loop;
                     if Has_Tick and then Peek_Kind /= Tok.Lp_Kind then
                        return Atom (Text);
                     end if;
                     if Peek_Kind = Tok.Lp_Kind and then not At_End then
                        P := P + 1;
                        declare
                           Args : Field_Vectors.Vector;
                           Idx  : Env_Maps.Map;
                           Arg_Ids : array (1 .. 64) of Natural := (others => 0);
                           N    : Natural := 0;
                        begin
                           loop
                              declare
                                 A : constant Natural := Expr_P;
                              begin
                                 if Stopped then
                                    return 0;
                                 end if;
                                 if N = Arg_Ids'Last then
                                    At_Bound := True;
                                    return 0;
                                 end if;
                                 N := N + 1;
                                 Arg_Ids (N) := A;
                              end;
                              if Peek_Kind = Tok.Comma_Kind and then not At_End then
                                 P := P + 1;
                              else
                                 exit;
                              end if;
                           end loop;
                           if At_End or else Toks (P).Kind /= Tok.Rp_Kind then
                              Failed := True;
                              return 0;
                           end if;
                           P := P + 1;
                           if By_Name.Contains (Lower (Text)) and then not Has_Tick then
                              declare
                                 F : constant Func := Funcs (By_Name.Element (Lower (Text)));
                              begin
                                 if U.Length (F.Body_T) > 0 and then Natural (F.Params.Length) = N
                                   and then not F.Is_Bool and then not Is_Recursive (F) and then Depth < Max_Depth
                                 then
                                    for K in 1 .. N loop
                                       Idx.Include (F.Params (K), Arg_Ids (K));
                                    end loop;
                                    Depth := Depth + 1;
                                    declare
                                       R : constant Natural := Normalise (U.To_String (F.Body_T), Idx);
                                    begin
                                       Depth := Depth - 1;
                                       return R;
                                    end;
                                 end if;
                              end;
                           end if;
                           declare
                              Name : U.Unbounded_String := U.To_Unbounded_String (Text & "(");
                           begin
                              for K in 1 .. N loop
                                 if K > 1 then
                                    U.Append (Name, ",");
                                 end if;
                                 U.Append (Name, Render (Arg_Ids (K)));
                              end loop;
                              U.Append (Name, ")");
                              return Atom (U.To_String (Name));
                           end;
                        end;
                     end if;
                     return Atom (Text);
                  end;
               when others =>
                  Failed := True;
                  return 0;
            end case;
         end;
      end Factor;

      function Term return Natural is
         Left : Natural := Factor;
      begin
         loop
            if Stopped then
               return 0;
            end if;
            exit when not (Peek_Is (Tok.Op_Kind, "*") or else Peek_Is (Tok.Op_Kind, "/")
                           or else Peek_Is (Tok.Op_Kind, "mod") or else Peek_Is (Tok.Op_Kind, "rem"));
            declare
               Op    : constant String := U.To_String (Toks (P).Text);
               Right : Natural;
            begin
               P := P + 1;
               Right := Factor;
               if Stopped then
                  return 0;
               end if;
               if Op = "*" then
                  Left := Mul (Left, Right);
               else
                  Left := Atom ("(" & Render (Left) & ")" & Op & "(" & Render (Right) & ")");
               end if;
            end;
         end loop;
         return Left;
      end Term;

      function Expr_P return Natural is
         Left : Natural := Term;
      begin
         loop
            if Stopped then
               return 0;
            end if;
            exit when not (Peek_Is (Tok.Op_Kind, "+") or else Peek_Is (Tok.Op_Kind, "-"));
            declare
               Minus : constant Boolean := U.To_String (Toks (P).Text) = "-";
               Right : Natural;
            begin
               P := P + 1;
               Right := Term;
               if Stopped then
                  return 0;
               end if;
               Left := Add (Left, Right, Minus);
            end;
         end loop;
         return Left;
      end Expr_P;

   begin
      Tokenize (Expr, Toks, Ok);
      if not Ok then
         Failed := True;
         return 0;
      end if;
      declare
         R : constant Natural := Expr_P;
      begin
         if Stopped then
            return 0;
         end if;
         if not At_End then
            Failed := True;
            return 0;
         end if;
         return R;
      end;
   end Normalise;

   --  The request's fields, split at NUL; k NULs give k + 1 fields.
   procedure Split (S : String; F : out Field_Vectors.Vector) is
      Start : Positive := S'First;
   begin
      F := Field_Vectors.Empty_Vector;
      for I in S'Range loop
         if S (I) = Character'Val (0) then
            F.Append (S (Start .. I - 1));
            Start := I + 1;
         end if;
      end loop;
      F.Append (S (Start .. S'Last));
   end Split;

   function Count_Of (S : String; Ok : in out Boolean) return Natural is
      N : Natural := 0;
   begin
      if S'Length < 1 or else S'Length > 7 or else (S'Length > 1 and then S (S'First) = '0') then
         Ok := False;
         return 0;
      end if;
      for C of S loop
         if C not in '0' .. '9' then
            Ok := False;
            return 0;
         end if;
         N := N * 10 + (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      return N;
   end Count_Of;

   function Word_Ok (S : String) return Boolean is
   begin
      if S'Length < 1 or else S'Length > Lovelace_Word_Rules_Pkg.Max_Word then
         return False;
      end if;
      for C of S loop
         if not Lovelace_Word_Rules_Pkg.Is_Word_Char (C) then
            return False;
         end if;
      end loop;
      return True;
   end Word_Ok;

   procedure Fail (Msg : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "poly-parser: " & Msg);
      Ada.Command_Line.Set_Exit_Status (2);
   end Fail;

begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Fail ("usage");
      return;
   end if;
   declare
      FD : constant GNAT.OS_Lib.File_Descriptor :=
        GNAT.OS_Lib.Open_Read (Ada.Command_Line.Argument (1), GNAT.OS_Lib.Binary);
   begin
      if FD = GNAT.OS_Lib.Invalid_FD then
         Fail ("cannot read");
         return;
      end if;
      if GNAT.OS_Lib.File_Length (FD) > Max_Request then
         GNAT.OS_Lib.Close (FD);
         Fail ("cannot read");
         return;
      end if;
      declare
         Buf : String (1 .. Natural (GNAT.OS_Lib.File_Length (FD)));
         N   : Integer := 0;
         F   : Field_Vectors.Vector;
         K   : Positive := 1;
         Ok  : Boolean := True;
         Out_Text : U.Unbounded_String;

         function Next return String is
         begin
            if K > Natural (F.Length) then
               Ok := False;
               return "";
            end if;
            K := K + 1;
            return F (K - 1);
         end Next;

         type Conj is record
            Op, Lhs, Rhs : U.Unbounded_String;
         end record;
         package Conj_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Conj);
         Conjs : Conj_Vectors.Vector;
      begin
         if Buf'Length > 0 then
            N := GNAT.OS_Lib.Read (FD, Buf (1)'Address, Buf'Length);
         end if;
         GNAT.OS_Lib.Close (FD);
         if N /= Buf'Length then
            Fail ("cannot read");
            return;
         end if;
         Split (Buf, F);
         declare
            NF : constant Natural := Count_Of (Next, Ok);
         begin
            for I in 1 .. NF loop
               exit when not Ok;
               declare
                  Fn : Func;
                  NP : Natural;
               begin
                  Fn.Name := U.To_Unbounded_String (Next);
                  declare
                     B : constant String := Next;
                  begin
                     if B /= "true" and then B /= "false" then
                        Ok := False;
                     end if;
                     Fn.Is_Bool := B = "true";
                  end;
                  Fn.Body_T := U.To_Unbounded_String (Next);
                  NP := Count_Of (Next, Ok);
                  for J in 1 .. NP loop
                     exit when not Ok;
                     Fn.Params.Append (Next);
                  end loop;
                  if not Word_Ok (U.To_String (Fn.Name)) then
                     Ok := False;
                  end if;
                  Funcs.Append (Fn);
                  By_Name.Include (Lower (U.To_String (Fn.Name)), Natural (Funcs.Length));
               end;
            end loop;
         end;
         if Ok then
            declare
               NC : constant Natural := Count_Of (Next, Ok);
            begin
               for I in 1 .. NC loop
                  exit when not Ok;
                  declare
                     C : Conj;
                  begin
                     C.Op := U.To_Unbounded_String (Next);
                     C.Lhs := U.To_Unbounded_String (Next);
                     C.Rhs := U.To_Unbounded_String (Next);
                     Conjs.Append (C);
                  end;
               end loop;
            end;
         end if;
         if not Ok or else K /= Natural (F.Length) + 1 then
            Fail ("malformed request");
            return;
         end if;
         for C of Conjs loop
            declare
               Empty : Env_Maps.Map;
               L     : constant Natural := Normalise (U.To_String (C.Lhs), Empty);
               R     : Natural := 0;
               D     : Natural := 0;
            begin
               if not (Failed or else At_Bound) then
                  R := Normalise (U.To_String (C.Rhs), Empty);
               end if;
               if not (Failed or else At_Bound) then
                  D := Add (L, R, True);
               end if;
               exit when Failed or else At_Bound;
               declare
                  Op_Raw : constant String := U.To_String (C.Op);
                  Op     : constant String (1 .. Op_Raw'Length) := Op_Raw;
                  A      : constant Positive := Lovelace_Word_Rules_Pkg.First_Non_Trim (Op, 1, Op'Length);
                  Z      : constant Natural := Lovelace_Word_Rules_Pkg.Last_Non_Trim (Op, A, Op'Length);
               begin
                  U.Append (Out_Text, "residual " & Render (D) & " " & Op (A .. Z) & " 0" & Character'Val (10));
               end;
            end;
         end loop;
         if At_Bound then
            Ada.Text_IO.Put_Line ("settled bound");
         elsif Failed then
            Ada.Text_IO.Put_Line ("settled");
         else
            declare
               S : constant String := U.To_String (Out_Text);
               W : Integer;
            begin
               if S'Length > 0 then
                  W := GNAT.OS_Lib.Write (GNAT.OS_Lib.Standout, S (S'First)'Address, S'Length);
               end if;
            end;
         end if;
         Ada.Command_Line.Set_Exit_Status (0);
      end;
   end;
end Poly_Parser_Main;
