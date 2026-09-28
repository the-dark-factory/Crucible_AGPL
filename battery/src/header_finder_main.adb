--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: a775521d7afb59a636b55ecef0e9a2f12ed5fab01e80aac85cdac8f46a31b6e9
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Lovelace_Word_Rules_Pkg;

procedure Header_Finder_Main is
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
   Sentence : constant String := "no `package X with SPARK_Mode is` header found";

   function Space_At (Text : String; I : Positive) return Boolean is
      Result : Boolean;
   begin
      if I <= Text'Length then
         Result := Lovelace_Word_Rules_Pkg.Is_Collapse_Space (Text (I));
      else
         Result := False;
      end if;
      return Result;
   end Space_At;

   function Word_At (Text : String; I : Positive) return Boolean is
      Result : Boolean;
   begin
      if I <= Text'Length then
         Result := Lovelace_Word_Rules_Pkg.Is_Word_Char (Text (I));
      else
         Result := False;
      end if;
      return Result;
   end Word_At;

   function Skip_Spaces (Text : String; I : Positive) return Positive is
      J : Positive;
   begin
      J := I;
      while J <= Text'Length and then Space_At (Text, J) loop
         J := J + 1;
      end loop;
      return J;
   end Skip_Spaces;

   function Lit_At (Text : String; I : Positive; Lit : String) return Boolean is
      Result : Boolean;
   begin
      if Lit'Length <= Text'Length - I + 1 then
         Result := Lovelace_Word_Rules_Pkg.Equal_CI (Text (I .. I + Lit'Length - 1), Lit);
      else
         Result := False;
      end if;
      return Result;
   end Lit_At;

   function Is_Ahead (Text : String; I : Positive) return Boolean is
      J : Positive;
      Found_Is : Boolean;
      No_Semi : Boolean;
   begin
      J := I;
      Found_Is := False;
      No_Semi := True;
      while J <= Text'Length loop
         if Text (J) = ';' then
            No_Semi := False;
            exit;
         end if;
         if Lit_At (Text, J, "is") and then (J = 1 or else not Word_At (Text, J - 1)) and then not Word_At (Text, J + 2) then
            Found_Is := True;
            exit;
         end if;
         J := J + 1;
      end loop;
      return Found_Is and then No_Semi;
   end Is_Ahead;

   procedure Match (Text : String; P : Positive; Found : out Boolean; First : out Natural; Last : out Natural) is
      N : Positive;
      W : Positive;
      S : Positive;
      L : Positive;
   begin
      Found := False;
      First := 0;
      Last := 0;
      if P /= 1 and then Word_At (Text, P - 1) then
         return;
      end if;
      if not Lit_At (Text, P, "package") then
         return;
      end if;
      if not Space_At (Text, P + 7) then
         return;
      end if;
      N := Skip_Spaces (Text, P + 7);
      if N > Text'Length or else (Text (N) not in 'A' .. 'Z' and then Text (N) not in 'a' .. 'z') then
         return;
      end if;
      First := N;
      L := N;
      while Word_At (Text, L + 1) loop
         L := L + 1;
      end loop;
      Last := L;
      if not Space_At (Text, Last + 1) then
         return;
      end if;
      W := Skip_Spaces (Text, Last + 1);
      if not Lit_At (Text, W, "with") then
         return;
      end if;
      if not Space_At (Text, W + 4) then
         return;
      end if;
      S := Skip_Spaces (Text, W + 4);
      if not Lit_At (Text, S, "spark_mode") or else Word_At (Text, S + 10) then
         return;
      end if;
      if not Is_Ahead (Text, S + 10) then
         return;
      end if;
      Found := True;
   end Match;
   --  SLOT END (scan)
begin
   --  SLOT BEGIN (main)
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "header-finder: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      use type Ada.Directories.File_Kind;
      Path  : constant String := Ada.Command_Line.Argument (1);
      Buf   : String (1 .. Lovelace_Word_Rules_Pkg.Max_Text);
      Len   : Natural;
      Over  : Boolean;
      Found : Boolean;
      First : Natural;
      Last  : Natural;
   begin
      if not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "header-finder: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      Read_Bounded (Path, Buf, Len, Over);
      if Over then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "header-finder: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      for P in 1 .. Len loop
         Match (Buf (1 .. Len), P, Found, First, Last);
         if Found then
            Ada.Text_IO.Put_Line ("package " & Buf (First .. Last));
            Ada.Command_Line.Set_Exit_Status (0);
            return;
         end if;
      end loop;
      Ada.Text_IO.Put_Line (Sentence);
      Ada.Command_Line.Set_Exit_Status (1);
   end;
   --  SLOT END (main)
end Header_Finder_Main;
