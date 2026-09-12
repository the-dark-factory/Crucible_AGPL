--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Body of Reply_Text_Pkg: only Escape_Quotes needs a body; every other operation is an
--  expression function completed in the spec. Written by the ANVIL lane's body-fill
--  (claude-cli, candidate 2; candidate 1 failed proof), job job-46218f0bf97cd3709a6171a8
--  verified 2026-09-12 09:36; results.jsonl still records via/model as null (harness gap noted
--  2026-09-11). Re-proved with the spec as built: 237 checks, 0 unproved, 0 warnings.
--  Escapes '"' only, not '\' -- see the spec header. Carried unchanged.
pragma Ada_2012;

--  Body for Reply_Text_Pkg.
--
--  Every other operation in the specification is an expression function
--  completed in the spec itself; only Escape_Quotes needs a body here.
--
--  Escape_Quotes prefixes each double-quote character with a backslash so
--  the text can be embedded inside a JSON string literal.  The output
--  buffer is fully initialised at declaration (no box notation) so that
--  gnatprove can discharge the "Result might not be initialized" check,
--  and the loop carries an inductive invariant bounding the fill counter
--  between I and 2 * I, which is exactly what the postcondition needs.

package body Reply_Text_Pkg with SPARK_Mode => On is

   function Escape_Quotes (S : String) return String is
      Result : String (1 .. 2 * S'Length) := (others => ' ');
      Len    : Natural                    := 0;
   begin
      --  Pre guarantees S'First = 1, so S'Range is 1 .. S'Length.
      for I in S'Range loop
         pragma Loop_Invariant (Len >= I - 1);
         pragma Loop_Invariant (Len <= 2 * (I - 1));

         if S (I) = '"' then
            Result (Len + 1) := '\';
            Result (Len + 2) := '"';
            Len := Len + 2;
         else
            Result (Len + 1) := S (I);
            Len := Len + 1;
         end if;
      end loop;

      pragma Assert (Len >= S'Length);
      pragma Assert (Len <= 2 * S'Length);

      return Result (1 .. Len);
   end Escape_Quotes;

end Reply_Text_Pkg;