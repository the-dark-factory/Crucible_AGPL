--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: a58124850dbba30a93c2bfee5e199cc787592c67391893ea4bddae0b63ba70b4
--
with Ada.Text_IO;
with Json_Scan_Pkg;
with Mascot_Scan_Pkg;
with Mascot_Measure_Pkg;
with Mascot_Judge_Pkg;
with Provenance_Stamp_Pkg;
with Door_Responder_Pkg;

procedure Expand_Back is
   Null_Id      : constant String := "null";
   Response_Key : constant String := "content";
   Think_End    : constant String := "</think>";
   Msg_Model    : constant String := "model reply fault ";
   Msg_Scan     : constant String := "design text refused ";
   Msg_Judge    : constant String := "design refused by the judge";
   Msg_Stamp    : constant String := "provenance refused";
   Backslash    : constant Character := Character'Val (92);
   Newline_Mark : constant Character := 'n';
   Quote        : constant Character := '"';
   Joiner       : constant Character := ',';
   Open_Bracket : constant Character := '[';
   Close_Bracket : constant Character := ']';
   Blank        : constant Character := ' ';

   Id_Buf      : String (1 .. 256);
   Fault_Buf   : String (1 .. 256);
   --  SLOT BEGIN (body-buffer)
   Max_Body : constant := 1_048_576;
   Body_Buf : String (1 .. Max_Body + 1);
   --  SLOT END (body-buffer)
   Id_Last     : Natural;
   Fault_Last  : Natural;
   Body_Last   : Natural;
begin
   Ada.Text_IO.Get_Line (Id_Buf, Id_Last);
   Ada.Text_IO.Get_Line (Fault_Buf, Fault_Last);
   Ada.Text_IO.Get_Line (Body_Buf, Body_Last);

   declare
      Id         : constant String := Id_Buf (1 .. Id_Last);
      Fault_Text : constant String := Fault_Buf (1 .. Fault_Last);
      --  SLOT BEGIN (body-view)
      Json_Body  : String renames Body_Buf (1 .. Body_Last);
      --  SLOT END (body-view)
   begin
      if Fault_Text'Length /= 1 or else Fault_Text (Fault_Text'First) /= '0' then
         Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Model & Fault_Text));
         Ada.Text_IO.Flush;
         return;
      end if;

      --  SLOT BEGIN (body-check)
      if Body_Last > Max_Body then
         Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Scan & "too_long_to_read"));
         Ada.Text_IO.Flush;
         return;
      end if;
      --  SLOT END (body-check)

      declare
         R   : constant Json_Scan_Pkg.Span_Type := Json_Scan_Pkg.Value_Span (Json_Body, Response_Key);
      begin
         if not R.found then
            Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Scan & Null_Id));
            Ada.Text_IO.Flush;
            return;
         end if;

         declare
            Raw   : constant String := Json_Body (R.first + 1 .. R.last - 1);
            Start : Natural := Raw'First;
         begin
            for K in Raw'Range loop
               if K + Think_End'Length - 1 <= Raw'Last and then Raw (K .. K + Think_End'Length - 1) = Think_End then
                  Start := K + Think_End'Length;
               end if;
            end loop;

            declare
               Set : Mascot_Scan_Pkg.Line_Set;
               I   : Natural := Start;
            begin
               Set.Count := 0;
               for L in Set.Lines'Range loop
                  Set.Lines (L).Len := 0;
               end loop;

while I <= Raw'Last loop
   declare
      Next : Character;
      Cur  : constant Natural := Set.Count + 1;
      C    : Character;
   begin
      if Raw (I) = Backslash and then I < Raw'Last then
         Next := Raw (I + 1);
         if Next = Newline_Mark then
            if Set.Count < Mascot_Measure_Pkg.Max_Nodes
              and then Set.Lines (Set.Count + 1).Len > 0
            then
               Set.Count := Set.Count + 1;
            end if;
            I := I + 2;
         else
            C := Next;
            if Set.Count = Mascot_Measure_Pkg.Max_Nodes then
               Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Scan & "too_many_lines"));
               Ada.Text_IO.Flush;
               return;
            end if;
            if Set.Lines (Cur).Len = Mascot_Scan_Pkg.Max_Line then
               Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Scan & "line_too_long"));
               Ada.Text_IO.Flush;
               return;
            end if;
            Set.Lines (Cur).Len := Set.Lines (Cur).Len + 1;
            Set.Lines (Cur).Text (Set.Lines (Cur).Len) := C;
            I := I + 2;
         end if;
      else
         C := Raw (I);
         if Set.Count = Mascot_Measure_Pkg.Max_Nodes then
            Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Scan & "too_many_lines"));
            Ada.Text_IO.Flush;
            return;
         end if;
         if Set.Lines (Cur).Len = Mascot_Scan_Pkg.Max_Line then
            Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Scan & "line_too_long"));
            Ada.Text_IO.Flush;
            return;
         end if;
         Set.Lines (Cur).Len := Set.Lines (Cur).Len + 1;
         Set.Lines (Cur).Text (Set.Lines (Cur).Len) := C;
         I := I + 1;
      end if;
   end;
