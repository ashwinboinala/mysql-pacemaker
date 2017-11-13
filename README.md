# mysql-pacemaker
Mysql replication auto failover using pacemaker.

Below is a simple solution to automate mysql replication failover using pacemaker:


1) Mysql installed on both the nodes with mysqlutilities and setup GTID replication.
       
       All slaves must use --master-info-repository=TABLE and create a replication user (ex: repl_admin) with following priviliges:
       SUPER, GRANT OPTION, REPLICATION SLAVE, RELOAD, DROP, CREATE, INSERT, and SELECT.
       

2) You need a virtual Ip with a DNS entry. (ex: 1.2.3.4 DNS: mysqlcluster)

3) Install pacemaker on both nodes, below are the installation steps.



    1)	Install pacemaker
        ```shell
        yum install pcs pacemaker fence-agents-all
        ```
    2)	Enable all services & start pcsd
        ```shell
        /bin/systemctl enable pcsd
        /bin/systemctl enable pacemaker
        /bin/systemctl enable corosync
        
        systemctl start pcsd
        ```   
    3)  Create a user on both mysql nodes and assign password
        (ex: hacluster)
        
    4)  Cluster auth
        ```shell
        #pcs cluster auth node1 node2

        #ex :
        pcs cluster auth mysqlnode1 mysqlnode2
        user: hacluster
        ```
    5)  Setup the cluster
        ```shell
        #pcs cluster setup --start --name cluster_name(dns_name) node1 node2

        #Example: mysqlcluster is your DNS_name

        pcs cluster setup --start --name mysqlcluster mysqlnode1 mysqlnode2
        ```
        
    6)  Add resource
        ```shell
        #pcs resource create VirtualIP IPaddr2 ip=virtual_ip  cidr_netmask=24 --group Dns_name

        #ex:  1.2.3.4 is your dns IP
        pcs resource create VirtualIP IPaddr2 ip=1.2.3.4 cidr_netmask=24 --group mysqlcluster
        ```
        
    7) Run below command to disable stonith & set no-quorum
    
       ```shell
       pcs property set stonith-enabled=false

       pcs property set no-quorum-policy=ignore
       ```  
   
   8)  Start & enable all services 
       
       ```shell
       pcs cluster start --all
       
       pcs cluster enable --all
       
       ```
       
   9)  Check status
       ```shell
        pcs status
       ``` 
   10) Manual failover
       ```shell
       pcs cluster stop mysqlnode1
       
       #verify if cluster is online on node2 (pcs status), then re-start the cluster on node1
       
       pcs cluster start mysqlnode1
       ```
      
      
4) Auto failover script for pacemaker (pcs-failover.sh), use below script to failover pcs.(run it on slave)

   ```shell
   #!/bin/sh
    cluster_activenode=$(pcs status | grep "Current DC:" | cut -d: -f2 | cut -d"(" -f1 | sed -e 's/^[ \t]*//')

    vip_activenode=$(pcs status | awk '/VirtualIP.*Started/{print $NF}')

    #hostname=echo $HOSTNAME

    if [ $cluster_activenode != $HOSTNAME ];
     then
              pcs cluster stop $cluster_activenode
              #echo $cluster_activenode $HOSTNAME

              sleep 45
              newcluster_activenode=$(pcs status | grep "Current DC:" | cut -d: -f2 | cut -d"(" -f1 | sed -e 's/^[ \t]*//')

             if [ $newcluster_activenode = $HOSTNAME ]; then

                pcs cluster start $cluster_activenode

            fi

    elif [ $vip_activenode != $HOSTNAME ];
     then
              pcs cluster stop $vip_activenode
             #echo vip_activenode

             sleep 45

              newvip_activenode=$(pcs status | awk '/VirtualIP.*Started/{print $NF}')

           if [ $newvip_activenode = $HOSTNAME ];      then

               pcs cluster start $vip_activenode

            fi

    fi
   
   ```
       

