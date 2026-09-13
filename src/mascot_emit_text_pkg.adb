--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Body of Mascot_Emit_Text_Pkg: Stem_Of only. body-fill-bench, qwen3-coder:30b via ollama, candidate 1
--  behind the no_unreferenced.bb tier-3 gate, gnatprove level 2 discharged, 2026-09-13. Never hand-edited.
package body Mascot_Emit_Text_Pkg with SPARK_Mode is

   function Stem_Of (Name : String) return String
   is
      R : String (1 .. Name'Length) := (others => ' ');
   begin
      for K in Name'Range loop
         R (K) := Lower (Name (K));
         pragma Loop_Invariant (for all I in Name'First .. K => R (I) = Lower (Name (I)));
      end loop;
      return R;
   end Stem_Of;

end Mascot_Emit_Text_Pkg;