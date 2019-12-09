$DBversion = 'XXX';  # will be replaced by the RM
if( CheckVersion( $DBversion ) ) {
    $dbh->do(q{ INSERT IGNORE INTO systempreferences ( `variable`, `value`, `options`, `explanation`, `type` ) VALUES ( "DisableReserveExpiration", 0, NULL, "Disable the use of expiration date in reserves module.", "YesNo" ) });

    SetVersion( $DBversion );
    print "Upgrade to $DBversion done (Bug 24194 - DisableReserveExpiration system preference)\n";
}
