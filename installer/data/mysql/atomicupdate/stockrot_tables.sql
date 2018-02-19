-- Stock Rotation Rotas

CREATE TABLE IF NOT EXISTS stockrotationrotas (
    rota_id int(11) auto_increment,          -- Stockrotation rota ID
    title varchar(100) NOT NULL,            -- Title for this rota
    description text NOT NULL default '',   -- Description for this rota
    cyclical tinyint(1) NOT NULL default 0, -- Should items on this rota keep cycling?
    active tinyint(1) NOT NULL default 0,   -- Is this rota currently active?
    PRIMARY KEY (`rota_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Stock Rotation Stages

CREATE TABLE IF NOT EXISTS stockrotationstages (
    stage_id int(11) auto_increment,     -- Unique stage ID
    position int(11) NOT NULL,           -- The position of this stage within its rota
    rota_id int(11) NOT NULL,            -- The rota this stage belongs to
    branchcode_id varchar(10) NOT NULL,  -- Branch this stage relates to
    duration int(11) NOT NULL default 4, -- The number of days items shoud occupy this stage
    PRIMARY KEY (`stage_id`),
    CONSTRAINT `stockrotationstages_rifk`
      FOREIGN KEY (`rota_id`)
      REFERENCES `stockrotationrotas` (`rota_id`)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT `stockrotationstages_bifk`
      FOREIGN KEY (`branchcode_id`)
      REFERENCES `branches` (`branchcode`)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Stock Rotation Items

CREATE TABLE IF NOT EXISTS stockrotationitems (
    itemnumber_id int(11) NOT NULL,         -- Itemnumber to link to a stage & rota
    stage_id int(11) NOT NULL,              -- stage ID to link the item to
    indemand tinyint(1) NOT NULL default 0, -- Should this item be skipped for rotation?
    fresh tinyint(1) NOT NULL default 0,    -- Flag showing item is only just added to rota
    PRIMARY KEY (itemnumber_id),
    CONSTRAINT `stockrotationitems_iifk`
      FOREIGN KEY (`itemnumber_id`)
      REFERENCES `items` (`itemnumber`)
      ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT `stockrotationitems_sifk`
      FOREIGN KEY (`stage_id`)
      REFERENCES `stockrotationstages` (`stage_id`)
      ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- System preferences

INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES
       ('StockRotation','0','If ON, enables the stock rotation module','','YesNo'),
       ('RotationPreventTransfers','0','If ON, prevent any transfers for items on stock rotation rotas, except for stock rotation transfers','','YesNo');

-- Permissions

INSERT IGNORE INTO userflags (bit, flag, flagdesc, defaulton) VALUES
       (23, 'stockrotation', 'Manage stockrotation operations', 0);

INSERT IGNORE INTO permissions (module_bit, code, description) VALUES
       (23, 'can_edit_rotas', 'Create, edit and delete rotas'),
       (23, 'can_add_items_rotas', 'Add and remove items from rotas');
