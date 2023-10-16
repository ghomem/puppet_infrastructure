### Purpose ########
# This class provides puppet backups
class puppet_infrastructure::puppet_backup {

  $mysystype = 'puppet'
  $mybasedir = lookup("${mysystype}::basedir")
  $myprefix  = lookup("${mysystype}::address")
  $mybackdir = lookup("${mysystype}::backdir")
  $myndays   = lookup("${mysystype}::backdays")
  $compression = lookup( { 'name' => "${mysystype}::compression", 'default_value' => true } )
  $mybindir  = lookup('filesystem::bindir')

  puppet_infrastructure::backup { $mysystype: basedir => $mybasedir, prefix => $myprefix, backdir => $mybackdir, ndays => $myndays, bindir => $mybindir, compression => $compression }

}
