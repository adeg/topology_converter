#!/bin/bash

echo "#################################"
echo "  Running Extra_Server_Config.sh"
echo "#################################"
if [ "$HOSTNAME" != netq-ts ]; then
  sudo su

  id -u cumulus &>/dev/null || useradd cumulus -m -s /bin/bash
  echo "cumulus:CumulusLinux!" | chpasswd
  usermod -aG sudo cumulus
  echo "cumulus ALL=(ALL) NOPASSWD:ALL" | tee --append /etc/sudoers.d/10_cumulus
  #Setup SSH key authentication for Ansible
  mkdir -p /home/cumulus/.ssh
  wget -qO /home/cumulus/.ssh/authorized_keys http://192.168.200.1/authorized_keys
  chown -R cumulus:cumulus /home/cumulus/.ssh

  #Test for Debian-Based Host
  which apt &> /dev/null
  if [ "$?" == "0" ]; then
      #These lines will be used when booting on a debian-based box
      echo -e "note: ubuntu device detected"

      #Install packages
      apt-get update -qy
      apt-get install -qy htop tree python python-pip ifenslave lldpd ntp

      #Set up LLDP
      echo "configure lldp portidsubtype ifname" > /etc/lldpd.d/port_info.conf

        echo " ### Configure NTP... ###"
        echo <<EOT >> /etc/ntp.conf
driftfile /var/lib/ntp/ntp.drift
statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

server clock.rdu.cumulusnetworks.com

# By default, exchange time with everybody, but don't allow configuration.
restrict -4 default kod notrap nomodify nopeer noquery
restrict -6 default kod notrap nomodify nopeer noquery

# Local users may interrogate the ntp server more closely.
restrict 127.0.0.1
restrict ::1
EOT

      #Replace existing network interfaces file
      echo -e "auto lo" > /etc/network/interfaces
      echo -e "iface lo inet loopback\n\n" >> /etc/network/interfaces
      echo -e  "source /etc/network/interfaces.d/*.intf\n" >> /etc/network/interfaces

      #Add vagrant interface
      echo -e "\n\nauto vagrant" > /etc/network/interfaces.d/vagrant.intf
      echo -e "iface vagrant inet dhcp\n\n" >> /etc/network/interfaces.d/vagrant.intf

      echo -e "\n\nauto eth0" > /etc/network/interfaces.d/eth0.cfg
      echo -e "iface eth0 inet dhcp" >> /etc/network/interfaces.d/eth0.cfg

      #Setup auto-update key authentication for Ansible
      echo -e "    post-up mkdir -p /home/cumulus/.ssh" >> /etc/network/interfaces.d/eth0.cfg
      echo -e "    post-up wget -qO /home/cumulus/.ssh/authorized_keys http://192.168.200.1/authorized_keys" >> /etc/network/interfaces.d/eth0.cfg
      echo -e "    post-up chown -R cumulus:cumulus /home/cumulus/.ssh" >> /etc/network/interfaces.d/eth0.cfg

      echo "retry 1;" >> /etc/dhcp/dhclient.conf
      
  fi

  #Test for Fedora-Based Host
  which yum &> /dev/null
  if [ "$?" == "0" ]; then
      echo -e "note: fedora-based device detected"
      /usr/bin/dnf install python -y
      echo -e "DEVICE=vagrant\nBOOTPROTO=dhcp\nONBOOT=yes" > /etc/sysconfig/network-scripts/ifcfg-vagrant
      echo -e "DEVICE=eth0\nBOOTPROTO=dhcp\nONBOOT=yes" > /etc/sysconfig/network-scripts/ifcfg-eth0

  fi

fi
echo "#################################"
echo "   Finished"
echo "#################################"
