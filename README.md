# State Machine

``` mermaid
stateDiagram-v2
    direction LR

    <!-- classDef red fill:#f00,color:white,font-weight:bold -->
    <!-- classDef blue fill:#00ff,color:white,font-weight:bold -->

    <!-- class FAIL_CHANNEL red -->
    <!-- class FUNDED blue -->

    %% Pseudo transitions
    [*] --> FUNDED: (0)\n! FUNDING_LOCKED\n-----------------------------\nlocal_htlcs #colon;= 0\nremote_htlcs #colon;= 0
    FUNDED --> [*]: (28)\n? SHUTDOWN ||\n!SHUTDOWN

    %% Simple error case
    FUNDED --> FAIL_CHANNEL: (1)\n? UPDATE_ADD_HTLC, h\n--------------------------------\nif(checkHtlc(h) == PARSING_ERROR) then ! UPDATE_FAIL_MALFORMED_HTLC\nelse if (checkHtlc(h)==NO_ROUTE) then ! UPDATE_FAIL_HTLC\nelse if(checkHtlc(h)==INVALID) then ! ERROR

    %% Received an update from upstream
    FUNDED --> MORE_HTLCS_WAIT: (2)\n? UPDATE_ADD_HTLC, h &&\ncheckHtlc(h) == VALID\n--------------------------------\nlocal_htlcs++\nset [NEW_HTLCS_T]
    FUNDED --> MORE_HTLCS_WAIT: (3)\n? USER_TX ||\n? UPDATE_ADD_HTLC_DS\n--------------------------------\n! UPDATE_ADD_HTLC\nremote_htlcs++\nset [NEW_HTCLS_T]
    FUNDED --> COMM_WAIT: (4)\n? USER_TX ||\n? UPDATE_ADD_HTLC_DS\n--------------------------------\n! UPDATE_ADD_HTLC\n ! COMMITMENT_SIGNED\nremote_htlcs++\nset [COMM_REV_T]

    MORE_HTLCS_WAIT --> REVOKE_WAIT: (5)\n? COMMITMENT_SIGNED, c &&\ncheckComm(c) == VALID\n------------------------------------\n! REVOKE_AND_ACK\n! COMMITMENT_SIGNED\nset [REV_T]
    MORE_HTLCS_WAIT --> FAIL_CHANNEL: (Xa)\n? COMMITMENT_SIGNED, c &&\ncheckComm(c) == INVALID\n------------------------------------\n! ERROR
    MORE_HTLCS_WAIT --> FAIL_CHANNEL: (Xb)\n? COMMITMENT_SIGNED, c &&\ncheckComm(c) == INVALID
    MORE_HTLCS_WAIT --> COMM_WAIT: (6)\n? USER_TX ||\n? UPDATE_ADD_HTLC_DS\n--------------------------------\n! UPDATE_ADD_HTLC\n! COMMITMENT_SIGNED\nremote_htlcs++\nset [COMM_REV_T]
    MORE_HTLCS_WAIT --> COMM_WAIT: (7)\n? UPDATE_ADD_HTLC, h &&\ncheckHtlc(h) == VALID\n--------------------------------\n! UPDATE_ADD_HTLC\n! COMMITMENT_SIGNED\nlocal_htlcs++\nremote_htlcs++\nset [COMM_REV_T]

    %% NOTE: I'm actually not sure about this one. The implementation does it, but I don't think it's mentioned in the BOLTs
    MORE_HTLCS_WAIT --> COMM_WAIT: (8)\nTIMEOUT [NEW_HTCLS_T]\n-----------------------------------\n! COMMITMENT_SIGNED\nset [COMM_REV_T]
    MORE_HTLCS_WAIT --> FAIL_CHANNEL: (9)\n? UPDATE_FAIL_HTLC ||\n? UPDATE_FAIL_MALFORMED_HTLC
    MORE_HTLCS_WAIT --> MORE_HTLCS_WAIT: (10)\n? USER_TX ||\n? UPDATE_ADD_HTLC_DS\n--------------------------------\n! UPDATE_ADD_HTLC\nremote_htlcs++
    MORE_HTLCS_WAIT --> MORE_HTLCS_WAIT: (11)\n? UPDATE_ADD_HTLC, h &&\ncheckHtlc(h) == VALID\n--------------------------------\nlocal_htlcs++
    MORE_HTLCS_WAIT --> FAIL_CHANNEL: (12)\n? UPDATE_ADD_HTLC, h\n--------------------------------\nif(checkHtlc(h) == PARSING_ERROR) then ! UPDATE_FAIL_MALFORMED_HTLC\nelse if (checkHtlc(h)==NO_ROUTE) then ! UPDATE_FAIL_HTLC\nelse if(checkHtlc(h)==INVALID) then ! ERROR

    REVOKE_WAIT --> COMM_WAIT_2: (13)\n? REVOKE_AND_ACK, a &&\ncheckAck(a) == VALID &&\nremote_htlcs==1 &&\nlocal_htlcs==0\n-------------------------------\n! UPDATE_FULFILL_HTLC\n! COMMITMENT_SIGNED\nremote_htlcs--\nset [COMM_T]
    REVOKE_WAIT --> FULFILL_WAIT: (14)\n? REVOKE_AND_ACK, a &&\ncheckAck(a) == VALID && \n(remote_htlcs !=1 ||\nlocal_htlcs != 0)\n-------------------------------\nset [FULFILL_REMOTE_T]\nset [FULFILL_LOCAL_T]
    REVOKE_WAIT --> FAIL_CHANNEL: (15a)\nTIMEOUT [REV_T]\n-------------------------------------\n ! ERROR
    REVOKE_WAIT --> FAIL_CHANNEL: (15b)\nTIMEOUT [REV_T] ||\n? ERROR
    
    COMM_WAIT --> COMM_WAIT: (16)\n? REVOKE_AND_ACK, a &&\ncheckAck(a)  == VALID
    COMM_WAIT --> COMM_WAIT: (17)\n? COMMITMENT_SIGNED, c &&\ncheckComm(c) == VALID\n------------------------------------\n! REVOKE_AND_ACK
    COMM_WAIT --> FULFILL_WAIT: (18)\n? REVOKE_AND_ACK, a &&\ncheckAck(a) == VALID\n-------------------------------\nset [FULFILL_REMOTE_T]\nset [FULFILL_LOCAL_T]
    COMM_WAIT --> FULFILL_WAIT: (19)\n? COMMITMENT_SIGNED, c &&\ncheckComm(c) == VALID\n------------------------------------\n! REVOKE_AND_ACK\nset [FULFILL_REMOTE_T]\nset [FULFILL_LOCAL_T]
    COMM_WAIT --> FAIL_CHANNEL: (20a)\nTIMEOUT [COMM_REV_T]\n-------------------------------------------------------\n! ERROR
    COMM_WAIT --> FAIL_CHANNEL: (20b)\nTIMEOUT [COMM_REV_T] ||\n? ERROR
    COMM_WAIT --> FAIL_CHANNEL: (20c)\n? REVOKE_AND_ACK, a &&\ncheckAck(a) == INVALID\n------------------------------\n! ERROR
    COMM_WAIT --> FAIL_CHANNEL: (20d)\n? REVOKE_AND_ACK, a &&\ncheckAck(a) == INVALID

    FULFILL_WAIT --> FULFILL_WAIT: (21)\n? UPDATE_FULFILL_HTLC, f &&\ncheckFulfillment(f) == VALID\n-------------------------------------\nlocal_htlcs--\nset [FULFILL_REMOTE_T]
    FULFILL_WAIT --> FULFILL_WAIT: (22)\n? UPDATE_FULFILL_HTLC_DS || TIMEOUT [FULFILL_LOCAL_T]\n------------------------------------------------------------\n! UPDATE_FULFILL_HTLC\nremote_htlcs--
    FULFILL_WAIT --> FAIL_CHANNEL: (23a)\nTIMEOUT [FULFILL_REMOTE_T]\n------------------------------------------------\n! ERROR
    FULFILL_WAIT --> FAIL_CHANNEL: (23b)\nTIMEOUT [FULFILL_REMOTE_T] ||\n? ERROR
    FULFILL_WAIT --> FAIL_CHANNEL: (23c)\n? UPDATE_FULFILL_HTLC, f &&\ncheckFulfillment(f) == INVALID\n-------------------------------------\n! ERROR
    FULFILL_WAIT --> FAIL_CHANNEL: (23d)\n? UPDATE_FULFILL_HTLC, f &&\ncheckFulfillment(f) == INVALID


    FULFILL_WAIT --> COMM_WAIT_2: (24)\n? UPDATE_FULFILL_HTLC, f &&\ncheckFulfillment(f) == VALID &&\nlocal_htlcs==1 &&\nremote_htlcs==0\n-------------------------------------\n! COMMITMENT_SIGNED\nlocal_htlcs--\nset [COMM_T]
    FULFILL_WAIT --> COMM_WAIT_2: (25)\n(? UPDATE_FULFILL_HTLC_DS || TIMEOUT [FULFILL_REMOTE_T]) &&\nremote_htlcs==1 &&\nlocal_htlcs==0\n------------------------------------------------------------\n! UPDATE_FULFILL_HTLC\n! COMMITMENT_SIGNED\nremote_htlcs--\nset [COMM_T]

    COMM_WAIT_2 --> REVOKE_WAIT_2: (26)\n? COMMITMENT_SIGNED, c &&\ncheckComm(c) == VALID\n------------------------------------\n! REVOKE_AND_ACK\nset [REV_T]
    COMM_WAIT_2 --> FAIL_CHANNEL: (27a)\nTIMEOUT [COMM_T]\n------------------------------------------\n! ERROR
    COMM_WAIT_2 --> FAIL_CHANNEL: (27b)\nTIMEOUT [COMM_T] ||\n? ERROR
    COMM_WAIT_2 --> FAIL_CHANNEL: (27c)\n? COMMITMENT_SIGNED, c &&\ncheckComm(c) == INVALID\n--------------------------------------------\n! ERROR
    COMM_WAIT_2 --> FAIL_CHANNEL: (27d)\n? COMMITMENT_SIGNED, c &&\ncheckComm(c) == INVALID

    REVOKE_WAIT_2 --> FUNDED: (29)\n? REVOKE_AND_ACK, a &&\ncheckAck(a) == VALID
    REVOKE_WAIT_2 --> FAIL_CHANNEL: (30a)\nTIMEOUT [REV_T]\n------------------------------------------\n! ERROR
    REVOKE_WAIT_2 --> FAIL_CHANNEL: (30b)\nTIMEOUT [REV_T] ||\n? ERROR
    REVOKE_WAIT_2 --> FAIL_CHANNEL: (30c)\n? REVOKE_AND_ACK, a &&\ncheckAck(a) == INVALID\n--------------------------------------------\n! ERROR
    REVOKE_WAIT_2 --> FAIL_CHANNEL: (30d)\n? REVOKE_AND_ACK, a &&\ncheckAck(a) == INVALID
```
