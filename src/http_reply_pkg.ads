--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: a0677bb01ced8b21bce2830d517c30d651613db3540d67f6256e3bc031a7eadc
--
package Http_Reply_Pkg with SPARK_Mode is

   Max_Reply : constant := 1_048_576;
   CR : constant Character := Character'Val (13);
   LF : constant Character := Character'Val (10);
   Status_10 : constant String := "HTTP/1.0 200";
   Status_11 : constant String := "HTTP/1.1 200";

   function Status_Is_200 (Reply : String) return Boolean is
     (Reply'Last >= 13 and then (Reply (1 .. 12) = Status_10 or else Reply (1 .. 12) = Status_11) and then (Reply (13) = ' ' or else Reply (13) = CR))
   with Pre => Reply'First = 1 and then Reply'Last in 0 .. Max_Reply,
        Post => (Status_Is_200'Result = (Reply'Last >= 13 and then (Reply (1 .. 12) = Status_10 or else Reply (1 .. 12) = Status_11)
                              and then (Reply (13) = ' ' or else Reply (13) = CR)));

   function Is_Blank_Line_At (Reply : String; I : Positive) return Boolean is
     (Reply (I) = CR and then Reply (I + 1) = LF and then Reply (I + 2) = CR and then Reply (I + 3) = LF)
   with Pre => Reply'First = 1 and then Reply'Last in 0 .. Max_Reply and then I <= Reply'Last - 3,
        Post => (Is_Blank_Line_At'Result = (Reply (I) = CR and then Reply (I + 1) = LF and then Reply (I + 2) = CR
                                 and then Reply (I + 3) = LF));

   function Header_End (Reply : String) return Natural
   with Pre => Reply'First = 1 and then Reply'Last in 0 .. Max_Reply,
        Post => (if Header_End'Result = 0 then (for all J in 1 .. Reply'Last - 3 => not Is_Blank_Line_At (Reply, J)))
                and then (if Header_End'Result /= 0 then Header_End'Result <= Reply'Last - 3
                          and then Is_Blank_Line_At (Reply, Header_End'Result)
                          and then (for all J in 1 .. Header_End'Result - 1 => not Is_Blank_Line_At (Reply, J)));

   function Body_First (Reply : String) return Natural is
     ((if Header_End (Reply) = 0 then 0 else Header_End (Reply) + 4))
   with Pre => Reply'First = 1 and then Reply'Last in 0 .. Max_Reply,
        Post => (if Body_First'Result /= 0 then Body_First'Result in 5 .. Reply'Last + 1);

   function Is_Usable (Reply : String) return Boolean is
     (Status_Is_200 (Reply) and then Header_End (Reply) /= 0 and then Header_End (Reply) + 4 <= Reply'Last)
   with Pre => Reply'First = 1 and then Reply'Last in 0 .. Max_Reply,
        Post => (Is_Usable'Result = (Status_Is_200 (Reply) and then Header_End (Reply) /= 0
                          and then Header_End (Reply) + 4 <= Reply'Last));

end Http_Reply_Pkg;
