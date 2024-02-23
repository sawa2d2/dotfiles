#!/bin/bash

function create_libvirt_pool()
{
  POOL_PATH=$1
  POOL_NAME=$2

  virsh pool-info $POOL_NAME &> /dev/null
  if [ $? -eq 0 ]; then
    echo "Nothing to do: Pool \"$POOL_NAME\" already exists."
    return
  fi

  mkdir -p $POOL_PATH
  chmod 755 $POOL_PATH


  virsh pool-define /dev/stdin <<EOF
<pool type='dir'>
  <name>$POOL_NAME</name>
  <target>
    <path>$POOL_PATH</path>
  </target>
</pool>
EOF

  virsh pool-start $POOL_NAME
  virsh pool-autostart $POOL_NAME
}

create_libvirt_pool "/var/lib/libvirt/images" "default"
create_libvirt_pool "/home/images" "home"
