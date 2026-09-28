--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 820f45c083673c7b8991d38d8e2d6fc15dd777d690fc622846dd698cf0243c9b
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Lovelace_Utf8_Decode_Pkg;
with Lovelace_Lex_Rules_Pkg;
with Lovelace_Text_Rules_Pkg;
with Lovelace_Word_Rules_Pkg;

procedure Function_Scanner_Main is
   use type GNAT.OS_Lib.File_Descriptor;
   use type Lovelace_Text_Rules_Pkg.Text_Error;

   --  CLI contract:
   --    function_scanner_main <clean-spec-file>
   --  success, exit 0: per construct "construct K <kind> <line> <end line>" and its fields
   --  (word, blank, byte length, line end, bytes, line end), then "end"; on a parse error
   --  only "failure <length>" and the sentence. Usage or unreadable: standard error, exit 2.

   package U renames Ada.Strings.Unbounded;
   package Lex renames Lovelace_Lex_Rules_Pkg;

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
   package Txt renames Lovelace_Text_Rules_Pkg;
   package Wrd renames Lovelace_Word_Rules_Pkg;

   Max_Spec : constant := 262_144;
   LF : constant Character := Character'Val (10);

   function Decimal (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Decimal;

   procedure Scan (S : String; Out_Text : out U.Unbounded_String; Failure : out U.Unbounded_String) is
      W : Lex.Width_Array (1 .. S'Length);
      Mask : Lex.Mask_Array (1 .. S'Length);

      function Line_Of (P : Positive) return Positive is
         N : Positive := 1;
      begin
         for K in 1 .. Natural'Min (P - 1, S'Length) loop
            if S (K) = LF then
               N := N + 1;
            end if;
         end loop;
         return N;
      end Line_Of;

      function Is_Letter (C : Character) return Boolean is (C in 'A' .. 'Z' | 'a' .. 'z');

      --  Go's reIdent at I: a letter, then letters, digits and '_'; "" when none.
      function Ident_At (I : Positive) return String is
         J : Positive := I;
      begin
         if I > S'Length or else not Is_Letter (S (I)) then
            return "";
         end if;
         while J + 1 <= S'Length and then Wrd.Is_Word_Char (S (J + 1)) loop
            J := J + 1;
         end loop;
         return S (I .. J);
      end Ident_At;

      --  hasKeywordAt: Kw at I, and no identifier character right after it.
      function Keyword_At (I : Positive; Kw : String) return Boolean is
        (I <= S'Length and then Kw'Length <= S'Length - I + 1
         and then S (I .. I + Kw'Length - 1) = Kw
         and then (I + Kw'Length > S'Length or else not Wrd.Is_Word_Char (S (I + Kw'Length))));

      procedure Field (Key : String; Value : String) is
      begin
         U.Append (Out_Text, Key & " " & Decimal (Value'Length) & LF & Value & LF);
      end Field;

      Pos : Positive := 1;
      K   : Natural := 0;
   begin
      Out_Text := U.Null_Unbounded_String;
      Failure := U.Null_Unbounded_String;
      for I in 1 .. S'Length loop
         W (I) := Lovelace_Utf8_Decode_Pkg.Width_At (S, I);
      end loop;
      loop
         exit when Pos > S'Length + 1;
         declare
            P : constant Natural := Wrd.Keyword_At_Or_After (S, "function", Pos);
         begin
            exit when P = 0;
            declare
               Line   : constant String := Decimal (Line_Of (P));
               I      : Positive := Txt.Skip_WS (S, P + 8);
               Name   : constant String := Ident_At (I);
               Has_Formal : Boolean := False;
               Formal_F   : Positive := 1;
               Formal_L   : Natural := 0;
               Ret    : U.Unbounded_String;
               J      : Positive;
               Kind   : U.Unbounded_String;
               Body_F, Aspects_F, Renames_F : Positive := 1;
               Body_L, Aspects_L, Renames_L : Natural := 0;
               Has_Body, Has_Aspects, Has_Renames : Boolean := False;
               End_At : Positive;

               --  First top-level semicolon from A (a fresh mask from A). False on failure.
               function Until_Semicolon (A : Positive; F : out Positive; L : out Natural; Next : out Positive) return Boolean is
                  R : Txt.Semicolon_Result;
               begin
                  Fill_Mask (S, W, A, Mask);
                  R := Txt.First_Top_Semicolon (S, Mask, A);
                  F := R.Piece_First;
                  L := R.Piece_Last;
                  Next := R.Next;
                  return R.Error = Txt.No_Error;
               end Until_Semicolon;
            begin
               if Name = "" then
                  Failure := U.To_Unbounded_String ("line " & Line & ": function without a name");
                  return;
               end if;
               I := Txt.Skip_WS (S, I + Name'Length);
               if I <= S'Length and then S (I) = '(' then
                  Fill_Mask (S, W, I, Mask);
                  declare
                     G : constant Txt.Group_Result := Txt.Balanced_Group (S, Mask, I);
                  begin
                     if G.Error /= Txt.No_Error then
                        Failure := U.To_Unbounded_String ("line " & Line & ": " & Txt.Error_Text (G.Error, I));
                        return;
                     end if;
                     Has_Formal := True;
                     Formal_F := G.Inner_First;
                     Formal_L := G.Inner_Last;
                     I := Txt.Skip_WS (S, G.Next);
                  end;
               end if;
               if not (6 <= S'Length - I + 1 and then S (I .. I + 5) = "return") then
                  Failure := U.To_Unbounded_String ("line " & Line & ": function " & Name & ": expected `return`");
                  return;
               end if;
               I := Txt.Skip_WS (S, I + 6);
               Ret := U.To_Unbounded_String (Ident_At (I));
               J := I + U.Length (Ret);
               while J <= S'Length and then S (J) = '.' loop
                  declare
                     More : constant String := (if J + 1 <= S'Length then Ident_At (J + 1) else "");
                  begin
                     exit when More = "";
                     U.Append (Ret, "." & More);
                     J := J + 1 + More'Length;
                  end;
               end loop;
               I := Txt.Skip_WS (S, J);
               if Keyword_At (I, "with") then
                  if not Until_Semicolon (Txt.Skip_WS (S, I + 4), Aspects_F, Aspects_L, End_At) then
                     Failure := U.To_Unbounded_String ("line " & Line & ": function " & Name & ": no terminating semicolon");
                     return;
                  end if;
                  Has_Aspects := True;
                  Kind := U.To_Unbounded_String ("decl-aspects");
               elsif Keyword_At (I, "is") then
                  I := Txt.Skip_WS (S, I + 2);
                  if not (I <= S'Length and then S (I) = '(') then
                     Failure := U.To_Unbounded_String
                       ("line " & Line & ": function " & Name & ": completion is not an expression function");
                     return;
                  end if;
                  Fill_Mask (S, W, I, Mask);
                  declare
                     G : constant Txt.Group_Result := Txt.Balanced_Group (S, Mask, I);
                     N : Positive;
                  begin
                     if G.Error /= Txt.No_Error then
                        Failure := U.To_Unbounded_String
                          ("line " & Line & ": function " & Name & ": " & Txt.Error_Text (G.Error, I));
                        return;
                     end if;
                     declare
                        T : constant Txt.Piece := Txt.Trim (S, G.Inner_First, G.Inner_Last);
                     begin
                        Body_F := T.First;
                        Body_L := T.Last;
                        Has_Body := True;
                     end;
                     N := Txt.Skip_WS (S, G.Next);
                     if Keyword_At (N, "with") then
                        if not Until_Semicolon (Txt.Skip_WS (S, N + 4), Aspects_F, Aspects_L, End_At) then
                           Failure := U.To_Unbounded_String
                             ("line " & Line & ": function " & Name & ": no terminating semicolon");
                           return;
                        end if;
                        Has_Aspects := True;
                        Kind := U.To_Unbounded_String ("completion-aspects");
                     else
                        if N <= S'Length and then S (N) = ';' then
                           N := N + 1;
                        end if;
                        End_At := N;
                        Kind := U.To_Unbounded_String ("completion");
                     end if;
                  end;
               elsif Keyword_At (I, "renames") then
                  if not Until_Semicolon (Txt.Skip_WS (S, I + 7), Renames_F, Renames_L, End_At) then
                     Failure := U.To_Unbounded_String ("line " & Line & ": function " & Name & ": no terminating semicolon");
                     return;
                  end if;
                  Has_Renames := True;
                  Kind := U.To_Unbounded_String ("renames");
               elsif I <= S'Length and then S (I) = ';' then
                  End_At := I + 1;
                  Kind := U.To_Unbounded_String ("decl");
               else
                  Failure := U.To_Unbounded_String
                    ("line " & Line & ": function " & Name & ": expected `with`, `is` or `;`");
                  return;
               end if;
               K := K + 1;
               U.Append (Out_Text, "construct " & Decimal (K) & " " & U.To_String (Kind) & " " & Line & " "
                         & Decimal (Line_Of (End_At)) & LF);
               Field ("name", Name);
               if Has_Formal then
                  Field ("formal", S (Formal_F .. Formal_L));
               end if;
               Field ("ret", U.To_String (Ret));
               if Has_Body then
                  Field ("body", S (Body_F .. Body_L));
               end if;
               if Has_Aspects then
                  Field ("aspects", S (Aspects_F .. Aspects_L));
               end if;
               if Has_Renames then
                  Field ("renames", S (Renames_F .. Renames_L));
               end if;
               Pos := End_At;
            end;
         end;
      end loop;
      U.Append (Out_Text, "end" & LF);
   end Scan;

begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "function-scanner: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      FD : constant GNAT.OS_Lib.File_Descriptor :=
        GNAT.OS_Lib.Open_Read (Ada.Command_Line.Argument (1), GNAT.OS_Lib.Binary);
   begin
      if FD = GNAT.OS_Lib.Invalid_FD then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "function-scanner: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      if GNAT.OS_Lib.File_Length (FD) > Max_Spec then
         GNAT.OS_Lib.Close (FD);
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "function-scanner: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      declare
         S : String (1 .. Natural (GNAT.OS_Lib.File_Length (FD)));
         N : Integer := 0;
         Out_Text, Failure : U.Unbounded_String;
      begin
         if S'Length > 0 then
            N := GNAT.OS_Lib.Read (FD, S (1)'Address, S'Length);
         end if;
         GNAT.OS_Lib.Close (FD);
         if N /= S'Length then
            Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "function-scanner: cannot read");
            Ada.Command_Line.Set_Exit_Status (2);
            return;
         end if;
         Scan (S, Out_Text, Failure);
         if U.Length (Failure) > 0 then
            Ada.Text_IO.Put_Line ("failure " & Decimal (U.Length (Failure)));
            Ada.Text_IO.Put_Line (U.To_String (Failure));
         else
            declare
               T : constant String := U.To_String (Out_Text);
               Wr : Integer;
            begin
               Wr := GNAT.OS_Lib.Write (GNAT.OS_Lib.Standout, T (T'First)'Address, T'Length);
            end;
         end if;
      end;
      Ada.Command_Line.Set_Exit_Status (0);
   end;
end Function_Scanner_Main;
