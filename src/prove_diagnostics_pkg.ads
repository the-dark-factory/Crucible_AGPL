--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: c237a2374e0e5f1451031ce9f4786e0d59b5581d8b5e1da49df58a2e49f56ba7
--
with Prove_Tally_Pkg;

package Prove_Diagnostics_Pkg with SPARK_Mode is

   use type Prove_Tally_Pkg.Line_Kind;

   Max_Lines      : constant := 60;
   Max_Line_Bytes : constant := 512;
   Max_Dropped    : constant := 100_000_000;
   Pat_Warning    : constant String := ": warning: ";

   subtype Line_Count is Integer range 0 .. Max_Lines;
   subtype Line_Index is Integer range 1 .. Max_Lines;
   subtype Kept_Length is Integer range 0 .. Max_Line_Bytes;
   subtype Dropped_Count is Integer range 0 .. Max_Dropped;

   type Kept_Line is record
      Text : String (1 .. Max_Line_Bytes) := (others => ' ');
      Len  : Kept_Length := 0;
   end record;

   type Line_Array is array (Line_Index) of Kept_Line;

   type Diagnostics is record
      Lines     : Line_Array := (others => (Text => (others => ' '), Len => 0));
      Count     : Line_Count := 0;
      Dropped   : Dropped_Count := 0;
      Saturated : Boolean := False;
   end record;

   function Keep (Line : String) return Boolean is
     (Prove_Tally_Pkg.Classify (Line) = Prove_Tally_Pkg.Kind_Unproved or else
      Prove_Tally_Pkg.Classify (Line) = Prove_Tally_Pkg.Kind_Error or else
      Prove_Tally_Pkg.Contains (Line, Pat_Warning))
   with Pre => Line'First = 1 and then Line'Length <= Prove_Tally_Pkg.Max_Line;

   function Fits (Line : String) return Boolean is
     (Line'Length <= Max_Line_Bytes);

   function Line_Text (D : Diagnostics; I : Line_Index) return String is
     (D.Lines (I).Text (1 .. D.Lines (I).Len))
   with Pre => I <= D.Count,
        Post => Line_Text'Result'Length = D.Lines (I).Len and then
                Line_Text'Result'Length <= Max_Line_Bytes;

   procedure Add (D : in out Diagnostics; Line : String)
   with Pre => Line'First = 1 and then Line'Length <= Prove_Tally_Pkg.Max_Line,
        Post => (if not Keep (Line) then D = D'Old) and
                (if Keep (Line) and then Fits (Line) and then D'Old.Count < Max_Lines then D.Count = D'Old.Count + 1) and
                (if Keep (Line) and then Fits (Line) and then D'Old.Count < Max_Lines then D.Lines (D.Count).Len = Line'Length) and
                (if Keep (Line) and then Fits (Line) and then D'Old.Count < Max_Lines then D.Lines (D.Count).Text (1 .. Line'Length) = Line) and
                (if Keep (Line) and then Fits (Line) and then D'Old.Count < Max_Lines then D.Dropped = D'Old.Dropped) and
                (if Keep (Line) and then (not Fits (Line) or else D'Old.Count = Max_Lines) then D.Count = D'Old.Count) and
                (if Keep (Line) and then (not Fits (Line) or else D'Old.Count = Max_Lines) and then D'Old.Dropped < Max_Dropped then D.Dropped = D'Old.Dropped + 1) and
                (if Keep (Line) and then (not Fits (Line) or else D'Old.Count = Max_Lines) and then D'Old.Dropped = Max_Dropped then D.Saturated) and
                (for all I in Line_Index range 1 .. D'Old.Count => D.Lines (I) = D'Old.Lines (I)) and
                D.Count >= D'Old.Count and
                D.Dropped >= D'Old.Dropped and
                (if D'Old.Saturated then D.Saturated);

end Prove_Diagnostics_Pkg;
