--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 293cdf58a95676a75447a0618aa559f14cf72d6b709e1032842689e451f32f44
--
package Cheat_Marker_Pkg with SPARK_Mode is

   Max_Line  : constant := 65_536;
   Max_Count : constant := 100_000_000;

   type Marker_Kind is
     (Mark_Assume, Mark_Annotate_Suppress, Mark_Spark_Mode_Off, Mark_Warnings_Off,
      Mark_Import, Mark_Review, Mark_None);

   subtype Count is Integer range 0 .. Max_Count;

   type Tally is record
      reject    : Count := 0;
      review    : Count := 0;
      saturated : Boolean := False;
   end record;

   function Is_Upper (C : Character) return Boolean
     is (C in 'A' .. 'Z');

   function Lower_Eq (A : Character; B : Character) return Boolean
     is ((A = B) or else (Is_Upper (A) and then Character'Pos (A) + 32 = Character'Pos (B)) or else (Is_Upper (B) and then Character'Pos (B) + 32 = Character'Pos (A)));

   function Is_Ident_Char (C : Character) return Boolean
     is (C in 'A' .. 'Z' or C in 'a' .. 'z' or C in '0' .. '9' or C = '_');

   function Is_Blank (C : Character) return Boolean
     is (C = ' ' or C = Character'Val (9));

   function Starts_With_CI (Line : String; P : Positive; Word : String) return Boolean
     is ((P + Word'Length - 1 <= Line'Length and then
          (for all K in 0 .. Word'Length - 1 => Lower_Eq (Line (P + K), Word (1 + K)))))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line and then Word'First = 1
                 and then Word'Length >= 1 and then Word'Length <= 32 and then P <= Line'Length;

   function Token_At (Line : String; P : Positive; Word : String) return Boolean
     is ((Starts_With_CI (Line, P, Word) and then
          (P = 1 or else not Is_Ident_Char (Line (P - 1))) and then
          (P + Word'Length > Line'Length or else not Is_Ident_Char (Line (P + Word'Length)))))
     with Pre => Line'First = 1 and then Line'Length <= Max_Line and then Word'First = 1
                 and then Word'Length >= 1 and then Word'Length <= 32 and then P <= Line'Length;

   function Has_Token (Line : String; Word : String) return Boolean
     is ((for some P in 1 .. Line'Length => Token_At (Line, P, Word)))
     with Pre => (Line'First = 1 and then Line'Length <= Max_Line and then Word'First = 1 and then Word'Length >= 1 and then Word'Length <= 32);

   function Has_Token_After (Line : String; First_Word : String; Second_Word : String) return Boolean
     is ((for some P in 1 .. Line'Length => Token_At (Line, P, First_Word) and then (for some Q in P + First_Word'Length .. Line'Length => Token_At (Line, Q, Second_Word))))
     with Pre => (Line'First = 1 and then Line'Length <= Max_Line and then First_Word'First = 1 and then First_Word'Length >= 1 and then First_Word'Length <= 32 and then Second_Word'First = 1 and then Second_Word'Length >= 1 and then Second_Word'Length <= 32);

   function Is_Comment_Line (Line : String) return Boolean
     is ((for some P in 1 .. Line'Length => (for all K in 1 .. P - 1 => Is_Blank (Line (K))) and then P + 1 <= Line'Length and then Line (P) = '-' and then Line (P + 1) = '-'))
     with Pre => (Line'First = 1 and then Line'Length <= Max_Line);

   function Is_Assume (Line : String) return Boolean
     is (Has_Token_After (Line, "pragma", "assume"))
     with Pre => (Line'First = 1 and then Line'Length <= Max_Line);

   function Is_Annotate_Suppress (Line : String) return Boolean
     is ((Has_Token_After (Line, "annotate", "false_positive") or else Has_Token_After (Line, "annotate", "intentional")))
     with Pre => (Line'First = 1 and then Line'Length <= Max_Line);

   function Is_Spark_Mode_Off (Line : String) return Boolean
     is (Has_Token_After (Line, "spark_mode", "off"))
     with Pre => (Line'First = 1 and then Line'Length <= Max_Line);

   function Is_Warnings_Off (Line : String) return Boolean
     is (Has_Token_After (Line, "warnings", "off"))
     with Pre => (Line'First = 1 and then Line'Length <= Max_Line);

   function Is_Import (Line : String) return Boolean
     is (Has_Token (Line, "import"))
     with Pre => (Line'First = 1 and then Line'Length <= Max_Line);

   function Is_Review (Line : String) return Boolean
     is ((Has_Token (Line, "assert_and_cut") or else Has_Token (Line, "always_terminates") or else Has_Token (Line, "inline_for_proof")))
     with Pre => (Line'First = 1 and then Line'Length <= Max_Line);

   function Marker_Of (Line : String) return Marker_Kind
     is ((if Is_Comment_Line (Line) then Mark_None
          elsif Is_Assume (Line) then Mark_Assume
          elsif Is_Annotate_Suppress (Line) then Mark_Annotate_Suppress
          elsif Is_Spark_Mode_Off (Line) then Mark_Spark_Mode_Off
          elsif Is_Warnings_Off (Line) then Mark_Warnings_Off
          elsif Is_Import (Line) then Mark_Import
          elsif Is_Review (Line) then Mark_Review
          else Mark_None))
     with Pre => (Line'First = 1 and then Line'Length <= Max_Line),
          Post => ((if Is_Comment_Line (Line) then Marker_Of'Result = Mark_None)
           and then (if not Is_Comment_Line (Line) and then Is_Assume (Line) then Marker_Of'Result = Mark_Assume)
           and then (if Marker_Of'Result = Mark_Review then Is_Review (Line) and not Is_Comment_Line (Line))
           and then (if Marker_Of'Result = Mark_None and not Is_Comment_Line (Line) then not Is_Assume (Line) and not Is_Annotate_Suppress (Line) and not Is_Spark_Mode_Off (Line) and not Is_Warnings_Off (Line) and not Is_Import (Line)));

   function Is_Reject (K : Marker_Kind) return Boolean
     is ((K = Mark_Assume) or else (K = Mark_Annotate_Suppress) or else (K = Mark_Spark_Mode_Off) or else (K = Mark_Warnings_Off) or else (K = Mark_Import));

   function Add (T : Tally; K : Marker_Kind) return Tally
     is ((if Is_Reject (K) then
             (reject => (if T.reject < Max_Count then T.reject + 1 else T.reject),
              review => T.review,
              saturated => (if T.reject < Max_Count then T.saturated else True))
          elsif K = Mark_Review then
             (reject => T.reject,
              review => (if T.review < Max_Count then T.review + 1 else T.review),
              saturated => (if T.review < Max_Count then T.saturated else True))
          else
             (reject => T.reject,
              review => T.review,
              saturated => T.saturated)))
     with Post => ((if T.saturated then Add'Result.saturated)
           and then (if Is_Reject (K) and then T.reject < Max_Count then Add'Result.reject = T.reject + 1)
           and then (if K = Mark_Review and then T.review < Max_Count then Add'Result.review = T.review + 1)
           and then (if not Is_Reject (K) then Add'Result.reject = T.reject)
           and then (Add'Result.reject >= T.reject and Add'Result.review >= T.review));

end Cheat_Marker_Pkg;
