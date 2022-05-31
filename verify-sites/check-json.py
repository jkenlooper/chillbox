import sys
import json

from jschon import create_catalog, JSON, JSONSchema

create_catalog("2020-12")

with open("site.schema.json") as site_schema_file:
    schema = JSONSchema(json.load(site_schema_file))

with open(sys.argv[1]) as json_file:
    result = schema.evaluate(JSON(json.load(json_file)))

sys.exit(0 if result.output("flag")["valid"] else 1)
