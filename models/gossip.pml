/* A state machine of the gossip protocol within the Lightning Network */

mtype = { INIT, CHAN_ANN, CHAN_UP, NODE_ANN,
					ERR_PROTO_SIG, ERR_BLACKLIST,
					ERR_UNKNOWN_CHAIN_HASH, ERR_NO_P2WSH,
					ERR_UTXO_USED }

chan AtoN = [1] of { mtype };
chan NtoA = [0] of { mtype };
chan BtoN = [1] of { mtype };
chan NtoB = [0] of { mtype };

/* TODO 10 is probably not the right number. What value */
/* should I use? */
chan StoredA = [10] of { mtype };
chan StoredB = [10] of { mtype };
chan RecentRejA = [10] of { mtype };
chan RecentRejB = [10] of { mtype };

int state[2];
int pid[2];

#define InitState               0
#define ListenChanState         1
#define ValidateChanAnnState    2
#define NoRouteState            3
#define ValidateUpState         4
#define ListenNodeState         5
#define ValidateNodeAnnState    6
#define UserWaitState           7
#define MakeChanAnnState        8
#define MakeChanUpState         9
#define MakeNodeAnnState        10
#define EndState                -1

proctype LightningGossip(chan snd, rcv, stored, rec_rej; int i) {
	pids[i] = _pid;
INITIAL:
	state[i] = InitState;
	if
  :: snd ! INIT -> goto LISTEN_CHAN;
  /* Terminate; TODO is this needed? */
	:: goto end;
	fi
LISTEN_CHAN:
  state[i] = ListenChanState;
  if
  :: rcv ? CHAN_ANN -> goto VALIDATE_CHAN_ANN
  fi
VALIDATE_CHAN_ANN:
  state[i] = ValidateChanAnnState;
  if
	:: stored ! CHAN_ANN -> goto VALIDATE_CHAN_ANN;
	:: rec_rej ! CHANN_ANN -> goto LISTEN_CHAN;
::
  fi


end:
	state[i] = EndState;
}


init {
	state[0] = InitState;
	state[1] = InitState;
	run LightningGossip(AtoN, NtoA, StoredA, RecentRejA, 0);
	run LightningGossip(BtoN, NtoB, StoredB, RecentRejB, 1);
}

/* TODO question for max: why are only SYN, ACK, and FIN modeling in the network here? */
active proctype network() {
	do
	:: AtoN ? SYN ->
		if
		:: NtoB ! SYN;
		fi unless timeout;
	:: BtoN ? SYN ->
		if
		:: NtoA ! SYN;
		fi unless timeout;
	:: AtoN ? FIN ->
		if
		:: NtoB ! FIN;
		fi unless timeout;
	:: BtoN ? FIN ->
		if
		:: NtoA ! FIN;
		fi unless timeout;
	:: AtoN ? ACK ->
		if
		:: NtoB ! ACK;
		fi unless timeout;
	:: BtoN ? ACK ->
		if
		:: NtoA ! ACK;
		fi unless timeout;
	:: _nr_pr < 3 -> break;
	od
end:
}
