--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1314b4e26803caa4850895861347d2fab66aa726d340c738eab85e3df566af21
--
package Duplicate_Completion_Pkg with SPARK_Mode is

   Max_Text : constant := 65_536;
   Max_Word : constant := 32;

   type Body_State is (Outside, Head, Expr_Form, Full_Form);

   type Body_Scan is record
      state      : Body_State;
      name_first : Natural;
      name_last  : Natural;
      blank      : Boolean;
   end record;

   Fresh : constant Body_Scan := (state => Outside, name_first => 0, name_last => 0, blank => False);

   function Is_Upper (C : Character) return Boolean is
     (C in 'A' .. 'Z')
     with Pre => True;

   function Lower_Eq (A : Character; B : Character) return Boolean is
     (A = B or else (Is_Upper (A) and then Character'Pos (A) + 32 = Character'Pos (B)) or else (Is_Upper (B) and then Character'Pos (B) + 32 = Character'Pos (A)))
     with Pre => True;

   function Is_Ident_Char (C : Character) return Boolean is
     (C in 'A' .. 'Z' or else C in 'a' .. 'z' or else C in '0' .. '9' or else C = '_')
     with Pre => True;

   function Is_Blank (C : Character) return Boolean is
     (C = ' ' or else C = Character'Val (9))
     with Pre => True;

   function Starts_With_CI (T : String; P : Positive; Pattern : String) return Boolean is
     (P + Pattern'Length - 1 <= T'Length and then
      (for all K in 0 .. Pattern'Length - 1 => Lower_Eq (T (P + K), Pattern (1 + K))))
     with Pre => T'First = 1 and then T'Length <= Max_Text and then Pattern'First = 1
                 and then Pattern'Length >= 1 and then Pattern'Length <= Max_Word
                 and then P <= T'Length + 1;

   function Token_At (T : String; P : Positive; Word : String) return Boolean is
     (Starts_With_CI (T, P, Word) and then
      (P = 1 or else not Is_Ident_Char (T (P - 1))) and then
      (P + Word'Length > T'Length or else not Is_Ident_Char (T (P + Word'Length))))
     with Pre => T'First = 1 and then T'Length <= Max_Text and then Word'First = 1
                 and then Word'Length >= 1 and then Word'Length <= Max_Word
                 and then P <= T'Length + 1;

   function Same_Ident (A : String; AF : Positive; AL : Positive; B : String; BF : Positive; BL : Positive) return Boolean is
     (AL - AF = BL - BF and then
      (for all K in 0 .. AL - AF => Lower_Eq (A (AF + K), B (BF + K))))
     with Pre => A'First = 1 and then A'Length <= Max_Text and then B'First = 1 and then B'Length <= Max_Text
                 and then AF <= AL and then AL <= A'Length and then BF <= BL and then BL <= B'Length;

   function Ident_Span (T : String; P : Positive; E : Positive; Line_Last : Positive) return Boolean is
     (P <= E and then E <= Line_Last and then
      (for all K in P .. E => Is_Ident_Char (T (K))) and then
      (E = Line_Last or else not Is_Ident_Char (T (E + 1))))
     with Pre => T'First = 1 and then T'Length <= Max_Text and then Line_Last <= T'Length;

   function Function_Name_Span (T : String; Line_First : Positive; Line_Last : Positive; P : Positive; E : Positive) return Boolean is
     (P <= Line_Last and then P >= Line_First + 9 and then
      (for some F in Line_First .. P - 9 =>
         Token_At (T, F, "function") and then
         (for all K in F + 8 .. P - 1 => Is_Blank (T (K)))) and then
      Ident_Span (T, P, E, Line_Last))
     with Pre => T'First = 1 and then T'Length <= Max_Text and then Line_First >= 1 and then Line_First <= Line_Last and then Line_Last <= T'Length;

   function Paren_After (T : String; I : Positive; Line_Last : Positive) return Boolean is
     ((for some Q in I + 2 .. Line_Last =>
        (for all K in I + 2 .. Q - 1 => Is_Blank (T (K))) and then T (Q) = '('))
     with Pre => T'First = 1 and then T'Length <= Max_Text and then Line_Last <= T'Length and then I <= Line_Last;

   function Has_Is_Paren (T : String; Line_First : Positive; Line_Last : Positive) return Boolean is
     ((for some I in Line_First .. Line_Last =>
        Token_At (T, I, "is") and then
        (for all K in Line_First .. I - 1 => T (K) /= ';') and then
        Paren_After (T, I, Line_Last)))
     with Pre => T'First = 1 and then T'Length <= Max_Text and then Line_First >= 1 and then Line_First <= Line_Last and then Line_Last <= T'Length;

   function Has_Is (T : String; Line_First : Positive; Line_Last : Positive) return Boolean is
     ((for some I in Line_First .. Line_Last =>
        Token_At (T, I, "is") and then I + 1 <= Line_Last and then
        (for all K in Line_First .. I - 1 => T (K) /= ';')))
     with Pre => T'First = 1 and then T'Length <= Max_Text and then Line_First >= 1 and then Line_First <= Line_Last and then Line_Last <= T'Length;

   function Has_Semicolon (T : String; Line_First : Positive; Line_Last : Positive) return Boolean is
     ((for some K in Line_First .. Line_Last => T (K) = ';'))
     with Pre => T'First = 1 and then T'Length <= Max_Text and then Line_First >= 1 and then Line_First <= Line_Last and then Line_Last <= T'Length;

   function Completed_In_Spec (Spec : String; T : String; P : Positive; E : Positive) return Boolean is
     ((for some G in 1 .. Spec'Length =>
        Token_At (Spec, G, "function") and then
        (for some Q in G + 9 .. Spec'Length =>
           (for all K in G + 8 .. Q - 1 => Is_Blank (Spec (K))) and then
           Q + (E - P) <= Spec'Length and then
           Same_Ident (Spec, Q, Q + (E - P), T, P, E) and then
           (Q + (E - P) = Spec'Length or else not Is_Ident_Char (Spec (Q + (E - P) + 1))) and then
           (for some I in Q + (E - P) + 1 .. Spec'Length =>
              Token_At (Spec, I, "is") and then
              (for all K in G .. I - 1 => Spec (K) /= ';') and then
              (for some R in I + 2 .. Spec'Length =>
                 (for all K in I + 2 .. R - 1 => Is_Blank (Spec (K))) and then Spec (R) = '(')))))
     with Pre => Spec'First = 1 and then Spec'Length <= Max_Text and then T'First = 1 and then T'Length <= Max_Text
                 and then P <= E and then E <= T'Length;

   function Enters (Spec : String; T : String; Line_First : Positive; Line_Last : Positive) return Boolean is
     ((for some P in Line_First .. Line_Last =>
        (for some E in P .. Line_Last =>
           Function_Name_Span (T, Line_First, Line_Last, P, E) and then
           Completed_In_Spec (Spec, T, P, E))))
     with Pre => Spec'First = 1 and then Spec'Length <= Max_Text and then T'First = 1 and then T'Length <= Max_Text
                 and then Line_First >= 1 and then Line_First <= Line_Last and then Line_Last <= T'Length;

   function Name_First_Of (T : String; Line_First : Positive; Line_Last : Positive) return Positive
     with Pre => T'First = 1 and then T'Length <= Max_Text and then Line_First >= 1 and then Line_First <= Line_Last and then Line_Last <= T'Length
                 and then (for some P in Line_First .. Line_Last => (for some E in P .. Line_Last => Function_Name_Span (T, Line_First, Line_Last, P, E))),
          Post => Name_First_Of'Result in Line_First .. Line_Last
                  and then (for some E in Name_First_Of'Result .. Line_Last => Function_Name_Span (T, Line_First, Line_Last, Name_First_Of'Result, E))
                  and then Is_Ident_Char (T (Name_First_Of'Result));

   function Ident_End (T : String; P : Positive; Line_Last : Positive) return Positive
     with Pre => T'First = 1 and then T'Length <= Max_Text and then Line_Last <= T'Length
                 and then P <= Line_Last and then Is_Ident_Char (T (P)),
          Post => Ident_End'Result in P .. Line_Last
                  and then Ident_Span (T, P, Ident_End'Result, Line_Last);

   function End_Line_Of (T : String; Line_First : Positive; Line_Last : Positive; NF : Positive; NL : Positive) return Boolean is
     ((for some Q in Line_First .. Line_Last =>
        Token_At (T, Q, "end") and then
        (for some R in Q + 4 .. Line_Last =>
           (for all K in Q + 3 .. R - 1 => Is_Blank (T (K))) and then
           R + (NL - NF) <= Line_Last and then
           Same_Ident (T, R, R + (NL - NF), T, NF, NL) and then
           (for some Z in R + (NL - NF) + 1 .. Line_Last =>
              (for all K in R + (NL - NF) + 1 .. Z - 1 => Is_Blank (T (K))) and then T (Z) = ';'))))
     with Pre => T'First = 1 and then T'Length <= Max_Text and then Line_First >= 1 and then Line_First <= Line_Last and then Line_Last <= T'Length
                 and then NF <= NL and then NL <= T'Length;

   function Add (S : Body_Scan; Spec : String; T : String; Line_First : Positive; Line_Last : Positive) return Body_Scan is
     (case S.state is
        when Outside =>
          (if Enters (Spec, T, Line_First, Line_Last) then
             (state      => (if Has_Is_Paren (T, Line_First, Line_Last) then
                               (if Has_Semicolon (T, Line_First, Line_Last) then Outside else Expr_Form)
                             elsif Has_Is (T, Line_First, Line_Last) then Full_Form
                             else Head),
              name_first => Name_First_Of (T, Line_First, Line_Last),
              name_last  => Ident_End (T, Name_First_Of (T, Line_First, Line_Last), Line_Last),
              blank      => True)
           else (state => Outside, name_first => 0, name_last => 0, blank => False)),
        when Head =>
          (state      => (if Has_Is_Paren (T, Line_First, Line_Last) then
                            (if Has_Semicolon (T, Line_First, Line_Last) then Outside else Expr_Form)
                          elsif Has_Is (T, Line_First, Line_Last) then Full_Form
                          else Head),
           name_first => S.name_first, name_last => S.name_last, blank => True),
        when Expr_Form =>
          (state      => (if Has_Semicolon (T, Line_First, Line_Last) then Outside else Expr_Form),
           name_first => S.name_first, name_last => S.name_last, blank => True),
        when Full_Form =>
          (state      => (if End_Line_Of (T, Line_First, Line_Last, S.name_first, S.name_last) then Outside else Full_Form),
           name_first => S.name_first, name_last => S.name_last, blank => True))
     with Pre => Spec'First = 1 and then Spec'Length <= Max_Text and then T'First = 1 and then T'Length <= Max_Text
                 and then Line_First >= 1 and then Line_First <= Line_Last and then Line_Last <= T'Length
                 and then (if S.state /= Outside then S.name_first >= 1 and then S.name_first <= S.name_last and then S.name_last <= T'Length),
          Post => Add'Result.blank = (S.state /= Outside or else Enters (Spec, T, Line_First, Line_Last))
                  and then (if S.state = Outside and then not Enters (Spec, T, Line_First, Line_Last) then Add'Result.state = Outside)
                  and then (if S.state = Expr_Form then Add'Result.state = (if Has_Semicolon (T, Line_First, Line_Last) then Outside else Expr_Form))
                  and then (if S.state = Full_Form then Add'Result.state = (if End_Line_Of (T, Line_First, Line_Last, S.name_first, S.name_last) then Outside else Full_Form))
                  and then (if S.state /= Outside then Add'Result.name_first = S.name_first and Add'Result.name_last = S.name_last)
                  and then (if Add'Result.state /= Outside then Add'Result.name_first >= 1 and Add'Result.name_first <= Add'Result.name_last and Add'Result.name_last <= T'Length);

end Duplicate_Completion_Pkg;
