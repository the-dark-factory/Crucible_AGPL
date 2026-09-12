--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Body of Reply_Text_Pkg v2: only Escape_Quotes needs a body. Written by the ANVIL lane's
--  body-fill (opus, candidate 2), job verified 2026-09-12 11:28; re-proved with the spec as
--  built: 273 checks, 0 unproved, 0 warnings. Escapes '"' only, not '\' -- see the spec header.
package body Reply_Text_Pkg with SPARK_Mode is

   --  Reply_Text_Pkg body.
   --
   --  Every other operation in the spec is an expression function completed in
   --  the specification itself, so the only subprogram needing a body here is
   --  Escape_Quotes.
   --
   --  Escape_Quotes copies S into a fixed-size buffer of 2 * S'Length
   --  characters, replacing each '"' by the two characters '\' and '"'.  The
   --  buffer is explicitly initialised at declaration (no box notation) so
   --  that the returned slice is provably initialised; the loop invariants
   --  carry the two length bounds demanded by the postcondition
   --  (S'Length <= Result'Length <= 2 * S'Length) and keep every index of the
   --  buffer writes inside range.

   function Escape_Quotes (S : String) return String is
      Max_Len : constant Natural := 2 * S'Length;
      Result  : String (1 .. Max_Len) := (others => ' ');
      Len     : Natural := 0;
   begin
      for I in S'Range loop
         if S (I) = '"' then
            --  Len + 2 <= 2 * (I - S'First + 1) <= Max_Len, from the
            --  invariant carried by the previous iteration (or Len = 0 on the
            --  first one).
            Result (Len + 1) := '\';
            Result (Len + 2) := '"';
            Len := Len + 2;
         else
            Result (Len + 1) := S (I);
            Len := Len + 1;
         end if;

         pragma Loop_Invariant (Len >= I - S'First + 1);
         pragma Loop_Invariant (Len <= 2 * (I - S'First + 1));
         pragma Loop_Invariant (Len <= Max_Len);
      end loop;

      pragma Assert (Len >= S'Length);
      pragma Assert (Len <= Max_Len);

      return Result (1 .. Len);
   end Escape_Quotes;

end Reply_Text_Pkg;