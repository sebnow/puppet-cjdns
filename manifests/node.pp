# == Define: cjdns::node
#
# This defined resource configures connection to a remote node.
#
# === Parameters
#
# [*ensure*]
#   Ensure the node is configured or absent. Valid values are +present+ and
#   +absent+.
#
# [*address*]
#   Specify the address of the node. Defaults to the resource title.
#
# [*auth_type*]
#   Specify the type of authentication for the host. Defaults to 1.
#
# [*conf_path*]
#   Specify the cjdroute configuration file path. Defaults to
#   "/etc/cjdroute.conf".
#
# [*key*]
#   Specify the node's public key. Defaults to "null".
#
# [*password*]
#   Specify the node's password.
#
# [*trust*]
#   Specify the trust level for the node. Defaults to 10000.
#
# === Example
#
# cjdns::node {"1.2.3.4:1234":
#   key      => 'thisIsNotARealKey.k',
#   password => 'thisIsNotARealPassword',
# }
#
# === Authors
#
# Sebastian Nowicki <sebnow@gmail.com>
#
define cjdns::node (
  $ensure = present,
  $password,
  $address=$title,
  $auth_type = 1,
  $conf_path = $cjdns::params::conf_path,
  $key = "null",
  $trust = 10000,
) {
  include cjdns
  if ! ($ensure in ["present", "absent"]) {
    fail("cjdns::node ensure parameter must be absent or present")
  }

  $augeas = "/files${cjdns::conf_path}//connectTo//${address}"

  Augeas {
    notify  => Service[$cjdns::service],
    require => Augeas[$cjdns::augeas],
    incl    => $conf_path,
    lens    => "Json.lns",
  }

  if $ensure == 'present' {
    augeas {$augeas:
      context => "/files${conf_path}//entry[. = 'UDPInterface']/dict",
      changes => [
        "defnode connectTo entry[. = 'connectTo'] connectTo",
        "defnode node \$connectTo/dict/entry[. = '${address}'] '${address}'",
        "set \$node/dict/entry[. = 'password'] password",
        "set \$node/dict/entry[. = 'password']/string '${password}'",
        "set \$node/dict/entry[. = 'authType'] authType",
        "set \$node/dict/entry[. = 'authType']/string '${auth_type}'",
        "set \$node/dict/entry[. = 'publicKey'] publicKey",
        "set \$node/dict/entry[. = 'publicKey']/string '${key}'",
        "set \$node/dict/entry[. = 'trust'] trust",
        "set \$node/dict/entry[. = 'trust']/string ${trust}",
      ],
    }
  } else {
    augeas {$augeas:
      changes => [
        "rm /files${conf_path}//entry[. = 'connectTo']//entry[. = '$address']"
      ],
    }
  }
}

