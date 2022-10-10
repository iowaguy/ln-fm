/* A state machine of the gossip protocol within the Lightning Network */
mtype = {
    /* These are message types. They can be sent by one node to
     its counterparty across the channel. */
    SHUTDOWN, CLOSING_SIGNED,
    
    /* These two are flags. They indicate whether a particular
     message was sent or received, which is important sometimes.
     Used by the state machine, but not communicated on the wire
     in the actual protocol.*/
    SEND, RECV,
    
    /* Validation states output one of the following. INVALID
     usually leads to an error state. Used by the state machine,
     but not communicated on the wire in the actual protocol. */
  VALID, INVALID
}

/* Messages can be delayed in the channel. */
chan AtoB = [1] of { mtype };
chan BtoA = [1] of { mtype };

int state[2];
int pids[2];

/* A boolean that indicates if the proposed sent by the counter-party 
is acceptable. */
bool acceptable[2] = {false,false};

/* This variable can be either SEND or RECV, depending on whether
   the message is being sent or received. */
mtype sent_or_received[2];

/* This variable represents the return status of the intermediate
   function calls. */
mtype status[2];

#define CloseIdleState                    0
#define CloseShutdownInitiatedState       1
#define ValidateShutdownState             2
#define FailChannelState                  3
#define CloseFeeNegotiationState          4
#define CloseFinishedState                5
#define EndState                         -1

/* This function simulates validating a received message. A message
   can either be valid or invalid. It is essentially a coin flip that
   causes both outcomes to be checked. */
inline ValidateMsg(peer) {
  if
    :: status[peer] = VALID;
    :: status[peer] = INVALID;
  fi
}

/*  This function simulates a party's decision making on 
    whether the fee proposed by the counter-party is acceptable or not.
    A message can either be acceptable or inacceptable. It is essentially a coin 
    flip that causes both outcomes to be checked. */
inline feeAcceptable(peer) {
    :: acceptable[peer] = true;
    :: acceptable[peer] = false;
}

proctype LightningClosing(chan snd, rcv; bit i) {
  pids[i] = _pid;

CLOSE_IDLE:
    state[i] = CloseIdleState;
    if
        /* Send a SHUTDOWN message to the counterparty */
        :: snd !SHUTDOWN -> sent_or_received[i] = SEND; goto CLOSE_SHUTDOWN_INITIATED
        
        /* Receive a SHUTDOWN message from the counterparty */
        :: rcv ?SHUTDOWN -> sent_or_received[i] = RECV; goto VALIDATE_SHUTDOWN
    fi
    
CLOSE_SHUTDOWN_INITIATED:
    state[i] = CloseShutdownInitiatedState;
    /* Receive a SHUTDOWN message from the counterparty */
    :: rcv ?SHUTDOWN -> sent_or_received[i] = RECV; goto VALIDATE_SHUTDOWN

VALIDATE_SHUTDOWN:
    state[i] = ValidateShutdownState
    ValidateMsg(peer);
    do
        /* Send error if the SHUTDOWN message is invalid */
        :: status[i] == INVALID -> snd !ERROR; goto FAIL_CHANNEL;
        /* If the message is valid we move to negotiate the closing fee */
        :: status[i] == VALID -> goto CLOSE_FEE_NEGOTIATION;
    od
    
CLOSE_FEE_NEGOTIATION:
    state[i] = CloseFeeNegotiationState;
    do
        /* Receive a CLOSING_SIGNED message from the counterparty. If the fee 
        proposed is not acceptable, then send another CLOSING_SIGNED 
        to the counter-party with an alternate fee proposal. If the fee is acceptable,
        send a CLOSING_SIGNED message with the same fee and move to CLOSE_FINISHED 
        after signing and broadcasting the closing transaction */
        :: rcv ?CLOSING_SIGNED -> feeAcceptible(peer);
        if 
            :: acceptable[i] == false -> snd !CLOSING_SIGNED; sent_or_received[i] = RECV; goto CLOSE_FEE_NEGOTIATION;
            :: acceptable[i] == true ->  goto CLOSE_FINISHED;
        fi
        
        /* Send the first CLOSING_SIGNED message with a fee proposal to 
        the counterparty */
        :: snd !CLOSING_SIGNED -> sent_or_received[i] = SEND; goto CLOSE_FEE_NEGOTIATION;
    od

CLOSE_FINISHED:
    /* Closing transaction has been broadcasted and we can move to end state. */
    state[i] = CloseFinishedState;
    goto end;

FAIL_CHANNEL:
    state[i] = FailChannelState;
    goto end;

end:
    state[i] = EndState;
}

init {
  state[0] = CloseIdleState;
  state[1] = CloseIdleState;
  run LightningClosing(AtoB, BtoA, 0);
  run LightningClosing(BtoA, AtoB, 1);
}
