--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 1358192479f96a8ced2f1a8ec39a2fde404120cb5c459aa01ed84972cf89ecca
--
with Tower_Stamp_Pkg;

package Tower_Ledger_Line_Pkg with SPARK_Mode is
   --  PURPOSE: the ONE machine-read row of CRUCIBLE's local tower ledger,
   --  state/tower.jsonl: is this line an ACCEPTED row, which digest does it
   --  name, is its version above another; and the exact text of such a row.
   --  USAGE: the caller loops over the file and asks of each stripped line.
   --  Write rows ONLY with Accepted_Row. Every other line is not a row here.

   Row_Length : constant := 101;
   Head_Last : constant := 13;
   Digest_First : constant := 14;
   Digest_Last : constant := 77;
   Mid_First : constant := 78;
   Mid_Last : constant := 90;
   Version_First : constant := 91;
   Version_Last : constant := 99;
   Tail_First : constant := 100;

   Row_Head : constant String := '{' & '"' & "accepted" & '"' & ':' & '"';
   Row_Mid  : constant String := '"' & ',' & '"' & "version" & '"' & ':' & '"';
   Row_Tail : constant String := '"' & '}';

   function Is_Padded_Version (S : String) return Boolean
   is (S'Length = 9 and then (for all I in S'Range => S (I) in '0' .. '9'))
   with Global => null,
        Post => Is_Padded_Version'Result =
                  (not (S'Length /= 9 or else
                        (for some I in S'Range => S (I) not in '0' .. '9')));

   function Is_Accepted_Row (Line : String) return Boolean
   is (Line'Length = Row_Length and then
       Line (1 .. Head_Last) = Row_Head and then
       Line (Mid_First .. Mid_Last) = Row_Mid and then
       Line (Tail_First .. Row_Length) = Row_Tail and then
       Tower_Stamp_Pkg.Is_Hex_Digest (Line (Digest_First .. Digest_Last)) and then
       Is_Padded_Version (Line (Version_First .. Version_Last)))
   with Global => null,
        Pre => Line'First = 1,
        Post => Is_Accepted_Row'Result =
                  (not (Line'Length /= Row_Length or else
                        Line (1 .. Head_Last) /= Row_Head or else
                        Line (Mid_First .. Mid_Last) /= Row_Mid or else
                        Line (Tail_First .. Row_Length) /= Row_Tail or else
                        not Tower_Stamp_Pkg.Is_Hex_Digest (Line (Digest_First .. Digest_Last))
                        or else not Is_Padded_Version (Line (Version_First .. Version_Last))));

   function Row_Names (Line : String; Digest : String) return Boolean
   is (Is_Accepted_Row (Line) and then Tower_Stamp_Pkg.Is_Hex_Digest (Digest)
       and then Line (Digest_First .. Digest_Last) = Digest)
   with Global => null,
        Pre => Line'First = 1,
        Post => (Row_Names'Result =
                   (not (not Is_Accepted_Row (Line) or else
                         not Tower_Stamp_Pkg.Is_Hex_Digest (Digest) or else
                         Line (Digest_First .. Digest_Last) /= Digest)))
                and then
                (if Row_Names'Result then Tower_Stamp_Pkg.Is_Hex_Digest (Digest));

   function Row_Is_Above (Line : String; V : String) return Boolean
   is (Is_Accepted_Row (Line) and then Is_Padded_Version (V) and then
       V < Line (Version_First .. Version_Last))
   with Global => null,
        Pre => Line'First = 1,
        Post => (Row_Is_Above'Result =
                   (not (not Is_Accepted_Row (Line) or else
                         not Is_Padded_Version (V) or else
                         V >= Line (Version_First .. Version_Last))))
                and then
                (if Row_Is_Above'Result then Is_Padded_Version (V));

   function Row_Is_Below (Line : String; V : String) return Boolean
   is (Is_Accepted_Row (Line) and then Is_Padded_Version (V) and then
       Line (Version_First .. Version_Last) < V)
   with Global => null,
        Pre => Line'First = 1,
        Post => (Row_Is_Below'Result =
                   (not (not Is_Accepted_Row (Line) or else
                         not Is_Padded_Version (V) or else
                         Line (Version_First .. Version_Last) >= V)))
                and then
                (if Row_Is_Below'Result then
                   (Is_Accepted_Row (Line) and then
                    Is_Padded_Version (V) and then
                    not Row_Is_Above (Line, V)));

   function Padded (V : String) return String
   is (String'(1 .. 9 - V'Length => '0') & V)
   with Global => null,
        Pre => Tower_Stamp_Pkg.Is_Version_Text (V) and then V'First = 1,
        Post => (Padded'Result'First = 1)
                and then (Padded'Result'Length = 9)
                and then (for all I in 1 .. 9 - V'Length =>
                            Padded'Result (I) = '0')
                and then (Padded'Result (9 - V'Length + 1 .. 9) = V)
                and then (Is_Padded_Version (Padded'Result));

   function Accepted_Row (Digest : String; V : String) return String
   is (Row_Head & Digest & Row_Mid & V & Row_Tail)
   with Global => null,
        Pre => Tower_Stamp_Pkg.Is_Hex_Digest (Digest) and then Digest'First = 1
               and then Is_Padded_Version (V) and then V'First = 1,
        Post => (Accepted_Row'Result'First = 1)
                and then (Accepted_Row'Result'Length = Row_Length)
                and then (Accepted_Row'Result (1 .. Head_Last) = Row_Head)
                and then (Accepted_Row'Result (Digest_First .. Digest_Last) = Digest)
                and then (Accepted_Row'Result (Mid_First .. Mid_Last) = Row_Mid)
                and then (Accepted_Row'Result (Version_First .. Version_Last) = V)
                and then (Accepted_Row'Result (Tail_First .. Row_Length) = Row_Tail)
                and then (Is_Accepted_Row (Accepted_Row'Result))
                and then (Row_Names (Accepted_Row'Result, Digest));

end Tower_Ledger_Line_Pkg;
