$DBversion = 'XXX';
if( CheckVersion( $DBversion ) ) {

    unless (TableExists('smtp_servers')) {

        # Create the table
        $dbh->do(q{
            CREATE TABLE `smtp_servers` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `name` VARCHAR(80) NOT NULL,
                `library_id` VARCHAR(10) NULL DEFAULT NULL,
                `host` VARCHAR(80) NOT NULL DEFAULT 'localhost',
                `port` INT(11) NOT NULL DEFAULT 25,
                `timeout` INT(11) NOT NULL DEFAULT 120,
                `ssl_mode` ENUM('disabled', 'ssl', 'starttls') NOT NULL,
                `user_name` VARCHAR(80) NULL DEFAULT NULL,
                `password` VARCHAR(80) NULL DEFAULT NULL,
                `debug` TINYINT(1) NOT NULL DEFAULT 0,
                PRIMARY KEY (`id`),
                UNIQUE KEY `library_id_idx` (`library_id`),
                KEY `host_idx` (`host`),
                CONSTRAINT `library_id_fk` FOREIGN KEY (`library_id`) REFERENCES `branches` (`branchcode`) ON DELETE CASCADE ON UPDATE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        });
    }

    # Always end with this (adjust the bug info)
    NewVersion( $DBversion, 22343, "Add SMTP configuration options");
}
