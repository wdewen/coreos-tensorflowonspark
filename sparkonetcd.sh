#!/bin/bash

. /etc/profile.d/apache-spark.sh
. /etc/profile.d/hadoop.sh

main () {

    NODE_IP=$1
    DISCOVERY_URL=$2

    ETCD_LOGS="/tmp/$NODE_IP-etcd.log"
    
    setup_userfilesystem

    if [ -z "$(cat /etc/hosts | grep $(hostname))" ]; then
	echo "$NODE_IP    $(hostname)" >> /etc/hosts
    fi

    yell "bootstrapping..."
    
    if [ ! -z $DISCOVERY_URL ]; then
	yell "got discovery token; attempting to join etcd cluster (waiting for all nodes)"
	runuser -u spark -- etcd --name $(hostname) --discovery $DISCOVERY_URL --advertise-client-urls=http://$NODE_IP:2379 --listen-client-urls=http://$NODE_IP:2379 --listen-peer-urls=http://$NODE_IP:2380 --initial-advertise-peer-urls=http://$NODE_IP:2380 &> $ETCD_LOGS &
	ETCDPID=$!
	sleep 2
	until curl -X GET http://$NODE_IP:2379/v2/machines; do
	    kill -0 $ETCDPID
	    if [ $? -ne 0 ]; then
		err $? "etcd appears to have failed." $ETCD_LOGS
	    fi
	    sleep 2
	done
	echo "(all nodes found in etcd cluster)"
	sleep 5 # wait for leader to be elected (needs better way)
    fi
    etcd "cluster-health"
    if [ $? -ne 0 ]; then
	err $? "etcd seems to have issues." $ETCD_LOGS
    fi
    etcd "get /spark/master" 1> /dev/null
    if [ $? -ne 0 ]; then
	yell "etcd has no /spark/master host entry; we're going for it"
	etcd "mk /spark/master ${NODE_IP}" &> /dev/null
    fi
    SPARK_MASTER_IP=$(etcd "get /spark/master")
    SPARK_MASTER_PORT=7077
    SPARK_LOCAL_IP=$NODE_IP
    PGREPF="worker"
    sed -i -e "s/\$MASTER_IP/${SPARK_MASTER_IP}/g" -e "s/\$NODE_IP/${NODE_IP}/g" $SPARK_HOME/conf/spark-defaults.conf
    if [ "$NODE_IP" = "$SPARK_MASTER_IP" ]; then 
	PGREPF="master"
	yell "we're spark master host!"
	yell "running start-master.sh..."
	runuser -u spark -- $SPARK_HOME/sbin/start-master.sh -h $NODE_IP
	sleep 5
	if [ -z "$(pgrep -f master)" ]; then
	    err 1 "start-master.sh appears to have failed." /opt/apache-spark/logs/*.master.*.out
	fi
    fi
    yell "running start-worker.sh..."
    runuser -u spark -- $SPARK_HOME/sbin/start-slave.sh -h $NODE_IP spark://$SPARK_MASTER_IP:$SPARK_MASTER_PORT
    sleep 5
    if [ -z "$(pgrep -f $PGREPF)" ]; then
	err 1 "start-slave.sh appears to have failed." /opt/apache-spark/logs/*.$PGREPF.*.out
    fi
    yell "successfully started $PGREPF; done."

    setup_env
    
    tail -f --pid=$(pgrep -f $PGREPF) /opt/apache-spark/logs/*.$PGREPF.*.out
}

err() {
    echo ">>> ERROR: $2"
    echo ">>> Last 10 lines of $3:"
    tail -n10 $3
    exit $1
}

yell() {
    echo ">>> $1"
}

setup_userfilesystem() {
    
    chown -R user:user /opt/user
    chmod -R ug+rwx /opt/user
    
}

setup_env() {

    echo "export MASTER=spark://$SPARK_MASTER_IP:$SPARK_MASTER_PORT" >> /etc/profile.d/apache-spark.sh
    
}

etcd() {
    etcdctl --endpoint http://$NODE_IP:2379 $1
}


main $@
