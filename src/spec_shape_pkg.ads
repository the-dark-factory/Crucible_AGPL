--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: efb98f891e2544f152dc6562b6cbe5f9ac0616901e3bfd45edd84d197dcd9755
--
package Spec_Shape_Pkg with SPARK_Mode is

   Max_Line : constant := 65_536;
   Max_Count : constant := 100_000_000;
   Pat_Post_Arrow : constant String := "post =>";
   Pat_Pre_Arrow : constant String := "pre =>";
   Pat_Expression : constant String := "is (";
   Pat_Error : constant String := ": error: ";
   Pat_Undefined : constant String := "is undefined";
   Pat_Not_Declared : constant String := "not declared";

   subtype Count is Integer range 0 .. Max_Count;

   type Shape is record
      operations : Count := 0;
      operations_with_post : Count := 0;
      preconditions : Count := 0;
      open_op : Boolean := False;
      has_post : Boolean := False;
      saturated : Boolean := False;
   end record;

   function Is_Upper (C : Character) return Boolean is
     (C in 'A' .. 'Z')
     with Pre => True, Post => Is_Upper'Result = (C in 'A' .. 'Z');

   function Lower_Eq (A : Character; B : Character) return Boolean is
     (A = B or else (Is_Upper (A) and then Character'Pos (A) + 32 = Character'Pos (B)) or else (Is_Upper (B) and then Character'Pos (B) + 32 = Character'Pos (A)))
     with Pre => True, Post => Lower_Eq'Result = (A = B or else (Is_Upper (A) and then Character'Pos (A) + 32 = Character'Pos (B)) or else (Is_Upper (B) and then Character'Pos (B) + 32 = Character'Pos (A)));

   function Is_Ident_Char (C : Character) return Boolean is
     (C in 'A' .. 'Z' or C in 'a' .. 'z' or C in '0' .. '9' or C = '_')
     with Pre => True, Post => Is_Ident_Char'Result = (C in 'A' .. 'Z' or C in 'a' .. 'z' or C in '0' .. '9' or C = '_');

   function Is_Blank (C : Character) return Boolean is
     (C = ' ' or C = Character'Val (9))
     with Pre => True, Post => Is_Blank'Result = (C = ' ' or C = Character'Val (9));

   function Contains_CI (Line : String; Pattern : String) return Boolean is
     (Line'Length >= Pattern'Length and then
      (for some P in 1 .. Line'Length - Pattern'Length + 1 =>
         (for all K in 0 .. Pattern'Length - 1 => Lower_Eq (Line (P + K), Pattern (1 + K)))))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line and then Pattern'First = 1
                 and then Pattern'Length >= 1 and then Pattern'Length <= 32;

   function Token_At (Line : String; P : Positive; Word : String) return Boolean is
     (P + Word'Length - 1 <= Line'Length and then
      (for all K in 0 .. Word'Length - 1 => Lower_Eq (Line (P + K), Word (1 + K))) and then
      (P = 1 or else not Is_Ident_Char (Line (P - 1))) and then
      (P + Word'Length > Line'Length or else not Is_Ident_Char (Line (P + Word'Length))))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line and then Word'First = 1
                 and then Word'Length >= 1 and then Word'Length <= 32 and then P <= Line'Length;

   function Has_Token (Line : String; Word : String) return Boolean is
     ((for some P in 1 .. Line'Length => Token_At (Line, P, Word)))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line and then Word'First = 1
                 and then Word'Length >= 1 and then Word'Length <= 32;

   function Is_Comment_Line (Line : String) return Boolean is
     ((for some P in 1 .. Line'Length =>
        (for all K in 1 .. P - 1 => Is_Blank (Line (K))) and then
        P + 1 <= Line'Length and then
        Line (P) = '-' and then
        Line (P + 1) = '-'))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line;

   function Is_Declaration (Line : String) return Boolean is
     (not Is_Comment_Line (Line) and then
      (Has_Token (Line, "function") or else Has_Token (Line, "procedure")))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line;

   function Has_Post (Line : String) return Boolean is
     (not Is_Comment_Line (Line) and then Contains_CI (Line, Pat_Post_Arrow))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line;

   function Has_Pre (Line : String) return Boolean is
     (not Is_Comment_Line (Line) and then Contains_CI (Line, Pat_Pre_Arrow))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line;

   function Has_Expression (Line : String) return Boolean is
     (not Is_Comment_Line (Line) and then Contains_CI (Line, Pat_Expression))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line;

   function Is_Contract (Line : String) return Boolean is
     (Has_Post (Line) or else Has_Expression (Line))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line;

   function Is_Undeclared_Name_Error (Line : String) return Boolean is
     (Contains_CI (Line, Pat_Error) and then
      (Contains_CI (Line, Pat_Undefined) or else Contains_CI (Line, Pat_Not_Declared)))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line;

   function Close_Open (S : Shape) return Shape is
     ((if S.open_op and then S.has_post and then S.operations_with_post < Max_Count then
        (operations => S.operations, operations_with_post => S.operations_with_post + 1, preconditions => S.preconditions, open_op => False, has_post => False, saturated => S.saturated)
      else
        (operations => S.operations, operations_with_post => S.operations_with_post, preconditions => S.preconditions, open_op => False, has_post => False, saturated => S.saturated)))
     with Pre => True,
          Post => Close_Open'Result.open_op = False and
                  Close_Open'Result.has_post = False and
                  Close_Open'Result.operations = S.operations and
                  (if S.open_op and then S.has_post and then S.operations_with_post < Max_Count
                   then Close_Open'Result.operations_with_post = S.operations_with_post + 1) and
                  (if not S.open_op or else not S.has_post then Close_Open'Result.operations_with_post = S.operations_with_post) and
                  Close_Open'Result.preconditions = S.preconditions;

   function Add (S : Shape; Line : String) return Shape is
     ((if Is_Declaration (Line) then
        (if S.operations < Max_Count then
           (operations => S.operations + 1, operations_with_post => Close_Open (S).operations_with_post, preconditions => (if Has_Pre (Line) and then S.preconditions < Max_Count then S.preconditions + 1 else S.preconditions), open_op => True, has_post => Is_Contract (Line), saturated => S.saturated)
         else
           (operations => S.operations, operations_with_post => Close_Open (S).operations_with_post, preconditions => (if Has_Pre (Line) and then S.preconditions < Max_Count then S.preconditions + 1 else S.preconditions), open_op => True, has_post => Is_Contract (Line), saturated => True))
      elsif Is_Contract (Line) or else Has_Pre (Line) then
        (operations => S.operations, operations_with_post => S.operations_with_post, preconditions => (if Has_Pre (Line) and then S.preconditions < Max_Count then S.preconditions + 1 else S.preconditions), open_op => S.open_op, has_post => (if Is_Contract (Line) and then S.open_op then True else S.has_post), saturated => S.saturated)
      else
        S))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line,
          Post => (if Is_Declaration (Line) and then S.operations < Max_Count then Add'Result.operations = S.operations + 1) and
                  (if not Is_Declaration (Line) then Add'Result.operations = S.operations) and
                  (if Is_Declaration (Line) then Add'Result.open_op) and
                  (if not Is_Declaration (Line) then Add'Result.open_op = S.open_op) and
                  (if Has_Pre (Line) and then S.preconditions < Max_Count then Add'Result.preconditions = S.preconditions + 1) and
                  (if not Has_Pre (Line) then Add'Result.preconditions = S.preconditions) and
                  (if not Is_Declaration (Line) and then Is_Contract (Line) and then S.open_op then Add'Result.has_post) and
                  (if Is_Declaration (Line) and then Is_Contract (Line) then Add'Result.has_post) and
                  Add'Result.operations >= S.operations and
                  Add'Result.operations_with_post >= S.operations_with_post;

   function Finish (S : Shape) return Shape is
     (Close_Open (S))
     with Pre => True,
          Post => Finish'Result.open_op = False and then Finish'Result.operations = S.operations;

   function Every_Operation_Has_Post (S : Shape) return Boolean is
     (S.operations_with_post = S.operations)
     with Pre => not S.open_op;

end Spec_Shape_Pkg;
