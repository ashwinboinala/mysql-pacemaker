# mysql-pacemaker
Mysql replication auto failover using pacemaker.

Below is a simple solution to automate mysql replication failover using pacemaker:


1) Mysql installed on both the nodes with mysqlutilities and setup GTID replication.
       
       All slaves must use --master-info-repository=TABLE and create a replication user (ex: repl_admin) with following priviliges:
       SUPER, GRANT OPTION, REPLICATION SLAVE, RELOAD, DROP, CREATE, INSERT, and SELECT.
       

2) You need a virtual Ip with a DNS entry. (ex: 1.2.3.4 DNS: mysqlcluster)

2) Install pacemaker on both nodes, below are the installation steps.



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
        (ex: mysqlcluster user: hacluster pwwd: hacluster)
        
    4)  Cluster auth:
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
        
    6)  Add resource.
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
       
   9)  Check status.
      ```shell
       pcs status
     ``` 
   10) Manual failover
       ```shell
       pcs cluster stop mysqlnode1
       
       #verify if cluster is online on node2 (pcs status), then start cluster on node1
       
       pcs cluster start mysqlnode1
       ```
      
      
4) Auto failover script for pacemaker (pcs-failover.sh), use below script to failover pcs.

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
       

6) Start mysqlfialover demon on secondary.

   ```shell
   
   mysqlfailover --master=master --slaves=local --failover-mode=auto --daemon=start --exec-before=/scripts/pcs-failover.sh 
   --exec-after=/scripts/after-failover.sh --log=/logs/mysql-repllogs.txt --log-age=90 --master-fail-retry=60 --force
   
   
   ```

7) Stop mysqlfailover

   ```shell
   
   mysqlfailover --demon=stop
   
   ```