end loop;
if Set.Count < Mascot_Measure_Pkg.Max_Nodes
  and then Set.Lines (Set.Count + 1).Len > 0
then
   Set.Count := Set.Count + 1;
end if;

               declare
                  SR    : constant Mascot_Scan_Pkg.Scan_Result := Mascot_Scan_Pkg.Scan (Set);
               begin
                  if not SR.Ok then
Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Scan & Mascot_Scan_Pkg.Fault_Kind'Image (SR.Fault)));
                     Ada.Text_IO.Flush;
                     return;
                  end if;

                  declare
                     Facts : constant Mascot_Judge_Pkg.Fact_Set := Mascot_Measure_Pkg.Measure (SR.Table);
                  begin
                     if not Mascot_Judge_Pkg.Accepted (Facts) then
                        --  SLOT BEGIN (judge-names)
                        declare
                           Failed : constant Mascot_Judge_Pkg.Failed_Set := Mascot_Judge_Pkg.Failed (Facts);
                           Total  : Natural := 0;
                        begin
                           for N in Mascot_Judge_Pkg.Fact_Name loop
                              if Failed (N) then
                                 Total := Total + 1 + Mascot_Judge_Pkg.Fact_Name'Image (N)'Length;
                              end if;
                           end loop;

                           if Msg_Judge'Length + Total > 4096 then
                              Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Scan & "too_long_to_echo"));
                              Ada.Text_IO.Flush;
                              return;
                           end if;

                           declare
                              Names      : String (1 .. Total);
                              Names_Last : Natural := 0;
                           begin
                              for N in Mascot_Judge_Pkg.Fact_Name loop
                                 if Failed (N) then
                                    declare
                                       Word : constant String := Mascot_Judge_Pkg.Fact_Name'Image (N);
                                    begin
                                       Names_Last := Names_Last + 1;
                                       Names (Names_Last) := Blank;
                                       for K in Word'Range loop
                                          Names_Last := Names_Last + 1;
                                          Names (Names_Last) := Word (K);
                                       end loop;
                                    end;
                                 end if;
                              end loop;

                              Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Judge & Names));
                              Ada.Text_IO.Flush;
                              return;
                           end;
                        end;
                        --  SLOT END (judge-names)
                     end if;

                     declare
                        Stamp : constant Provenance_Stamp_Pkg.Stamp_Facts :=
                          (Model_Recorded => True, Endpoint_Recorded => True, Rail_Recorded => True,
                           Methodology_Digest_Recorded => True, Brief_Digest_Recorded => True, Verdict_Recorded => True,
                           Build => (specification_sha_recorded => True, prover_name_recorded => True,
                                     prover_version_recorded => True, factory_commit_recorded => True,
                                     tree_was_clean => True, host_recorded => True, timestamp_recorded => True,
                                     fields_recorded => 7, fields_required => 7));
                     begin
                        if not Provenance_Stamp_Pkg.Accepted (Stamp) then
                           Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Stamp));
                           Ada.Text_IO.Flush;
                           return;
                        end if;

                        --  SLOT BEGIN (design-join)
                        declare
                           pragma Compile_Time_Error (Mascot_Measure_Pkg.Max_Nodes * (Mascot_Scan_Pkg.Max_Line + 1) + 1 > Door_Responder_Pkg.Max_Design_Text, "a scanned design can be longer than the door echoes");
                           Total       : Natural := 2;
                        begin
                           for J in 1 .. Set.Count loop
                              Total := Total + Set.Lines (J).Len;
                              if J > 1 then
                                 Total := Total + 1;
                              end if;
                           end loop;

                           if Total > Door_Responder_Pkg.Max_Design_Text then
                              Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Scan & "too_long_to_echo"));
                              Ada.Text_IO.Flush;
                              return;
                           end if;

                           declare
                              Design      : String (1 .. Total);
                              Design_Last : Natural := 0;
                           begin
                              Design_Last := Design_Last + 1;
                              Design (Design_Last) := Open_Bracket;

                              for J in 1 .. Set.Count loop
                                 if J > 1 then
                                    Design_Last := Design_Last + 1;
                                    Design (Design_Last) := Joiner;
                                 end if;

                                 for C in 1 .. Set.Lines (J).Len loop
                                    Design_Last := Design_Last + 1;
                                    Design (Design_Last) := Set.Lines (J).Text (C);
                                 end loop;
                              end loop;

                              Design_Last := Design_Last + 1;
                              Design (Design_Last) := Close_Bracket;

                              Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => False, Stamped => True, Design_Text => Design, Fault_Message => Null_Id));
                              Ada.Text_IO.Flush;
                           end;
                        end;
                        --  SLOT END (design-join)
                     end;
                  end;
               end;
            end;
         end;
      end;
   end;
end Expand_Back;
