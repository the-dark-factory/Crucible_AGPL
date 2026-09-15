--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: c8262b65918070226749e09d89c982137387536f07b604e017a161604a1d7490
--
package Bounded_Channel_Pkg with SPARK_Mode is

   generic
      type Element_Type is private;
      Capacity : Positive;
   package Channel is

      subtype Count is Natural range 0 .. Capacity;
      subtype Index is Positive range 1 .. Capacity;
      type Slots is array (Index) of Element_Type;
      type Queue is record
         Items  : Slots;
         Length : Count;
         Closed : Boolean;
      end record;

      function Is_Empty (Q : Queue) return Boolean is (Q.Length = 0) with Global => null;
      function Is_Full (Q : Queue) return Boolean is (Q.Length = Capacity) with Global => null;
      function Is_Closed (Q : Queue) return Boolean is (Q.Closed) with Global => null;

      function First (Q : Queue) return Element_Type is (Q.Items (1))
        with Pre => not Is_Empty (Q), Global => null;

      function Put (Q : Queue; E : Element_Type) return Queue is
        ((Q with delta Length => Q.Length + 1, Items => (Q.Items with delta Q.Length + 1 => E)))
        with Pre  => not Is_Full (Q) and then not Is_Closed (Q),
             Post => Put'Result.Length = Q.Length + 1
                     and then Put'Result.Items (Q.Length + 1) = E
                     and then (for all I in 1 .. Q.Length => Put'Result.Items (I) = Q.Items (I))
                     and then Put'Result.Closed = Q.Closed,
             Global => null;

      function Take (Q : Queue) return Queue is
        ((Q with delta Length => Q.Length - 1,
                  Items => (for I in Index => (if I < Capacity then Q.Items (I + 1) else Q.Items (I)))))
        with Pre  => not Is_Empty (Q),
             Post => Take'Result.Length = Q.Length - 1
                     and then (for all I in 1 .. Q.Length - 1 => Take'Result.Items (I) = Q.Items (I + 1))
                     and then Take'Result.Closed = Q.Closed,
             Global => null;

      function Close (Q : Queue) return Queue is ((Q with delta Closed => True))
        with Post => Is_Closed (Close'Result)
                     and then Close'Result.Length = Q.Length
                     and then (for all I in 1 .. Q.Length => Close'Result.Items (I) = Q.Items (I)),
             Global => null;

   end Channel;

   package Reference is new Channel (Element_Type => Integer, Capacity => 4);

end Bounded_Channel_Pkg;
