vrrp_script chk_haproxy {
        script "pidof haproxy"
        interval 5
        weight -4
        fall 2
        rise 1
}

vrrp_instance vrrp_1 {
        interface ens3
        virtual_router_id 1
        state BACKUP
        priority 200
        
    unicast_src_ip ${ip1}

    unicast_peer {
        ${ip2}
        ${ip3}
    }

        authentication {
                auth_type PASS
                auth_pass Secret
        }
        
        track_script {
                chk_haproxy
        }

    notify_master "/usr/libexec/keepalived/ip_failover.sh" root
    notify_backup "/usr/libexec/keepalived/ip_release.sh" root
}
