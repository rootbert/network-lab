# network-lab
a small network lab which is a playground for network tests.
This lab consists of 12 VMs (ubuntu 14.04 64bit), they simulate a 3-sites-office
and use the Intel e1000 network interface (had some troubles with specific tests
using virtio).
However, you can just clone the VMs and extend the lab to your own needs; 
just take care of the bridge/tap-interface mappings.
Feel free to play around with firewalling, routing etc. ... just exchange some of
the hosts and start with the tests. Try vyos, OpenBSD, OpenBGP, Quagga, iptables,
etc as firewall ... hope this project saves someone elses time.

default credentials:

user: nwlabadmin

password: nwlabadmin

## Info
Images will follow as soon as I have a site to upload them (12 x 520MB).
The direcotry "files" contains the xml-files for libvirt-bin, the network-lab.odg 
which reflects the lab in a graphic way and the nwlab.sh which starts or stops 
the whole lab.
nwlab01 is the core router which is connected to a bridge on the host and should
then be configured to forward all the packages.

## Setup
You need an Ubuntu 14.04 computer with KVM for the setup, the primary network interface
of the computer should be bridged to br0. This is where the core router nwlab01 
is attached to. Just have a look in the nwlab.sh script where various bridges
(brXX) are defined.
The xml files should be stored into /etc/libvirt/qemu/ and libvirt-bin restarted.
Then you need to edit the virtual disks of each virtual machine, e.g with "virsh edit nwlab01"
you need to adjust the "source file" according to where the images are located: 
``` 
<disk type='file' device='disk'>
      <driver name='qemu' type='raw'/>
      <source file='/mnt/750/vm/nwlab01.img'/>
      <target dev='vda' bus='virtio'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
    </disk>
```
(in my case they are located under /mnt/750/vm/)
The packages "libvirt-bin uml-utilities bridge-utils" are needed, the script checks for
this and installs them

