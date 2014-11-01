# Usage (one of these):
# ./delegate.sh
# GDB="gdb -ex run --args" ./delegate.sh

num=${1-000}
testnet_datadir=tmp/delegate${num}

BTS_BUILD=${BTS_BUILD-~/bitshares/bitshares_toolkit}
BTS_WEBKIT=${BTS_WEBKIT-~/bitshares/bitshares_webkit}

HTTP_PORT=${HTTP_PORT-42${num}}	# 42000
RPC_PORT=${RPC_PORT-43${num}}	# 43000
P2P_PORT=10${num}		# 10000

function init {
  . ./bin/rpc_function.sh
  if test -d "$testnet_datadir/wallets/default"
  then
    if [ -z "$GDB" ]
    then
        sleep 3
    else
        sleep 10
    fi
    echo "Login..."
    # the process may be gone, re-indexing, etc. just error silently
    rpc open '"default"' > /dev/null 2>&1
    rpc unlock '9999, "Password00"' > /dev/null 2>&1
  else
    sleep 3
    echo "Creating default wallet..."
    rpc wallet_backup_restore '"config/wallet.json", "default", "Password00"'
  fi
  for i in $(seq 0 100)
  do
    rpc wallet_delegate_set_block_production '"delegate'$i'", "true"'
  done
}
init&

set -o xtrace

${GDB-} \
"${BTS_BUILD}/programs/client/bitshares_client"\
 --data-dir "$testnet_datadir"\
 --genesis-config "$BTS_WEBKIT/testnet/config/genesis.json"\
 --server\
 --httpport=$HTTP_PORT\
 --rpcport=$RPC_PORT\
 --rpcuser=test\
 --rpcpassword=test\
 --upnp=false\
 --p2p-port=$P2P_PORT\
 --min-delegate-connection-count=0\
 --disable-default-peers
