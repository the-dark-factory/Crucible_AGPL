--  Copyright (C) 2026 Anthony Gair
--  SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-DarkFactory-Commercial-1.0
--  Forged and machine-checked by The Dark Factory. This file is the
--  vendored copy of an IMMUTABLE wu round output. This comment block is
--  the only difference from it; nothing below this line is altered.
--  Reproduce with scripts/stamp-licence.sh in the ada-factory repo.
--  Unstamped source sha256: 8cf64071e5fb11efc344cd903ca43dc862d12406cb19d3801555649cedc1f1fc
--
--  Rail_Socket_Edge -- CRUCIBLE's ONE outbound socket (step 4b). The only src/ unit that names GNAT.Sockets.
--  Purpose: one request/reply exchange with a rail endpoint, reporting TRANSPORT FACTS only. It decides
--  nothing: its caller has already asked Sovereign_Gate_Pkg and the rail's May_Send, and afterwards judges
--  these facts with the rail's proven decider (Prover_Rail_Pkg.Decide, Model_Request_Pkg.Reply_Fault).
--  It never binds, listens or accepts; it reads no configuration.
--  Usage:
--     Exchange (Host => "127.0.0.1", Port => 8471, Request => Line, Timeout_Seconds => 600,
--               Max_Reply => 1_048_576, Until_Line_Feed => True,
--               Reply => Buf, Reply_Len => N, Reached => R, Timed_Out => T,
--               Over_Bound => O, Complete => C);
--  Facts:
--     Reached    -- a connection was made within the timeout.
--     Timed_Out  -- after connecting, the exchange broke (receive/send timeout or reset) before it ended.
--     Over_Bound -- the reply reached Max_Reply bytes before it ended; nothing past Max_Reply is kept.
--     Complete   -- the reply ended as asked: at the first line feed (not stored) when Until_Line_Feed,
--                   otherwise at a clean close by the peer; never when Timed_Out or Over_Bound.
package Rail_Socket_Edge with SPARK_Mode => Off is

   procedure Exchange
     (Host            : String;
      Port            : Positive;
      Request         : String;
      Timeout_Seconds : Positive;
      Max_Reply       : Positive;
      Until_Line_Feed : Boolean;
      Reply           : out String;
      Reply_Len       : out Natural;
      Reached         : out Boolean;
      Timed_Out       : out Boolean;
      Over_Bound      : out Boolean;
      Complete        : out Boolean)
   with Pre => Reply'First = 1 and then Reply'Length >= Max_Reply;

end Rail_Socket_Edge;
