--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Body of Reply_Text_Pkg v2: only Escape_Quotes needs a body. Written by the ANVIL lane's
--  body-fill (opus, candidate 3), job verified 2026-09-12 11:41; re-proved with the spec as
--  built: 265 checks, 0 unproved, 0 warnings. Escapes '"' only, not '\' -- see the spec header.
pragma Ada_2012;

--  Reply_Text_Pkg (body)
--
--  Purpose: supplies the one operation of the specification that is not an
--  expression function.  Every other visible subprogram of Reply_Text_Pkg is
--  declared in the spec as an expression function and therefore needs no
--  body here; re-declaring them would be an error.
--
--  Escape_Quotes rewrites each '"' in S as the two-character sequence \" so
--  that the result can itself be embedded inside a JSON string literal.  The
--  loop invariants establish the length bounds asserted by the postcondition:
--  one character in yields at least one and at most two characters out.

package body Reply_Text_Pkg with SPARK_Mode is

   ---------------------
   -- Escape_Quotes --
   ---------------------

   function Escape_Quotes (S : String) return String is
      Buf : String (1 .. 2 * S'Length) := (others => ' ');
      Len : Natural := 0;
   begin
      for I in S'Range loop
         if S (I) = '"' then
            Buf (Len + 1) := '\';
            Buf (Len + 2) := '"';
            Len := Len + 2;
         else
            Buf (Len + 1) := S (I);
            Len := Len + 1;
         end if;

         pragma Loop_Invariant (Len >= I - S'First + 1);
         pragma Loop_Invariant (Len <= 2 * (I - S'First + 1));
         pragma Loop_Invariant (Len <= Buf'Last);
      end loop;

      return Buf (1 .. Len);
   end Escape_Quotes;

end Reply_Text_Pkg;