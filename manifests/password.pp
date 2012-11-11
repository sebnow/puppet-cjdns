# == Define: cjdns::password
#
# This defined resource configures a CJDNS password.
#
# === Parameters
#
# [*ensure*]
#   Ensure the password is configured or absent. Valid values are +present+ and
#   +absent+.
#
# [*password*]
#   Specify the password. Defaults to the resource title.
#
# === Example
#
# cjdns::password {"thisIsNotARealPAssword": }
#
# === Authors
#
# Sebastian Nowicki <sebnow@gmail.com>
#
define cjdns::password (
  $ensure = present,
  $password=$title
) {
  include cjdns
  if ! ($ensure in ["present", "absent"]) {
    fail("cjdns::password ensure parameter must be absent or present")
  }

  $augeas = "/files${cjdns::conf_path}//password//${password}"

  Augeas {
    context => $cjdns::augeas_context,
    incl    => $cjdns::conf_path,
    lens    => "Json.lns",
    notify  => Service[$cjdns::service],
    require => Augeas[$cjdns::augeas],
  }

  if $ensure == 'present' {
    augeas {$augeas:
      changes => [
        "defnode pwds entry[. = 'authorizedPasswords'] authorizedPasswords",
        "defnode pwd \$pwds/array/dict/entry[. = 'password'][string = '$password'] password",
        "set \$pwd/string '$password'",
      ],
    }
  } else {
    augeas {$augeas:
      changes => [
        "defnode pwds entry[. = 'authorizedPasswords'] authorizedPasswords",
        "rm \$pwds/array/dict/entry[. = 'password'][string = '$password'] password",
      ],
    }
  }
}

