--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: dc62185e45282b5c6c24cf1698f3248a35c72611ba4da7bf82b42163940f7e03
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Lovelace_Go_Quote_Pkg;
with Lovelace_Utf8_Decode_Pkg;
with Lovelace_Go_Print_Pkg;

procedure Go_Quote_Wide_Main is
   use type Ada.Streams.Stream_Element_Offset;

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

   --  SLOT BEGIN (scan)
   Backslash : constant Character := Character'Val (92);
   Quote     : constant Character := Character'Val (34);
   Hex_Chars : constant String := "0123456789abcdef";

   function Hex (Value : Natural; Width : Positive) return String is
      Result : String (1 .. Width) := (others => '0');
      V      : Natural := Value;
   begin
      for K in reverse Result'Range loop
         Result (K) := Hex_Chars (V mod 16 + 1);
         V := V / 16;
      end loop;
      return Result;
   end Hex;

   procedure Put_Quoted (Text : String) is
      I : Positive := 1;
   begin
      Ada.Text_IO.Put (Quote);
      while I <= Text'Length loop
         if Character'Pos (Text (I)) <= 127 then
            Ada.Text_IO.Put (Lovelace_Go_Quote_Pkg.Escape_Of (Text (I)));
            I := I + 1;
         else
            declare
               W : constant Lovelace_Utf8_Decode_Pkg.Rune_Width :=
                 Lovelace_Utf8_Decode_Pkg.Width_At (Text, I);
            begin
               if W = 0 then
                  Ada.Text_IO.Put (Backslash);
                  Ada.Text_IO.Put ('x');
                  Ada.Text_IO.Put (Hex (Character'Pos (Text (I)), 2));
                  I := I + 1;
               else
                  declare
                     R : constant Lovelace_Utf8_Decode_Pkg.Rune :=
                       Lovelace_Utf8_Decode_Pkg.Rune_At (Text, I);
                  begin
                     if Lovelace_Go_Print_Pkg.Is_Print (R) then
                        Ada.Text_IO.Put (Text (I .. I + W - 1));
                     elsif R < 16#10000# then
                        Ada.Text_IO.Put (Backslash);
                        Ada.Text_IO.Put ('u');
                        Ada.Text_IO.Put (Hex (R, 4));
                     else
                        Ada.Text_IO.Put (Backslash);
                        Ada.Text_IO.Put ('U');
                        Ada.Text_IO.Put (Hex (R, 8));
                     end if;
                     I := I + W;
                  end;
               end if;
            end;
         end if;
      end loop;
      Ada.Text_IO.Put (Quote);
   end Put_Quoted;
   --  SLOT END (scan)
begin
   --  SLOT BEGIN (main)
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "go-quote-wide: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      use type Ada.Directories.File_Kind;
      Path  : constant String := Ada.Command_Line.Argument (1);
      Buf  : String (1 .. Lovelace_Utf8_Decode_Pkg.Max_Text);
      Len  : Natural;
      Over : Boolean;
   begin
      if not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "go-quote-wide: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      Read_Bounded (Path, Buf, Len, Over);
      if Over then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "go-quote-wide: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      Put_Quoted (Buf (1 .. Len));
      Ada.Text_IO.New_Line;
      Ada.Command_Line.Set_Exit_Status (0);
   end;
   --  SLOT END (main)
end Go_Quote_Wide_Main;
