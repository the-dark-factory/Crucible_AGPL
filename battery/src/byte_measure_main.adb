--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: b4306ac2dbfc845376a7f2e28bc80e93e2dc17e7f39c5d1749d81862f899517a
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Lovelace_Utf8_Decode_Pkg;

procedure Byte_Measure_Main is
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
function Digit (W : Natural) return Character is
  (Character'Val (Character'Pos ('0') + W));
   --  SLOT END (scan)
begin
   --  SLOT BEGIN (main)
if Ada.Command_Line.Argument_Count /= 1 then
   Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "byte-measure: usage");
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
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "byte-measure: cannot read");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   Read_Bounded (Path, Buf, Len, Over);
   if Over then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "byte-measure: cannot read");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   for I in 1 .. Len loop
      Ada.Text_IO.Put (Digit (Lovelace_Utf8_Decode_Pkg.Width_At (Buf (1 .. Len), I)));
   end loop;
   Ada.Text_IO.New_Line;
   Ada.Command_Line.Set_Exit_Status (0);
end;
   --  SLOT END (main)
end Byte_Measure_Main;
