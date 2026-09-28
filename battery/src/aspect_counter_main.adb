--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: c63d7be10ff03b9214b13f0612a30c0b513cfee09253d8e0cabb0114d3698398
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Lovelace_Word_Rules_Pkg;

procedure Aspect_Counter_Main is
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
   function Space_At (Text : String; I : Positive) return Boolean is
   begin
      if I <= Text'Length then
         return Lovelace_Word_Rules_Pkg.Is_Collapse_Space (Text (I));
      end if;
      return False;
   end Space_At;

   function Key_At (Text : String; Q : Positive; Name : String) return Boolean is
      Start : constant Integer := Q + Name'Length;
      J     : Integer;
   begin
      if Name'Length > Text'Length - Q + 1 then
         return False;
      end if;
      if not Lovelace_Word_Rules_Pkg.Equal_CI (Text (Q .. Q + Name'Length - 1), Name) then
         return False;
      end if;
      J := Start;
      while J <= Text'Length and then Space_At (Text, J) loop
         J := J + 1;
      end loop;
      if J > Text'Length or else J + 1 > Text'Length then
         return False;
      end if;
      return Text (J) = '=' and then Text (J + 1) = '>';
   end Key_At;

   function Starts_At (Text : String; P : Positive; Name : String) return Boolean is
   begin
      if P > Text'Length then
         return False;
      end if;
      if P = 1 then
         return Key_At (Text, 1, Name);
      end if;
      return (Space_At (Text, P) or else Text (P) = ',' or else Text (P) = '(')
        and then P + 1 <= Text'Length
        and then Key_At (Text, P + 1, Name);
   end Starts_At;

   function Owned_By_Function (Text : String; P : Positive) return Boolean is
   begin
      return Lovelace_Word_Rules_Pkg.Last_Keyword_Before (Text, "function", P)
        > Lovelace_Word_Rules_Pkg.Last_Keyword_Before (Text, "procedure", P);
   end Owned_By_Function;

   function Count_Aspect (Text : String; Name : String) return Natural is
      Cnt : Natural := 0;
   begin
      for P in 1 .. Text'Length loop
         if Starts_At (Text, P, Name) and then Owned_By_Function (Text, P) then
            Cnt := Cnt + 1;
         end if;
      end loop;
      return Cnt;
   end Count_Aspect;

   function Image (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      if S'Length > 1 and then S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      end if;
      return S;
   end Image;
   --  SLOT END (scan)
begin
   --  SLOT BEGIN (main)
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "aspect-counter: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      use type Ada.Directories.File_Kind;
      Path  : constant String := Ada.Command_Line.Argument (1);
      Buf  : String (1 .. Lovelace_Word_Rules_Pkg.Max_Text);
      Len  : Natural;
      Over : Boolean;
   begin
      if not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "aspect-counter: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      Read_Bounded (Path, Buf, Len, Over);
      if Over then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "aspect-counter: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      Ada.Text_IO.Put_Line (Image (Count_Aspect (Buf (1 .. Len), "pre")) & " "
                            & Image (Count_Aspect (Buf (1 .. Len), "post")));
      Ada.Command_Line.Set_Exit_Status (0);
   end;
   --  SLOT END (main)
end Aspect_Counter_Main;
