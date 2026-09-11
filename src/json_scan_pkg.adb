--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Body: body-fill-bench, claude-cli opus (candidate 2), proof tier level 2, 2026-09-11 20:01. See the spec header.
--
package body Json_Scan_Pkg with SPARK_Mode is

   --  Scanning helpers.  Every loop below is a bounded `for` loop over
   --  Line'Range, so termination holds by construction, and every value
   --  returned to the caller passes through a single guarded return that
   --  re-establishes the postcondition's range facts explicitly.

   HT        : constant Character := Character'Val (9);
   Max_Depth : constant Natural   := 65_536;

   No_Span : constant Span_Type :=
     (found => False, kind => K_None, first => 0, last => 0);

   function Is_Blank (C : Character) return Boolean is
     (C = ' ' or else C = HT);

   function Is_Quote (C : Character) return Boolean is
     (C = '"' or else C = ''');

   ---------------------
   -- Key_Position    --
   ---------------------

   function Key_Position (Line : String; Key : String) return Natural is
      Pos : Natural := 0;
   begin
      --  Key cannot occur if it is longer than the whole line; this test also
      --  bounds Key'Length by 65536, which keeps the index arithmetic below
      --  free of overflow.
      if Key'Length <= Line'Length then
         for I in Line'Range loop
            if Line (I) = '''
              and then I <= Line'Last - Key'Length - 1
              and then Line (I + 1 .. I + Key'Length) = Key
              and then Line (I + Key'Length + 1) = '''
            then
               Pos := I;
               exit;
            end if;
            pragma Loop_Invariant (Pos = 0);
         end loop;
      end if;

      --  Single guarded exit: the postcondition is literally the guard.
      if Pos in Line'Range and then Line (Pos) = ''' then
         return Pos;
      else
         return 0;
      end if;
   end Key_Position;

   ---------------------
   -- Value_Span      --
   ---------------------

   function Value_Span (Line : String; Key : String) return Span_Type is
      P      : constant Natural := Key_Position (Line, Key);
      Colon  : Natural   := 0;
      VF     : Natural   := 0;
      VL     : Natural   := 0;
      K      : Kind_Type := K_None;
      Depth  : Natural   := 0;
      In_Str : Boolean   := False;
      Esc    : Boolean   := False;
      Quote  : Character := ' ';
   begin
      if P = 0 then
         return No_Span;
      end if;

      --  Colon separating key from value.
      for I in Line'Range loop
         if I > P and then Line (I) = ':' then
            Colon := I;
            exit;
         end if;
         pragma Loop_Invariant (Colon = 0);
      end loop;

      if Colon not in Line'Range then
         return No_Span;
      end if;

      --  First non-blank character after the colon: the value start.
      for I in Line'Range loop
         if I > Colon and then not Is_Blank (Line (I)) then
            VF := I;
            exit;
         end if;
         pragma Loop_Invariant (VF = 0);
      end loop;

      if VF not in Line'Range then
         return No_Span;
      end if;

      if Is_Quote (Line (VF)) then

         --  Quoted string: scan to the matching, unescaped delimiter.
         K     := K_String;
         Quote := Line (VF);
         for I in Line'Range loop
            if I > VF and then VL = 0 then
               if Esc then
                  Esc := False;
               elsif Line (I) = '\' then
                  Esc := True;
               elsif Line (I) = Quote then
                  VL := I;
               end if;
            end if;
            pragma Loop_Invariant (VL = 0 or else VL in Line'Range);
         end loop;

      elsif Line (VF) = '{' or else Line (VF) = '[' then

         --  Object or array: depth counting, ignoring brackets inside strings.
         K := K_Composite;
         for I in Line'Range loop
            if I >= VF and then VL = 0 then
               if In_Str then
                  if Esc then
                     Esc := False;
                  elsif Line (I) = '\' then
                     Esc := True;
                  elsif Line (I) = Quote then
                     In_Str := False;
                  end if;
               elsif Is_Quote (Line (I)) then
                  In_Str := True;
                  Quote  := Line (I);
               elsif Line (I) = '{' or else Line (I) = '[' then
                  if Depth >= Max_Depth then
                     return No_Span;
                  end if;
                  Depth := Depth + 1;
               elsif Line (I) = '}' or else Line (I) = ']' then
                  if Depth > 0 then
                     Depth := Depth - 1;
                  end if;
                  if Depth = 0 then
                     VL := I;
                  end if;
               end if;
            end if;
            pragma Loop_Invariant (Depth <= Max_Depth);
            pragma Loop_Invariant (VL = 0 or else VL in Line'Range);
         end loop;

      else

         --  Bare token: run to the next separator, dropping trailing blanks.
         K  := K_Bare;
         VL := VF;
         for I in Line'Range loop
            if I > VF then
               exit when Line (I) = ','
                 or else Line (I) = '}'
                 or else Line (I) = ']';
               if not Is_Blank (Line (I)) then
                  VL := I;
               end if;
            end if;
            pragma Loop_Invariant (VL in Line'Range);
            pragma Loop_Invariant (VL >= VF);
         end loop;

      end if;

      --  Single guarded exit: mirrors the "found" half of the postcondition.
      if K /= K_None
        and then VF in Line'Range
        and then VL in Line'Range
        and then VF <= VL
      then
         return (found => True, kind => K, first => VF, last => VL);
      else
         return No_Span;
      end if;
   end Value_Span;

   ---------------------
   -- String_Contents --
   ---------------------

   function String_Contents (Line : String; S : Span_Type) return Span_Type is
   begin
      --  S.first < S.last is what makes S.first + 1 overflow-free and keeps
      --  the resulting (possibly empty) span inside the original one.
      if S.first < S.last
        and then Is_Quote (Line (S.first))
        and then Line (S.last) = Line (S.first)
      then
         return (found => True,
                 kind  => K_String,
                 first => S.first + 1,
                 last  => S.last - 1);
      else
         return (found => True,
                 kind  => K_String,
                 first => S.first,
                 last  => S.last);
      end if;
   end String_Contents;

   ---------------------
   -- Equals_Literal  --
   ---------------------

   function Equals_Literal
     (Line : String; S : Span_Type; Literal : String) return Boolean is
   begin
      if S.last - S.first + 1 /= Literal'Length then
         return False;
      else
         return Line (S.first .. S.last) = Literal;
      end if;
   end Equals_Literal;

end Json_Scan_Pkg;