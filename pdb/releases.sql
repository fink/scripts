delete from `distribution`;
delete from `release`;

insert into `distribution` (dist_id, identifier, description, architecture, priority, active, visible, unsupported) values (null, '10.1', '10.1', 'powerpc', 1, 0, 0, 1);
select @last_dist_id := last_insert_id();
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'bindist',  '0.4.1', 1, 0);

insert into `distribution` (dist_id, identifier, description, architecture, priority, active, visible, unsupported) values (null, '10.2-gcc3.3', '10.2\n(gcc3.3 only)', 'powerpc', 2, 1, 1, 1);
select @last_dist_id := last_insert_id();
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'unstable', 'current', 3, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'stable',   'current', 2, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'bindist',  '0.6.4', 1, 1);

insert into `distribution` (dist_id, identifier, description, architecture, priority, active, visible, unsupported) values (null, '10.3', '10.3', 'powerpc', 3, 1, 1, 0);
select @last_dist_id := last_insert_id();
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'unstable', 'current', 3, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'stable',   'current', 2, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'bindist',  '0.7.2', 1, 1);

insert into `distribution` (dist_id, identifier, description, architecture, priority, active, visible, unsupported) values (null, '10.4', '10.4/powerpc', 'powerpc', 4, 1, 1, 0);
select @last_dist_id := last_insert_id();
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'unstable', 'current', 3, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'stable',   'current', 2, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'bindist',  '0.8.1', 1, 1);

insert into `distribution` (dist_id, identifier, description, architecture, priority, active, visible, unsupported) values (null, '10.4', '10.4/intel', 'i386', 5, 1, 1, 0);
select @last_dist_id := last_insert_id();
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'unstable', 'current', 3, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'stable',   'current', 2, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'bindist',  '0.8.1', 1, 1);

insert into `distribution` (dist_id, identifier, description, architecture, priority, active, visible, unsupported) values (null, '10.5', '10.5/powerpc', 'powerpc', 6, 1, 0, 0);
select @last_dist_id := last_insert_id();
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'unstable', 'current', 3, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'stable',   'current', 2, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'bindist',  '0.9.0', 1, 0);

insert into `distribution` (dist_id, identifier, description, architecture, priority, active, visible, unsupported) values (null, '10.5', '10.5/intel', 'i386', 7, 1, 0, 0);
select @last_dist_id := last_insert_id();
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'unstable', 'current', 3, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'stable',   'current', 2, 1);
insert into `release` (rel_id, dist_id, type, version, priority, active) values (null, @last_dist_id, 'bindist',  '0.9.0', 1, 0);
