// A state machine of the gossip protocol within the Lightning Network

mtype = { INIT, CHAN_ANN, CHAN_UP, NODE_ANN,
					ERR_PROTO_SIG, ERR_BLACKLIST,
					ERR_UNKNOWN_CHAIN_HASH, ERR_NO_P2WSH,
					ERR_UTXO_USED }

chan AtoN = [1] of { mtype };
chan NtoA = [0] of { mtype };
chan BtoN = [1] of { mtype };
chan NtoB = [0] of { mtype };

int state[2];
int pid[2];

#define InitState               0
#define BoostrapState           1
#define ListenChanState         2
#define ValidateChanAnnState    3
#define NoRouteState            4
#define ValidateUpState         5
#define ListenNodeState         6
#define ValidateNodeAnnState    7
#define UserWaitState           8
#define MakeChanAnnState        9
#define MakeChanUpState         10
#define MakeNodeAnnState        11
#define EndState                -1

proctype LightningGossip(chan snd, rcv; int i) {
	pids[i] = _pid;
CLOSED:
	state[i] = ClosedState;
	if
	/* Passive open */
	:: goto LISTEN;
	/* Active open */
	:: snd ! SYN; goto SYN_SENT;
	/* Terminate */
	:: goto end;
	fi

end:
	state[i] = EndState;
}


init {
	state[0] = InitState;
	state[1] = InitState;
	run LightningGossip(AtoN, NtoA, 0);
	run LightningGossip(BtoN, NtoB, 1);
}

// TODO question for max: why are only SYN, ACK, and FIN modeling in the network here?
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
