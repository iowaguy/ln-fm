/* A state machine of the gossip protocol within the Lightning Network */

mtype = {
  /* These are message types. They can be sent by one node to
     its counterparty across the channel. */
  UPDATE_ADD_HTLC, ERROR, COMMITMENT_SIGNED, REVOKE_AND_ACK,
  UPDATE_FAIL_HTLC, UPDATE_FAIL_MALFORMED_HTLC, UPDATE_FULFILL_HTLC,

  /* These two are flags. They indicate whether a particular
     message was sent or received, which is important sometimes.
     Used by the state machine, but not communicated on the wire
     in the actual protocol.*/
  SEND, RECV,

  /* Validation states output one of the following. INVALID
     usually leads to an error state. Used by the state machine,
     but not communicated on the wire in the actual protocol. */
  VALID, INVALID,

  /* This is used to indicate whether or not there are more
     HTLCs that need to be closed before returning to the
     initial FUNDED state. Used by the state machine, but
     not communicated on the wire in the actual protocol. */
  MORE, NO_MORE
}

/* Rendezvous communication channels */
chan AtoB = [0] of { mtype };
chan BtoA = [0] of { mtype };

int state[2];
int pids[2];

/* A boolean that indicates if all the HTLCs have been fulfilled or
   not. All HTLCs must be fulfilled before new ones can be added
   (i.e. before the state machine can return to `FUNDED`). */
bool fulfilled[2] = { false, false };

/* A boolean that indicates whether the two peers have gotten their
   commitments out of sync. */
bool desynced[2] = { false, false };

/* The number of HTLCs that can be open at a time by a single peer.
   The actual number in the protocol is 483, but we decrease it in our
   model to avoid state-space explosion. */
int maxCurrentHtlcs = 10;

/* The number of HTLCs currently open by the peer. */
int currentHtcls[2] = {0, 0};

/* This variable can be either SEND or RECV, depending on whether
   the message is being sent or received. */
mtype sent_or_received[2];

/* This variable represents the return status of the intermediate
   function calls. */
mtype status[2];


#define FundedState                    0
#define ValHtlcState                   1
#define MoreHtlcsWaitState             2
#define FailChannelState               3
#define CloseChannelState              4
#define OpenChannelState               5
#define CommitmentAckWaitState         6
#define ValSeqAck1State                7
#define ValSeqAck2State                8
#define ValCommitmentState             9
#define ValConcCommitmentState         10
#define ValPrimaryCommitmentState      11
#define AckWaitState                   12
#define DeleteHtlcState                13
#define ValidateFulfillmentState       14
#define HtlcFulfillWaitState           15
#define ResyncState                    16
#define ValDesyncComState              17
#define EndState                       -1

/* The HTLC_OPEN state is always eventually followed by either: funded, */
/* ackwait, confirmcomm, fail or close*/
ltl phi1 {
  always (
    (state[0] == HtlcOpenState)
    implies (
      eventually (
        (
          state[0] == FundedState     ||
          state[0] == AckWaitState     ||
          state[0] == ConfirmCommState ||
          state[0] == FailState ||
          state[0] == CloseState
        )
      )
    )
  )
}

/* ltl state3canBeForever { */
/* 	! ( eventually ( always (state[0] == AckWaitState) ) ) */
/* } */

/* This function simulates validating a received message. A message
   can either be valid or invalid. */
proctype ValidateMsg(bit peer) {
  do
    :: status[peer] = VALID; break;
    :: status[peer] = INVALID; break;
  od
}

/* Add an HTLC to the local node. The second parameter indicates whether
   the HTLC was sent or received. Return INVALID if that puts the
   local node over `maxCurrentHtlcs`. Return VALID otherwise. */
proctype AddHtlc(bit peer) {
  atomic {
    if
      :: fulfilled == false && currentHtcls[peer] < maxCurrentHtlcs -> currentHtlcs[peer]++; status[peer] = VALID; break;
      :: fulfilled == false && currentHtcls[peer] >= maxCurrentHtlcs -> status[peer] = INVALID; break;

      /* If the HTLCs have already been fulfilled, then we cannot add
         new HTLCs. Therefore, as a shortcut, we just set this to VALID,
         so that the state machine can progress to the next logical state. */
      :: fulfilled == true -> status[peer] = VALID; break;
    fi
  }
}

