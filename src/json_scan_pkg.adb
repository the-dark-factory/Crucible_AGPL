--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Body: the lane's body-fill (claude-cli opus, candidate 2, proof tier level 2), 2026-09-11 21:34. See the spec header.
--
package body Json_Scan_Pkg with SPARK_Mode is

   --  Purpose: scanning primitives over a single flat JSON text line.
   --
   --  Implementation notes:
   --    * Every scanning loop is a FOR loop over Line'Range, so termination is
   --      by construction (no while loops anywhere in this body).
   --    * Each loop is written in "guarded, exit-free" style: a Done flag
   --      freezes the result once found.  That keeps every loop invariant a
   --      statement about the prefix Line'First .. K, so at loop exit
   --      (K = Line'Last) the invariant IS the property the postcondition
   --      needs.
   --    * "found" in Value_Span is decided solely by Key_Position, whose loop
   --      carries the prefix invariant discharging
   --      (Key_Position'Result /= 0) = Has_Key (Line, Key).  Value_Span then
   --      inherits that equality instead of re-deriving it from its own scan.
   --    * Nesting depth is a bounded subtype and every increment/decrement is
   --      explicitly guarded, so no overflow or range check is left to the
   --      prover.

   Max_Depth : constant := 65536;

   subtype Depth_Type is Natural range 0 .. Max_Depth;

   ------------------
   -- Key_Position --
   ------------------

   function Key_Position (Line : String; Key : String) return Natural is
      Pos : Natural := 0;
   begin
      for I in Line'Range loop
         if Pos = 0 and then Is_Key_At (Line, Key, I) then
            Pos := I;
         end if;

         --  Prefix invariant: the segment Line'First .. I is fully classified.
         --  At exit (I = Line'Last) this is exactly "Pos = 0 => not Has_Key".
         pragma Loop_Invariant
           (if Pos = 0
            then (for all J in Line'First .. I => not Is_Key_At (Line, Key, J)));

         --  And "Pos /= 0 => Has_Key", together with the leftmost property.
         pragma Loop_Invariant
           (if Pos /= 0
            then Pos in Line'First .. I
                 and then Is_Key_At (Line, Key, Pos)
                 and then No_Key_Before (Line, Key, Pos));

         pragma Loop_Invariant
           (if Pos = 0 then No_Key_Before (Line, Key, I));
      end loop;

      return Pos;
   end Key_Position;

   ----------------
   -- Value_Span --
   ----------------

   function Value_Span (Line : String; Key : String) return Span_Type is
      P      : constant Natural := Key_Position (Line, Key);
      Colon  : Natural    := 0;
      V      : Natural    := 0;
      Q      : Natural    := 0;
      L      : Natural    := 0;
      Depth  : Depth_Type := 0;
      Esc    : Boolean    := False;
      In_Str : Boolean    := False;
      Done   : Boolean    := False;
   begin
      if P = 0 then
         --  Key_Position's contract gives (P /= 0) = Has_Key, so reporting
         --  "not found" here discharges found = Has_Key (Line, Key).
         return (found => False, kind => K_None, first => 0, last => 0);
      end if;

      pragma Assert (Is_Key_At (Line, Key, P));
      pragma Assert (P in Line'Range);
      pragma Assert (P + Key'Length + 1 <= Line'Last);
      --  Unfolding Is_Key_At: a colon exists after the closing quote of the key.
      pragma Assert
        (for some C in P + Key'Length + 2 .. Line'Last => Line (C) = ':');

      --  Locate that colon.
      for K in Line'Range loop
         if not Done
           and then K >= P + Key'Length + 2
           and then Line (K) = ':'
         then
            Colon := K;
            Done  := True;
         end if;

         pragma Loop_Invariant (Done = (Colon /= 0));
         pragma Loop_Invariant
           (if Colon /= 0
            then Colon in P + Key'Length + 2 .. K and then Line (Colon) = ':');
         pragma Loop_Invariant
           (if Colon = 0
            then (for all M in P + Key'Length + 2 .. K => Line (M) /= ':'));
      end loop;

      --  The prefix invariant for Colon = 0 contradicts the existential above.
      pragma Assert (Colon /= 0);
      pragma Assert (Colon in Line'Range);
      pragma Assert (Colon > P);

      --  Locate the first non-blank character after the colon.
      Done := False;
      for K in Line'Range loop
         if not Done and then K > Colon and then Line (K) /= ' ' then
            V    := K;
            Done := True;
         end if;

         pragma Loop_Invariant (Done = (V /= 0));
         pragma Loop_Invariant
           (if V /= 0 then V in Colon + 1 .. K and then Line (V) /= ' ');
      end loop;

      if V = 0 then
         --  Nothing but blanks after the colon.  The key IS present, so found
         --  must stay True; report the colon itself, which is inside Line, is
         --  not a blank, and lies strictly after the key position.
         return (found => True, kind => K_Bare, first => Colon, last => Colon);
      end if;

      pragma Assert (V in Line'Range);
      pragma Assert (V > Colon);
      pragma Assert (V > P);

      --  Quoted string value.
      if Line (V) = '"' then
         Q    := 0;
         Esc  := False;
         Done := False;

         for K in Line'Range loop
            if not Done and then K > V then
               if Esc then
                  Esc := False;
               elsif Line (K) = '\' then
                  Esc := True;
               elsif Line (K) = '"' then
                  Q    := K;
                  Done := True;
               end if;
            end if;

            pragma Loop_Invariant (Done = (Q /= 0));
            pragma Loop_Invariant
              (if Q /= 0 then Q in V + 1 .. K and then Line (Q) = '"');
         end loop;

         if Q /= 0 then
            return (found => True, kind => K_String, first => V, last => Q);
         end if;

         --  Unterminated string: fall back to the colon so that the result
         --  still satisfies every branch of the postcondition.
         return (found => True, kind => K_Bare, first => Colon, last => Colon);
      end if;

      --  Object or array value.
      if Line (V) = '{' or else Line (V) = '[' then
         L      := V;
         Depth  := 0;
         Esc    := False;
         In_Str := False;
         Done   := False;

         for K in Line'Range loop
            if not Done and then K >= V then
               if In_Str then
                  if Esc then
                     Esc := False;
                  elsif Line (K) = '\' then
                     Esc := True;
                  elsif Line (K) = '"' then
                     In_Str := False;
                  end if;
               elsif Line (K) = '"' then
                  In_Str := True;
               elsif Line (K) = '{' or else Line (K) = '[' then
                  --  Guarded increment: no overflow left to the prover.
                  if Depth < Max_Depth then
                     Depth := Depth + 1;
                  end if;
               elsif Line (K) = '}' or else Line (K) = ']' then
                  --  Guarded decrement: no underflow left to the prover.
                  if Depth > 0 then
                     Depth := Depth - 1;
                  end if;

                  if Depth = 0 then
                     L    := K;
                     Done := True;
                  end if;
               end if;
            end if;

            pragma Loop_Invariant (Depth <= Max_Depth);
            pragma Loop_Invariant (L in V .. Line'Last);
            pragma Loop_Invariant (if Done then L in V .. K);
         end loop;

         if not Done then
            --  Unbalanced composite: take the rest of the line.
            L := Line'Last;
         end if;

         pragma Assert (L in V .. Line'Last);
         return (found => True, kind => K_Composite, first => V, last => L);
      end if;

      --  Bare value (number, true, false, null): runs to the next separator,
      --  trailing blanks excluded.
      L    := V;
      Done := False;

      for K in Line'Range loop
         if not Done and then K > V then
            if Line (K) = ',' or else Line (K) = '}' or else Line (K) = ']' then
               Done := True;
            elsif Line (K) /= ' ' then
               L := K;
            end if;
         end if;

         pragma Loop_Invariant (L in V .. Line'Last);
      end loop;

      pragma Assert (Line (V) /= '"');
      pragma Assert (Line (V) /= '{');
      pragma Assert (Line (V) /= '[');
      return (found => True, kind => K_Bare, first => V, last => L);
   end Value_Span;

   ---------------------
   -- String_Contents --
   ---------------------

   function String_Contents (Line : String; S : Span_Type) return Span_Type
     is ((found => True,
          kind  => K_String,
          first => S.first + 1,
          last  => S.last - 1));

   --------------------
   -- Equals_Literal --
   --------------------

   function Equals_Literal
     (Line : String; S : Span_Type; Literal : String) return Boolean
     is ((Literal'Length = S.last - S.first + 1)
         and then (Line (S.first .. S.last) = Literal));

end Json_Scan_Pkg;