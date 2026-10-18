--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 622bc11bb003357659c53de77c8cd45d7ec236d6a23e77b8f26891027ee8463c
--
with Json_Scan_Pkg;
with Mascot_Measure_Pkg;

package Mascot_Scan_Pkg with SPARK_Mode is

   use type Mascot_Measure_Pkg.Node_Kind;
   use type Mascot_Measure_Pkg.Node;
   use type Json_Scan_Pkg.Kind_Type;

   Max_Line : constant := 1024;

   subtype Line_Length is Natural range 0 .. Max_Line;

   type Line_Rec is record
      Text : String (1 .. Max_Line);
      Len  : Line_Length;
   end record;

   type Line_Array is array (Mascot_Measure_Pkg.Node_Index) of Line_Rec;

   type Line_Set is record
      Lines : Line_Array;
      Count : Mascot_Measure_Pkg.Node_Count;
   end record;

   Key_Id        : constant String := "id";
   Key_Kind      : constant String := "kind";
   Key_Element   : constant String := "element";
   Key_Buffer    : constant String := "buffer";
   Key_Producer  : constant String := "producer";
   Key_Producers : constant String := "producers";
   Key_Consumer  : constant String := "consumer";
   Key_Consumers : constant String := "consumers";
   Key_Reporting : constant String := "reporting";
   Key_Reads     : constant String := "reads";
   Key_Writes    : constant String := "writes";
   Key_Reports   : constant String := "reports";
   Key_Accessed  : constant String := "accessed";
   Key_Discharge : constant String := "discharge";
   Key_Children  : constant String := "children";

   Lit_Activity  : constant String := "activity";
   Lit_Pool      : constant String := "pool";
   Lit_Channel   : constant String := "channel";
   Lit_Composite : constant String := "composite";
   Lit_True      : constant String := "true";

   function Present (L : Line_Rec; Key : String) return Boolean
   is (Json_Scan_Pkg.Has_Key (L.Text (1 .. L.Len), Key))
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64;

   function Kind_Is (L : Line_Rec; Lit : String) return Boolean
   is (Present (L, Key_Kind) and then Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key_Kind).kind = Json_Scan_Pkg.K_String and then Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key_Kind).first < Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key_Kind).last and then Json_Scan_Pkg.Equals_Literal (L.Text (1 .. L.Len), Json_Scan_Pkg.String_Contents (L.Text (1 .. L.Len), Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key_Kind)), Lit))
   with Global => null,
        Pre    => Lit'First = 1 and then Lit'Length >= 1 and then Lit'Length <= 64;

   function Kind_Known (L : Line_Rec) return Boolean
   is (Present (L, Key_Kind) and then (Kind_Is (L, Lit_Activity) xor Kind_Is (L, Lit_Pool) xor Kind_Is (L, Lit_Channel) xor Kind_Is (L, Lit_Composite)))
   with Global => null;

   function Kind_Of (L : Line_Rec) return Mascot_Measure_Pkg.Node_Kind
   is ((if Kind_Is (L, Lit_Activity) then Mascot_Measure_Pkg.Activity elsif Kind_Is (L, Lit_Pool) then Mascot_Measure_Pkg.Pool elsif Kind_Is (L, Lit_Channel) then Mascot_Measure_Pkg.Channel else Mascot_Measure_Pkg.Composite))
   with Global => null,
        Pre    => Kind_Known (L);

   function Is_Reporting (L : Line_Rec) return Boolean
   is (Present (L, Key_Reporting) and then ((Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key_Reporting).kind = Json_Scan_Pkg.K_Bare and then Json_Scan_Pkg.Equals_Literal (L.Text (1 .. L.Len), Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key_Reporting), Lit_True)) or else (Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key_Reporting).kind = Json_Scan_Pkg.K_String and then Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key_Reporting).first < Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key_Reporting).last and then Json_Scan_Pkg.Equals_Literal (L.Text (1 .. L.Len), Json_Scan_Pkg.String_Contents (L.Text (1 .. L.Len), Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key_Reporting)), Lit_True))))
   with Global => null;

   function One_Or_Many (L : Line_Rec; Key_One : String; Key_Many : String) return Mascot_Measure_Pkg.Node_Count
   is ((if Present (L, Key_One) then 1 elsif Present (L, Key_Many) then 2 else 0))
   with Global => null,
        Pre    => Key_One'First = 1 and then Key_One'Length >= 1 and then Key_One'Length <= 64 and then Key_Many'First = 1 and then Key_Many'Length >= 1 and then Key_Many'Length <= 64;

   function Id_Span (L : Line_Rec) return Json_Scan_Pkg.Span_Type
   is (Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key_Id))
   with Global => null,
        Pre    => Present (L, Key_Id);

   function Slice_Of (A : Line_Rec; SA : Json_Scan_Pkg.Span_Type) return String
   with Global => null,
        Pre    => SA.First in 1 .. A.Len and then SA.Last in 1 .. A.Len and then SA.First <= SA.Last,
        Post   => Slice_Of'Result'First = 1 and then Slice_Of'Result'Length = SA.Last - SA.First + 1 and then (for all K in Slice_Of'Result'Range => Slice_Of'Result (K) = A.Text (SA.First + K - 1));

   function Same_Id (A : Line_Rec; B : Line_Rec; SA : Json_Scan_Pkg.Span_Type; Key : String) return Boolean
   is (Json_Scan_Pkg.Equals_Literal (B.Text (1 .. B.Len), Json_Scan_Pkg.String_Contents (B.Text (1 .. B.Len), Json_Scan_Pkg.Value_Span (B.Text (1 .. B.Len), Key)), Slice_Of (A, SA)))
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64 and then Present (B, Key) and then Json_Scan_Pkg.Value_Span (B.Text (1 .. B.Len), Key).kind = Json_Scan_Pkg.K_String and then Json_Scan_Pkg.Value_Span (B.Text (1 .. B.Len), Key).first < Json_Scan_Pkg.Value_Span (B.Text (1 .. B.Len), Key).last and then SA.Found and then SA.First in 1 .. A.Len and then SA.Last in 1 .. A.Len and then SA.First <= SA.Last and then SA.Last - SA.First + 1 <= 64;

   function Id_Well_Formed (L : Line_Rec) return Boolean
   is ((Id_Span (L).Found and then Id_Span (L).First in 1 .. L.Len and then Id_Span (L).Last in 1 .. L.Len and then Id_Span (L).First <= Id_Span (L).Last and then Id_Span (L).Kind = Json_Scan_Pkg.K_String and then Id_Span (L).Last - Id_Span (L).First + 1 >= 3 and then Id_Span (L).Last - Id_Span (L).First + 1 <= 64))
   with Global => null,
        Pre    => Present (L, Key_Id);

   function Id_Text_Of (L : Line_Rec) return String
   is ((Slice_Of (L, Json_Scan_Pkg.String_Contents (L.Text (1 .. L.Len), Id_Span (L)))))
   with Global => null,
        Pre    => Present (L, Key_Id) and then Id_Well_Formed (L),
        Post   => Id_Text_Of'Result'First = 1 and then Id_Text_Of'Result'Length >= 1 and then Id_Text_Of'Result'Length <= 62;

   function Has_Ref_Text (L : Line_Rec; Key : String) return Boolean
   is ((Present (L, Key) and then Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key).kind = Json_Scan_Pkg.K_String and then Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key).last - Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key).first >= 2))
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64;

   function Ref_Span (L : Line_Rec; Key : String) return Json_Scan_Pkg.Span_Type
   is ((Json_Scan_Pkg.String_Contents (L.Text (1 .. L.Len), Json_Scan_Pkg.Value_Span (L.Text (1 .. L.Len), Key))))
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64 and then Has_Ref_Text (L, Key),
        Post   => Ref_Span'Result.first >= 1 and then Ref_Span'Result.last <= L.Len and then Ref_Span'Result.first <= Ref_Span'Result.last;

   function Word_At (L : Line_Rec; V : Json_Scan_Pkg.Span_Type; P : Positive; Id : String) return Boolean
   is ((P + Id'Length - 1 <= V.last and then (P = V.first or else L.Text (P - 1) = ' ') and then (P + Id'Length - 1 = V.last or else L.Text (P + Id'Length) = ' ') and then Json_Scan_Pkg.Equals_Literal (L.Text (1 .. L.Len), (found => True, kind => Json_Scan_Pkg.K_String, first => P, last => P + Id'Length - 1), Id)))
   with Global => null,
        Pre    => V.first >= 1 and then V.last <= L.Len and then V.first <= V.last and then P >= V.first and then P <= V.last and then Id'First = 1 and then Id'Length >= 1 and then Id'Length <= 64;

   function Word_Starts (L : Line_Rec; V : Json_Scan_Pkg.Span_Type; P : Positive) return Boolean
   is ((L.Text (P) /= ' ' and then (P = V.first or else L.Text (P - 1) = ' ')))
   with Global => null,
        Pre    => V.first >= 1 and then V.last <= L.Len and then V.first <= V.last and then P >= V.first and then P <= V.last;

   function Refers (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index; Key : String; J : Mascot_Measure_Pkg.Node_Index) return Boolean
   is ((Has_Ref_Text (S.Lines (I), Key) and then Present (S.Lines (J), Key_Id) and then Id_Well_Formed (S.Lines (J)) and then (for some P in Ref_Span (S.Lines (I), Key).first .. Ref_Span (S.Lines (I), Key).last => Word_At (S.Lines (I), Ref_Span (S.Lines (I), Key), P, Id_Text_Of (S.Lines (J))))))
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64 and then I <= S.Count and then J <= S.Count;

   function Every_Word_Declared (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index; Key : String) return Boolean
   is ((not Present (S.Lines (I), Key) or else (Has_Ref_Text (S.Lines (I), Key) and then (for all P in Ref_Span (S.Lines (I), Key).first .. Ref_Span (S.Lines (I), Key).last => (if Word_Starts (S.Lines (I), Ref_Span (S.Lines (I), Key), P) then (for some J in 1 .. S.Count => Present (S.Lines (J), Key_Id) and then Id_Well_Formed (S.Lines (J)) and then Word_At (S.Lines (I), Ref_Span (S.Lines (I), Key), P, Id_Text_Of (S.Lines (J)))))))))
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64 and then I <= S.Count;

   function Every_Word_Plumbing (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index; Key : String) return Boolean
   is ((not Present (S.Lines (I), Key) or else (Has_Ref_Text (S.Lines (I), Key) and then (for all P in Ref_Span (S.Lines (I), Key).first .. Ref_Span (S.Lines (I), Key).last => (if Word_Starts (S.Lines (I), Ref_Span (S.Lines (I), Key), P) then (for some J in 1 .. S.Count => Present (S.Lines (J), Key_Id) and then Id_Well_Formed (S.Lines (J)) and then Word_At (S.Lines (I), Ref_Span (S.Lines (I), Key), P, Id_Text_Of (S.Lines (J))) and then (Kind_Is (S.Lines (J), Lit_Channel) or else Kind_Is (S.Lines (J), Lit_Pool))))))))
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64 and then I <= S.Count;

   function Every_Word_Activity (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index; Key : String) return Boolean
   is ((not Present (S.Lines (I), Key) or else (Has_Ref_Text (S.Lines (I), Key) and then (for all P in Ref_Span (S.Lines (I), Key).first .. Ref_Span (S.Lines (I), Key).last => (if Word_Starts (S.Lines (I), Ref_Span (S.Lines (I), Key), P) then (for some J in 1 .. S.Count => Present (S.Lines (J), Key_Id) and then Id_Well_Formed (S.Lines (J)) and then Word_At (S.Lines (I), Ref_Span (S.Lines (I), Key), P, Id_Text_Of (S.Lines (J))) and then Kind_Is (S.Lines (J), Lit_Activity)))))))
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64 and then I <= S.Count;

   function Find_Ref (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index; Key : String; Upto : Mascot_Measure_Pkg.Node_Count) return Mascot_Measure_Pkg.Node_Ref
   is ((if Upto = 0 then 0 elsif Present (S.Lines (Upto), Key_Id) and then Present (S.Lines (I), Key) and then Json_Scan_Pkg.Value_Span (S.Lines (I).Text (1 .. S.Lines (I).Len), Key).kind = Json_Scan_Pkg.K_String and then Json_Scan_Pkg.Value_Span (S.Lines (I).Text (1 .. S.Lines (I).Len), Key).first < Json_Scan_Pkg.Value_Span (S.Lines (I).Text (1 .. S.Lines (I).Len), Key).last and then Id_Span (S.Lines (Upto)).Found and then Id_Span (S.Lines (Upto)).First in 1 .. S.Lines (Upto).Len and then Id_Span (S.Lines (Upto)).Last in 1 .. S.Lines (Upto).Len and then Id_Span (S.Lines (Upto)).First <= Id_Span (S.Lines (Upto)).Last and then Id_Span (S.Lines (Upto)).Kind = Json_Scan_Pkg.K_String and then Id_Span (S.Lines (Upto)).Last - Id_Span (S.Lines (Upto)).First + 1 >= 3 and then Id_Span (S.Lines (Upto)).Last - Id_Span (S.Lines (Upto)).First + 1 <= 64 and then Same_Id (S.Lines (Upto), S.Lines (I), Json_Scan_Pkg.String_Contents (S.Lines (Upto).Text (1 .. S.Lines (Upto).Len), Id_Span (S.Lines (Upto))), Key) then Upto else Find_Ref (S, I, Key, Upto - 1)))
   with Global => null,
        Pre    => Key'First = 1 and then Key'Length >= 1 and then Key'Length <= 64 and then Upto <= S.Count and then I <= S.Count,
        Subprogram_Variant => (Decreases => Upto);

   function Names_Producer (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index; J : Mascot_Measure_Pkg.Node_Index) return Boolean
   is (Refers (S, I, Key_Producer, J) or else Refers (S, I, Key_Producers, J))
   with Global => null,
        Pre    => I <= S.Count and then J <= S.Count;

   function Names_Consumer (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index; J : Mascot_Measure_Pkg.Node_Index) return Boolean
   is (Refers (S, I, Key_Consumer, J) or else Refers (S, I, Key_Consumers, J))
   with Global => null,
        Pre    => I <= S.Count and then J <= S.Count;

   function Last_Producer (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index; Upto : Mascot_Measure_Pkg.Node_Count) return Mascot_Measure_Pkg.Node_Ref
   is (if Upto = 0 then 0 elsif Names_Producer (S, I, Upto) then Upto else Last_Producer (S, I, Upto - 1))
   with Global => null,
        Pre    => I <= S.Count and then Upto <= S.Count,
        Subprogram_Variant => (Decreases => Upto);

   function First_Consumer (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index; Left : Mascot_Measure_Pkg.Node_Count) return Mascot_Measure_Pkg.Node_Ref
   is (if Left = 0 then 0 elsif Names_Consumer (S, I, S.Count - Left + 1) then S.Count - Left + 1 else First_Consumer (S, I, Left - 1))
   with Global => null,
        Pre    => I <= S.Count and then Left <= S.Count,
        Subprogram_Variant => (Decreases => Left);

   function Producer_Ref (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Mascot_Measure_Pkg.Node_Ref
   is (Last_Producer (S, I, S.Count))
   with Global => null,
        Pre    => I <= S.Count;

   function Consumer_Ref (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Mascot_Measure_Pkg.Node_Ref
   is (First_Consumer (S, I, S.Count))
   with Global => null,
        Pre    => I <= S.Count;

   function Last_Producer_Is_Last (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index; Upto : Mascot_Measure_Pkg.Node_Count) return Boolean
   is (if Upto = 0 then True else Last_Producer_Is_Last (S, I, Upto - 1))
   with Ghost,
        Global => null,
        Pre    => I <= S.Count and then Upto <= S.Count,
        Subprogram_Variant => (Decreases => Upto),
        Post   => Last_Producer_Is_Last'Result and then Last_Producer (S, I, Upto) <= Upto and then (if Last_Producer (S, I, Upto) = 0 then (for all J in 1 .. Upto => not Names_Producer (S, I, J)) else Names_Producer (S, I, Last_Producer (S, I, Upto)) and then (for all J in Last_Producer (S, I, Upto) + 1 .. Upto => not Names_Producer (S, I, J)));

   function First_Consumer_Is_First (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index; Left : Mascot_Measure_Pkg.Node_Count) return Boolean
   is (if Left = 0 then True else First_Consumer_Is_First (S, I, Left - 1))
   with Ghost,
        Global => null,
        Pre    => I <= S.Count and then Left <= S.Count,
        Subprogram_Variant => (Decreases => Left),
        Post   => First_Consumer_Is_First'Result and then (if First_Consumer (S, I, Left) = 0 then (for all K in S.Count - Left + 1 .. S.Count => not Names_Consumer (S, I, K)) else First_Consumer (S, I, Left) >= S.Count - Left + 1 and then First_Consumer (S, I, Left) <= S.Count and then Names_Consumer (S, I, First_Consumer (S, I, Left)) and then (for all K in S.Count - Left + 1 .. First_Consumer (S, I, Left) - 1 => not Names_Consumer (S, I, K)));

   function Back_Pair (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Boolean
   is (for some J in 1 .. S.Count => Names_Producer (S, I, J) and then (for some K in 1 .. J => Names_Consumer (S, I, K)))
   with Ghost,
        Global => null,
        Pre    => I <= S.Count;

   function Ordered_Back (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Boolean
   is (Last_Producer_Is_Last (S, I, S.Count) and then First_Consumer_Is_First (S, I, S.Count) and then Producer_Ref (S, I) /= 0 and then Consumer_Ref (S, I) /= 0 and then Producer_Ref (S, I) >= Consumer_Ref (S, I))
   with Ghost,
        Global => null,
        Pre    => I <= S.Count,
        Post   => Ordered_Back'Result = Back_Pair (S, I);

   function Node_Of (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Mascot_Measure_Pkg.Node
   is ((Kind => Kind_Of (S.Lines (I)), Rank => I, Has_Element => Present (S.Lines (I), Key_Element), Has_Buffer => Present (S.Lines (I), Key_Buffer), Producer_Count => One_Or_Many (S.Lines (I), Key_Producer, Key_Producers), Consumer_Count => One_Or_Many (S.Lines (I), Key_Consumer, Key_Consumers), Producer => Producer_Ref (S, I), Consumer => Consumer_Ref (S, I), Is_Reporting => Is_Reporting (S.Lines (I)), Data_Reads => (if Present (S.Lines (I), Key_Reads) then 1 else 0), Data_Writes => (if Present (S.Lines (I), Key_Writes) then 1 else 0), Has_Reporting => (Find_Ref (S, I, Key_Reports, S.Count) in 1 .. S.Count and then Kind_Is (S.Lines (Find_Ref (S, I, Key_Reports, S.Count)), Lit_Channel) and then Is_Reporting (S.Lines (Find_Ref (S, I, Key_Reports, S.Count)))), Accessor_Count => (if Present (S.Lines (I), Key_Accessed) then 1 else 0), Discharge_Present => Present (S.Lines (I), Key_Discharge), Child_Count => (if Present (S.Lines (I), Key_Children) then 1 else 0)))
   with Global => null,
        Pre    => I <= S.Count and then Kind_Known (S.Lines (I));

   type Fault_Kind is (No_Fault, No_Lines, Missing_Id, Unknown_Kind);

   function Fault_Of (S : Line_Set) return Fault_Kind
   is ((if S.Count = 0 then No_Lines elsif (for some I in 1 .. S.Count => not Present (S.Lines (I), Key_Id)) then Missing_Id elsif (for some I in 1 .. S.Count => not Kind_Known (S.Lines (I))) then Unknown_Kind else No_Fault))
   with Global => null;

   function Well_Formed (S : Line_Set) return Boolean
   is (Fault_Of (S) = No_Fault)
   with Global => null;

   type Scan_Result is record
      Ok    : Boolean;
      Fault : Fault_Kind;
      Table : Mascot_Measure_Pkg.Node_Table;
   end record;

   function Scan (S : Line_Set) return Scan_Result
   with Global => null,
        Post   => Scan'Result.Ok = Well_Formed (S) and then Scan'Result.Fault = Fault_Of (S) and then (if Well_Formed (S) then Scan'Result.Table.Last = S.Count and then (for all I in 1 .. S.Count => Scan'Result.Table.Nodes (I) = Node_Of (S, I)));

end Mascot_Scan_Pkg;
