$DBversion = 'XXX'; # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {

    if( !column_exists( 'branchtransfers', 'datecancelled' ) ) {
        $dbh->do( "ALTER TABLE `branchtransfers` ADD COLUMN `datecancelled` datetime default NULL AFTER `datearrived`" );
    }

    NewVersion( $DBversion, 26057, "Add datecancelled field to branchtransfers");
}
