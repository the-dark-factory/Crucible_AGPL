--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Channel_Wiring_Pkg body, lineage 2 (2026-09-13): body-filled behind wire_gate.bb, proved through the Reference
--  instance; Close counts this producer and closes the value queue under the last one. Never hand-edited.
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
            if Finished < Producers then
               Finished := Finished + 1;
            end if;
            if Finished = Producers then
               Value := Q.Close (Value);
            end if;
         end Close;

         function Fill return Q.Count is (Value.Length);

         function Is_Closed return Boolean is (Value.Closed);

         function Finished_Count return Natural is (Finished);
      end Wire;
   end Wiring;

   package Reference is new Wiring (Q => Bounded_Channel_Pkg.Reference, Initial => 0);

end Channel_Wiring_Pkg;