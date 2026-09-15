--  Copyright (C) 2026 The Dark Factory Ltd
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: eeea1e3cb86f55af896a13a999b7b14a0542de8bacbf236269261d4e5a9e38d6
--
with Reply_Text_Pkg;

package Door_Responder_Pkg with SPARK_Mode is

   type Reply_Kind is (Design_Reply, Refusal_Reply);

   Refusal_Code : constant Integer := -32000;

   function Reply_Kind_Of (Refused : Boolean; Stamped : Boolean) return Reply_Kind
   is (if Refused then Refusal_Reply
       elsif Stamped then Design_Reply
       else Refusal_Reply)
   with Global => null,
        Post => (Reply_Kind_Of'Result = Design_Reply) = (not Refused and then Stamped);

   function Reply_Of (Id_Text : String; Refused : Boolean; Stamped : Boolean;
                      Design_Text : String; Fault_Message : String) return String
   is ((if Reply_Kind_Of (Refused, Stamped) = Design_Reply
        then Reply_Text_Pkg.Result_Reply (Id_Text, Design_Text)
        else Reply_Text_Pkg.Error_Reply (Id_Text, Refusal_Code, Fault_Message)))
   with Global => null,
        Pre => Id_Text'First = 1 and then Id_Text'Length <= 4096
          and then Design_Text'First = 1 and then Design_Text'Length <= 4096
          and then Fault_Message'First = 1 and then Fault_Message'Length <= 4096,
        Post => Reply_Of'Result'Length >= 2;

end Door_Responder_Pkg;
