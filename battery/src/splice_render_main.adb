--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 2e1a68eb2144f441834be21d964d086dfbbd09a34cff2dd3f81895061dfd1cca
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Containers.Indefinite_Vectors;
with Lovelace_Splice_Fit_Pkg;

procedure Splice_Render_Main is
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

   package Field_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);

   --  SLOT BEGIN (scan)
   procedure Split_Fields (Text : String; Fields : out Field_Vectors.Vector) is
      Start : Positive := Text'First;
   begin
      Fields := Field_Vectors.Empty_Vector;
      for I in Text'First .. Text'Last + 1 loop
         if I > Text'Last or else Text (I) = Character'Val (0) then
            declare
               Piece : constant String (1 .. I - Start) := Text (Start .. I - 1);
            begin
               Fields.Append (Piece);
            end;
            Start := I + 1;
         end if;
      end loop;
   end Split_Fields;

   function Count_Value (S : String) return Integer is
      V : Integer := 0;
   begin
      if S'Length < 1 or else S'Length > 7 then
         return -1;
      end if;
      if S'Length > 1 and then S (S'First) = '0' then
         return -1;
      end if;
      for C of S loop
         if C not in '0' .. '9' then
            return -1;
         end if;
         V := V * 10 + (Character'Pos (C) - Character'Pos ('0'));
      end loop;
      return V;
   end Count_Value;

   function Malformed (Fields : Field_Vectors.Vector) return Boolean is
      Count : constant Natural := Natural (Fields.Length);
      P     : Integer;
      A     : Integer;
   begin
      if Count < 8 then
         return True;
      end if;
      if Fields (1) /= "decl" and then Fields (1) /= "function"
        and then Fields (1) /= "completion" and then Fields (1) /= "params"
      then
         return True;
      end if;
      if Count_Value (Fields (2)) < 0 then
         return True;
      end if;
      if Count_Value (Fields (2)) > Lovelace_Splice_Fit_Pkg.Max_Lines then
         return True;
      end if;
      if Fields (5) /= "true" and then Fields (5) /= "false" then
         return True;
      end if;
      P := Count_Value (Fields (7));
      if P < 0 then
         return True;
      end if;
      if Count < 8 + 2 * P then
         return True;
      end if;
      A := Count_Value (Fields (8 + 2 * P));
      if A < 0 then
         return True;
      end if;
      return Count /= 8 + 2 * P + A;
   end Malformed;

   function Param_From (Fields : Field_Vectors.Vector; K : Positive; P : Natural) return String is
     (if K > P then ""
      else "; " & Fields (6 + 2 * K) & " : " & Fields (7 + 2 * K) & Param_From (Fields, K + 1, P));

   function Param_List (Fields : Field_Vectors.Vector) return String is
     (if Count_Value (Fields (7)) = 0 then ""
      else " (" & Fields (8) & " : " & Fields (9) & Param_From (Fields, 2, Count_Value (Fields (7))) & ")");

   function Aspect_From (Fields : Field_Vectors.Vector; Base : Positive; K : Positive; A : Natural) return String is
     (if K > A then "" else ", " & Fields (Base + K) & Aspect_From (Fields, Base, K + 1, A));

   function Aspect_Part (Fields : Field_Vectors.Vector) return String is
     (if Count_Value (Fields (8 + 2 * Count_Value (Fields (7)))) = 0 then ""
      else " with " & Fields (9 + 2 * Count_Value (Fields (7)))
           & Aspect_From (Fields, 8 + 2 * Count_Value (Fields (7)), 2,
                          Count_Value (Fields (8 + 2 * Count_Value (Fields (7))))));

   function Render (Fields : Field_Vectors.Vector) return String is
      Head : constant String := "function " & Fields (3) & Param_List (Fields) & " return " & Fields (4);
   begin
      if Fields (1) = "decl" then
         return Head & Aspect_Part (Fields) & ";";
      elsif Fields (1) = "function" then
         if Fields (5) = "true" then
            return "   " & Head & " is (" & Fields (6) & ")" & Aspect_Part (Fields) & ";";
         else
            return "   " & Head & Aspect_Part (Fields) & ";";
         end if;
      else
         return "   " & Head & " is (" & Fields (6) & ");";
      end if;
   end Render;
   --  SLOT END (scan)
begin
   --  SLOT BEGIN (main)
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "splice-render: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      use type Ada.Directories.File_Kind;
      Path   : constant String := Ada.Command_Line.Argument (1);
      Buf    : String (1 .. Lovelace_Splice_Fit_Pkg.Max_Text);
      Len    : Natural;
      Over   : Boolean;
      Fields : Field_Vectors.Vector;
   begin
      if not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "splice-render: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      Read_Bounded (Path, Buf, Len, Over);
      if Over then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "splice-render: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      Split_Fields (Buf (1 .. Len), Fields);
      if Malformed (Fields) then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "splice-render: malformed request");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      if Fields (1) = "params" then
         Ada.Text_IO.Put (Param_List (Fields));
         Ada.Text_IO.New_Line;
      else
         declare
            Text : constant String := Render (Fields);
            N    : constant Natural := Count_Value (Fields (2));
         begin
            if Text'Length > 65_536 then
               Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "splice-render: rendered text over 65536 bytes");
               Ada.Command_Line.Set_Exit_Status (2);
               return;
            end if;
            declare
               Fit_Text : constant String (1 .. Text'Length) := Text;
            begin
               for K in 1 .. N loop
                  Ada.Text_IO.Put (Lovelace_Splice_Fit_Pkg.Fit_Line (Fit_Text, N, K));
                  Ada.Text_IO.New_Line;
               end loop;
            end;
         end;
      end if;
      Ada.Command_Line.Set_Exit_Status (0);
   end;
   --  SLOT END (main)
end Splice_Render_Main;
