--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: e29fb3776964c2769ccc86928135bd1606e7e307b30d1f890c94e747f98c57cb
--
package Tower_Bounds_Pkg with SPARK_Mode is
   --  PURPOSE: the ONE place the tower bundle's size bounds live. Line 1 of a bundle (the sealed payload)
   --  may be Max_Bundle_Line characters; line 2 (the envelope) Max_Envelope_Line; the whole file
   --  Max_Bundle_File bytes; the Reef's fetch reply, which carries the file as hex, Max_Fetch_Reply bytes.
   --  USAGE: every unit that bounds a bundle line or a fetch reply names these constants and writes no
   --  number of its own. Line_Fits asks about a line 1; Fetch_Reply_Bytes says how big a reply must be
   --  room for. Cap_Is_Consistent says the constants agree. No I/O, no clock, no state.

   Max_Bundle_Line   : constant := 16_777_216;
   Max_Envelope_Line : constant := 16_386;
   Max_Bundle_File   : constant := 16_793_604;
   Fetch_Head_Length : constant := 27;
   Fetch_Tail_Length : constant := 3;
   Max_Fetch_Reply   : constant := 33_587_238;

   function Line_Fits (Length : Natural) return Boolean is
     (Length >= 1 and then Length <= Max_Bundle_Line)
     with Global => null,
          Post => Line_Fits'Result = (Length >= 1 and then Length <= Max_Bundle_Line);

   function File_Bytes (Line_1 : Natural; Line_2 : Natural) return Natural is
     (Line_1 + Line_2 + 2)
     with Global => null,
          Pre => Line_1 <= Max_Bundle_Line and then Line_2 <= Max_Envelope_Line,
          Post => File_Bytes'Result = Line_1 + Line_2 + 2
                  and then File_Bytes'Result <= Max_Bundle_File;

   function Reply_Bytes (File : Natural) return Natural is
     (Fetch_Head_Length + 2 * File + Fetch_Tail_Length)
     with Global => null,
          Pre => File <= Max_Bundle_File,
          Post => Reply_Bytes'Result = Fetch_Head_Length + 2 * File + Fetch_Tail_Length
                  and then Reply_Bytes'Result <= Max_Fetch_Reply;

   function Fetch_Reply_Bytes (Line_1 : Natural; Line_2 : Natural) return Natural is
     (Reply_Bytes (File_Bytes (Line_1, Line_2)))
     with Global => null,
          Pre => Line_1 <= Max_Bundle_Line and then Line_2 <= Max_Envelope_Line,
          Post => Fetch_Reply_Bytes'Result = Fetch_Head_Length + 2 * (Line_1 + Line_2 + 2) + Fetch_Tail_Length
                  and then Fetch_Reply_Bytes'Result <= Max_Fetch_Reply;

   function Cap_Is_Consistent return Boolean is
     (Max_Bundle_Line = 16 * 1_048_576
      and then Max_Bundle_File = Max_Bundle_Line + Max_Envelope_Line + 2
      and then Max_Fetch_Reply = Fetch_Head_Length + 2 * Max_Bundle_File + Fetch_Tail_Length)
     with Global => null,
          Post => Cap_Is_Consistent'Result;

end Tower_Bounds_Pkg;
