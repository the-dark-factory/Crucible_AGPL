--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 2735b4d2c1ac79b8ebb0f37293e43c6c0da60c72cc5497d7aa7edf58c6d602c1
--
package Prove_Tally_Pkg with SPARK_Mode is

   Max_Line  : constant := 65_536;
   Max_Count : constant := 100_000_000;

   Pat_Info      : constant String := ": info: ";
   Pat_Medium    : constant String := ": medium: ";
   Pat_High      : constant String := ": high: ";
   Pat_Low       : constant String := ": low: ";
   Pat_Error     : constant String := ": error: ";
   Pat_Proved    : constant String := " proved";
   Pat_Justified : constant String := "justified";
   Pat_Skipped   : constant String := "skipped; body is";

   type Line_Kind is (Kind_Proved, Kind_Unproved, Kind_Justified, Kind_Error, Kind_Skipped, Kind_Other);

   subtype Count is Integer range 0 .. Max_Count;

   type Tally is record
      proved    : Count := 0;
      unproved  : Count := 0;
      justified : Count := 0;
      errors    : Count := 0;
      skipped   : Count := 0;
      saturated : Boolean := False;
   end record;

   function Contains (Line : String; Pattern : String) return Boolean is
     ((Line'Length >= Pattern'Length and then (for some I in 1 .. Line'Length - Pattern'Length + 1 => Line (I .. I + Pattern'Length - 1) = Pattern)))
   with
     Pre =>
       Line'First = 1 and then Line'Length <= Max_Line and then Pattern'First = 1 and then Pattern'Length >= 1 and then Pattern'Length <= 64;

   function Classify (Line : String) return Line_Kind is
     ((if Contains (Line, Pat_Skipped) then Kind_Skipped
       elsif Contains (Line, Pat_Error) then Kind_Error
       elsif Contains (Line, Pat_Medium) or Contains (Line, Pat_High) or Contains (Line, Pat_Low) then Kind_Unproved
       elsif Contains (Line, Pat_Info) and Contains (Line, Pat_Justified) then Kind_Justified
       elsif Contains (Line, Pat_Info) and Contains (Line, Pat_Proved) then Kind_Proved
       else Kind_Other))
   with
     Pre =>
       Line'First = 1 and then Line'Length <= Max_Line,
     Post =>
       ((if Contains (Line, Pat_Skipped) then Classify'Result = Kind_Skipped)
        and (if Classify'Result = Kind_Proved then Contains (Line, Pat_Info) and Contains (Line, Pat_Proved) and not Contains (Line, Pat_Medium) and not Contains (Line, Pat_High) and not Contains (Line, Pat_Low) and not Contains (Line, Pat_Error))
        and (if Contains (Line, Pat_Medium) and not Contains (Line, Pat_Skipped) and not Contains (Line, Pat_Error) then Classify'Result = Kind_Unproved));

   function Add (T : Tally; K : Line_Kind) return Tally is
     ((if K = Kind_Proved then
          (proved => (if T.proved < Max_Count then T.proved + 1 else T.proved), unproved => T.unproved, justified => T.justified, errors => T.errors, skipped => T.skipped, saturated => T.saturated or T.proved >= Max_Count)
      elsif K = Kind_Unproved then
          (proved => T.proved, unproved => (if T.unproved < Max_Count then T.unproved + 1 else T.unproved), justified => T.justified, errors => T.errors, skipped => T.skipped, saturated => T.saturated or T.unproved >= Max_Count)
      elsif K = Kind_Justified then
          (proved => T.proved, unproved => T.unproved, justified => (if T.justified < Max_Count then T.justified + 1 else T.justified), errors => T.errors, skipped => T.skipped, saturated => T.saturated or T.justified >= Max_Count)
      elsif K = Kind_Error then
          (proved => T.proved, unproved => T.unproved, justified => T.justified, errors => (if T.errors < Max_Count then T.errors + 1 else T.errors), skipped => T.skipped, saturated => T.saturated or T.errors >= Max_Count)
      elsif K = Kind_Skipped then
          (proved => T.proved, unproved => T.unproved, justified => T.justified, errors => T.errors, skipped => (if T.skipped < Max_Count then T.skipped + 1 else T.skipped), saturated => T.saturated or T.skipped >= Max_Count)
      else
          (T)))
   with
     Post =>
       ((if T.saturated then Add'Result.saturated)
        and (if K = Kind_Unproved and T.unproved < Max_Count then Add'Result.unproved = T.unproved + 1)
        and (if K = Kind_Skipped and T.skipped < Max_Count then Add'Result.skipped = T.skipped + 1)
        and (if K /= Kind_Proved then Add'Result.proved = T.proved)
        and (Add'Result.unproved >= T.unproved and Add'Result.skipped >= T.skipped));

   function Checks_Generated (T : Tally) return Natural is
     (Natural (T.proved) + Natural (T.unproved) + Natural (T.justified))
   with
     Post =>
       (Checks_Generated'Result = Natural (T.proved) + Natural (T.unproved) + Natural (T.justified));

end Prove_Tally_Pkg;
