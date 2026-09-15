--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 575dec878630ba93c9b8b5019a83d82f50f3ff2bc8d3800a042d151085a51c99
--
package Audit_Ledger_Pkg with SPARK_Mode is

   Capacity : constant := 4096;

   subtype Entry_Count is Natural range 0 .. Capacity;
   subtype Entry_Index is Positive range 1 .. Capacity;

   type Activity_Kind is
     (Door_Listener,
      Licence_Gate,
      Intake_Gate,
      Sovereign_Gate,
      Estate_Model_Caller,
      Offshore_Model_Caller,
      Design_Text_Scanner,
      Fact_Measurer,
      Mascot_Judge,
      Provenance_Stamper,
      Door_Responder,
      Audit_Sink);

   subtype Event_Code is Natural range 0 .. 255;

   type Event is record
      Source : Activity_Kind;
      Code   : Event_Code;
   end record;

   type Entry_Array is array (Entry_Index) of Event;

   type Ledger is record
      Entries : Entry_Array;
      Count   : Entry_Count;
      Full    : Boolean;
   end record;

   Sink_Started  : constant Event_Code := 1;
   Ledger_Full   : constant Event_Code := 2;
   Ledger_Sealed : constant Event_Code := 3;

   function Is_Full (L : Ledger) return Boolean is (L.Count = Capacity)
     with Global => null;

   function Is_Sink_Lifecycle (Code : Event_Code) return Boolean is
     ((Code = Sink_Started) or else (Code = Ledger_Full) or else (Code = Ledger_Sealed))
     with Global => null;

   function Sink_Report_Allowed (E : Event) return Boolean is
     ((if E.Source = Audit_Sink then Is_Sink_Lifecycle (E.Code) else True))
     with Global => null;

   function Appended (L : Ledger; E : Event) return Ledger is
     (if Is_Full (L)
      then (L with delta Full => True)
      else (L with delta
              Entries => (L.Entries with delta L.Count + 1 => E),
              Count   => L.Count + 1,
              Full    => L.Count + 1 = Capacity))
     with Global => null,
          Post => (if Is_Full (L)
                   then Appended'Result.Count = L.Count and then Appended'Result.Full
                        and then (for all I in 1 .. L.Count => Appended'Result.Entries (I) = L.Entries (I))
                   else Appended'Result.Count = L.Count + 1
                        and then Appended'Result.Entries (L.Count + 1) = E
                        and then (for all I in 1 .. L.Count => Appended'Result.Entries (I) = L.Entries (I))
                        and then Appended'Result.Full = (L.Count + 1 = Capacity));

end Audit_Ledger_Pkg;
