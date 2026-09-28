--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 9619b9804825b9b5f90af392a4cc10fffe1b512ef04f8f88b10a3c708347517f
--
package Lovelace_Message_Rules_Pkg with SPARK_Mode, Pure is

   Max_Text : constant := 1_048_576;
   Max_Pattern : constant := 64;

   subtype Outcome is Natural range 0 .. 3;
   Unreached    : constant Outcome := 0;
   Failed       : constant Outcome := 1;
   Proved       : constant Outcome := 2;
   Inapplicable : constant Outcome := 3;

   type Level_Kind is (Info_Level, Medium_Level, High_Level, Low_Level, Warning_Level, Error_Level);

   type Message_Facts is record
      Line                  : Natural;
      Level                 : Level_Kind;
      Mentions_Postcondition : Boolean;
      Mentions_Precondition  : Boolean;
      Says_Might_Fail        : Boolean;
      Says_Might             : Boolean;
      Says_Proved            : Boolean;
      Says_Unused_Variable   : Boolean;
   end record;

   type Message_Array is array (Positive range <>) of Message_Facts;

   type Line_Class is (Message_Line, Example_Line, Other_Line);

   type Line_Facts is record
      Class       : Line_Class;
      Own         : Boolean;
      Line        : Natural;
      Has_Summary : Boolean;
   end record;

   type Scan_State is record
      Last_Line    : Natural;
      Summary_Seen : Boolean;
   end record;

   Initial_State : constant Scan_State := (Last_Line => 0, Summary_Seen => False);

   type Fault_Kind is (No_Fault, Error_Message_Fault, Failed_Run_Fault);

   function Contains (Text : String; Pattern : String) return Boolean is
     (Pattern'Length <= Text'Length and then
      (for some P in 1 .. Text'Length - Pattern'Length + 1 =>
         Text (P .. P + Pattern'Length - 1) = Pattern))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text and then
                   Pattern'First = 1 and then Pattern'Length >= 1 and then
                   Pattern'Length <= Max_Pattern,
          Post => (if Contains'Result then Pattern'Length <= Text'Length);

   function Facts_Of (Line : Natural; Level : Level_Kind; Text : String) return Message_Facts is
     ((Line                   => Line,
       Level                  => Level,
       Mentions_Postcondition => Contains (Text, "postcondition"),
       Mentions_Precondition  => Contains (Text, "precondition"),
       Says_Might_Fail        => Contains (Text, "might fail"),
       Says_Might             => Contains (Text, "might"),
       Says_Proved            => Contains (Text, "proved"),
       Says_Unused_Variable   => Contains (Text, "unused variable")))
     with Pre  => Text'First = 1 and then Text'Length <= Max_Text,
          Post => Facts_Of'Result.Line = Line and then Facts_Of'Result.Level = Level;

   function Lower (C : Character) return Character is
     (if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C)
     with Post => (if C not in 'A' .. 'Z' then Lower'Result = C);

   function Is_Own_File (Base : String; Package_Name : String) return Boolean is
     (Base'Length = Package_Name'Length + 4 and then
      (for all K in 0 .. Package_Name'Length - 1 =>
         Lower (Base (Base'First + K)) = Lower (Package_Name (Package_Name'First + K))) and then
      Lower (Base (Base'First + Package_Name'Length))     = '.' and then
      Lower (Base (Base'First + Package_Name'Length + 1)) = 'a' and then
      Lower (Base (Base'First + Package_Name'Length + 2)) = 'd' and then
      Lower (Base (Base'First + Package_Name'Length + 3)) = 's')
     with Pre  => Base'Length <= 4_096 and then
                   Package_Name'Length >= 1 and then
                   Package_Name'Length <= 1_024,
          Post => (if Is_Own_File'Result then Base'Length = Package_Name'Length + 4);

   function Keep_Message (L : Line_Facts) return Boolean is
     (L.Class = Message_Line and then L.Own)
     with Post => (Keep_Message'Result = (L.Class = Message_Line and then L.Own));

   function Next_State (S : Scan_State; L : Line_Facts) return Scan_State is
     (if L.Class = Message_Line
      then (Last_Line => (if L.Own then L.Line else 0), Summary_Seen => S.Summary_Seen)
      else (Last_Line => S.Last_Line, Summary_Seen => S.Summary_Seen or else L.Has_Summary))
     with Post =>
       (if L.Class = Message_Line and then not L.Own then Next_State'Result.Last_Line = 0) and then
       (if L.Class /= Message_Line then Next_State'Result.Last_Line = S.Last_Line) and then
       (if S.Summary_Seen then Next_State'Result.Summary_Seen) and then
       (if L.Class = Message_Line then Next_State'Result.Summary_Seen = S.Summary_Seen);

   function Example_Target (S : Scan_State; L : Line_Facts) return Natural is
     (if L.Class = Example_Line and then S.Last_Line > 0 then S.Last_Line else 0)
     with Post =>
       (if L.Class /= Example_Line then Example_Target'Result = 0) and then
       (if Example_Target'Result > 0 then Example_Target'Result = S.Last_Line);

   function Has_Error (Msgs : Message_Array; Count : Natural) return Boolean is
     ((for some K in 1 .. Count => Msgs (K).Level = Error_Level))
     with Pre => Msgs'First = 1 and then Count <= Msgs'Last;

   function Fault_Of (Error_Seen : Boolean; Exit_Failed : Boolean; Summary_Seen : Boolean) return Fault_Kind is
     (if Error_Seen then Error_Message_Fault
      elsif Exit_Failed and then not Summary_Seen then Failed_Run_Fault
      else No_Fault)
     with Post =>
       ((Fault_Of'Result = Error_Message_Fault) = Error_Seen) and then
       (if Summary_Seen and then not Error_Seen then Fault_Of'Result = No_Fault);

   function Reached_Of (Summary_Seen : Boolean; Error_Seen : Boolean) return Boolean is
     (Summary_Seen and then not Error_Seen)
     with Post => (Reached_Of'Result = (Summary_Seen and then not Error_Seen));

   function In_Range (M : Message_Facts; From : Natural; To : Natural) return Boolean is
     (M.Line >= From and then M.Line <= To);

   function Is_Check_Level (L : Level_Kind) return Boolean is
     (L = Medium_Level or else L = High_Level or else L = Low_Level);

   function Post_Outcome (Reached : Boolean; Msgs : Message_Array; Count : Natural;
                          From : Natural; To : Natural) return Outcome is
     (if not Reached then Unreached
      elsif (for some K in 1 .. Count =>
               In_Range (Msgs (K), From, To) and then Msgs (K).Mentions_Postcondition
               and then Msgs (K).Says_Might_Fail) then Failed
      elsif (for some K in 1 .. Count =>
               In_Range (Msgs (K), From, To) and then Msgs (K).Mentions_Postcondition
               and then Msgs (K).Level = Info_Level and then Msgs (K).Says_Proved) then Proved
      else Unreached)
     with Pre => Msgs'First = 1 and then Count <= Msgs'Last,
          Post =>
            (if not Reached then Post_Outcome'Result = Unreached) and then
            (Post_Outcome'Result /= Inapplicable) and then
            (if Post_Outcome'Result = Proved then
               (for all K in 1 .. Count =>
                  (if In_Range (Msgs (K), From, To) and then Msgs (K).Mentions_Postcondition
                   then not Msgs (K).Says_Might_Fail)));

   function Runtime_Outcome (Reached : Boolean; Msgs : Message_Array; Count : Natural;
                             From : Natural; To : Natural) return Outcome is
     (if not Reached then Unreached
      elsif (for some K in 1 .. Count =>
               In_Range (Msgs (K), From, To) and then
               not Msgs (K).Mentions_Postcondition and then
               not Msgs (K).Mentions_Precondition and then
               Is_Check_Level (Msgs (K).Level)) then Failed
      else Proved)
     with Pre => Msgs'First = 1 and then Count <= Msgs'Last,
          Post =>
            (if not Reached then Runtime_Outcome'Result = Unreached) and then
            (if Reached then Runtime_Outcome'Result /= Unreached) and then
            (if Reached and then Count = 0 then Runtime_Outcome'Result = Proved);

   function Any_Fail_In (Msgs : Message_Array; Count : Natural; From : Natural; To : Natural) return Boolean is
     ((for some K in 1 .. Count =>
        In_Range (Msgs (K), From, To) and then
        not Msgs (K).Mentions_Postcondition and then
        Is_Check_Level (Msgs (K).Level) and then
        Msgs (K).Says_Might))
     with Pre => Msgs'First = 1 and then Count <= Msgs'Last,
          Post => (if Count = 0 then not Any_Fail_In'Result);

   function Unused_In (Msgs : Message_Array; Count : Natural; From : Natural; To : Natural) return Boolean is
     ((for some K in 1 .. Count =>
        In_Range (Msgs (K), From, To) and then
        Msgs (K).Level = Warning_Level and then
        Msgs (K).Says_Unused_Variable))
     with Pre => Msgs'First = 1 and then Count <= Msgs'Last,
          Post => (if Unused_In'Result then Count >= 1);

end Lovelace_Message_Rules_Pkg;
