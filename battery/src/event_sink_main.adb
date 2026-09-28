--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 386d9c197854cc8ccd1b687e780e9f7e83320f9f84f981a650844f6f26c1ff15
--
with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;

procedure Event_Sink_Main is
   use type GNAT.OS_Lib.File_Descriptor;

   HT : constant Character := Character'Val (9);
   LF : constant Character := Character'Val (10);

   --  SLOT BEGIN (scan)
   function Decimal (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      if S (S'First) = ' ' then
         return S (S'First + 1 .. S'Last);
      else
         return S;
      end if;
   end Decimal;

   procedure Write_Record (FD : GNAT.OS_Lib.File_Descriptor; S : String) is
      Line : constant String := S & LF;
      Result : Integer;
   begin
      if FD /= GNAT.OS_Lib.Invalid_FD then
         Result := GNAT.OS_Lib.Write (FD, Line'Address, Line'Length);
      end if;
   end Write_Record;

   procedure Handle_Line (FD : GNAT.OS_Lib.File_Descriptor; Line : String; K : Positive; Written : in out Natural) is
      Count : Natural := 0;
   begin
      for J in Line'Range loop
         if Line (J) = HT then
            Count := Count + 1;
         end if;
      end loop;
      if Count = 3 then
         Write_Record (FD, Line);
         Written := Written + 1;
      else
         Write_Record (FD, "event-sink" & HT & "malformed_record" & HT & HT & Decimal (K));
      end if;
   end Handle_Line;
   --  SLOT END (scan)
begin
   --  SLOT BEGIN (main)
   declare
      Chunk   : String (1 .. 65_536);
      N       : Integer;
      Current : Ada.Strings.Unbounded.Unbounded_String;
      FD      : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      K       : Natural := 0;
      Written : Natural := 0;
   begin
      if Ada.Environment_Variables.Exists ("VACUITY_EVENTS")
        and then Ada.Environment_Variables.Value ("VACUITY_EVENTS") /= ""
      then
         FD := GNAT.OS_Lib.Open_Append (Ada.Environment_Variables.Value ("VACUITY_EVENTS"), GNAT.OS_Lib.Binary);
      end if;
      Write_Record (FD, "event-sink" & HT & "sink_started" & HT & HT);
      loop
         N := GNAT.OS_Lib.Read (GNAT.OS_Lib.Standin, Chunk'Address, Chunk'Length);
         exit when N <= 0;
         for I in 1 .. N loop
            if Chunk (I) = LF then
               K := K + 1;
               Handle_Line (FD, Ada.Strings.Unbounded.To_String (Current), K, Written);
               Current := Ada.Strings.Unbounded.Null_Unbounded_String;
            else
               Ada.Strings.Unbounded.Append (Current, Chunk (I));
            end if;
         end loop;
      end loop;
      if Ada.Strings.Unbounded.Length (Current) > 0 then
         K := K + 1;
         Handle_Line (FD, Ada.Strings.Unbounded.To_String (Current), K, Written);
      end if;
      Write_Record (FD, "event-sink" & HT & "sink_finished" & HT & HT & Decimal (Written));
      if FD /= GNAT.OS_Lib.Invalid_FD then
         GNAT.OS_Lib.Close (FD);
      end if;
   end;
   --  SLOT END (main)
end Event_Sink_Main;
