--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Mascot_Scan_Pkg lineage 6 (2026-09-13): lineage 5 verbatim plus ONE fact, Every_Word_Activity — the third of the
--  word-kind family beside Every_Word_Declared and Every_Word_Plumbing: every word of a value names a declared
--  ACTIVITY line. Why: a channel's producer, producers and consumer words must name activities; Every_Word_Declared
--  (applied to those keys by the emit core, lineage 7) says only that each word names some line, so a producer naming
--  a channel or a pool still passed (brief Amendment 4 erratum 24's remainder, r5's F.10). Scratch-proved locally first
--  (339 checks, 0 unproved), then lane wu-crucible-mascot-scan-6 round A, planner qwen3.8-27b-ada:v0.3, accepted first
--  round, 0 unproved, 211 GPU s. Body (Slice_Of, Scan) carried unchanged. Never hand-edited. Comment-stripped sha
--  equals the round-A spec.
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

   function Node_Of (S : Line_Set; I : Mascot_Measure_Pkg.Node_Index) return Mascot_Measure_Pkg.Node
   is ((Kind => Kind_Of (S.Lines (I)), Rank => I, Has_Element => Present (S.Lines (I), Key_Element), Has_Buffer => Present (S.Lines (I), Key_Buffer), Producer_Count => One_Or_Many (S.Lines (I), Key_Producer, Key_Producers), Consumer_Count => One_Or_Many (S.Lines (I), Key_Consumer, Key_Consumers), Producer => (if One_Or_Many (S.Lines (I), Key_Producer, Key_Producers) = 1 then Find_Ref (S, I, Key_Producer, S.Count) else 0), Consumer => (if One_Or_Many (S.Lines (I), Key_Consumer, Key_Consumers) = 1 then Find_Ref (S, I, Key_Consumer, S.Count) else 0), Is_Reporting => Is_Reporting (S.Lines (I)), Data_Reads => (if Present (S.Lines (I), Key_Reads) then 1 else 0), Data_Writes => (if Present (S.Lines (I), Key_Writes) then 1 else 0), Has_Reporting => (Find_Ref (S, I, Key_Reports, S.Count) in 1 .. S.Count and then Kind_Is (S.Lines (Find_Ref (S, I, Key_Reports, S.Count)), Lit_Channel) and then Is_Reporting (S.Lines (Find_Ref (S, I, Key_Reports, S.Count)))), Accessor_Count => (if Present (S.Lines (I), Key_Accessed) then 1 else 0), Discharge_Present => Present (S.Lines (I), Key_Discharge), Child_Count => (if Present (S.Lines (I), Key_Children) then 1 else 0)))
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
