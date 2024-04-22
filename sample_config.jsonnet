# function to get the macAdresses of the nodes
local getNodesForMacAddresses(nodes) = {
  [nodes[name].macAddress]: name
  for name in std.objectFields(nodes)
};
# function to get the cluster metadata for the nodes
local getClusterMetadataForNodes(clusters) = {
  [node]: std.prune({
    'cluster': cluster,
  } + clusters[cluster] { nodes:: null, })
  for cluster in std.objectFields(clusters)
  for node in clusters[cluster].nodes
};
{
    'templates': {
        'ipxe': {
            'default': self.rhel9,
            'rhel9': |||
              #!ipxe
              kernel {{ kernelUrl }} initrd=initrd ip=dhcp inst.repo={{ installRepoUrl }} inst.ks={{ installKickstartUrl }}
              initrd {{ initrdUrl }}
              boot
            |||
        },
        'kickstart': {
            'default': self.rhel9,
            'rhel9': |||
              # version=RockyLinux9
              text
              lang en_US.UTF-8
              keyboard us
              firewall --enabled --service ssh
              timezone America/Los_Angeles
              # join bondslaves
              network --bootproto=dhcp --device={{ networkLink }} --onboot=on --activate --hostname {{ hostname }} {%- if networkDevice == "bond" -%} --bondslaves={{ bondSlaves | join_with_comma }} {%- endif -%}
              
              ignoredisk --only-use={{ installDisk }}
              clearpart --all --drives={{ installDisk }}
              part /boot/efi --fstype="efi" --size=1024
              part / --fstype=xfs --size=1 --grow
              rootpw --plaintext "provisioning"
              reboot
              %packages
              @base
              @core
              @development
              %end
              %post
              # Enable root login for SSH
              mkdir /root/.ssh
              chmod 0700 /root/.ssh
              echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDY6sn37rrrOVcmHE6ZcuL2HiOj4i+T2z4bWvsEWcEqwxxraIIYJvZeLX8m5Iikgh4NvZF9PElDBUaWz2FkoE8C/lFLHmjq/80ayJcJVZTqhGgdhxccbGZIX4RhmYd5Wmu8mrkzrVNrv08DLnWyZV4ag50sYdtX6qNyHXiuLB7GO+Oq9ui0DfXnVXt/QLomVEDOW9PefkKPLv3LoYWvnyHE7+muOZmoEGL1Yi7HUbTJFAX4zElArsgbVkqcEUEtuQ+Ic+iB5ZbgGcwgpXLDtzhDvAJ2TVIFezgzwSEmmDo1rOFQOSWXAJwiGeMWQTERQpZoblYORYgQw8HV/DkD/IwADcTurSSTOonnZVfejWzuChN5Tb4TakD92yUOHs16Qpy/QWEECSu8dh49iysRjTrBNZskxyn3H42N1pPq1Mt4AWd3kGO4YIDYojxtX5NNDPk/eGV0X+O8sLHrHz/NwtMt4Fsi5RtZak78tM/oC8BUFJU/2nrzgF1qITXVyE8qhuzi6mY/oQZ4Ex2EVEvpouerkkLcCRPJKIBuAb362KSG4E7kg0ta3XgiPlevYPuPI220k6jiLiJH8QZKrQJ6TvOwgKC8T5b9WfegUR0UL+FjEI+yWN9xBjgiHHEW/h0+6c7Xs1Nj72XqFW5bQIzIZHUN+DrU73KqPrQ5qRxlJpe7qQ==" > /root/.ssh/authorized_keys
              %end
            |||
        }
    },
    'clusters': {
        'us1': {
            'installRepoUrl': 'http://nas-01.cloud-fortress.net/isos/Rocky-9.3-x86_64-dvd',
            'installKickstartUrl': 'https://netboot.cloud-fortress.net/kickstart?mac_address${net0/mac}',
            'kernelUrl': 'http://nas-01.cloud-fortress.net/isos/Rocky-9.3-x86_64-dvd/images/pxeboot/vmlinuz',
            'initrdUrl': 'http://nas-01.cloud-fortress.net/isos/Rocky-9.3-x86_64-dvd/images/pxeboot/initrd.img',
            'templates': {
                'ipxe': 'default',
                'kickstart': 'default'
            },
            'nodes': [
                'beastmode.cloud-fortress.net',
                'controller-01.cloud-fortress.net',
                'controller-02.cloud-fortress.net',
                'controller-03.cloud-fortress.net',
                'controller-04.cloud-fortress.net',
                'controller-05.cloud-fortress.net',
                'controller-06.cloud-fortress.net'
            ]
        },
        'us2': {
            'nodes': [
                'controller-07.cloud-fortress.net',
                'controller-08.cloud-fortress.net',
                'controller-09.cloud-fortress.net',
                'controller-10.cloud-fortress.net',
                'controller-11.cloud-fortress.net',
                'controller-12.cloud-fortress.net',
                'controller-13.cloud-fortress.net'
            ]
        }
    },
    'nodes': std.mergePatch(getClusterMetadataForNodes(self.clusters), 
    {
        'beastmode.cloud-fortress.net': {
            'macAddress': '98:b7:85:01:17:ae',
            'ignoreDisks': [
                'disk/by-id/nvme-eui.e8238fa6bf530001001b448b4e410d9b',
                'disk/by-id/nvme-eui.e8238fa6bf530001001b448b4e459dae'
            ],
            'network': {
                'device': 'bond',
                'bondSlaves': 'enp67s0f0,enp67s0f1'
            }
        },
        'controller-01.cloud-fortress.net': {
            'macAddress': '6c:4b:90:e3:9d:b4',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-02.cloud-fortress.net': {
            'macAddress': '6c:4b:90:e3:a8:21',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-03.cloud-fortress.net': {
            'macAddress': '6c:4b:90:e3:a0:e3',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-04.cloud-fortress.net': {
            'macAddress': '6c:4b:90:e3:9e:2b',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-05.cloud-fortress.net': {
            'macAddress': '6c:4b:90:d4:6d:cd',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-06.cloud-fortress.net': {
            'macAddress': '6c:4b:90:e5:51:7f',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-07.cloud-fortress.net': {
            'macAddress': '08:3a:88:67:70:24',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-08.cloud-fortress.net': {
            'macAddress': '08:3a:88:67:70:b2',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-09.cloud-fortress.net': {
            'macAddress': '08:3a:88:67:77:8d',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-10.cloud-fortress.net': {
            'macAddress': '08:3a:88:67:7d:81',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-11.cloud-fortress.net': {
            'macAddress': '08:3a:88:67:70:1a',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-12.cloud-fortress.net': {
            'macAddress': '08:3a:88:67:78:3c',
            'cleanParts': [
                'nvme0n1'
            ]
        },
        'controller-13.cloud-fortress.net': {
            'macAddress': '38:7c:76:4d:4d:a1',
            'cleanParts': [
                'sda'
            ]
        }
    }),
    macAddresses: getNodesForMacAddresses(self.nodes)
}