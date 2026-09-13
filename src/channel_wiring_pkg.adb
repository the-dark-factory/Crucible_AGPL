--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Body of Channel_Wiring_Pkg: the protected body of Wire and the reference instance through which it is
--  proved. body-fill-bench, qwen3-coder:30b via ollama, behind wire_gate.bb, gnatprove level 2 discharged,
--  2026-09-13. Never hand-edited.
package body Channel_Wiring_Pkg with SPARK_Mode is
   package body Wiring is
      protected body Wire is
         entry Put (E : Q.Element_Type; Accepted : out Boolean)
           when Value.Length < Cap or else Value.Closed is
         begin
            if Q.Is_Closed (Value) then
               Accepted := False;
            else
               Value := Q.Put (Value, E);
               Accepted := True;
            end if;
         end Put;

         entry Take (E : out Q.Element_Type; Done : out Boolean)
           when Value.Length > 0 or else Value.Closed is
         begin
            if Q.Is_Empty (Value) then
               E := Initial;
               Done := True;
            else
               E := Q.First (Value);
               Value := Q.Take (Value);
               Done := False;
            end if;
         end Take;

         procedure Close is
         begin
            Value := Q.Close (Value);
         end Close;

         function Fill return Q.Count is (Value.Length);

         function Is_Closed return Boolean is (Value.Closed);
      end Wire;
   end Wiring;

   package Reference is new Wiring (Q => Bounded_Channel_Pkg.Reference, Initial => 0);

end Channel_Wiring_Pkg;