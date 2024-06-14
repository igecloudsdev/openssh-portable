#	$OpenBSD
#	Placed in the Public Domain.

tid="penalties"

grep -vi PerSourcePenalties $OBJ/sshd_config > $OBJ/sshd_config.bak
cp $OBJ/authorized_keys_${USER} $OBJ/authorized_keys_${USER}.bak

conf() {
	test -z "$PIDFILE" || stop_sshd
	(cat $OBJ/sshd_config.bak ;
	 echo "PerSourcePenalties $@") > $OBJ/sshd_config
	cp $OBJ/authorized_keys_${USER}.bak $OBJ/authorized_keys_${USER}
	start_sshd
}

conf "authfail:30s min:50s max:200s"

verbose "test connect"
${SSH} -F $OBJ/ssh_config somehost true || fatal "basic connect failed"

verbose "penalty for authentication failure"

# Fail authentication once
cat /dev/null > $OBJ/authorized_keys_${USER}
${SSH} -F $OBJ/ssh_config somehost true && fatal "noauth connect succeeded"
cp $OBJ/authorized_keys_${USER}.bak $OBJ/authorized_keys_${USER}

# Should be below penalty threshold
${SSH} -F $OBJ/ssh_config somehost true || fatal "authfail not expired"

# Fail authentication again; penalty should activate
cat /dev/null > $OBJ/authorized_keys_${USER}
${SSH} -F $OBJ/ssh_config somehost true && fatal "noauth connect succeeded"
cp $OBJ/authorized_keys_${USER}.bak $OBJ/authorized_keys_${USER}

# These should be refused by the active penalty
${SSH} -F $OBJ/ssh_config somehost true && fail "authfail not rejected"
${SSH} -F $OBJ/ssh_config somehost true && fail "repeat authfail not rejected"

conf "noauth:100s"
${SSH} -F $OBJ/ssh_config somehost true || fatal "basic connect failed"
verbose "penalty for no authentication"
${SSHKEYSCAN} -t ssh-ed25519 -p $PORT 127.0.0.1 >/dev/null || fatal "keyscan failed"

# Repeat attempt should be penalised
${SSHKEYSCAN} -t ssh-ed25519 -p $PORT 127.0.0.1 >/dev/null 2>&1 && fail "keyscan not rejected"
