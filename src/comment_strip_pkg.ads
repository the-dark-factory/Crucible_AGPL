--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Comment_Strip_Pkg: the lane's carried-digest formula as PROVED FACTS (Line_End, First_Non_Blank,
--  Is_Kept: drop comment lines and blank lines, keep the rest with their line feed) plus Stripped, the
--  copy, with a bounds Post. Unit 2 of the emitter re-decomposition brief, 2026-09-13. Lane
--  wu-crucible-comment-strip round A, planner qwen3.8-27b-ada:v0.3, accepted first round, 0 unproved,
--  28 GPU s. Never hand-edited. Comment-stripped sha equals the round-A spec.
package Comment_Strip_Pkg with SPARK_Mode is

   Max_Text : constant := 65536;
   LF : constant Character := Character'Val (10);
   HT : constant Character := Character'Val (9);

   function Line_End (S : String; I : Positive) return Positive
     is ((if I > S'Last or else S (I) = LF then I else Line_End (S, I + 1)))
     with Global => null,
          Pre  => S'First = 1 and then S'Length <= Max_Text and then I <= S'Last + 1,
          Subprogram_Variant => (Increases => I),
          Post => Line_End'Result >= I
                  and then Line_End'Result <= S'Last + 1
                  and then (if Line_End'Result <= S'Last then S (Line_End'Result) = LF)
                  and then (for all K in I .. Line_End'Result - 1 => S (K) /= LF);

   function First_Non_Blank (S : String; I : Positive; E : Positive) return Positive
     is ((if I >= E then E elsif S (I) /= ' ' and then S (I) /= HT then I else First_Non_Blank (S, I + 1, E)))
     with Global => null,
          Pre  => S'First = 1 and then S'Length <= Max_Text and then E <= S'Last + 1 and then I <= E,
          Subprogram_Variant => (Increases => I),
          Post => First_Non_Blank'Result >= I
                  and then First_Non_Blank'Result <= E
                  and then (if First_Non_Blank'Result < E then S (First_Non_Blank'Result) /= ' ' and then S (First_Non_Blank'Result) /= HT)
                  and then (for all K in I .. First_Non_Blank'Result - 1 => S (K) = ' ' or else S (K) = HT);

   function Is_Kept (S : String; I : Positive; E : Positive) return Boolean
     is ((First_Non_Blank (S, I, E) < E
          and then not (S (First_Non_Blank (S, I, E)) = '-'
                        and then First_Non_Blank (S, I, E) + 1 < E
                        and then S (First_Non_Blank (S, I, E) + 1) = '-')))
     with Global => null,
          Pre => S'First = 1 and then S'Length <= Max_Text and then E <= S'Last + 1 and then I <= E;

   function Stripped (S : String) return String
     with Global => null,
          Pre  => S'First = 1 and then S'Length <= Max_Text,
          Post => Stripped'Result'First = 1
                  and then Stripped'Result'Length <= S'Length + 1;

end Comment_Strip_Pkg;
