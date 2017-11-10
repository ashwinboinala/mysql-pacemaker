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
