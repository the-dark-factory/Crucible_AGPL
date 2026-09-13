--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Body of Mascot_Emit_Pkg: Ada_Name only (every other function is an expression function).
--  body-fill-bench, qwen3-coder:30b via ollama, candidate 1, gnatprove level 2 discharged, 2026-09-13.
--  Never hand-edited.
package body Mascot_Emit_Pkg with SPARK_Mode is

   function Ada_Name (S : String) return String
   is
      R : String (1 .. S'Length) := (others => ' ');
   begin
      for K in S'Range loop
         if Is_Separator (S (K)) then
            R (K) := '_';
         elsif K = S'First or else Is_Separator (S (K - 1)) then
            R (K) := Upper (S (K));
         else
            R (K) := S (K);
         end if;
         pragma Loop_Invariant
           (for all I in S'First .. K =>
              R (I) = (if Is_Separator (S (I)) then '_'
                       elsif I = S'First or else Is_Separator (S (I - 1)) then Upper (S (I))
                       else S (I)));
      end loop;
      return R;
   end Ada_Name;

end Mascot_Emit_Pkg;