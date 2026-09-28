--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 98fbeba8ddddd99e7966ed6122e814a631cd084f18c5a11299539f1a26d879a5
--
with Lovelace_Lex_Rules_Pkg;
use Lovelace_Lex_Rules_Pkg;

package Lovelace_Text_Rules_Pkg with SPARK_Mode, Pure is

   type Piece is record
      Raw_First : Positive := 1;
      Raw_Last  : Natural  := 0;
      First     : Positive := 1;
      Last      : Natural  := 0;
   end record;

   type Piece_Array is array (Positive range <>) of Piece;

   type Text_Error is (No_Error, Expected_Open, Unbalanced, No_Semicolon);

   type Group_Result is record
      Error       : Text_Error := No_Error;
      Inner_First : Positive := 1;
      Inner_Last  : Natural  := 0;
      Next        : Positive := 1;
   end record;

   type Semicolon_Result is record
      Error       : Text_Error := No_Error;
      Semicolon   : Positive := 1;
      Piece_First : Positive := 1;
      Piece_Last  : Natural  := 0;
      Next        : Positive := 1;
   end record;

   subtype Depth_Type is Integer range -Max_Text .. Max_Text;

   If_Word              : constant String := "if ";
   Paren_If             : constant String := "(if ";
   Expected_Open_Prefix : constant String := "expected '(' at offset ";
   Unbalanced_Prefix    : constant String := "unbalanced parentheses from offset ";
   No_Semicolon_Text    : constant String := "no terminating semicolon";

   function Is_Trim_Space (C : Character) return Boolean is
     (C = Character'Val (9) or else C = Character'Val (10) or else C = Character'Val (11)
      or else C = Character'Val (12) or else C = Character'Val (13) or else C = ' ')
     with Global => null;

   function All_Trim_Between (Text : String; From : Positive; To : Natural) return Boolean is
     ((for all K in From .. To => Is_Trim_Space (Text (K))))
     with Pre => Text'First = 1 and then To <= Text'Length;

   function Ends_Not_Trim (Text : String; First : Positive; Last : Natural) return Boolean is
     (if First <= Last then
        (not Is_Trim_Space (Text (First)) and then not Is_Trim_Space (Text (Last))))
     with Pre => Text'First = 1 and then Last <= Text'Length;

   function Is_Trim_Of (Text : String; Raw_First : Positive; Raw_Last : Natural;
                        First : Positive; Last : Natural) return Boolean is
     (Raw_First <= First
      and then Last <= Raw_Last
      and then First <= Last + 1
      and then All_Trim_Between (Text, Raw_First, First - 1)
      and then All_Trim_Between (Text, Last + 1, Raw_Last)
      and then Ends_Not_Trim (Text, First, Last))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Raw_Last <= Text'Length
                 and then Raw_First <= Raw_Last + 1;

   function First_Non_Trim (Text : String; From : Positive; Last : Natural) return Positive is
     (if From > Last then Last + 1
      elsif not Is_Trim_Space (Text (From)) then From
      else First_Non_Trim (Text, From + 1, Last))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then From <= Last + 1,
          Post => First_Non_Trim'Result >= From and then First_Non_Trim'Result <= Last + 1
                  and then All_Trim_Between (Text, From, First_Non_Trim'Result - 1)
                  and then (if First_Non_Trim'Result <= Last then not Is_Trim_Space (Text (First_Non_Trim'Result))),
          Subprogram_Variant => (Decreases => Last - From + 1);

   function Last_Non_Trim (Text : String; First : Positive; Last : Natural) return Natural is
     (if Last < First then First - 1
      elsif not Is_Trim_Space (Text (Last)) then Last
      else Last_Non_Trim (Text, First, Last - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Last <= Text'Length
                  and then First <= Last + 1,
          Post => Last_Non_Trim'Result >= First - 1 and then Last_Non_Trim'Result <= Last
                  and then All_Trim_Between (Text, Last_Non_Trim'Result + 1, Last)
                  and then (if Last_Non_Trim'Result >= First then not Is_Trim_Space (Text (Last_Non_Trim'Result))),
          Subprogram_Variant => (Decreases => Last - First + 1);

   function Trim (Text : String; Raw_First : Positive; Raw_Last : Natural) return Piece is
     ((Raw_First => Raw_First,
       Raw_Last  => Raw_Last,
       First     => First_Non_Trim (Text, Raw_First, Raw_Last),
       Last      => Last_Non_Trim (Text, First_Non_Trim (Text, Raw_First, Raw_Last), Raw_Last)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Raw_Last <= Text'Length
                  and then Raw_First <= Raw_Last + 1,
          Post => Trim'Result.Raw_First = Raw_First and then Trim'Result.Raw_Last = Raw_Last
                  and then Is_Trim_Of (Text, Raw_First, Raw_Last, Trim'Result.First, Trim'Result.Last);

   function Code_Step (M : Mask_Class; C : Character) return Integer is
     (if M = Code and then C = '(' then 1
      elsif M = Code and then C = ')' then -1
      else 0)
     with Post => Code_Step'Result >= -1 and then Code_Step'Result <= 1;

   function Depth_After (Text : String; Mask : Mask_Array; From : Positive; K : Natural) return Depth_Type is
     (if K < From then 0
      else Depth_After (Text, Mask, From, K - 1) + Code_Step (Mask (K), Text (K)))
     with Ghost,
          Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then K <= Text'Length,
          Post => (if K < From then Depth_After'Result = 0)
                  and then Depth_After'Result >= -K and then Depth_After'Result <= K,
          Subprogram_Variant => (Decreases => K);

   function Group_Close (Text : String; Mask : Mask_Array; Open : Positive; K : Positive; Depth : Depth_Type) return Natural is
     (if K > Text'Length then 0
      elsif Depth + Code_Step (Mask (K), Text (K)) = 0 then K
      else Group_Close (Text, Mask, Open, K + 1, Depth + Code_Step (Mask (K), Text (K))))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then Open <= K and then K <= Text'Length + 1
                  and then Depth = Depth_After (Text, Mask, Open, K - 1),
          Post => Group_Close'Result = 0
                  or else (Group_Close'Result >= K and then Group_Close'Result <= Text'Length
                           and then Depth_After (Text, Mask, Open, Group_Close'Result) = 0),
          Subprogram_Variant => (Decreases => Text'Length - K + 1);

   function Group_Error (E : Text_Error) return Group_Result is
     ((Error => E, Inner_First => 1, Inner_Last => 0, Next => 1));

   function Group_Found (Open : Positive; Close : Positive) return Group_Result is
     ((Error => No_Error, Inner_First => Open + 1, Inner_Last => Close - 1, Next => Close + 1))
     with Pre => Open <= Max_Text and then Close <= Max_Text;

   function Balanced_Group (Text : String; Mask : Mask_Array; Open : Positive) return Group_Result is
     (if Open > Text'Length or else Text (Open) /= '(' then Group_Error (Expected_Open)
      elsif Group_Close (Text, Mask, Open, Open, 0) = 0 then Group_Error (Unbalanced)
      else Group_Found (Open, Group_Close (Text, Mask, Open, Open, 0)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then Open <= Text'Length + 1
                  and then (for all K in 1 .. Text'Length => ((Mask (K) = Outside) = (K < Open)))
                  and then (if Open <= Text'Length and then Text (Open) = '(' then Mask (Open) = Code),
          Post => ((Balanced_Group'Result.Error = Expected_Open) = (Open > Text'Length or else Text (Open) /= '('))
                  and then Balanced_Group'Result.Error /= No_Semicolon;

   function Is_Top_Semicolon (Text : String; Mask : Mask_Array; From : Positive; K : Positive) return Boolean is
     (Mask (K) = Code and then Text (K) = ';' and then Depth_After (Text, Mask, From, K) = 0)
     with Ghost,
          Pre => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                 and then Mask'Last = Text'Last and then K <= Text'Length;

   function Semi_Scan (Text : String; Mask : Mask_Array; From : Positive; K : Positive; Depth : Depth_Type) return Natural is
     (if K > Text'Length then 0
      elsif Depth + Code_Step (Mask (K), Text (K)) = 0 and then Mask (K) = Code and then Text (K) = ';' then K
      else Semi_Scan (Text, Mask, From, K + 1, Depth + Code_Step (Mask (K), Text (K))))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then From <= K and then K <= Text'Length + 1
                  and then Depth = Depth_After (Text, Mask, From, K - 1),
          Post => Semi_Scan'Result = 0
                  or else (Semi_Scan'Result >= K and then Semi_Scan'Result <= Text'Length
                           and then Is_Top_Semicolon (Text, Mask, From, Semi_Scan'Result)),
          Subprogram_Variant => (Decreases => Text'Length - K + 1);

   function Semi_Of (Text : String; Mask : Mask_Array; From : Positive) return Natural is
     (Semi_Scan (Text, Mask, From, From, 0))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then From <= Text'Length + 1,
          Post => Semi_Of'Result = 0
                  or else (Semi_Of'Result >= From and then Semi_Of'Result <= Text'Length);

   function Semi_Missing return Semicolon_Result is
     ((Error => No_Semicolon, Semicolon => 1, Piece_First => 1, Piece_Last => 0, Next => 1));

   function Semi_Found (Text : String; From : Positive; Semi : Positive) return Semicolon_Result is
     ((Error       => No_Error,
       Semicolon   => Semi,
       Piece_First => Trim (Text, From, Semi - 1).First,
       Piece_Last  => Trim (Text, From, Semi - 1).Last,
       Next        => Semi + 1))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text
                 and then From <= Semi and then Semi <= Text'Length;

   function First_Top_Semicolon (Text : String; Mask : Mask_Array; From : Positive) return Semicolon_Result is
     (if Semi_Of (Text, Mask, From) = 0 then Semi_Missing
      else Semi_Found (Text, From, Semi_Of (Text, Mask, From)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then From <= Text'Length + 1
                  and then (for all K in 1 .. Text'Length => ((Mask (K) = Outside) = (K < From))),
          Post => ((First_Top_Semicolon'Result.Error = No_Error) = (Semi_Of (Text, Mask, From) /= 0))
                  and then First_Top_Semicolon'Result.Error /= Expected_Open
                  and then First_Top_Semicolon'Result.Error /= Unbalanced;

   function Is_Top_Separator (Text : String; Mask : Mask_Array; Sep : Character; K : Positive) return Boolean is
     (Mask (K) = Code and then Text (K) = Sep and then Depth_After (Text, Mask, 1, K) = 0)
     with Ghost,
          Pre => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                 and then Mask'Last = Text'Last and then K <= Text'Length;

   function Next_Separator (Text : String; Mask : Mask_Array; Sep : Character; K : Positive; Depth : Depth_Type) return Natural is
     (if K > Text'Length then 0
      elsif Depth + Code_Step (Mask (K), Text (K)) = 0 and then Mask (K) = Code and then Text (K) = Sep then K
      else Next_Separator (Text, Mask, Sep, K + 1, Depth + Code_Step (Mask (K), Text (K))))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then Sep /= '(' and then Sep /= ')'
                  and then K <= Text'Length + 1 and then Depth = Depth_After (Text, Mask, 1, K - 1),
          Post => Next_Separator'Result = 0
                  or else (Next_Separator'Result >= K and then Next_Separator'Result <= Text'Length
                           and then Is_Top_Separator (Text, Mask, Sep, Next_Separator'Result)),
          Subprogram_Variant => (Decreases => Text'Length - K + 1);

   function Sep_Point_From (Text : String; Mask : Mask_Array; Sep : Character; K : Positive) return Natural is
     (Next_Separator (Text, Mask, Sep, K, 0))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then Sep /= '(' and then Sep /= ')'
                  and then K <= Text'Length + 1
                  and then (K = 1 or else Is_Top_Separator (Text, Mask, Sep, K - 1)),
          Post => Sep_Point_From'Result = 0
                  or else (Sep_Point_From'Result >= K and then Sep_Point_From'Result <= Text'Length
                           and then Is_Top_Separator (Text, Mask, Sep, Sep_Point_From'Result));

   function Count_Pieces_From (Text : String; Mask : Mask_Array; Sep : Character; K : Positive) return Positive is
     (if Sep_Point_From (Text, Mask, Sep, K) = 0 then 1
      else 1 + Count_Pieces_From (Text, Mask, Sep, Sep_Point_From (Text, Mask, Sep, K) + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then Sep /= '(' and then Sep /= ')'
                  and then K <= Text'Length + 1
                  and then (K = 1 or else Is_Top_Separator (Text, Mask, Sep, K - 1)),
          Post => Count_Pieces_From'Result <= Text'Length - K + 2,
          Subprogram_Variant => (Decreases => Text'Length - K + 1);

   function Piece_Count (Text : String; Mask : Mask_Array; Sep : Character) return Positive is
     (Count_Pieces_From (Text, Mask, Sep, 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then Sep /= '(' and then Sep /= ')',
          Post => Piece_Count'Result <= Text'Length + 1;

   function Past_End_Piece (Text : String) return Piece is
     ((Raw_First => Text'Length + 1, Raw_Last => Text'Length, First => Text'Length + 1, Last => Text'Length))
     with Pre => Text'Length <= Max_Text;

   function Sep_End (Text : String; Mask : Mask_Array; Sep : Character; K : Positive) return Natural is
     (if Sep_Point_From (Text, Mask, Sep, K) = 0 then Text'Length
      else Sep_Point_From (Text, Mask, Sep, K) - 1)
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then Sep /= '(' and then Sep /= ')'
                  and then K <= Text'Length + 1
                  and then (K = 1 or else Is_Top_Separator (Text, Mask, Sep, K - 1)),
          Post => Sep_End'Result <= Text'Length and then Sep_End'Result >= K - 1;

   function Piece_From (Text : String; Mask : Mask_Array; Sep : Character; K : Positive; N : Positive) return Piece is
     (if N = 1 then Trim (Text, K, Sep_End (Text, Mask, Sep, K))
      elsif Sep_Point_From (Text, Mask, Sep, K) = 0 then Past_End_Piece (Text)
      else Piece_From (Text, Mask, Sep, Sep_Point_From (Text, Mask, Sep, K) + 1, N - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then Sep /= '(' and then Sep /= ')'
                  and then K <= Text'Length + 1
                  and then (K = 1 or else Is_Top_Separator (Text, Mask, Sep, K - 1)),
          Post => Piece_From'Result.Raw_Last <= Text'Length,
          Subprogram_Variant => (Decreases => N);

   function Piece_Bounds (Text : String; Mask : Mask_Array; Sep : Character; N : Positive) return Piece is
     (Piece_From (Text, Mask, Sep, 1, N))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then Sep /= '(' and then Sep /= ')',
          Post => Piece_Bounds'Result.Raw_Last <= Text'Length;

   function Skip_WS (Text : String; I : Positive) return Positive is
     (if I > Text'Length then I
      elsif not Is_Space (Text (I)) then I
      else Skip_WS (Text, I + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length + 1,
          Post => Skip_WS'Result >= I and then Skip_WS'Result <= Text'Length + 1
                  and then (for all K in I .. Skip_WS'Result - 1 => Is_Space (Text (K)))
                  and then (if Skip_WS'Result <= Text'Length then not Is_Space (Text (Skip_WS'Result))),
          Subprogram_Variant => (Decreases => Text'Length - I + 1);

   function Keyword_Then_Space (Text : String; I : Positive; Kw : String) return Boolean is
     (I + Kw'Length <= Text'Length
      and then Equal_Ignoring_Case (Text (I .. I + Kw'Length - 1), Kw)
      and then Is_Space (Text (I + Kw'Length)))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length + 1
                 and then Kw'First = 1 and then Kw'Length >= 1 and then Kw'Length <= 8;

   function After_Then (Text : String; J : Positive) return Positive is
     (if Keyword_Then_Space (Text, J, "then") then Skip_WS (Text, J + 4) else J)
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then J <= Text'Length + 1,
          Post => After_Then'Result >= J;

   function Conjunction_At (Text : String; I : Positive) return Natural is
     (if not Keyword_Then_Space (Text, I, "and") then 0
      elsif After_Then (Text, Skip_WS (Text, I + 3)) > Text'Length then 0
      else After_Then (Text, Skip_WS (Text, I + 3)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then I <= Text'Length + 1,
          Post => (Conjunction_At'Result = 0
                   or else (Conjunction_At'Result >= I + 4 and then Conjunction_At'Result <= Text'Length));

   function Starts_With_If (Text : String) return Boolean is
     ((Text'Length >= 3 and then Text (Text'First .. Text'First + 2) = If_Word)
      or else (Text'Length >= 4 and then Text (Text'First .. Text'First + 3) = Paren_If))
     with Pre => Text'First = 1 and then Text'Length <= Max_Text;

   function Is_Cut_Point (Text : String; Mask : Mask_Array; K : Positive) return Boolean is
     (K > 1 and then Mask (K) = Code and then Is_Space (Text (K - 1))
      and then Conjunction_At (Text, K) > 0)
     with Pre => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                 and then Mask'Last = Text'Last and then K <= Text'Length;

   function Is_Conjunction_Point (Text : String; Mask : Mask_Array; K : Positive) return Boolean is
     (Depth_After (Text, Mask, 1, K) = 0 and then Is_Cut_Point (Text, Mask, K))
     with Ghost,
          Pre => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                 and then Mask'Last = Text'Last and then K <= Text'Length;

   function Next_Conj_Point (Text : String; Mask : Mask_Array; K : Positive; Depth : Depth_Type) return Natural is
     (if K > Text'Length then 0
      elsif Depth + Code_Step (Mask (K), Text (K)) = 0 and then Is_Cut_Point (Text, Mask, K) then K
      else Next_Conj_Point (Text, Mask, K + 1, Depth + Code_Step (Mask (K), Text (K))))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then K <= Text'Length + 1
                  and then Depth = Depth_After (Text, Mask, 1, K - 1),
          Post => Next_Conj_Point'Result = 0
                  or else (Next_Conj_Point'Result >= K and then Next_Conj_Point'Result <= Text'Length
                           and then Is_Conjunction_Point (Text, Mask, Next_Conj_Point'Result)),
          Subprogram_Variant => (Decreases => Text'Length - K + 1);

   function Conj_Point_From (Text : String; Mask : Mask_Array; K : Positive) return Natural is
     (Next_Conj_Point (Text, Mask, K, 0))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then K <= Text'Length + 1
                  and then (K = 1 or else Is_Conjunction_Point (Text, Mask, K - 1)),
          Post => Conj_Point_From'Result = 0
                  or else (Conj_Point_From'Result >= K and then Conj_Point_From'Result <= Text'Length
                           and then Is_Conjunction_Point (Text, Mask, Conj_Point_From'Result));

   function Conj_Count_From (Text : String; Mask : Mask_Array; K : Positive) return Positive is
     (if Conj_Point_From (Text, Mask, K) = 0 then 1
      else 1 + Conj_Count_From (Text, Mask, Conj_Point_From (Text, Mask, K) + 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then K <= Text'Length + 1
                  and then (K = 1 or else Is_Conjunction_Point (Text, Mask, K - 1)),
          Post => Conj_Count_From'Result <= Text'Length - K + 2,
          Subprogram_Variant => (Decreases => Text'Length - K + 1);

   function Resume_At (Text : String; Mask : Mask_Array; K : Positive) return Positive is
     (Conjunction_At (Text, Conj_Point_From (Text, Mask, K)))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then K <= Text'Length + 1
                  and then (K = 1 or else Is_Conjunction_Point (Text, Mask, K - 1))
                  and then Conj_Point_From (Text, Mask, K) > 0,
          Post => Resume_At'Result <= Text'Length;

   function Conj_End (Text : String; Mask : Mask_Array; S : Positive; K : Positive) return Natural is
     (if Conj_Point_From (Text, Mask, K) = 0 then Text'Length
      else Integer'Max (S - 1, Conj_Point_From (Text, Mask, K) - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then K <= Text'Length + 1
                  and then (K = 1 or else Is_Conjunction_Point (Text, Mask, K - 1)) and then S <= Text'Length + 1,
          Post => Conj_End'Result <= Text'Length and then Conj_End'Result >= S - 1;

   function Conj_Piece_From (Text : String; Mask : Mask_Array; S : Positive; K : Positive; N : Positive) return Piece is
     (if N = 1 then Trim (Text, S, Conj_End (Text, Mask, S, K))
      elsif Conj_Point_From (Text, Mask, K) = 0 then Past_End_Piece (Text)
      else Conj_Piece_From (Text, Mask, Resume_At (Text, Mask, K), Conj_Point_From (Text, Mask, K) + 1, N - 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last and then K <= Text'Length + 1
                  and then (K = 1 or else Is_Conjunction_Point (Text, Mask, K - 1)) and then S <= Text'Length + 1,
          Post => Conj_Piece_From'Result.Raw_Last <= Text'Length,
          Subprogram_Variant => (Decreases => N);

   function Whole_Piece (Text : String) return Piece is
     ((Raw_First => 1, Raw_Last => Text'Length, First => 1, Last => Text'Length))
     with Pre => Text'Length <= Max_Text;

   function Conjunct_Count (Text : String; Mask : Mask_Array) return Positive is
     (if Starts_With_If (Text) then 1 else Conj_Count_From (Text, Mask, 1))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last
                  and then (for all K in 1 .. Text'Length => Mask (K) /= Outside)
                  and then (Text'Length = 0
                            or else (not Is_Trim_Space (Text (1)) and then not Is_Trim_Space (Text (Text'Length)))),
          Post => Conjunct_Count'Result <= Text'Length + 1;

   function Conjunct_Bounds (Text : String; Mask : Mask_Array; N : Positive) return Piece is
     (if Starts_With_If (Text) then Whole_Piece (Text) else Conj_Piece_From (Text, Mask, 1, 1, N))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then Mask'First = 1
                  and then Mask'Last = Text'Last
                  and then (for all K in 1 .. Text'Length => Mask (K) /= Outside)
                  and then (Text'Length = 0
                            or else (not Is_Trim_Space (Text (1)) and then not Is_Trim_Space (Text (Text'Length)))),
          Post => Conjunct_Bounds'Result.Raw_Last <= Text'Length;

   function Offset_Image (N : Natural) return String is
     (Natural'Image (N) (2 .. Natural'Image (N)'Last))
     with Post => Offset_Image'Result'Length <= 11;

   function Has_Prefix (R : String; P : String) return Boolean is
     (P'Length <= R'Length
      and then R (R'First .. R'Last - (R'Length - P'Length)) = P)
     with Pre => R'Length <= Max_Text and then P'Length <= Max_Text;

   function Error_Text (E : Text_Error; At_Index : Positive) return String is
     (if E = Expected_Open then Expected_Open_Prefix & Offset_Image (At_Index - 1)
      elsif E = Unbalanced then Unbalanced_Prefix & Offset_Image (At_Index - 1)
      elsif E = No_Semicolon then No_Semicolon_Text
      else "")
     with Post => (if E = Expected_Open then Has_Prefix (Error_Text'Result, Expected_Open_Prefix))
                  and then (if E = Unbalanced then Has_Prefix (Error_Text'Result, Unbalanced_Prefix))
                  and then (if E = No_Semicolon then Error_Text'Result = No_Semicolon_Text)
                  and then (if E = No_Error then Error_Text'Result'Length = 0);

end Lovelace_Text_Rules_Pkg;
