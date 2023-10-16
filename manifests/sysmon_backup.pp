### Purpose ########
# This class provides sysmon backups
class puppet_infrastructure::sysmon_backup {

  $mysystype = 'sysmon'
  $mybasedir = lookup("${mysystype}::basedir")
  $myprefix  = lookup("${mysystype}::address")
  $mybackdir = lookup("${mysystype}::backdir")
  $myndays   = lookup("${mysystype}::backdays")
  $compression = lookup( { 'name' => "${mysystype}::compression", 'default_value' => true } )
  $mybindir  = lookup('filesystem::bindir')

  puppet_infrastructure::backup { $mysystype: basedir => $mybasedir, prefix => $myprefix, backdir => $mybackdir, ndays => $myndays, bindir => $mybindir, compression => $compression }

}