proctype LightningNormal(chan snd, rcv; bit i) {
  pids[i] = _pid;
FUNDED:
  state[i] = FundedState;
  if
    /* Receive the first HTLC from the counterparty. (5)*/
    :: rcv ? UPDATE_ADD_HTLC -> send_or_receive = RECV; goto VAL_HTLC;

    /* Counterparty sent an error for some reason (4) */
    :: rcv ? ERROR -> goto FAIL_CHANNEL;

    /* Local node sent an error for some reason (4) */
    :: snd ! ERROR -> goto FAIL_CHANNEL;

    /* Send the first HTLC to the counterparty. (3) */
    :: snd ! UPDATE_ADD_HTLC -> send_or_receive = SEND; goto MORE_HTLCS_WAIT;
  fi

VAL_HTLC:
  state[i] = ValHtlcState;
  run ValidateMsg(i);
  if
    /* Send an error if the HTLC is malformed or incorrect. (8) */
    :: status[i] == INVALID -> snd ! UPDATE_FAIL_HTLC; snd ! ERROR; goto FAIL_CHANNEL;
    :: status[i] == INVALID -> snd ! UPDATE_FAIL_MALFORMED_HTLC; snd ! ERROR; goto FAIL_CHANNEL;

    /* Use this transition if the received HTLC is deemed valid. (9) */
    :: status[i] == VALID && desynced[i] == false -> goto MORE_HTLCS_WAIT;

    /* The out-of-sync `UPDATE_ADD_HTLC` received was valid. (42) */
    :: status[i] == VALID && desynced[i] == true -> goto RESYNC;
  fi

MORE_HTLCS_WAIT:
  state[i] = MoreHtlcsWaitState;
  run AddHtlc(i)
  if
    /* Receive additional HTLCs from the counterparty. Cannot take this path if
       recovering from out of sync commitments or if in the process of fulfilling an
       HTLC. (7) */
    :: desynced[i] == false && fulfilled[i] == false && rcv ? UPDATE_ADD_HTLC ->
       sent_or_received[i] = RECV; goto VAL_HTLC;

    /* Send an error if adding another HTLC puts the local node over its max HTLC limit. (31) */
    :: status[i] == INVALID -> goto FAIL_CHANNEL;

    /* Send additional HTLCs to the counterparty, but only if the previous HTLC
       (sent or received) did not put the local node over the `maxCurrentHtlcs`
       limit. (6) */
    :: status[i] == VALID && fulfilled[i] == false && desynced[i] == false ->
       snd ! UDPATE_ADD_HTLC; sent_or_received[i] = SEND; goto MORE_HTLCS_WAIT;

    /* The counterparty sends the first `COMMITMENT_SIGNED`. Once a node sends or
       receives a `COMMITMENT_SIGNED`, it must complete the pair before adding new
       HTLCs. Sending a commitment is an attempt to synchronize the nodes. If
       nodes were out-of-sync, they are now marked as in sync. They can later be
       marked as out-of-sync if a conflict occurs. (18) */
    :: status[i] == VALID && rcv ? COMMITMENT_SIGNED; desynced = false; goto VAL_PRIMARY_COMM;

    /* Once a node sends or receives a `COMMITMENT_SIGNED`, it must complete the
       pair before adding new HTLCs. Sending a commitment is an attempt to
       synchronize the nodes. If nodes were out-of-sync, they are now marked as in
       sync. They can later be marked as out-of-sync if a conflict occurs. (11) */
    :: status[i] == VALID && snd ! COMMITMENT_SIGNED; desynced = false; goto COMM_ACK_WAIT;
  fi

RESYNC:
  state[i] = ResyncState;
  if
    /* A `COMMITMENT_SIGNED` signed was sent concurrently (in addition to concurrent HTLCs),
       the local node needs to ack it. (43) */
    :: rcv ? COMMITMENT_SIGNED -> snd ! REVOKE_AND_ACK; goto VAL_DESYNC_COM;

    /* Fail the channel if the other node timesout or sends an error during
       resynchronization. (45) */
    :: timeout -> snd ! ERROR; goto FAIL_CHANNEL;
    :: rcv ? ERROR -> goto FAIL_CHANNEL;

    /* The nodes exchanged `UPDATE_ADD_HTLC`s concurrently. One node also send a
       `COMMITMENT_SIGNED`, which the counterparty has acked but not sent their own
       `COMMITMENT_SIGNED` (yet). (44) */
    :: rcv ? REVOKE_AND_ACK -> goto VAL_SEQ_ACK_1;
  fi

VAL_DESYNC_COM:
  state[i] = ValDesyncComState;
  run ValidateMsg(i);
  if
    /* The concurrent commitment is well-formed. Next step is to either send or
       receive commitments that include all the HTLCs. (48) */
    :: status[i] == VALID -> goto MORE_HTLCS_WAIT;

    /* Fail the channel if the commitment is malformed. (47) */
    :: status[i] == INVALID -> snd ! ERROR; goto FAIL_CHANNEL;
  fi

COMM_ACK_WAIT:
  state[i] = CommitmentAckWaitState;
  if
    /* An `UPDATE_ADD_HTLC` was received after the local node already sent a
       commitment. Nodes are out of sync and need to be resynchronized. (41) */
    :: rcv ? UPDATE_ADD_HTLC -> desynced = true; goto VAL_HTLC;

    /* There is no timeout specified in the specification, but there should be. */
    /* If the local node times out, send an `ERROR`. (17) */
    :: timeout -> snd ! ERROR; goto FAIL_CHANNEL;

    /* If an `ERROR` is received, fail the channel. (17) */
    :: rcv ? ERROR -> goto FAIL_CHANNEL;


    /* Commitments were sent sequentially. The counterparty acked a commitment before
       sending its own. (12) */
    :: rcv ? REVOKE_AND_ACK; goto VAL_SEQ_ACK_1;

    /* This transition means that the counterparty sent a commitment before
       receiving the local commitment, i.e., they are concurrent. This is fine as long as
       neither party both commits and revokes before receiving the counterparty's
       commitment. (19) */
    :: rcv ? COMMITMENT_SIGNED; goto VAL_CONC_COMM;
  fi

VAL_SEQ_ACK_1:
  state[i] = ValSeqAck1State;
  run ValidateMsg(i);
  if
    /* Receive sequential commitment, but only if the previously received ack was
       valid, and the peers are in sync. (13) */
    :: status[i] == VALID && desynced[i] == false && rcv ? COMMITMENT_SIGNED -> goto VAL_COMM;

    /* This transition should only be taken if the previous transition was `44`.
       The counterparty has sent an ack, so now the local node and the counterparty
       need to exchange commitments that include *all* the HTLCs (i.e. the
       concurrent ones that were not all previously accounted for). (46) */
    :: status[i] == VALID && desynced[i] == true -> goto MORE_HTLCS_WAIT;

    /* There is no timeout specified in the specification, but there should be.
       If the local node times out, send an `ERROR`. Also send an error if the
       previously received ack is invalid. (14) */
    :: timeout || status[i] == INVALID -> snd ! ERROR; goto FAIL_CHANNEL;

    /* If an `ERROR` is received, fail the channel. (14) */
    :: rcv ? ERROR -> goto FAIL_CHANNEL;
  fi

VAL_COMM:
  state[i] = ValCommitmentState;
  run ValidateMsg(i);
  if
    /* If the previously received commitment is valid, send an ack. Then wait for
       the HTLC fulfillment. (15) */
    :: status[i] == VALID -> snd ! REVOK_AND_ACK; goto HTLC_FULLFIL_WAIT;

    /* If the received commitment is invalid, send an `ERROR` and fail the channel. (16) */
    :: status[i] == INVALID -> snd ! ERROR; goto FAIL_CHANNEL;

    /* Can receive an `ERROR` message at any time. (16) */
    :: rcv ? ERROR -> goto FAIL_CHANNEL;
  fi

VAL_CONC_COMM:
  state[i] = ValConcCommitmentState;
  run ValidateMsg(i);
  if
    /* Both commitments have been exchanged, now we need to exchange both acks.
       Either order is fine. (21) */
    :: status[i] == VALID &&
       ((snd ! REVOKE_AND_ACK && rcv ? REVOKE_AND_ACK) ||
        (rcv ? REVOKE_AND_ACK && snd ! REVOKE_AND_ACK)) ->
       goto VAL_CONC_ACK;

    /* There is no timeout specified in the specification, but there should be.
       If the local node times out, send an `ERROR`. Also send an error if the
       previously received commitment is invalid. (20) */
    :: timeout || status[i] == INVALID -> snd ! ERROR; goto FAIL_CHANNEL;

    /* If an `ERROR` is received, fail the channel. (20) */
    :: rcv ? ERROR -> goto FAIL_CHANNEL;
  fi

VAL_PRIMARY_COMM:
  state[i] = ValPrimaryCommitmentState;
  run ValidateMsg(i);
  if
    /* Concurrent commitment swap. Send local commitment before swapping acks. (28) */
    :: status[i] == VALID &&
       snd ! COMMITMENT_SIGNED &&
       ((snd ! REVOKE_AND_ACK && rcv ? REVOKE_AND_ACK) ||
        (rcv ? REVOKE_AND_ACK && snd ! REVOKE_AND_ACK)) ->
       goto VAL_CONC_ACK;

    /* Send the ack and new commitment. (24) */
    :: status[i] == VALID -> snd ! REVOKE_AND_ACK; snd ! COMMITMENT_SIGNED; goto ACK_WAIT;

    /* If the received commitment is invalid, send an `ERROR` and fail the channel. (23) */
    :: status[i] == INVALID -> snd ! ERROR; goto FAIL_CHANNEL;

    /* Can receive an `ERROR` message at any time. (23) */
    :: rcv ? ERROR -> goto FAIL_CHANNEL;
  fi

FAIL_CHANNEL:
  state[i] = FailChannelState;
  goto end;

end:
  state[i] = EndState;
}


init {
  state[0] = FundedState;
  state[1] = FundedState;
  run LightningNormal(AtoB, BtoA, 0);
  run LightningNormal(BtoA, AtoB, 1);
}

