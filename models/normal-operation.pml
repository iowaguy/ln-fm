/* A state machine of the gossip protocol within the Lightning Network */

mtype = {
	UPDATE_ADD_HTLC, ERROR, COMMITMENT_SIGNED, REVOKE_AND_ACK,
	UPDATE_FAIL_HTLC, UPDATE_FAIL_MALFORMED_HTLC, UPDATE_FULFILL_HTLC
}

chan AtoN = [1] of { mtype };
chan NtoA = [0] of { mtype };
chan BtoN = [1] of { mtype };
chan NtoB = [0] of { mtype };

int state[2];
int pids[2];

#define FundedState             0
#define ValHtlcState            1
#define HtlcOpenState           2
#define AckWaitState            3
#define ConfirmCommState        4
#define FailState               5
#define CloseState              6
#define EndState                -1

proctype LightningNormal(chan snd, rcv; int i) {
	pids[i] = _pid;
FUNDED:
	state[i] = FundedState;
	if
  :: rcv ! UPDATE_ADD_HTLC -> goto VAL_HTLC;
	fi
VAL_HTLC:
  state[i] = ValHtlcState;
  if
	:: snd ! UPDATE_FAIL_HTLC; snd ! ERROR -> goto FAIL;
	:: snd ! UPDATE_FAIL_MALFORMED_HTLC; snd ! ERROR -> goto FAIL;

	/* This transition executes if the HTLC is valid*/
	:: goto HTLC_OPEN;
  fi
HTLC_OPEN:
  state[i] = HtlcOpenState;
	if
	:: snd ! COMMITMENT_SIGNED -> goto ACK_WAIT;
	:: rcv ? COMMITMENT_SIGNED -> goto CONFIRM_COMM;
	:: rcv ? UPDATE_FULFILL_HTLC -> goto FUNDED;
	:: goto CLOSE;
	fi
ACK_WAIT:
  state[i] = AckWaitState;
	if
	:: rcv ? REVOKE_AND_ACK -> goto HTLC_OPEN;
	fi
CONFIRM_COMM:
  state[i] = ConfirmCommState;
	if
	/* Do this if the commitment_signed is valid */
	:: snd ! REVOKE_AND_ACK -> goto HTLC_OPEN;
	:: snd ! ERROR -> goto FAIL;
	fi
FAIL:
  state[i] = FailState;
	goto end;
CLOSE:
  state[i] = CloseState;
	goto end;
end:
	state[i] = EndState;
}


init {
	state[0] = FundedState;
	state[1] = FundedState;
	run LightningNormal(AtoN, NtoA, 0);
	run LightningNormal(BtoN, NtoB, 1);
}

active proctype network() {
	do
	:: AtoN ? UPDATE_ADD_HTLC ->
		if
		:: NtoB ! UPDATE_ADD_HTLC;
		fi unless timeout;
	:: BtoN ? UPDATE_ADD_HTLC ->
		if
		:: NtoA ! UPDATE_ADD_HTLC;
		fi unless timeout;
	:: AtoN ? ERROR ->
		if
		:: NtoB ! ERROR;
		fi unless timeout;
	:: BtoN ? ERROR ->
		if
		:: NtoA ! ERROR;
		fi unless timeout;
	:: AtoN ? COMMITMENT_SIGNED ->
		if
		:: NtoB ! COMMITMENT_SIGNED;
		fi unless timeout;
	:: BtoN ? COMMITMENT_SIGNED ->
		if
		:: NtoA ! COMMITMENT_SIGNED;
		fi unless timeout;
	:: AtoN ? REVOKE_AND_ACK ->
		if
		:: NtoB ! REVOKE_AND_ACK;
		fi unless timeout;
	:: BtoN ? REVOKE_AND_ACK ->
		if
		:: NtoA ! REVOKE_AND_ACK;
		fi unless timeout;

	:: AtoN ? UPDATE_FAIL_HTLC ->
		if
		:: NtoB ! UPDATE_FAIL_HTLC;
		fi unless timeout;
	:: BtoN ? UPDATE_FAIL_HTLC ->
		if
		:: NtoA ! UPDATE_FAIL_HTLC;
		fi unless timeout;
	:: AtoN ? UPDATE_FAIL_MALFORMED_HTLC ->
		if
		:: NtoB ! UPDATE_FAIL_MALFORMED_HTLC;
		fi unless timeout;
	:: BtoN ? UPDATE_FAIL_MALFORMED_HTLC ->
		if
		:: NtoA ! UPDATE_FAIL_MALFORMED_HTLC;
		fi unless timeout;
	:: AtoN ? UPDATE_FULFILL_HTLC ->
		if
		:: NtoB ! UPDATE_FULFILL_HTLC;
		fi unless timeout;
	:: BtoN ? UPDATE_FULFILL_HTLC ->
		if
		:: NtoA ! UPDATE_FULFILL_HTLC;
		fi unless timeout;
	:: _nr_pr < 3 -> break;
	od
}
