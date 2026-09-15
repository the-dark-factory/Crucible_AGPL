--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Body of Pool_Wiring_Pkg: the protected body of Store and the reference instance through which it is
--  proved. body-fill-bench, qwen3-coder:30b via ollama, behind store_gate.bb, gnatprove level 2 discharged,
--  2026-09-13. Never hand-edited.
package body Pool_Wiring_Pkg with SPARK_Mode is
   package body Wiring is
      protected body Store is
         function Read return P.State_Type is (P.Read (Value));

         procedure Write (V : P.State_Type; Accepted : out Boolean) is
         begin
            Accepted := P.May_Write (Value) and then P.Write_Count (Value) < Natural'Last;
            if Accepted then
               Value := P.Write (Value, V);
            end if;
         end Write;

         function Write_Count return Natural is (P.Write_Count (Value));
      end Store;
   end Wiring;

   package Reference is new Wiring (P => Pool_Pkg.Reference, Initial => 0);

end Pool_Wiring_Pkg;