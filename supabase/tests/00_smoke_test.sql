begin;
set local search_path = public, extensions;

create temp table tap_out(seq serial, line text);
grant all on tap_out to public;
grant all on sequence tap_out_seq_seq to public;

insert into tap_out(line) select plan(2);
insert into tap_out(line) select has_schema('private', 'schema private existe');
insert into tap_out(line) select has_extension('pgcrypto', 'pgcrypto habilitado');
insert into tap_out(line) select * from finish();

select string_agg(line, E'\n' order by seq) as tap from tap_out;
rollback;
