--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 6a0aa2695e6a125cca49cde84594bc7a4c3ff125076147c4f8dbb345359fc57d
--
with Ada.Text_IO;
with Json_Scan_Pkg;
with Frame_Facts_Pkg;
with Edition_Licence_Pkg;
with Crucible_Edition;
with Door_Port_Pkg;
with Intake_Gate_Pkg;
with Sovereign_Gate_Pkg;
with Reply_Text_Pkg;
with Door_Responder_Pkg;

procedure Expand_Front is
   use type Door_Port_Pkg.Fault_Kind;
   use type Intake_Gate_Pkg.Fault_Kind;
   use type Sovereign_Gate_Pkg.Route_Kind;

   Host_Buf : String (1 .. 256);
   Port_Buf : String (1 .. 256);
   Sov_Buf  : String (1 .. 256);
   Line_Buf : String (1 .. 65536);

   Host_Last  : Natural;
   Port_Last  : Natural;
   Sov_Last   : Natural;
   Line_Last  : Natural;

begin
   Ada.Text_IO.Get_Line (Host_Buf, Host_Last);
   Ada.Text_IO.Get_Line (Port_Buf, Port_Last);
   Ada.Text_IO.Get_Line (Sov_Buf, Sov_Last);
   Ada.Text_IO.Get_Line (Line_Buf, Line_Last);

   declare
      Host      : constant String := Host_Buf (1 .. Host_Last);
      Port_Text : constant String := Port_Buf (1 .. Port_Last);
      Sov_Text  : constant String := Sov_Buf (1 .. Sov_Last);
      Line      : constant String := Line_Buf (1 .. Line_Last);

      Http_Prefix : constant String := "http://";
      Colon       : constant String := ":";
      Null_Id     : constant String := "null";
      Prompt_Mark : constant String := "P";
      Refusal_Mark : constant String := "R";
      Msg_Door    : constant String := "door refused ";
      Msg_Intake  : constant String := "intake refused ";
      Msg_Route   : constant String := "sovereign rail refuses off-estate endpoint";
      Design_Instruction : constant String :=
        "Emit a MASCOT design as JSON lines: exactly one subsystem per line, "
        & "each line one flat JSON object with string values only and no nesting. "
        & "Keys: id (required); kind (required: activity, pool, channel or composite); "
        & "element (typed channel or pool); buffer (buffered channel); producer (one) or "
        & "producers (many); consumer (one) or consumers (many); reporting:true on the one "
        & "events channel; reads, writes, reports (activity); accessed (pool); discharge "
        & "(any leaf: what is proved here); children (composite). No prose, no fences. Brief: ";
      Licence_Present : constant Boolean := True;
      Edition : constant Edition_Licence_Pkg.Edition_Type :=
        (if Crucible_Edition.Is_Agpl then Edition_Licence_Pkg.Agpl else Edition_Licence_Pkg.Commercial);
      Requested : constant Edition_Licence_Pkg.Requested_Licence_Type :=
        (if Crucible_Edition.Is_Agpl then Edition_Licence_Pkg.Agpl_Licence else Edition_Licence_Pkg.Proprietary_Licence);

      Span : constant Json_Scan_Pkg.Span_Type := Frame_Facts_Pkg.Id_Span (Line);
      Id   : constant String (1 .. (if Span.found then Span.last - Span.first + 1 else Null_Id'Length)) :=
        (if Span.found then Line (Span.first .. Span.last) else Null_Id);

      procedure Refuse (Msg : String) is
      begin
         Ada.Text_IO.Put_Line (Refusal_Mark);
         Ada.Text_IO.Put_Line (Door_Responder_Pkg.Reply_Of (Id, Refused => True, Stamped => False, Design_Text => Null_Id, Fault_Message => Msg));
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
      end;

      declare
         B : constant Json_Scan_Pkg.Span_Type := Door_Port_Pkg.Brief_Span (Line);
         Brief : constant String (1 .. B.last - B.first + 1) := Line (B.first .. B.last);
      begin
         declare
            G : constant Intake_Gate_Pkg.Fault_Kind := Intake_Gate_Pkg.Fault_Of (Brief);
         begin
            if G /= Intake_Gate_Pkg.No_Fault then
               Refuse (Msg_Intake & Reply_Text_Pkg.Image_Of (Intake_Gate_Pkg.Fault_Kind'Pos (G)));
               return;
            end if;
         end;

         declare
            Endpoint  : constant String := Http_Prefix & Host & Colon & Port_Text;
            Sovereign : constant Boolean := Sov_Text'Length >= 1 and then Sov_Text (1) = '1';
         begin
            if Sovereign_Gate_Pkg.Route_Of (Endpoint, Sovereign) = Sovereign_Gate_Pkg.Refused_Sovereign_Off_Estate then
               Refuse (Msg_Route);
               return;
            end if;
         end;

         Ada.Text_IO.Put_Line (Prompt_Mark);
         Ada.Text_IO.Put_Line (Id);
         Ada.Text_IO.Put_Line (Design_Instruction & Brief);
         Ada.Text_IO.Flush;
      end;
   end;
end Expand_Front;
