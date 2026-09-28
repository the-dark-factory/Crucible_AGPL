--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 8a00916fae2ff0a7492bcd017b51c3cac583541f4c31fdf4d7a99e633398c4eb
--
package body Json_Scan_Pkg with SPARK_Mode is

   function Key_Position (Line : String; Key : String) return Natural is
   begin
      for I in Line'Range loop
         pragma Loop_Invariant (No_Key_Before (Line, Key, I));
         if Is_Key_At (Line, Key, I) then
            return I;
         end if;
      end loop;
      return 0;
   end Key_Position;

   function Value_Span (Line : String; Key : String) return Span_Type is
      Kpos   : Natural;
      Cpos   : Natural;
      Fpos   : Natural;
      Q      : Natural;
      L      : Natural;
      Depth  : Natural;
      Esc    : Boolean;
      In_Str : Boolean;
   begin
      Kpos := Key_Position (Line, Key);

      if Kpos = 0 then
         return (found => False, kind => K_None, first => 0, last => 0);
      end if;

      pragma Assert (Is_Key_At (Line, Key, Kpos));

      Cpos := 0;
      for J in (Kpos + Key'Length + 2) .. Line'Last loop
         if Line (J) = ':' then
            Cpos := J;
            exit;
         end if;
         pragma Loop_Invariant (Cpos = 0);
         pragma Loop_Invariant (for all S in Kpos + Key'Length + 2 .. J => Line (S) /= ':');
         pragma Loop_Invariant (Colon_From (Line, Kpos + Key'Length + 2) = Colon_From (Line, J + 1));
      end loop;

      if Cpos = 0 then
         return (found => False, kind => K_None, first => 0, last => 0);
      end if;

      Fpos := 0;
      for J in (Cpos + 1) .. Line'Last loop
         if Line (J) /= ' ' then
            Fpos := J;
            exit;
         end if;
         pragma Loop_Invariant (Fpos = 0);
         pragma Loop_Invariant (Nonblank_From (Line, Cpos + 1) = Nonblank_From (Line, J + 1));
      end loop;

      if Fpos = 0 then
         return (found => True, kind => K_Bare, first => Cpos, last => Cpos);
      elsif Line (Fpos) = '"' then
         Q := 0;
         Esc := False;
         for J in (Fpos + 1) .. Line'Last loop
            if Esc then
               Esc := False;
            elsif Line (J) = '\' then
               Esc := True;
            elsif Line (J) = '"' then
               Q := J;
               exit;
            end if;
            pragma Loop_Invariant (Q = 0);
            pragma Loop_Invariant (String_End (Line, Fpos + 1, False) = String_End (Line, J + 1, Esc));
         end loop;
         if Q = 0 then
            return (found => True, kind => K_Bare, first => Cpos, last => Cpos);
         else
            return (found => True, kind => K_String, first => Fpos, last => Q);
         end if;
      elsif Line (Fpos) = '{' or else Line (Fpos) = '[' then
         L := Line'Last;
         Depth := 0;
         In_Str := False;
         Esc := False;
         for J in Fpos .. Line'Last loop
            if In_Str then
               if Esc then
                  Esc := False;
               elsif Line (J) = '\' then
                  Esc := True;
               elsif Line (J) = '"' then
                  In_Str := False;
                  Esc := False;
               end if;
            elsif Line (J) = '"' then
               In_Str := True;
            elsif Line (J) = '{' or else Line (J) = '[' then
               Depth := Depth + 1;
            elsif Line (J) = '}' or else Line (J) = ']' then
               if Depth <= 1 then
                  L := J;
                  exit;
               end if;
               Depth := Depth - 1;
            end if;
            pragma Loop_Invariant (L = Line'Last);
            pragma Loop_Invariant (Depth <= J - Fpos + 1);
            pragma Loop_Invariant (if not In_Str then not Esc);
            pragma Loop_Invariant (Close_From (Line, Fpos, 0, False, False) = Close_From (Line, J + 1, Depth, In_Str, Esc));
         end loop;
         return (found => True, kind => K_Composite, first => Fpos, last => L);
      else
         L := Fpos;
         for J in (Fpos + 1) .. Line'Last loop
            exit when Line (J) = ',' or else Line (J) = '}' or else Line (J) = ']';
            if Line (J) /= ' ' then
               L := J;
            end if;
            pragma Loop_Invariant (L in Fpos .. J);
            pragma Loop_Invariant (Line (L) /= ' ');
            pragma Loop_Invariant (Bare_End (Line, Fpos + 1, Fpos) = Bare_End (Line, J + 1, L));
         end loop;
         return (found => True, kind => K_Bare, first => Fpos, last => L);
      end if;
   end Value_Span;

   function String_Contents (Line : String; S : Span_Type) return Span_Type is
   begin
      return (found => True, kind => K_String, first => S.first + 1, last => S.last - 1);
   end String_Contents;

   function Equals_Literal (Line : String; S : Span_Type; Literal : String) return Boolean is
   begin
      return (Literal'Length = S.last - S.first + 1) and then (Line (S.first .. S.last) = Literal);
   end Equals_Literal;

end Json_Scan_Pkg;