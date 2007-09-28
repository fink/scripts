create table if not exists `sections` (
 name varchar(32) not null,
 description text,
 primary key (name)
) engine = innodb collate ascii_general_ci;

create table if not exists `distribution` (
  dist_id int unsigned not null auto_increment,
  identifier varchar(16) not null,
  description varchar(64) not null default '',
  architecture enum('powerpc', 'i386') not null default 'powerpc',
  priority tinyint unsigned not null default '1',
  active boolean default 1,
  visible boolean default 1,
  unsupported boolean default 0,
  primary key (dist_id)
) engine = innodb collate ascii_general_ci;

create table if not exists `release` (
  rel_id int unsigned not null auto_increment,
  dist_id int unsigned not null references `distribution(dist_id)`,
  type enum('bindist', 'stable', 'unstable') not null,
  version varchar(16) not null,
  priority tinyint unsigned not null default '1',
  active boolean default 1,
  primary key (rel_id),
  index (dist_id),
  index (rel_id, dist_id),
  index (priority),
) engine = innodb collate ascii_general_ci;

create table if not exists `package` (
 pkg_id int unsigned not null auto_increment,
 rel_id int unsigned not null references `release(rel_id)`,
 name varchar(64) not null,
 parentname varchar(64),
 version varchar(64) not null,
 revision varchar (16) not null,
 epoch tinyint not null default '0',
 descshort varchar(80) not null default '',
 desclong text,
 descusage text,
 maintainer varchar(255),
 license varchar(64),
 homepage varchar(255),
 section varchar(32) not null,
 infofile varchar(255) not null default '',
 infofilechanged datetime,
 primary key (pkg_id),
 index (name),
 index (section),
 index (rel_id)
 index (name, rel_id),
) engine = innodb collate ascii_general_ci;
