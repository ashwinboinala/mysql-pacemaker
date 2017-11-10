# mysql-pacemaker
Mysql auto failover using pacemaker.

Below is a simple solution to automate mysqlfailover using pacemaker:

Prerequisites :

1) Mysql installed on both the nodes with mysqlutilities.

2) Virtual Ip with a DNS entry.

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
    3) 	Create a user on both mysql nodes and assign password
        (ex: mysqlcluster user: hacluster pwwd: hacluster)
        
    4)  Cluster auth:
        ```shell
        #pcs cluster auth node1 node2

        #ex :
        pcs cluster auth mysqlnode1 mysqlnode2
        ```
    5)  Start the cluster
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
   
   8)  Enable all services 
       
       ```shell
       pcs cluster enable --all
       
       ```
       
   9)  Check status.
      ```shell
       pcs status
     ``` 
   10) manual failover
       ```shell
       pcs cluster stop mysqlnode1
       
       ```
      
      
4) Auto failover script for pacemaker:

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
       
       




