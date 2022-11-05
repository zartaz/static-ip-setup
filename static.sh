#!/bin/bash

function check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "ubuntu" ]; then
            echo -e "\nUbuntu detected, proceeding...\n"
            return 0
        fi
    fi
    return 1
}
function check_netplan() {
    if which netplan > /dev/null; then
        echo -e "\nNetplan is installed, proceeding...\n"
        return 0
    fi
    return 1
}
function check_networkd() {
    if which networkctl > /dev/null; then
        echo -e "\nNetworkd is installed, proceeding...\n"
        return 0
    fi
    return 1
}
function check_hostnamectl() {
    if which hostnamectl > /dev/null; then
        echo -e "\nHostnamectl is installed, proceeding...\n"
        return 0
    fi
    echo -e "\nHostnamectl is not installed, exiting...\n"
    return 1
}
function backup_yaml() {
    echo -e "\nRenaming all .yaml files inside /etc/netplan/ to .yaml.bak\n"
    sudo mv /etc/netplan/*.yaml /etc/netplan/*.yaml.bak
}
function create_static_yaml() {
    #list all interfaces
    echo -e "\nListing all interfaces...\n"
    sudo ip link show
    echo -e "\nPlease enter the interface you want to configure: "
    read interface

    #show the current ip address
    echo -e "\nShowing current ip address...\n"
    sudo ip addr show $interface
    echo -e "\nPlease enter the IP address you want to assign to $interface: "
    read ip

    #ask user for netmask or press enter to use default
    echo -e "\nPlease enter the netmask you want to assign to $interface or press enter to use default: "
    read netmask
    if [ -z "$netmask" ]; then
        netmask=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | cut -d'/' -f2)
    fi

    #ask user for gateway or press enter to use default
    echo -e "\nPlease enter the gateway you want to assign to $interface or press enter to use default: "
    read gateway
    if [ -z "$gateway" ]; then
        gateway=$(ip route | awk '/default/ {print $3}')
    fi

    #ask user for dns or press enter to use default
    echo -e "\nPlease enter the dns you want to assign to $interface or press enter to use default: "
    read dns
    if [ -z "$dns" ]; then
        dns=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
    fi

    # ask hostname or use default
    echo -e "\nPlease enter the hostname you want to assign to $interface or press enter to use default: "
    read hostname
    if [ -z "$hostname" ]; then
        hostname=$(hostname)
    fi

    echo -e "\nCreating /etc/netplan/01-netcfg.yaml\n"
    sudo touch /etc/netplan/01-netcfg.yaml

    echo -e "\nWriting to /etc/netplan/01-netcfg.yaml\n"
    sudo cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
    version: 2
    renderer: networkd
    ethernets:
        $interface:
            addresses:
                - $ip/$netmask
            nameservers:
                addresses: [$dns]
            routes:
                - to: default
                  via: $gateway
}
EOF
    echo -e "\nApplying new configuration...\n"
    sudo netplan apply
    echo -e "\nSetting hostname to $hostname...\n"
    sudo hostnamectl set-hostname $hostname
    echo -e "\nSetting domain name to $domain...\n"
    sudo hostnamectl set-domain $domain
    echo -e "\nDone!\n"
}

check_os
check_netplan
check_networkd
check_hostnamectl
backup_yaml
create_static_yaml