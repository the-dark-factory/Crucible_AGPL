--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 51e5dd5e3dfe26a79bd6c45ad6852ad72b90a603efb5495a582a3451fba50b82
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Lovelace_Expr_Token_Pkg;

procedure Expr_Tokenizer_Main is
   use type Ada.Streams.Stream_Element_Offset;
   use type Lovelace_Expr_Token_Pkg.Token_Kind;

   --  CLI contract:
   --    expr_tokenizer_main <file>
   --  success, exit 0: one line per token, "<kind> <text>" (num, id, op, lp, rp, comma);
   --  or exactly one line "settled" when any byte is not a token (Go's tokenize fails).
   --  failure, exit 2: one line on standard error, nothing on standard output.

   --  Read at most Max_Line + 1 bytes of a file. Over_Bound is True when the file holds more than Max_Line
   --  bytes, so the caller can refuse without ever holding an unbounded answer.
   procedure Read_Bounded (Path : String; Text : out String; Len : out Natural; Over_Bound : out Boolean) is
      F     : Ada.Streams.Stream_IO.File_Type;
      Chunk : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last  : Ada.Streams.Stream_Element_Offset;
   begin
      Len := 0;
      Over_Bound := False;
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Ada.Streams.Stream_IO.Open (F, Ada.Streams.Stream_IO.In_File, Path);
      while not Ada.Streams.Stream_IO.End_Of_File (F) loop
         Ada.Streams.Stream_IO.Read (F, Chunk, Last);
         exit when Last < Chunk'First;
         for I in Chunk'First .. Last loop
            if Len = Text'Length then
               Over_Bound := True;
               Ada.Streams.Stream_IO.Close (F);
               return;
            end if;
            Len := Len + 1;
            Text (Text'First + Len - 1) := Character'Val (Chunk (I));
         end loop;
      end loop;
      Ada.Streams.Stream_IO.Close (F);
   end Read_Bounded;

   --  The number's digits without its '_' bytes.
   function Digits_Only (S : String) return String is
   begin
      if S'Length = 0 then
         return "";
      elsif S (S'First) = '_' then
         return Digits_Only (S (S'First + 1 .. S'Last));
      else
         return S (S'First) & Digits_Only (S (S'First + 1 .. S'Last));
      end if;
   end Digits_Only;

   --  True when some byte of Text is not the start of a token (Go's tokenize fails).
   function Settles (Text : String) return Boolean is
      I : Positive := 1;
   begin
      while I <= Text'Length loop
         if Lovelace_Expr_Token_Pkg.Kind_At (Text, I) = Lovelace_Expr_Token_Pkg.Bad_Kind then
            return True;
         end if;
         I := Lovelace_Expr_Token_Pkg.Token_Last (Text, I) + 1;
      end loop;
      return False;
   end Settles;

   procedure Print_Tokens (Text : String) is
      I : Positive := 1;
      L : Positive;
      K : Lovelace_Expr_Token_Pkg.Token_Kind;
   begin
      while I <= Text'Length loop
         K := Lovelace_Expr_Token_Pkg.Kind_At (Text, I);
         L := Lovelace_Expr_Token_Pkg.Token_Last (Text, I);
         case K is
            when Lovelace_Expr_Token_Pkg.Lp_Kind =>
               Ada.Text_IO.Put_Line ("lp (");
            when Lovelace_Expr_Token_Pkg.Rp_Kind =>
               Ada.Text_IO.Put_Line ("rp )");
            when Lovelace_Expr_Token_Pkg.Comma_Kind =>
               Ada.Text_IO.Put_Line ("comma ,");
            when Lovelace_Expr_Token_Pkg.Op_Kind =>
               Ada.Text_IO.Put_Line ("op " & Text (I .. L));
            when Lovelace_Expr_Token_Pkg.Num_Kind =>
               Ada.Text_IO.Put_Line ("num " & Digits_Only (Text (I .. L)));
            when Lovelace_Expr_Token_Pkg.Id_Kind =>
               if Lovelace_Expr_Token_Pkg.Is_Word_Op (Text, I, L) then
                  Ada.Text_IO.Put_Line ("op " & Lovelace_Expr_Token_Pkg.Word_Op_Text (Text, I, L));
               else
                  Ada.Text_IO.Put_Line ("id " & Text (I .. L));
               end if;
            when others =>
               null;
         end case;
         I := L + 1;
      end loop;
   end Print_Tokens;

begin
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "expr-tokenizer: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      use type Ada.Directories.File_Kind;
      Path : constant String := Ada.Command_Line.Argument (1);
      Buf  : String (1 .. Lovelace_Expr_Token_Pkg.Max_Text);
      Len  : Natural;
      Over : Boolean;
   begin
      if not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "expr-tokenizer: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      Read_Bounded (Path, Buf, Len, Over);
      if Over then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "expr-tokenizer: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      declare
         Text : constant String (1 .. Len) := Buf (1 .. Len);
      begin
         if Settles (Text) then
            Ada.Text_IO.Put_Line ("settled");
         else
            Print_Tokens (Text);
         end if;
      end;
      Ada.Command_Line.Set_Exit_Status (0);
   end;
end Expr_Tokenizer_Main;
