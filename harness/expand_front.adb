--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: c73871df3a2188ab60023df32bd7d8333f414fcdca99217bbcb8aa71748c63bf
--
with Ada.Text_IO;
with Frame_Facts_Pkg;
with Edition_Licence_Pkg;
with Crucible_Edition;
with Door_Port_Pkg;
with Intake_Gate_Pkg;
with Sovereign_Gate_Pkg;
with Reply_Text_Pkg;
with Door_Responder_Pkg;

procedure Expand_Front is
   Host_Buf : String (1 .. 256);
   Port_Buf : String (1 .. 256);
   Sov_Buf  : String (1 .. 256);
   Line_Buf : String (1 .. 65536);

   Host_Last : Natural;
   Port_Last : Natural;
   Sov_Last  : Natural;
   Line_Last : Natural;
begin
   Ada.Text_IO.Get_Line (Host_Buf, Host_Last);
   Ada.Text_IO.Get_Line (Port_Buf, Port_Last);
   Ada.Text_IO.Get_Line (Sov_Buf, Sov_Last);
   Ada.Text_IO.Get_Line (Line_Buf, Line_Last);

   declare
      use type Door_Port_Pkg.Fault_Kind;
      use type Intake_Gate_Pkg.Fault_Kind;
      use type Sovereign_Gate_Pkg.Route_Kind;

      Host      : constant String := Host_Buf (1 .. Host_Last);
      Port_Text : constant String := Port_Buf (1 .. Port_Last);
      Sov_Text  : constant String := Sov_Buf (1 .. Sov_Last);
      Line      : constant String := Line_Buf (1 .. Line_Last);

      Http_Prefix  : constant String := "http://";
      Colon        : constant String := ":";
      Null_Id      : constant String := "null";
      Prompt_Mark  : constant String := "P";
      Refusal_Mark : constant String := "R";
      Msg_Door     : constant String := "door refused ";
      Msg_Intake   : constant String := "intake refused ";
      Msg_Route    : constant String := "sovereign rail refuses off-estate endpoint";
      Licence_Present : constant Boolean := True;
      Edition : constant Edition_Licence_Pkg.Edition_Type :=
        (if Crucible_Edition.Is_Agpl then Edition_Licence_Pkg.Agpl else Edition_Licence_Pkg.Commercial);
      Requested : constant Edition_Licence_Pkg.Requested_Licence_Type :=
        (if Crucible_Edition.Is_Agpl then Edition_Licence_Pkg.Agpl_Licence else Edition_Licence_Pkg.Proprietary_Licence);

      Design_Instruction : constant String :=
        "Emit a MASCOT design as JSON lines: exactly one subsystem per line, each line one flat JSON "
        & "object, every value a double-quoted string (no numbers, no lists, no nesting), no prose, no "
        & "fences, no comments. Keys: id, kind, element, buffer, producer, producers, consumer, "
        & "reporting, reads, writes, reports, accessed, discharge, children. A proven judge refuses the "
        & "design unless ALL of these hold: "
        & "(1) every line has id and kind; kind is activity, pool, channel or composite. "
        & "(2) every channel line has element (the type carried), buffer (the depth, e.g. 1), producer "
        & "(one activity id) or producers (activity ids separated by spaces), and consumer naming exactly "
        & "ONE activity id. "
        & "Carry data in POOLS, not channels: every input the operation reads and every result it produces "
        & "lives in a pool whose accessed names the activities that use it. The events channel is the ONLY "
        & "channel from the worker to the sink. "
        & "(3) exactly one channel is the events channel: it has reporting set to true, and exactly one "
        & "activity (the sink) consumes it. "
        & "(4) every activity line has reports naming that events channel id, and reads or writes naming "
        & "channel or pool ids (space separated). "
        & "(5) every pool line has element and accessed naming the activity ids that use it. "
        & "(6) every activity and every pool has discharge: the obligation proved there, in words, never "
        & "empty. "
        & "(7) every composite line has children naming ids; every other line is a leaf. "
        & "(8) the data flow between activities has no cycle, and no two channels join the same producer "
        & "to the same consumer. "
        & "Example line: {""id"":""events"",""kind"":""channel"",""element"":""Event"",""buffer"":""8"","
        & """producer"":""searcher"",""consumer"":""reporter"",""reporting"":""true""} "
        & "Example pool line (every pool carries its discharge): {""id"":""input"",""kind"":""pool"",""element"":""Input"","
        & """accessed"":""worker"",""discharge"":""the input is read-only while the worker runs""} "
        & "Example activity line (the sink; every activity reports on the events channel and carries its discharge): "
        & "{""id"":""reporter"",""kind"":""activity"",""reads"":""events"",""reports"":""events"","
        & """discharge"":""every event is written once, in order""} "
        & "Depth: give every decision the brief names its own activity; never merge two decisions into one "
        & "activity, and never leave a decision the brief names without an activity whose discharge states it. "
        & "Brief: ";

      Id_Found : constant Boolean := Frame_Facts_Pkg.Id_Span (Line).found;
      Id_First : constant Natural := Frame_Facts_Pkg.Id_Span (Line).first;
      Id_Last  : constant Natural := Frame_Facts_Pkg.Id_Span (Line).last;
      Id       : constant String (1 .. (if Id_Found then Id_Last - Id_First + 1 else Null_Id'Length)) :=
        (if Id_Found then Line (Id_First .. Id_Last) else Null_Id);

      procedure Refuse (Msg : String) is
      begin
         Ada.Text_IO.Put_Line (Refusal_Mark);
         Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False,
           Design_Text => Null_Id, Fault_Message => Msg));
         Ada.Text_IO.Flush;
      end Refuse;

   begin
      declare
         F : constant Door_Port_Pkg.Fault_Kind := Door_Port_Pkg.Fault_Of (Line, Licence_Present, Edition, Requested);
      begin
         if F /= Door_Port_Pkg.No_Fault then
            Refuse (Msg_Door & Reply_Text_Pkg.Image_Of (Door_Port_Pkg.Fault_Kind'Pos (F)));
            return;
         end if;

         declare
            B_First : constant Natural := Door_Port_Pkg.Brief_Span (Line).first;
            B_Last  : constant Natural := Door_Port_Pkg.Brief_Span (Line).last;
            Brief   : constant String (1 .. B_Last - B_First + 1) := Line (B_First .. B_Last);
         begin
            declare
               G : constant Intake_Gate_Pkg.Fault_Kind := Intake_Gate_Pkg.Fault_Of (Brief);
            begin
               if G /= Intake_Gate_Pkg.No_Fault then
                  Refuse (Msg_Intake & Reply_Text_Pkg.Image_Of (Intake_Gate_Pkg.Fault_Kind'Pos (G)));
                  return;
               end if;

               declare
                  Endpoint  : constant String := Http_Prefix & Host & Colon & Port_Text;
                  Sovereign : constant Boolean := Sov_Text'Length >= 1 and then Sov_Text (1) = '1';
               begin
                  if Sovereign_Gate_Pkg.Route_Of (Endpoint, Sovereign) = Sovereign_Gate_Pkg.Refused_Sovereign_Off_Estate then
                     Refuse (Msg_Route);
                     return;
                  end if;

                  Ada.Text_IO.Put_Line (Prompt_Mark);
                  Ada.Text_IO.Put_Line (Id);
                  Ada.Text_IO.Put_Line (Design_Instruction & Brief);
                  Ada.Text_IO.Flush;
               end;
            end;
         end;
      end;
   end;
end Expand_Front;
