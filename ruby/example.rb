#!/usr/bin/env ruby

require 'Redland'

#uri_string=args[0]
#parser_name=args[1]
uri_string="file:../perl/dc.rdf"
parser_name="repat"


world=Redland::librdf_new_world
Redland::librdf_world_open world

storage=Redland::librdf_new_storage world, "hashes", "test", "new='yes',hash-type='bdb',dir='.'"
raise "Failed to create RDF storage" if !storage


model=Redland::librdf_new_model world, storage, ""
if !model then
  Redland::librdf_free_storage storage
  raise "Failed to create RDF model"
end

parser=Redland::librdf_new_parser world, parser_name, "", nil
if !parser then
  Redland::librdf_free_model model
  Redland::librdf_free_storage storage
  raise "Failed to create RDF parser"
end

uri=Redland::librdf_new_uri world, uri_string

stream=Redland::librdf_parser_parse_as_stream parser, uri, uri

count=0
while Redland::librdf_stream_end(stream) == 0
  statement=Redland::librdf_stream_next stream
  Redland::librdf_model_add_statement model, statement
  puts "found statement: #{Redland::librdf_statement_to_string statement}"
  count=count+1
end

Redland::librdf_free_stream stream

puts "Parsing added count statements"

Redland::librdf_free_parser parser


puts "Printing all statements"
stream=Redland::librdf_model_serialise model
while Redland::librdf_stream_end(stream) == 0
  statement=Redland::librdf_stream_next stream
  puts "Statement: #{Redland::librdf_statement_to_string statement}"
end

Redland::librdf_free_stream stream


Redland::librdf_free_model model
Redland::librdf_free_storage storage

Redland::librdf_free_world world
