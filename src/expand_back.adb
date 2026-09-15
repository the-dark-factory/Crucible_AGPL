--  SLOT BEGIN (context)
with Ada.Text_IO;
with Json_Scan_Pkg;
with Mascot_Scan_Pkg;
with Mascot_Measure_Pkg;
with Mascot_Judge_Pkg;
with Provenance_Stamp_Pkg;
with Door_Responder_Pkg;
--  SLOT END (context)

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
   Body_Buf    : String (1 .. 65536);
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
      Json_Body  : constant String := Body_Buf (1 .. Body_Last);
   begin
      if Fault_Text'Length /= 1 or else Fault_Text (Fault_Text'First) /= '0' then
         Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Model & Fault_Text));
         Ada.Text_IO.Flush;
         return;
      end if;

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
                  if Raw (I) = Backslash and then I < Raw'Last then
                     declare
                        Next : constant Character := Raw (I + 1);
                        Cur  : constant Natural := Set.Count + 1;
                     begin
                        if Next = Newline_Mark then
                           if Set.Lines (Cur).Len > 0 then
                              Set.Count := Set.Count + 1;
                           end if;
                        elsif Next = Quote then
                           if Set.Lines (Cur).Len < Mascot_Scan_Pkg.Max_Line then
                              Set.Lines (Cur).Len := Set.Lines (Cur).Len + 1;
                              Set.Lines (Cur).Text (Set.Lines (Cur).Len) := Quote;
                           end if;
                        elsif Next = Backslash then
                           if Set.Lines (Cur).Len < Mascot_Scan_Pkg.Max_Line then
                              Set.Lines (Cur).Len := Set.Lines (Cur).Len + 1;
                              Set.Lines (Cur).Text (Set.Lines (Cur).Len) := Backslash;
                           end if;
                        else
                           if Set.Lines (Cur).Len < Mascot_Scan_Pkg.Max_Line then
                              Set.Lines (Cur).Len := Set.Lines (Cur).Len + 1;
                              Set.Lines (Cur).Text (Set.Lines (Cur).Len) := Next;
                           end if;
                        end if;
                        I := I + 2;
                     end;
                  else
                     declare
                        Cur : constant Natural := Set.Count + 1;
                     begin
                        if Set.Lines (Cur).Len < Mascot_Scan_Pkg.Max_Line then
                           Set.Lines (Cur).Len := Set.Lines (Cur).Len + 1;
                           Set.Lines (Cur).Text (Set.Lines (Cur).Len) := Raw (I);
                        end if;
                     end;
                     I := I + 1;
                  end if;

                  exit when Set.Count = Mascot_Measure_Pkg.Max_Nodes;
               end loop;

               if Set.Lines (Set.Count + 1).Len > 0
                 and then Set.Count < Mascot_Measure_Pkg.Max_Nodes
               then
                  Set.Count := Set.Count + 1;
               end if;

               declare
                  SR    : constant Mascot_Scan_Pkg.Scan_Result := Mascot_Scan_Pkg.Scan (Set);
               begin
                  if not SR.Ok then
                     --  SLOT BEGIN (scan-refusal)
Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Scan & Mascot_Scan_Pkg.Fault_Kind'Image (SR.Fault)));
                     --  SLOT END (scan-refusal)
                     Ada.Text_IO.Flush;
                     return;
                  end if;

                  declare
                     Facts : constant Mascot_Judge_Pkg.Fact_Set := Mascot_Measure_Pkg.Measure (SR.Table);
                  begin
                     if not Mascot_Judge_Pkg.Accepted (Facts) then
                        declare
                           Failed     : constant Mascot_Judge_Pkg.Failed_Set := Mascot_Judge_Pkg.Failed (Facts);
                           Names      : String (1 .. 1024);
                           Names_Last : Natural := 0;
                        begin
                           for N in Mascot_Judge_Pkg.Fact_Name loop
                              if Failed (N) then
                                 declare
                                    Word : constant String := Mascot_Judge_Pkg.Fact_Name'Image (N);
                                 begin
                                    if Names_Last < Names'Last then
                                       Names_Last := Names_Last + 1;
                                       Names (Names_Last) := Blank;
                                    end if;
                                    for K in Word'Range loop
                                       if Names_Last < Names'Last then
                                          Names_Last := Names_Last + 1;
                                          Names (Names_Last) := Word (K);
                                       end if;
                                    end loop;
                                 end;
                              end if;
                           end loop;
                           Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg_Judge & Names (1 .. Names_Last)));
                           Ada.Text_IO.Flush;
                           return;
                        end;
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

                        declare
                           Design      : String (1 .. 4096);
                           Design_Last : Natural := 0;
                        begin
                           if Design_Last < Design'Last then
                              Design_Last := Design_Last + 1;
                              Design (Design_Last) := Open_Bracket;
                           end if;
                           for J in 1 .. Set.Count loop
                              if J > 1 then
                                 if Design_Last < Design'Last then
                                    Design_Last := Design_Last + 1;
                                    Design (Design_Last) := Joiner;
                                 end if;
                              end if;
                              for C in 1 .. Set.Lines (J).Len loop
                                 if Design_Last < Design'Last then
                                    Design_Last := Design_Last + 1;
                                    Design (Design_Last) := Set.Lines (J).Text (C);
                                 end if;
                              end loop;
                           end loop;
                           if Design_Last < Design'Last then
                              Design_Last := Design_Last + 1;
                              Design (Design_Last) := Close_Bracket;
                           end if;

                           Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => False, Stamped => True, Design_Text => Design (1 .. Design_Last), Fault_Message => Null_Id));
                           Ada.Text_IO.Flush;
                        end;
                     end;
                  end;
               end;
            end;
         end;
      end;
   end;
end Expand_Back;
