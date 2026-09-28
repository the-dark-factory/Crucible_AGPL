--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: b7254771787a13e50589b7c0881f152869fafee6bf746361670b2d7b1a26fd1e
--
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with Ada.Containers.Indefinite_Vectors;
with Lovelace_Word_Rules_Pkg;

procedure Claim_Former_Main is
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
   package W renames Lovelace_Word_Rules_Pkg;
   procedure Split_Fields (Text : String; Fields : out Field_Vectors.Vector) is
      F : Positive := Text'First;
   begin
      Fields := Field_Vectors.Empty_Vector;
      for I in Text'First .. Text'Last + 1 loop
         if I > Text'Last or else Text (I) = Character'Val (0) then
            declare P : constant String (1 .. I - F) := Text (F .. I - 1); begin Fields.Append (P); end;
            F := I + 1;
         end if;
      end loop;
   end Split_Fields;
   function Decimal (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Decimal;
   function Is_Letter (C : Character) return Boolean is (C in 'A' .. 'Z' | 'a' .. 'z');
   function Name_Ok (Name : String) return Boolean is
   begin
      if Name'Length < 1 or else Name'Length > 256 or else not Is_Letter (Name (Name'First)) then return False; end if;
      for C of Name loop if not W.Is_Word_Char (C) then return False; end if; end loop;
      return True;
   end Name_Ok;
   function Trimmed (S : String) return String is
      F : constant Positive := W.First_Non_Trim (S, 1, S'Length);
      L : constant Natural := W.Last_Non_Trim (S, F, S'Length);
      R : constant String (1 .. L - F + 1) := S (F .. L);
   begin
      return R;
   end Trimmed;
   function Is_Predicate_Form (T : String; Name : String) return Boolean is
      P : Positive := 1;
   begin
      if P <= T'Length and then T (P) = '(' then P := P + 1; end if;
      while P <= T'Length and then W.Is_Collapse_Space (T (P)) loop P := P + 1; end loop;
      if P > T'Length or else not W.Name_At (T, P, Name, True) then return False; end if;
      P := P + W.Name_Length (Name, True);
      while P <= T'Length and then W.Is_Collapse_Space (T (P)) loop P := P + 1; end loop;
      if P <= T'Length and then T (P) = ')' then P := P + 1; end if;
      return P = T'Length + 1;
   end Is_Predicate_Form;
   function Name_Char (C : Character) return Boolean is (W.Is_Word_Char (C));
   function Expand (Tpl : String; M : String) return String is
      R : Ada.Strings.Unbounded.Unbounded_String;
      I : Positive := Tpl'First;
   begin
      while I <= Tpl'Last loop
         if Tpl (I) /= '$' then
            Ada.Strings.Unbounded.Append (R, Tpl (I)); I := I + 1;
         elsif I < Tpl'Last and then Tpl (I + 1) = '$' then
            Ada.Strings.Unbounded.Append (R, '$'); I := I + 2;
         else
            declare
               J : Positive := I + 1; Brace : Boolean := False; S, E : Natural; Ok : Boolean := False; Next : Positive;
            begin
               if J <= Tpl'Last and then Tpl (J) = '{' then Brace := True; J := J + 1; end if;
               S := J;
               while J <= Tpl'Last and then Name_Char (Tpl (J)) loop J := J + 1; end loop;
               E := J - 1;
               if E >= S then
                  if Brace then
                     if J <= Tpl'Last and then Tpl (J) = '}' then Ok := True; Next := J + 1; end if;
                  else Ok := True; Next := J; end if;
               end if;
               if not Ok then
                  Ada.Strings.Unbounded.Append (R, '$'); I := I + 1;
               else
                  if Tpl (S .. E) = "0" then Ada.Strings.Unbounded.Append (R, M); end if;
                  I := Next;
               end if;
            end;
         end if;
      end loop;
      return Ada.Strings.Unbounded.To_String (R);
   end Expand;
   function Replace_All (T : String; Name : String; Body_Text : String) return String is
      R : Ada.Strings.Unbounded.Unbounded_String;
      From : Positive := 1;
      Tpl : constant String := "(" & Body_Text & ")";
   begin
      loop
         declare P : constant Natural := (if From > T'Length then 0 else W.Next_Name_At_Or_After (T, Name, True, From)); begin
            if P = 0 then
               if From <= T'Length then Ada.Strings.Unbounded.Append (R, T (From .. T'Length)); end if;
               exit;
            end if;
            Ada.Strings.Unbounded.Append (R, T (From .. P - 1));
            Ada.Strings.Unbounded.Append (R, Expand (Tpl, T (P .. P + W.Name_Length (Name, True) - 1)));
            From := P + W.Name_Length (Name, True);
         end;
      end loop;
      return Ada.Strings.Unbounded.To_String (R);
   end Replace_All;
   --  SLOT END (scan)
begin
   --  SLOT BEGIN (main)
   if Ada.Command_Line.Argument_Count /= 1 then
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "claim-former: usage");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;
   declare
      use type Ada.Directories.File_Kind;
      Path   : constant String := Ada.Command_Line.Argument (1);
      Buf    : String (1 .. Lovelace_Word_Rules_Pkg.Max_Text);
      Len    : Natural;
      Over   : Boolean;
      Fields : Field_Vectors.Vector;
   begin
      if not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File
      then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "claim-former: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      Read_Bounded (Path, Buf, Len, Over);
      if Over then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "claim-former: cannot read");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      Split_Fields (Buf (1 .. Len), Fields);
      if Natural (Fields.Length) /= 4
        or else (Fields (2) /= "true" and then Fields (2) /= "false")
        or else not Name_Ok (Fields (1))
      then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "claim-former: malformed request");
         Ada.Command_Line.Set_Exit_Status (2);
         return;
      end if;
      declare
         Name      : constant String := Fields (1);
         Post      : constant String := Fields (3);
         Body_Text : constant String := Fields (4);
      begin
         if Post'Length = 0 or else Body_Text'Length = 0 then
            Ada.Text_IO.Put_Line ("settled");
         else
            declare
               T     : constant String := Trimmed (Post);
               Claim : constant String :=
                 (if Fields (2) = "true" and then Is_Predicate_Form (T, Name) then Body_Text
                  else Replace_All (T, Name, Body_Text));
            begin
               if Claim'Length > 1_048_576 then
                  Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "claim-former: claim over 1048576 bytes");
                  Ada.Command_Line.Set_Exit_Status (2);
                  return;
               end if;
               Ada.Text_IO.Put_Line ("claim " & Decimal (Claim'Length));
               Ada.Text_IO.Put (Claim);
               Ada.Text_IO.New_Line;
            end;
         end if;
      end;
      Ada.Command_Line.Set_Exit_Status (0);
   end;
   --  SLOT END (main)
end Claim_Former_Main;
