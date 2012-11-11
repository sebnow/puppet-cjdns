# == Class: cjdns
#
# This class installs and configures CJDNS.
#
# https://github.com/cjdelisle/cjdns
#
# === Parameters
#
# [*ensure*]
#   Ensure CJDNS is installed or absent. Valid values are +present+ and
#   +absent+.
#
# [*admin_host*]
#   Specify the admin RPC bind address
#
# [*admin_port*]
#   Specify the admin RPC bind port
#
# [*admin_password*]
#   Specify the admin RPC password
#
# [*conf_path*]
#   Path to the cjdroute.conf configuration file. Default to
#   "/etc/cjdroute.conf"
#
# [*host*]
#   Specify the bind address
#
# [*port*]
#   Specify the bind port
#
# [*inactivity*]
#   Specify the amount of time after which inactive CryptoAuth sessions are town
#   down, in seconds.
#
# [*ipv6*]
#   Specify the IPv6 address for the CJDNS node
#
# [*pid_file*]
#   Specify the PID file location
#
# [*private_key*]
#   Specify the private key for the CJDNS node. This can be generated using
#   "cjdroute --genconf".
#
# [*public_key*]
#   Specify the public key for the CJDNS node. This can be generated using
#   "cjdroute --genconf".
#
# [*schema_version*]
#   Specify the schema version of the cjdroute configuration file. Defaults to
#   1.
#
# === Example
#
# class {"cjdns":
#   host           => "127.0.0.1",
#   port           => 11234,
#   ipv6           => "fc8f:2064:091f:9987:566b:1b58:6c9a:648c",
#   private_key    => "88dfc2748a152a02225dd07057ec141ace0f2181d607680bb970b1ccd1f6ac28",
#   public_key     => "hd0znhy24zhzb3td4ssv4uc4x61xwgu6s4405urjysmgq8lnjqg0.k",
# }
#
# === Authors
#
# Sebastian Nowicki <sebnow@gmail.com>
#
class cjdns (
  $ensure = present,
  $ipv6,
  $port,
  $private_key,
  $public_key,
  $admin_host = $cjdns::params::admin_host,
  $admin_password = undef,
  $admin_port = $cjdns::params::admin_port,
  $conf_path = $cjdns::params::conf_path,
  $host = $cjdns::params::host,
  $inactivity = $cjdns::params::inactivity,
  $pid_file = $cjdns::params::pid_file,
  $schema_version = $cjdns::params::schema_version
) inherits cjdns::params {
  if ! ($ensure in ["present", "absent"]) {
    fail("cjdns ensure parameter must be absent or present")
  }

  $package = 'cjdns'
  $service = 'cjdns'
  $augeas = "/files$conf_path"
  $augeas_context = "$augeas/dict"
  $bind_address = "$host:$port"

  # Workarounds for augeas's JSON lens
  $workarounds = [
    # Comments are not allowed in the JSON spec
    's#//.*$##',
    '/\/\*/,/\*\//d',
    # Remove empty lines
    '/^\s*$/d',
    # Remove example values. Some of these cause issues.
    '/router/,/},/d',
    '/interfaces/,/},/d',
    '/security/,/],/d',
    '/admin/,/},/d',
    '/authorizedPasswords/,/],/d',
    # Numbers are valid but the lens doesn't support them
    's/"\:[\t ]*\([0-9][0-9]*\)\(,\)\?$/":"\1"\2/',
  ]

  if $ensure == "present" {
    $service_enable = true
    $service_ensure = running
    $package_ensure = present
  } else {
    $service_enable = false
    $service_ensure = stopped
    $package_ensure = absent
  }

	package {$package:
		ensure => $package_ensure,
	}

  if $ensure == 'absent' {
    file {$conf_path:
      ensure => $ensure,
    }
  } else {
    exec {'cjdroute --genconf':
      command => inline_template("cjdroute --genconf | sed '<%= workarounds.join('; ') %>' > $conf_path"),
      creates => $conf_path,
    }

    file {$conf_path:
      ensure  => $ensure,
      require => Exec['cjdroute --genconf'],
      mode    => 600,
    }

    Augeas {
      require => [Package[$package], Exec['cjdroute --genconf']],
      incl    => $conf_path,
      lens    => "Json.lns",
    }

    augeas {$augeas:
      context => $augeas_context,
      changes => [
        "set entry[. = 'version'] version",
        "set entry[. = 'version']/string '${schema_version}'",
        "set entry[. = 'privateKey'] privateKey",
        "set entry[. = 'privateKey']/string '${private_key}'",
        "set entry[. = 'publicKey'] publicKey",
        "set entry[. = 'publicKey']/string '${public_key}'",
        "set entry[. = 'ipv6'] ipv6",
        "set entry[. = 'ipv6']/string '${ipv6}'",
        "set entry[. = 'resetAfterInactivitySeconds'] resetAfterInactivitySeconds",
        "set entry[. = 'resetAfterInactivitySeconds']/string '${inactivity}'",
        "set entry[. = 'pidFile'] pidFile",
        "set entry[. = 'pidFile']/string '${pid_file}'",
        "defnode interfaces entry[. = 'interfaces'] interfaces",
        "defnode udp \$interfaces/dict/entry[. = 'UDPInterface'] UDPInterface",
        "defnode bind \$udp/dict/entry[. = 'bind'] bind",
        "set \$bind/string '$bind_address'",
        "defnode router entry[. = 'router'] router",
        "defnode iface \$router/dict/entry[. = 'interface'] interface",
        "set \$iface/dict/entry[. = 'type'] type",
        "set \$iface/dict/entry[. = 'type']/string 'TUNInterface'",
      ],
    }

    if $admin_password {
      $admin_address = "${admin_host}:${admin_port}"
      $augeas_admin = "${augeas_context}//admin"
      augeas {$augeas_admin:
        context => $augeas_context,
        changes => [
          "defnode admin entry[. = 'admin'] admin",
          "set \$admin/dict/entry[. = 'bind'] bind",
          "set \$admin/dict/entry[. = 'bind']/string '${admin_address}'",
          "set \$admin/dict/entry[. = 'password'] password",
          "set \$admin/dict/entry[. = 'password']/string '${admin_password}'",
        ],
      }
    }
  }

	service {$service:
    enable    => $service_enable,
		ensure    => $service_ensure,
		require   => [Package[$package], Augeas[$augeas]],
    subscribe => Augeas[$augeas],
	}
}

