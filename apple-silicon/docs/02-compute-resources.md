# Compute Resources

Because we cannot use VirtualBox and are instead using Multipass, [a script is provided](./deploy-virtual-machines.sh) to create the six VMs.

1. Run the VM deploy script from your Mac terminal application

    ```bash
    ./deploy-virtual-machines.sh
    ```

    The script lowers the MTU of every VM to 1400 (see [Troubleshooting](#troubleshooting)). If you know your network carries full size packets you can keep the default with `VM_MTU=1500 ./deploy-virtual-machines.sh`.

2. Verify you can connect to all VMs:

    ```bash
    multipass shell controlplane01
    ```

    You should see a command prompt like `ubuntu@controlplane01:~$`

    Type the following to return to the Mac terminal

    ```bash
    exit
    ```

    Do this for the other controlplanes, both nodes and loadbalancer.

# Deleting the Virtual Machines

When you have finished with your cluster and want to reclaim the resources, perform the following steps

1. Exit from all your VM sessions
1. Run the [delete script](../delete-virtual-machines.sh) from your Mac terminal application

    ```bash
    ./delete-virtual-machines.sh
    ````

1. Clean stale DHCP leases. Multipass does not do this automatically and if you do not do it yourself you will eventually run out of IP addresses on the multipass VM network.

    1. Edit the following

        ```bash
        sudo vi /var/db/dhcpd_leases
        ```

    1. Remove all blocks that look like this, specifically those with `name` like `controlplane`, `node` or `loadbalancer`
        ```text
        {
            name=controlplane01
            ip_address=192.168.64.4
            hw_address=1,52:54:0:78:4d:ff
            identifier=1,52:54:0:78:4d:ff
            lease=0x65dc3134
        }
        ```

    1. Save the file and exit

Next: [Client tools](../../docs/03-client-tools.md)<br>
Prev: [Prerequisites](./01-prerequisites.md)

# Troubleshooting

## Image pulls time out, pods stay in `ContainerCreating` or `Init:0/1`

`containerd` logs show TLS handshake timeouts when pulling images such as `registry.k8s.io/pause`. The network path between the VMs and the internet cannot carry 1500 byte packets (common behind VPNs and some routers), and the ICMP messages that would tell the VM to send smaller packets are dropped. Large TLS packets silently disappear.

Check from any VM. The first command should fail and the second succeed:

```bash
ping -c 3 -M do -s 1472 registry.k8s.io
ping -c 3 -M do -s 1372 registry.k8s.io
```

`deploy-virtual-machines.sh` sets the MTU to 1400 for this reason. If you created the VMs with an older version of the script, run this on every VM:

```bash
IFACE=$(ip route | awk '/default/ { print $5; exit }')
sudo ip link set dev "$IFACE" mtu 1400
```

## Host names stop resolving after the VMs restart

cloud-init rebuilds `/etc/hosts` from `/etc/cloud/templates/hosts.debian.tmpl` at every boot, removing the entries for the other nodes. `deploy-virtual-machines.sh` adds the entries to the template as well, so they survive a restart. If you created the VMs with an older version of the script, run this on every VM while the node entries are still in `/etc/hosts` (if they are already gone, restore them first from `/etc/hosts` on a VM that still has them):

```bash
grep -E 'controlplane|node0|loadbalancer' /etc/hosts | sed 's/$/ # kthw/' | sudo tee -a /etc/cloud/templates/hosts.debian.tmpl
```
