create table release (
 name varchar(20) not null,
 description text,
 primary key (name)
);

create table sections (
 name varchar(32) not null,
 description text,
 primary key (name)
);

create table package (
 release varchar(20) not null,
 fullname varchar(128) not null,
 name varchar(64) not null,
 version varchar(64) not null,
 revision varchar (16) not null,
 section varchar(32) not null,
 descshort varchar(80) not null default '',
 desclong text,
 maintainer varchar(255),
 homepage varchar(255),
 latest tinyint not null default '0',
 needtest tinyint not null default '0',
 primary key (release,name),
 index (section),
 index (latest),
 index (needtest)
);