5) I am using mysql_config_editor to connect to master and slave, this way you are not exposing your password.
   Below is an example.
   
   ```shell
   
   #on node1
        
        mysql_config_editor set --login-path=local --socket=/var/lib/mysql/mysql.sock --user=repl_admin --password 
        --host=mysqlnode1 --port=3306
        
        mysql_config_editor set --login-path=master --user=repl_admin --password --host=mysqlnode2 --port=3306
        
   #on node2 
        
        mysql_config_editor set --login-path=local --socket=/var/lib/mysql/mysql.sock --user=repl_admin --password 
        --host=mysqlnode2 --port=3306
        
        mysql_config_editor set --login-path=master --user=repl_admin --password --host=mysqlnode1 --port=3306
        
   ```
       

6) Start mysqlfialover demon on slave, this will continously monitors the master & slave and all the activity is logged into --log    file, if the master is down and failover is triggered once the fialover is done the new master logpos is logged into log file and you can use that pos to start replicating data from new master to new slave.       
   ```shell
   
   mysqlfailover --master=master --slaves=local --failover-mode=auto --daemon=start --exec-before=/scripts/pcs-failover.sh 
   --exec-after=/scripts/after-failover.sh --log=/mysql-repllogs.txt --log-age=90 --master-fail-retry=60 --force
   
   ```
   you can use --exec-after option to make changes on New master(Post-failover tasks) for example I turn off the read_only flag.
   ```
   mysql --login-path=local -e="SET GLOBAL read_only = OFF;" 
   ```
   #if the fialover is triggered the new master info is logged into log file.
   ex: 
   Below is the sample log that gets generated after failover.
   ```
       2017-11-10 00:11:01 AM INFO Failed to reconnect to the master after 3 attempts.
       2017-11-10 00:11:01 AM CRITICAL Master is confirmed to be down or unreachable.
       2017-11-10 00:11:01 AM INFO Failover starting in 'auto' mode...
       2017-11-10 00:11:01 AM INFO Candidate slave mysqlnode2:3306 will become the new master.
       2017-11-10 00:11:01 AM INFO Checking slaves status (before failover).
       2017-11-10 00:11:01 AM INFO Preparing candidate for failover.
       2017-11-10 00:11:01 AM INFO Creating replication user if it does not exist.
       2017-11-10 00:11:01 AM INFO Spawning external script.
       2017-11-10 00:11:54 AM INFO Script completed Ok.
       2017-11-10 00:11:54 AM INFO Stopping slaves.
       2017-11-10 00:11:54 AM INFO Performing STOP on all slaves.
       2017-11-10 00:11:54 AM INFO Switching slaves to new master.
       2017-11-10 00:11:54 AM INFO Disconnecting new master as slave.
       2017-11-10 00:11:54 AM INFO Starting slaves.
       2017-11-10 00:11:54 AM INFO Performing START on all slaves.
       2017-11-10 00:11:54 AM INFO Checking slaves for errors.
       2017-11-10 00:11:54 AM INFO Failover complete.
       2017-11-10 00:11:59 AM INFO Unregistering existing instances from slaves.
       2017-11-10 00:11:59 AM INFO Registering instance on new master mysqlnode2:3306.
       2017-11-10 00:11:59 AM INFO Master Information
       2017-11-10 00:11:59 AM INFO Binary Log File: mysql-bin.000004, Position: 1340, Binlog_Do_DB: N/A, Binlog_Ignore_DB: N/A
       2017-11-10 00:11:59 AM INFO GTID Executed Set: 3c54f865-c5e4-11e7-8a8b-000c29a2555a:1-6[...]
       2017-11-10 00:11:59 AM INFO Getting health for master: mysqlnode2:3306.
       2017-11-10 00:11:59 AM INFO Health Status:
       2017-11-10 00:11:59 AM INFO host: mysqlnode2, port: 3306, role: MASTER, state: UP, gtid_mode: ON, health: OK

   ``` 
#from the above log you can use "INFO Binary Log File: mysql-bin.000004, Position: 1340, Binlog_Do_DB: N/A, Binlog_Ignore_DB:   N/A" to start replicating data from new master to slaves.
  

7) Below is the command to stop mysqlfailover demon.

   ```shell
   
   mysqlfailover --demon=stop
   
   ```

Note: mysqlfailover is still a single point of failover, if the demon is stopped you have to restart it or you need to setup a job to monitor this demon.
