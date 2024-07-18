        apt install -y iptables-persistent
# Clear firewall config
        iptables -F
        iptables -X
        iptables -t nat -F
        iptables -t nat -X
        iptables -t mangle -F
# Config ipv4 firewall
        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        iptables -A INPUT -m state --state INVALID -j DROP
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A INPUT -p icmp --icmp-type 3 -j ACCEPT
        iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT
        iptables -A INPUT -p icmp --icmp-type 12 -j ACCEPT
        iptables -A INPUT -p udp --dport 5353 -j ACCEPT
        iptables -A INPUT -j DROP
        iptables -A FORWARD -j DROP
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
# Config ipv6 firewall
        ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        ip6tables -A INPUT -m state --state INVALID -j DROP
        ip6tables -A INPUT -i lo -j ACCEPT
        ip6tables -A INPUT -p ipv6-icmp -j ACCEPT
        ip6tables -A INPUT -j DROP
        ip6tables -A FORWARD -j DROP
        ip6tables -P INPUT DROP
        ip6tables -P FORWARD DROP
        ip6tables -P OUTPUT ACCEPT
        iptables-save > /etc/iptables/rules.v4
        ip6tables-save > /etc/iptables/rules.v6
        sleep 5;
        service netfilter-persistent restart
        sleep 5;
