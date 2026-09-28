--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: e8c151fd3dbb0c35fbbf84dafb575f4478c7fa01822fc7252448d976859fc8c2
--
package Lovelace_Expr_Token_Pkg with SPARK_Mode, Pure is

   Max_Text : constant := 1_048_576;

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);
   CR : constant Character := Character'Val (13);

   Mod_Word : constant String := "mod";
   Rem_Word : constant String := "rem";

   type Token_Kind is (Space_Kind, Lp_Kind, Rp_Kind, Comma_Kind, Op_Kind, Num_Kind, Id_Kind, Bad_Kind);

   type Run_Class is (Digit_Run, Ident_Run, Attr_Run);

   function Is_Letter (C : Character) return Boolean is
     (C in 'A' .. 'Z' or else C in 'a' .. 'z');

   function Is_Digit (C : Character) return Boolean is
     (C in '0' .. '9');

   function Lower (C : Character) return Character is
     (if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C)
     with Post => (if C not in 'A' .. 'Z' then Lower'Result = C);

   function In_Run (Class : Run_Class; C : Character) return Boolean is
     (case Class is
        when Digit_Run => Is_Digit (C) or else C = '_',
        when Ident_Run => Is_Letter (C) or else Is_Digit (C) or else C = '_',
        when Attr_Run  => Is_Letter (C) or else C = '_');

   function Is_Token_Space (C : Character) return Boolean is
     (C = ' ' or else C = LF or else C = HT or else C = CR);

   function Is_Op_Char (C : Character) return Boolean is
     (C = '+' or else C = '-' or else C = '*' or else C = '/');

   function Run_End (Text : String; K : Positive; Class : Run_Class) return Natural is
     (if K > Text'Length then Text'Length
      elsif not In_Run (Class, Text (K)) then K - 1
      else Run_End (Text, K + 1, Class))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then K <= Text'Length + 1,
          Post => Run_End'Result >= K - 1 and then Run_End'Result <= Text'Length
                  and then (for all J in K .. Run_End'Result => In_Run (Class, Text (J))),
          Subprogram_Variant => (Decreases => Text'Length - K + 1);

   function Attr_Follows (Text : String; E : Natural) return Boolean is
     (E <= Text'Length - 2 and then Text (E + 1) = ''' and then In_Run (Attr_Run, Text (E + 2)))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then E >= 1;

   function Ident_End (Text : String; I : Positive) return Positive is
     (if Attr_Follows (Text, Run_End (Text, I + 1, Ident_Run))
      then Run_End (Text, Run_End (Text, I + 1, Ident_Run) + 2, Attr_Run)
      else Run_End (Text, I + 1, Ident_Run))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length
                  and then Is_Letter (Text (I)),
          Post => Ident_End'Result >= I and then Ident_End'Result <= Text'Length;

   function Kind_At (Text : String; I : Positive) return Token_Kind is
     (if Is_Token_Space (Text (I)) then Space_Kind
      elsif Text (I) = '(' then Lp_Kind
      elsif Text (I) = ')' then Rp_Kind
      elsif Text (I) = ',' then Comma_Kind
      elsif Is_Op_Char (Text (I)) then Op_Kind
      elsif Is_Digit (Text (I)) then Num_Kind
      elsif Is_Letter (Text (I)) then Id_Kind
      else Bad_Kind)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length,
          Post => ((Kind_At'Result = Id_Kind) = Is_Letter (Text (I)))
                  and then ((Kind_At'Result = Num_Kind) = Is_Digit (Text (I)))
                  and then ((Kind_At'Result = Op_Kind) = Is_Op_Char (Text (I)));

   function Token_Last (Text : String; I : Positive) return Positive is
     (case Kind_At (Text, I) is
        when Num_Kind => Run_End (Text, I + 1, Digit_Run),
        when Id_Kind  => Ident_End (Text, I),
        when Op_Kind  => (if Text (I) = '*' and then I < Text'Length and then Text (I + 1) = '*' then I + 1 else I),
        when others   => I)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length,
          Post => Token_Last'Result >= I and then Token_Last'Result <= Text'Length
                  and then (if Kind_At (Text, I) not in Num_Kind | Id_Kind | Op_Kind then Token_Last'Result = I);

   function Is_Word_Op (Text : String; First : Positive; Last : Natural) return Boolean is
     (Last >= First and then Last - First = 2
      and then ((Lower (Text (First)) = 'm' and then Lower (Text (First + 1)) = 'o' and then Lower (Text (First + 2)) = 'd')
                or else (Lower (Text (First)) = 'r' and then Lower (Text (First + 1)) = 'e' and then Lower (Text (First + 2)) = 'm')))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length;

   function Word_Op_Text (Text : String; First : Positive; Last : Natural) return String is
     (if Lower (Text (First)) = 'm' then Mod_Word else Rem_Word)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then Is_Word_Op (Text, First, Last),
          Post => Word_Op_Text'Result'Length = 3;

end Lovelace_Expr_Token_Pkg;
