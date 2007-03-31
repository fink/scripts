CREATE TABLE file_paths (
       file_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       parent_id INTEGER NOT NULL,
       file_name VARCHAR NOT NULL,
       fullpath STRING NOT NULL,
       UNIQUE (parent_id, file_name)
);

CREATE TABLE packages (
       package_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       package_name STRING NOT NULL UNIQUE
);

CREATE TABLE file_versions (
       file_version_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
       is_directory BOOLEAN NOT NULL,
       package_id INTEGER NOT NULL,
       fullpath STRING NOT NULL,
       file_id INTEGER NOT NULL,
       size INTEGER NOT NULL,
       posix_user STRING NULL,
       posix_group STRING NULL,
       flags VARCHAR NULL,
       UNIQUE (package_id, file_id)
);
CREATE INDEX file_ver_idx ON file_versions (file_id);