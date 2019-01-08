// data shared among test suites

let testPrivateKey = "MIKtfK9lvhBbMU9xThDJ+fe7XXN009ljIKiVDxEMXn0="

let testConfig = """
# A WireGuard config used for integration testing
[Interface]
Address = 192.0.2.0/32
PrivateKey = \(testPrivateKey)
[Peer]
PublicKey = ExO1PPLobAXSOCDFs7GpwJcG+5VMQZD9Pk73YqxXoS8=
Endpoint = 192.0.2.1/32:51820
AllowedIPs = 198.51.100.0/24
"""

let testConfigDifferentCasing = """
# a wireguard config used for integration testing
[interface]
address = 192.0.2.0/32
privatekey = \(testPrivateKey)
[peer]
publickey = exo1pplobaxsocdfs7gpwjcg+5vmqzd9pk73yqxxos8=
endpoint = 192.0.2.1/32:51820
allowedips = 198.51.100.0/24
"""

let testConfigs = [
    "testConfig": testConfig,
    "testConfigDifferentCasing": testConfigDifferentCasing,
]
