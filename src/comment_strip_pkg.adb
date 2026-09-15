--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Body of Comment_Strip_Pkg: Stripped only. body-fill-bench, qwen3-coder:30b via ollama, candidate 1,
--  gnatprove level 2 discharged, 2026-09-13. Never hand-edited.
package body Comment_Strip_Pkg with SPARK_Mode is

   function Stripped (S : String) return String is
      Buf : String (1 .. S'Length + 1) := (others => ' ');
      Last : Natural := 0;
      I : Positive := 1;
   begin
      while I <= S'Last loop
         pragma Loop_Invariant (Last <= I - 1);
         pragma Loop_Invariant (Last <= Buf'Last);
         pragma Loop_Variant (Increases => I);
         declare
            E : constant Positive := Line_End (S, I);
         begin
            if Is_Kept (S, I, E) then
               for K in I .. E - 1 loop
                  pragma Loop_Invariant (Last = Last'Loop_Entry + (K - I));
                  Last := Last + 1;
                  Buf (Last) := S (K);
               end loop;
               Last := Last + 1;
               Buf (Last) := LF;
            end if;
            I := E + 1;
         end;
      end loop;
      return Buf (1 .. Last);
   end Stripped;

end Comment_Strip_Pkg;